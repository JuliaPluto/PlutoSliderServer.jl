import Pluto: Pluto, without_pluto_file_extension, generate_html, @asynclog
using Base64
using SHA
using OrderedCollections
using FromFile

@from "./MoreAnalysis.jl" import bound_variable_connections_graph
@from "./Export.jl" import try_get_exact_pluto_version, try_fromcache, try_tocache
@from "./Types.jl" import NotebookSession, RunningNotebook, FinishedNotebook
@from "./Configuration.jl" import PlutoDeploySettings
@from "./FileHelpers.jl" import find_notebook_files_recursive
myhash = base64encode ∘ sha256
function path_hash(path)
    myhash(read(path))
end

showall(xs) = Text(join(string.(xs), "\n"))


###
# Shutdown
function process(
    s::NotebookSession{String,Nothing,<:Any};
    server_session::Pluto.ServerSession,
    settings::PlutoDeploySettings,
    output_dir::AbstractString,
    start_dir::AbstractString,
    progress,
)::NotebookSession


    if s.run isa RunningNotebook
        Pluto.SessionActions.shutdown(server_session, s.run.notebook)
    end

    try
        remove_static_export(s.path; settings, output_dir)
    catch e
        @warn "Failed to remove static export files" s.path exception =
            (e, catch_backtrace())
    end

    @info "### ✓ $(progress) Shutdown complete" s.path

    NotebookSession(; path=s.path, current_hash=nothing, desired_hash=nothing, run=nothing)
end

###
# Launch
function process(
    s::NotebookSession{Nothing,String,<:Any};
    server_session::Pluto.ServerSession,
    settings::PlutoDeploySettings,
    output_dir::AbstractString,
    start_dir::AbstractString,
    progress,
)::NotebookSession

    path = s.path
    abs_path = joinpath(start_dir, path)

    @info "###### ◐ $(progress) Launching..." s.path

    jl_contents = read(abs_path, String)
    new_hash = myhash(jl_contents)
    if new_hash != s.desired_hash
        @warn "Notebook file does not have desired hash. This probably means that the file changed too quickly. Continuing and hoping for the best!" s.path new_hash s.desired_hash
    end

    keep_running = settings.SliderServer.enabled
    skip_cache = keep_running || path ∈ settings.Export.ignore_cache

    cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, new_hash)

    run = if cached_state !== nothing
        @info "Loaded from cache, skipping notebook run" s.path new_hash
        original_state = cached_state
        FinishedNotebook(; path, original_state)
    else
        try
            # open and run the notebook
            notebook = Pluto.SessionActions.open(server_session, abs_path; run_async=false)
            # get the state object
            original_state = Pluto.notebook_to_js(notebook)
            # shut down the notebook
            if !keep_running
                @info "Shutting down notebook process" s.path
                Pluto.SessionActions.shutdown(server_session, notebook)
            end
            try_tocache(settings.Export.cache_dir, new_hash, original_state)
            if keep_running
                bond_connections = bound_variable_connections_graph(notebook)
                @info "Bond connections" s.path showall(collect(bond_connections))

                RunningNotebook(; path, notebook, original_state, bond_connections)
            else
                FinishedNotebook(; path, original_state)
            end
        catch e
            (e isa InterruptException) || rethrow(e)
            @error "$(progress) Failed to run notebook!" path exception =
                (e, catch_backtrace())
            # continue
            nothing
        end
    end

    generate_static_export(
        path,
        run.original_state,
        jl_contents;
        settings,
        start_dir,
        output_dir,
    )
    if settings.Export.static_export_state
        generate_static_staterequests(path, settings, server_session, session, output_dir)
    end

    @info "### ✓ $(progress) Ready" s.path new_hash

    NotebookSession(;
        path=s.path,
        current_hash=new_hash,
        desired_hash=s.desired_hash,
        run=run,
    )
end

###
# Update if needed
function process(
    s::NotebookSession{String,String,<:Any};
    server_session::Pluto.ServerSession,
    settings::PlutoDeploySettings,
    output_dir::AbstractString,
    start_dir::AbstractString,
    progress,
)::NotebookSession

    if s.current_hash != s.desired_hash
        @info "Updating notebook... will shut down and relaunch" s.path

        # Simple way to update: shut down notebook and start new one
        if s.run isa RunningNotebook
            Pluto.SessionActions.shutdown(server_session, s.run.notebook)
        end

        @info "Shutdown complete" s.path

        result = process(
            NotebookSession(;
                path=s.path,
                current_hash=nothing,
                desired_hash=s.desired_hash,
                run=nothing,
            );
            server_session,
            settings,
            output_dir,
            start_dir,
            progress,
        )

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


"""
Core Action: Generate static export for a Pluto Notebook

# Arguments:
1. slider_server_url: URL of the slider server. This will be the URL of your server, if you deploy
2. offer_binder: Flag to enable the Binder button
3. binder_url: URL of the binder link that will be invoked. Use a compatible pluto-enabled binder 
4. baked_state: Whether to export pluto state within the html or in a separate file.
5. pluto_cdn_root: URL where pluto will go to find the static frontend assets 
"""
function generate_static_export(
    path,
    original_state,
    jl_contents;
    settings,
    output_dir,
    start_dir,
)
    pluto_version = try_get_exact_pluto_version()
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


    slider_server_running_somewhere =
        settings.Export.slider_server_url !== nothing ||
        (settings.SliderServer.serve_static_export_folder && settings.SliderServer.enabled)

    notebookfile_js = if settings.Export.offer_binder || slider_server_running_somewhere
        if settings.Export.baked_notebookfile
            "\"data:text/julia;charset=utf-8;base64,$(base64encode(jl_contents))\""
        else
            repr(basename(export_jl_path))
        end
    else
        "undefined"
    end
    slider_server_url_js = if slider_server_running_somewhere
        abs_path = joinpath(start_dir, path)
        url_of_root = relpath(start_dir, dirname(abs_path)) # e.g. "." or "../../.." 
        repr(something(settings.Export.slider_server_url, url_of_root))
    else
        "undefined"
    end
    binder_url_js = if settings.Export.offer_binder
        repr(something(settings.Export.binder_url, Pluto.default_binder_url))
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
        notebookfile_js,
        statefile_js,
        slider_server_url_js,
        binder_url_js,
        disable_ui=settings.Export.disable_ui,
    )
    write(export_html_path, html_contents)

    if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing) &&
       !settings.Export.baked_notebookfile
        write(export_jl_path, jl_contents)
    end

    @debug "Written to $(export_html_path)"
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
    if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing) &&
       !settings.Export.baked_notebookfile
        tryrm(export_jl_path)
    end


    function run_bonds_get_patch_info(
        server_session,
        notebook_session::NotebookSession,
        bonds::AbstractDict{Symbol,<:Any},
    )::Union{AbstractDict{String,Any},Nothing}
        sesh = notebook_session

        notebook = sesh.notebook

        topological_order, new_state = withtoken(sesh.run.token) do
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
                @error "Failed to set bond values" exception = (e, catch_backtrace())
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

        patches =
            Firebasey.diff(only_relevant(sesh.run.original_state), only_relevant(new_state))
        patches_as_dicts::Array{Dict} = patches

        Dict{String,Any}(
            "patches" => patches_as_dicts,
            "ids_of_cells_that_ran" => ids_of_cells_that_ran,
        )
    end

    function generate_static_staterequests(
        path,
        settings::PlutoDeploySettings,
        pluto_session::Pluto.ServerSession,
        notebook_session::NotebookSession,
        output_dir=".",
    )
        sesh = notebook_session
        connections = sesh.bond_connections

        mkpath(joinpath(output_dir, "bondconnections"))

        mkpath(joinpath(output_dir, "staterequest", HTTP.URIs.escapeuri(sesh.current_hash)))

        write_path =
            joinpath(output_dir, "bondconnections", HTTP.URIs.escapeuri(sesh.current_hash))

        write(write_path, Pluto.pack(sesh.bond_connections))

        @info "Written bond connections to " write_path

        for variable_group in Set(values(connections))

            names = sort(variable_group)

            possible_values = [
                Pluto.possible_bond_values(
                    pluto_session::Pluto.ServerSession,
                    sesh.notebook::Pluto.Notebook,
                    n::Symbol,
                ) for n in names
            ]

            for combination in Iterators.product(possible_values...)
                bonds = OrderedDict{Symbol,Any}(
                    n =>
                        OrderedDict{String,Any}("value" => v, "is_first_value" => true)
                    for (n, v) in zip(names, combination)
                )

                result = run_bonds_get_patch_info(pluto_session, sesh, bonds)

                if result !== nothing
                    write_path = joinpath(
                        output_dir,
                        "staterequest",
                        HTTP.URIs.escapeuri(sesh.current_hash),
                        Pluto.pack(bonds) |> base64encode |> HTTP.URIs.escapeuri,
                    )

                    write(write_path, Pluto.pack(result))

                    @info "Written state request to " write_path

                end
            end

        end


    end
end