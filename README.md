# skidbladnir

Quantitative comparison of candidate space propulsion systems for two reference missions:
a crewed Mars transfer and a 500 kg deep-space probe.

Start with `docs/survey.md` for the cited literature review and `docs/findings.md` for the
results and what they rest on.

## Layout

    docs/survey.md      literature survey, cited, with open problems per propulsion class
    docs/findings.md    results, ranked candidates, remaining unknowns
    docs/figures/       plots produced by the Julia pipeline
    sql/schema.sql      DuckDB schema, constraints, views and COPY loaders
    data/raw/*.csv      raw inputs, version controlled
    data/propulsion.duckdb   built artifact, not version controlled
    scala/              Mill module: typed dataset, SQL validation, comparison pipeline
    julia/Propulsion/   numerical models, plots, unit tests
    lean/               Lean 4 and Mathlib formalisation of the relations used
    scripts/            pipeline and sensitivity entry points

## Languages

Julia for numerical models and plotting. Scala 3 with Mill for ingestion, validation and the
comparison pipeline. Lean 4 with Mathlib for the formal statements and proofs. DuckDB for all
storage, reached from Scala over JDBC and from Julia via DuckDB.jl. No Python.

Dependencies outside the standard libraries are DuckDB.jl, DataFrames.jl, Plots.jl, the
DuckDB JDBC driver and Mathlib.

## Running everything

    # 1. build the database from the CSVs
    duckdb data/propulsion.duckdb < sql/schema.sql

    # 2. Scala: validate and run the comparison
    cd scala
    mill pipeline.runMain propulsion.Verify          # assertion-based self-tests
    mill pipeline.runMain propulsion.Main validate   # SQL range and consistency checks
    mill pipeline.runMain propulsion.Main compare    # writes producer 'scala'
    mill pipeline.runMain propulsion.Main report     # ranked table
    cd ..

    # 3. Julia: models, metrics and figures
    julia --project=julia/Propulsion julia/Propulsion/test/runtests.jl
    julia --project=julia/Propulsion scripts/run_julia_pipeline.jl   # writes producer 'julia'
    julia --project=julia/Propulsion scripts/sensitivity.jl

    # 4. Lean: build the proofs and confirm no sorry
    cd lean
    lake build
    lake env lean check_axioms.lean
    cd ..

The database path is found by walking up from the working directory, so the Scala and Julia
entry points work from anywhere in the tree. Set `PROPULSION_DB` to override.

## How the three implementations relate

The same relations are implemented three times on purpose. Scala and Julia implement them
independently, and the Julia test suite joins both producers' rows in the `results` table and
requires agreement to 1e-9 relative, so a mistake in one shows up as a disagreement rather
than as a plausible wrong answer. Lean states and proves the relations, including the
mass-fraction bound the comparison depends on. Each Scala and Julia function names the Lean
declaration it corresponds to.
