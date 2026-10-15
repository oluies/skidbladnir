# Plotting. Kept in a separate file so the numerical core can be read without it.
#
# GR is driven headless (GKSwstype=100) so this runs the same way in a terminal and in CI.

using Plots

const TYPE_COLOUR = Dict(
    "gridded_ion" => :steelblue,
    "hall" => :darkorange,
    "mpd" => :seagreen,
    "other_plasma" => :mediumpurple,
    "nuclear_thermal" => :firebrick,
)

const PROPELLANT_COLOUR = Dict(
    "krypton" => :mediumseagreen,
    "xenon" => :steelblue,
)

"""
    hbar_panel(sub, valuecol, title, xlabel; colour_by, colour_map, topn, alpha_by, titlefontsize)

One horizontal bar panel of `sub[!, valuecol]`, best at the top.

Shared by every bar figure in this file so the panel styling lives in one place. Rows whose
`valuecol` is missing are dropped, which is how nuclear thermal rows fall out of the
trip-time figure: the power-limited model does not produce a trip time for them.

`colour_by` names the column that selects a colour from `colour_map`. `topn` truncates to the
best n, since more than about a dozen bars on one panel is unreadable and the tail is
uninformative; pass `nothing` to keep them all. `alpha_by` names a Bool column drawn pale when
false, used to mark rows that fail their mission's time cap.

Bars are on a linear axis. A log axis would be natural for the spread but a bar starts at
zero, and log(0) is not a place an axis can start.
"""
function hbar_panel(sub, valuecol, title, xlabel;
                    colour_by::Symbol,
                    colour_map::AbstractDict,
                    topn::Union{Nothing,Int} = nothing,
                    alpha_by::Union{Nothing,Symbol} = nothing,
                    titlefontsize::Int = 9)
    keep = sub[.!ismissing.(sub[!, valuecol]), :]
    if nrow(keep) == 0
        return plot(; title = title, titlefontsize = titlefontsize, framestyle = :box,
                    showaxis = false, grid = false, legend = false)
    end
    sorted = sort(keep, valuecol)
    topn === nothing || (sorted = first(sorted, topn))
    vals = Float64.(sorted[!, valuecol])
    labels = String.(sorted.thruster_name)
    cols = [get(colour_map, k, :grey) for k in sorted[!, colour_by]]
    alphas = alpha_by === nothing ? 1.0 : [v === true ? 1.0 : 0.45 for v in sorted[!, alpha_by]]
    n = length(vals)
    bar(
        1:n, vals;
        orientation = :h,
        yticks = (1:n, labels),
        yflip = true,
        ylims = (0.4, n + 0.6),
        legend = false,
        color = cols,
        fillalpha = alphas,
        linewidth = 0,
        title = title,
        xlabel = xlabel,
        titlefontsize = titlefontsize,
        tickfontsize = 7,
        guidefontsize = 8,
        grid = :x,
    )
end

"""
    make_plots(con, outdir; producer="julia", topn=12) -> Vector{String}

Write the comparison figures and return the paths written.

Three quantities are plotted per mission: trip time, initial mass and propellant mass.
Only the best `topn` candidates per mission appear, ranked by the quantity being plotted,
because 31 bars on one panel is unreadable and the tail is uninformative.

Nuclear thermal rows appear in the mass plots and are absent from the trip-time plot,
because the power-limited model that produces a trip time does not apply to them. That
absence is the point rather than a gap to be filled.
"""
function make_plots(con, outdir::AbstractString;
                    producer::AbstractString = "julia", topn::Int = 12)
    ENV["GKSwstype"] = "100"
    gr()
    mkpath(outdir)

    df = query_db(con, """
        SELECT r.*, m.name AS mission_name, m.mission_id AS mid,
               t.name AS thruster_name, t.thruster_type, t.propellant
        FROM results r
        JOIN missions m ON m.mission_id = r.mission_id
        JOIN thrusters t ON t.thruster_id = r.thruster_id
        WHERE r.producer = '$producer' AND r.feasible
        ORDER BY r.mission_id, r.initial_mass_kg
    """)

    written = String[]
    missions = unique(df.mid)

    specs = [
        (:trip_time_days, "trip_time", "Thrusting time", "days"),
        (:initial_mass_kg, "initial_mass", "Initial mass", "kg"),
        (:propellant_mass_kg, "propellant_mass", "Propellant mass", "kg"),
    ]

    for (col, slug, title, xlabel) in specs
        panels = Any[]
        for mid in missions
            sub = df[df.mid .== mid, :]
            name = first(sub.mission_name)
            push!(panels, hbar_panel(sub, col, "$title — $name", xlabel;
                                     colour_by = :thruster_type,
                                     colour_map = TYPE_COLOUR,
                                     topn = topn))
        end
        p = plot(panels...; layout = (2, 2), size = (1600, 1000),
                 left_margin = 32Plots.mm, bottom_margin = 8Plots.mm,
                 top_margin = 4Plots.mm)
        path = joinpath(outdir, "$slug.png")
        savefig(p, path)
        push!(written, path)
    end

    # The trade the whole comparison is about: raising specific impulse cuts propellant
    # and lengthens the burn. One panel per mission, every feasible electric candidate,
    # coloured by thruster type to match the bar charts.
    panels = Any[]
    legend_panel = argmax([
        length(unique(df[(df.mid .== mid) .& .!ismissing.(df.trip_time_days), :].thruster_type))
        for mid in missions
    ])
    for (i, mid) in enumerate(missions)
        sub = df[(df.mid .== mid) .& .!ismissing.(df.trip_time_days), :]
        name = nrow(sub) == 0 ? mid : first(sub.mission_name)
        if nrow(sub) == 0
            push!(panels, plot(; title = name, titlefontsize = 9, framestyle = :box,
                               showaxis = false, grid = false, legend = false))
            continue
        end
        p = plot(; title = name, titlefontsize = 9, xlabel = "specific impulse, s",
                 ylabel = "thrusting time, days", guidefontsize = 8, tickfontsize = 7,
                 legend = (i == legend_panel ? :topright : false), legendfontsize = 7)
        for tt in sort(unique(sub.thruster_type))
            g = sub[sub.thruster_type .== tt, :]
            scatter!(p, Float64.(g.exhaust_velocity_m_s) ./ g0, Float64.(g.trip_time_days);
                     label = tt, color = get(TYPE_COLOUR, tt, :grey),
                     markersize = 7, markerstrokewidth = 0)
        end
        push!(panels, p)
    end
    p = plot(panels...; layout = (2, 2), size = (1500, 1000),
             left_margin = 10Plots.mm, bottom_margin = 8Plots.mm)
    path = joinpath(outdir, "isp_vs_trip_time.png")
    savefig(p, path)
    push!(written, path)

    push!(written, make_krypton_plot(con, outdir; producer = producer))

    written
end

"""
    make_krypton_plot(con, outdir; producer="julia") -> String

Krypton against the xenon it is set against, on the same thruster where one exists.

The dataset holds three measured krypton operating points. Two of them, the BHT-1500-C and
the SPT-100 at its nominal condition, have a xenon control measured on the same thruster in
the same campaign. The third, the SPT-100 at 393 V, comes from a separate life-test paper and
has no condition-matched xenon run, so it appears alongside the 302 V nominal control rather
than against a true control. Plotting them together shows the trade: krypton buys a lower
initial mass and pays for it in thrusting time. Rows that fail their mission's time cap are
drawn pale.
"""
function make_krypton_plot(con, outdir::AbstractString; producer::AbstractString = "julia")
    ENV["GKSwstype"] = "100"
    gr()
    mkpath(outdir)

    df = query_db(con, """
        SELECT m.mission_id AS mid, m.name AS mission_name,
               t.name AS thruster_name, t.propellant,
               r.initial_mass_kg, r.tank_mass_kg, r.trip_time_days, r.feasible
        FROM results r
        JOIN missions m ON m.mission_id = r.mission_id
        JOIN thrusters t ON t.thruster_id = r.thruster_id
        WHERE r.producer = '$producer'
          AND t.thruster_id IN ('spt100_kr_390v','spt100_kr_nom','spt100_xe_nakles',
                                'bht1500c_kr','bht1500c_xe')
        ORDER BY r.mission_id, t.propellant, r.initial_mass_kg
    """)

    panels = Any[]
    for mid in ("mars_crew_nominal", "mars_crew_fast", "probe500_nominal")
        sub = df[df.mid .== mid, :]
        nrow(sub) == 0 && continue
        name = first(sub.mission_name)
        for (col, label) in ((:initial_mass_kg, "initial mass, kg"),
                             (:tank_mass_kg, "tank dry mass, kg"),
                             (:trip_time_days, "thrusting time, days"))
            push!(panels, hbar_panel(sub, col,
                                     "$name\n$label (pale = fails the time cap)", label;
                                     colour_by = :propellant,
                                     colour_map = PROPELLANT_COLOUR,
                                     alpha_by = :feasible,
                                     titlefontsize = 8))
        end
    end

    p = plot(panels...; layout = (3, 3), size = (2000, 1250),
             left_margin = 34Plots.mm, bottom_margin = 7Plots.mm, top_margin = 5Plots.mm)
    path = joinpath(outdir, "krypton_vs_xenon.png")
    savefig(p, path)
    path
end
