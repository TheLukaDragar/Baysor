using Configurations

@option mutable struct DataOptions
    x::String = "x"
    y::String = "y"
    z::String = "z"
    gene::String = "gene"
    force_2d::Bool = false # Ignores z-column in the data if it is provided
    min_molecules_per_gene::Int = 1
    exclude_genes::String = ""
    min_molecules_per_cell::Int = 0
    min_molecules_per_segment::Int = 0
    confidence_nn_id = 0
end

@option mutable struct SegmentationOptions
    scale::Float64 = -1.0 # Negative values mean it must be estimated from `min_molecules_per_cell`
    scale_std::String = "25%"
    estimate_scale_from_centers::Bool = true

    n_clusters::Int = 4
    prior_segmentation_confidence::Float64 = 0.2
    iters::Int = 500
    n_cells_init::Int = 0 # Initial number of cells

    nuclei_genes::String = ""
    cyto_genes::String = ""

    # The parameters below are not supposed to be changed normally
    new_component_weight::Float64 = 0.2
    new_component_fraction::Float64 = 0.3
end

@option mutable struct PlottingOptions
    gene_composition_neigborhood::Int = 0
    min_pixels_per_cell::Int = 15

    # Method for gene vector estimation for NCV dimensionality reduction. Possible values: `hash`, `dense`, `sparse`.
    # `dense` and `sparse` method are based on PCA and will likely be removed in further versions.
    # (default: `hash`)
    ncv_method::String = "hash"
end

@option mutable struct RunOptions
    data::DataOptions = DataOptions()
    segmentation::SegmentationOptions = SegmentationOptions()
    plotting::PlottingOptions = PlottingOptions()
end