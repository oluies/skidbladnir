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
propellant and tank mass, initial mass, thruster count, total thrust and power, and
power-limited thrusting time. That is 124 rows, of which 98 are feasible.

Four assumptions carry the result. None is a measurement.

Power plant specific mass is taken as 20 kg/kW for nuclear electric and 12 kg/kW for solar
electric. Thruster plus power processing dry mass, where a source does not give one, is
taken as 5 kg/kW; this applies to 29 of the 31 rows. Mission payload masses, delta-v and
trip-time caps are stated project assumptions, with only the 2 MWe and 6 MWe power levels
traceable to a source [S18].

The fourth is tankage. The tank is sized as

    f = 1.5 * P / (rho * psi) + kappa / rho

kilograms of tank per kilogram of propellant, the first term a thin-walled pressure vessel
and the second a structural and insulation floor, with `psi` an effective wall specific
strength of 2.8e5 J/kg and `kappa` 8 kg/m3. `psi` is calibrated so xenon at 150 bar and
1600 kg/m3 lands near 5 percent of propellant mass, which is where flown xenon tankage sits;
every other propellant then follows from its own density and pressure rather than from a
second free choice. The resulting fractions are 5.5 percent for xenon, 12.0 for hydrogen,
17.6 for krypton, 33.6 for argon, 1.5 for lithium and 0.2 for iodine.

Because the tank is sized by the propellant and the propellant by the inert mass it has to
push, the inert mass is the solution of a fixed point rather than a sum:

    m_f = base / (1 - f (MR - 1))

That has a solution only while `f (MR - 1) < 1`. Past it the tank needed to hold the
propellant outweighs what the propellant buys back and no finite vehicle closes; the
pipeline marks such a row infeasible rather than returning a number. The Lean development
proves the closed form solves the fixed point, that it is positive under exactly that
condition, and that it is strictly increasing in `f`.

Two further limits are worth stating plainly. The trip time computed here is thrusting
time from the power-limited relation, not a trajectory solution, so it is a lower bound on
a real transfer. And nuclear thermal rows are given rocket-equation results only: reactor
thermal power is not electrical input power, so the power-limited model does not apply to
them and their trip time is left empty rather than filled with a number the model cannot
support. NTP can therefore be compared on mass here, and cannot be compared on time.

## Crewed Mars transfer, nominal

90 t payload, 7000 m/s, 2 MWe, 365-day cap. 30 of 31 candidates are feasible; the only
failure is the NPT30-I2, a 1 mN cubesat thruster that has no business on this mission.

| rank | thruster | type | propellant | initial mass kg | propellant kg | tank kg | days | units |
|---|---|---|---|---|---|---|---|---|
| 1 | HiPEP | gridded ion | xenon | 153 252 | 12 673 | 697 | 319.0 | 81 |
| 2 | MAI lithium AF-MPD 200 kW | MPD | lithium | 165 235 | 25 602 | 384 | 276.9 | 10 |
| 3 | T6 | gridded ion | xenon | 166 926 | 25 532 | 1 404 | 199.2 | 444 |
| 4 | NEXT PM1 | gridded ion | xenon | 167 680 | 26 265 | 1 445 | 181.3 | 289 |
| 5 | MAI lithium AF-MPD 32 kW | MPD | lithium | 169 624 | 29 266 | 438 | 277.7 | 62 |
| 6 | MAI lithium AF-MPD 150 kW | MPD | lithium | 169 814 | 29 620 | 444 | 266.4 | 13 |

The spread across the feasible set is narrow. The top six sit within 11 percent of each
other, because at 2 MWe and 20 kg/kW the power plant alone is 40 t and the payload is 90 t,
so 130 t of the vehicle is fixed before a thruster is chosen. Propellant is 8 to 17 percent
of the vehicle for the leading candidates and tankage under 1 percent. The choice of
thruster is not what sizes this vehicle.

Tankage changed the order here. VASIMR ranked second before the tank model was added and is
now outside the top six, because argon stores at 500 kg/m3 and 300 bar and carries a 33.6
percent tank fraction, the worst of any propellant in the set. The three lithium MPD
thrusters moved the other way: lithium is a dense unpressurised solid, so its tank is 1.5
percent and all three gained a place, the 200 kW unit from third to second, the 32 kW from
sixth to fifth and the 150 kW from seventh to sixth.

Thruster count is the discriminator the mass column hides. HiPEP leads on mass and needs 81
units; T6 and NEXT need 444 and 289. The candidates needing ten or fewer units are the
lithium MPD thrusters, the least mature hardware in the set.

## Crewed Mars transfer, fast

90 t payload, 15 000 m/s, 6 MWe, 210-day cap. Only 9 of 31 are feasible, and the pattern of
failure is the result.

| rank | thruster | type | propellant | initial mass kg | propellant kg | tank kg | days | units |
|---|---|---|---|---|---|---|---|---|
| 1 | HERMeS AEPS | Hall | xenon | 452 138 | 201 079 | 11 059 | 206.0 | 480 |
| 2 | X3 nested-channel Hall | Hall | xenon | 462 843 | 211 510 | 11 633 | 185.6 | 60 |
| 3 | BHT-1500-C xenon | Hall | xenon | 557 684 | 301 125 | 16 562 | 199.6 | 3333 |
| 4 | SPT-140 | Hall | xenon | 623 036 | 363 067 | 19 969 | 187.5 | 1200 |
| 5 | PPS-1350-G | Hall | xenon | 662 071 | 400 068 | 22 004 | 183.7 | 4000 |
| 6 | SPT-100 | Hall | xenon | 684 576 | 421 402 | 23 177 | 200.2 | 4444 |

Every surviving electric candidate is a xenon Hall thruster. Every gridded ion thruster
fails, as do all three lithium MPD thrusters, VASIMR, and all three krypton rows. They fail
on time, not on mass. Power-limited thrusting time scales with the square of exhaust velocity
at fixed power, so the high specific impulse that wins the nominal mission is exactly what
loses the fast one.

The three nuclear thermal rows are feasible here and sit below the table, because once
tankage is charged they are the three heaviest vehicles in the feasible set: the NASEM
reference NTP at 1067 t, Pewee at 1431 t and Phoebus-2A at 1696 t, ranking seventh, eighth
and ninth of nine. Hydrogen is the reason. At 70.85 kg/m3 it carries a 12.0 percent tank
fraction against xenon's 5.5, and it is combined with mass ratios above 5, so the tank
compounds against the propellant rather than trimming it. Their feasibility flag means only
that the rocket equation closes: the comparison has nothing to say about whether any of them
meets the 210-day requirement, because the model that produces a trip time does not apply to
them.

Within the electric survivors, propellant is 44 to 62 percent of the vehicle, against 8 to 17
percent on the nominal mission. Doubling delta-v and halving the time cap moves the design
from power-plant-dominated to propellant-dominated.

## 500 kg deep-space probe

20 kW solar electric, 3650-day cap. Nominal has all 31 candidates feasible; the high-energy
variant loses three, all of them nuclear thermal and all of them to tankage rather than time;
the structural-floor sweep below explains why.

Nominal, 12 000 m/s:

| rank | thruster | initial mass kg | propellant kg | tank kg | days | units |
|---|---|---|---|---|---|---|
| 1 | HiPEP | 1008 | 139 | 8 | 282.8 | 1 |
| 2 | NEXT PM1 | 1104 | 280 | 15 | 278.8 | 2 |
| 3 | T6 | 1124 | 278 | 15 | 241.0 | 4 |
| 4 | XIPS-25 orbit raising | 1193 | 348 | 19 | 206.2 | 4 |
| 5 | NSTAR | 1224 | 396 | 22 | 187.6 | 8 |

High energy, 20 000 m/s:

| rank | thruster | initial mass kg | propellant kg | tank kg | days | units |
|---|---|---|---|---|---|---|
| 1 | HiPEP | 1120 | 245 | 13 | 499.3 | 1 |
| 2 | NEXT PM1 | 1363 | 525 | 29 | 523.9 | 2 |
| 3 | T6 | 1380 | 521 | 29 | 451.4 | 4 |
| 4 | XIPS-25 orbit raising | 1533 | 670 | 37 | 397.0 | 4 |
| 5 | MAI lithium AF-MPD 32 kW | 1563 | 653 | 10 | 384.2 | 1 |

This is the one case where the comparison gives a clear and stable answer. High-Isp gridded
ion thrusters take the top four places at both delta-v levels, the ordering does not change
between them, and it survived both the sensitivity cases and the addition of tankage. The
probe is small enough that propellant is a large share of the vehicle, which is precisely the
regime where specific impulse decides the outcome.

The practical recommendation differs from the raw ranking. HiPEP ranks first but was
cancelled with the Jupiter Icy Moons Orbiter in 2005 and has no flight heritage [S04]. NEXT
and T6 are second and third at a cost of 10 and 12 percent in initial mass, and both are
qualified hardware, with T6 flying on BepiColombo [S26] and NEXT having completed its
ground qualification [S02]. For a 500 kg probe the defensible choice is NEXT or T6.
## Krypton against xenon on matched hardware

The dataset carries three measured krypton operating points. Two of them have a xenon control
on the same thruster in the same facility, measured in the same campaign, so for those two the
propellant can be compared without going through a correction factor. The third, the SPT-100
at 393 V, comes from a separate life-test paper [S31] and has no condition-matched xenon run;
where it is set against xenon below it is against the 302 V nominal control from [S30], which
differs in discharge voltage and flow as well as propellant.

Tankage decides this comparison, and it decides it against krypton.

500 kg probe, nominal:

| thruster | propellant | propellant kg | tank kg | initial mass kg | days |
|---|---|---|---|---|---|
| BHT-1500-C | xenon | 758 | 42 | 1639 | 152.3 |
| BHT-1500-C | krypton | 735 | 130 | 1700 | 212.0 |
| SPT-100 nominal | xenon | 1118 | 61 | 2014 | 170.7 |
| SPT-100 nominal | krypton | 1247 | 220 | 2302 | 249.7 |

Crewed Mars nominal:

| thruster | propellant | tank kg | initial mass kg | days |
|---|---|---|---|---|
| BHT-1500-C | xenon | 3 445 | 206 084 | 124.6 |
| BHT-1500-C | krypton | 10 389 | 209 275 | 161.4 |
| SPT-100 nominal | xenon | 4 809 | 232 247 | 126.3 |
| SPT-100 nominal | krypton | 15 850 | 245 694 | 170.9 |

Krypton loses on initial mass in every pair on both missions, by 3.7 and 14.3 percent on the
probe and 1.5 and 5.8 percent on Mars, and it loses on time by 30 to 46 percent as well. The
mechanism is visible in the tank column: krypton's tank is three times xenon's for a similar
propellant load, because it stores at 650 against 1600 kg/m3 and at 200 against 150 bar, so it
pays on both terms of the tank relation.

This reverses what the comparison said before tankage was modelled. Without a tank, krypton
won on mass in all four pairings, by 1.7 to 3.1 percent, and the earlier version of this
document flagged tankage as the one thing that could overturn that result. It did. The
propellant-only picture, where krypton's higher specific impulse buys a smaller propellant
load, is real but is not what the vehicle sees.

Where the time cap binds the two effects point the same way. On the fast Mars mission all
three krypton rows fail the 210-day limit, and so now does the SPT-100 xenon control at 224.0
days, which passed at 202.4 before its tank was charged against it. Only the BHT-1500-C xenon
survives among the matched set, at 199.6 days.

Two things still keep this from being the last word. The tank model is first-order: it carries
no boil-off hardware, no feed system, and no square-cube advantage for a large tank over a
small one, and its effective wall strength is calibrated against a single xenon anchor rather
than derived. And krypton reaches no higher than fifteenth on the probe and enters no Mars
top six, so the question it settles is a sub-ranking among Hall thrusters rather than the
choice of propulsion for either mission.

`docs/figures/krypton_vs_xenon.png` plots the pairs across all three missions in initial mass,
tank mass and thrusting time, with the rows that fail their time cap drawn pale.


## Agreement between the implementations

The Scala and Julia pipelines implement the relations separately rather than sharing code.
The Julia test suite joins both producers' rows in the `results` table and requires
agreement to 1e-9 relative. All 124 rows agree on initial mass, propellant mass, tank mass,
trip time, thruster count and feasibility. 1592 Julia tests and 44 Scala self-tests pass, and
SQL validation reports no errors over 17 checks.

The Lean development proves the relations the comparison uses, including
`propellantMassFraction_mem_Ico`, the statement that the propellant mass fraction lies in
`[0, 1)`, and `propellantMassFraction_lt_of_isp_lt`, which is what licenses ranking by
specific impulse. The tankage section adds `inertMassWithTank_fixed_point`, that the closed
form really solves the fixed point, `inertMassWithTank_pos`, that a vehicle closes exactly
when `f (MR - 1) < 1`, and `tankMassFraction_lt_of_density_lt`, that denser storage means a
lighter tank, which is krypton's problem stated formally, and `tankCloses_iff_lt_max`, that a
vehicle closes exactly when its tank fraction is below 1/(MR-1). All 32 theorems depend only on
Lean's three standard axioms.

One gap between the proof and the code is worth recording. The mass-fraction bound is
strict over the reals, but in Float64 the fraction rounds to exactly 1.0 once delta-v over
exhaust velocity passes about 37, which would mean an infinite mass ratio. The pipelines cap
the mass ratio at 1e6, corresponding to a ratio near 13.8, so they never approach it. A test
in `julia/Propulsion/test/runtests.jl` pins both facts so the gap cannot close silently.

## Sensitivity

`scripts/sensitivity.jl` recomputes the rankings with the four unmeasured assumptions varied:
power plant specific mass, thruster dry mass, the tank wall's effective specific strength,
and the tank structural floor. The first three move by roughly a factor of two in each
direction and are swept against the electric candidates. The floor runs from half to four
times its assumed value and is swept against the nuclear thermal rows, where it carries 94
percent of the tank fraction.

For the crewed Mars nominal mission, halving power plant specific mass from 20 to 10 kg/kW
drops HiPEP's initial mass from 153 t to 131 t. Doubling it to 40 kg/kW removes HiPEP from
the feasible set entirely, because the extra propellant pushes its thrusting time past the
365-day cap, and the MAI 200 kW lithium MPD inherits first place at 213 t. A factor of two in
a quantity nobody has measured is enough to unseat the first-ranked candidate.

Varying thruster specific mass from 2 to 10 kg/kW moves HiPEP's initial mass from 147 t to
164 t, and it does change the order beneath it. At 10 kg/kW NSTAR rises to second at 175 t,
because its sourced 8.2 kg dry mass [S28] is immune to the assumption while every
assumed-mass candidate grows around it; the MAI 200 kW lithium thruster drops to third at
176 t, with T6 and NEXT at 179 and 180 t behind it.

Tank strength matters most to whichever propellant stores worst. Doubling the effective wall
strength halves the pressure term and leaves the structural floor alone, so xenon goes from
5.5 to 3.0 percent and argon from 33.6 to 17.6, while unpressurised lithium and iodine do not
move at all. That is enough to bring VASIMR back into the Mars top five at fourth place on
167 t; halving the wall strength leaves VASIMR out and pushes T6's tank from 1.4 t to 2.7 t.
Argon's position is therefore a statement about the tank assumption rather than about the
thruster.

The probe rankings do not move under any of the three electric knobs. HiPEP, NEXT, T6 and
XIPS-25 hold the top four places across every combination tried. The probe conclusion can be
relied on; the crewed Mars conclusion cannot.

### Nuclear thermal and the tank structural floor

The wall-strength sweep above is the wrong knob for nuclear thermal propulsion, and seeing
why is itself the result. The tank relation has two terms, and which one dominates depends
entirely on storage density:

| propellant | storage | pressure term | floor term | total |
|---|---|---|---|---|
| liquid hydrogen | 70.85 kg/m3, 1 bar | 0.0075 (6.2%) | 0.1129 (93.8%) | 0.1204 |
| xenon | 1600 kg/m3, 150 bar | 0.0500 (90.9%) | 0.0050 (9.1%) | 0.0550 |

They are mirror images. Xenon's tank is a pressure vessel and responds to wall strength;
hydrogen's is a thin-walled box around a very large volume, and 94 percent of its mass comes
from the structural and insulation floor. Changing the wall strength barely moves a nuclear
thermal vehicle. Changing the floor decides whether it exists.

`scripts/sensitivity.jl` sweeps the floor from 4 to 32 kg/m3 against the three nuclear
thermal rows. The two crewed missions behave completely differently.

On the nominal mission, at delta-v 7000 m/s and mass ratios near 2.2 to 2.4, nuclear thermal
is insensitive. Every engine still closes at 32 kg/m3, four times the assumed value, and the
closure limits sit at 50 to 58 kg/m3:

| engine | MR | kappa = 4 | kappa = 8 | kappa = 16 | kappa = 32 | closes while kappa < |
|---|---|---|---|---|---|---|
| NASEM reference NTP | 2.210 | 216 t | 233 t | 277 t | 448 t | 58.0 |
| Pewee | 2.327 | 229 t | 249 t | 303 t | 536 t | 52.8 |
| Phoebus-2A | 2.388 | 236 t | 258 t | 318 t | 593 t | 50.5 |

On the fast mission, at 15 000 m/s and mass ratios of 5.5 to 6.5, the same engines are
fragile. Doubling the floor to 16 kg/m3 does not make them heavier; it makes them
nonexistent.

| engine | MR | kappa = 4 | kappa = 8 | kappa = 16 | closes while kappa < |
|---|---|---|---|---|---|
| NASEM reference NTP | 5.471 | 690 t | 1067 t | does not close | 15.3 |
| Pewee | 6.111 | 817 t | 1431 t | does not close | 13.3 |
| Phoebus-2A | 6.458 | 893 t | 1696 t | does not close | 12.4 |

Phoebus-2A stops closing at 12.4 kg/m3, which is 1.55 times the assumed floor. The
fast-mission nuclear thermal numbers reported earlier in this document therefore sit inside a
factor of about 1.5 of a cliff, on a parameter this project chose rather than measured.

The reason the two missions diverge is the closure condition itself. A vehicle closes while
its tank fraction stays below `1/(MR - 1)`, so the tolerable fraction collapses as delta-v
rises: 0.83 at the nominal mass ratio against 0.18 at the fast one. Lean states this as
`tankCloses_iff_lt_max`, and `tankCloses_bound_antitone` gives the monotonicity that makes a
faster mission strictly less forgiving. Hydrogen's 0.12 is comfortable against the first and
close to the second.

The same sweep run against the two probe missions completes the picture, and it explains a
result reported earlier in this document. A nuclear thermal engine pushing a 500 kg payload
is not a design: the model excludes engine dry mass, and a Rover-class reactor masses tonnes
against that payload, so these rows say something about the tank model rather than about a
vehicle anyone would build. What they say is worth having, because they are the tightest
closure margins in the study.

| mission | MR range | closes while kappa < | margin at the baseline 8 kg/m3, kcrit/8 |
|---|---|---|---|
| Crewed Mars, nominal | 2.21 to 2.39 | 50.5 to 58.0 | closes, 6.3 to 7.3 times margin |
| 500 kg probe, nominal | 3.90 to 4.45 | 20.0 to 23.9 | closes, 2.5 to 3.0 times margin |
| Crewed Mars, fast | 5.47 to 6.46 | 12.4 to 15.3 | closes, 1.6 to 1.9 times margin |
| 500 kg probe, high energy | 9.64 to 12.03 | 5.9 to 7.7 | does not close, 0.74 to 0.96 times margin |

The ordering is monotone in mass ratio, which is `tankCloses_bound_antitone` restated in
kilograms: every increase in delta-v tightens the tolerable tank fraction, and hydrogen's
0.1204 crosses the line somewhere between the fast Mars mission and the high-energy probe.

The high-energy probe is where the model is at its least trustworthy. The best of the three
engines, the NASEM reference at mass ratio 9.64, tolerates a floor up to 7.67 kg/m3 against
the 8.0 assumed. It fails by four percent. Those are the three infeasible rows on that
mission noted earlier: they are not a physical conclusion, they are a chosen constant landing
just the wrong side of a threshold. At 4 kg/m3 all three close, the NASEM reference at 10.8 t
on a 500 kg payload.

On the probe's nominal mission the margin is real but not large. All three engines close at
the baseline, at 3.0 to 3.8 t, and all three stop closing by 32 kg/m3; doubling the floor to
16 raises initial mass by 101 to 199 percent.

What does not change under any of this is the ranking. Nuclear thermal is heavier than the
leading electric candidate on all four missions across the whole range swept, including at the
optimistic 4 kg/m3: 216 t against HiPEP's 153 t on the nominal Mars mission, 690 t against
HERMeS AEPS at 452 t on the fast one, 2.4 t against 1.0 t on the nominal probe and 10.8 t
against 1.1 t on the high-energy probe. The sensitivity moves nuclear thermal between
"expensive" and "impossible", never into contention on mass. Its case rests on trip time,
which this comparison does not evaluate for it.

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
| Mars fast | X3 nested-channel Hall | 60 | 3525 |
| Mars nominal | MAI lithium AF-MPD 200 kW | 10 | 2560 |
| Mars nominal | X3 nested-channel Hall | 20 | 2349 |
| Mars nominal | VASIMR VX-200 | 10 | 2318 |
| Mars fast | HERMeS AEPS | 480 | 419 |
| Mars nominal | HiPEP | 81 | 156 |
| Mars nominal | NEXT PM1 | 289 | 91 |
| Mars nominal | PPS-1350-G | 1333 | 59 |
| Mars nominal | NSTAR | 860 | 41 |

The throughput actually demonstrated is far below all of this. The best-qualified figure in
the dataset is the SPT-100, validated past 2.71 MN·s of total impulse, about 9000 hours at its
nominal condition [S31]; at its measured 1511 s that is roughly 183 kg of xenon per thruster.
The PPS-1350-G accumulated 82 kg over about 5000 hours in flight on SMART-1 [S01]. The
candidates that need fewest units, and that look best on mass, are the ones requiring one to
two orders of magnitude more throughput per unit than those figures, from hardware whose life
has never been characterised: the X3 at 2349 kg per unit, with cathodes drawing 247 A that are
a research item rather than a product [S08], and the lithium MPD thrusters at 2560 kg per unit,
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

The tank model is first-order. It sizes a thin-walled pressure vessel plus a structural floor
and calibrates the wall strength against a single xenon anchor; it carries no boil-off
hardware, no feed system, no mounts, and no square-cube advantage for a large tank over a
small one. It is enough to show that tankage reverses the krypton comparison, and not enough
to size a real tank.

Its weakest number is the 8 kg/m3 structural floor, which is calibrated against nothing. For
xenon that hardly matters, since the floor is 9 percent of the tank. For liquid hydrogen it
is 94 percent of it, and the sensitivity above shows the fast-mission nuclear thermal rows
stop closing somewhere between 12 and 16 kg/m3. A measured dry mass for a long-duration
liquid hydrogen tank, with insulation and boil-off hardware included and the boundary stated,
would replace a guess that currently decides whether an entire propulsion class appears in
the fast-mission results at all.

Iodine appears in the propellants table and in the survey but contributes only the NPT30-I2,
a 1 mN cubesat thruster that clears both probe missions and fails both crewed Mars missions
on the trip-time cap, needing 466 days against the 365-day limit and 768 against the 210-day
one; there is no kilowatt-class iodine operating point to add, because none has been
published [S11].

Argon is represented only by VASIMR, which is a 200 kW laboratory device run in one-to-two
minute pulses [S15]. It ranked second on crewed Mars nominal before tankage was charged
against it and is now outside the top six on a 33.6 percent tank fraction, so its position is
as much a statement about the tank model as about the thruster. Its performance figures rest
on a peak point rather than anything sustained, and the longest continuous run of the
follow-on hardware was 88 hours at 80 kW [S16].
