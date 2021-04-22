module WebAPI
using HTTP
using SHA
import Pluto
import PlutoSliderServer: FinishedNotebookSession, RunningNotebookSession, QueuedNotebookSession, myhash, MoreAnalysis, generate_html, get_configuration

import JSON

include("./Export.jl")
include("./FileHelpers.jl")
import .Export: try_fromcache, try_tocache, default_index

showall(xs) = Text(join(string.(xs),"\n"))
pluto_version = Export.try_get_exact_pluto_version()

function path_hash(path)
    myhash(read(path))
end

function add_to_session!(server_session, notebook_sessions, path, settings, pluto_options)

    # Panayiotis: Can we re-set pluto_options???
    hash = path_hash(path) # Before running!
    keep_running = path ∉ settings.SliderServer.exclude
    skip_cache = keep_running || path ∈ settings.Export.ignore_cache

    cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, hash)
    if cached_state !== nothing
        @info "Loaded from cache, skipping notebook run" hash
        original_state = cached_state
    else
        try
            # open and run the notebook (TODO: tell pluto not to write to the notebook file)
            notebook = Pluto.SessionActions.open(server_session, path; run_async=false)
            # get the state object
            original_state = Pluto.notebook_to_js(notebook)
            # shut down the notebook (later)
            try_tocache(settings.Export.cache_dir, hash, original_state)
            if keep_running
                bond_connections = MoreAnalysis.bound_variable_connections_graph(notebook)
                @info "Bond connections" showall(collect(bond_connections))
                session = RunningNotebookSession(;
                    path=path,
                    hash=hash,
                    notebook=notebook, 
                    original_state=original_state, 
                    bond_connections=bond_connections,
                )
                push!(notebook_sessions, session)
            else 
                @info "Shutting down notebook process"
                Pluto.SessionActions.shutdown(server_session, notebook)
                session = FinishedNotebookSession(;
                    path=path,
                    hash=path_hash(path),
                    original_state=original_state, 
                )
            end
        catch e
            (e isa InterruptException) || rethrow(e)
            @error "Failed to run notebook!" path exception = (e, catch_backtrace())
            return
        end
    end
    if !isnothing(settings.Export.output_dir)
        generate_static_export(path, settings)
    end
end

function generate_static_export(path, settings)
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

    # TODO: maybe we can avoid writing the .jl file if only the slider server is needed? the frontend only uses it to get its hash
    var"we need the .jl file" = (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing)
    var"the .jl file is already there and might have changed" = isfile(export_jl_path)

    if var"we need the .jl file" || var"the .jl file is already there and might have changed"
        write(export_jl_path, jl_contents)
    end

    @info "Written to $(export_html_path)"
end


function remove_from_session!(server_session, notebook_sessions, hash)
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

function extend_router!(router, server_session, notebook_sessions, get_sesh)

    function get_notebooks(request::HTTP.Request)
        hashes = map(notebook_sessions) do sesh
            sesh isa RunningNotebookSession ? sesh.hash : nothing
        end
        running_hashes = filter(hash -> !isnothing(hash), hashes)
        HTTP.Response(200, "Notebooks that run are: " * join(running_hashes, ", "))
    end

    function get_notebook(request::HTTP.Request)
        sesh = get_sesh(request)
        notfound = sesh === nothing
        running = sesh isa RunningNotebookSession
        queued = sesh isa QueuedNotebookSession
        finished = sesh isa FinishedNotebookSession
        HTTP.Response(200, "Notebook with hash $('h') status is: [running:$(running), queued: $(queued), finished: $(finished), notfound: $(notfound)]")
    end

    function start_notebook(request::HTTP.Request)
        sesh = get_sesh(request)
        notfound = sesh === nothing
        running = sesh isa RunningNotebookSession
        queued = sesh isa QueuedNotebookSession
        finished = sesh isa FinishedNotebookSession
        notebook = "..."
        if running
            return HTTP.Response(200, "Notebook already running, nothing to do!")
        end
        path, io = mktemp()
        notebookbytes = HTTP.payload(request)
        @info path typeof(notebookbytes), notebookbytes 
        hash = myhash(notebookbytes)
        open(path, "w") do io
            write(io, notebookbytes)
        end
        add_to_session!(server_session, notebook_sessions, path)

        HTTP.Response(200, "Started notebook successfully " * hash)
    end

    function stop_notebook(request::HTTP.Request)
        sesh = get_sesh(request)
        notfound = sesh === nothing
        running = sesh isa RunningNotebookSession
        queued = sesh isa QueuedNotebookSession
        finished = sesh isa FinishedNotebookSession
        notebook_hash = sesh.hash
        if running
            remove_from_session!(server_session, notebook_sessions, notebook_hash)
            msg = "Successfully shut down " * sesh.hash
        else
            msg = "Nothing to do!"
        end
        @info msg
        return HTTP.Response(200, msg)
    end

    function reload_filesystem(request::HTTP.Request)
        
        if get(ENV, "GITHUB_SECRET", "") !== ""
            i = findfirst(a -> lowercase(a.first) == lowercase("X-Hub-Signature-256"), request.headers)
            @info request.headers i
            if (isnothing(i))
                @warn "Can't validate: header not found"
            end
            secure_header = request.headers[i].second
            digest = "sha256=" * bytes2hex(hmac_sha256(collect(codeunits(ENV["GITHUB_SECRET"])), request.body))
            println(length(request.body))
            println("Digest: " * digest)
            println("header: " * secure_header)
            security_test = digest == secure_header
            if !security_test
                return HTTP.Response(501, "Not authorized!")
            end
        end
        
        params = HTTP.queryparams(HTTP.URI(request.target))
        github_url = get(get(JSON.parse(String(request.body)), "repository", Dict()), "html_url", nothing)
        folder = !isnothing(github_url) ? split(github_url, "/")[end] : "spam"
        exclude_hases = get(params, "exclude", [])
        @async try
            if length(folder) > 0 
                toclone = github_url
                this_folder = pwd()
                @info this_folder
                run(`rm -rf "$folder"`)
                # Clone without history
                # Fetch/Pull if you have latest
                # Also have some cleanup around!
                run(`git clone "$toclone"`)
            else 
                return HTTP.Response(501, "Can't pull")
            end
            start_dir = "$this_folder/$folder"
            settings, pluto_options = get_configuration("$this_folder/$folder/pluto-deployment-environment/PlutoDeployment.toml")

            @info "New Settings" Text(settings)

            paths = ["$start_dir/$path" for path in find_notebook_files_recursive(start_dir) if !isnothing(path)]
            new_hashes = map(path_hash, paths)

            running_hashes = map(notebook_sessions) do sesh
                sesh isa RunningNotebookSession ? sesh.hash : nothing
            end

            to_delete = [h for h in running_hashes if !(h ∈ new_hashes) && !isnothing(h)]
            to_start = [h for h in new_hashes if !(h ∈ running_hashes) && !isnothing(h)]
            to_run = [p for p in paths if (path_hash(p) ∈ to_start)]
            @info "delete" to_delete
            @info "start" to_start
            @info "to run: " to_run
            for hash in to_delete
                remove_from_session!(server_session, notebook_sessions, hash)
            end

            for hash in to_start
                runpath = paths[findfirst(h -> hash === h, new_hashes)]
                add_to_session!(server_session, notebook_sessions, runpath, settings, pluto_options)
                @info "started" runpath
            end
            # Create index!
            if settings.SliderServer.serve_static_export_folder && settings.Export.create_index
                output_dir = something(ENV["current_root"], settings.Export.output_dir, "$start_dir")
                write(joinpath(output_dir, "index.html"), default_index((
                    without_pluto_file_extension(path) => without_pluto_file_extension(path) * ".html"
                    for path in to_run
                )))
                @info "Wrote index to" output_dir
            end
            @info "run successully!"
        catch e
            @warn "Fail in reloading " e
            showerror(stderr, e, stacktrace(catch_backtrace()))
            rethrow(e)
         HTTP.Response(503, "Failed to reload")
         finally
        end
        sleep(max(rand(), 0.1)) # That's both trigger async AND protection against timing attacks :O
        return HTTP.Response(200, "Webhook accepted, async job started!")

    end

    HTTP.@register(router, "GET", "/notebooks/", get_notebooks)
    HTTP.@register(router, "GET", "/notebook/*/", get_notebook)
    HTTP.@register(router, "POST", "/notebook/*/", start_notebook)
    HTTP.@register(router, "DELETE", "/notebook/*/", stop_notebook)
    HTTP.@register(router, "POST", "/github_webhook/", reload_filesystem)

end
end