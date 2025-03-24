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



@from "./IndexJSON.jl" import generate_index_json
@from "./IndexHTML.jl" import temp_index, generate_basic_index_html
@from "./Types.jl" import NotebookSession, RunningNotebook, FinishedNotebook
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

    with_cacheable_configured! = with_cacheable!(settings.SliderServer.cache_control)

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
            @info "Request hash not found. See error hint in my source code." notebook_hash maxlog =
                50
            nothing
        else
            notebook_sessions[i]
        end
    end

    function get_bonds(request::HTTP.Request)
        bonds_raw, explicits_raw = if request.method == "POST"
            # TODO: implement POST version
            data = Pluto.unpack(IOBuffer(HTTP.payload(request)))
            data isa Dict ? (data, nothing) : data
        elseif request.method == "GET"
            uri = HTTP.URI(request.target)

            parts = HTTP.URIs.splitpath(uri.path)
            # parts[1] == "staterequest"
            # notebook_hash = parts[2]

            @assert length(parts) == 3
            data = Pluto.unpack(base64urldecode(parts[3]))

            explicit = let
                q = HTTP.queryparams(uri)
                e = get(q, "explicit", nothing)
                e === nothing ? nothing : Pluto.unpack(base64urldecode(e))
            end

            (data, explicit)
        end

        (
            Dict{Symbol,Any}(Symbol(k) => v for (k, v) in bonds_raw),
            explicits_raw === nothing ? nothing : Set(Symbol.(explicits_raw)),
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

            names::Vector{Symbol} = Symbol.(keys(bonds))
            
            explicits = something(explicits, names)
            
            
            names_original = names
            names =
                begin
                    # REMOVE ALL NAMES that depend on 
                    # an explicit bond
                    # 
                    # Because its new value might no longer be valid.
                    # 
                    # For exaxmple:
                    # @bind xx Slider(1:100)
                    # @bind yy Slider(xx:100)
                    # 
                    # (ignore bond transformatinos for now)
                    # 
                    # The sliders will be set on (1,1) initially.
                    # The user moves the first slider, giving (10,1).
                    # The value for `y` will be sent, but this should be ignored. Because it was generated from an outdated bond.
                    
                    
                    # the cells where you set a bond explicitly
                    starts = PlutoDependencyExplorer.where_assigned(
                        notebook.topology,
                        explicits,
                    )

                    # all cells that depend on an explicit bond
                    cells_depending_on_explicits = Pluto.MoreAnalysis.downstream_recursive(
                        notebook.topology,
                        starts,
                    )

                    # remove any variable `n` from `names` if...
                    filter(names) do n
                        !(
                            # ...`n` depends on an explicit bond.
                            any(cells_depending_on_explicits) do c
                                n in notebook.topology.nodes[c].definitions
                            end
                        )
                    end
                end

            @debug "Analysis" names names_original starts cells_depending_on_explicits
            
            new_state = withtoken(sesh.run.token) do
                try
                    # Set the bond values. We don't need to merge dicts here because the old bond values will never be used.
                    notebook.bonds = bonds
                    
                    # Run the bonds!
                    topological_order = Pluto.set_bond_values_reactive(
                        session=server_session,
                        notebook=notebook,
                        bound_sym_names=names,
                        is_first_values=[false for _n in names], # because requests should be stateless. We might want to do something special for the (actual) initial request (containing every initial bond value) in the future.
                        run_async=false,
                    )::Pluto.TopologicalOrder

                    @debug "Finished running!" length(topological_order.runnable)
                    
                    Pluto.notebook_to_js(notebook)
                catch e
                    @error "Failed to set bond values" exception = (e, catch_backtrace())
                    nothing
                end
            end
            new_state === nothing && return (
                HTTP.Response(500, "Failed to set bond values") |>
                with_cors! |>
                with_not_cacheable!
            )
            
            t4 = time()

            # We only want to send state updates about...
            function only_relevant(state)
                new = copy(state)
                # ... the cells that just ran and ...
                new["cell_results"] = filter(state["cell_results"]) do (id, cell_state)
                    id ∈ (c.cell_id for c in cells_depending_on_explicits)
                end
                # ... nothing about bond values, because we don't want to synchronize among clients. and...
                delete!(new, "bonds")
                # ... we ignore changes to the status tree caused by a running bonds.
                delete!(new, "status_tree")
                new
            end

            patches = let
                notebook_patches = Firebasey.diff(
                    only_relevant(sesh.run.original_state),
                    only_relevant(new_state),
                )

                # if bond values were removed by Pluto, then that should also happen on the PSS client
                bond_patches = [
                    Firebasey.RemovePatch(["bonds", string(k)]) for
                    k in keys(bonds) if string(k) ∉ keys(new_state["bonds"])
                ]

                @debug "patches" notebook_patches bond_patches

                union!(notebook_patches, bond_patches)
            end

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
                with_server_timing!(t1, t2, t3, t4, t5, t6) : identity
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

function with_server_timing!(t1, t2, t3, t4, t5, t6)
    s(name, start, stop) = "$name;dur=$(round((stop - start) * 1000; digits=2))"

    function (response::HTTP.Response)
        HTTP.setheader(response, "Server-Timing" => "$(
            s("total", t1, t6)),$(
            s("p1deserialize", t1, t2)),$(
            s("p2lag", t2, t3)),$(
            s("p3setBonds", t3, t4)),$(
            s("p4diff", t4, t5)),$(
            s("p5msgpack", t5, t6))")
        response
    end
end
