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
                @test r.initial_mass_kg > m.payload_mass_kg
                @test 0 < r.propellant_mass_fraction < 1
                @test r.propellant_mass_kg < r.initial_mass_kg
                @test r.mass_ratio >= 1
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
                       trip_time_days, n_thrusters
                FROM results WHERE producer = 'scala'
            """)
            if nrow(scala) == 0
                @info "no Scala rows present; run the Scala compare task to enable this check"
                @test true
            else
                joined = innerjoin(results, scala,
                                   on = [:mission_id, :thruster_id], makeunique = true)
                @test nrow(joined) == nrow(scala)
                for r in eachrow(joined)
                    @test isapprox(r.initial_mass_kg, r.initial_mass_kg_1, rtol = 1e-9)
                    @test isapprox(r.propellant_mass_kg, r.propellant_mass_kg_1, rtol = 1e-9)
                    if !ismissing(r.trip_time_days) && !ismissing(r.trip_time_days_1)
                        @test isapprox(r.trip_time_days, r.trip_time_days_1, rtol = 1e-9)
                    else
                        @test ismissing(r.trip_time_days) && ismissing(r.trip_time_days_1)
                    end
                    @test isequal(r.n_thrusters, r.n_thrusters_1)
                end
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
