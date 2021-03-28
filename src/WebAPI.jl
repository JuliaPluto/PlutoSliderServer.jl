module WebAPI
using HTTP
import Pluto

function extend_router(router, server_session, notebook_sessions, get_sesh)

    function get_notebooks(request::HTTP.Request)
        @info "get notebook runs"
        hashes = map(notebook_sessions) do sesh
            sesh.hash
        end
        HTTP.Response(200, "Notebooks that run are: " * join(hashes, ", "))
    end

    function get_notebook(request::HTTP.Request)
        sesh = get_sesh(request)
        notfound = sesh === nothing
        running = sesh isa RunningNotebookSession
        queued = sesh isa QueuedNotebookSession
        finished = sesh isa FinishedNotebookSession
        @info "get notebook runs"
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

        hash = (base64encode ∘ sha256)()
        notebook = Pluto.SessionActions.open(server_session, path; run_async=false)
        original_state = Pluto.notebook_to_js(notebook)
        bond_connections = MoreAnalysis.bound_variable_connections_graph(notebook)

        session = RunningNotebookSession(;
            path,
            hash,
            notebook, 
            original_state, 
            bond_connections,
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

        if running
            Pluto.SessionActions.shutdown(server_session, sesh.notebook)
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