#!/usr/bin/env julia
#
# Sensitivity of the ranking to the two assumptions the literature does not pin down:
# power plant specific mass (alpha) and thruster plus power-processing dry mass.
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

"Recompute one mission under explicit alpha and thruster specific mass."
function rank(mission, thrusters; alpha, tsm, topn = 5)
    rows = NamedTuple[]
    for t in eachrow(thrusters)
        (t.power_basis == "electrical_input" && !ismissing(t.isp_s) &&
         !ismissing(t.thrust_mN) && !ismissing(t.input_power_W) &&
         !ismissing(t.efficiency)) || continue
        ve = exhaust_velocity(t.isp_s)
        mr = mass_ratio(mission.delta_v_m_s, ve)
        n = max(1, Int(floor(mission.power_available_W / t.input_power_W)))
        p_total = n * t.input_power_W
        unit = ismissing(t.mass_kg) ? tsm * t.input_power_W / 1000 : t.mass_kg
        inert = mission.payload_mass_kg + alpha * mission.power_available_W / 1000 + n * unit
        m0 = inert * mr
        mp = m0 - inert
        days = seconds_to_days(transfer_time_seconds(mp, ve, t.efficiency, p_total))
        ok = ismissing(mission.max_trip_time_days) || days <= mission.max_trip_time_days
        ok || continue
        push!(rows, (name = t.name, m0 = m0, mp = mp, days = days, n = n))
    end
    first(sort(DataFrame(rows), :m0), topn)
end

try
    for mid in ("mars_crew_nominal", "probe500_nominal")
        mission = first(eachrow(missions[missions.mission_id .== mid, :]))
        println("\n", "="^78)
        println(mission.name, "   payload ", Int(mission.payload_mass_kg), " kg, dv ",
                Int(mission.delta_v_m_s), " m/s, power ",
                Int(mission.power_available_W / 1000), " kW")
        println("="^78)

        base_alpha = alpha_for_source(mission.power_source)
        for alpha in (base_alpha / 2, base_alpha, base_alpha * 2)
            r = rank(mission, thrusters; alpha = alpha, tsm = THRUSTER_SPECIFIC_MASS_KG_PER_KW)
            @printf("\nalpha = %.0f kg/kW, thruster %.0f kg/kW\n",
                    alpha, THRUSTER_SPECIFIC_MASS_KG_PER_KW)
            for row in eachrow(r)
                @printf("   %-28s m0 %10.0f kg   mp %9.0f kg   %7.1f d   N=%d\n",
                        row.name, row.m0, row.mp, row.days, row.n)
            end
        end

        for tsm in (2.0, 5.0, 10.0)
            r = rank(mission, thrusters; alpha = base_alpha, tsm = tsm)
            @printf("\nalpha = %.0f kg/kW, thruster %.0f kg/kW\n", base_alpha, tsm)
            for row in eachrow(r)
                @printf("   %-28s m0 %10.0f kg   mp %9.0f kg   %7.1f d   N=%d\n",
                        row.name, row.m0, row.mp, row.days, row.n)
            end
        end
    end
finally
    close_db(con)
end
