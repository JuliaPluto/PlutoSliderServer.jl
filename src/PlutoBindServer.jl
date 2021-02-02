module PlutoBindServer

import Pluto
import Pluto: ServerSession, Firebasey, Token, withtoken
using HTTP
using Base64
using SHA
using Sockets

myhash = base64encode ∘ sha256



Base.@kwdef struct SwankyNotebookSession
    hash::String
    notebook::Pluto.Notebook
    original_state
    token::Token=Token()
end


function with_cors!(response::HTTP.Response)
    push!(response.headers, "Access-Control-Allow-Origin" => "*")
    response
end


# create router

function make_router(session::ServerSession, swanky_sessions::AbstractVector{SwankyNotebookSession})
    router = HTTP.Router()

    function serve_staterequest(request::HTTP.Request)        
        uri = HTTP.URI(request.target)
    
        parts = HTTP.URIs.splitpath(uri.path)
        # parts[1] == "staterequest"
        notebook_hash = parts[2] |> HTTP.unescapeuri

        i = findfirst(swanky_sessions) do sesh
            sesh.hash == notebook_hash
        end
        
        response = if i === nothing
            @info "Request hash not found" request.target
            HTTP.Response(404, "Not found!")
        else
            sesh = swanky_sessions[i]
            notebook = sesh.notebook
            bonds_raw = let
                request_body = IOBuffer(HTTP.payload(request))
                Pluto.unpack(request_body)
            end
            bonds = Dict(Symbol(k) => v for (k, v) in bonds_raw)

            # @show bonds

            withtoken(sesh.token) do
                notebook.bonds = bonds

                # TODO: is_first_value should be determined by the client
                Pluto.set_bond_values_reactive(
                    session=session,
                    notebook=notebook,
                    bound_sym_names=Symbol.(keys(bonds)),
                    is_first_value=false,
                    run_async=false,
                )

                # sleep(.5)
            end

            @info "Finished running!"

            new_state = Pluto.notebook_to_js(notebook)

            patches = Firebasey.diff(sesh.original_state, new_state)
            patches_as_dicts::Array{Dict} = patches

            HTTP.Response(200, Pluto.pack(patches_as_dicts))
        end
        with_cors!(response)
    end
    
    HTTP.@register(router, "GET", "/", r -> with_cors!(HTTP.Response(200, "Hi!")))
    
    HTTP.@register(router, "POST", "/staterequest/*/", serve_staterequest)

    router
end

function empty_router()
    router = HTTP.Router()
    HTTP.@register(router, "GET", "/", r -> with_cors!(HTTP.Response(200, "Hi!")))
    router
end



function run_paths(notebook_paths::Vector{String}; copy_to_temp_before_running=false, create_statefiles=false, kwargs...)
    @warn "Make sure that you run this bind server inside a containerized environment -- it is not intended to be secure. Assume that users can execute arbitrary code inside your notebooks."

    options = Pluto.Configuration.from_flat_kwargs(; kwargs...)
    session = Pluto.ServerSession(;options=options)

    router_ref = Ref{HTTP.Router}(empty_router())

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

    # We start the HTTP server before launching notebooks so that the server responds to heroku/digitalocean garbage fast enough
    http_server_task = @async HTTP.serve(hostIP, UInt16(port), stream=true, server=serversocket) do http::HTTP.Stream
        request::HTTP.Request = http.message
        request.body = read(http)
        HTTP.closeread(http)

        params = HTTP.queryparams(HTTP.URI(request.target))

        response_body = HTTP.handle(router_ref[], request)

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

    swanky_sessions = map(notebook_paths) do path
        @info "Opening $(path)"
        hash = myhash(read(path))
        if copy_to_temp_before_running
            newpath = tempname()
            write(newpath, read(path))
        else
            newpath = path
        end
        nb = Pluto.SessionActions.open(session, newpath; run_async=false)
        if create_statefiles
            # becomes .jlstate
            write(newpath * "state", Pluto.pack(Pluto.notebook_to_js(nb)))
        end

        @info "Ready $(path)" hash

        SwankyNotebookSession(hash=hash, notebook=nb, original_state=Pluto.notebook_to_js(nb))
    end
    
    router_ref[] = make_router(session, swanky_sessions)

    wait(http_server_task)
end

function run_directory(start_dir::String="."; kwargs...)
    notebookfiles = let
        jlfiles = vcat(map(walkdir(start_dir)) do (root, dirs, files)
            map(
                filter(files) do file
                    occursin(".jl", file)
                end
                ) do file
                joinpath(root, file)
            end
        end...)
        filter(jlfiles) do f
            !occursin(".julia", f) &&
            readline(f) == "### A Pluto.jl notebook ###"
        end
    end
    
    @show notebookfiles

    PlutoBindServer.run_paths(notebookfiles; kwargs...)
end

end
