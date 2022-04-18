import PlutoSliderServer: PlutoSliderServer, Pluto, list_files_recursive
import HTTP
import Deno_jll
using OrderedCollections

import Random
using Test
using UUIDs
using Base64

@testset "HTTP requests" begin
    test_dir = tempname(cleanup=false)
    cp(@__DIR__, test_dir)

    notebook_paths = ["basic3.jl"]
    # notebook_paths = ["basic2.jl", "parallelpaths4.jl"]

    port = rand(Random.RandomDevice(), 12345:65000)


    still_booting = Ref(true)
    ready_result = Ref{Any}(nothing)
    function on_ready(result)
        ready_result[] = result
        still_booting[] = false
    end


    t = Pluto.@asynclog begin
        try
            run(
                `$(Deno_jll.deno()) run --allow-net --allow-read https://deno.land/std@0.115.0/http/file_server.ts $(test_dir) --cors --port $(port)`,
            )
        catch e
            if !(e isa TaskFailedException) && !(e isa InterruptException)
                showerror(stderr, e, stacktrace(catch_backtrace()))
            end
        end
    end

    withenv("JULIA_DEBUG" => nothing) do
        PlutoSliderServer.export_directory(
            test_dir;
            Precompute_enabled=true,
            notebook_paths,
            on_ready,
        )
    end

    @test isdir(joinpath(test_dir, "staterequest"))
    @test isdir(joinpath(test_dir, "bondconnections"))
    @show list_files_recursive(joinpath(test_dir, "staterequest"))
    @show readdir(joinpath(test_dir, "bondconnections"))
    @test length(list_files_recursive(joinpath(test_dir, "staterequest"))) == let
        x = 10
        y = 20
        z = 15
        x * y + z
    end

    while !occursin(
        "Pluto.jl notebook",
        read(download("http://localhost:$(port)/basic3.jl"), String),
    )
        @info "Waiting for file server to start"
        sleep(0.1)
    end

    while still_booting[]
        sleep(0.1)
    end


    notebook_sessions = ready_result[].notebook_sessions

    @show notebook_paths [
        (s.path, typeof(s.run), s.current_hash) for s in notebook_sessions
    ]

    @testset "Bond connections - $(name)" for (i, name) in enumerate(notebook_paths)
        s = notebook_sessions[i]

        for ending in [""]
            response = HTTP.get(
                "http://localhost:$(port)/bondconnections/$(HTTP.URIs.escapeuri(s.current_hash))" *
                ending,
            )

            result = Pluto.unpack(response.body)

            @test result ==
                  Dict(String(k) => String.(v) for (k, v) in s.run.bond_connections)
        end
    end


    @testset "State request - basic3.jl" begin
        i = 1
        s = notebook_sessions[i]

        @testset "Method $(method)" for method in ["GET"], x = 3:7

            v(x) = OrderedDict("value" => x)

            bonds = OrderedDict("x" => v(x), "y" => v(7))

            state = Pluto.unpack(Pluto.pack(s.run.original_state))

            sum_cell_id = "26025270-9b5e-4841-b295-0c47437bc7db"

            response = if method == "GET"
                arg = Pluto.pack(bonds) |> PlutoSliderServer.base64urlencode

                HTTP.request(
                    method,
                    "http://localhost:$(port)/staterequest/$(s.current_hash)/$(arg)",
                )
            else
                HTTP.request(
                    method,
                    "http://localhost:$(port)/staterequest/$(s.current_hash)/",
                    [],
                    Pluto.pack(bonds),
                )
            end

            result = Pluto.unpack(response.body)

            @test sum_cell_id ∈ result["ids_of_cells_that_ran"]

            for patch in result["patches"]
                Pluto.Firebasey.applypatch!(
                    state,
                    convert(Pluto.Firebasey.JSONPatch, patch),
                )
            end

            @test state["cell_results"][sum_cell_id]["output"]["body"] ==
                  let
                x = bonds["x"]["value"]
                y = bonds["y"]["value"]
                repeat(string(x), y)
            end |> repr

        end
    end

    # close(ready_result[].serversocket)

    try
        schedule(t, InterruptException(); error=true)
        wait(t)
    catch e
        if !(e isa TaskFailedException) && !(e isa InterruptException)
            rethrow(e)
        end
    end
    # schedule(t, InterruptException(), error=true)
    @info "DONEZO"

    @test true
end