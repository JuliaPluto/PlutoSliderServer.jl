module PlutoBindServer

import Pluto
import Pluto: ServerSession
using HTTP
using Base64
using SHA
using Sockets

myhash = base64encode ∘ sha256











# create router

function make_router(hashes_notebooks)
    router = HTTP.Router()

    function serve_staterequest(request::HTTP.Request)
        uri = HTTP.URI(request.target)
    
        parts = HTTP.URIs.splitpath(uri.path)
        # @assert parts[1] == "staterequest"
        notebook_hash = parts[2] |> HTTP.unescapeuri
        
        if haskey(hashes_notebooks, notebook_hash)

            request_body = IOBuffer(HTTP.payload(request))
            
            patch = Pluto.unpack(request_body)

            @show patch



            HTTP.Response(200, Pluto.pack(patch))
        else
            HTTP.Response(404, "Not found!")
        end
    end
    
    HTTP.@register(router, "GET", "/", r -> HTTP.Response(200, "Hi!"))
    
    HTTP.@register(router, "POST", "/staterequest/*/", serve_staterequest)

    router
end



function run_paths(notebook_paths::Vector{String}; kwargs...)
    options = Pluto.Configuration.from_flat_kwargs(; kwargs...)
    session = Pluto.ServerSession(;options=options)

    hashes_notebooks = Dict(map(notebook_paths) do path
        @info "Opening $(path)"
        hash = myhash(read(path))
        newpath = tempname()
        write(newpath, read(path))
        nb = Pluto.SessionActions.open(session, newpath; run_async=false)

        @info "Ready $(path)" hash

        hash => nb
    end...)

    
    router = make_router(hashes_notebooks)

    host = session.options.server.host
    port = session.options.server.port

    hostIP = parse(Sockets.IPAddr, host)
    if port === nothing
        port, serversocket = Sockets.listenany(hostIP, UInt16(1234))
    else
        try
            serversocket = Sockets.listen(hostIP, UInt16(port))
        catch e
            @error "Port with number $port is already in use. Use Pluto.run() to automatically select an available port."
            return
        end
    end

    @info "Starting server..." host Int(port)

    HTTP.serve(hostIP, UInt16(port), stream=true, server=serversocket) do http::HTTP.Stream
        request::HTTP.Request = http.message
        request.body = read(http)
        HTTP.closeread(http)

        params = HTTP.queryparams(HTTP.URI(request.target))

        response_body = HTTP.handle(router, request)

        request.response::HTTP.Response = response_body
        request.response.request = request
        try
            HTTP.setheader(http, "Referrer-Policy" => "origin-when-cross-origin")
            HTTP.startwrite(http)
            write(http, request.response.body)
            HTTP.closewrite(http)
        catch e
            if isa(e, Base.IOError) || isa(e, ArgumentError)
                # @warn "Attempted to write to a closed stream at $(request.target)"
            else
                rethrow(e)
            end
        end
    end
end






end
