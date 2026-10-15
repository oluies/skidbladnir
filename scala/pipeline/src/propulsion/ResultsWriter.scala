package propulsion

import java.sql.{Connection, Timestamp, Types}
import java.time.Instant

/** Writes comparison rows back into the `results` table.
  *
  * Rows are replaced per producer, so re-running the Scala pipeline never leaves a mixture of
  * two runs behind, and never disturbs the rows Julia wrote.
  */
object ResultsWriter:

  private val insertSql =
    """INSERT INTO results (
         run_id, run_ts, producer, mission_id, thruster_id, n_thrusters,
         exhaust_velocity_m_s, mass_ratio, propellant_mass_fraction, propellant_mass_kg,
         initial_mass_kg, power_plant_mass_kg, tank_mass_kg, tank_mass_fraction,
         thrust_total_N, power_total_W,
         trip_time_days, meets_time_constraint, feasible, alpha_kg_per_kW, notes
       ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"""

  def write(conn: Connection, producer: String, results: Vector[ComparisonResult]): Int =
    val del = conn.prepareStatement("DELETE FROM results WHERE producer = ?")
    try
      del.setString(1, producer)
      del.executeUpdate()
    finally del.close()

    val ts = Timestamp.from(Instant.now())
    val ps = conn.prepareStatement(insertSql)
    try
      for r <- results do
        ps.setString(1, r.runId)
        ps.setTimestamp(2, ts)
        ps.setString(3, r.producer)
        ps.setString(4, r.missionId)
        ps.setString(5, r.thrusterId)
        setOptInt(ps, 6, r.nThrusters)
        setOptDouble(ps, 7, r.exhaustVelocityMS)
        setOptDouble(ps, 8, r.massRatio)
        setOptDouble(ps, 9, r.propellantMassFraction)
        setOptDouble(ps, 10, r.propellantMassKg)
        setOptDouble(ps, 11, r.initialMassKg)
        setOptDouble(ps, 12, r.powerPlantMassKg)
        setOptDouble(ps, 13, r.tankMassKg)
        setOptDouble(ps, 14, r.tankMassFraction)
        setOptDouble(ps, 15, r.thrustTotalN)
        setOptDouble(ps, 16, r.powerTotalW)
        setOptDouble(ps, 17, r.tripTimeDays)
        setOptBoolean(ps, 18, r.meetsTimeConstraint)
        ps.setBoolean(19, r.feasible)
        setOptDouble(ps, 20, r.alphaKgPerKW)
        ps.setString(21, r.notes)
        ps.addBatch()
      ps.executeBatch().sum
    finally ps.close()

  private def setOptDouble(ps: java.sql.PreparedStatement, i: Int, v: Option[Double]): Unit =
    v match
      case Some(d) if d.isFinite => ps.setDouble(i, d)
      case _                     => ps.setNull(i, Types.DOUBLE)

  private def setOptInt(ps: java.sql.PreparedStatement, i: Int, v: Option[Int]): Unit =
    v match
      case Some(n) => ps.setInt(i, n)
      case None    => ps.setNull(i, Types.INTEGER)

  private def setOptBoolean(ps: java.sql.PreparedStatement, i: Int, v: Option[Boolean]): Unit =
    v match
      case Some(b) => ps.setBoolean(i, b)
      case None    => ps.setNull(i, Types.BOOLEAN)
