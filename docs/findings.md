# Findings

This document reports what the pipeline computes, which candidates rank where, and what
would have to be measured before any of it should be trusted as a recommendation. The
survey and its citations are in `docs/survey.md`; source tags of the form `[S01]` refer to
the table there and to the `sources` table in the database.

## Reproducing the numbers

    duckdb data/propulsion.duckdb < sql/schema.sql
    cd scala && mill pipeline.runMain propulsion.Main compare && cd ..
    julia --project=julia/Propulsion scripts/run_julia_pipeline.jl
    julia --project=julia/Propulsion scripts/sensitivity.jl
    cd lean && lake build && lake env lean check_axioms.lean

Every number below came from a query against `data/propulsion.duckdb` after those steps.
The database is not version controlled; it is rebuilt from `sql/schema.sql` and the CSVs in
`data/raw/`.

## What was computed, and on what assumptions

For each of 4 missions and each of 26 thrusters that records a specific impulse, the
pipeline computes exhaust velocity, Tsiolkovsky mass ratio, propellant mass fraction,
propellant and initial mass, thruster count, total thrust and power, and power-limited
thrusting time. That is 104 rows, of which 86 are feasible.

Three assumptions carry the result. None is a measurement.

Power plant specific mass is taken as 20 kg/kW for nuclear electric and 12 kg/kW for solar
electric. Thruster plus power processing dry mass, where a source does not give one, is
taken as 5 kg/kW; this applies to 24 of the 26 rows. Mission payload masses, delta-v and
trip-time caps are stated project assumptions, with only the 2 MWe and 6 MWe power levels
traceable to a source [S18].

Two further limits are worth stating plainly. The trip time computed here is thrusting
time from the power-limited relation, not a trajectory solution, so it is a lower bound on
a real transfer. And nuclear thermal rows are given rocket-equation results only: reactor
thermal power is not electrical input power, so the power-limited model does not apply to
them and their trip time is left empty rather than filled with a number the model cannot
support. NTP can therefore be compared on mass here, and cannot be compared on time.

## Crewed Mars transfer, nominal

90 t payload, 7000 m/s, 2 MWe, 365-day cap. 25 of 26 candidates are feasible; the only
failure is the NPT30-I2, a 1 mN cubesat thruster that has no business on this mission.

| rank | thruster | type | propellant | initial mass kg | propellant kg | mass fraction | days | units |
|---|---|---|---|---|---|---|---|---|
| 1 | HiPEP | gridded ion | xenon | 152 492 | 12 610 | 0.083 | 317.5 | 81 |
| 2 | VASIMR VX-200 | other plasma | argon | 161 955 | 21 955 | 0.136 | 209.5 | 10 |
| 3 | MAI lithium AF-MPD 200 kW | MPD | lithium | 164 781 | 25 531 | 0.155 | 276.2 | 10 |
| 4 | T6 | gridded ion | xenon | 165 268 | 25 278 | 0.153 | 197.3 | 444 |
| 5 | NEXT PM1 | gridded ion | xenon | 165 967 | 25 997 | 0.157 | 179.4 | 289 |
| 6 | MAI lithium AF-MPD 32 kW | MPD | lithium | 169 095 | 29 175 | 0.173 | 276.8 | 62 |

The spread across the whole feasible set is narrow. From HiPEP at 152 t to the SPT-50 at
268 t is a factor of 1.76, and the top six sit within 11 % of each other. The reason is
that at 2 MWe and 20 kg/kW the power plant alone is 40 t, and the payload is 90 t, so 130 t
of the initial mass is fixed before a thruster is chosen. Propellant is 8 % to 17 % of the
vehicle for the leading candidates. The choice of thruster is not what sizes this vehicle.

Thruster count is the discriminator the mass column hides. HiPEP leads on mass and needs 81
units; T6 and NEXT need 444 and 289. The three candidates that need ten or fewer units,
VASIMR and the two lithium MPD thrusters, are the least mature hardware in the set.

## Crewed Mars transfer, fast

90 t payload, 15 000 m/s, 6 MWe, 210-day cap. Only 9 of 26 are feasible, and the pattern of
failure is the result.

| rank | thruster | type | propellant | initial mass kg | propellant kg | mass fraction | days | units |
|---|---|---|---|---|---|---|---|---|
| 1 | HERMeS AEPS | Hall | xenon | 432 221 | 192 221 | 0.445 | 196.9 | 480 |
| 2 | X3 nested-channel Hall | Hall | xenon | 441 420 | 201 720 | 0.457 | 177.0 | 60 |
| 3 | NASEM reference NTP | nuclear thermal | hydrogen | 492 422 | 402 422 | 0.817 | not evaluated | - |
| 4 | Pewee | nuclear thermal | hydrogen | 550 021 | 460 021 | 0.836 | not evaluated | - |
| 5 | SPT-140 | Hall | xenon | 575 179 | 335 179 | 0.583 | 173.1 | 1200 |
| 6 | Phoebus-2A | nuclear thermal | hydrogen | 581 229 | 491 229 | 0.845 | not evaluated | - |

Every gridded ion thruster fails, as do all three lithium MPD thrusters and VASIMR. They
fail on time, not on mass. The power-limited thrusting time scales with the square of
exhaust velocity at fixed power, so the high specific impulse that wins the nominal mission
is exactly what loses the fast one. The survivors are the low-Isp, high-thrust-density Hall
thrusters and the nuclear thermal rows, which are not subject to the constraint at all
because the model does not evaluate them on it.

That last point needs holding on to. The NTP rows rank third, fourth and sixth on mass
alone, and the comparison has nothing to say about whether they meet the 210-day
requirement. Their appearance in this table is not evidence that they do.

Within the electric survivors, propellant is 45 % to 58 % of the vehicle, against 8 % to
17 % on the nominal mission. Doubling delta-v and halving the time cap moves the design
from power-plant-dominated to propellant-dominated.

## 500 kg deep-space probe

20 kW solar electric, 3650-day cap. Both delta-v variants are shown; every candidate is
feasible in both, so the time cap does no work here and the ranking is purely on mass.

Nominal, 12 000 m/s:

| rank | thruster | initial mass kg | propellant kg | mass fraction | days | units |
|---|---|---|---|---|---|---|
| 1 | HiPEP | 999 | 137 | 0.138 | 280.3 | 1 |
| 2 | NEXT PM1 | 1083 | 274 | 0.253 | 273.6 | 2 |
| 3 | T6 | 1103 | 273 | 0.248 | 236.7 | 4 |
| 4 | XIPS-25 orbit raising | 1166 | 340 | 0.292 | 201.5 | 4 |
| 5 | NSTAR | 1191 | 386 | 0.324 | 182.7 | 8 |

High energy, 20 000 m/s:

| rank | thruster | initial mass kg | propellant kg | mass fraction | days | units |
|---|---|---|---|---|---|---|
| 1 | HiPEP | 1103 | 241 | 0.219 | 491.6 | 1 |
| 2 | NEXT PM1 | 1316 | 507 | 0.385 | 505.8 | 2 |
| 3 | T6 | 1334 | 504 | 0.378 | 436.3 | 4 |
| 4 | XIPS-25 orbit raising | 1467 | 641 | 0.437 | 380.0 | 4 |
| 5 | XIPS-25 station keeping | 1525 | 685 | 0.449 | 332.7 | 10 |

This is the one case where the comparison gives a clear and stable answer. High-Isp gridded
ion thrusters take the top five places at both delta-v levels, the ordering does not change
between them, and it survives every sensitivity case run below. The probe is small enough
that propellant is a large share of the vehicle, which is precisely the regime where
specific impulse decides the outcome.

The practical recommendation differs from the raw ranking. HiPEP ranks first but was
cancelled with the Jupiter Icy Moons Orbiter in 2005 and has no flight heritage [S04]. NEXT
and T6 are second and third at a cost of 8 % and 10 % in initial mass, and both are
qualified hardware, with T6 flying on BepiColombo [S26] and NEXT having completed its
ground qualification [S02]. For a 500 kg probe the defensible choice is NEXT or T6.

## Agreement between the implementations

The Scala and Julia pipelines implement the relations separately rather than sharing code.
The Julia test suite joins both producers' rows in the `results` table and requires
agreement to 1e-9 relative. All 104 rows agree on initial mass, propellant mass, trip time
and thruster count. 878 Julia tests and 26 Scala self-tests pass, and SQL validation
reports no errors over 17 checks.

The Lean development proves the relations the comparison uses, including
`propellantMassFraction_mem_Ico`, the statement that the propellant mass fraction lies in
`[0, 1)`, and `propellantMassFraction_lt_of_isp_lt`, which is what licenses ranking by
specific impulse. All 21 theorems depend only on Lean's three standard axioms.

One gap between the proof and the code is worth recording. The mass-fraction bound is
strict over the reals, but in Float64 the fraction rounds to exactly 1.0 once delta-v over
exhaust velocity passes about 37, which would mean an infinite mass ratio. The pipelines cap
the mass ratio at 1e6, corresponding to a ratio near 13.8, so they never approach it. A test
in `julia/Propulsion/test/runtests.jl` pins both facts so the gap cannot close silently.

## Sensitivity

`scripts/sensitivity.jl` recomputes the rankings with the two unmeasured mass assumptions
varied by a factor of two in each direction.

For the crewed Mars nominal mission, halving power plant specific mass from 20 to 10 kg/kW
drops HiPEP's initial mass from 152 t to 131 t. Doubling it to 40 kg/kW removes HiPEP from
the feasible set entirely, because the extra propellant pushes its thrusting time past the
365-day cap, and VASIMR inherits first place at 208 t. A factor of two in a quantity nobody
has measured is enough to unseat the first-ranked candidate.

Varying thruster specific mass from 2 to 10 kg/kW moves HiPEP's initial mass from 146 t to
163 t, and at 10 kg/kW the NSTAR rises from outside the top five to second place, because
its fixed 8.2 kg dry mass [S28] stops being penalised by an assumption while every other
candidate's assumed mass grows.

The probe rankings do not move. HiPEP, NEXT and T6 hold the top three places across every
combination tried, with only the fourth and fifth places exchanging. The probe conclusion
can be relied on; the crewed Mars conclusion cannot.

Figures are in `docs/figures`: `trip_time.png`, `initial_mass.png`, `propellant_mass.png`
and `isp_vs_trip_time.png`.

## The three unknowns that would most change these results

**Power plant specific mass at megawatt scale.** At 2 MWe and 20 kg/kW the power plant is
40 t of a 130 t inert mass, which is more than the entire propellant load of the leading
candidates. The sensitivity run shows that a factor of two in this number reorders the
crewed Mars ranking and eliminates the leader. Nothing measures it: the largest space
fission system ever operated is KRUSTY at 1 kWe for 28 hours [S19], three orders of
magnitude short, and the NASEM committee's finding was precisely that a MWe-class system
needs power orders of magnitude above any completed demonstration [S18]. Every published
crewed NEP trip time, including the ones here, rests on an assumed value. A ground
demonstration at even 100 kWe with measured mass, including radiators and power
conditioning, would settle more about crewed Mars propulsion than any thruster programme.

**Thruster and power-processing dry mass.** The dataset records a dry mass for 2 of 26
thrusters. The other 24 use an assumed 5 kg/kW, and the validation run emits 26
`dry_mass_unknown` warnings to make that visible. The gap is in the literature rather than
in the transcription: performance papers report thrust, specific impulse, power and
efficiency, and very often omit mass. Because the assumption scales with power, it
systematically favours whichever architecture the assumption happens to suit, and the
sensitivity run shows NSTAR moving three places on nothing but a change in that constant.
Published dry masses for the flight and qualification units, with power processing included
and the boundary stated, would cost nothing to produce and would firm up every trade study
that uses this data.

**Demonstrated propellant throughput per thruster against what a mission needs.** This is
the unknown the mass ranking conceals, and it inverts the recommendation. Dividing
propellant mass by thruster count gives what each unit must process:

| mission | thruster | units | propellant per unit kg |
|---|---|---|---|
| Mars fast | X3 nested-channel Hall | 60 | 3362 |
| Mars nominal | MAI lithium AF-MPD 200 kW | 10 | 2553 |
| Mars nominal | X3 nested-channel Hall | 20 | 2306 |
| Mars nominal | VASIMR VX-200 | 10 | 2196 |
| Mars fast | HERMeS AEPS | 480 | 401 |
| Mars nominal | HiPEP | 81 | 156 |
| Mars nominal | NEXT PM1 | 289 | 90 |
| Mars nominal | PPS-1350-G | 1333 | 57 |
| Mars nominal | NSTAR | 860 | 41 |

The only in-flight throughput figure in the dataset is the PPS-1350-G, which processed 82 kg
of xenon over about 5000 hours on SMART-1 [S01]. The candidates that need fewest units, and
that look best on mass, are the ones requiring one to two orders of magnitude more
throughput per unit than that, from hardware whose life has never been characterised: the
X3 at 2306 kg per unit, with cathodes drawing 247 A that are a research item rather than a
product [S08], and the lithium MPD thrusters at 2553 kg per unit, whose published test
durations are short and whose electrode erosion is largely uncharacterised [S13]. Running
the trade the other way, the thrusters whose throughput requirement sits inside demonstrated
experience are the ones needing hundreds or thousands of units. Qualified throughput per
thruster, measured to the duration a Mars mission actually needs, would decide between those
two bad options, and nothing in the present data can.

## What this comparison does not settle

The nuclear thermal rows cannot be ranked against the electric ones on time, because the
power-limited model does not apply to them and no NTP trajectory model is implemented here.
Their position in the Mars tables reflects mass alone and engine dry mass is excluded from
it, so those initial masses are optimistic by an unrecorded amount.

Trip times are thrusting times, not trajectories. A real transfer adds coast, and for the
crewed cases the difference between a 197-day burn and a 210-day mission cap is well inside
the error of treating one as the other.

The delta-v figures and payload masses are project assumptions. They are decomposed into
named legs in `DELTA_V_BUDGETS` and checked against the database, which makes them explicit
and auditable, but it does not make them right.

Krypton and iodine appear in the propellants table and in the survey, but no krypton
thruster is in the dataset, because the krypton literature reports efficiency as a range
against xenon rather than as a standalone operating point [S12]. A krypton comparison would
need measured krypton performance for a specific thruster, not a penalty applied to a xenon
number.
