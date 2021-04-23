module Types
    using Configurations
    using TOML
    import Pluto: Pluto, Token, Notebook
    export NotebookSession, RunningNotebookSession, QueuedNotebookSession, FinishedNotebookSession, SliderServerSettings, ExportSettings, PlutoDeploySettings, get_configuration
    ###
    # SESSION DEFINITION
    
    abstract type NotebookSession end
    
    Base.@kwdef struct RunningNotebookSession <: NotebookSession
        path::String
        hash::String
        notebook::Pluto.Notebook
        original_state
        token::Token=Token()
        bond_connections::Dict{Symbol,Vector{Symbol}}
    end
    
    Base.@kwdef struct QueuedNotebookSession <: NotebookSession
        path::String
        hash::String
    end
    
    Base.@kwdef struct FinishedNotebookSession <: NotebookSession
        path::String
        hash::String
        original_state
    end
    
    
    ###
    # CONFIGURATION
    
    @option struct SliderServerSettings
        exclude::Vector=String[]
        port::Integer=2345
        host="127.0.0.1"
        simulated_lag::Real=0
        serve_static_export_folder::Bool=true
        start_dir="." # Relative to julia that is running
        repository::Union{Nothing,String}=nothing
    end
    
    @option struct ExportSettings
        output_dir::Union{Nothing,String}=nothing
        exclude::Vector=String[]
        ignore_cache::Vector=String[]
        pluto_cdn_root::Union{Nothing,String}=nothing
        baked_state::Bool=true
        offer_binder::Bool=true
        disable_ui::Bool=true
        cache_dir::Union{Nothing,String}=nothing
        slider_server_url::Union{Nothing,String}=nothing
        binder_url::Union{Nothing,String}=nothing
        create_index::Bool=true
    end
    
    @option struct PlutoDeploySettings
        SliderServer::SliderServerSettings=SliderServerSettings()
        Export::ExportSettings=ExportSettings()
        Pluto::Pluto.Configuration.Options=Pluto.Configuration.Options()
    end
    
    function get_configuration(toml_path::Union{Nothing,String}=nothing; kwargs...)
        if !isnothing(toml_path) && isfile(toml_path)
            toml_d = TOML.parsefile(toml_path)
            
            kwargs_dict = Configurations.to_dict(Configurations.from_kwargs(PlutoDeploySettings; kwargs...))
            Configurations.from_dict(PlutoDeploySettings, merge_recursive(toml_d, kwargs_dict))
        else
            Configurations.from_kwargs(PlutoDeploySettings; kwargs...)
        end
    end
    
    merge_recursive(a::AbstractDict, b::AbstractDict) = mergewith(merge_recursive, a, b)
    merge_recursive(a, b) = b
end