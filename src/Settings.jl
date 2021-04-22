module Settings
using Configurations
import Pluto
using FromFile

UnionNothingString = Any
export SliderServerSettings, ExportSettings, PlutoDeploySettings, get_configuration, merge_recursive

@option struct SliderServerSettings
    exclude::Vector = String[]
    port::Integer = 2345
    host = "127.0.0.1"
    simulated_lag::Real = 0
    serve_static_export_folder::Bool = true
end

@option struct ExportSettings
    output_dir::UnionNothingString = nothing
    exclude::Vector = String[]
    ignore_cache::Vector = String[]
    pluto_cdn_root::UnionNothingString = nothing
    baked_state::Bool = true
    offer_binder::Bool = true
    disable_ui::Bool = true
    cache_dir::UnionNothingString = nothing
    slider_server_url::UnionNothingString = nothing
    binder_url::UnionNothingString = nothing
    create_index::Bool = true
end

@option struct PlutoDeploySettings
    SliderServer::SliderServerSettings = SliderServerSettings()
    Export::ExportSettings = ExportSettings()
end


function get_configuration(toml_path::Union{Nothing,String}=nothing; kwargs...)
    if !isnothing(toml_path) && isfile(toml_path)
        toml_d = TOML.parsefile(toml_path)

        relevant_for_me = filter(toml_d) do (k, v)
            k ∈ ["SliderServer", "Export"]
        end
        relevant_for_pluto = get(toml_d, "Pluto", Dict())

        remaining = setdiff(keys(toml_d), ["SliderServer", "Export", "Pluto"])
        if !isempty(remaining)
            @error "Configuration categories not recognised:" remaining
        end

        kwargs_dict = Configurations.to_dict(Configurations.from_kwargs(PlutoDeploySettings; kwargs...))
        (
            Configurations.from_dict(PlutoDeploySettings, merge_recursive(relevant_for_me, kwargs_dict)),
            Pluto.Configuration.from_flat_kwargs(;(Symbol(k) => v for (k, v) in relevant_for_pluto)...),
        )
    else
        (
            Configurations.from_kwargs(PlutoDeploySettings; kwargs...),
            Pluto.Configuration.Options(),
        )
    end
end

merge_recursive(a::AbstractDict, b::AbstractDict) = mergewith(merge_recursive, a, b)
merge_recursive(a, b) = b

end