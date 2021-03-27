module WebAPI
using HTTP


get_notebooks = quote 

    function get_notebooks(request::HTTP.Request)
        @info "get notebook runs"
        @show server_session
        HTTP.Response(200, "Notebooks that run are:")
    end
end

function get_notebook(server_session, notebook_session)
    function get_notebook(request::HTTP.Request)
        @info "get notebook runs"
        HTTP.Response(200, "Notebook with hash $('h') status is: 234234")
    end
end

function start_notebook(request::HTTP.Request)
    @info "get notebook runs"
    HTTP.Response(200, "Starting notebook")
end

function stop_notebook(request::HTTP.Request)
    @info "stopping notebook"
    HTTP.Response(200, "Starting notebook")
end

function reload_filesystem(request::HTTP.Request)
    @info "looking for changes"
end


end