
import Pluto: Pluto, without_pluto_file_extension, @asynclog
using Base64
using SHA
using FromFile

@from "./MoreAnalysis.jl" import MoreAnalysis 
@from "./Export.jl" import Export: Export, generate_html, try_fromcache, try_tocache
@from "./Types.jl" import Types: PlutoDeploySettings, NotebookSession, RunningNotebook, FinishedNotebook
@from "./FileHelpers.jl" import FileHelpers: find_notebook_files_recursive
myhash = base64encode ∘ sha256
function path_hash(path)
    myhash(read(path))
end

showall(xs) = Text(join(string.(xs),"\n"))


###
# Shutdown
function process(s::NotebookSession{String,Nothing,<:Any};
        server_session::Pluto.ServerSession,
        settings::PlutoDeploySettings,
        output_dir::AbstractString,
        start_dir::AbstractString,
    )::NotebookSession

    
    if s.run isa RunningNotebook
        Pluto.SessionActions.shutdown(server_session, s.run.notebook)
    end

    try
        remove_static_export(s.path;
            settings,
            output_dir,
        )
    catch e
        @warn "Failed to remove static export files" s.path exception=(e,catch_backtrace())
    end
    
    @info "Shut down" s.path

    NotebookSession(;
        path=s.path,
        current_hash=nothing,
        desired_hash=nothing,
        run=nothing,
    )
end

###
# Launch
function process(s::NotebookSession{Nothing,String,<:Any};
        server_session::Pluto.ServerSession,
        settings::PlutoDeploySettings,
        output_dir::AbstractString,
        start_dir::AbstractString,
    )::NotebookSession

    path = s.path
    abs_path = joinpath(start_dir, path)
    new_hash = path_hash(abs_path)
    if new_hash != s.desired_hash
        @error "Hashfk ajhsdf kha sdkfjh "
    end

    @info "Launching the notebook"

    # TODO: Take these from Settings
    jl_contents = read(abs_path, String)
    hash = myhash(jl_contents)
    
    keep_running = settings.SliderServer.enabled
    skip_cache = keep_running || path ∈ settings.Export.ignore_cache

    cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, hash)

    run = if cached_state !== nothing
        @info "Loaded from cache, skipping notebook run" hash
        original_state = cached_state
        FinishedNotebook(;
            path,
            original_state,
        )
    else
        try
            # open and run the notebook (TODO: tell pluto not to write to the notebook file)
            notebook = Pluto.SessionActions.open(server_session, abs_path; run_async=false)
            # get the state object
            original_state = Pluto.notebook_to_js(notebook)
            # shut down the notebook
            if !keep_running
                @info "Shutting down notebook process"
                Pluto.SessionActions.shutdown(server_session, notebook)
            end
            try_tocache(settings.Export.cache_dir, hash, original_state)
            if keep_running
                bond_connections = MoreAnalysis.bound_variable_connections_graph(notebook)
                @info "Bond connections" showall(collect(bond_connections))

                RunningNotebook(;
                    path,
                    notebook,
                    original_state,
                    bond_connections,
                )
            else
                FinishedNotebook(;
                    path,
                    original_state,
                )
            end
        catch e
            (e isa InterruptException) || rethrow(e)
            @error "Failed to run notebook!" path exception=(e,catch_backtrace())
            # continue
            nothing
        end
    end

    generate_static_export(path, run.original_state, jl_contents;
        settings,
        output_dir,
    )

    NotebookSession(;
        path=s.path,
        current_hash=new_hash,
        desired_hash=s.desired_hash,
        run=run,
    )
end

###
# Update if needed
function process(s::NotebookSession{String,String,<:Any};
        server_session::Pluto.ServerSession,
        settings::PlutoDeploySettings,
        output_dir::AbstractString,
        start_dir::AbstractString,
    )::NotebookSession

    @info "Update method called" s.path s.current_hash s.desired_hash

    if s.current_hash != s.desired_hash
        @info "Updating notebook..." s.path
        
        # Simple way to update: shut down notebook and start new one
        if s.run isa RunningNotebook
            Pluto.SessionActions.shutdown(server_session, s.run.notebook)
        end

        @info "Shutdown done" s.path

        result = process(NotebookSession(;
            path=s.path,
            current_hash=nothing,
            desired_hash=s.desired_hash,
            run=nothing,
        );
            server_session,
            settings,
            output_dir,
            start_dir,
        )
        @info "process relay done" s.path

        result
    else
        s
    end
end

###
# Leave it shut down
process(s::NotebookSession{Nothing,Nothing,<:Any}; kwargs...)::NotebookSession = s


should_shutdown(::NotebookSession{String,Nothing,<:Any}) = true
should_shutdown(::NotebookSession) = false
should_update(s::NotebookSession{String,String,<:Any}) = s.current_hash != s.desired_hash
should_update(::NotebookSession) = false
should_launch(::NotebookSession{Nothing,String,<:Any}) = true
should_launch(::NotebookSession) = false

will_process(s) = should_update(s) || should_launch(s) || should_shutdown(s)



# """
# Wait for notebook to have 0 running or queued cells
# Poll in intervals of 5 seconds
# """
# function waitnotebookready(notebook::Pluto.Notebook)
#     i = 0
#     sleep(3)  # "Make sure" pluto picked up the change in notebook 
#     println("Waiting for notebook to get ready")
#     while (i < 360)
#         isrunning = length(filter(cell -> (cell.queued || cell.running), notebook.cells)) > 0
#         if (!isrunning)
#             println("")
#             return
#         end
#         print("\r\nWaiting for notebook to be ready [$(5*i)s]")
#         sleep(5)
#         i += 1
#     end
#     @error "Couldn't get the notebook status after 30 minutes."
# end

# """
# Core Action. Renew a session without restarting it!

# This function renews the RunningNotebookSession that the PlutoSliderServer
# tracks with
# 1. updated hash (serve correct GET requests)
# 2. updated bond_connections
# 3. update original_state (will be used in export, if that is set)
# This implementation assumes Pluto will watch file updates
# There is a race condition there:
#     Webhook
#         -> pull
#         -> file changes
#             -> pluto picksup the change [is the file ready?]
#         -> renew_session [is pluto running? has pluto picked up file change?]
# """
# function renew_session!(notebook_sessions, server_session, outdated_sesh; 
#     settings::PlutoDeploySettings)
#     path = outdated_sesh.path
#     sesh = outdated_sesh.original

#     @info "Renewing " path
#     i = findfirst(s -> s.path == path, notebook_sessions)
#     if isnothing(i)
#         @warn "Can't find session to renew"
#         return (nothing, nothing, nothing)
#     end
#     jl_contents = try
#         read(joinpath(settings.SliderServer.start_dir, path), String)
#     catch e
#         @warn "notebook deleted; removing"
#         filter_sessions!(s -> s -> s.path != path, notebook_sessions, server_session)
#         return
#     end
#     new_hash = path_hash(abs_path)
#     session = notebook_sessions[i]
#     if new_hash == session.current_hash
#         println("Renewing unnecessary; returning!") 
#     end
#     # filewatching
#     # update_from_file(server_session, session.notebook)
#     # If pluto implements the filewatching itself, switch to the line below:
#     # waitnotebookready(session.notebook)
#     bond_connections = MoreAnalysis.bound_variable_connections_graph(session.notebook)
#     original_state = Pluto.notebook_to_js(session.notebook)
#     notebook_sessions[i] = RunningNotebookSession(;
#             path,
#             hash=new_hash,
#             notebook=session.notebook,
#             original_state,
#             bond_connections,
#         )
#         notebook_sessions[i], jl_contents, original_state
# end

"""
Core Action: Generate static export for a Pluto Notebook

# Arguments:
1. slider_server_url: URL of the slider server. This will be the URL of your server, if you deploy
2. offer_binder: Flag to enable the Binder button
3. binder_url: URL of the binder link that will be invoked. Use a compatible pluto-enabled binder 
4. baked_state: Whether to export pluto state within the html or in a separate file.
5. pluto_cdn_root: URL where pluto will go to find the static frontend assets 
"""
function generate_static_export(path, original_state, jl_contents; settings, output_dir)
    pluto_version = Export.try_get_exact_pluto_version()
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


    notebookfile_js = if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing)
        repr(basename(export_jl_path))
    else
        "undefined"
    end
    slider_server_url_js = if settings.Export.slider_server_url !== nothing
        repr(settings.Export.slider_server_url)
    else
        "undefined"
    end
    binder_url_js = if settings.Export.offer_binder
        repr(something(settings.Export.binder_url, "https://mybinder.org/v2/gh/fonsp/pluto-on-binder/v$(string(pluto_version))"))
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
        version=pluto_version,
        notebookfile_js, statefile_js,
        slider_server_url_js, binder_url_js,
        disable_ui=settings.Export.disable_ui
    )
    write(export_html_path, html_contents)

    if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing)
        write(export_jl_path, jl_contents)
    end

    @info "Written to $(export_html_path)"
end

tryrm(x) = isfile(x) && rm(x)

function remove_static_export(path; settings, output_dir)
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


    if !settings.Export.baked_state
        tryrm(export_statefile_path)
    end
    tryrm(export_html_path)
    if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing)
        tryrm(export_jl_path)
    end
end