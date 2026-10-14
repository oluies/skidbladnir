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
