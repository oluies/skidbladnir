/-
Reproducible check that the results carry no `sorry`.

    cd lean && lake env lean check_axioms.lean

Each theorem should report exactly [propext, Classical.choice, Quot.sound], the three
standard axioms of Lean's logic. The appearance of `sorryAx` anywhere would mean a gap.
-/
import Propulsion.Basic

#print axioms Propulsion.propellantMassFraction_mem_Ico
#print axioms Propulsion.propellantMassFraction_mem_Ioo
#print axioms Propulsion.propellantMassFraction_lt_one
#print axioms Propulsion.propellantMassFraction_nonneg
#print axioms Propulsion.propellantMassFraction_pos
#print axioms Propulsion.propellantMassFraction_eq_one_sub_inv_massRatio
#print axioms Propulsion.propellantMassFraction_lt_of_deltaV_lt
#print axioms Propulsion.propellantMassFraction_lt_of_exhaustVelocity_lt
#print axioms Propulsion.propellantMassFraction_lt_of_isp_lt
#print axioms Propulsion.propellantMass_div_initialMass
#print axioms Propulsion.propellantMass_lt_initialMass
#print axioms Propulsion.lt_initialMass
#print axioms Propulsion.one_lt_massRatio
#print axioms Propulsion.specificImpulse_exhaustVelocity
#print axioms Propulsion.power_thrust_isp
#print axioms Propulsion.thrustFromPower_inputPower
#print axioms Propulsion.inputPower_thrustFromPower
#print axioms Propulsion.massFlow_thrustFromPower
#print axioms Propulsion.transferTime_eq_propellantMass_div_massFlow
#print axioms Propulsion.transferTime_double_power
#print axioms Propulsion.transferTime_lt_of_power_lt
