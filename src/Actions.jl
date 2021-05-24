module Actions
    import Pluto: Pluto, without_pluto_file_extension
    using Base64
    using SHA
    using FromFile
    @from "./MoreAnalysis.jl" import MoreAnalysis 
    @from "./Export.jl" using Export
    @from "./Types.jl" using Types
    myhash = base64encode ∘ sha256
    showall(xs) = Text(join(string.(xs),"\n"))

    function add_to_session!(notebook_sessions, server_session, path, settings, run_server=true, start_dir=".")
        jl_contents = read(joinpath(start_dir, path), String)
        hash = myhash(jl_contents)
        # The 5 lines below are needed if the code is not invoked within PlutoSliderServer.run_directory
        i = findfirst(s -> s.hash == hash, notebook_sessions)
        if isnothing(i)
            push!(notebook_sessions, QueuedNotebookSession(;path, hash=hash))
            i = length(notebook_sessions)
        end
        keep_running = run_server && path ∉ settings.SliderServer.exclude
        skip_cache = keep_running || path ∈ settings.Export.ignore_cache

        local notebook, original_state

        cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, hash)
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

    function generate_static_export(path, settings, original_state=nothing, output_dir=".", jl_contents=nothing)
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
            if settings.Export.baked_state
                "\"data:;base64,$(base64encode(jl_contents))\""
            else
                repr(basename(export_jl_path))
            end
        else
            "undefined"
        end
        slider_server_url_js = if settings.Export.slider_server_url !== nothing
            repr(settings.Export.slider_server_url)
        else
            "undefined"
        end
        binder_url_js = if settings.Export.offer_binder
            repr(something(settings.Export.binder_url, "https://mybinder.org/v2/gh/fonsp/pluto-on-binder/v$(string(Pluto.PLUTO_VERSION))"))
            # not string(pluto_version) because it has to be an `x.y.z` version number, not a commit hash
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

        if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing) && !settings.Export.baked_state
            write(export_jl_path, jl_contents)
        end

        @info "Written to $(export_html_path)"
    end
end