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
}
