module Configuration
    using Configurations
    import TOML
    import Pluto
    export SliderServerSettings, ExportSettings, PlutoDeploySettings, get_configuration
    using TerminalLoggers: TerminalLogger
    using Logging: global_logger
    using FromFile
    @from "./ConfigurationDocs.jl" import @extract_docs, get_kwdocs, list_options_md
    
    
    @extract_docs @option struct SliderServerSettings
        "Run the slider server?"
        enabled::Bool=true
        "List of notebook files to skip. Provide paths relative to `start_dir`. *If `Export.enabled` is `true` (default), then only paths in `SliderServer_exclude ∩ Export_exclude` will be skipped, paths in `setdiff(SliderServer_exclude, Export_exclude)` will be shut down after exporting.*"
        exclude::Vector=String[]
        "Port to run the HTTP server on."
        port::Integer=2345
        """Often set to `"0.0.0.0"` on a server."""
        host::Any="127.0.0.1"
        simulated_lag::Real=0
        "Besides handling slider server request, should we also run a static file server of the export output folder? Set to `false` if you are serving the HTML files in another way, e.g. using GitHub Pages, and, for some reason, you do not want to *also* serve the HTML files using this serve."
        serve_static_export_folder::Bool=true
        "Watch the input directory for file changes, and update the slider server sessions automatically. More info in the README."
        watch_dir::Bool=false
        repository::Union{Nothing,String}=nothing
    end
    
    # @info "Wowww" get_kwdocs(SliderServerSettings)
    
    # println(list_options_md(SliderServerSettings))
    
    @extract_docs @option struct ExportSettings
        "Generate static HTML files?"
        enabled::Bool=true
        "Folder to write generated HTML files to (will create directories to preserve the input folder structure). Leave at the default to generate each HTML file in the same folder as the notebook file."
        output_dir::Union{Nothing,String}=nothing
        "List of notebook files to skip. Provide paths relative to `start_dir`."
        exclude::Vector=String[]
        "List of notebook files that should always re-run, skipping the `cache_dir` system. Provide paths relative to `start_dir`."
        ignore_cache::Vector=String[]
        pluto_cdn_root::Union{Nothing,String}=nothing
        "base64-encode the state object and write it inside the .html file. If `false`, a separate `.plutostate` file is generated. A separate statefile allows us to show a loading bar in pluto while the statefile is loading, but it can complicate setup in some environments."
        baked_state::Bool=true
        baked_notebookfile::Bool=true
        "hide all buttons and toolbars to make it look like an article."
        disable_ui::Bool=true
        """show a "Run on Binder" button on the notebooks."""
        offer_binder::Bool=true
        "e.g. `https://mybinder.org/v2/gh/mitmath/18S191/e2dec90`. Defaults to a binder repo that runs the correct version of Pluto -- https://github.com/fonsp/pluto-on-binder. TODO docs"
        binder_url::Union{Nothing,String}=nothing
        "e.g. `https://sliderserver.mycoolproject.org/` TODO docs"
        slider_server_url::Union{Nothing,String}=nothing
        "If provided, use this directory to read and write cached notebook states. Caches will be indexed by the hash of the notebook file, but you need to take care to invalidate the cache when Pluto or this export script updates. Useful in combination with https://github.com/actions/cache, see https://github.com/JuliaPluto/static-export-template for an example."
        cache_dir::Union{Nothing,String}=nothing
        "Automatically generate an `index.html` file listing all the exported notebooks (only if no `index.jl` or `index.html` file exists already)."
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
end