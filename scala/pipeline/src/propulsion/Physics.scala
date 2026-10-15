package propulsion

/** The closed-form relations the comparison rests on.
  *
  * Each function here corresponds to a statement formalised in `lean/Propulsion/`. The
  * correspondence is named in the comment above the function so the two can be kept in step.
  *
  * Units are SI throughout: thrust in N, velocity in m/s, power in W, mass in kg, time in s.
  * Specific impulse is in seconds, which is the one non-SI quantity in common use.
  */
object Physics {

  /** Standard gravity, the constant that defines specific impulse in seconds. */
  val g0: Double = 9.80665

  /** Exhaust velocity from specific impulse. Lean: `Propulsion.exhaustVelocity`. */
  def exhaustVelocity(ispSeconds: Double): Double = g0 * ispSeconds

  /** Specific impulse from exhaust velocity, the inverse of [[exhaustVelocity]]. */
  def specificImpulse(exhaustVelocity: Double): Double = exhaustVelocity / g0

  /** Tsiolkovsky mass ratio m0/mf = exp(dv / ve). Lean: `Propulsion.massRatio`, `one_lt_massRatio`. */
  def massRatio(deltaV: Double, exhaustVelocity: Double): Double =
    math.exp(deltaV / exhaustVelocity)

  /** Propellant mass fraction mp/m0 = 1 - exp(-dv/ve), equal to 1 - 1/MR.
    *
    * Lean: `Propulsion.propellantMassFraction` and `propellantMassFraction_mem_Ico`, which is the
    * inequality the comparison uses: the fraction is strictly below 1 for any finite delta-v,
    * so a finite initial mass always exists.
    */
  def propellantMassFraction(deltaV: Double, exhaustVelocity: Double): Double =
    1.0 - math.exp(-deltaV / exhaustVelocity)

  /** Initial mass needed to deliver `finalMass` through `deltaV`. */
  def initialMass(finalMass: Double, deltaV: Double, exhaustVelocity: Double): Double =
    finalMass * massRatio(deltaV, exhaustVelocity)

  /** Propellant mass needed to deliver `finalMass` through `deltaV`. */
  def propellantMass(finalMass: Double, deltaV: Double, exhaustVelocity: Double): Double =
    initialMass(finalMass, deltaV, exhaustVelocity) - finalMass

  /** Electrical input power for a given thrust, from P = T * ve / (2 * eta).
    *
    * Lean: `Propulsion.power_thrust_isp`. This is the relation that ties the three quoted numbers on a
    * thruster datasheet together, and the one v_thruster_consistency checks in SQL.
    */
  def inputPower(thrustN: Double, exhaustVelocity: Double, efficiency: Double): Double =
    thrustN * exhaustVelocity / (2.0 * efficiency)

  /** Thrust available from a given electrical power, the inverse of [[inputPower]]. */
  def thrustFromPower(powerW: Double, exhaustVelocity: Double, efficiency: Double): Double =
    2.0 * efficiency * powerW / exhaustVelocity

  /** Propellant mass flow rate, mdot = T / ve. */
  def massFlow(thrustN: Double, exhaustVelocity: Double): Double = thrustN / exhaustVelocity

  /** Thrusting time for a power-limited vehicle: t = mp * ve^2 / (2 * eta * P).
    *
    * This is the burn duration, not a trajectory solution. It is a lower bound on trip time
    * for a continuously thrusting transfer and is used here as the comparison metric.
    * Lean: `Propulsion.transferTime` and `transferTime_eq_propellantMass_div_massFlow`.
    */
  def transferTimeSeconds(
      propellantMassKg: Double,
      exhaustVelocity: Double,
      efficiency: Double,
      powerW: Double
  ): Double =
    propellantMassKg * exhaustVelocity * exhaustVelocity / (2.0 * efficiency * powerW)

  val secondsPerDay: Double = 86400.0

  def secondsToDays(seconds: Double): Double = seconds / secondsPerDay

  // ------------------------------------------------------------------ tankage

  /** Effective specific strength of the tank wall, J/kg.
    *
    * A thin-walled sphere holding pressure P over volume V needs a wall of mass
    * 1.5 * P * V / (sigma/rho). The value here is well below raw carbon fibre because it has
    * to absorb the liner, bosses, mounts and safety factor the ideal relation ignores. It is
    * calibrated so xenon at 150 bar and 1600 kg/m3 lands near 5% of propellant mass, which is
    * where flown xenon tankage sits; every other propellant follows from that one anchor.
    */
  val tankSpecificStrengthJPerKg: Double = 2.8125e5

  /** Structural floor on tank mass, kg per m3 of propellant volume. Keeps an unpressurised
    * store from coming out weightless and carries most of a cryogenic tank's mass.
    */
  val tankStructuralFloorKgPerM3: Double = 8.0

  /** Tank dry mass as a fraction of the propellant it holds:
    * f = 1.5 * P / (rho * psi) + kappa / rho.
    *
    * Both terms scale inversely with storage density, which is the whole of krypton's
    * problem: it stores at about 40% of xenon's density and at a higher pressure, so it pays
    * twice. Lean: `Propulsion.tankMassFraction`.
    */
  def tankMassFraction(storageDensityKgM3: Double, storagePressureBar: Double): Double =
    require(storageDensityKgM3 > 0, s"storage density must be positive, got $storageDensityKgM3")
    val pPa = storagePressureBar * 1.0e5
    1.5 * pPa / (storageDensityKgM3 * tankSpecificStrengthJPerKg) +
      tankStructuralFloorKgPerM3 / storageDensityKgM3

  /** Solve for the inert mass once the tank is charged against it.
    *
    * The tank is sized by the propellant it holds and the propellant by the inert mass it
    * pushes, so m_f = base + f * m_f * (MR - 1), giving m_f = base / (1 - f * (MR - 1)).
    *
    * None when f * (MR - 1) >= 1. That is a physical limit rather than a numerical guard:
    * past it the tank outweighs what the propellant buys back and no finite vehicle closes.
    * Lean: `Propulsion.inertMassWithTank_pos`.
    */
  def inertMassWithTank(baseInertKg: Double, massRatio: Double, tankFraction: Double): Option[Double] =
    val denom = 1.0 - tankFraction * (massRatio - 1.0)
    if denom > 0.0 then Some(baseInertKg / denom) else None
}
