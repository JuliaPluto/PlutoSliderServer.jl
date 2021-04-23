module PlutoSliderServer

using FromFile

@from "./MoreAnalysis.jl" import MoreAnalysis
@from "./FileHelpers.jl" import FileHelpers: find_notebook_files_recursive, list_files_recursive
@from "./Export.jl" using Export
@from "./Actions.jl" import Actions: add_to_session!, generate_static_export, myhash, showall
@from "./Types.jl" using Types

import Pluto
import Pluto: ServerSession, Firebasey, Token, withtoken, pluto_file_extensions, without_pluto_file_extension
using HTTP
using Base64
using SHA
using Sockets
using Configurations
using TOML

using Logging: global_logger
using GitHubActions: GitHubActionsLogger
function __init__()
    get(ENV, "GITHUB_ACTIONS", "false") == "true" && global_logger(GitHubActionsLogger())
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

include("./HTTPRouter.jl")



export export_directory, run_directory, github_action


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
- `Export_offer_binder::Bool=true`: show a "Run on Binder" button on the notebooks.
- `Export_binder_url::Union{Nothing,String}=nothing`: e.g. `https://mybinder.org/v2/gh/mitmath/18S191/e2dec90`. Defaults to a binder repo that runs the correct version of Pluto -- https://github.com/fonsp/pluto-on-binder. TODO docs
- `Export_slider_server_url::Union{Nothing,String}=nothing`: e.g. `https://bindserver.mycoolproject.org/` TODO docs
- `Export_cache_dir::Union{Nothing,String}=nothing`: if provided, use this directory to read and write cached notebook states. Caches will be indexed by notebook hash, but you need to take care to invalidate the cache when Pluto or this export script updates. Useful in combination with https://github.com/actions/cache.
- `Export_output_dir::String="."`: folder to write generated HTML files to (will create directories to preserve the input folder structure). Leave at the default to generate each HTML file in the same folder as the notebook file.
- `notebook_paths::Vector{String}=find_notebook_files_recursive(start_dir)`: If you do not want the recursive save behaviour, then you can set this to a vector of absolute paths. In that case, `start_dir` is ignored, and you should set `Export_output_dir`.
"""
function export_directory(args...; kwargs...)
    run_directory(args...; static_export=true, run_server=false, kwargs...)
end
export_notebook(p; kwargs...) = run_notebook(p; static_export=true, run_server=false, kwargs...)
github_action = export_directory

function run_notebook(path::String; kwargs...)
    run_directory(dirname(path); notebook_paths=[basename(path)], kwargs...)
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
        static_export::Bool=false, run_server::Bool=true, 
        on_ready::Function=((args...)->()),
        config_toml_path::Union{String,Nothing}=joinpath(Base.active_project() |> dirname, "PlutoDeployment.toml"),
        kwargs...
    )

    pluto_version = Export.try_get_exact_pluto_version()
    settings = get_configuration(config_toml_path;kwargs...)
    output_dir = something(settings.Export.output_dir, start_dir)
    mkpath(output_dir)

    to_run = if static_export
        setdiff(notebook_paths, settings.SliderServer.exclude ∩ settings.Export.exclude)
    else
        s = setdiff(notebook_paths, settings.SliderServer.exclude)
        filter(s) do f
            occursin("@bind", read(joinpath(start_dir, f), String))
        end
    end
    
    @info "Settings" Text(settings)

    run_server && @warn "Make sure that you run this slider server inside a containerized environment -- it is not intended to be secure. Assume that users can execute arbitrary code inside your notebooks."

    if to_run != notebook_paths
        @info "Excluded notebooks:" showall(setdiff(notebook_paths, to_run))
    end

    @info "Pluto notebooks to run:" showall(to_run)

    settings.Pluto.server.disable_writing_notebook_files = true
    settings.Pluto.evaluation.lazy_workspace_creation = true
    server_session = Pluto.ServerSession(;options=settings.Pluto)

    notebook_sessions = NotebookSession[QueuedNotebookSession(;path, hash=myhash(read(joinpath(start_dir, path)))) for path in to_run]

    if run_server
        static_dir = (
            static_export && settings.SliderServer.serve_static_export_folder
        ) ? output_dir : nothing
        router = make_router(settings, server_session, notebook_sessions; static_dir )
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

    if static_export && settings.Export.create_index
        exists = any(["index.html", "index.md", ("index"*e for e in pluto_file_extensions)...]) do f
            joinpath(output_dir, f) |> isfile
        end
        if !exists
            write(joinpath(output_dir, "index.html"), default_index((
                without_pluto_file_extension(path) => without_pluto_file_extension(path) * ".html"
                for path in to_run
            )))
        end
    end

    # RUN ALL NOTEBOOKS AND KEEP THEM RUNNING
    for (i, path) in enumerate(to_run)
        
        @info "[$(i)/$(length(to_run))] Opening $(path)"

    local session, jl_contents, original_state
    # That's because you can't continue in a loop
    try
        session, jl_contents, original_state = add_to_session!(notebook_sessions, server_session, path, settings, run_server, start_dir)
    catch e
        rethrow(e)
        continue
    end

    if static_export
            generate_static_export(path, settings, original_state, output_dir, jl_contents)
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
