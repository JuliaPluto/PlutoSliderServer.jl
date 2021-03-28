module WebAPI
using HTTP
import Pluto
import PlutoSliderServer: FinishedNotebookSession, RunningNotebookSession, QueuedNotebookSession, myhash, MoreAnalysis

# curl -X DELETE http://127.0.0.1:2345/notebook/uut+KtbdWht451eFX7gBhnqfHRSarm0KK6NyontJkQE=/
# curl -X GET http://127.0.0.1:2345/notebook/uut+KtbdWht451eFX7gBhnqfHRSarm0KK6NyontJkQE=/
# curl -X POST --data-binary "@./notebook2.jl.assets/notebook2.jl" http://127.0.0.1:2345/notebook/start/


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
        notebook = Pluto.SessionActions.open(server_session, path; run_async=false)
        original_state = Pluto.notebook_to_js(notebook)
        bond_connections = MoreAnalysis.bound_variable_connections_graph(notebook)

        session = RunningNotebookSession(;
            path=path,
            hash=hash,
            notebook=notebook, 
            original_state=original_state, 
            bond_connections=bond_connections,
        )
        push!(notebook_sessions, session)

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
            Pluto.SessionActions.shutdown(server_session, sesh.notebook)
            i = findfirst(notebook_sessions) do sesh
                sesh.hash == notebook_hash
            end
            notebook_sessions[i] = FinishedNotebookSession(;
                sesh.path,
                sesh.hash,
                sesh.original_state,
            )
            msg = "Successfully shut down " * sesh.hash
        else
            msg = "Nothing to do!"
        end
        @info msg
        return HTTP.Response(200, msg)
    end

    function reload_filesystem(request::HTTP.Request)
        @info "looking for changes"
    end

    HTTP.@register(router, "GET", "/notebooks/", get_notebooks)
    HTTP.@register(router, "GET", "/notebook/*/", get_notebook)
    HTTP.@register(router, "POST", "/notebook/*/", start_notebook)
    HTTP.@register(router, "DELETE", "/notebook/*/", stop_notebook)
    HTTP.@register(router, "POST", "/reload_filesystem/", reload_filesystem)

end
end