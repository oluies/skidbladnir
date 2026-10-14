package propulsion

import java.sql.Connection

enum Severity:
  case Error, Warning

/** A validation rule expressed as SQL. The query returns one row per violation, with a
  * single VARCHAR column `detail` describing it. An empty result is a pass.
  */
final case class Check(name: String, severity: Severity, description: String, sql: String)

final case class Violation(check: String, severity: Severity, detail: String)

object Validation:

  /** Published thruster tables round their numbers and sometimes mix anode efficiency with
    * total efficiency, or PPU input power with thruster input power. The largest residual in
    * the current dataset is 0.075 (PPS-1350-G), so 0.10 separates that from a real error.
    */
  val EfficiencyResidualTolerance: Double = 0.10

  val MinimumFlownOrTested: Int = 15

  val KnownDerivedFields: Set[String] =
    Set("thrust_mN", "isp_s", "input_power_W", "efficiency")

  val checks: Vector[Check] = Vector(
    Check(
      "efficiency_range",
      Severity.Error,
      "total efficiency must lie in (0, 1]",
      """SELECT thruster_id || ': efficiency=' || efficiency AS detail
         FROM thrusters
         WHERE efficiency IS NOT NULL AND (efficiency <= 0 OR efficiency > 1)"""
    ),
    Check(
      "isp_range",
      Severity.Error,
      "specific impulse must lie between 100 s and 20000 s",
      """SELECT thruster_id || ': isp_s=' || isp_s AS detail
         FROM thrusters
         WHERE isp_s IS NOT NULL AND (isp_s < 100 OR isp_s > 20000)"""
    ),
    Check(
      "thrust_positive",
      Severity.Error,
      "thrust must be strictly positive when recorded",
      """SELECT thruster_id || ': thrust_mN=' || thrust_mN AS detail
         FROM thrusters WHERE thrust_mN IS NOT NULL AND thrust_mN <= 0"""
    ),
    Check(
      "power_positive",
      Severity.Error,
      "input power must be strictly positive when recorded",
      """SELECT thruster_id || ': input_power_W=' || input_power_W AS detail
         FROM thrusters WHERE input_power_W IS NOT NULL AND input_power_W <= 0"""
    ),
    Check(
      "efficiency_consistency",
      Severity.Error,
      s"quoted efficiency must agree with T*g0*Isp/(2P) to within $EfficiencyResidualTolerance",
      s"""SELECT thruster_id || ': quoted=' || round(efficiency_quoted, 4)
                 || ' derived=' || round(efficiency_derived, 4)
                 || ' residual=' || round(efficiency_residual, 4) AS detail
          FROM v_thruster_consistency
          WHERE efficiency_abs_residual > $EfficiencyResidualTolerance"""
    ),
    Check(
      "ntp_power_basis",
      Severity.Error,
      "nuclear thermal rows must quote reactor thermal power, never electrical input",
      """SELECT thruster_id || ': power_basis=' || power_basis AS detail
         FROM thrusters
         WHERE thruster_type = 'nuclear_thermal' AND power_basis <> 'reactor_thermal'"""
    ),
    Check(
      "electric_power_basis",
      Severity.Error,
      "electric thruster rows must quote electrical input power",
      """SELECT thruster_id || ': power_basis=' || power_basis AS detail
         FROM thrusters
         WHERE thruster_type <> 'nuclear_thermal' AND power_basis <> 'electrical_input'"""
    ),
    Check(
      "orphan_source",
      Severity.Error,
      "every thruster must cite a source present in the sources table",
      """SELECT t.thruster_id || ': source_id=' || t.source_id AS detail
         FROM thrusters t LEFT JOIN sources s ON t.source_id = s.source_id
         WHERE s.source_id IS NULL"""
    ),
    Check(
      "orphan_propellant",
      Severity.Error,
      "every thruster must name a propellant present in the propellants table",
      """SELECT t.thruster_id || ': propellant=' || t.propellant AS detail
         FROM thrusters t LEFT JOIN propellants p ON t.propellant = p.propellant
         WHERE p.propellant IS NULL"""
    ),
    Check(
      "duplicate_thruster_name",
      Severity.Error,
      "thruster names must be unique",
      """SELECT name || ' appears ' || count(*) || ' times' AS detail
         FROM thrusters GROUP BY name HAVING count(*) > 1"""
    ),
    Check(
      "minimum_flown_or_tested",
      Severity.Error,
      s"the dataset must hold at least $MinimumFlownOrTested flown or ground-tested thrusters",
      s"""SELECT 'only ' || count(*) || ' flown or ground-tested thrusters' AS detail
          FROM thrusters WHERE status IN ('flown','ground_tested')
          HAVING count(*) < $MinimumFlownOrTested"""
    ),
    Check(
      "derived_fields_known",
      Severity.Error,
      "derived_fields must name real columns",
      s"""SELECT thruster_id || ': derived_fields=' || derived_fields AS detail
          FROM thrusters
          WHERE derived_fields IS NOT NULL
            AND derived_fields NOT IN (${KnownDerivedFields.map(f => s"'$f'").mkString(", ")})"""
    ),
    Check(
      "mission_parameters_positive",
      Severity.Error,
      "missions need a positive payload mass and delta-v",
      """SELECT mission_id || ': payload=' || payload_mass_kg || ' dv=' || delta_v_m_s AS detail
         FROM missions WHERE payload_mass_kg <= 0 OR delta_v_m_s <= 0"""
    ),
    Check(
      "electric_mission_needs_power",
      Severity.Error,
      "a mission flown on electric propulsion must state the available power",
      """SELECT mission_id AS detail FROM missions
         WHERE power_source IN ('solar_electric','nuclear_electric') AND power_available_W IS NULL"""
    ),
    Check(
      "flown_thruster_has_year",
      Severity.Warning,
      "a flown thruster would normally record a first flight year",
      """SELECT thruster_id AS detail FROM thrusters
         WHERE status = 'flown' AND first_flight_year IS NULL"""
    ),
    Check(
      "dry_mass_unknown",
      Severity.Warning,
      "dry mass is not recorded, so the comparison falls back to a specific-mass assumption",
      """SELECT thruster_id AS detail FROM thrusters WHERE mass_kg IS NULL"""
    ),
    Check(
      "assumed_mission_parameters",
      Severity.Warning,
      "mission parameters are project assumptions rather than values taken from a source",
      """SELECT mission_id AS detail FROM missions WHERE parameter_basis = 'assumed'"""
    )
  )

  def run(conn: Connection): Vector[Violation] =
    checks.flatMap { c =>
      Db.query(conn, c.sql)(rs => Violation(c.name, c.severity, Db.str(rs, "detail")))
    }

  def report(violations: Vector[Violation]): String =
    val errors = violations.filter(_.severity == Severity.Error)
    val warnings = violations.filter(_.severity == Severity.Warning)
    val sb = StringBuilder()
    sb ++= s"validation: ${checks.size} checks, ${errors.size} errors, ${warnings.size} warnings\n"
    for group <- Vector(errors, warnings); v <- group do
      sb ++= f"  ${v.severity.toString.toUpperCase}%-7s ${v.check}%-30s ${v.detail}\n"
    sb.result()
