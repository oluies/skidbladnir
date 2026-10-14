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
    */
  def compare(mission: Mission, t: Thruster, runId: String, producer: String): Option[ComparisonResult] =
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
        val inertMass = mission.payloadMassKg + powerPlantMass + n * unitMass
        val m0 = inertMass * mr
        val mp = m0 - inertMass
        val tripSeconds = Physics.transferTimeSeconds(mp, ve, eta, pTotal)
        val tripDays = Physics.secondsToDays(tripSeconds)
        val meetsTime = mission.maxTripTimeDays.map(tripDays <= _)
        val sane = mr.isFinite && mr <= MaxMassRatio && m0.isFinite
        val massNote =
          if t.massKg.isDefined then "thruster mass from source"
          else f"thruster mass assumed at $ThrusterSpecificMassKgPerKW%.1f kg/kW"

        ComparisonResult(
          runId = runId,
          producer = producer,
          missionId = mission.missionId,
          thrusterId = t.thrusterId,
          nThrusters = Some(n),
          exhaustVelocityMS = Some(ve),
          massRatio = Some(mr),
          propellantMassFraction = Some(zeta),
          propellantMassKg = Some(mp),
          initialMassKg = Some(m0),
          powerPlantMassKg = Some(powerPlantMass),
          thrustTotalN = t.thrustN.map(_ * n),
          powerTotalW = Some(pTotal),
          tripTimeDays = Some(tripDays),
          meetsTimeConstraint = meetsTime,
          feasible = sane && meetsTime.getOrElse(true),
          alphaKgPerKW = Some(alpha),
          notes = s"power-limited electric; $massNote; " +
            f"power plant $powerPlantMass%.0f kg at $alpha%.1f kg/kW"
        )
      else
        // Nuclear thermal, or any row without the full electric quadruple. The power-limited
        // transfer model does not apply: reactor thermal power is not electrical input power,
        // and a thermal rocket's burn is short compared with the coast. Trip time is left
        // unevaluated rather than filled with a number the model cannot support.
        val inertMass = mission.payloadMassKg
        val m0 = inertMass * mr
        val mp = m0 - inertMass
        val sane = mr.isFinite && mr <= MaxMassRatio && m0.isFinite
        val why =
          if t.powerBasis == PowerBasis.ReactorThermal then
            "nuclear thermal: power-limited transfer model does not apply, trip time not evaluated"
          else if mission.powerAvailableW.isEmpty then "mission states no available power"
          else "row lacks one of thrust, Isp, power or efficiency"

        ComparisonResult(
          runId = runId,
          producer = producer,
          missionId = mission.missionId,
          thrusterId = t.thrusterId,
          nThrusters = None,
          exhaustVelocityMS = Some(ve),
          massRatio = Some(mr),
          propellantMassFraction = Some(zeta),
          propellantMassKg = Some(mp),
          initialMassKg = Some(m0),
          powerPlantMassKg = None,
          thrustTotalN = t.thrustN,
          powerTotalW = None,
          tripTimeDays = None,
          meetsTimeConstraint = None,
          feasible = sane,
          alphaKgPerKW = None,
          notes = s"$why; engine dry mass excluded, initial mass is payload times mass ratio"
        )
    }

  def runAll(
      missions: Vector[Mission],
      thrusters: Vector[Thruster],
      runId: String,
      producer: String
  ): Vector[ComparisonResult] =
    for
      m <- missions
      t <- thrusters
      r <- compare(m, t, runId, producer)
    yield r
