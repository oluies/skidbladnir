# Changelog

## 2026-10-15

### Task 1: literature survey
- Added docs/survey.md. Covers gridded ion, Hall-effect, MPD and VASIMR, nuclear thermal,
  nuclear electric, and propellant alternatives (xenon, krypton, iodine, lithium, hydrogen).
- 26 sources, tagged S01 to S26. Tags are the primary keys used later by the sources table,
  so a number in the prose traces to the row the pipeline reads.
- Open problems recorded per class.
- Performance numbers were taken from the primary documents where they could be read directly.
  The flight ion and Hall figures come from the tables in Goebel and Katz chapter 9, extracted
  from the JPL PDF rather than from secondary summaries.
- Thruster dry mass is missing from most sources. Those fields are left empty rather than
  estimated, and the gap is carried forward as a named unknown.

### Project setup
- git repository initialised, .gitignore excludes data/*.duckdb (rebuilt from CSV + schema),
  Mill out/, Lean .lake/, and Julia Manifest.toml.
- Lean toolchain installed via elan (leanprover/lean4:v4.35.0) with Mathlib pinned to v4.35.0.

### Task 2: DuckDB schema and raw data
- Added sql/schema.sql: tables for sources, propellants, missions, thrusters and results,
  with CHECK constraints on ranges and enumerations and foreign keys between them.
- Added data/raw/{sources,propellants,missions,thrusters}.csv, loaded by COPY from schema.sql.
- 26 thrusters, of which 25 are flown or ground-tested: 12 gridded ion, 7 Hall, 3 lithium
  applied-field MPD, 1 VASIMR, 3 nuclear thermal. 29 sources, 6 propellants, 4 missions.
- Two columns exist because the data forced them. mass_basis records how a dry mass was
  obtained, and is 'unknown' for 24 of 26 rows because the cited sources do not give one.
  power_basis separates electrical input power from reactor thermal power so the two are
  never mixed in a power-limited calculation.
- derived_fields names any column computed for self-consistency rather than quoted, so a
  derived number is never mistaken for a measurement.
- Added v_thruster_consistency, which recomputes efficiency from the quoted thrust, Isp and
  power. Source-quoted rows disagree with their own quadruple by up to 0.075 absolute
  (PPS-1350-G), which is publication rounding and mixed efficiency definitions rather than
  error. This sets the validation tolerance used in task 3.

### Task 3: Scala Mill module
- Added scala/build.mill, a single ScalaModule on Scala 3.10.0 with one dependency,
  org.duckdb:duckdb_jdbc:1.5.6.0, matching the DuckDB CLI that writes the file.
- No test framework. propulsion.Verify runs 26 assertion-based checks from a main class so
  the module stays inside the agreed dependency budget.
- Db locates data/propulsion.duckdb by walking up from the working directory, because Mill
  runs tasks from scala/ rather than the repository root. PROPULSION_DB overrides.
- Typed dataset in Model.scala and Dataset.scala. Nullable columns are Option, so an absent
  dry mass stays absent instead of becoming 0.0.
- Validation.scala holds 17 SQL checks, 14 of them errors and 3 warnings. The efficiency
  consistency check recomputes T*g0*Isp/(2P) and fails above 0.10 absolute residual.
- Current state: 0 errors, 30 warnings. 26 of the warnings are dry_mass_unknown, which is the
  dataset telling the truth about the literature rather than a defect.
- Comparison.scala states its assumptions as named constants and writes them into the results
  table: power plant specific mass of 20 kg/kW nuclear and 12 kg/kW solar, and a 5 kg/kW
  fallback for thruster plus power processing dry mass.
- Nuclear thermal rows get rocket-equation results only. Reactor thermal power is not
  electrical input power, so trip time is left NULL rather than computed from a model that
  does not apply.
- 104 result rows written (4 missions x 26 thrusters), 86 feasible.
- Numeric output is formatted under Locale.ROOT so it does not change with the shell locale.

### Task 4: Julia package
- Added julia/Propulsion: physics relations, delta-v budgets, the comparison, DuckDB
  round-trip and plotting. Dependencies are DuckDB.jl, DataFrames.jl, Plots.jl and three
  standard library packages.
- DuckDB.jl 1.5.2 reads the file written by the DuckDB 1.5.6 CLI without trouble.
- DELTA_V_BUDGETS breaks each mission's single delta-v figure into named legs, and a test
  checks every budget sums to the value held in the missions table.
- The physics relations are implemented independently of the Scala versions rather than
  shared, so that agreement between them carries information. The test suite joins the two
  producers' rows in the results table and requires them to match to 1e-9 relative. They do,
  across all 104 rows.
- 878 tests pass.
- One test documents a real limit. The mass-fraction inequality is strict over the reals and
  is proved that way in Lean, but in Float64 the fraction rounds to exactly 1.0 once dv/ve
  passes about 37. The comparison's MAX_MASS_RATIO of 1e6 corresponds to dv/ve near 13.8, so
  the models stay well clear of it. The test pins both facts.
- Four figures written to docs/figures: trip time, initial mass, propellant mass and the
  specific impulse against trip time trade. Bars are linear, not logarithmic, because a bar
  starts at zero. Nuclear thermal rows are absent from the trip-time figure by construction.
- Figures are committed rather than ignored, because docs/findings.md refers to them.

### Task 5: Lean formalisation
- Added lean/Propulsion/Basic.lean on Lean 4 v4.35.0 with Mathlib pinned to the matching tag.
- 11 definitions and 21 theorems, all proved, no sorry anywhere.
- Definitions: g0, exhaustVelocity, specificImpulse, massRatio, propellantMassFraction,
  initialMass, propellantMass, inputPower, thrustFromPower, massFlow, transferTime.
- The headline result is propellantMassFraction_mem_Ico: for non-negative delta-v and
  positive exhaust velocity the propellant mass fraction lies in [0, 1), with the upper
  bound strict. That strictness is what guarantees a finite initial mass for any mission.
- propellantMassFraction_lt_one needs no hypotheses at all, because exp is positive
  everywhere. The real content of the comparison's feasibility test is therefore the
  trip-time constraint, not the mass bound.
- propellantMassFraction_lt_of_isp_lt is the fact that justifies ranking candidates by
  specific impulse: raising Isp strictly lowers the propellant mass fraction.
- power_thrust_isp states the identity that v_thruster_consistency checks in SQL.
- lean/check_axioms.lean reports the axiom dependencies of all 21 theorems. Each depends on
  exactly [propext, Classical.choice, Quot.sound] and none on sorryAx.
- Comments in Physics.scala now cite the Lean declaration names that actually exist.

### Task 6: findings
- Added docs/findings.md with results queried from DuckDB, ranked candidates for all four
  missions, cross-implementation agreement, a sensitivity study and the three unknowns.
- Added scripts/sensitivity.jl, which recomputes the rankings with the two unmeasured mass
  assumptions varied by a factor of two in each direction. Nothing it computes is written
  to the database.
- Exported alpha_for_source from the Julia module so the sensitivity script can reach it.
- Results. The probe answer is stable: high-Isp gridded ion thrusters take the top five
  places at both delta-v levels and the ordering survives every sensitivity case. NEXT or T6
  is the defensible pick, since HiPEP ranks first but was cancelled in 2005 and has no
  flight heritage.
- The crewed Mars answer is not stable. At 2 MWe and 20 kg/kW the power plant and payload
  fix 130 t of the vehicle before a thruster is chosen, the whole feasible set spans a
  factor of 1.76, and doubling the specific-mass assumption removes the top-ranked candidate
  from the feasible set altogether.
- On the fast Mars mission every gridded ion thruster, every MPD thruster and VASIMR fail,
  all on time rather than mass, because power-limited thrusting time grows with the square
  of exhaust velocity at fixed power.
- The third unknown inverts the recommendation. The candidates that look best on mass need
  2200 to 3400 kg of propellant throughput per unit, against the single in-flight figure in
  the dataset of 82 kg for the PPS-1350-G.

### Verification
Full rebuild from a clean database passes end to end: schema loads, 26 Scala self-tests
pass, validation reports 0 errors over 17 checks, both pipelines write 104 rows with 86
feasible, 878 Julia tests pass including agreement with the Scala rows to 1e-9 relative,
four figures render, Lean builds and all 21 theorems report only the three standard axioms.

## 2026-10-15 (later)

### Krypton thruster data from measured operating points
- Added three measured krypton operating points, two of them with a xenon control taken on the
  same thruster in the same campaign, so the propellant can be compared without a correction
  factor. Thruster count goes from 26 to 31, result rows from 104 to 124, feasible from 86
  to 103.
- spt100_kr_390v is the strongest row in the whole dataset: thrust 86.7 mN, Isp 1966 s, power
  1977 W and total efficiency 0.423 are all measured, and they agree with each other to
  0.00025 in efficiency. Taken from the 205-hour krypton life test of a flight-model SPT-100.
- spt100_kr_nom and spt100_xe_nakles are the nominal-condition pair from the same programme.
  The derived xenon thrust of 80.2 mN reproduces the 80 mN flight figure quoted independently
  in S01, which checks the derivation method used for every derived thrust in the dataset.
- bht1500c_kr and bht1500c_xe are the Busek pair, the best krypton point reported and its
  nearest matched xenon condition.
- New sources S30 (IEPC-2011-003), S31 (IEPC-2013-347 life test) and S32 (Linnell and
  Gallimore, JPP 2006). S12 updated with authors and the BHT-1500-C designation.
- All five rows pass the efficiency consistency check with residuals below 0.0003.

### What the krypton data shows
- Krypton wins on mass in every matched pair and loses on time in every one: 3.1 percent less
  initial mass and 24 percent more thrusting time for the BHT-1500-C on crewed Mars nominal.
  At fixed available power, Isp sets propellant mass and efficiency sets thrust, so krypton's
  trade lands on different axes.
- Where the time cap binds the sign reverses. On the fast Mars mission all three krypton rows
  fail the 210-day limit while both xenon controls pass.
- The comparison carries no tank model, which is the one thing that could overturn this. For
  the probe, krypton saves 86 kg of propellant and asks for 2.2 times the tank volume.
- Krypton reaches no higher than fourteenth on the probe and enters no Mars top six. The
  headline recommendations are unchanged.
- The SPT-100 nominal pair shows the theoretical 25 percent Isp gain arriving as under 4
  percent: 1568 s against 1511 s on the same thruster.

### Documents and figures
- docs/survey.md krypton section rewritten around the measured points, with a table of the
  five rows and their provenance. Krypton open problems rewritten: the efficiency penalty is
  now measured rather than a range, but tankage and life remain open. The 205-hour test is
  the longest published krypton run and is about forty times short of the roughly 9000 hours
  validated on xenon for the same thruster.
- docs/findings.md gains a matched-hardware section, updated counts throughout, and a
  rewritten throughput unknown that now uses the SPT-100 qualified figure of 2.71 MN-s, about
  183 kg of xenon per thruster, as the anchor instead of the PPS-1350-G flight accumulation.
- New figure docs/figures/krypton_vs_xenon.png plots the pairs across three missions with
  time-cap failures drawn pale.
- Sensitivity conclusions are unchanged; the new rows enter no top five in any case tried.

### Review 1972 corrections
- The claim that all three krypton points had a matched xenon control was wrong. Only two do,
  the BHT-1500-C and the SPT-100 at its nominal condition. The SPT-100 at 393 V comes from the
  separate life-test paper and has no condition-matched xenon run; where it is set against
  xenon it is against the 302 V nominal control, which differs in voltage and flow as well as
  propellant. Corrected in findings.md, survey.md, CHANGELOG and the plots.jl docstring.
- "All three xenon controls pass" on the fast Mars mission corrected to both of them.
- VASIMR is second on crewed Mars nominal, not third. The ranking table was right and the
  prose was wrong.
- The NPT30-I2 clears both probe missions and fails the two Mars missions on the trip-time
  cap, 466 days against 365 and 768 against 210. It was described as failing both reference
  missions on thrust, and the model has no thrust constraint.
- The 205-hour krypton test is about forty times short of the roughly 9000 hours validated on
  xenon, not two orders of magnitude. Two orders would need the 50 kh design life, which is
  not the anchor these documents use.
- The one-third krypton storage density (S12, 14 MPa and 50 C) and the 2.2 times volume
  computed from the propellants table (650 against 1600 kg/m3 at 293 K) are at different
  conditions. Both now say so, so the tankage argument reads consistently.
- plots.jl: hoisted the duplicated horizontal bar panel into hbar_panel, shared by make_plots
  and make_krypton_plot, parameterised by colour column, colour map, topn and an optional
  alpha column. Figures are byte-for-byte equivalent. Fixed the stale "26 bars" docstring.

### Review 1973 corrections
- The krypton note in data/raw/propellants.csv still ended "each with a matched xenon
  control", the exact claim the previous commit corrected in four other places. The shipped
  data note was contradicting every document that reads from it. It now names which two
  krypton points have a control and says the 393 V point has none.
- The density reconciliation did not follow from its own numbers. 650 against 1600 kg/m3 is
  2.46 times the volume per kilogram, not 2.2; the 2.2 in the probe case only comes out that
  low because krypton also carries 12 percent less propellant. Survey, findings and the CSV
  note now give the two steps separately instead of presenting a per-kilogram density ratio
  as if it produced the per-case volume ratio.
- The fast-Mars paragraph cited only the unmatched SPT-100 comparison and omitted the second
  genuine pair. It now leads with both like-for-like pairs, BHT-1500-C at 225.8 against 186.8
  days and SPT-100 nominal at 251.3 against 202.4, and keeps the 393 V row as the explicitly
  weaker data point.

## 2026-10-15 (tank model)

### Propellant tankage charged against the vehicle
- The comparison now sizes a propellant tank and carries it in the inert mass. Previously it
  did not, and docs/findings.md named that as the one gap able to overturn a stated result.
  It did overturn it.
- Tank fraction is f = 1.5 P / (rho psi) + kappa / rho kg of tank per kg of propellant: a
  thin-walled pressure vessel plus a structural and insulation floor. psi, the effective wall
  specific strength, is calibrated once so xenon at 150 bar and 1600 kg/m3 lands near 5
  percent, where flown xenon tankage sits. Every other propellant then follows from its own
  density and pressure rather than a second free choice.
- Resulting fractions: xenon 5.5 percent, hydrogen 12.0, krypton 17.6, argon 33.6, lithium
  1.5, iodine 0.2.
- Because the tank is sized by the propellant and the propellant by the inert mass, the inert
  mass is a fixed point, m_f = base / (1 - f (MR - 1)), with a solution only while
  f (MR - 1) < 1. Past that the tank outweighs what the propellant buys back and no finite
  vehicle closes; such rows are marked infeasible rather than returned as a number.
- Added tank_mass_kg and tank_mass_fraction to the results table.

### What it changed
- Krypton now loses every matched pair on both missions, having won all four before. Its tank
  is three times xenon's for a similar propellant load, because it stores at 650 against 1600
  kg/m3 and at 200 against 150 bar, so it pays on both terms.
- VASIMR fell from second on crewed Mars nominal to outside the top six, on argon's 33.6
  percent tank fraction. The lithium MPD thrusters gained places for the opposite reason.
- Feasible combinations fell from 103 to 98 of 124.
- The probe ranking did not move. HiPEP, NEXT, T6 and XIPS-25 hold the top four at both
  delta-v levels and through every sensitivity case.

### Implementation
- Julia and Scala implement the tank model independently, as with the rest. All 124 rows
  agree to 1e-9 on initial mass, propellant mass, tank mass and trip time, with no
  feasibility mismatches.
- Lean gains 9 theorems: the closed form solves the fixed point, it is positive exactly when
  the vehicle closes, it is strictly increasing in tank fraction and never below the base, and
  the tank fraction is strictly decreasing in storage density and increasing in pressure. 30
  theorems total, all depending only on the three standard axioms, no sorry.
- Tests: 1560 Julia, 35 Scala. New Julia tests pin the divergence condition and assert the
  krypton reversal directly, so it cannot regress silently.
- scripts/sensitivity.jl now varies tank wall strength as a third axis. Doubling it brings
  VASIMR back into the Mars top five; halving it does not. Argon's position is a statement
  about the tank assumption rather than about the thruster.
- docs/figures/krypton_vs_xenon.png gains a tank mass column, which is the mechanism.

### Review 1975 corrections
- The fast-Mars nuclear thermal paragraph quoted pre-tank masses, 492/550/581 t. With
  hydrogen's 12.0 percent tank fraction charged the three rows are 1067, 1431 and 1696 t, and
  they rank seventh, eighth and ninth of nine rather than third, fifth and sixth. The lead
  sentence also claimed the rows were absent from a table ranked on a column they have, which
  made no sense; they are absent because they are the heaviest.
- The thruster dry mass sensitivity claim was false and had replaced a correct one. At
  10 kg/kW NSTAR rises to second at 175 t, because its sourced 8.2 kg dry mass is immune to an
  assumption that inflates every other candidate. Restored, and dropped the claim that the top
  of the order does not change.
- Doubling the tank wall strength halves the pressure term only; the structural floor is
  untouched. Xenon goes 5.5 to 3.0 percent and argon 33.6 to 17.6, while unpressurised lithium
  and iodine do not move. The script already did this correctly; only the prose was wrong.
- make_krypton_plot's docstring still described krypton as buying a lower initial mass, the
  conclusion the tank model reverses.
- All three lithium MPD rows gained a place under tankage, not two.
- compare_one and Comparison.compare each built four near-identical row literals. Both now
  build the row once and derive the branches by merge and copy, so a new results column is one
  edit per language rather than four.

### Test count determinism
The suite count moved between runs because the krypton reversal test queried the database for
this producer's rows, which may not exist yet on a fresh build. It now computes from the
in-memory results instead, so the count is stable: 1560 with the Scala rows present for the
cross-implementation check, 816 without.

### Review 1976 corrections
- scripts/sensitivity.jl still carried the claim the previous commit corrected in two
  documents, as a code comment: "a weaker tank wall doubles every tank fraction". psi_scale
  divides only the pressure term, so unpressurised lithium and iodine do not move at all.
  Reworded with the actual numbers.
- The Julia refactor had dropped the m0 and tank_mass locals and recomputed inert_mass * mr
  and f_tank * mp inline at each use, which reintroduced the duplication the refactor existed
  to remove and diverged from the Scala twin. Both branches now name the three locals, as
  Comparison.scala does.

## 2026-10-16

### Tank sensitivity for the nuclear thermal hydrogen case
- The existing wall-strength sweep is the wrong knob for nuclear thermal propulsion, and
  finding out why is the result. The tank relation has two terms and storage density decides
  which dominates. Liquid hydrogen at 70.85 kg/m3 takes 93.8 percent of its tank fraction
  from the structural floor and 6.2 from pressure; xenon at 1600 kg/m3 and 150 bar is the
  mirror image at 9.1 and 90.9. Wall strength barely moves a hydrogen vehicle. The floor
  decides whether it exists.
- scripts/sensitivity.jl gains an NTP section sweeping the structural floor from 4 to
  32 kg/m3 against all three nuclear thermal rows on both crewed missions, reporting tank
  fraction, initial mass, and the floor at which each engine stops closing.
- The two missions behave oppositely. On the nominal mission, at mass ratios near 2.2 to 2.4,
  every engine still closes at 32 kg/m3 and the limits sit at 50 to 58. On the fast mission,
  at mass ratios of 5.5 to 6.5, doubling the floor to 16 does not make the engines heavier,
  it makes them nonexistent. Phoebus-2A stops closing at 12.4 kg/m3, 1.55 times the assumed
  value.
- The reason is the closure condition: a vehicle closes while its tank fraction stays under
  1/(MR-1), which collapses from 0.83 at the nominal mass ratio to 0.18 at the fast one.
  Hydrogen's 0.12 is comfortable against the first and close to the second.
- What does not move is the ranking. Nuclear thermal is heavier than the leading electric
  candidate on both missions across the whole range swept, including at an optimistic
  4 kg/m3. The sweep moves it between expensive and impossible, never into contention on
  mass.

### Supporting work
- Added max_tank_fraction and critical_structural_floor in Julia, maxTankFraction and
  criticalStructuralFloor in Scala. The first turns the closure predicate into a number the
  sensitivity can compare against; the second inverts the tank relation to ask which floor a
  given engine tolerates.
- Lean gains tankCloses_iff_lt_max, that a vehicle closes exactly when f < 1/(MR-1), and
  tankCloses_bound_antitone, that a larger mass ratio tolerates strictly less tankage. 32
  theorems, all axiom-clean.
- Tests: 1585 Julia, 42 Scala. One pins a Float64 limit worth knowing. The closure boundary is
  exact over the reals and is not representable: at a tank fraction within rounding of the
  limit the denominator is a tiny positive number rather than zero, so the model returns an
  absurd mass rather than refusing. The test asserts the result is either nothing or above
  1e15 kg, and that every propellant actually used sits far from its limit.
- docs/findings.md gains the section, and the tank caveat now names the 8 kg/m3 floor as the
  model's weakest number: 9 percent of a xenon tank, 94 percent of a hydrogen one, and the
  thing that decides whether a whole propulsion class appears in the fast-mission results.

### Review 1989 corrections
- The two new closure helpers had been inserted between inert_mass_with_tank's docstring and
  its definition, which orphaned the docstring. Julia does not attach a docstring across a
  blank line, so it became a bare string literal: the module loaded, every test passed, and
  `?inert_mass_with_tank` silently returned nothing. The helpers now sit below the function.
  All three docstrings verified attached.
- docs/findings.md still carried the pre-commit counts, 1560 Julia / 35 Scala and 30
  theorems, against the actual 1585 / 42 / 32. The CHANGELOG entry under the 2026-10-15 tank
  model section still says 1560 / 35 and is left alone: it is dated history that was correct
  when written, not drift.
- The sensitivity section swept four parameters while describing three, in both the document
  and the script header. Both now name the structural floor as the fourth and say which knobs
  apply to which candidates.
- The probe paragraph had been stranded at the end of the new nuclear thermal subsection,
  where "any of the three" read as the floor sweep. Moved back above the subsection and
  qualified as the three electric knobs; the probe missions carry no hydrogen.
- The NTP sweep hardcoded the 8 kg/m3 baseline in four places while arguing that the floor
  should be retuned. It now reads TANK_STRUCTURAL_FLOOR_KG_PER_M3, sweeps half to four times
  that value rather than fixed numbers, and hoists the baseline mass out of the inner loop.
  Output is unchanged at the current constant.
- The NTP rows were selected by propellant rather than thruster_type. A future hydrogen
  electric row would have been printed under the nuclear thermal heading and sized without
  its power plant. Now filtered on thruster_type.
- Removed a duplicated comment line in the new testset.

### Review 1994 corrections
- The sensitivity intro said all four assumptions were "varied by a factor of two in each
  direction", but the structural floor is swept from half to four times its value, as the
  document's own table says two paragraphs later. The qualifier is now scoped: the three
  electric knobs move by roughly a factor of two, the floor from half to four times.
- The script header had a stray conjunction left from appending a fourth item to a
  three-item list.

### Probe missions added to the NTP tank sweep
- The structural-floor sweep now covers all four missions rather than the two crewed ones.
  The probe rows explain a result already in the comparison: the three infeasible rows on the
  high-energy probe are the three nuclear thermal engines, failing on tankage.
- Fragility is monotone in mass ratio, which is tankCloses_bound_antitone restated in
  kilograms. Tolerable floor by mission: crewed Mars nominal 50.5 to 58.0 kg/m3, probe
  nominal 20.0 to 23.9, crewed Mars fast 12.4 to 15.3, probe high energy 5.9 to 7.7.
  Hydrogen's 0.1204 fraction crosses the line between the last two.
- The high-energy probe is where the model is least trustworthy. The best engine, the NASEM
  reference at mass ratio 9.64, tolerates a floor up to 7.67 kg/m3 against the 8.0 assumed.
  It fails by four percent. Those rows are a chosen constant landing just the wrong side of a
  threshold, not a physical conclusion.
- Stated plainly in the script output and the document: a nuclear thermal engine pushing a
  500 kg payload is not a design. The model excludes engine dry mass and a Rover-class
  reactor masses tonnes against that payload. The rows are included because they are the
  tightest closure margins in the study, not because the vehicle is credible.
- The sweep output now reports the baseline mass per engine and prints a dash rather than a
  NaN in the comparison column when the baseline itself does not close.
- The ranking is unchanged on all four missions: nuclear thermal stays heavier than the
  leading electric candidate across the whole range swept, 2.4 t against 1.0 t on the nominal
  probe and 10.8 t against 1.1 t on the high-energy one.
- Tests: 1592 Julia, 44 Scala. New tests pin that all three nuclear thermal engines fall
  below the assumed floor on the high-energy probe, and that the best of them misses by a
  small margin rather than a large one.

### Review 2007 corrections
- The margin column in the new mission summary table read "4 to 7 times" for crewed Mars
  nominal. The other three rows are kcrit/8 exactly, and that row is 50.5/8 to 58.0/8, so
  6.3 to 7.3. The "4" matched no quantity in the model. Every row of the column is now
  kcrit/8, including the high-energy probe at 0.74 to 0.96, which is below one and is
  precisely why it does not close.
- README.md still annotated the Verify line with "26 self-tests" against the actual 44. This
  is the fourth count-drift finding in the session, so rather than re-syncing the number the
  annotations now describe what the commands check without counting: "assertion-based
  self-tests" and "SQL range and consistency checks". Precise counts stay in docs/findings.md
  and this file, where they are verification claims rather than usage notes.

### Review 2011 correction
- The last row of the mission summary table gave its margin as a bare "0.74 to 0.96" while
  the three rows above label the same quantity "times margin". Labelled, and the column
  header now names the quantity as kcrit/8 so the figure does not have to be inferred.

## 2026-10-17

### Nuclear thermal engine dry mass, and a units bug it exposed
- Found and fixed a 1000x error of my own. Phoebus-2A's thrust was recorded as 930000 mN,
  that is 930 N, from a source that says 930 kN. Nothing caught it: v_thruster_consistency
  only covers electrical rows, NTP thrust feeds no calculation, and no document quoted it.
  Corrected to 930000000 mN.
- Added v_ntp_consistency and an 18th validation check to close that gap. The nozzle converts
  reactor thermal power into jet power, so T*g0*Isp/2 can never exceed the reactor thermal
  power and in practice is a large fraction of it. Phoebus-2A corrected gives 0.916; the
  erroneous value gives 0.0009. Verified by negative test: reinstating the bad figure in a
  scratch database makes the check fail with exactly that ratio.
- Added ntp_nerva_derived, the 25 klbf Pewee-class dual turbopump expander cycle engine
  baselined in Mars DRA 5.0, from Borowski et al. (new source S33): 906 s, 2790 K core exit,
  1000 psi, 12.5 kg/s hydrogen, thrust-to-weight 3.50. Its engine dry mass of 3240 kg is
  derived from that ratio and is the only published route to an engine mass for this class.
- The comparison now charges engine dry mass in the non-electric branch, as it already did
  for the tank and power plant. 32 thrusters, 128 rows, 101 feasible.

### What it shows
- Only one of the four nuclear thermal rows carries an engine. Pewee and Phoebus-2A were
  reactor tests and the NASEM entry is a study reference point, so none of the three has an
  engine mass to charge and their initial masses stay optimistic by an unrecorded amount.
  Their notes now say "engine dry mass not recorded and excluded" rather than implying zero.
- At Mars scale 3.24 t of engine is small: the engine-carrying row lands within one percent
  of the NASEM reference. At probe scale it is not. On the nominal probe the NERVA-derived
  engine comes out at 22.0 t against 3.0 to 3.8 t for the rows that omit their engines, a
  factor of six, and 22 t of vehicle to move 500 kg of payload. The warning that an NTP
  engine on a probe is not a design is now visible in the results rather than only asserted.
- mass_kg joins the set of fields derived_fields may name, since the new row's mass is
  derived from a published thrust-to-weight rather than quoted directly.
- Tests: 1645 Julia, 44 Scala. A new test pins that recorded engine mass is charged, that the
  result matches payload-plus-engine sizing exactly, and that a row without one says so.

### Review 2019 corrections
- The worst of these was a split model, not stale prose. The results path charges engine dry
  mass; ntp_tank_sensitivity still sized on payload alone, so ntp_nerva_derived came out at
  22.0 t in the results table and 2.9 t in the sweep, and both numbers were published in
  docs/findings.md a few sections apart. The sweep now charges engine mass the way
  compare_one does and the two agree exactly at 22020 kg. Its printed caveat, which still
  claimed the model excludes engine dry mass, now says which rows carry an engine and which
  do not.
- The structural-floor sweep section had not been updated for the fourth nuclear thermal
  row, which the script had already started printing. Both engine tables gain the
  NERVA-derived row, the MR and kcrit ranges widen to 2.20-2.39 / 3.86-4.45 / 5.41-6.46 /
  9.50-12.03 and 50.5-58.6 / 20.0-24.2 / 12.4-15.5 / 5.9-7.8, and the document no longer says
  "three" in one place and "four" in another about the same set.
- On the high-energy probe the best engine is now the NERVA-derived row at mass ratio 9.50,
  tolerating 7.80 kg/m3 and missing the assumed floor by 2.4 percent rather than the NASEM
  reference missing by 4. The probe-nominal increase at kappa=16 is 97 to 199 percent.
- The new jet-power check could not see ntp_nerva_derived, which records no reactor power, so
  the thrust its 3240 kg mass is derived from was validated by nothing. That is the same gap
  the previous commit set out to close. Added v_ntp_engine_mass and a 19th check requiring the
  implied thrust-to-weight to lie between 1 and 10; the row gives exactly 3.500, matching its
  quoted ratio, and a negative test with the mass set to 324 kg fails the check at 34.999.
- Stale counts: docs/findings.md now says 3 of 32 thrusters record a dry mass, and the two
  code comments that counted rows are count-free, as README.md already was.
- The sweep is a script and no test covers it, which is why the split model went unnoticed.
  Worth knowing when reading its output.

### Review 2025 corrections
- The sweep no longer re-derives compare_one's sizing. It calls compare_one and prints the
  initial_mass_kg and tank_mass_kg it returns, so the sweep and the results table are the
  same calculation by construction rather than two copies kept in step by assertion. That
  duplication is what produced the 22.0 t against 2.9 t split the previous review caught,
  and the printed claim that the two match is now structural.
- Both test suites still pinned the superseded version of the claim: they iterated the Isp
  literals 900, 845 and 820, omitting the 906 s row that is in fact the tightest of the four
  and the one the published figure now quotes. Changing that row's Isp would have staled the
  document with every test green. Both suites now derive the engine list from the nuclear
  thermal rows in the dataset, assert that every one of them falls below the assumed floor on
  the high-energy probe, and check the best margin without naming which engine that is, so a
  fifth row cannot slip past and the test does not need editing when the ordering changes.
- The nominal-mission prose said closure limits sit at 51 to 59 kg/m3 while the table three
  lines below gives 50.5 as the lowest. Corrected to 50 to 59.
- Counts: 1648 Julia, 43 Scala. The Scala total falls by one because two hardcoded checks
  were replaced by a single dataset-driven one.

### Review 2037 correction
- The new Scala probe check claimed to mirror the Julia one but did not. Julia asserts
  through compare_one, exercising the comparison; Scala recomputed closure from
  Physics.inertMassWithTank directly. That helper decides None purely on
  1 - f*(mr-1) <= 0, so the payload-plus-engine base it was passed could not affect the
  result: dead weight that read as though engine mass mattered to closure. The coverage was
  one-sided, since a regression in the comparison propagating tankage divergence into
  initialMassKg would have failed the Julia suite and passed the Scala one. The Scala check
  now goes through Comparison.compare, the same path the results table takes.

## 2026-10-19

### A figure for the closure limit, and a figures section in the README
- Added docs/figures/ntp_tank_floor.png. A vehicle closes only while its tank fraction stays
  below 1/(MR-1), and liquid hydrogen's fraction is pinned near 0.120 by its storage density,
  so the mission's mass ratio alone decides whether a nuclear thermal vehicle exists. The two
  lines cross at mass ratio 9.30. The three missions below that all close; the high-energy
  probe at 9.50 to 12.03 does not, which is the whole of why its nuclear thermal rows are
  infeasible. The right panel repeats it in the structural-floor units the sweep varies,
  against the assumed 8 kg/m3.
- This was the most consequential result in the study with no picture: it lived only in
  tables in findings.md and in script output.
- README gains a Figures section carrying that plot and the krypton matched-pair plot with
  what each shows, and naming the other four. GitHub renders them from the repository, so
  the headline results are visible without running anything.
- Figure count is now 6; findings.md's figure list updated to match.
