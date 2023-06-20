using FromFile

import Pluto
import Pluto:
    ServerSession,
    Firebasey,
    Token,
    withtoken,
    pluto_file_extensions,
    without_pluto_file_extension
using HTTP
using Sockets
import JSON

@from "./IndexJSON.jl" import generate_index_json
@from "./IndexHTML.jl" import temp_index, generate_basic_index_html
@from "./Types.jl" import NotebookSession, RunningNotebook
@from "./Configuration.jl" import PlutoDeploySettings, get_configuration
@from "./PlutoHash.jl" import base64urldecode

ready_for_bonds(::Any) = false
ready_for_bonds(sesh::NotebookSession{String,String,RunningNotebook}) =
    sesh.current_hash == sesh.desired_hash
queued_for_bonds(::Any) = false
queued_for_bonds(sesh::NotebookSession{<:Any,String,<:Any}) =
    sesh.current_hash != sesh.desired_hash


function make_router(
    notebook_sessions::AbstractVector{<:NotebookSession},
    server_session::ServerSession;
    settings::PlutoDeploySettings,
    start_dir::AbstractString,
    static_dir::Union{String,Nothing}=nothing,
)
    router = HTTP.Router()

    function get_sesh(request::HTTP.Request)
        uri = HTTP.URI(request.target)

        parts = HTTP.URIs.splitpath(uri.path)
        # parts[1] == "staterequest"
        notebook_hash = parts[2]

        i = findfirst(notebook_sessions) do sesh
            sesh.desired_hash == notebook_hash
        end

        if i === nothing
            #= 
            ERROR HINT

            This means that the notebook file used by the web client does not precisely match any of the notebook files running in this server. 

            If this is an automated setup, then this could happen inbetween deployments. 

            If this is a manual setup, then running the .jl notebook file might have caused a small change (e.g. the version number or a whitespace change). Copy notebooks to a temporary directory before running them using the bind server. =#
            @info "Request hash not found. See error hint in my source code." notebook_hash maxlog=50
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
            # notebook_hash = parts[2]

            @assert length(parts) == 3

            base64urldecode(parts[3])
        end
        bonds_raw = Pluto.unpack(request_body)

        Dict{Symbol,Any}(Symbol(k) => v for (k, v) in bonds_raw)
    end

    "Happens whenever you move a slider"
    function serve_staterequest(request::HTTP.Request)
        sesh = get_sesh(request)

        response = if ready_for_bonds(sesh)
            notebook = sesh.run.notebook

            bonds = try
                get_bonds(request)
            catch e
                @error "Failed to deserialize bond values" exception =
                    (e, catch_backtrace())
                return HTTP.Response(500, "Failed to deserialize bond values") |>
                       with_cors! |>
                       with_not_cacheable!
            end

            @debug "Deserialized bond values" bonds

            let lag = settings.SliderServer.simulated_lag
                lag > 0 && sleep(lag)
            end

            topological_order, new_state = withtoken(sesh.run.token) do
                try
                    notebook.bonds = bonds

                    names::Vector{Symbol} = Symbol.(keys(bonds))

                    topological_order = Pluto.set_bond_values_reactive(
                        session=server_session,
                        notebook=notebook,
                        bound_sym_names=names,
                        is_first_values=[false for _n in names], # because requests should be stateless. We might want to do something special for the (actual) initial request (containing every initial bond value) in the future.
                        run_async=false,
                    )::Pluto.TopologicalOrder

                    new_state = Pluto.notebook_to_js(notebook)

                    topological_order, new_state
                catch e
                    @error "Failed to set bond values" exception = (e, catch_backtrace())
                    nothing, nothing
                end
            end
            topological_order === nothing && return (
                HTTP.Response(500, "Failed to set bond values") |>
                with_cors! |>
                with_not_cacheable!
            )

            ids_of_cells_that_ran = [c.cell_id for c in topological_order.runnable]

            @debug "Finished running!" length(ids_of_cells_that_ran)

            # We only want to send state updates about...
            function only_relevant(state)
                new = copy(state)
                # ... the cells that just ran and ...
                new["cell_results"] = filter(state["cell_results"]) do (id, cell_state)
                    id ∈ ids_of_cells_that_ran
                end
                # ... nothing about bond values, because we don't want to synchronize among clients. and...
                delete!(new, "bonds")
                # ... we ignore changes to the status tree caused by a running bonds.
                delete!(new, "status_tree")
                new
            end

            patches = Firebasey.diff(
                only_relevant(sesh.run.original_state),
                only_relevant(new_state),
            )
            patches_as_dicts::Array{Dict} = Firebasey._convert(Array{Dict}, patches)

            HTTP.Response(
                200,
                Pluto.pack(
                    Dict{String,Any}(
                        "patches" => patches_as_dicts,
                        "ids_of_cells_that_ran" => ids_of_cells_that_ran,
                    ),
                ),
            ) |>
            with_cacheable! |>
            with_cors! |>
            with_msgpack!
        elseif queued_for_bonds(sesh)
            HTTP.Response(503, "Still loading the notebooks... check back later!") |>
            with_cors! |>
            with_not_cacheable!
        else
            HTTP.Response(404, "Not found!") |> with_cors! |> with_not_cacheable!
        end
    end

    function serve_bondconnections(request::HTTP.Request)
        sesh = get_sesh(request)

        response = if ready_for_bonds(sesh)
            HTTP.Response(200, Pluto.pack(sesh.run.bond_connections)) |>
            with_cors! |>
            with_cacheable! |>
            with_msgpack!
        elseif queued_for_bonds(sesh)
            HTTP.Response(503, "Still loading the notebooks... check back later!") |>
            with_cors! |>
            with_not_cacheable!
        else
            HTTP.Response(404, "Not found!") |> with_cors! |> with_not_cacheable!
        end
    end

    HTTP.register!(
        router,
        "GET",
        "/",
        r -> let
            done = count(sesh -> sesh.current_hash == sesh.desired_hash, notebook_sessions)
            if static_dir !== nothing
                path = joinpath(static_dir, "index.html")
                if !isfile(path)
                    path = tempname() * ".html"
                    write(path, temp_index(notebook_sessions))
                end
                Pluto.asset_response(path)
            else
                if done < length(notebook_sessions)
                    HTTP.Response(
                        503,
                        "Still loading the notebooks... check back later! [$(done)/$(length(notebook_sessions)) ready]",
                    )
                else
                    HTTP.Response(200, "Hi!")
                end
            end |>
            with_cors! |>
            with_not_cacheable!
        end,
    )


    HTTP.register!(
        router,
        "GET",
        "/pluto_export.json",
        r -> let
            HTTP.Response(200, generate_index_json(notebook_sessions; settings, start_dir)) |>
            with_json! |>
            with_cors! |>
            with_not_cacheable!
        end,
    )

    # !!!! IDEAAAA also have a get endpoint with the same thing but the bond data is base64 encoded in the URL
    # only use it when the amount of data is not too much :o

    HTTP.register!(router, "POST", "/staterequest/*/", serve_staterequest)
    HTTP.register!(router, "GET", "/staterequest/*/*", serve_staterequest)
    HTTP.register!(router, "GET", "/bondconnections/*/", serve_bondconnections)

    if static_dir !== nothing
        function serve_pluto_asset(request::HTTP.Request)
            uri = HTTP.URI(request.target)

            filepath = Pluto.project_relative_path(
                "frontend",
                relpath(HTTP.unescapeuri(uri.path), "/pluto_asset/"),
            )
            Pluto.asset_response(filepath)
        end
        HTTP.register!(router, "GET", "/pluto_asset/**", serve_pluto_asset)
        function serve_asset(request::HTTP.Request)
            uri = HTTP.URI(request.target)

            filepath = joinpath(static_dir, relpath(HTTP.unescapeuri(uri.path), "/"))
            Pluto.asset_response(filepath)
        end
        HTTP.register!(router, "GET", "/**", serve_asset)
    end

    router
end


###
# HEADERS

function with_msgpack!(response::HTTP.Response)
    HTTP.setheader(response, "Content-Type" => "application/msgpack")
    response
end

function with_json!(response::HTTP.Response)
    HTTP.setheader(response, "Content-Type" => "application/json; charset=utf-8")
    response
end

function with_cors!(response::HTTP.Response)
    HTTP.setheader(response, "Access-Control-Allow-Origin" => "*")
    response
end

function with_cacheable!(response::HTTP.Response)
    second = 1
    minute = 60second
    hour = 60minute
    day = 24hour
    year = 365day

    HTTP.setheader(response, "Cache-Control" => "public, max-age=$(10year), immutable")
    response
end

function with_not_cacheable!(response::HTTP.Response)
    HTTP.setheader(response, "Cache-Control" => "no-store, no-cache")
    response
end

function ReferrerMiddleware(handler)
    return function (req::HTTP.Request)
        response = handler(req)
        HTTP.setheader(response, "Referrer-Policy" => "origin-when-cross-origin")
        return response
    end
end
