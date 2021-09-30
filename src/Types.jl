module Types
    using Configurations
    import TOML
    import Pluto: Pluto, Token, Notebook
    export NotebookSession, SliderServerSettings, ExportSettings, PlutoDeploySettings, get_configuration, withlock
    using TerminalLoggers: TerminalLogger
    using Logging: global_logger

    ###
    # SESSION DEFINITION

    abstract type RunResult end

    Base.@kwdef struct RunningNotebook <: RunResult
        path::String
        notebook::Pluto.Notebook
        original_state
        token::Token=Token()
        bond_connections::Dict{Symbol,Vector{Symbol}}
    end
    Base.@kwdef struct FinishedNotebook <: RunResult
        path::String
        original_state
    end

    Base.@kwdef struct NotebookSession{C<:Union{Nothing,String}, D<:Union{Nothing,String}, R<:Union{Nothing,RunResult}}
        path::String
        current_hash::C
        desired_hash::D
        run::R
    end

    
    ###
    # CONFIGURATION

    @option struct SliderServerSettings
        enabled::Bool=true
        exclude::Vector=String[]
        port::Integer=2345
        host="127.0.0.1"
        simulated_lag::Real=0
        serve_static_export_folder::Bool=true
        start_dir="." # Relative to julia that is running
        watch_dir::Bool=false
        repository::Union{Nothing,String}=nothing
    end
    
    @option struct ExportSettings
        enabled::Bool=true
        output_dir::Union{Nothing,String}=nothing
        exclude::Vector=String[]
        ignore_cache::Vector=String[]
        pluto_cdn_root::Union{Nothing,String}=nothing
        baked_state::Bool=true
        baked_notebookfile::Bool=true
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

    function get_configuration(toml_path::Union{Nothing,String}=nothing; kwargs...)::PlutoDeploySettings
        if !isnothing(toml_path) && isfile(toml_path)
            Configurations.from_toml(PlutoDeploySettings, toml_path; kwargs...)
        else
            global_logger(try
                TerminalLogger(; margin=1)
            catch
                TerminalLogger()
            end)
            Configurations.from_kwargs(PlutoDeploySettings; kwargs...)
        end
    end
    
    merge_recursive(a::AbstractDict, b::AbstractDict) = mergewith(merge_recursive, a, b)
    merge_recursive(a, b) = b

    ###
    # LOCK

    const locked_objects = Dict{UInt,Token}()
    function withlock(f, x)
        l = get!(Token, locked_objects, objectid(x))
        take!(l)
        local result
        try
            result = f()
        catch e
            rethrow(e)
        finally
            put!(l)
        end
        result
    end
end

