module PlutoSliderServer

include("./MoreAnalysis.jl")
import .MoreAnalysis



import Pluto
import Pluto: ServerSession, Firebasey, Token, withtoken
using HTTP
using Base64
using SHA
using Sockets
using Configurations

myhash = base64encode ∘ sha256

###
# SESSION DEFINITION

abstract type NotebookSession end

Base.@kwdef struct RunningNotebookSession <: NotebookSession
    hash::String
    notebook::Pluto.Notebook
    original_state
    token::Token=Token()
    bond_connections::Dict{Symbol,Vector{Symbol}}
end

Base.@kwdef struct QueuedNotebookSession <: NotebookSession
    hash::String
end

###
# CONFIGURATION

@option struct SliderServerSettings
    exclude::Vector=String[]
    is_cool::Bool=true
end
@option struct ExportSettings
    baked_state::Bool=true
    offer_binder::Bool=true
    disable_ui::Bool=true
    slider_server_url::Union{Nothing,String}=nothing
    binder_url::Union{Nothing,String}=nothing
    cache_dir::Union{Nothing,String}=nothing
end
@option struct PlutoDeploySettings
    SliderServer::SliderServerSettings=SliderServerSettings()
    Export::ExportSettings=ExportSettings()
end



function find_notebook_files_recursive(start_dir)
    jlfiles = vcat(
        map(walkdir(start_dir)) do (root, dirs, files)
            map(
                filter(endswith_pluto_file_extension, files)
            ) do file
                joinpath(root, file)
            end
        end...
    )
    plutofiles = filter(jlfiles) do f
        readline(f) == "### A Pluto.jl notebook ###" &&
        (!occursin(".julia", f) || occursin(".julia", start_dir))
    end

    # reverse alphabetical order so that week5 becomes available before week4 :)
    reverse(plutofiles)
end

"""
    run_directory(start_dir::String="."; kwargs...)

Run the Pluto bind server for all Pluto notebooks in the given directory (recursive search). 

Additional keyword arguments can be given to the Pluto.run constructor. Note that **security is always disabled**.
"""
function run_directory(start_dir::String="."; kwargs...)
    plutodeployment_toml = joinpath(Base.active_project() |> dirname, "PlutoDeployment.toml")

    settings = if isfile(plutodeployment_toml)
        Configurations.from_toml(PlutoDeploySettings, plutodeployment_toml)
    else
        PlutoDeploySettings()
    end

    @show settings

    notebookfiles = find_notebook_files_recursive(start_dir)

    to_run = filter(notebookfiles) do f
        relpath(f, start_dir) ∉ relpath.(settings.SliderServer.exclude, [start_dir])
    end

    if to_run != notebookfiles
        @info "Excluded notebooks" setdiff(notebookfiles, to_run)
    end
    @info "Pluto notebooks to run:" to_run

    PlutoSliderServer.run_paths(to_run; kwargs...)
end



function run_paths(notebook_paths::Vector{String}; create_statefiles=false, kwargs...)
    @warn "Make sure that you run this bind server inside a containerized environment -- it is not intended to be secure. Assume that users can execute arbitrary code inside your notebooks."

    options = Pluto.Configuration.from_flat_kwargs(; kwargs...)
    server_session = Pluto.ServerSession(;options=options)

    notebook_sessions = NotebookSession[QueuedNotebookSession(hash=myhash(read(path))) for path in notebook_paths]
    router = make_router(server_session, notebook_sessions)

    # This is boilerplate HTTP code, don't read it
    host = server_session.options.server.host
    port = server_session.options.server.port

    # This is boilerplate HTTP code, don't read it
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


    # This is boilerplate HTTP code, don't read it
    # We start the HTTP server before launching notebooks so that the server responds to heroku/digitalocean garbage fast enough
    http_server_task = @async HTTP.serve(hostIP, UInt16(port), stream=true, server=serversocket) do http::HTTP.Stream
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

    # RUN ALL NOTEBOOKS AND KEEP THEM RUNNING
    for (i, path) in enumerate(notebook_paths)
        @info "[$(i)/$(length(notebook_paths))] Opening $(path)"
        hash = myhash(read(path))
        # run the notebook synchronously
        nb = Pluto.SessionActions.open(server_session, path; run_async=false)
        state = Pluto.notebook_to_js(nb)

        if create_statefiles
            # becomes .jlstate
            write(path * "state", Pluto.pack(state))
        end

        connections = MoreAnalysis.bound_variable_connections_graph(nb)

        @info "[$(i)/$(length(notebook_paths))] Ready $(path)" hash Text(join(collect(connections), "\n"))

        # By setting the sesions to a running session, (modifying the notebook_sessions array),
        # the HTTP router will now start serving requests for this notebook.
        notebook_sessions[i] = RunningNotebookSession(
            hash=hash, 
            notebook=nb, 
            original_state=state, 
            bond_connections=connections
        )
    end
    @info "-- ALL NOTEBOOKS READY --"

    wait(http_server_task)
end

###
# HTTP ROUTER

function make_router(server_session::ServerSession, notebook_sessions::AbstractVector{<:NotebookSession})
    router = HTTP.Router()

    function get_sesh(request::HTTP.Request)
        uri = HTTP.URI(request.target)
    
        parts = HTTP.URIs.splitpath(uri.path)
        # parts[1] == "staterequest"
        notebook_hash = parts[2] |> HTTP.unescapeuri

        i = findfirst(notebook_sessions) do sesh
            sesh.hash == notebook_hash
        end
        
        if i === nothing
            #= 
            ERROR HINT

            This means that the notebook file used by the web client does not precisely match any of the notebook files running in this server. 

            If this is an automated setup, then this could happen inbetween deployments. 
            
            If this is a manual setup, then running the .jl notebook file might have caused a small change (e.g. the version number or a whitespace change). Copy notebooks to a temporary directory before running them using the bind server. =#
            @info "Request hash not found. See errror hint in my source code." notebook_hash
            nothing
        else
            notebook_sessions[i]
        end
    end

    function get_bonds(request::HTTP.Request)
        request_body = if request.method == "POST"
            IOBuffer(HTTP.payload(request))
        elseif request.method == "GET"
            uri = HTTP.URI(request.target)
    
            parts = HTTP.URIs.splitpath(uri.path)
            # parts[1] == "staterequest"
            # notebook_hash = parts[2] |> HTTP.unescapeuri

            @assert length(parts) == 3

            base64decode(parts[3] |> HTTP.unescapeuri)
        end
        bonds_raw = Pluto.unpack(request_body)

        Dict{Symbol,Any}(Symbol(k) => v for (k, v) in bonds_raw)
    end

    "Happens whenever you move a slider"
    function serve_staterequest(request::HTTP.Request)
        sesh = get_sesh(request)        
        
        response = if sesh isa RunningNotebookSession
            notebook = sesh.notebook
            
            bonds = try
                get_bonds(request)
            catch e
                @error "Failed to deserialize bond values" exception=(e, catch_backtrace())
                return HTTP.Response(500, "Failed to deserialize bond values") |> with_cors! |> with_not_cachable!
            end

            @debug "Deserialized bond values" bonds

            let lag = server_session.options.server.simulated_lag
                lag > 0 && sleep(lag)
            end

            topological_order, new_state = withtoken(sesh.token) do
                try
                    notebook.bonds = bonds

                    names::Vector{Symbol} = Symbol.(keys(bonds))

                    # TODO: is_first_value should be determined by the client
                    topological_order = Pluto.set_bond_values_reactive(
                        session=server_session,
                        notebook=notebook,
                        bound_sym_names=names,
                        is_first_value=false,
                        run_async=false,
                    )::Pluto.TopologicalOrder

                    new_state = Pluto.notebook_to_js(notebook)

                    topological_order, new_state
                catch e
                    @error "Failed to set bond values" exception=(e, catch_backtrace())
                    nothing, nothing
                end
            end
            topological_order === nothing && return (HTTP.Response(500, "Failed to set bond values") |> with_cors! |> with_not_cachable!)

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

            patches = Firebasey.diff(only_relevant(sesh.original_state), only_relevant(new_state))
            patches_as_dicts::Array{Dict} = patches

            HTTP.Response(200, Pluto.pack(Dict{String,Any}(
                "patches" => patches_as_dicts,
                "ids_of_cells_that_ran" => ids_of_cells_that_ran,
            ))) |> with_cachable! |> with_cors! |> with_msgpack!
        elseif sesh isa QueuedNotebookSession
            HTTP.Response(503, "Still loading the notebooks... check back later!") |> with_cors! |> with_not_cachable!
        else
            HTTP.Response(404, "Not found!") |> with_cors! |> with_not_cachable!
        end
    end

    function serve_bondconnections(request::HTTP.Request)        
        sesh = get_sesh(request)        
        
        response = if sesh isa RunningNotebookSession
            HTTP.Response(200, Pluto.pack(sesh.bond_connections)) |> with_cors! |> with_cachable! |> with_msgpack!
        elseif sesh isa QueuedNotebookSession
            HTTP.Response(503, "Still loading the notebooks... check back later!") |> with_cors! |> with_not_cachable!
        else
            HTTP.Response(404, "Not found!") |> with_cors! |> with_not_cachable!
        end
    end
    
    HTTP.@register(router, "GET", "/", r -> (if all(x -> x isa RunningNotebookSession, notebook_sessions)
        HTTP.Response(200, "Hi!")
    else
        HTTP.Response(503, "Still loading the notebooks... check back later!")
    end |> with_cors! |> with_not_cachable!))
    
    # !!!! IDEAAAA also have a get endpoint with the same thing but the bond data is base64 encoded in the URL
    # only use it when the amount of data is not too much :o

    HTTP.@register(router, "POST", "/staterequest/*/", serve_staterequest)
    HTTP.@register(router, "GET", "/staterequest/*/*", serve_staterequest)
    HTTP.@register(router, "GET", "/bondconnections/*/", serve_bondconnections)

    router
end


###
# HEADERS

function with_msgpack!(response::HTTP.Response)
    push!(response.headers, "Content-Type" => "application/msgpack")
    response
end

function with_cors!(response::HTTP.Response)
    push!(response.headers, "Access-Control-Allow-Origin" => "*")
    response
end

function with_cachable!(response::HTTP.Response)
    second = 1
    minute = 60second
    hour = 60minute
    day = 24hour
    year = 365day

    push!(response.headers, "Cache-Control" => "public, max-age=$(10year), immutable")
    response
end

function with_not_cachable!(response::HTTP.Response)
    push!(response.headers, "Cache-Control" => "no-store, no-cache, max-age=5")
    response
end


end
