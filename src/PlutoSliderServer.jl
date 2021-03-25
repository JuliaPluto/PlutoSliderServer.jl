module PlutoSliderServer

include("./MoreAnalysis.jl")
import .MoreAnalysis

include("./FileHelpers.jl")
include("./Export.jl")
using .Export
include("./GitHubAction.jl")

import Pluto
import Pluto: ServerSession, Firebasey, Token, withtoken
using HTTP
using Base64
using SHA
using Sockets
using Configurations
using TOML

myhash = base64encode ∘ sha256

###
# SESSION DEFINITION

abstract type NotebookSession end

Base.@kwdef struct RunningNotebookSession <: NotebookSession
    hash::String
    notebook::Pluto.Notebook
    original_state
    token::Token=Token()
    bond_connections::Dict{Symbol,Vector{Symbol}}
end

Base.@kwdef struct QueuedNotebookSession <: NotebookSession
    hash::String
end

Base.@kwdef struct FinishedNotebookSession <: NotebookSession
    hash::String
    original_state
end



###
# CONFIGURATION

UnionNothingString = Any

@option struct SliderServerSettings
    exclude::Vector=String[]
    port::Integer=2345
    host="127.0.0.1"
    simulated_lag::Real=0
    serve_static_export_folder::Bool=false
end

@option struct ExportSettings
    output_dir::UnionNothingString=nothing
    exclude::Vector=String[]
    ignore_cache::Vector=String[]
    pluto_cdn_root::UnionNothingString=nothing
    baked_state::Bool=true
    offer_binder::Bool=true
    disable_ui::Bool=true
    cache_dir::UnionNothingString=nothing
    slider_server_url::UnionNothingString=nothing
    binder_url::UnionNothingString=nothing
end

@option struct PlutoDeploySettings
    SliderServer::SliderServerSettings=SliderServerSettings()
    Export::ExportSettings=ExportSettings()
end


function get_configuration(toml_path::Union{Nothing,String}=nothing; kwargs...)
    if !isnothing(toml_path) && isfile(toml_path)
        toml_d = TOML.parsefile(toml_path)

        relevant_for_me = filter(toml_d) do (k,v)
            k ∈ ["SliderServer", "Export"]
        end
        relevant_for_pluto = get(toml_d, "Pluto", Dict())

        remaining = setdiff(keys(toml_d), ["SliderServer", "Export", "Pluto"])
        if !isempty(remaining)
            @error "Configuration categories not recognised:" remaining
        end

        (
            Configurations.from_dict(PlutoDeploySettings, relevant_for_me; kwargs...),
            Pluto.Configuration.from_flat_kwargs(;(Symbol(k) => v for (k,v) in relevant_for_pluto)...),
        )
    else
        (
            Configurations.from_kwargs(PlutoDeploySettings; kwargs...),
            Pluto.Configuration.Options(),
        )
    end
end


include("./HTTPRouter.jl")



export export_directory, run_directory


"""
    export_directory(start_dir::String="."; kwargs...)

Search recursively for all Pluto notebooks in the current folder, and for each notebook:
- Run the notebook and wait for all cells to finish
- Export the state object
- Create a .html file with the same name as the notebook, which has:
  - The JS and CSS assets to load the Pluto editor
  - The state object embedded
  - Extra functionality enabled, such as hidden UI, binder button, and a live bind server

# Keyword rguments
- `Export_exclude::Vector{String}=[]`: list of notebook files to skip. Provide paths relative to `start_dir`.
- `Export_disable_ui::Bool=true`: hide all buttons and toolbars to make it look like an article.
- `Export_baked_state::Bool=true`: base64-encode the state object and write it inside the .html file. If `false`, a separate `.plutostate` file is generated.
- `Export_offer_binder::Bool=false`: show a "Run on Binder" button on the notebooks. Use `binder_url` to choose a binder repository.
- `Export_binder_url::Union{Nothing,String}=nothing`: e.g. `https://mybinder.org/v2/gh/mitmath/18S191/e2dec90` TODO docs
- `Export_slider_server_url::Union{Nothing,String}=nothing`: e.g. `https://bindserver.mycoolproject.org/` TODO docs
- `Export_cache_dir::Union{Nothing,String}=nothing`: if provided, use this directory to read and write cached notebook states. Caches will be indexed by notebook hash, but you need to take care to invalidate the cache when Pluto or this export script updates. Useful in combination with https://github.com/actions/cache.
- `Export_output_dir::String="."`: folder to write generated HTML files to (will create directories to preserve the input folder structure). Leave at the default to generate each HTML file in the same folder as the notebook file.
- `notebook_paths::Vector{String}=find_notebook_files_recursive(start_dir)`: If you do not want the recursive save behaviour, then you can set this to a vector of absolute paths. In that case, `start_dir` is ignored, and you should set `Export_output_dir`.
"""
function export_directory(args...; kwargs...)
    run_directory(args...; run_server=false, kwargs...)
end
export_notebook(p; kwargs...) = run_notebook(p; run_server=false, kwargs...)

function run_notebook(path::String; kwargs...)
    run_directory(dirname(path); notebook_paths=[path], kwargs...)
end


"""
    run_directory(start_dir::String="."; export_options...)

Run the Pluto bind server for all Pluto notebooks in the given directory (recursive search). 

# Keyword arguments
- `SliderServer_exclude::Vector{String}=[]`: list of notebook files to skip. Provide paths relative to `start_dir`. _If `static_export` is `true`, then only paths in `SliderServer_exclude ∩ Export_exclude` will be skipped, paths in `setdiff(SliderServer_exclude, Export_exclude)` will be shut down after exporting._
- `SliderServer_port::Integer=2345`: Port to run the HTTP server on.
- `SliderServer_host="127.0.0.1"`: Often set to `"0.0.0.0"` on a server.
- `static_export::Bool=false`: Also export static files?
- `notebook_paths::Vector{String}=find_notebook_files_recursive(start_dir)`: If you do not want the recursive save behaviour, then you can set this to a vector of absolute paths. In that case, `start_dir` is ignored, and you should set `Export_output_dir`.

If `static_export` is `true`, then additional `Export_` keywords can be given, see [`export_directory`](@ref).
"""
function run_directory(
        start_dir::String="."; 
        notebook_paths::Vector{String}=find_notebook_files_recursive(start_dir),
        static_export::Bool=true, run_server::Bool=true, 
        on_ready::Function=((args...)->()),
        config_toml_path::Union{String,Nothing}=joinpath(Base.active_project() |> dirname, "PlutoDeployment.toml"),
        kwargs...
    )

    settings, pluto_options = get_configuration(config_toml_path;kwargs...)
    output_dir = something(settings.Export.output_dir, start_dir)
    mkpath(output_dir)

    to_run = setdiff(notebook_paths, if static_export
        settings.SliderServer.exclude ∩ settings.Export.exclude
    else
        settings.SliderServer.exclude
    end)
    
    @info "Settings" Text(settings)

    run_server && @warn "Make sure that you run this slider server inside a containerized environment -- it is not intended to be secure. Assume that users can execute arbitrary code inside your notebooks."

    if static_export && settings.Export.offer_binder && settings.Export.binder_url === nothing
        # TODO how can we fix the binder version to a Pluto version? We can't use the Pluto hash because the binder repo is different from Pluto.jl itself. We can use Pluto versions, tag those on the binder repo.
        @warn "We highly recommend setting the `binder_url` keyword argument with a fixed commit hash. The default is not fixed to a specific version, and the binder button will break when Pluto updates.
        
        This might be automated in the future."
    end

    if to_run != notebook_paths
        @info "Excluded notebooks:" setdiff(notebook_paths, to_run)
    end

    @info "Pluto notebooks to run:" to_run


    server_session = Pluto.ServerSession(;options=pluto_options)

    notebook_sessions = NotebookSession[QueuedNotebookSession(hash=myhash(read(joinpath(start_dir, path)))) for path in to_run]

    if run_server

        router = make_router(settings, server_session, notebook_sessions; static_dir=settings.SliderServer.serve_static_export_folder ? output_dir : nothing)
        # This is boilerplate HTTP code, don't read it
        host = settings.SliderServer.host
        port = settings.SliderServer.port

        # This is boilerplate HTTP code, don't read it
        hostIP = parse(Sockets.IPAddr, host)
        if port === nothing
            port, serversocket = Sockets.listenany(hostIP, UInt16(1234))
        else
            serversocket = try
                Sockets.listen(hostIP, UInt16(port))
            catch e
                @error "Port with number $port is already in use. Use Pluto.run() to automatically select an available port."
                return
            end
        end

        @info "Starting server..." host Int(port)

        # This is boilerplate HTTP code, don't read it
        # We start the HTTP server before launching notebooks so that the server responds to heroku/digitalocean garbage fast enough
        http_server_task = @async HTTP.serve(hostIP, UInt16(port), stream=true, server=serversocket) do http::HTTP.Stream
            request::HTTP.Request = http.message
            request.body = read(http)
            HTTP.closeread(http)
    
            params = HTTP.queryparams(HTTP.URI(request.target))
    
            response_body = HTTP.handle(router, request)
    
            request.response::HTTP.Response = response_body
            request.response.request = request
            try
                HTTP.setheader(http, "Referrer-Policy" => "origin-when-cross-origin")
                HTTP.startwrite(http)
                write(http, request.response.body)
                HTTP.closewrite(http)
            catch e
                if isa(e, Base.IOError) || isa(e, ArgumentError)
                    # @warn "Attempted to write to a closed stream at $(request.target)"
                else
                    rethrow(e)
                end
            end
        end
    else
        http_server_task = @async 1+1
        serversocket = nothing
    end

    # RUN ALL NOTEBOOKS AND KEEP THEM RUNNING
    for (i, path) in enumerate(to_run)
        
        @info "[$(i)/$(length(to_run))] Opening $(path)"


        jl_contents = read(joinpath(start_dir, path), String)
        hash = myhash(jl_contents)

        keep_running = run_server && path ∉ settings.SliderServer.exclude && occursin("@bind", jl_contents)

        cached_state = keep_running ? nothing : try_fromcache(settings.Export.cache_dir, hash)
        if cached_state !== nothing
            @info "Loaded from cache, skipping notebook run" hash
            original_state = cached_state
        else
            # open and run the notebook (TODO: tell pluto not to write to the notebook file)
            notebook = Pluto.SessionActions.open(server_session, joinpath(start_dir, path); run_async=false)
            # get the state object
            original_state = Pluto.notebook_to_js(notebook)
            # shut down the notebook
            if !keep_running
                @info "Shutting down notebook process"
                Pluto.SessionActions.shutdown(server_session, notebook)
            end

            try_tocache(settings.Export.cache_dir, hash, original_state)
        end
        

        if static_export
            export_jl_path = let
                relative_to_notebooks_dir = path
                joinpath(output_dir, relative_to_notebooks_dir)
            end
            export_html_path = let
                relative_to_notebooks_dir = without_pluto_file_extension(path) * ".html"
                joinpath(output_dir, relative_to_notebooks_dir)
            end
            export_statefile_path = let
                relative_to_notebooks_dir = without_pluto_file_extension(path) * ".plutostate"
                joinpath(output_dir, relative_to_notebooks_dir)
            end


            mkpath(dirname(export_jl_path))
            mkpath(dirname(export_html_path))
            mkpath(dirname(export_statefile_path))


            notebookfile_js = if settings.Export.offer_binder
                repr(basename(export_jl_path))
            else
                "undefined"
            end
            slider_server_url_js = if settings.Export.slider_server_url !== nothing
                repr(settings.Export.slider_server_url)
            else
                "undefined"
            end
            binder_url_js = if settings.Export.binder_url !== nothing
                repr(settings.Export.binder_url)
            else
                "undefined"
            end
            statefile_js = if !settings.Export.baked_state
                open(export_statefile_path, "w") do io
                    Pluto.pack(io, original_state)
                end
                repr(basename(export_statefile_path))
            else
                statefile64 = base64encode() do io
                    Pluto.pack(io, original_state)
                end

                "\"data:;base64,$(statefile64)\""
            end

            html_contents = generate_html(;
                pluto_cdn_root=settings.Export.pluto_cdn_root,
                notebookfile_js, statefile_js,
                slider_server_url_js, binder_url_js,
                disable_ui=settings.Export.disable_ui
            )
            write(export_html_path, html_contents)

            # TODO: maybe we can avoid writing the .jl file if only the slider server is needed? the frontend only uses it to get its hash
            var"we need the .jl file" = (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing)
            var"the .jl file is already there and might have changed" = isfile(export_jl_path)

            if var"we need the .jl file" || var"the .jl file is already there and might have changed"
                write(export_jl_path, jl_contents)
            end

            @info "Written to $(export_html_path)"
        end

        if keep_running
            bond_connections = MoreAnalysis.bound_variable_connections_graph(notebook)
            @info "Bond connections" Text(join(collect(bond_connections), "\n"))

            # By setting notebook_sessions[i] to a running session, (modifying the array), the HTTP router will now start serving requests for this notebook.
            notebook_sessions[i] = RunningNotebookSession(;
                hash,
                notebook, 
                original_state, 
                bond_connections,
            )
        else
            notebook_sessions[i] = FinishedNotebookSession(;
                hash,
                original_state,
            )
        end

        @info "[$(i)/$(length(to_run))] Ready $(path)" hash
    end
    @info "-- ALL NOTEBOOKS READY --"

    on_ready((;
        serversocket,
        server_session, 
        notebook_sessions,
    ))

    wait(http_server_task)
end


end
