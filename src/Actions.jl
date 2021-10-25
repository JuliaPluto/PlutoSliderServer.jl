module Actions
    import Pluto: Pluto, ServerSession, Firebasey, Token, withtoken, pluto_file_extensions, without_pluto_file_extension
    using Base64
    using SHA
    using OrderedCollections
    import HTTP
    using FromFile
    @from "./MoreAnalysis.jl" import MoreAnalysis 
    @from "./Export.jl" using Export
    @from "./Types.jl" using Types
    myhash = base64encode ∘ sha256
    showall(xs) = Text(join(string.(xs),"\n"))

    function add_to_session!(notebook_sessions, server_session, path, settings, run_server=true, start_dir=".")
        jl_contents = read(joinpath(start_dir, path), String)
        current_hash = myhash(jl_contents)
        # The 5 lines below are needed if the code is not invoked within PlutoSliderServer.run_directory
        i = findfirst(s -> s.current_hash == current_hash, notebook_sessions)
        if isnothing(i)
            push!(notebook_sessions, QueuedNotebookSession(;path, current_hash=current_hash))
            i = length(notebook_sessions)
        end
        keep_running = run_server && path ∉ settings.SliderServer.exclude
        skip_cache = keep_running || path ∈ settings.Export.ignore_cache

        local notebook, original_state

        cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, current_hash)
        if cached_state !== nothing
            @info "Loaded from cache, skipping notebook run" current_hash
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
                        current_hash,
                        notebook,
                        original_state,
                        bond_connections,
                    )
                else
                    notebook_sessions[i] = FinishedNotebookSession(;
                        path,
                        current_hash,
                        original_state,
                    )
                end
                try_tocache(settings.Export.cache_dir, current_hash, original_state)
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
            if settings.Export.baked_notebookfile
                "\"data:text/julia;charset=utf-8;base64,$(base64encode(jl_contents))\""
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
            repr(something(settings.Export.binder_url, Pluto.default_binder_url))
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

        if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing) && !settings.Export.baked_notebookfile
            write(export_jl_path, jl_contents)
        end

        @info "Written to $(export_html_path)"
    end
    
        
    function run_bonds_get_patch_info(server_session, notebook_session::NotebookSession, bonds::AbstractDict{Symbol,<:Any})::Union{AbstractDict{String,Any},Nothing}
        sesh = notebook_session
        
        notebook = sesh.notebook
        
        topological_order, new_state = withtoken(sesh.token) do
            try
                notebook.bonds = bonds

                names::Vector{Symbol} = Symbol.(keys(bonds))

                topological_order = Pluto.set_bond_values_reactive(
                    session=server_session,
                    notebook=notebook,
                    bound_sym_names=names,
                    run_async=false,
                )::Pluto.TopologicalOrder

                new_state = Pluto.notebook_to_js(notebook)

                topological_order, new_state
            catch e
                @error "Failed to set bond values" exception=(e, catch_backtrace())
                nothing, nothing
            end
        end
        if topological_order === nothing
            return nothing
        end

        ids_of_cells_that_ran = [c.cell_id for c in topological_order.runnable]

        @debug "Finished running!" length(ids_of_cells_that_ran)

        # We only want to send state updates about...
        function only_relevant(state)
            new = copy(state)
            # ... the cells that just ran and ...
            new["cell_results"] = filter(state["cell_results"]) do (id, cell_state)
                id ∈ ids_of_cells_that_ran
            end
            # ... nothing about bond values, because we don't want to synchronize among clients.
            new["bonds"] = Dict{String,Dict{String,Any}}()
            new
        end

        patches = Firebasey.diff(only_relevant(sesh.original_state), only_relevant(new_state))
        patches_as_dicts::Array{Dict} = patches

        Dict{String,Any}(
            "patches" => patches_as_dicts,
            "ids_of_cells_that_ran" => ids_of_cells_that_ran,
        )
    end
    
    function generate_static_staterequests(path, settings::PlutoDeploySettings, pluto_session::Pluto.ServerSession, notebook_session::NotebookSession, output_dir=".")
        sesh = notebook_session
        connections = sesh.bond_connections
        
        mkpath(
            joinpath(
            output_dir,
            "bondconnections",
        )
        )
        
        mkpath(joinpath(
            output_dir,
            "staterequest",
            HTTP.URIs.escapeuri(sesh.current_hash),
        ))
        
        write_path = joinpath(
            output_dir,
            "bondconnections",
            HTTP.URIs.escapeuri(sesh.current_hash)
        )
        
        write(write_path, Pluto.pack(sesh.bond_connections))
        
        @info "Written bond connections to " write_path
        
        for variable_group in Set(values(connections))
            
            names = sort(variable_group)
            
            possible_values = [Pluto.possible_bond_values(pluto_session::Pluto.ServerSession, sesh.notebook::Pluto.Notebook, n::Symbol) for n in names]
            
            for combination in Iterators.product(possible_values...)
                bonds = OrderedDict{Symbol,Any}(
                    n => OrderedDict{String,Any}("value" => v, "is_first_value" => true)
                    for (n,v) in zip(names, combination)                    
                )
                
                result = run_bonds_get_patch_info(pluto_session, sesh, bonds)
                
                if result !== nothing                 
                    write_path = joinpath(
                        output_dir,
                        "staterequest",
                        HTTP.URIs.escapeuri(sesh.current_hash),
                        Pluto.pack(bonds) |>
                            base64encode |>
                            HTTP.URIs.escapeuri
                    )
                    
                    write(write_path, Pluto.pack(result))
                    
                    @info "Written state request to " write_path
                    
                end
            end
            
        end
        
        
    end
end