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
