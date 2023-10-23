import UMAP
import Distributions: UnivariateDistribution,pdf

function plot_noise_estimation_diagnostics(edge_lengths::Vector{Float64}, confidences::Vector{Float64}, d1::T, d2::T; title::String="Noise estimation",
        confidence_nn_id::Union{Int, String}="k", linewidth::Float64=4.0, bins::Int=50) where T <: UnivariateDistribution
        x_max = quantile(edge_lengths, 0.99);
        n1 = sum(confidences);
        n2 = length(confidences) - n1;

        p_df = estimate_hist(edge_lengths[edge_lengths .< x_max], normalize=true, nbins=bins, type=:bar)
        p_df[!, :intra] = n1 / (n1 + n2) .* pdf.(d1, p_df.s)
        p_df[!, :bg] = n2 / (n1 + n2) .* pdf.(d2, p_df.s)

        return p_df |>
            VL.@vlplot(x={:s, title="Distance to $(confidence_nn_id)'th nearest neighbor"}, title=title, width=400, height=300) +
            VL.@vlplot(:bar, y={:h, title="Density"}, color={datum="Observed", scale={scheme="category10"}, legend={title="Distribution"}}) +
            VL.@vlplot({:line, size=linewidth}, y=:bg, color={datum="Background"}) +
            VL.@vlplot({:line, size=linewidth}, y=:intra, color={datum="Intracellular"})
end

# Function to be called from an environment without DataFrames imported
plot_num_transcript_overview(df_spatial::DataFrame, args...; kwargs...) =
    plot_num_transcript_overview(df_spatial.gene, args...; kwargs...)

function plot_num_transcript_overview(genes::Vector{Int}, confidences::Vector{Float64}, gene_names::Vector; alpha::Float64=0.3)
    order = sortperm(gene_names)
    return plot_expression_vectors(
        count_array(genes[confidences .>= 0.5], max_value=length(gene_names))[order],
        count_array(genes[confidences .< 0.5], max_value=length(gene_names))[order],
        gene_names=gene_names[order]; labels=["Real", "Noise"], ylabel="Num. molecules",
        min_expr_frac=0.01, alpha=alpha
    )
end

function plot_gene_structure(gene_emb::DataFrame)
    return gene_emb |>
        VL.@vlplot(
            x={:x, scale={domain=val_range(gene_emb.x)}, title="UMAP-1"},
            y={:y, scale={domain=val_range(gene_emb.y)}, title="UMAP-2"},
            size={:size, scale={range=[5, 10]}, legend=false},
            tooltip={:gene, type="nominal"},
            width=600, height=600, title="Gene local structure",
            config={axis={grid=false, ticks=false, ticklabels=false, labels=false}}
        ) +
        VL.@vlplot(:text, text={:gene, type="nominal"}, selection={view={type=:interval, bind=:scales}}) +
        VL.@vlplot({:point, filled=true})
end

function estimate_panel_plot_size(df_spatial::DataFrame, min_molecules_per_cell::Int, min_pixels_per_cell::Int=7)
    n_cells_per_side = sqrt(size(df_spatial, 1) / min_molecules_per_cell)
    plot_size = min_pixels_per_cell * n_cells_per_side
    x_rng = val_range(df_spatial.x)
    y_rng = val_range(df_spatial.y)
    y_ratio = (y_rng[2] - y_rng[1]) / (x_rng[2] - x_rng[1])

    y_ratio = y_ratio^0.5;
    x_ratio = 1 / y_ratio^0.5;
    plot_size = (x_ratio * plot_size, y_ratio * plot_size)
    return plot_size, n_cells_per_side
end

plot_dataset_colors(df_spatial::DataFrame, colors::Symbol; kwargs...) =
    plot_dataset_colors(df_spatial, df_spatial[!, colors]; kwargs...)

function plot_dataset_colors(
        df_spatial::DataFrame, color::Union{Vector, Symbol, String};
        min_molecules_per_cell::Int, min_pixels_per_cell::Int=7, markersize::Float64=-1., alpha::Union{Float64, Vector{Float64}}=0.5,
        prior_polygons::Array{Matrix{Float64}, 1}=Matrix{Float64}[], polygons::Array{Matrix{Float64}, 1}=Matrix{Float64}[],
        ticks::Bool=true, axis_kwargs::KWArgT=nothing, kwargs...
    )

    axis_kwargs = update_args((xticklabelsize=12, yticklabelsize=12), axis_kwargs)
    plot_size = estimate_panel_plot_size(df_spatial, min_molecules_per_cell, min_pixels_per_cell)[1]
    if markersize < 0
        markersize = min(max(50.0 / min_molecules_per_cell, 0.25), 5)
    end

    fig = MK.Figure(resolution=plot_size)
    fig[1, 1] = MK.Axis(fig; xticksvisible=ticks, yticksvisible=ticks, axis_kwargs...);

    if length(prior_polygons) > 0
        MK.poly!([MK.Point2.(eachrow(p)) for p in prior_polygons]; strokecolor="darkred", color=Colors.RGBA(1, 0.65, 0, 0.25), strokewidth=0.5)
    end

    return plot_molecules!(df_spatial, polygons; color=color, markersize=markersize, alpha=alpha, kwargs...)
end

function plot_confidence_distribution(confidence::Vector{Float64}, is_noise::AbstractVector{Bool}; bins::AbstractVector{Float64}=0.0:0.025:1.025, size=(500, 250))
    v1 = confidence[.!is_noise]
    v2 = confidence[is_noise]
    p_df = estimate_hist(v1, bins=bins)
    p_df[!, :h2] = estimate_hist(v2, bins=bins).h;

    return p_df |>
        VL.@vlplot(
            x={:s, title="Confidence", scale={domain=[minimum(p_df.s), maximum(p_df.e)]}}, x2=:e, y=:hs,
            width=size[1], height=size[2], title={text="Confidence per molecule"}
        ) +
        VL.@vlplot(:bar, y2={:h, title="Num. molecules"}, color={datum="Assigned molecules"}, tooltip={:h}) +
        VL.@vlplot({:bar, opacity=0.5}, y2=:h2, color={datum="Noise molecules"}, tooltip={:h2})
end

function plot_assignment_confidence_distribution(assignment_confidence::Vector{Float64}, nbins::Int=30, width::Int=500, height::Int=250)
    return estimate_hist(assignment_confidence; nbins=nbins) |>
        VL.@vlplot() +
        VL.@vlplot(
            :rect, x={:s, title="Assignment confidence"}, y={:hs, title="Num. molecules"},
            x2={:e}, y2={:h}, tooltip={:h},
            title="Assignment confidence", width=width, height=height
        ) +
        VL.@vlplot(:rule, x={datum=0.95})
end

function plot_n_molecules_per_cell(n_mols_per_cell::Vector{Int}, nbins::Int=50, width::Int=500, height::Int=250)
    p_df = estimate_hist(n_mols_per_cell, nbins=nbins)
    return p_df |> VL.@vlplot(
        mark={:rect},
        x={:s, scale={domain=[minimum(p_df.s), maximum(p_df.e)]}, title="Num. molecules per cell"},
        x2={:e},
        y={:hs},
        y2={:h, title="Num. cells"},
        width=width, height=height, title="Num. molecules per cell", tooltip={:h}
    )
end