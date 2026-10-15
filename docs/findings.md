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

For each of 4 missions and each of 31 thrusters that records a specific impulse, the
pipeline computes exhaust velocity, Tsiolkovsky mass ratio, propellant mass fraction,
propellant and initial mass, thruster count, total thrust and power, and power-limited
thrusting time. That is 124 rows, of which 103 are feasible.

Three assumptions carry the result. None is a measurement.

Power plant specific mass is taken as 20 kg/kW for nuclear electric and 12 kg/kW for solar
electric. Thruster plus power processing dry mass, where a source does not give one, is
taken as 5 kg/kW; this applies to 29 of the 31 rows. Mission payload masses, delta-v and
trip-time caps are stated project assumptions, with only the 2 MWe and 6 MWe power levels
traceable to a source [S18].

Two further limits are worth stating plainly. The trip time computed here is thrusting
time from the power-limited relation, not a trajectory solution, so it is a lower bound on
a real transfer. And nuclear thermal rows are given rocket-equation results only: reactor
thermal power is not electrical input power, so the power-limited model does not apply to
them and their trip time is left empty rather than filled with a number the model cannot
support. NTP can therefore be compared on mass here, and cannot be compared on time.

## Crewed Mars transfer, nominal

90 t payload, 7000 m/s, 2 MWe, 365-day cap. 30 of 31 candidates are feasible; the only
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

90 t payload, 15 000 m/s, 6 MWe, 210-day cap. Only 11 of 31 are feasible, and the pattern of
failure is the result.

| rank | thruster | type | propellant | initial mass kg | propellant kg | mass fraction | days | units |
|---|---|---|---|---|---|---|---|---|
| 1 | HERMeS AEPS | Hall | xenon | 432 221 | 192 221 | 0.445 | 196.9 | 480 |
| 2 | X3 nested-channel Hall | Hall | xenon | 441 420 | 201 720 | 0.457 | 177.0 | 60 |
| 3 | NASEM reference NTP | nuclear thermal | hydrogen | 492 422 | 402 422 | 0.817 | not evaluated | - |
| 4 | BHT-1500-C xenon | Hall | xenon | 521 683 | 281 686 | 0.540 | 186.8 | 3333 |
| 5 | Pewee | nuclear thermal | hydrogen | 550 021 | 460 021 | 0.836 | not evaluated | - |
| 6 | SPT-140 | Hall | xenon | 575 179 | 335 179 | 0.583 | 173.1 | 1200 |
| 7 | Phoebus-2A | nuclear thermal | hydrogen | 581 229 | 491 229 | 0.845 | not evaluated | - |

Every gridded ion thruster fails, as do all three lithium MPD thrusters, VASIMR and all
three krypton rows, each failing where the xenon it is set against passes. They
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

## Krypton against xenon on matched hardware

The dataset carries three measured krypton operating points. Two of them have a xenon control
on the same thruster in the same facility, measured in the same campaign, so for those two the
propellant can be compared without going through a correction factor. The third, the SPT-100 at
393 V, comes from a separate life-test paper [S31] and has no condition-matched xenon run; where
it is set against xenon below it is against the 302 V nominal control from [S30], which differs
in discharge voltage and flow as well as propellant. The two true pairs behave the same way on
both reference missions.

Crewed Mars nominal:

| thruster | propellant | Isp s | efficiency | initial mass kg | propellant kg | days | units |
|---|---|---|---|---|---|---|---|
| BHT-1500-C | krypton | 2160 | 0.474 | 194 817 | 54 823 | 150.3 | 1052 |
| BHT-1500-C | xenon | 1970 | 0.543 | 201 134 | 61 135 | 121.6 | 1111 |
| SPT-100 nominal | krypton | 1568 | 0.360 | 220 705 | 80 712 | 153.5 | 1474 |
| SPT-100 nominal | xenon | 1511 | 0.440 | 224 534 | 84 537 | 122.1 | 1480 |

500 kg probe nominal:

| thruster | propellant | initial mass kg | propellant kg | days | units |
|---|---|---|---|---|---|
| BHT-1500-C | krypton | 1471 | 636 | 183.5 | 10 |
| BHT-1500-C | xenon | 1561 | 722 | 145.1 | 11 |
| SPT-100 nominal | krypton | 1822 | 987 | 197.6 | 14 |
| SPT-100 nominal | xenon | 1876 | 1041 | 159.0 | 14 |

Krypton wins on mass in every pair, by 3.1 % for the BHT-1500-C and 1.7 % for the SPT-100 on
the crewed mission, and loses on time by 24 % and 26 %. That split follows from the structure
of the model rather than from anything subtle. At a fixed available power, specific impulse
sets propellant mass and efficiency sets thrust, so krypton's higher specific impulse shows
up as less propellant while its lower efficiency shows up as a longer burn. Wherever the
trip-time cap is slack, krypton looks better.

Where the cap binds, the sign reverses completely. On the fast Mars mission all three krypton
rows fail the 210-day limit while both xenon controls pass: the BHT-1500-C needs 225.8 days on
krypton against 186.8 on xenon, which is a like-for-like pair, and the SPT-100 at 393 V needs
239.5 days against 202.4 for the 302 V xenon control, which is not. Krypton is not a drop-in
substitution whose cost is a fixed efficiency penalty; it moves a vehicle along the
mass-against-time trade, and which direction counts as better depends entirely on which
constraint is active.

Two things keep this from being a recommendation. The first is tankage, which the model does
not carry. For the probe, the BHT-1500-C needs 636 kg of krypton in 0.98 m³ against 722 kg of
xenon in 0.45 m³ at the storage densities in the propellants table, so krypton saves 86 kg of
propellant while asking for 2.2 times the tank volume. Whether the tank mass for that volume
is under 86 kg decides the comparison, and no source consulted gives tank mass for a krypton
system. The second is that krypton reaches no higher than fourteenth on the probe and does not
enter the top six on either Mars mission. The leaders everywhere are high-Isp gridded ion
thrusters on xenon, and adding krypton moved none of them.

`docs/figures/krypton_vs_xenon.png` plots the pairs across all three missions, with the rows
that fail their time cap drawn pale.

## Agreement between the implementations

The Scala and Julia pipelines implement the relations separately rather than sharing code.
The Julia test suite joins both producers' rows in the `results` table and requires
agreement to 1e-9 relative. All 124 rows agree on initial mass, propellant mass, trip time
and thruster count. 1038 Julia tests and 26 Scala self-tests pass, and SQL validation
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

Figures are in `docs/figures`: `trip_time.png`, `initial_mass.png`, `propellant_mass.png`,
`isp_vs_trip_time.png` and `krypton_vs_xenon.png`.

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

**Thruster and power-processing dry mass.** The dataset records a dry mass for 2 of 31
thrusters. The other 29 use an assumed 5 kg/kW, and the validation run emits 29
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

The throughput actually demonstrated is far below all of this. The best-qualified figure in
the dataset is the SPT-100, validated past 2.71 MN·s of total impulse, about 9000 hours at its
nominal condition [S31]; at its measured 1511 s that is roughly 183 kg of xenon per thruster.
The PPS-1350-G accumulated 82 kg over about 5000 hours in flight on SMART-1 [S01]. The
candidates that need fewest units, and that look best on mass, are the ones requiring one to
two orders of magnitude more throughput per unit than those figures, from hardware whose life
has never been characterised: the X3 at 2306 kg per unit, with cathodes drawing 247 A that are
a research item rather than a product [S08], and the lithium MPD thrusters at 2553 kg per unit,
whose published test durations are short and whose electrode erosion is largely
uncharacterised [S13]. Running the trade the other way, the thrusters whose throughput
requirement sits inside demonstrated experience are the ones needing hundreds or thousands of
units.

Krypton makes this worse rather than better. It cuts propellant mass per unit, which helps,
but the longest published krypton run on any thruster is the 205 hours the SPT-100 managed at
2 kW [S31], against roughly 9000 hours qualified on xenon. The same paper notes that running
its example mission on krypton would put as much energy through the thruster as 8800 hours of
nominal xenon operation, and that whether the hardware survives that is unknown [S31].
Qualified throughput per thruster, measured to the duration a Mars mission actually needs and
on the propellant actually proposed, would decide between these options, and nothing in the
present data can.

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

Krypton is compared here without a tank model, which is the one thing that could overturn the
matched-pair result above. Iodine appears in the propellants table and in the survey but
contributes only the NPT30-I2, a 1 mN cubesat thruster that clears both probe missions and
fails both crewed Mars missions on the trip-time cap, needing 466 days against the 365-day
limit and 768 against the 210-day one; there is no kilowatt-class iodine operating point to
add, because none has been published [S11].

Argon is represented only by VASIMR, which is a 200 kW laboratory device run in one-to-two
minute pulses [S15]. Its second place on the crewed Mars nominal mission rests on a peak
performance point, not on anything sustained, and the longest continuous run of the follow-on
hardware was 88 hours at 80 kW [S16].
