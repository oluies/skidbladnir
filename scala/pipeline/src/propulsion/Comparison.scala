package propulsion

/** The comparison pipeline.
  *
  * Analysis assumptions live here as named constants rather than inside the data, because
  * they are choices made by this project and not facts taken from a source. Every one of them
  * is written into the results table so a stored row can be read back without the code.
  */
object Comparison:

  /** Power system specific mass, kg per kW of electrical output.
    *
    * This is the single most consequential assumption in the whole comparison and no
    * megawatt-class system exists to measure it against (see docs/survey.md, nuclear electric
    * propulsion). The nuclear figure is the kind of value mission studies assume; the solar
    * figure is representative of a large flight array with its power processing.
    */
  val PowerPlantAlphaKgPerKW: Map[String, Double] = Map(
    "nuclear_electric" -> 20.0,
    "solar_electric" -> 12.0
  )

  val DefaultAlphaKgPerKW: Double = 20.0

  /** Fallback for thruster plus power processing dry mass when the source does not give one.
    * 24 of the 26 rows in the dataset need this.
    */
  val ThrusterSpecificMassKgPerKW: Double = 5.0

  /** Above this mass ratio the vehicle is not a design, it is an arithmetic artefact. */
  val MaxMassRatio: Double = 1.0e6

  def alphaFor(mission: Mission): Double =
    mission.powerSource.flatMap(PowerPlantAlphaKgPerKW.get).getOrElse(DefaultAlphaKgPerKW)

  /** Compare one thruster against one mission. Returns None when the thruster does not even
    * record a specific impulse, which is the minimum the rocket equation needs.
    *
    * `tankFraction` is the tank dry mass per kg of propellant for this thruster's propellant,
    * from [[Physics.tankMassFraction]]. It is passed in rather than looked up so the physics
    * stays separable from the data access.
    */
  def compare(
      mission: Mission,
      t: Thruster,
      runId: String,
      producer: String,
      tankFraction: Double
  ): Option[ComparisonResult] =
    t.ispS.map { isp =>
      val ve = Physics.exhaustVelocity(isp)
      val mr = Physics.massRatio(mission.deltaVMS, ve)
      val zeta = Physics.propellantMassFraction(mission.deltaVMS, ve)

      val electric = t.isElectricComplete && mission.powerAvailableW.isDefined

      if electric then
        val pAvail = mission.powerAvailableW.get
        val pThruster = t.inputPowerW.get
        val eta = t.efficiency.get
        val n = math.max(1, math.floor(pAvail / pThruster).toInt)
        val pTotal = n * pThruster
        val unitMass = t.massKg.getOrElse(ThrusterSpecificMassKgPerKW * pThruster / 1000.0)
        val alpha = alphaFor(mission)
        val powerPlantMass = alpha * pAvail / 1000.0
        val baseInert = mission.payloadMassKg + powerPlantMass + n * unitMass

        Physics.inertMassWithTank(baseInert, mr, tankFraction) match
          case None =>
            ComparisonResult(
              runId, producer, mission.missionId, t.thrusterId,
              nThrusters = Some(n),
              exhaustVelocityMS = Some(ve),
              massRatio = Some(mr),
              propellantMassFraction = Some(zeta),
              propellantMassKg = None,
              initialMassKg = None,
              powerPlantMassKg = Some(powerPlantMass),
              tankMassKg = None,
              tankMassFraction = Some(tankFraction),
              thrustTotalN = t.thrustN.map(_ * n),
              powerTotalW = Some(pTotal),
              tripTimeDays = None,
              meetsTimeConstraint = None,
              feasible = false,
              alphaKgPerKW = Some(alpha),
              notes = f"tankage diverges: tank fraction $tankFraction%.3f times (MR-1) ${mr - 1}%.3f reaches 1, no closed vehicle"
            )
          case Some(inertMass) =>
            val mp = inertMass * (mr - 1.0)
            val tankMass = tankFraction * mp
            val m0 = inertMass * mr
            val tripSeconds = Physics.transferTimeSeconds(mp, ve, eta, pTotal)
            val tripDays = Physics.secondsToDays(tripSeconds)
            val meetsTime = mission.maxTripTimeDays.map(tripDays <= _)
            val sane = mr.isFinite && mr <= MaxMassRatio && m0.isFinite
            val massNote =
              if t.massKg.isDefined then "thruster mass from source"
              else f"thruster mass assumed at $ThrusterSpecificMassKgPerKW%.1f kg/kW"

            ComparisonResult(
              runId, producer, mission.missionId, t.thrusterId,
              nThrusters = Some(n),
              exhaustVelocityMS = Some(ve),
              massRatio = Some(mr),
              propellantMassFraction = Some(zeta),
              propellantMassKg = Some(mp),
              initialMassKg = Some(m0),
              powerPlantMassKg = Some(powerPlantMass),
              tankMassKg = Some(tankMass),
              tankMassFraction = Some(tankFraction),
              thrustTotalN = t.thrustN.map(_ * n),
              powerTotalW = Some(pTotal),
              tripTimeDays = Some(tripDays),
              meetsTimeConstraint = meetsTime,
              feasible = sane && meetsTime.getOrElse(true),
              alphaKgPerKW = Some(alpha),
              notes = s"power-limited electric; $massNote; " +
                f"power plant $powerPlantMass%.0f kg at $alpha%.1f kg/kW; " +
                f"tank $tankMass%.0f kg at f=$tankFraction%.3f"
            )
      else
        // Nuclear thermal, or any row without the full electric quadruple. The power-limited
        // transfer model does not apply, so trip time is left unevaluated rather than filled
        // with a number the model cannot support.
        val why =
          if t.powerBasis == PowerBasis.ReactorThermal then
            "nuclear thermal: power-limited transfer model does not apply, trip time not evaluated"
          else if mission.powerAvailableW.isEmpty then "mission states no available power"
          else "row lacks one of thrust, Isp, power or efficiency"

        Physics.inertMassWithTank(mission.payloadMassKg, mr, tankFraction) match
          case None =>
            ComparisonResult(
              runId, producer, mission.missionId, t.thrusterId,
              nThrusters = None,
              exhaustVelocityMS = Some(ve),
              massRatio = Some(mr),
              propellantMassFraction = Some(zeta),
              propellantMassKg = None,
              initialMassKg = None,
              powerPlantMassKg = None,
              tankMassKg = None,
              tankMassFraction = Some(tankFraction),
              thrustTotalN = t.thrustN,
              powerTotalW = None,
              tripTimeDays = None,
              meetsTimeConstraint = None,
              feasible = false,
              alphaKgPerKW = None,
              notes = f"$why; tankage diverges at f=$tankFraction%.3f and MR=$mr%.3f"
            )
          case Some(inertMass) =>
            val mp = inertMass * (mr - 1.0)
            val tankMass = tankFraction * mp
            val m0 = inertMass * mr
            val sane = mr.isFinite && mr <= MaxMassRatio && m0.isFinite

            ComparisonResult(
              runId, producer, mission.missionId, t.thrusterId,
              nThrusters = None,
              exhaustVelocityMS = Some(ve),
              massRatio = Some(mr),
              propellantMassFraction = Some(zeta),
              propellantMassKg = Some(mp),
              initialMassKg = Some(m0),
              powerPlantMassKg = None,
              tankMassKg = Some(tankMass),
              tankMassFraction = Some(tankFraction),
              thrustTotalN = t.thrustN,
              powerTotalW = None,
              tripTimeDays = None,
              meetsTimeConstraint = None,
              feasible = sane,
              alphaKgPerKW = None,
              notes = f"$why; engine dry mass excluded; tank $tankMass%.0f kg at f=$tankFraction%.3f"
            )
    }

  /** Tank fraction per propellant name, computed from storage density and pressure. */
  def tankFractions(propellants: Vector[Propellant]): Map[String, Double] =
    propellants.flatMap { p =>
      p.storageDensityKgM3.map { rho =>
        p.propellant -> Physics.tankMassFraction(rho, p.storagePressureBar.getOrElse(0.0))
      }
    }.toMap

  def runAll(
      missions: Vector[Mission],
      thrusters: Vector[Thruster],
      propellants: Vector[Propellant],
      runId: String,
      producer: String
  ): Vector[ComparisonResult] =
    val fractions = tankFractions(propellants)
    for
      m <- missions
      t <- thrusters
      r <- compare(m, t, runId, producer, fractions.getOrElse(t.propellant, 0.0))
    yield r
