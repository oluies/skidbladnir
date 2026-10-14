import Mathlib

/-!
# Formal statements of the propulsion relations

This file states the relations the comparison pipeline uses and proves the facts the
comparison relies on. The definitions correspond one for one with the implementations in
`scala/pipeline/src/propulsion/Physics.scala` and `julia/Propulsion/src/Propulsion.jl`; the
name of each Lean declaration is cited in a comment at the corresponding function there.

Everything is over `ℝ`. The headline result is `propellantMassFraction_mem_Ico`: the
propellant mass fraction lies in `[0, 1)` for any non-negative delta-v and positive exhaust
velocity, so a finite initial mass always exists. The strictness of the upper bound is what
makes the comparison meaningful, and it is what the floating-point implementations lose at
extreme delta-v (see the saturation test in `julia/Propulsion/test/runtests.jl`).
-/

namespace Propulsion

noncomputable section

open Real

/-! ## Constants -/

/-- Standard gravity, the constant that defines specific impulse in seconds. -/
def g₀ : ℝ := 9.80665

theorem g₀_pos : 0 < g₀ := by unfold g₀; norm_num

/-! ## Exhaust velocity -/

/-- Exhaust velocity from specific impulse, `ve = g₀ * Isp`. -/
def exhaustVelocity (isp : ℝ) : ℝ := g₀ * isp

/-- Specific impulse from exhaust velocity. -/
def specificImpulse (ve : ℝ) : ℝ := ve / g₀

theorem specificImpulse_exhaustVelocity (isp : ℝ) :
    specificImpulse (exhaustVelocity isp) = isp := by
  unfold specificImpulse exhaustVelocity
  field_simp [ne_of_gt g₀_pos]

theorem exhaustVelocity_pos {isp : ℝ} (h : 0 < isp) : 0 < exhaustVelocity isp :=
  mul_pos g₀_pos h

theorem exhaustVelocity_lt_exhaustVelocity {isp₁ isp₂ : ℝ} (h : isp₁ < isp₂) :
    exhaustVelocity isp₁ < exhaustVelocity isp₂ := by
  unfold exhaustVelocity
  exact mul_lt_mul_of_pos_left h g₀_pos

/-! ## The Tsiolkovsky relation -/

/-- Tsiolkovsky mass ratio, `m₀ / m_f = exp (Δv / ve)`. -/
def massRatio (Δv ve : ℝ) : ℝ := exp (Δv / ve)

theorem massRatio_pos (Δv ve : ℝ) : 0 < massRatio Δv ve := exp_pos _

theorem massRatio_ne_zero (Δv ve : ℝ) : massRatio Δv ve ≠ 0 := ne_of_gt (massRatio_pos Δv ve)

theorem massRatio_zero (ve : ℝ) : massRatio 0 ve = 1 := by
  unfold massRatio; simp

/-- With a positive delta-v the mass ratio strictly exceeds one. -/
theorem one_lt_massRatio {Δv ve : ℝ} (hΔv : 0 < Δv) (hve : 0 < ve) : 1 < massRatio Δv ve := by
  unfold massRatio
  rw [show (1 : ℝ) = exp 0 by simp]
  exact exp_lt_exp.mpr (div_pos hΔv hve)

/-! ## Mass fraction -/

/-- Propellant mass fraction, `m_p / m₀ = 1 - exp (-(Δv / ve))`. -/
def propellantMassFraction (Δv ve : ℝ) : ℝ := 1 - exp (-(Δv / ve))

/-- The mass fraction written through the mass ratio, `ζ = 1 - 1 / MR`. -/
theorem propellantMassFraction_eq_one_sub_inv_massRatio (Δv ve : ℝ) :
    propellantMassFraction Δv ve = 1 - 1 / massRatio Δv ve := by
  unfold propellantMassFraction massRatio
  rw [exp_neg, one_div]

/-- **The upper bound the comparison relies on.**

The propellant mass fraction is strictly below one for every delta-v and every exhaust
velocity, with no hypotheses at all, because `exp` is strictly positive everywhere. This is
what guarantees that a finite initial mass exists for any mission. -/
theorem propellantMassFraction_lt_one (Δv ve : ℝ) : propellantMassFraction Δv ve < 1 := by
  unfold propellantMassFraction
  have h : 0 < exp (-(Δv / ve)) := exp_pos _
  linarith

theorem propellantMassFraction_nonneg {Δv ve : ℝ} (hΔv : 0 ≤ Δv) (hve : 0 < ve) :
    0 ≤ propellantMassFraction Δv ve := by
  unfold propellantMassFraction
  have h : exp (-(Δv / ve)) ≤ 1 := by
    rw [show (1 : ℝ) = exp 0 by simp]
    exact exp_le_exp.mpr (by have := div_nonneg hΔv (le_of_lt hve); linarith)
  linarith

theorem propellantMassFraction_pos {Δv ve : ℝ} (hΔv : 0 < Δv) (hve : 0 < ve) :
    0 < propellantMassFraction Δv ve := by
  unfold propellantMassFraction
  have h : exp (-(Δv / ve)) < 1 := by
    rw [show (1 : ℝ) = exp 0 by simp]
    exact exp_lt_exp.mpr (by have := div_pos hΔv hve; linarith)
  linarith

/-- **The mass-fraction inequality used in the comparison.**

For a non-negative delta-v and a positive exhaust velocity the propellant mass fraction
lies in `[0, 1)`. The upper bound is strict. -/
theorem propellantMassFraction_mem_Ico {Δv ve : ℝ} (hΔv : 0 ≤ Δv) (hve : 0 < ve) :
    propellantMassFraction Δv ve ∈ Set.Ico (0 : ℝ) 1 :=
  ⟨propellantMassFraction_nonneg hΔv hve, propellantMassFraction_lt_one Δv ve⟩

/-- With a strictly positive delta-v the fraction lies in the open interval. -/
theorem propellantMassFraction_mem_Ioo {Δv ve : ℝ} (hΔv : 0 < Δv) (hve : 0 < ve) :
    propellantMassFraction Δv ve ∈ Set.Ioo (0 : ℝ) 1 :=
  ⟨propellantMassFraction_pos hΔv hve, propellantMassFraction_lt_one Δv ve⟩

theorem propellantMassFraction_zero (ve : ℝ) : propellantMassFraction 0 ve = 0 := by
  unfold propellantMassFraction; simp

/-! ## Monotonicity, which is what justifies ranking candidates -/

/-- A larger delta-v needs a larger propellant mass fraction. -/
theorem propellantMassFraction_lt_of_deltaV_lt {Δv₁ Δv₂ ve : ℝ} (hve : 0 < ve)
    (h : Δv₁ < Δv₂) :
    propellantMassFraction Δv₁ ve < propellantMassFraction Δv₂ ve := by
  unfold propellantMassFraction
  have hdiv : Δv₁ / ve < Δv₂ / ve := div_lt_div_of_pos_right h hve
  have : exp (-(Δv₂ / ve)) < exp (-(Δv₁ / ve)) := exp_lt_exp.mpr (by linarith)
  linarith

/-- A larger exhaust velocity needs a smaller propellant mass fraction. This is the fact
that lets the comparison rank candidates by specific impulse. -/
theorem propellantMassFraction_lt_of_exhaustVelocity_lt {Δv ve₁ ve₂ : ℝ} (hΔv : 0 < Δv)
    (hve₁ : 0 < ve₁) (h : ve₁ < ve₂) :
    propellantMassFraction Δv ve₂ < propellantMassFraction Δv ve₁ := by
  unfold propellantMassFraction
  have hdiv : Δv / ve₂ < Δv / ve₁ := div_lt_div_of_pos_left hΔv hve₁ h
  have : exp (-(Δv / ve₁)) < exp (-(Δv / ve₂)) := exp_lt_exp.mpr (by linarith)
  linarith

/-- Stated on specific impulse, which is how the dataset records it. -/
theorem propellantMassFraction_lt_of_isp_lt {Δv isp₁ isp₂ : ℝ} (hΔv : 0 < Δv)
    (hisp₁ : 0 < isp₁) (h : isp₁ < isp₂) :
    propellantMassFraction Δv (exhaustVelocity isp₂)
      < propellantMassFraction Δv (exhaustVelocity isp₁) :=
  propellantMassFraction_lt_of_exhaustVelocity_lt hΔv (exhaustVelocity_pos hisp₁)
    (exhaustVelocity_lt_exhaustVelocity h)

/-! ## Vehicle masses -/

/-- Initial mass needed to deliver `mf` through `Δv`. -/
def initialMass (mf Δv ve : ℝ) : ℝ := mf * massRatio Δv ve

/-- Propellant mass needed to deliver `mf` through `Δv`. -/
def propellantMass (mf Δv ve : ℝ) : ℝ := initialMass mf Δv ve - mf

theorem initialMass_pos {mf : ℝ} (hmf : 0 < mf) (Δv ve : ℝ) : 0 < initialMass mf Δv ve :=
  mul_pos hmf (massRatio_pos Δv ve)

/-- The initial mass always exceeds the delivered mass when the delta-v is positive. -/
theorem lt_initialMass {mf Δv ve : ℝ} (hmf : 0 < mf) (hΔv : 0 < Δv) (hve : 0 < ve) :
    mf < initialMass mf Δv ve := by
  unfold initialMass
  nth_rewrite 1 [show mf = mf * 1 by ring]
  exact mul_lt_mul_of_pos_left (one_lt_massRatio hΔv hve) hmf

theorem propellantMass_pos {mf Δv ve : ℝ} (hmf : 0 < mf) (hΔv : 0 < Δv) (hve : 0 < ve) :
    0 < propellantMass mf Δv ve := by
  unfold propellantMass
  have := lt_initialMass hmf hΔv hve
  linarith

/-- The propellant mass is strictly less than the initial mass: the vehicle is never all
propellant. This is the mass-fraction bound restated in kilograms. -/
theorem propellantMass_lt_initialMass {mf Δv ve : ℝ} (hmf : 0 < mf) :
    propellantMass mf Δv ve < initialMass mf Δv ve := by
  unfold propellantMass
  linarith

/-- The mass fraction really is the propellant mass over the initial mass. -/
theorem propellantMass_div_initialMass {mf : ℝ} (hmf : mf ≠ 0) (Δv ve : ℝ) :
    propellantMass mf Δv ve / initialMass mf Δv ve = propellantMassFraction Δv ve := by
  have hexp : exp (Δv / ve) ≠ 0 := exp_ne_zero _
  unfold propellantMass initialMass massRatio propellantMassFraction
  rw [exp_neg]
  field_simp

/-! ## Power, thrust and specific impulse -/

/-- Electrical input power for a given thrust, `P = T * ve / (2 η)`. -/
def inputPower (T ve η : ℝ) : ℝ := T * ve / (2 * η)

/-- Thrust available from a given electrical power, `T = 2 η P / ve`. -/
def thrustFromPower (P ve η : ℝ) : ℝ := 2 * η * P / ve

/-- The power relation written on specific impulse, which is how datasheets quote it.
This is the identity checked in SQL by `v_thruster_consistency`. -/
theorem power_thrust_isp (T isp η : ℝ) :
    inputPower T (exhaustVelocity isp) η = T * g₀ * isp / (2 * η) := by
  unfold inputPower exhaustVelocity
  ring

/-- Power and thrust determine each other. -/
theorem thrustFromPower_inputPower {ve η : ℝ} (hve : ve ≠ 0) (hη : η ≠ 0) (T : ℝ) :
    thrustFromPower (inputPower T ve η) ve η = T := by
  unfold thrustFromPower inputPower
  field_simp

theorem inputPower_thrustFromPower {ve η : ℝ} (hve : ve ≠ 0) (hη : η ≠ 0) (P : ℝ) :
    inputPower (thrustFromPower P ve η) ve η = P := by
  unfold thrustFromPower inputPower
  field_simp

/-- Propellant mass flow rate, `ṁ = T / ve`. -/
def massFlow (T ve : ℝ) : ℝ := T / ve

theorem massFlow_thrustFromPower {ve η : ℝ} (hve : ve ≠ 0) (P : ℝ) :
    massFlow (thrustFromPower P ve η) ve = 2 * η * P / ve ^ 2 := by
  unfold massFlow thrustFromPower
  field_simp

/-! ## Power-limited transfer time -/

/-- Thrusting time for a power-limited vehicle, `t = m_p ve² / (2 η P)`. -/
def transferTime (mp ve η P : ℝ) : ℝ := mp * ve ^ 2 / (2 * η * P)

/-- The transfer time is the propellant mass divided by the mass flow rate. -/
theorem transferTime_eq_propellantMass_div_massFlow {ve η P : ℝ} (hve : ve ≠ 0) (hη : η ≠ 0)
    (hP : P ≠ 0) (mp : ℝ) :
    transferTime mp ve η P = mp / massFlow (thrustFromPower P ve η) ve := by
  rw [massFlow_thrustFromPower hve]
  unfold transferTime
  field_simp

/-- Doubling the available power halves the thrusting time. -/
theorem transferTime_double_power {ve η P : ℝ} (hve : ve ≠ 0) (hη : η ≠ 0) (hP : P ≠ 0)
    (mp : ℝ) :
    transferTime mp ve η (2 * P) = transferTime mp ve η P / 2 := by
  unfold transferTime
  field_simp

/-- Transfer time is strictly decreasing in available power. -/
theorem transferTime_lt_of_power_lt {mp ve η P₁ P₂ : ℝ} (hmp : 0 < mp) (hve : ve ≠ 0)
    (hη : 0 < η) (hP₁ : 0 < P₁) (h : P₁ < P₂) :
    transferTime mp ve η P₂ < transferTime mp ve η P₁ := by
  unfold transferTime
  have hve2 : 0 < ve ^ 2 := by positivity
  have hnum : 0 < mp * ve ^ 2 := by positivity
  exact div_lt_div_of_pos_left hnum (by positivity) (by nlinarith)

end

end Propulsion
