import Pluto:
    Pluto, without_pluto_file_extension, generate_html, @asynclog, withtoken, Firebasey
using Base64
using FromFile
import HTTP.URIs

@from "./MoreAnalysis.jl" import bound_variable_connections_graph
@from "./Export.jl" import try_get_exact_pluto_version,
    try_fromcache, try_tocache, write_statefile
@from "./Types.jl" import NotebookSession, RunningNotebook, FinishedNotebook, RunResult
@from "./Configuration.jl" import PlutoDeploySettings, is_glob_match
@from "./precomputed/index.jl" import generate_precomputed_staterequests
@from "./PlutoHash.jl" import plutohash
@from "./PathUtils.jl" import to_local_path, to_url_path


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


    url_path = s.path

    if s.run isa RunningNotebook
        Pluto.SessionActions.shutdown(server_session, s.run.notebook)
    end

    try
        remove_static_export(url_path; settings, output_dir)
    catch e
        @warn "Failed to remove static export files" path = url_path exception =
            (e, catch_backtrace())
    end

    @info "### ✓ $(progress) Shutdown complete" path = url_path

    NotebookSession(; path=url_path, current_hash=nothing, desired_hash=nothing, run=nothing)
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

    url_path = s.path # stored using forward slashes relative to start_dir
    abs_path = joinpath(start_dir, to_local_path(url_path))

    @info "###### ◐ $(progress) Launching..." path = url_path

    jl_contents = read(abs_path, String)
    new_hash = plutohash(jl_contents)
    if new_hash != s.desired_hash
        @warn "Notebook file does not have desired hash. This probably means that the file changed too quickly. Continuing and hoping for the best!" path =
            url_path new_hash s.desired_hash
    end

    keep_running = (settings.SliderServer.enabled || settings.Precompute.enabled) &&
        !is_glob_match(url_path, settings.SliderServer.exclude) &&
        occursin("@bind", jl_contents)
    skip_cache = keep_running || is_glob_match(url_path, settings.Export.ignore_cache)

    cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, new_hash)

    t_elapsed = @elapsed run = if cached_state !== nothing
        @info "Loaded from cache, skipping notebook run" path = url_path new_hash
        original_state = cached_state
        FinishedNotebook(; path=url_path, original_state)
    else
        try
            # open and run the notebook
            notebook = Pluto.SessionActions.open(server_session, abs_path; run_async=false)
            # get the state object
            original_state = Pluto.notebook_to_js(notebook)
            delete!(original_state, "status_tree")
            # shut down the notebook
            if !keep_running
                @info "Shutting down notebook process" path = url_path
                Pluto.SessionActions.shutdown(server_session, notebook)
            end
            try_tocache(settings.Export.cache_dir, new_hash, original_state)
            if keep_running
                bond_connections =
                    bound_variable_connections_graph(server_session, notebook)
                @info "Bond connections" path = url_path showall(collect(bond_connections))

                RunningNotebook(; path=url_path, notebook, original_state, bond_connections)
            else
                FinishedNotebook(; path=url_path, original_state)
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
            url_path,
            run.original_state,
            jl_contents;
            settings,
            start_dir,
            output_dir,
        )
    end

    new_session = NotebookSession(; path=url_path, current_hash=new_hash, desired_hash=s.desired_hash, run)
    if settings.Precompute.enabled
        generate_precomputed_staterequests(
            new_session;
            settings,
            pluto_session=server_session,
            output_dir,
        )
        # TODO shutdown
    end

    @info "### ✓ $(progress) Ready" path = url_path new_hash t_elapsed

    new_session
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

    url_path = s.path

    if s.current_hash != s.desired_hash
        @info "Updating notebook... will shut down and relaunch" path = url_path

        # Simple way to update: shut down notebook and start new one
        if s.run isa RunningNotebook
            Pluto.SessionActions.shutdown(server_session, s.run.notebook)
        end

        @info "Shutdown complete" path = url_path

        result = process(
            NotebookSession(;
                path=url_path,
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
    url_path,
    original_state,
    jl_contents;
    settings,
    output_dir,
    start_dir,
)
    pluto_version = try_get_exact_pluto_version()
    export_jl_path = let
        relative_to_notebooks_dir = url_path
        joinpath(output_dir, to_local_path(relative_to_notebooks_dir))
    end
    export_html_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(url_path) * ".html"
        joinpath(output_dir, to_local_path(relative_to_notebooks_dir))
    end
    export_statefile_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(url_path) * ".plutostate"
        joinpath(output_dir, to_local_path(relative_to_notebooks_dir))
    end


    mkpath(dirname(export_jl_path))
    mkpath(dirname(export_html_path))
    mkpath(dirname(export_statefile_path))


    slider_server_running_somewhere =
        settings.Export.slider_server_url !== nothing ||
        (
            settings.SliderServer.serve_static_export_folder &&
            settings.SliderServer.enabled
        ) ||
        settings.Precompute.enabled

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
        abs_path = joinpath(start_dir, to_local_path(url_path))
        url_of_root = to_url_path(relpath(start_dir, dirname(abs_path))) # e.g. "." or "../../.."
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

tryrm(x) = isfile(x) && rm(x)

function remove_static_export(url_path; settings, output_dir)
    export_jl_path = let
        relative_to_notebooks_dir = url_path
        joinpath(output_dir, to_local_path(relative_to_notebooks_dir))
    end
    export_html_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(url_path) * ".html"
        joinpath(output_dir, to_local_path(relative_to_notebooks_dir))
    end
    export_statefile_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(url_path) * ".plutostate"
        joinpath(output_dir, to_local_path(relative_to_notebooks_dir))
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
