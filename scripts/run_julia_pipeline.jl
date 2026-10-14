#!/usr/bin/env julia
#
# Run the Julia side of the comparison: load from DuckDB, compute metrics, write them back
# as producer 'julia', and render the figures into docs/figures/.
#
#     julia --project=julia/Propulsion scripts/run_julia_pipeline.jl

using Propulsion
using DataFrames
using Printf

con = connect_db()
try
    results = run_comparison(con)
    n = write_results!(con, results)
    @printf("comparison: %d rows written as producer 'julia'\n", n)
    @printf("  feasible combinations: %d of %d\n", count(results.feasible), nrow(results))

    repo = dirname(dirname(abspath(@__FILE__)))
    figures = make_plots(con, joinpath(repo, "docs", "figures"))
    println("figures:")
    for f in figures
        println("  ", relpath(f, repo))
    end
finally
    close_db(con)
end
