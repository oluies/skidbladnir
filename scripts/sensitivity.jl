#!/usr/bin/env julia
#
# Sensitivity of the ranking to the three assumptions the literature does not pin down:
# power plant specific mass (alpha), thruster plus power-processing dry mass, and the tank
# wall's effective specific strength.
#
#     julia --project=julia/Propulsion scripts/sensitivity.jl
#
# Nothing here is written to the database. The comparison in the results table uses the
# baseline values; this script exists to show how much weight those values carry.

using Propulsion
using DataFrames
using Printf

con = connect_db()

thrusters = load_thrusters(con)
missions = load_missions(con)
propellants = load_propellants(con)

ismiss(x) = x === missing || (x isa Real && !isfinite(x))

"Tank fraction per propellant at a given effective wall specific strength."
function tank_fractions(psi_scale)
    Dict(
        p.propellant => begin
            rho = p.storage_density_kg_m3
            p_pa = (ismiss(p.storage_pressure_bar) ? 0.0 : p.storage_pressure_bar) * 1.0e5
            1.5 * p_pa / (rho * TANK_SPECIFIC_STRENGTH_J_PER_KG * psi_scale) +
                TANK_STRUCTURAL_FLOOR_KG_PER_M3 / rho
        end
        for p in eachrow(propellants) if !ismiss(p.storage_density_kg_m3)
    )
end

"Recompute one mission under explicit alpha, thruster specific mass and tank strength."
function rank(mission, thrusters; alpha, tsm, psi_scale = 1.0, topn = 5)
    fracs = tank_fractions(psi_scale)
    rows = NamedTuple[]
    for t in eachrow(thrusters)
        (t.power_basis == "electrical_input" && !ismiss(t.isp_s) &&
         !ismiss(t.thrust_mN) && !ismiss(t.input_power_W) &&
         !ismiss(t.efficiency)) || continue
        ve = exhaust_velocity(t.isp_s)
        mr = mass_ratio(mission.delta_v_m_s, ve)
        n = max(1, Int(floor(mission.power_available_W / t.input_power_W)))
        p_total = n * t.input_power_W
        unit = ismiss(t.mass_kg) ? tsm * t.input_power_W / 1000 : t.mass_kg
        base = mission.payload_mass_kg + alpha * mission.power_available_W / 1000 + n * unit
        f = get(fracs, t.propellant, 0.0)
        inert = inert_mass_with_tank(base, mr, f)
        inert === nothing && continue           # tankage diverges, no closed vehicle
        mp = inert * (mr - 1)
        m0 = inert * mr
        days = seconds_to_days(transfer_time_seconds(mp, ve, t.efficiency, p_total))
        ok = ismiss(mission.max_trip_time_days) || days <= mission.max_trip_time_days
        ok || continue
        push!(rows, (name = t.name, m0 = m0, mp = mp, tank = f * mp, days = days, n = n))
    end
    isempty(rows) && return DataFrame()
    first(sort(DataFrame(rows), :m0), topn)
end

function show_case(mission, label, r)
    println("\n", label)
    if nrow(r) == 0
        println("   (nothing feasible)")
        return
    end
    for row in eachrow(r)
        @printf("   %-28s m0 %10.0f kg   mp %9.0f kg   tank %8.0f kg   %7.1f d   N=%d\n",
                row.name, row.m0, row.mp, row.tank, row.days, row.n)
    end
end

try
    for mid in ("mars_crew_nominal", "probe500_nominal")
        mission = first(eachrow(missions[missions.mission_id .== mid, :]))
        println("\n", "="^92)
        println(mission.name, "   payload ", Int(mission.payload_mass_kg), " kg, dv ",
                Int(mission.delta_v_m_s), " m/s, power ",
                Int(mission.power_available_W / 1000), " kW")
        println("="^92)

        base_alpha = alpha_for_source(mission.power_source)

        for alpha in (base_alpha / 2, base_alpha, base_alpha * 2)
            show_case(mission,
                      @sprintf("alpha = %.0f kg/kW, thruster %.0f kg/kW, tank psi x1.0",
                               alpha, THRUSTER_SPECIFIC_MASS_KG_PER_KW),
                      rank(mission, thrusters; alpha = alpha,
                           tsm = THRUSTER_SPECIFIC_MASS_KG_PER_KW))
        end

        for tsm in (2.0, 5.0, 10.0)
            show_case(mission,
                      @sprintf("alpha = %.0f kg/kW, thruster %.0f kg/kW, tank psi x1.0",
                               base_alpha, tsm),
                      rank(mission, thrusters; alpha = base_alpha, tsm = tsm))
        end

        # psi_scale multiplies the wall strength, so it scales the pressure term only. The
        # kappa/rho structural floor is untouched, and unpressurised stores do not move at
        # all: at psi x2 xenon goes 5.5 to 3.0 percent and argon 33.6 to 17.6, while lithium
        # stays at 1.5 and iodine at 0.2.
        for psi in (0.5, 1.0, 2.0)
            show_case(mission,
                      @sprintf("alpha = %.0f kg/kW, thruster %.0f kg/kW, tank psi x%.1f",
                               base_alpha, THRUSTER_SPECIFIC_MASS_KG_PER_KW, psi),
                      rank(mission, thrusters; alpha = base_alpha,
                           tsm = THRUSTER_SPECIFIC_MASS_KG_PER_KW, psi_scale = psi))
        end
    end
finally
    close_db(con)
end
