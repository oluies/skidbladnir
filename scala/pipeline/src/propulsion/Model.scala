package propulsion

/** The typed dataset the rest of the pipeline works against.
  *
  * Nullable database columns are `Option` here rather than sentinel values, because the
  * interesting fact about this dataset is precisely which fields the literature does not
  * record. Collapsing an absent dry mass to 0.0 would hide that.
  */

enum ThrusterType(val dbValue: String):
  case GriddedIon     extends ThrusterType("gridded_ion")
  case Hall           extends ThrusterType("hall")
  case Mpd            extends ThrusterType("mpd")
  case OtherPlasma    extends ThrusterType("other_plasma")
  case NuclearThermal extends ThrusterType("nuclear_thermal")

object ThrusterType:
  def fromDb(s: String): ThrusterType =
    values.find(_.dbValue == s).getOrElse(throw IllegalArgumentException(s"unknown thruster_type: $s"))

enum PowerBasis(val dbValue: String):
  case ElectricalInput extends PowerBasis("electrical_input")
  case ReactorThermal  extends PowerBasis("reactor_thermal")

object PowerBasis:
  def fromDb(s: String): PowerBasis =
    values.find(_.dbValue == s).getOrElse(throw IllegalArgumentException(s"unknown power_basis: $s"))

enum Status(val dbValue: String):
  case Flown            extends Status("flown")
  case GroundTested     extends Status("ground_tested")
  case ReferenceConcept extends Status("reference_concept")

object Status:
  def fromDb(s: String): Status =
    values.find(_.dbValue == s).getOrElse(throw IllegalArgumentException(s"unknown status: $s"))

enum MassBasis(val dbValue: String):
  case Measured  extends MassBasis("measured")
  case Vendor    extends MassBasis("vendor")
  case Secondary extends MassBasis("secondary")
  case Unknown   extends MassBasis("unknown")

object MassBasis:
  def fromDb(s: String): MassBasis =
    values.find(_.dbValue == s).getOrElse(throw IllegalArgumentException(s"unknown mass_basis: $s"))

enum MissionClass(val dbValue: String):
  case CrewedMars      extends MissionClass("crewed_mars")
  case DeepSpaceProbe  extends MissionClass("deep_space_probe")

object MissionClass:
  def fromDb(s: String): MissionClass =
    values.find(_.dbValue == s).getOrElse(throw IllegalArgumentException(s"unknown mission_class: $s"))

final case class Source(
    sourceId: String,
    citation: String,
    venue: Option[String],
    year: Option[Int],
    url: Option[String],
    sourceKind: String
)

final case class Propellant(
    propellant: String,
    acceleratedSpecies: Option[String],
    storedSpecies: Option[String],
    molarMassGMol: Double,
    firstIonisationEV: Option[Double],
    storagePhase: String,
    storageDensityKgM3: Option[Double],
    storagePressureBar: Option[Double],
    sourceId: Option[String]
)

final case class Thruster(
    thrusterId: String,
    name: String,
    thrusterType: ThrusterType,
    propellant: String,
    thrustMN: Option[Double],
    ispS: Option[Double],
    inputPowerW: Option[Double],
    efficiency: Option[Double],
    massKg: Option[Double],
    massBasis: MassBasis,
    powerBasis: PowerBasis,
    status: Status,
    firstFlightYear: Option[Int],
    sourceId: String,
    derivedFields: Option[String]
):
  def thrustN: Option[Double] = thrustMN.map(_ / 1000.0)

  /** True when the row carries everything the power-limited electric model needs. */
  def isElectricComplete: Boolean =
    powerBasis == PowerBasis.ElectricalInput &&
      thrustMN.isDefined && ispS.isDefined && inputPowerW.isDefined && efficiency.isDefined

  /** True when the row carries everything the rocket equation needs. */
  def hasIsp: Boolean = ispS.isDefined

final case class Mission(
    missionId: String,
    name: String,
    missionClass: MissionClass,
    payloadMassKg: Double,
    deltaVMS: Double,
    maxTripTimeDays: Option[Double],
    powerAvailableW: Option[Double],
    powerSource: Option[String]
)

/** One row of the comparison, matching the `results` table column for column. */
final case class ComparisonResult(
    runId: String,
    producer: String,
    missionId: String,
    thrusterId: String,
    nThrusters: Option[Int],
    exhaustVelocityMS: Option[Double],
    massRatio: Option[Double],
    propellantMassFraction: Option[Double],
    propellantMassKg: Option[Double],
    initialMassKg: Option[Double],
    powerPlantMassKg: Option[Double],
    tankMassKg: Option[Double],
    tankMassFraction: Option[Double],
    thrustTotalN: Option[Double],
    powerTotalW: Option[Double],
    tripTimeDays: Option[Double],
    meetsTimeConstraint: Option[Boolean],
    feasible: Boolean,
    alphaKgPerKW: Option[Double],
    notes: String
)
