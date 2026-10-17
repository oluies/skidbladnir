"""
    Propulsion

Numerical models for the propulsion comparison: delta-v budgets, mass fractions and
power-limited transfer times, read from and written back to the DuckDB file.

The relations here mirror `scala/pipeline/src/propulsion/Physics.scala` and the Lean
statements in `lean/Propulsion/`. The three implementations are kept deliberately
independent so that agreement between them is evidence rather than tautology; the
cross-check lives in `test/runtests.jl`.

Units are SI throughout: thrust N, velocity m/s, power W, mass kg, time s. Specific
impulse is in seconds, the one non-SI quantity in common use.
"""
module Propulsion

using DuckDB
using DataFrames
using Printf
using Dates

export g0,
    exhaust_velocity,
    specific_impulse,
    mass_ratio,
    propellant_mass_fraction,
    initial_mass,
    propellant_mass,
    input_power,
    thrust_from_power,
    mass_flow,
    transfer_time_seconds,
    seconds_to_days,
    delta_v_budget,
    DELTA_V_BUDGETS,
    POWER_PLANT_ALPHA_KG_PER_KW,
    DEFAULT_ALPHA_KG_PER_KW,
    alpha_for_source,
    THRUSTER_SPECIFIC_MASS_KG_PER_KW,
    MAX_MASS_RATIO,
    TANK_SPECIFIC_STRENGTH_J_PER_KG,
    TANK_STRUCTURAL_FLOOR_KG_PER_M3,
    tank_mass_fraction,
    inert_mass_with_tank,
    max_tank_fraction,
    critical_structural_floor,
    database_path,
    connect_db,
    close_db,
    load_thrusters,
    load_missions,
    load_propellants,
    query_db,
    compare_one,
    run_comparison,
    write_results!,
    make_plots,
    make_krypton_plot

# ---------------------------------------------------------------- constants

"Standard gravity, the constant that defines specific impulse in seconds."
const g0 = 9.80665

"""
Power system specific mass, kg per kW of electrical output.

This is the most consequential assumption in the comparison and no megawatt-class system
exists to measure it against. Values match `Comparison.PowerPlantAlphaKgPerKW` on the Scala
side so the two pipelines can be compared row for row.
"""
const POWER_PLANT_ALPHA_KG_PER_KW = Dict(
    "nuclear_electric" => 20.0,
    "solar_electric" => 12.0,
)

const DEFAULT_ALPHA_KG_PER_KW = 20.0

"Fallback for thruster plus power processing dry mass when the source does not give one."
const THRUSTER_SPECIFIC_MASS_KG_PER_KW = 5.0

"Above this mass ratio the vehicle is not a design, it is an arithmetic artefact."
const MAX_MASS_RATIO = 1.0e6

const SECONDS_PER_DAY = 86400.0

# ------------------------------------------------------------------ physics

"Exhaust velocity from specific impulse, ve = g0 * Isp."
exhaust_velocity(isp_s::Real) = g0 * isp_s

"Specific impulse from exhaust velocity, the inverse of [`exhaust_velocity`](@ref)."
specific_impulse(ve::Real) = ve / g0

"Tsiolkovsky mass ratio m0/mf = exp(dv / ve)."
mass_ratio(delta_v::Real, ve::Real) = exp(delta_v / ve)

"""
    propellant_mass_fraction(delta_v, ve)

Propellant mass fraction mp/m0 = 1 - exp(-dv/ve), equal to 1 - 1/MR.

This is strictly between 0 and 1 for every positive finite delta-v, which is the inequality
the comparison relies on and the one proved in `lean/Propulsion/Basic.lean`.
"""
propellant_mass_fraction(delta_v::Real, ve::Real) = 1 - exp(-delta_v / ve)

"Initial mass needed to deliver `m_final` through `delta_v`."
initial_mass(m_final::Real, delta_v::Real, ve::Real) = m_final * mass_ratio(delta_v, ve)

"Propellant mass needed to deliver `m_final` through `delta_v`."
propellant_mass(m_final::Real, delta_v::Real, ve::Real) =
    initial_mass(m_final, delta_v, ve) - m_final

"Electrical input power for a given thrust, P = T * ve / (2 * eta)."
input_power(thrust_N::Real, ve::Real, eta::Real) = thrust_N * ve / (2 * eta)

"Thrust available from a given electrical power, the inverse of [`input_power`](@ref)."
thrust_from_power(power_W::Real, ve::Real, eta::Real) = 2 * eta * power_W / ve

"Propellant mass flow rate, mdot = T / ve."
mass_flow(thrust_N::Real, ve::Real) = thrust_N / ve

"""
    transfer_time_seconds(mp, ve, eta, power_W)

Thrusting time for a power-limited vehicle, t = mp * ve^2 / (2 * eta * P).

This is the burn duration rather than a trajectory solution, and so is a lower bound on
trip time for a continuously thrusting transfer.
"""
transfer_time_seconds(mp::Real, ve::Real, eta::Real, power_W::Real) =
    mp * ve^2 / (2 * eta * power_W)

seconds_to_days(seconds::Real) = seconds / SECONDS_PER_DAY


# ------------------------------------------------------------------- tankage

"""
Effective specific strength of the tank wall, J/kg (equivalently m^2/s^2).

A thin-walled sphere holding pressure `P` over volume `V` needs a wall of mass
`1.5 * P * V / (sigma/rho)`, where `sigma/rho` is the material's specific strength. The value
used here is well below raw carbon fibre, because it has to absorb the liner, bosses, mounts,
weld lands and the safety factor that the ideal relation ignores.

It is calibrated so that xenon at 150 bar and 1600 kg/m3 lands near 5 percent of propellant
mass, which is where flown xenon tankage sits. Everything else follows from that one anchor,
so the xenon-to-krypton comparison is driven by pressure and density rather than by two
independently chosen numbers.
"""
const TANK_SPECIFIC_STRENGTH_J_PER_KG = 2.8125e5

"""
Structural floor on tank mass, kg per m3 of propellant volume.

The pressure term goes to zero for a propellant stored unpressurised, but a tank still has
walls, and a cryogenic tank still has insulation. This term keeps a solid or liquid store from
coming out weightless and carries most of the hydrogen tank mass.
"""
const TANK_STRUCTURAL_FLOOR_KG_PER_M3 = 8.0

"""
    tank_mass_fraction(storage_density_kg_m3, storage_pressure_bar) -> Float64

Tank dry mass as a fraction of the propellant mass it holds.

    f = 1.5 * P / (rho * psi) + kappa / rho

The first term is the thin-walled pressure vessel, the second the structural and insulation
floor. Both scale inversely with storage density, which is the whole of krypton's problem: it
stores at about 40 percent of xenon's density at 293 K and at a higher pressure, so it pays
twice over.

This is a first-order model. It does not carry boil-off hardware, feed systems, or the
square-cube advantage a very large tank enjoys over a small one.
"""
function tank_mass_fraction(storage_density_kg_m3::Real, storage_pressure_bar::Real)
    rho = float(storage_density_kg_m3)
    rho > 0 || throw(ArgumentError("storage density must be positive, got $rho"))
    p_pa = float(storage_pressure_bar) * 1.0e5
    pressure_term = 1.5 * p_pa / (rho * TANK_SPECIFIC_STRENGTH_J_PER_KG)
    floor_term = TANK_STRUCTURAL_FLOOR_KG_PER_M3 / rho
    pressure_term + floor_term
end

"""
    inert_mass_with_tank(base_inert_kg, mass_ratio, tank_fraction) -> Float64 or nothing

Solve for the inert mass once the tank is charged against it.

The tank is sized by the propellant it holds, and the propellant is sized by the inert mass it
has to push, so the two are mutually defined:

    m_f = base + f * m_p,   m_p = m_f * (MR - 1)
    =>  m_f = base / (1 - f * (MR - 1))

Returns `nothing` when `f * (MR - 1) >= 1`. That is not a numerical guard but a real physical
limit: past it the tank needed to hold the propellant is heavier than the propellant buys back,
and no finite vehicle closes. The corresponding Lean statement is
`Propulsion.inertMassWithTank_pos`.
"""
function inert_mass_with_tank(base_inert_kg::Real, mass_ratio::Real, tank_fraction::Real)
    denom = 1 - tank_fraction * (mass_ratio - 1)
    denom > 0 || return nothing
    base_inert_kg / denom
end

"""
    max_tank_fraction(mass_ratio) -> Float64

The largest tank fraction a vehicle at this mass ratio can carry and still close, `1/(MR-1)`.

[`inert_mass_with_tank`](@ref) has a solution exactly when `f < max_tank_fraction(mr)`. Above
it the tank needed to hold the propellant outweighs what the propellant buys back. Returns
`Inf` for `mr <= 1`, where no propellant is needed and tankage is unconstrained. The Lean
statement is `Propulsion.tankCloses_iff_lt_max`.
"""
max_tank_fraction(mass_ratio::Real) = mass_ratio > 1 ? 1 / (mass_ratio - 1) : Inf

"""
    critical_structural_floor(storage_density_kg_m3, storage_pressure_bar, mass_ratio) -> Float64

The structural floor `kappa` at which a vehicle at this mass ratio stops closing.

Inverts `f = 1.5 P / (rho psi) + kappa / rho` against `max_tank_fraction`. Negative means the
pressure term alone already exceeds the limit, so no floor is small enough to save it.

This is the number that matters for hydrogen. At 70.85 kg/m3 the floor term carries 94
percent of the tank fraction and the pressure term only 6, so `kappa` rather than the wall
strength decides whether a nuclear thermal vehicle closes at all.
"""
function critical_structural_floor(storage_density_kg_m3::Real, storage_pressure_bar::Real,
                                   mass_ratio::Real)
    rho = float(storage_density_kg_m3)
    rho > 0 || throw(ArgumentError("storage density must be positive, got $rho"))
    pressure_term = 1.5 * float(storage_pressure_bar) * 1.0e5 /
                    (rho * TANK_SPECIFIC_STRENGTH_J_PER_KG)
    rho * (max_tank_fraction(mass_ratio) - pressure_term)
end

# ------------------------------------------------------------ delta-v budget

"""
Per-mission delta-v budgets, broken into named legs.

These are project assumptions, not values taken from a source. They are recorded here so
that the single `delta_v_m_s` number in the missions table can be seen as something built
out of parts rather than asserted. `test/runtests.jl` checks that every budget sums to the
value held in the database.
"""
const DELTA_V_BUDGETS = Dict(
    "mars_crew_nominal" => (
        earth_departure = 3500.0,
        mars_arrival = 2500.0,
        margin = 1000.0,
    ),
    "mars_crew_fast" => (
        earth_departure = 7000.0,
        mars_arrival = 6000.0,
        margin = 2000.0,
    ),
    "probe500_nominal" => (
        earth_escape = 5000.0,
        cruise_shaping = 4000.0,
        target_rendezvous = 2000.0,
        margin = 1000.0,
    ),
    "probe500_aggressive" => (
        earth_escape = 7000.0,
        cruise_shaping = 8000.0,
        target_rendezvous = 3000.0,
        margin = 2000.0,
    ),
)

"""
    delta_v_budget(mission_id) -> NamedTuple

The delta-v legs for a mission. `sum(values(delta_v_budget(id)))` is the mission total.
"""
delta_v_budget(mission_id::AbstractString) = DELTA_V_BUDGETS[mission_id]

# ----------------------------------------------------------------- database

"""
    database_path() -> String

Locate `data/propulsion.duckdb` by walking up from the working directory, matching what the
Scala side does. `PROPULSION_DB` overrides.
"""
function database_path()
    explicit = get(ENV, "PROPULSION_DB", "")
    isempty(explicit) || return explicit
    dir = pwd()
    while true
        candidate = joinpath(dir, "data", "propulsion.duckdb")
        isfile(candidate) && return candidate
        parent = dirname(dir)
        parent == dir && error(
            "could not find data/propulsion.duckdb walking up from $(pwd()). " *
            "Build it with: duckdb data/propulsion.duckdb < sql/schema.sql",
        )
        dir = parent
    end
end

connect_db(path::AbstractString = database_path()) = DBInterface.connect(DuckDB.DB, path)

"Close a connection opened by [`connect_db`](@ref)."
close_db(con) = DBInterface.close!(con)

query(con, sql::AbstractString) = DataFrame(DBInterface.execute(con, sql))

"""
    query_db(con, sql) -> DataFrame

Run `sql` and collect the rows. Exported so callers do not need DBInterface directly.
"""
query_db(con, sql::AbstractString) = query(con, sql)

load_thrusters(con) = query(con, "SELECT * FROM thrusters ORDER BY thruster_id")
load_missions(con) = query(con, "SELECT * FROM missions ORDER BY mission_id")
load_propellants(con) = query(con, "SELECT * FROM propellants ORDER BY propellant")

# --------------------------------------------------------------- comparison

ismiss(x) = x === missing || (x isa Real && !isfinite(x))

"Power plant specific mass for a mission's power source."
alpha_for_source(power_source) =
    ismiss(power_source) ? DEFAULT_ALPHA_KG_PER_KW :
    get(POWER_PLANT_ALPHA_KG_PER_KW, power_source, DEFAULT_ALPHA_KG_PER_KW)

"""
    compare_one(mission, thruster) -> NamedTuple or nothing

Compare one thruster row against one mission row. Returns `nothing` when the thruster does
not record a specific impulse, which is the least the rocket equation needs.

Electric rows get the full power-limited treatment. Nuclear thermal rows get the rocket
equation only: reactor thermal power is not electrical input power, so trip time is left
`missing` rather than computed from a model that does not apply to them.
"""
function compare_one(mission, thruster; tank_fraction::Real = 0.0)
    ismiss(thruster.isp_s) && return nothing

    ve = exhaust_velocity(thruster.isp_s)
    mr = mass_ratio(mission.delta_v_m_s, ve)
    zeta = propellant_mass_fraction(mission.delta_v_m_s, ve)
    f_tank = float(tank_fraction)

    # Every branch returns a row of exactly these fields. Building it once and merging the
    # per-branch overrides keeps the four outcomes the same shape, so adding a results column
    # is one edit rather than four that have to stay in lockstep.
    base_row = (
        mission_id = mission.mission_id,
        thruster_id = thruster.thruster_id,
        n_thrusters = missing,
        exhaust_velocity_m_s = ve,
        mass_ratio = mr,
        propellant_mass_fraction = zeta,
        propellant_mass_kg = missing,
        initial_mass_kg = missing,
        power_plant_mass_kg = missing,
        tank_mass_kg = missing,
        tank_mass_fraction = f_tank,
        thrust_total_N = ismiss(thruster.thrust_mN) ? missing : thruster.thrust_mN / 1000,
        power_total_W = missing,
        trip_time_days = missing,
        meets_time_constraint = missing,
        feasible = false,
        alpha_kg_per_kW = missing,
        notes = "",
    )

    electric =
        thruster.power_basis == "electrical_input" &&
        !ismiss(thruster.thrust_mN) &&
        !ismiss(thruster.input_power_W) &&
        !ismiss(thruster.efficiency) &&
        !ismiss(mission.power_available_W)

    if electric
        p_avail = mission.power_available_W
        p_thruster = thruster.input_power_W
        eta = thruster.efficiency
        n = max(1, Int(floor(p_avail / p_thruster)))
        p_total = n * p_thruster
        unit_mass =
            ismiss(thruster.mass_kg) ?
            THRUSTER_SPECIFIC_MASS_KG_PER_KW * p_thruster / 1000 : thruster.mass_kg
        alpha = alpha_for_source(mission.power_source)
        power_plant_mass = alpha * p_avail / 1000
        base_inert = mission.payload_mass_kg + power_plant_mass + n * unit_mass

        common = (
            n_thrusters = n,
            power_plant_mass_kg = power_plant_mass,
            thrust_total_N = n * thruster.thrust_mN / 1000,
            power_total_W = p_total,
            alpha_kg_per_kW = alpha,
        )

        inert_mass = inert_mass_with_tank(base_inert, mr, f_tank)
        if inert_mass === nothing
            # Tankage diverges: the tank needed to hold the propellant outweighs what the
            # propellant buys back, so no finite vehicle closes.
            return merge(base_row, common, (
                notes = @sprintf(
                    "tankage diverges: tank fraction %.3f times (MR-1) %.3f reaches 1, no closed vehicle",
                    f_tank, mr - 1
                ),
            ))
        end

        mp = inert_mass * (mr - 1)
        tank_mass = f_tank * mp
        m0 = inert_mass * mr
        trip_days = seconds_to_days(transfer_time_seconds(mp, ve, eta, p_total))
        meets = ismiss(mission.max_trip_time_days) ? missing :
                trip_days <= mission.max_trip_time_days
        sane = isfinite(mr) && mr <= MAX_MASS_RATIO && isfinite(m0)
        mass_note =
            ismiss(thruster.mass_kg) ?
            @sprintf("thruster mass assumed at %.1f kg/kW", THRUSTER_SPECIFIC_MASS_KG_PER_KW) :
            "thruster mass from source"

        return merge(base_row, common, (
            propellant_mass_kg = mp,
            initial_mass_kg = m0,
            tank_mass_kg = tank_mass,
            trip_time_days = trip_days,
            meets_time_constraint = meets,
            feasible = sane && (meets === missing ? true : meets),
            notes = @sprintf(
                "power-limited electric; %s; power plant %.0f kg at %.1f kg/kW; tank %.0f kg at f=%.3f",
                mass_note, power_plant_mass, alpha, tank_mass, f_tank
            ),
        ))
    else
        # Nuclear thermal, or any row without the full electric quadruple. The power-limited
        # transfer model does not apply, so trip time is left missing rather than computed
        # from a model that does not fit.
        why =
            thruster.power_basis == "reactor_thermal" ?
            "nuclear thermal: power-limited transfer model does not apply, trip time not evaluated" :
            ismiss(mission.power_available_W) ? "mission states no available power" :
            "row lacks one of thrust, Isp, power or efficiency"

        # Charge engine dry mass where the source gives one. ntp_nerva_derived does; the
        # Rover reactor tests and the NASEM study reference do not, because a reactor test
        # is not an engine, so those rows stay optimistic by an unrecorded amount.
        engine_mass = ismiss(thruster.mass_kg) ? 0.0 : thruster.mass_kg
        base_inert = mission.payload_mass_kg + engine_mass
        inert_mass = inert_mass_with_tank(base_inert, mr, f_tank)
        if inert_mass === nothing
            return merge(base_row, (
                notes = @sprintf("%s; tankage diverges at f=%.3f and MR=%.3f", why, f_tank, mr),
            ))
        end

        mp = inert_mass * (mr - 1)
        tank_mass = f_tank * mp
        m0 = inert_mass * mr
        sane = isfinite(mr) && mr <= MAX_MASS_RATIO && isfinite(m0)

        return merge(base_row, (
            propellant_mass_kg = mp,
            initial_mass_kg = m0,
            tank_mass_kg = tank_mass,
            feasible = sane,
            notes = @sprintf(
                "%s; %s; tank %.0f kg at f=%.3f", why,
                engine_mass > 0 ? @sprintf("engine dry mass %.0f kg", engine_mass) :
                                  "engine dry mass not recorded and excluded",
                tank_mass, f_tank
            ),
        ))
    end
end

"""
    run_comparison(con) -> DataFrame

Every mission crossed with every thruster that records a specific impulse.
"""
function run_comparison(con)
    propellants = load_propellants(con)
    # Tank fraction per propellant, from its storage density and pressure.
    tank_fractions = Dict(
        p.propellant => (ismiss(p.storage_density_kg_m3) ? 0.0 :
                         tank_mass_fraction(p.storage_density_kg_m3,
                                            ismiss(p.storage_pressure_bar) ? 0.0 :
                                            p.storage_pressure_bar))
        for p in eachrow(propellants)
    )
    missions = load_missions(con)
    thrusters = load_thrusters(con)
    rows = NamedTuple[]
    for m in eachrow(missions), t in eachrow(thrusters)
        r = compare_one(m, t; tank_fraction = get(tank_fractions, t.propellant, 0.0))
        r === nothing || push!(rows, r)
    end
    DataFrame(rows)
end

"""
    write_results!(con, results; producer="julia", run_id=...)

Replace this producer's rows in the `results` table. Rows written by the Scala pipeline are
left alone, so both sets can be compared afterwards.
"""
function write_results!(con, results::DataFrame; producer::AbstractString = "julia",
                        run_id::AbstractString = "julia-$(Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"))")
    DBInterface.execute(con, "DELETE FROM results WHERE producer = '$producer'")

    staged = copy(results)
    staged.run_id .= run_id
    staged.run_ts .= now()
    staged.producer .= producer

    DuckDB.register_data_frame(con, staged, "staged_results")
    try
        DBInterface.execute(con, """
            INSERT INTO results (
                run_id, run_ts, producer, mission_id, thruster_id, n_thrusters,
                exhaust_velocity_m_s, mass_ratio, propellant_mass_fraction, propellant_mass_kg,
                initial_mass_kg, power_plant_mass_kg, tank_mass_kg, tank_mass_fraction,
                thrust_total_N, power_total_W,
                trip_time_days, meets_time_constraint, feasible, alpha_kg_per_kW, notes)
            SELECT
                run_id, run_ts, producer, mission_id, thruster_id, n_thrusters,
                exhaust_velocity_m_s, mass_ratio, propellant_mass_fraction, propellant_mass_kg,
                initial_mass_kg, power_plant_mass_kg, tank_mass_kg, tank_mass_fraction,
                thrust_total_N, power_total_W,
                trip_time_days, meets_time_constraint, feasible, alpha_kg_per_kW, notes
            FROM staged_results
        """)
    finally
        DuckDB.unregister_data_frame(con, "staged_results")
    end
    nrow(staged)
end

include("plots.jl")

end # module
