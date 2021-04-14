module WebAPI
using HTTP
using SHA
import Pluto
import PlutoSliderServer: FinishedNotebookSession, RunningNotebookSession, QueuedNotebookSession, myhash, MoreAnalysis, find_notebook_files_recursive

import JSON

# curl -X DELETE http://127.0.0.1:2345/notebook/uut+KtbdWht451eFX7gBhnqfHRSarm0KK6NyontJkQE=/
# curl -X GET http://127.0.0.1:2345/notebook/uut+KtbdWht451eFX7gBhnqfHRSarm0KK6NyontJkQE=/
# curl -X POST --data-binary "@./notebook2.jl.assets/notebook2.jl" http://127.0.0.1:2345/notebook/start/
# curl -X GET http://127.0.0.1:2345/github_webhook/?github_url=https://github.com/pankgeorg/spam

function path_hash(path)
    myhash(read(path))
end

function add_to_session(server_session, notebook_sessions, path)
    notebook = Pluto.SessionActions.open(server_session, path; run_async=false)
    original_state = Pluto.notebook_to_js(notebook)
    bond_connections = MoreAnalysis.bound_variable_connections_graph(notebook)
    session = RunningNotebookSession(;
        path=path,
        hash=path_hash(path),
        notebook=notebook, 
        original_state=original_state, 
        bond_connections=bond_connections,
    )
    push!(notebook_sessions, session)
end

function remove_from_session(server_session, notebook_sessions, hash)
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

function extend_router(router, server_session, notebook_sessions, get_sesh)

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
        add_to_session(server_session, notebook_sessions, path)

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
            remove_from_session(server_session, notebook_sessions, notebook_hash)
            msg = "Successfully shut down " * sesh.hash
        else
            msg = "Nothing to do!"
        end
        @info msg
        return HTTP.Response(200, msg)
    end

    function reload_filesystem(request::HTTP.Request)
        if get(ENV, "GITHUB_SECRET", "") !== ""
            i = findfirst(a -> a.first == "X-Hub-Signature-256", request.headers)
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
            paths = ["$start_dir/$path" for path in find_notebook_files_recursive(start_dir) if !isnothing(path)]
            new_hashes = map(path_hash, paths)

            running_hashes = map(notebook_sessions) do sesh
                sesh isa RunningNotebookSession ? sesh.hash : nothing
            end

            to_delete = [h for h in running_hashes if !(h ∈ new_hashes) && !isnothing(h)]
            to_start = [h for h in new_hashes if !(h ∈ running_hashes) && !isnothing(h)]
            @info "delete" to_delete
            @info "start" to_start
            for hash in to_delete
                remove_from_session(server_session, notebook_sessions, hash)
            end

            for hash in to_start
                runpath = paths[findfirst(h -> hash === h, new_hashes)]
                add_to_session(server_session, notebook_sessions, runpath)
                @info "started" runpath
            end
            HTTP.Response(200, "Reload complete")
        catch e
           @warn "Fail in reloading " e
        HTTP.Response(503, "Failed to reload")
        finally
        end

        return HTTP.Response(200, "Webhook accepted, async job started!")

    end

    HTTP.@register(router, "GET", "/notebooks/", get_notebooks)
    HTTP.@register(router, "GET", "/notebook/*/", get_notebook)
    HTTP.@register(router, "POST", "/notebook/*/", start_notebook)
    HTTP.@register(router, "DELETE", "/notebook/*/", stop_notebook)
    HTTP.@register(router, "POST", "/github_webhook/", reload_filesystem)

end
end