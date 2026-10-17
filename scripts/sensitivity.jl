#!/usr/bin/env julia
#
# Sensitivity of the ranking to the four assumptions the literature does not pin down:
# power plant specific mass (alpha), thruster plus power-processing dry mass, the tank
# wall's effective specific strength, and its structural floor kappa. The first three move
# by roughly a factor of two in each direction and are swept against the electric
# candidates; kappa runs from half to four times its assumed value and is swept against the
# nuclear thermal rows, where it carries 94 percent of the tank fraction.
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


# ---------------------------------------------------------------- NTP tankage
#
# The electric sweep above varies the tank wall strength, which scales the pressure term.
# That is the wrong knob for a nuclear thermal vehicle. Liquid hydrogen at 70.85 kg/m3 takes
# 94 percent of its tank fraction from the structural and insulation floor kappa/rho and only
# 6 percent from pressure, so psi barely moves it. This section sweeps kappa instead, and
# reports how close each engine sits to the closure limit f < 1/(MR-1).

"Tank fraction for a propellant at an explicit structural floor."
function tank_fraction_at(rho, p_bar, kappa)
    1.5 * p_bar * 1.0e5 / (rho * TANK_SPECIFIC_STRENGTH_J_PER_KG) + kappa / rho
end

function ntp_tank_sensitivity(missions, thrusters, propellants)
    h2 = first(eachrow(propellants[propellants.propellant .== "hydrogen", :]))
    rho, p_bar = h2.storage_density_kg_m3, h2.storage_pressure_bar
    # Select by thruster_type, not propellant: a future hydrogen electric row would need the
    # electric branch's power plant and thruster mass, which this section does not charge.
    ntp = thrusters[(thrusters.thruster_type .== "nuclear_thermal") .&
                    .!ismiss.(thrusters.isp_s), :]

    println("\n", "="^92)
    println("Nuclear thermal: sensitivity to the tank structural floor")
    println("="^92)
    kappa0 = TANK_STRUCTURAL_FLOOR_KG_PER_M3
    f0 = tank_fraction_at(rho, p_bar, kappa0)
    @printf("\nliquid hydrogen at %.2f kg/m3 and %.0f bar\n", rho, p_bar)
    @printf("  pressure term %.5f (%.1f percent of the baseline fraction)\n",
            tank_fraction_at(rho, p_bar, 0.0),
            100 * tank_fraction_at(rho, p_bar, 0.0) / f0)
    @printf("  floor term at kappa=%.0f: %.5f (%.1f percent)\n",
            kappa0, kappa0 / rho, 100 * (kappa0 / rho) / f0)
    println("\nThe floor dominates, so kappa rather than the wall strength decides this case.")

    for mid in ("mars_crew_nominal", "mars_crew_fast")
        mission = first(eachrow(missions[missions.mission_id .== mid, :]))
        println("\n", "-"^92)
        @printf("%s   payload %d kg, dv %d m/s\n",
                mission.name, Int(mission.payload_mass_kg), Int(mission.delta_v_m_s))
        println("-"^92)
        for t in eachrow(ntp)
            ve = exhaust_velocity(t.isp_s)
            mr = mass_ratio(mission.delta_v_m_s, ve)
            fmax = max_tank_fraction(mr)
            kcrit = critical_structural_floor(rho, p_bar, mr)
            # Baseline for the comparison column, computed once per engine.
            inert0 = inert_mass_with_tank(mission.payload_mass_kg, mr, f0)
            m0_base = inert0 === nothing ? nothing : inert0 * mr
            @printf("\n  %-22s Isp %4.0f s  MR %.3f   closes while f < %.4f (kappa < %.1f kg/m3)\n",
                    t.name, t.isp_s, mr, fmax, kcrit)
            for kappa in (kappa0 / 2, kappa0, kappa0 * 2, kappa0 * 4)
                f = tank_fraction_at(rho, p_bar, kappa)
                inert = inert_mass_with_tank(mission.payload_mass_kg, mr, f)
                if inert === nothing
                    @printf("     kappa %5.1f  f %.4f   does not close\n", kappa, f)
                else
                    m0 = inert * mr
                    delta = m0_base === nothing ? NaN : 100 * m0 / m0_base - 100
                    @printf("     kappa %5.1f  f %.4f   m0 %10.0f kg   tank %9.0f kg   %+6.1f%% vs kappa=%.0f\n",
                            kappa, f, m0, f * inert * (mr - 1), delta, kappa0)
                end
            end
        end
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
    ntp_tank_sensitivity(missions, thrusters, propellants)
finally
    close_db(con)
end
