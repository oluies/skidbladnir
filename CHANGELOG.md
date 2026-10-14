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
