using Configurations
import Pluto
export SliderServerSettings, ExportSettings, PlutoDeploySettings, get_configuration
using FromFile
import Glob
@from "./ConfigurationDocs.jl" import @extract_docs, get_kwdocs, list_options_md


@extract_docs @option struct SliderServerSettings
    enabled::Bool = true
    "List of notebook files to skip. Provide paths relative to `start_dir`. *If `Export.enabled` is `true` (default), then only paths in `SliderServer_exclude ∩ Export_exclude` will be skipped, paths in `setdiff(SliderServer_exclude, Export_exclude)` will be shut down after exporting. You can use the `*` wildcard and other [glob patterns](https://en.wikipedia.org/wiki/Glob_(programming))."
    exclude::Vector = String[]
    "Port to run the HTTP server on."
    port::Integer = 2345
    """Often set to `"0.0.0.0"` on a server."""
    host::Any = "127.0.0.1"
    "Watch the input directory for file changes, and update the slider server sessions automatically. Only takes effect when running the slider server. More info in the README."
    watch_dir::Bool = true
    "Besides handling slider server request, should we also run a static file server of the export output folder? Set to `false` if you are serving the HTML files in another way, e.g. using GitHub Pages, and, for some reason, you do not want to *also* serve the HTML files using this serve."
    serve_static_export_folder::Bool = true
    simulated_lag::Real = 0
    server_timing_header::Bool = false
    "Cache-Control header sent on requests in which caching is enabled. Set to `no-store, no-cache` to completely disable caching"
    cache_control::String = "public, max-age=315600000, immutable"
end

@extract_docs @option struct ExportSettings
    "Generate static HTML files? This setting can only be `false` if you are also running a slider server."
    enabled::Bool = true
    "Folder to write generated HTML files to (will create directories to preserve the input folder structure). The behaviour of the default value depends on whether you are running the slider server, or just exporting. If running the slider server, we use a temporary directory; otherwise, we use `start_dir` (i.e. we generate each HTML file in the same folder as the notebook file)."
    output_dir::Union{Nothing,String} = nothing
    "List of notebook files to skip. Provide paths relative to `start_dir`.  You can use the `*` wildcard and other [glob patterns](https://en.wikipedia.org/wiki/Glob_(programming))."
    exclude::Vector{String} = String[]
    "List of notebook files that should always re-run, skipping the `cache_dir` system. Provide paths relative to `start_dir`.  You can use the `*` wildcard and other [glob patterns](https://en.wikipedia.org/wiki/Glob_(programming))."
    ignore_cache::Vector = String[]
    "If provided, use this directory to read and write cached notebook states. Caches will be indexed by the hash of the notebook file, but you need to take care to invalidate the cache when Pluto or this export script updates. Useful in combination with https://github.com/actions/cache, see https://github.com/JuliaPluto/static-export-template for an example."
    cache_dir::Union{Nothing,String} = nothing
    "base64-encode the state object and write it inside the .html file. If `false`, a separate `.plutostate` file is generated. A separate statefile allows us to show a loading bar in pluto while the statefile is loading, but it can complicate setup in some environments."
    baked_state::Bool = true
    """base64-encode the .jl notebook source and write it inside the .html file. If `false`, a separate `.jl` file is generated (or the original is used). The main difference is in the "Edit or run this notebook > On your computer" flow on the HTML file: with a separate notebook file (default), it will be a URL that you can copy and open with Pluto. With a baked notebook file, it will be a download button, and visitors need to save the notebook on their local drive, which can be more complicated."""
    baked_notebookfile::Bool = true
    "Hide all buttons and toolbars in Pluto to make it look like an article."
    disable_ui::Bool = true
    """Show a "Run on Binder" button on the notebooks."""
    offer_binder::Bool = true
    """ADVANCED: URL of the binder repository to load when you click the "Run on binder" button in the top right, this will be set automatically if you leave it at the default value. This setting is quite advanced, and only makes sense if you have a fork of `https://github.com/fonsp/pluto-on-binder/` (because you want to control the binder launch, or because you are using your own fork of Pluto). If so, the setting should be of the form `"https://mybinder.org/v2/gh/fonsp/pluto-on-binder/v0.17.2"`, where `fonsp/pluto-on-binder` is the name of your repository, and `v0.17.2` is a tag or commit hash."""
    binder_url::Union{Nothing,String} = nothing
    """If 1) you are using this setup to export HTML files for notebooks, AND 2) you are running the slider server **on another setup/computer**, then this setting should be the URL pointing to the slider server, e.g. `"https://sliderserver.mycoolproject.org/"`. For example, you need this if you use GitHub Actions and GitHub Pages to generate HTML files, with a slider server on DigitalOcean. === If you only have *one* server for both the static exports and the slider server, and people will read notebooks directly on your server, then the default value `nothing` will work: it will automatically make the HTML files use their current domain for the slider server."""
    slider_server_url::Union{Nothing,String} = nothing
    "Automatically generate an `index.html` file, listing all the exported notebooks (only if no `index.jl` or `index.html` file exists already)."
    create_index::Bool = true
    "Use the Pluto Featured GUI to display the notebooks on the auto-generated index page, using frontmatter for title, description, image, and more. The default is currently `false`, but it might change in the future. Set to `true` or `false` explicitly to fix a value."
    create_pluto_featured_index::Union{Nothing,Bool} = nothing
    pluto_cdn_root::Union{Nothing,String} = nothing
end

@option struct PlutoDeploySettings
    SliderServer::SliderServerSettings = SliderServerSettings()
    Export::ExportSettings = ExportSettings()
    Pluto::Pluto.Configuration.Options = Pluto.Configuration.Options()
end

function get_configuration(
    toml_path::Union{Nothing,String}=nothing;
    kwargs...,
)::PlutoDeploySettings
    # we set `Pluto_server_notebook_path_suggestion=joinpath(homedir(),"")` to because the default value for this setting changes when the pwd changes. This causes our run_git_directory to exit... Not necessary for Pluto 0.17.3 and up.
    if !isnothing(toml_path) && isfile(toml_path)
        Configurations.from_toml(
            PlutoDeploySettings,
            toml_path;
            Pluto_server_notebook_path_suggestion=joinpath(homedir(), ""),
            kwargs...,
        )
    else
        Configurations.from_kwargs(
            PlutoDeploySettings;
            Pluto_server_notebook_path_suggestion=joinpath(homedir(), ""),
            kwargs...,
        )
    end
end

merge_recursive(a::AbstractDict, b::AbstractDict) = mergewith(merge_recursive, a, b)
merge_recursive(a, b) = b


is_glob_match(path::AbstractString, pattern::AbstractString) =
    occursin(Glob.FilenameMatch(pattern, ""), path)
is_glob_match(path::AbstractString, patterns::AbstractVector{<:AbstractString}) =
    any(p -> is_glob_match(path, p), patterns)
is_glob_match(pattern) = path -> is_glob_match(path, pattern)
