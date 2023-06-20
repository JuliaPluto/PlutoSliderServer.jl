import Pluto: Pluto, without_pluto_file_extension, generate_html, @asynclog
using Base64
using FromFile

@from "./MoreAnalysis.jl" import bound_variable_connections_graph
@from "./Export.jl" import try_get_exact_pluto_version, try_fromcache, try_tocache
@from "./Types.jl" import NotebookSession, RunningNotebook, FinishedNotebook, RunResult
@from "./Configuration.jl" import PlutoDeploySettings, is_glob_match
@from "./FileHelpers.jl" import find_notebook_files_recursive
@from "./PlutoHash.jl" import plutohash


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
    new_hash = plutohash(jl_contents)
    if new_hash != s.desired_hash
        @warn "Notebook file does not have desired hash. This probably means that the file changed too quickly. Continuing and hoping for the best!" s.path new_hash s.desired_hash
    end

    keep_running =
        settings.SliderServer.enabled &&
        !is_glob_match(path, settings.SliderServer.exclude) &&
        occursin("@bind", jl_contents)
    skip_cache = keep_running || is_glob_match(path, settings.Export.ignore_cache)

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
            delete!(original_state, "status_tree")
            # shut down the notebook
            if !keep_running
                @info "Shutting down notebook process" s.path
                Pluto.SessionActions.shutdown(server_session, notebook)
            end
            try_tocache(settings.Export.cache_dir, new_hash, original_state)
            if keep_running
                bond_connections =
                    bound_variable_connections_graph(server_session, notebook)
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

    if run isa RunResult
        generate_static_export(
            path,
            run.original_state,
            jl_contents;
            settings,
            start_dir,
            output_dir,
        )
    end

    @info "### ✓ $(progress) Ready" s.path new_hash

    NotebookSession(; path, current_hash=new_hash, desired_hash=s.desired_hash, run)
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
        write_statefile(export_statefile_path, original_state)
        repr(basename(export_statefile_path))
    else
        statefile64 = base64encode() do io
            Pluto.pack(io, original_state)
        end

        "\"data:;base64,$(statefile64)\""
    end

    frontmatter = convert(
        Pluto.FrontMatter,
        get(
            () -> Pluto.FrontMatter(),
            get(() -> Dict{String,Any}(), original_state, "metadata"),
            "frontmatter",
        ),
    )
    header_html = Pluto.frontmatter_html(frontmatter)

    html_contents = Pluto.generate_html(;
        pluto_cdn_root=settings.Export.pluto_cdn_root,
        version=pluto_version,
        notebookfile_js,
        statefile_js,
        slider_server_url_js,
        binder_url_js,
        disable_ui=settings.Export.disable_ui,
        header_html,
    )
    write(export_html_path, html_contents)

    if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing) &&
       !settings.Export.baked_notebookfile
        write(export_jl_path, jl_contents)
    end

    @debug "Written to $(export_html_path)"
end

function write_statefile(path, state)
    data = Pluto.pack(state)
    write(path, data)
    @assert read(path) == data
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
end