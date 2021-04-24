module Actions
    import Pluto: Pluto, without_pluto_file_extension
    using Base64
    using SHA
    using FromFile
    export myhash, path_hash, showall, add_to_session!, renew_session!, remove_from_session!, register_webhook, run_folder, get_paths_from, generate_static_export
    @from "./MoreAnalysis.jl" import MoreAnalysis 
    @from "./Export.jl" using Export
    @from "./Types.jl" using Types
    @from "./FileHelpers.jl" import FileHelpers: find_notebook_files_recursive
    myhash = base64encode ∘ sha256
    path_hash = path -> myhash(read(path))

    showall(xs) = Text(join(string.(xs),"\n"))

    """
    Core Action. 
    
    add_to_session! lets PlutoSliderServer know about a new session
    start_dir should come from settings
    """
    function add_to_session!(notebook_sessions, server_session, path, settings, run_server, start_dir)
        # TODO: Take these from Settings
        jl_contents = read(joinpath(start_dir, path), String)
        hash = myhash(jl_contents)
        # The 5 lines below are needed if the code is not invoked within PlutoSliderServer.run_directory
        i = findfirst(s -> s.hash == hash, notebook_sessions)
        if isnothing(i)
            push!(notebook_sessions, QueuedNotebookSession(;path, hash=hash))
            i = length(notebook_sessions)
        end
        keep_running = occursin("@bind", read(joinpath(start_dir, path), String)) && path ∉ settings.SliderServer.exclude
        skip_cache = keep_running || path ∈ settings.Export.ignore_cache

        local notebook, original_state

        cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, hash)
        # This probably only works in github action context
        if cached_state !== nothing
            @info "Loaded from cache, skipping notebook run" hash
            original_state = cached_state
        else
            try
                # open and run the notebook (TODO: tell pluto not to write to the notebook file)
                notebook = Pluto.SessionActions.open(server_session, joinpath(start_dir, path); run_async=false)
                # get the state object
                original_state = Pluto.notebook_to_js(notebook)
                # shut down the notebook
                if !keep_running
                    @info "Shutting down notebook process"
                    Pluto.SessionActions.shutdown(server_session, notebook)
                end
                if keep_running
                    bond_connections = MoreAnalysis.bound_variable_connections_graph(notebook)
                    @info "Bond connections" showall(collect(bond_connections))

                    # By setting notebook_sessions[i] to a running session, (modifying the array), the HTTP router will now start serving requests for this notebook.
                    notebook_sessions[i] = RunningNotebookSession(;
                        path,
                        hash,
                        notebook,
                        original_state,
                        bond_connections,
                    )
                else
                    notebook_sessions[i] = FinishedNotebookSession(;
                        path,
                        hash,
                        original_state,
                    )
                end
                try_tocache(settings.Export.cache_dir, hash, original_state)
            catch e
                (e isa InterruptException) || rethrow(e)
                @error "Failed to run notebook!" path exception=(e,catch_backtrace())
                # continue
            end
        end
        notebook_sessions[i], jl_contents, original_state
    end

    """
    Wait for notebook to have 0 running or queued cells
    Poll in intervals of 5 seconds
    """
    function waitnotebookready(notebook::Pluto.Notebook)
        i = 0
        sleep(3)  # "Make sure" pluto picked up the change in notebook 
        println("Waiting for notebook to get ready")
        while (i < 360)
            isrunning = length(filter(cell -> (cell.queued || cell.running), notebook.cells)) > 0
            if (!isrunning)
                println("")
                return
            end
            print("\r\nWaiting for notebook to be ready [$(5*i)s]")
            sleep(5)
            i += 1
        end
        @error "Couldn't get the notebook status after 30 minutes."
    end

    """
    Core Action. Renew a session without restarting it!

    This function renews the RunningNotebookSession that the PlutoSliderServer
    tracks with
    1. updated hash (serve correct GET requests)
    2. updated bond_connections
    3. update original_state (will be used in export, if that is set)
    This implementation assumes Pluto will watch file updates
    There is a race condition there:
        Webhook
            -> pull
            -> file changes
                -> pluto picksup the change [is the file ready?]
            -> renew_session [is pluto running? has pluto picked up file change?]
    """
    function renew_session!(notebook_sessions, server_session, path, settings)
        @info "Renewing " path
        jl_contents = read(joinpath(settings.SliderServer.start_dir, path), String)
        new_hash = path_hash(path)
        i = findfirst(s -> s.path == path, notebook_sessions)
        if isnothing(i)
            @warn "Can't find session to renew"
            return (nothing, nothing, nothing)
        end
        session = notebook_sessions[i]
        waitnotebookready(session.notebook)
        bond_connections = MoreAnalysis.bound_variable_connections_graph(session.notebook)
        original_state = Pluto.notebook_to_js(session.notebook)
        notebook_sessions[i] = RunningNotebookSession(;
             path,
             hash=new_hash,
             notebook=session.notebook,
             original_state,
             bond_connections,
         )
         notebook_sessions[i], jl_contents, original_state
    end
    """
    Core Action. Stops a notebook from running in PlutoSliderServer
    """
    function remove_from_session!(notebook_sessions, server_session, hash)
        i = findfirst(notebook_sessions) do sesh
            sesh.hash === hash
        end
        if i === nothing
            @warn hash "Don't stop anything"
            return
        end
        sesh = notebook_sessions[i]
        Pluto.SessionActions.shutdown(server_session, sesh.notebook)
        notebook_sessions[i] = FinishedNotebookSession(;
            sesh.path,
            sesh.hash,
            sesh.original_state,
        )
    end

    """
    Starts and creates static exports for all notebooks in a folder,
    respecting the settings provided
    """
    function run_folder(folder, notebook_sessions, server_session, settings, output_dir)
        to_run = get_paths_from(folder, settings)
        for path in to_run
            @info path "starting"
            session, jl_contents, original_state = add_to_session!(notebook_sessions, server_session, path, settings, true, folder)
            if path ∉ settings.Export.exclude
                generate_static_export(path, settings, original_state, output_dir, jl_contents)
            end
        end
        @info "success"
    end

    """
    Helper function to get the paths in a folder , excluding those
    set for exclusion in settings
    """
    function get_paths_from(folder, settings)
        notebook_paths = find_notebook_files_recursive(folder)
        to_run = setdiff(notebook_paths, settings.SliderServer.exclude)
    end

    """
    Core Action: Generate static export for a Pluto Notebook
    Settings must specify
    1. slider_server_url: URL of the slider server. This will be the URL of your server, if you deploy
    2. offer_binder: Flag to enable the Binder button
    3. binder_url: URL of the binder link that will be invoked. Use a compatible pluto-enabled binder 
    4. baked_state: Whether to export pluto state within the html or in a separate file.
    5. pluto_cdn_root: URL where pluto will go to find the static frontend assets 
    """
    function generate_static_export(path, settings, original_state, output_dir, jl_contents)
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
end