module PlutoSliderServer

using FromFile

@from "./MoreAnalysis.jl" import MoreAnalysis
@from "./FileHelpers.jl" import FileHelpers: find_notebook_files_recursive, list_files_recursive
@from "./Export.jl" using Export
@from "./Actions.jl" import process, should_shutdown, should_update, should_launch, will_process
@from "./Types.jl" using Types: Types, NotebookSession, get_configuration, withlock
@from "./Webhook.jl" import register_webhook!
@from "./ReloadFolder.jl" import update_sessions!, select
@from "./HTTPRouter.jl" import make_router
@from "./gitpull.jl" import fetch_pull

import Pluto
import Pluto: ServerSession, Firebasey, Token, withtoken, pluto_file_extensions, without_pluto_file_extension
using HTTP
using Base64
using SHA
using Sockets
import BetterFileWatching: watch_folder

using Logging: global_logger
using GitHubActions: GitHubActionsLogger
using TerminalLoggers: TerminalLogger
function __init__()
    if get(ENV, "GITHUB_ACTIONS", "false") == "true"
        global_logger(GitHubActionsLogger())
    else
        global_logger(try
            TerminalLogger(; margin=1)
        catch
            TerminalLogger()
        end)
    end
end

export export_directory, run_directory, github_action

showall(xs) = Text(join(string.(xs),"\n"))

default_config_path() = joinpath(Base.active_project() |> dirname, "PlutoDeployment.toml")


macro ignorefailure(x)
    quote
        try
            $(esc(x))
        catch e
            showerror(stderr, e, catch_backtrace())
        end
    end
end

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
    run_directory(args...; Export_enabled=true, SliderServer_enabled=false, kwargs...)
end
export_notebook(p; kwargs...) = run_notebook(p; Export_enabled=true, SliderServer_enabled=false, kwargs...)
github_action = export_directory

function run_notebook(path::String; kwargs...)
    run_directory(dirname(path); notebook_paths=[basename(path)], kwargs...)
end

"""
    run_directory(start_dir::String="."; export_options...)

Run the Pluto bind server for all Pluto notebooks in the given directory (recursive search). 

# Keyword arguments
- `SliderServer_exclude::Vector{String}=[]`: list of notebook files to skip. Provide paths relative to `start_dir`. _If `Export.enabled` is `true` (default), then only paths in `SliderServer_exclude ∩ Export_exclude` will be skipped, paths in `setdiff(SliderServer_exclude, Export_exclude)` will be shut down after exporting._
- `SliderServer_port::Integer=2345`: Port to run the HTTP server on.
- `SliderServer_host="127.0.0.1"`: Often set to `"0.0.0.0"` on a server.
- `notebook_paths::Union{Nothing,Vector{String}}=nothing`: If you do not want the recursive save behaviour, then you can set this to a vector of absolute paths. In that case, `start_dir` is ignored, and you should set `Export_output_dir`.

If `Export.enabled` is `true` (default), then additional `Export_` keywords can be given, see [`export_directory`](@ref).
"""
function run_directory(
        start_dir::String="."; 
        notebook_paths::Union{Nothing,Vector{String}}=nothing,
        on_ready::Function=((args...)->()),
        config_toml_path::Union{String,Nothing}=default_config_path(),
        kwargs...
    )

    settings = get_configuration(config_toml_path; kwargs...)
    output_dir = something(settings.Export.output_dir, start_dir)
    mkpath(output_dir)

    if joinpath("a","b") != "a/b"
        @error "PlutoSliderServer.jl is only designed to work on unix systems."
        exit()
    end

    function getpaths()
        all_nbs = notebook_paths !== nothing ? notebook_paths : find_notebook_files_recursive(start_dir)
        if settings.Export.enabled
            setdiff(all_nbs, settings.SliderServer.exclude ∩ settings.Export.exclude)
        else
            s = setdiff(all_nbs, settings.SliderServer.exclude)
            filter(s) do f
                occursin("@bind", read(joinpath(start_dir, f), String))
            end
        end
    end

    to_run = getpaths()
    
    @info "Settings" Text(settings)

    settings.SliderServer.enabled && @warn "Make sure that you run this slider server inside a containerized environment -- it is not intended to be secure. Assume that users can execute arbitrary code inside your notebooks."

    # if to_run != notebook_paths
    #     @info "Excluded notebooks:" showall(setdiff(notebook_paths, to_run))
    # end

    settings.Pluto.server.disable_writing_notebook_files = true
    settings.Pluto.evaluation.lazy_workspace_creation = true
    server_session = Pluto.ServerSession(;options=settings.Pluto)

    notebook_sessions = NotebookSession[]
    # notebook_sessions = NotebookSession[QueuedNotebookSession(;path, hash=myhash(read(joinpath(start_dir, path)))) for path in to_run]

    if settings.SliderServer.enabled
        static_dir = (
            settings.Export.enabled && settings.SliderServer.serve_static_export_folder
        ) ? output_dir : nothing
        router = make_router(notebook_sessions, server_session; settings, static_dir )
        # register_webhook!(router) do
        #     new_settings = get_configuration(config_toml_path)
        #     @info new_settings
        #     @info new_settings == settings
        #     # TODO: Restart if settings changed
            
        #     # reload(notebook_sessions, server_session; settings)
        # end
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

        address = let
            host_str = string(hostIP)
            host_pretty = if isa(hostIP, Sockets.IPv6)
                if host_str == "::1"
                    "localhost"
                else
                    "[$(host_str)]"
                end
            elseif host_str == "127.0.0.1" # Assuming the other alternative is IPv4
                "localhost"
            else
                host_str
            end
            port_pretty = Int(port)
            "http://$(host_pretty):$(port_pretty)/"
        end


        @info "# Starting server..." address

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

    if settings.Export.enabled && settings.Export.create_index
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


    function refresh_until_synced(check_dir_on_every_step::Bool, did_something::Bool=false)
        should_continue = withlock(notebook_sessions) do
            
            check_dir_on_every_step && update_sessions!(notebook_sessions, getpaths(); start_dir)

            # todo: try catch to release lock?
            to_shutdown = select(should_shutdown, notebook_sessions)
            to_update = select(should_update, notebook_sessions)
            to_launch = select(should_launch, notebook_sessions)
    
            s = something(to_shutdown, to_update, to_launch, "not found")
    
            if s != "not found"

                progress = "[$(
                    count(!will_process, notebook_sessions) + 1
                )/$(length(notebook_sessions))]"

                new = process(s;
                    server_session,
                    settings,
                    output_dir,
                    start_dir,
                    progress
                )
                if new !== s
                    if new isa NotebookSession{Nothing,Nothing,<:Any}
                        # remove it
                        filter!(!isequal(s), notebook_sessions)
                    elseif s !== new
                        replace!(notebook_sessions, s => new)
                    end
                end

                true
            else
                did_something && @info "# ALL NOTEBOOKS READY"
                false
            end
        end

        should_continue && refresh_until_synced(check_dir_on_every_step, true)
    end

    # RUN ALL NOTEBOOKS AND KEEP THEM RUNNING
    update_sessions!(notebook_sessions, getpaths(); start_dir)
    refresh_until_synced(false)

    watch_dir_task = Pluto.@asynclog if settings.SliderServer.watch_dir
        @info "Watching directory for changes..."
        debounced = kind_of_debounced() do _
            @debug "File change detected!"
            sleep(.5)
            refresh_until_synced(true)
        end
        watch_folder(debounced, start_dir)
    end

    if settings.SliderServer.watch_dir
        # todo: skip first watch_folder so that we dont need this sleepo
        sleep(2)
    end


    on_ready((;
        serversocket,
        server_session, 
        notebook_sessions,
    ))

    try
        wait(http_server_task)
    catch e
        @ignorefailure close(serversocket)
        @ignorefailure schedule(watch_dir_task, e; error=true)
        e isa InterruptException || rethrow(e)
    end
end


function run_git_directory(
    start_dir::String="."; 
    notebook_paths::Union{Nothing,Vector{String}}=nothing,
    on_ready::Function=((args...)->()),
    config_toml_path::Union{String,Nothing}=default_config_path(),
    kwargs...
    )

    run_dir_task = Ref{Any}()

    get_settings() = get_configuration(config_toml_path; SliderServer_watch_dir=true, kwargs...)
    old_settings = get_settings()

    run_dir_task[] = Pluto.@asynclog begin
        run_directory(start_dir; notebook_paths, on_ready, config_toml_path, SliderServer_watch_dir=true, kwargs...)
    end

    Pluto.@asynclog while true
        new_settings = get_settings()

        if old_settings != new_settings
            @error "Configuration changed. Shutting down!"

            # @ignorefailure schedule(run_dir_task[], InterruptException(); error=true)
            exit()
        end

        sleep(5)
        fetch_pull(start_dir)
    end

    while true
        try
            wait(run_dir_task[])
        catch e
            if e isa InterruptException
                yield()
                sleep(2)
            else
                showerror(stderr, e, catch_backtrace())
            end
            yield()
            sleep(2)
        end
    end
end

function kind_of_debounced(f)
    update_waiting = Ref(true)
    running = Ref(false)

    function go(args...)
        # @info "trigger" update_waiting[] running[]
        update_waiting[] = true
        if !running[]
            running[] = true
            update_waiting[] = false

            f(args...)
            running[] = false
        end
        update_waiting[] && go(args...)
    end

    return go
end


end
