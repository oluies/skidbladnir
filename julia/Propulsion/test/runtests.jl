using Test
using Propulsion
using DataFrames

@testset "Propulsion" begin

    @testset "physics relations" begin
        @test exhaust_velocity(3000.0) ≈ 9.80665 * 3000.0
        @test specific_impulse(exhaust_velocity(4190.0)) ≈ 4190.0
        @test mass_ratio(0.0, 30000.0) ≈ 1.0
        @test mass_ratio(7000.0, 30000.0) ≈ exp(7000.0 / 30000.0)

        ve = 30000.0
        dv = 12000.0
        @test propellant_mass_fraction(dv, ve) ≈ 1 - 1 / mass_ratio(dv, ve)

        # The inequality the comparison relies on, proved in lean/Propulsion/Basic.lean.
        # Restricted to the range where Float64 can represent the result; see the
        # saturation testset below for where it stops being able to.
        for dv in (1.0, 1e3, 1e4, 1e5, 1e6)
            z = propellant_mass_fraction(dv, 30000.0)
            @test 0 < z < 1
        end
        @test propellant_mass_fraction(0.0, 30000.0) == 0.0
    end

    @testset "mass fraction saturates in Float64 well outside the useful range" begin
        # The Lean proof gives a strict inequality over the reals: the propellant mass
        # fraction is below 1 for every finite delta-v. Float64 cannot hold that. Once
        # dv/ve exceeds about 37, exp(-dv/ve) underflows the last bit and the fraction
        # rounds to exactly 1.0, which would mean an infinite mass ratio.
        ve = 30000.0
        @test propellant_mass_fraction(36 * ve, ve) < 1.0
        @test propellant_mass_fraction(1e9, ve) == 1.0

        # The comparison never gets near that. MAX_MASS_RATIO caps the vehicle at a mass
        # ratio of 1e6, which is dv/ve of about 13.8, leaving a wide margin.
        @test log(MAX_MASS_RATIO) < 36

        # Monotone in delta-v, and monotone the other way in exhaust velocity.
        zs = [propellant_mass_fraction(d, 30000.0) for d in (1e3, 5e3, 1e4, 2e4)]
        @test issorted(zs)
        zv = [propellant_mass_fraction(1e4, v) for v in (1e4, 2e4, 4e4, 8e4)]
        @test issorted(zv, rev = true)

        @test initial_mass(1000.0, 5000.0, ve) ≈ 1000.0 * mass_ratio(5000.0, ve)
        @test propellant_mass(1000.0, 5000.0, ve) ≈ initial_mass(1000.0, 5000.0, ve) - 1000.0
    end

    @testset "power, thrust and specific impulse" begin
        ve = exhaust_velocity(4190.0)
        p = input_power(0.237, ve, 0.71)
        @test thrust_from_power(p, ve, 0.71) ≈ 0.237

        # NEXT at its full-power point should reproduce roughly 6.9 kW from its own numbers.
        @test isapprox(input_power(0.237, exhaust_velocity(4190.0), 0.71), 6900.0, rtol = 0.01)

        # NSTAR at throttle level 15.
        @test isapprox(input_power(0.0927, exhaust_velocity(3127.0), 0.618), 2325.0, rtol = 0.02)

        @test mass_flow(0.0927, ve) ≈ 0.0927 / ve
    end

    @testset "power-limited transfer time" begin
        ve = exhaust_velocity(4000.0)
        eta, p, mp = 0.7, 100_000.0, 2000.0

        # Equivalent to propellant mass divided by mass flow rate.
        mdot = 2 * eta * p / ve^2
        @test transfer_time_seconds(mp, ve, eta, p) ≈ mp / mdot

        # Doubling power halves the time; doubling propellant doubles it.
        @test transfer_time_seconds(mp, ve, eta, p) ≈ 2 * transfer_time_seconds(mp, ve, eta, 2p)
        @test transfer_time_seconds(2mp, ve, eta, p) ≈ 2 * transfer_time_seconds(mp, ve, eta, p)

        @test seconds_to_days(86400.0) ≈ 1.0
    end


    @testset "tank mass model" begin
        # Calibration anchor: xenon at 150 bar and 1600 kg/m3 should land near 5 percent,
        # which is where flown xenon tankage sits.
        f_xe = tank_mass_fraction(1600.0, 150.0)
        @test 0.04 < f_xe < 0.07

        # Krypton pays twice: lower density and higher pressure.
        f_kr = tank_mass_fraction(650.0, 200.0)
        @test f_kr > f_xe
        @test f_kr / f_xe > 2.5

        # Argon is worse again.
        @test tank_mass_fraction(500.0, 300.0) > f_kr

        # Strictly decreasing in storage density, strictly increasing in pressure.
        # Lean: tankMassFraction_lt_of_density_lt, tankMassFraction_lt_of_pressure_lt.
        densities = [400.0, 650.0, 1000.0, 1600.0, 4933.0]
        @test issorted([tank_mass_fraction(r, 150.0) for r in densities], rev = true)
        pressures = [0.0, 50.0, 150.0, 300.0]
        @test issorted([tank_mass_fraction(1000.0, p) for p in pressures])

        @test_throws ArgumentError tank_mass_fraction(0.0, 150.0)

        # An unpressurised dense solid still gets a structural floor, never zero.
        @test tank_mass_fraction(4933.0, 0.0) > 0
    end

    @testset "inert mass with tankage" begin
        base, mr = 1000.0, 1.5

        # No tank gives back the base. Lean: inertMassWithTank_zero.
        @test inert_mass_with_tank(base, mr, 0.0) == base

        # The closed form solves the fixed point m_f = base + f * m_f * (MR - 1).
        # Lean: inertMassWithTank_fixed_point.
        for f in (0.0, 0.05, 0.176, 0.5)
            mf = inert_mass_with_tank(base, mr, f)
            @test mf !== nothing
            @test mf ≈ base + f * (mf * (mr - 1))
        end

        # Strictly increasing in tank fraction, and never below the base.
        # Lean: inertMassWithTank_lt_of_tankFraction_lt, le_inertMassWithTank.
        ms = [inert_mass_with_tank(base, mr, f) for f in (0.0, 0.1, 0.2, 0.4)]
        @test all(!isnothing, ms)
        @test issorted(Float64.(ms))
        @test all(m -> m >= base, Float64.(ms))

        # Past f * (MR - 1) = 1 no finite vehicle closes. Lean: the tankCloses hypothesis.
        @test inert_mass_with_tank(base, 3.0, 0.5) === nothing   # 0.5 * 2.0 == 1
        @test inert_mass_with_tank(base, 3.0, 0.6) === nothing
        @test inert_mass_with_tank(base, 3.0, 0.49) !== nothing
    end


    @testset "tank closure limit" begin
        # inert_mass_with_tank closes exactly when f < max_tank_fraction(mr).
        # Lean: tankCloses_iff_lt_max.
        for mr in (1.5, 2.2, 5.5, 6.46)
            fmax = max_tank_fraction(mr)
            @test inert_mass_with_tank(1000.0, mr, fmax * 0.99) !== nothing
            @test inert_mass_with_tank(1000.0, mr, fmax * 1.01) === nothing
        end

        # The boundary itself is not exactly representable. At f within rounding of the
        # limit the denominator is a tiny positive number rather than zero, so the model
        # returns an absurd mass instead of nothing. The Lean statement is exact over the
        # reals; Float64 is not, and the guard in practice is distance from the limit.
        for mr in (2.2, 5.5, 6.46)
            at_limit = inert_mass_with_tank(1000.0, mr, max_tank_fraction(mr))
            @test at_limit === nothing || at_limit > 1e15
        end

        # Every propellant the comparison actually uses sits far from its limit on both
        # crewed missions, so the model never operates near that boundary.
        for (rho, p_bar) in ((1600.0, 150.0), (650.0, 200.0), (70.85, 1.0), (500.0, 300.0))
            f = tank_mass_fraction(rho, p_bar)
            @test f < 0.5 * max_tank_fraction(2.4)   # nominal Mars, worst NTP mass ratio
        end
        # A larger mass ratio tolerates a smaller tank fraction.
        # Lean: tankCloses_bound_antitone.
        @test issorted([max_tank_fraction(mr) for mr in (1.5, 2.5, 4.0, 6.5)], rev = true)

        # No propellant needed, so tankage is unconstrained.
        @test max_tank_fraction(1.0) == Inf
        @test max_tank_fraction(0.5) == Inf

        # critical_structural_floor inverts the tank relation: at exactly that kappa the
        # fraction equals the closure limit.
        rho, p_bar = 70.85, 1.0
        for mr in (2.21, 5.47, 6.46)
            kcrit = critical_structural_floor(rho, p_bar, mr)
            f_at_crit = 1.5 * p_bar * 1e5 / (rho * TANK_SPECIFIC_STRENGTH_J_PER_KG) + kcrit / rho
            @test isapprox(f_at_crit, max_tank_fraction(mr), rtol = 1e-12)
        end
        @test_throws ArgumentError critical_structural_floor(0.0, 1.0, 2.0)

        # Hydrogen's tank is dominated by the structural floor, xenon's by pressure. That is
        # why the wall-strength sweep moves the electric cases and barely touches NTP.
        h2_pressure = 1.5 * 1e5 / (70.85 * TANK_SPECIFIC_STRENGTH_J_PER_KG)
        h2_floor = TANK_STRUCTURAL_FLOOR_KG_PER_M3 / 70.85
        @test h2_floor > 10 * h2_pressure

        xe_pressure = 1.5 * 150e5 / (1600.0 * TANK_SPECIFIC_STRENGTH_J_PER_KG)
        xe_floor = TANK_STRUCTURAL_FLOOR_KG_PER_M3 / 1600.0
        @test xe_pressure > 5 * xe_floor

        # The fast Mars mission is where the NTP case is fragile: Phoebus-2A at MR 6.46
        # stops closing below twice the assumed structural floor of 8 kg/m3.
        kcrit_fast = critical_structural_floor(70.85, 1.0, 6.458)
        @test TANK_STRUCTURAL_FLOOR_KG_PER_M3 < kcrit_fast < 2 * TANK_STRUCTURAL_FLOOR_KG_PER_M3

        # The high-energy probe is the tightest case in the study and sits the wrong side of
        # the line: at mass ratios near 9.6 to 12 the tolerable floor falls below the 8 kg/m3
        # assumed, so the nuclear thermal rows do not close there at all. The margin is four
        # percent for the best of the three, which is why those rows are a statement about
        # the assumption rather than a physical conclusion.
        for isp in (900.0, 845.0, 820.0)
            mr = mass_ratio(20000.0, exhaust_velocity(isp))
            @test critical_structural_floor(70.85, 1.0, mr) < TANK_STRUCTURAL_FLOOR_KG_PER_M3
            @test inert_mass_with_tank(500.0, mr, tank_mass_fraction(70.85, 1.0)) === nothing
        end
        # The best engine misses by a small margin rather than a large one.
        mr_best = mass_ratio(20000.0, exhaust_velocity(900.0))
        @test critical_structural_floor(70.85, 1.0, mr_best) >
              0.9 * TANK_STRUCTURAL_FLOOR_KG_PER_M3
    end

    con = connect_db()
    try
        thrusters = load_thrusters(con)
        missions = load_missions(con)
        propellants = load_propellants(con)

        @testset "dataset loads" begin
            @test nrow(thrusters) >= 15
            @test count(s -> s in ("flown", "ground_tested"), thrusters.status) >= 15
            @test nrow(missions) == 4
            @test nrow(propellants) >= 5
            # Absent dry mass must stay absent rather than arrive as zero.
            unknown = thrusters[thrusters.mass_basis .== "unknown", :]
            @test all(ismissing, unknown.mass_kg)
        end

        @testset "delta-v budgets sum to the mission total" begin
            for m in eachrow(missions)
                budget = delta_v_budget(m.mission_id)
                @test sum(values(budget)) ≈ m.delta_v_m_s
                @test all(>(0), values(budget))
            end
        end

        results = run_comparison(con)

        @testset "comparison invariants" begin
            @test nrow(results) == count(!ismissing, thrusters.isp_s) * nrow(missions)

            for r in eachrow(results)
                m = first(missions[missions.mission_id .== r.mission_id, :])
                @test 0 < r.propellant_mass_fraction < 1
                @test r.mass_ratio >= 1
                if ismissing(r.initial_mass_kg)
                    # The only way a row has no initial mass is tankage divergence, and such
                    # a row must be reported infeasible rather than silently dropped.
                    @test !r.feasible
                    @test occursin("tankage diverges", r.notes)
                    @test ismissing(r.propellant_mass_kg)
                else
                    @test r.initial_mass_kg > m.payload_mass_kg
                    @test r.propellant_mass_kg < r.initial_mass_kg
                    # Initial mass is inert plus propellant, and the tank is inside the inert.
                    @test r.tank_mass_kg >= 0
                    @test isapprox(r.tank_mass_kg,
                                   r.tank_mass_fraction * r.propellant_mass_kg, rtol = 1e-9)
                end
            end

            # Nuclear thermal rows must not carry a power-limited trip time.
            ntp = thrusters[thrusters.power_basis .== "reactor_thermal", :].thruster_id
            ntp_rows = results[in.(results.thruster_id, Ref(ntp)), :]
            @test nrow(ntp_rows) > 0
            @test all(ismissing, ntp_rows.trip_time_days)

            # Raising specific impulse must cut propellant on a fixed mission.
            m = first(eachrow(missions[missions.mission_id .== "probe500_nominal", :]))
            lo = compare_one(m, first(eachrow(thrusters[thrusters.thruster_id .== "spt100", :])))
            hi = compare_one(m, first(eachrow(thrusters[thrusters.thruster_id .== "next_pm1", :])))
            @test hi.propellant_mass_fraction < lo.propellant_mass_fraction
        end

        @testset "agreement with the Scala pipeline" begin
            # Both pipelines implement the same relations independently. Where the Scala run
            # has written rows, the two must agree to floating-point noise. This is the check
            # that makes the duplication worth having.
            scala = query_db(con, """
                SELECT mission_id, thruster_id, initial_mass_kg, propellant_mass_kg,
                       tank_mass_kg, trip_time_days, n_thrusters, feasible
                FROM results WHERE producer = 'scala'
            """)
            if nrow(scala) == 0
                @info "no Scala rows present; run the Scala compare task to enable this check"
                @test true
            else
                joined = innerjoin(results, scala,
                                   on = [:mission_id, :thruster_id], makeunique = true)
                @test nrow(joined) == nrow(scala)
                approx_or_both_missing(a, b) =
                    (ismissing(a) && ismissing(b)) ||
                    (!ismissing(a) && !ismissing(b) && isapprox(a, b, rtol = 1e-9))
                for r in eachrow(joined)
                    @test approx_or_both_missing(r.initial_mass_kg, r.initial_mass_kg_1)
                    @test approx_or_both_missing(r.propellant_mass_kg, r.propellant_mass_kg_1)
                    @test approx_or_both_missing(r.tank_mass_kg, r.tank_mass_kg_1)
                    @test approx_or_both_missing(r.trip_time_days, r.trip_time_days_1)
                    @test isequal(r.n_thrusters, r.n_thrusters_1)
                    @test r.feasible == r.feasible_1
                end
            end
        end


        @testset "tankage reverses the krypton matched pairs" begin
            # Without a tank model krypton wins on initial mass in both matched pairs.
            # Charging the tank against the vehicle reverses both, which is the result the
            # tank model was added to settle. Computed from `results` rather than queried,
            # so the check does not depend on whether this producer's rows are already in
            # the database.
            probe = results[results.mission_id .== "probe500_nominal", :]
            by_id = Dict(r.thruster_id => r for r in eachrow(probe))
            for (kr, xe) in (("bht1500c_kr", "bht1500c_xe"),
                             ("spt100_kr_nom", "spt100_xe_nakles"))
                @test haskey(by_id, kr) && haskey(by_id, xe)
                @test by_id[xe].initial_mass_kg < by_id[kr].initial_mass_kg
                # The krypton tank is the reason, not the propellant mass.
                @test by_id[kr].tank_mass_kg > 2 * by_id[xe].tank_mass_kg
            end
        end

        @testset "results round-trip through DuckDB" begin
            n = write_results!(con, results)
            @test n == nrow(results)
            back = query_db(con,
                "SELECT count(*) AS n FROM results WHERE producer = 'julia'")
            @test back.n[1] == nrow(results)
        end
    finally
        close_db(con)
    end
end
