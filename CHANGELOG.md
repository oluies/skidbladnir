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
