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
import PlutoDependencyExplorer



@from "./run_bonds.jl" import run_bonds_get_patches
@from "./IndexJSON.jl" import generate_index_json
@from "./IndexHTML.jl" import generate_temp_index_html
@from "./Types.jl" import NotebookSession, RunningNotebook, FinishedNotebook
@from "./Configuration.jl" import PlutoDeploySettings, get_configuration
@from "./PlutoHash.jl" import base64urldecode
@from "./PathUtils.jl" import to_local_path

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

    with_cacheable_configured! = with_cacheable!(settings.SliderServer.cache_control)

    function get_sesh(request::HTTP.Request)::Union{Nothing,NotebookSession}
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
            @info "Request hash not found. See error hint in my source code." notebook_hash maxlog =
                50
            nothing
        else
            notebook_sessions[i]
        end
    end

    function get_bonds(request::HTTP.Request)
        uri = HTTP.URI(request.target)
        parts = HTTP.URIs.splitpath(uri.path)
        # parts[1] == "staterequest"
        # parts[2] == notebook_hash
        
        explicits = let
            q = HTTP.queryparams(uri)
            e = get(q, "explicit", nothing)
            e === nothing ? nothing : Set(Iterators.map(Symbol, Pluto.unpack(base64urldecode(e))))
        end

        bonds_raw = if request.method == "POST"
            Pluto.unpack(IOBuffer(HTTP.payload(request)))
        elseif request.method == "GET"
            @assert length(parts) == 3
            Pluto.unpack(base64urldecode(parts[3]))
        end

        (
            Dict{Symbol,Any}(Symbol(k) => v for (k, v) in bonds_raw),
            explicits,
        )
    end

    "Happens whenever you move a slider"
    function serve_staterequest(request::HTTP.Request)
        t1 = time()

        sesh = get_sesh(request)

        response = if ready_for_bonds(sesh)
            notebook = sesh.run.notebook

            bonds, explicits = try
                get_bonds(request)
            catch e
                @error "Failed to deserialize bond values" exception =
                    (e, catch_backtrace())
                return HTTP.Response(500, "Failed to deserialize bond values") |>
                       with_cors! |>
                       with_not_cacheable!
            end
            

            t2 = time()
            @debug "Deserialized bond values" bonds explicits

            let lag = settings.SliderServer.simulated_lag
                lag > 0 && sleep(lag)
            end
            t3 = time()

            (; patches, t35, t4 ) = run_bonds_get_patches(
                server_session,
                sesh.run,
                bonds,
                explicits,
            )

            patches_as_dicts::Array{Dict} = Firebasey._convert(Array{Dict}, patches)

            t5 = time()

            response_data = Pluto.pack(
                Dict{String,Any}(
                    "patches" => patches_as_dicts,
                ),
            )
            @debug "Sending patches" Pluto.unpack(response_data)

            t6 = time()

            HTTP.Response(200, response_data) |>
            (
                settings.SliderServer.server_timing_header ?
                with_server_timing!(t1, t2, t3, t35, t4, t5, t6) : identity
            ) |>
            with_cacheable_configured! |>
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
            with_cacheable_configured! |>
            with_msgpack!
        elseif queued_for_bonds(sesh)
            HTTP.Response(503, "Still loading the notebooks... check back later!") |>
            with_cors! |>
            with_not_cacheable!
        elseif sesh isa NotebookSession{<:Any,String,FinishedNotebook}
            HTTP.Response(422, "Notebook is no longer running") |>
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
                    write(path, generate_temp_index_html(notebook_sessions; settings, start_dir))
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
                to_local_path(relpath(HTTP.unescapeuri(uri.path), "/pluto_asset/")),
            )
            Pluto.asset_response(filepath)
        end
        HTTP.register!(router, "GET", "/pluto_asset/**", serve_pluto_asset)
        function serve_asset(request::HTTP.Request)
            uri = HTTP.URI(request.target)

            filepath = joinpath(static_dir, to_local_path(relpath(HTTP.unescapeuri(uri.path), "/")))
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

function with_cacheable!(cache_control::String)
    return (response::HTTP.Response) -> begin
        HTTP.setheader(response, "Cache-Control" => cache_control)
        response
    end
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

function with_server_timing!(t1, t2, t3, t35, t4, t5, t6)
    s(name, start, stop) = "$name;dur=$(round((stop - start) * 1000; digits=2))"

    function (response::HTTP.Response)
        HTTP.setheader(response, "Server-Timing" => "$(
            s("total", t1, t6)),$(
            s("p1deserialize", t1, t2)),$(
            s("p2lag", t2, t3)),$(
            s("p3preanalysis", t3, t35)),$(
            s("p4setBonds", t35, t4)),$(
            s("p5diff", t4, t5)),$(
            s("p6msgpack", t5, t6))")
        response
    end
end
