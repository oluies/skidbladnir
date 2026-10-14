# skidbladnir

Quantitative comparison of candidate space propulsion systems for two reference missions:
a crewed Mars transfer and a 500 kg deep-space probe.

## Layout

    docs/survey.md      literature survey, cited, with open problems per propulsion class
    docs/findings.md    results, ranked candidates, remaining unknowns
    sql/schema.sql      DuckDB schema and COPY loaders
    data/raw/*.csv      raw inputs, version controlled
    data/propulsion.duckdb   built artifact, not version controlled
    scala/              Mill module: ingestion, SQL validation, typed dataset, results writer
    julia/Propulsion/   numerical models, plots, unit tests
    lean/               Lean 4 + Mathlib formalisation of the relations used

## Languages

Julia for numerical models and plotting. Scala 3 with Mill for ingestion, validation and the
comparison pipeline. Lean 4 with Mathlib for the formal statements and proofs. DuckDB for all
storage, reached from Scala over JDBC and from Julia via DuckDB.jl. No Python.

## Building the database

    duckdb data/propulsion.duckdb < sql/schema.sql
