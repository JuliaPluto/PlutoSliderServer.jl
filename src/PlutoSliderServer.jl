module PlutoSliderServer

using FromFile

@from "./MoreAnalysis.jl" import bound_variable_connections_graph
@from "./FileHelpers.jl" import find_notebook_files_recursive, list_files_recursive
@from "./IndexHTML.jl" import generate_index_html
@from "./IndexJSON.jl" import generate_index_json
@from "./Actions.jl" import process,
    should_shutdown, should_update, should_launch, will_process
@from "./Types.jl" import NotebookSession
@from "./Lock.jl" import withlock
@from "./Configuration.jl" import PlutoDeploySettings,
    ExportSettings, SliderServerSettings, get_configuration, is_glob_match
@from "./ConfigurationDocs.jl" import @extract_docs,
    get_kwdocs, list_options_md, list_options_toml
@from "./ReloadFolder.jl" import update_sessions!, select
@from "./HTTPRouter.jl" import make_router, ReferrerMiddleware
@from "./gitpull.jl" import fetch_pull

@from "./PlutoHash.jl" import plutohash, base64urlencode, base64urldecode
export plutohash, base64urlencode, base64urldecode

import Pluto
import Pluto:
    ServerSession,
    Firebasey,
    Token,
    withtoken,
    pluto_file_extensions,
    without_pluto_file_extension
using HTTP
using Sockets
import Pkg
import BetterFileWatching: watch_folder
import AbstractPlutoDingetjes: is_inside_pluto
import TerminalLoggers: TerminalLogger
import Logging: global_logger, ConsoleLogger
import GitHubActions: GitHubActionsLogger

export export_directory, run_directory, run_git_directory, github_action
export export_notebook, run_notebook

export show_sample_config_toml_file

const logger_loaded = Ref{Bool}(false)
function load_cool_logger()
    if !logger_loaded[]
        logger_loaded[] = true
        if ((global_logger() isa ConsoleLogger) && !is_inside_pluto())
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
    end
end

const sample_config_toml_file = """
# WARNING: this sample configuration file contains settings for **all options**, to demonstrate what is possible. For most users, we recommend keeping the configuration file small, and letting PlutoSliderServer choose the default settings automatically. 

# This means: DO NOT use this file in your setup, instead, create an empty toml file and **add only the settings that you want to change**. 

[Export]
$(list_options_toml(ExportSettings))

[SliderServer]
$(list_options_toml(SliderServerSettings))

[Pluto]
[Pluto.compiler]
threads = 1

# See documentation for `Pluto.Configuration` for the full list of options. You need specify the categories within `Pluto.Configuration.Options` (`compiler`, `evaluation`, etc).
"""

function show_sample_config_toml_file()
    Text(sample_config_toml_file)
end

merge_recursive(a::AbstractDict, b::AbstractDict) = mergewith(merge_recursive, a, b)
merge_recursive(a, b) = b

merge_recursive(a::PlutoDeploySettings, b::PlutoDeploySettings) = Configurations.from_dict(
    PlutoDeploySettings,
    merge_recursive(Configurations.to_dict(a), Configurations.to_dict(b)),
)

with_kwargs(original::PlutoDeploySettings; kwargs...) =
    merge_recursive(original, Configurations.from_kwargs(PlutoDeploySettings; kwargs...))

showall(xs) = Text(join(string.(xs), "\n"))

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
$(list_options_md(ExportSettings; prefix="Export"))
- `notebook_paths::Vector{String}=find_notebook_files_recursive(start_dir)`: If you do not want the recursive save behaviour, then you can set this to a vector of absolute paths. In that case, `start_dir` is ignored, and you should set `Export_output_dir`.
"""
function export_directory(args...; kwargs...)
    run_directory(args...; Export_enabled=true, SliderServer_enabled=false, kwargs...)
end
"""
    export_notebook(notebook_filename::String; kwargs...)

A single-file version of [`export_directory`](@ref).
"""
export_notebook(p; kwargs...) = run_notebook(
    p;
    Export_enabled=true,
    SliderServer_enabled=false,
    Export_create_index=false,
    kwargs...,
)
github_action = export_directory


"""
    run_notebook(notebook_filename::String; kwargs...)

A single-file version of [`run_directory`](@ref).
"""
function run_notebook(path::String; kwargs...)
    path = Pluto.tamepath(path)
    @assert isfile(path)
    run_directory(dirname(path); notebook_paths=[basename(path)], kwargs...)
end

"""
    run_directory(start_dir::String="."; export_options...)

Run the Pluto bind server for all Pluto notebooks in the given directory (recursive search). 

# Keyword arguments
$(list_options_md(SliderServerSettings; prefix="SliderServer"))
- `notebook_paths::Union{Nothing,Vector{String}}=nothing`: If you do not want the recursive save behaviour, then you can set this to a vector of absolute paths. In that case, `start_dir` is ignored, and you should set `Export_output_dir`.
- `Export_enabled::Bool=true`: Also export HTML files?

---

## Export keyword arguments

If `Export_enabled` is `true`, then additional `Export_` keywords can be given:
$(list_options_md(ExportSettings; prefix="Export"))
"""
function run_directory(
    start_dir::String=".";
    notebook_paths::Union{Nothing,Vector{String}}=nothing,
    on_ready::Function=((args...) -> nothing),
    config_toml_path::Union{String,Nothing}=default_config_path(),
    kwargs...,
)


    @assert joinpath("a", "b") == "a/b" "PlutoSliderServer does not work on Windows yet!"

    load_cool_logger()

    start_dir = Pluto.tamepath(start_dir)
    @assert isdir(start_dir)

    settings = get_configuration(config_toml_path; kwargs...)
    output_dir = something(
        settings.Export.output_dir,
        settings.SliderServer.enabled ? mktempdir() : start_dir,
    )
    mkpath(output_dir)

    if joinpath("a", "b") != "a/b"
        @error "PlutoSliderServer.jl is only designed to work on unix systems."
        exit()
    end

    function getpaths()
        all_nbs =
            notebook_paths !== nothing ? notebook_paths :
            find_notebook_files_recursive(start_dir)

        s_remaining = filter(!is_glob_match(settings.SliderServer.exclude), all_nbs)
        e_remaining = filter(!is_glob_match(settings.Export.exclude), all_nbs)

        if settings.Export.enabled
            if settings.SliderServer.enabled
                s_remaining ∪ e_remaining
            else
                e_remaining
            end
        else
            filter(s_remaining) do f
                try
                    occursin("@bind", read(joinpath(start_dir, f), String))
                catch
                    true
                end
            end
        end
    end

    @info "Versions" julia=VERSION pluto=Pluto.PLUTO_VERSION plutosliderserver=(VERSION >= v"1.9" ? pkgversion(@__MODULE__) : nothing)
    @info "Settings" Text(settings)

    settings.SliderServer.enabled &&
        @warn "Make sure that you run this slider server inside an isolated environment -- it is not intended to be secure. Assume that users can execute arbitrary code inside your notebooks."

    settings.Pluto.server.disable_writing_notebook_files = true
    settings.Pluto.evaluation.lazy_workspace_creation = true

    server_session = Pluto.ServerSession(; options=settings.Pluto)

    notebook_sessions = NotebookSession[]

    if settings.SliderServer.enabled
        static_dir =
            (settings.Export.enabled && settings.SliderServer.serve_static_export_folder) ?
            output_dir : nothing
        router =
            make_router(notebook_sessions, server_session; settings, static_dir, start_dir)

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
                @error "Port with number $port is already in use."
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

        # We start the HTTP server before launching notebooks so that the server responds to heroku/digitalocean garbage fast enough
        http_server = HTTP.serve!(
            router |> ReferrerMiddleware,
            hostIP,
            UInt16(port),
            server=serversocket,
        )

        @info "# Server started"
    else
        http_server = nothing
        serversocket = nothing
    end

    function write_index(sessions)
        if (
            settings.Export.enabled &&
            settings.Export.create_index &&
            # If `settings.SliderServer.serve_static_export_folder`, then we serve a dynamic index page (inside HTTPRouter.jl), so we don't want to create a static index page.
            !(
                settings.SliderServer.enabled &&
                settings.SliderServer.serve_static_export_folder
            )
        )
            # HTML
            exists = any([
                "index.html",
                "index.md",
                ("index" * e for e in pluto_file_extensions)...,
            ]) do f
                joinpath(output_dir, f) |> isfile
            end
            if !exists
                write(
                    joinpath(output_dir, "index.html"),
                    generate_index_html(sessions; settings),
                )
            end

            # JSON
            write(
                joinpath(output_dir, "pluto_export.json"),
                generate_index_json(sessions; settings, start_dir),
            )
        end
    end

    function refresh_until_synced(check_dir_on_every_step::Bool, did_something::Bool=false)
        should_continue = withlock(notebook_sessions) do

            if check_dir_on_every_step
                update_sessions!(notebook_sessions, getpaths(); start_dir)
                write_index(notebook_sessions)
            end

            # todo: try catch to release lock?
            to_shutdown = select(should_shutdown, notebook_sessions)
            to_update = select(should_update, notebook_sessions)
            to_launch = select(should_launch, notebook_sessions)

            s = something(to_shutdown, to_update, to_launch, "not found")

            if s != "not found"

                progress = "[$(
                    count(!will_process, notebook_sessions) + 1
                )/$(length(notebook_sessions))]"

                new = process(s; server_session, settings, output_dir, start_dir, progress)
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

        if did_something || should_continue
            write_index(notebook_sessions)
        end

        should_continue && refresh_until_synced(check_dir_on_every_step, true)
    end

    # RUN ALL NOTEBOOKS AND KEEP THEM RUNNING
    update_sessions!(notebook_sessions, getpaths(); start_dir)
    write_index(notebook_sessions)
    refresh_until_synced(false)

    should_watch = settings.SliderServer.enabled && settings.SliderServer.watch_dir

    watch_dir_task = Pluto.@asynclog if should_watch
        @info "Watching directory for changes..."
        debounced = kind_of_debounced() do _
            @debug "File change detected!"
            sleep(0.5)
            refresh_until_synced(true)
        end
        watch_folder(debounced, start_dir)
    end



    if http_server === nothing
        on_ready((; serversocket, http_server, server_session, notebook_sessions))
    else
        try
            if should_watch
                # todo: skip first watch_folder so that we dont need this sleepo (EDIT: i forgot why this sleep is here.. oops!)
                sleep(2)
            end
            on_ready((; serversocket, http_server, server_session, notebook_sessions))

            # blocking call, waiting for a Ctrl-C interrupt
            wait(http_server)
        catch e
            @info "# Closing web server..."
            @ignorefailure close(http_server)
            if should_watch
                @info "Stopping directory watching..."
                istaskdone(watch_dir_task) ||
                    @ignorefailure schedule(watch_dir_task, e; error=true)
            end
            e isa InterruptException || rethrow(e)
            @info "Server exited ✅"
        end
    end

    nothing
end

"""
    run_git_directory(start_dir::String="."; export_options...)

Like [`run_directory`](@ref), but will automatically keep running `git pull` in `start_dir` and update the slider server to match changes in the directory. See our README for more info.

If you use a `PlutoDeployment.toml` file, we also keep checking whether this file changed. If it changed, we **exit Julia session**, and you will have to restart it. Open an issue if this is a problem.
"""
function run_git_directory(
    start_dir::String=".";
    notebook_paths::Union{Nothing,Vector{String}}=nothing,
    on_ready::Function=((args...) -> ()),
    config_toml_path::Union{String,Nothing}=default_config_path(),
    kwargs...,
)

    start_dir = Pluto.tamepath(start_dir)
    @assert isdir(start_dir)


    get_settings() =
        get_configuration(config_toml_path; SliderServer_watch_dir=true, kwargs...)
    old_settings = get_settings()

    run_dir_task = Pluto.@asynclog begin
        run_directory(
            start_dir;
            notebook_paths,
            on_ready,
            config_toml_path,
            SliderServer_watch_dir=true,
            kwargs...,
        )
    end
    old_deps = Pkg.dependencies()
    pull_loop_task = Pluto.@asynclog while true
        new_settings = get_settings()
        new_deps = Pkg.dependencies()

        if old_settings != new_settings
            @error "Configuration changed. Shutting down!"

            println(stderr, "Old settings:")
            println(stderr, repr(old_settings))
            println(stderr, "")
            println(stderr, "New settings:")
            println(stderr, repr(new_settings))

            exit() # this should trigger a restart, using the new settings
        end
        if old_deps != new_deps
            @error "Package environment changed. Shutting down!"
            exit() # this should trigger a restart, using the new settings
        end

        sleep(5)
        try
            fetch_pull(start_dir)
        catch e
            @warn "git: Error in poll_pull_loop" exception = (e, catch_backtrace())
        end
    end

    waitall([run_dir_task, pull_loop_task])
end

function waitall(tasks)
    killing = Ref(false)
    @sync for t in tasks
        try
            wait(t)
        catch e
            if !(e isa InterruptException)
                showerror(stderr, e, catch_backtrace())
            end
            if !killing[]
                killing[] = true
                for t2 in tasks
                    try
                        schedule(t2, e; error=true)
                    catch e
                    end
                end
            end
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
