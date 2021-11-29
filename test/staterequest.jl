import PlutoSliderServer
import PlutoSliderServer.Pluto
import PlutoSliderServer.HTTP

using Test
using UUIDs
using Base64

@testset "HTTP requests" begin
    test_dir = tempname(cleanup=false)
    cp(@__DIR__, test_dir)

    notebook_paths = ["basic2.jl", "parallelpaths4.jl"]

    port = rand(12345:65000)


    still_booting = Ref(true)
    ready_result = Ref{Any}(nothing)
    function on_ready(result)
        ready_result[] = result
        still_booting[] = false
    end

    t = Pluto.@asynclog begin
        try
            PlutoSliderServer.run_directory(
                test_dir;
                Export_enabled=false,
                SliderServer_port=port,
                notebook_paths,
                on_ready,
            )
        catch e
            if !(e isa TaskFailedException)
                showerror(stderr, e, stacktrace(catch_backtrace()))
            end
        end
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

        for ending in ["", "/"]
            response = HTTP.get(
                "http://localhost:$(port)/bondconnections/$(HTTP.URIs.escapeuri(s.current_hash))" *
                ending,
            )

            result = Pluto.unpack(response.body)

            @test result ==
                  Dict(String(k) => String.(v) for (k, v) in s.run.bond_connections)
        end
    end


    @testset "State request - basic2.jl" begin
        i = 1
        s = notebook_sessions[i]

        @testset "Method $(method)" for method in ["GET", "POST"], x = 30:33

            v(x) = Dict("value" => x)

            bonds = Dict("x" => v(x), "y" => v(42))

            state = Pluto.unpack(Pluto.pack(s.run.original_state))

            sum_cell_id = "26025270-9b5e-4841-b295-0c47437bc7db"

            response = if method == "GET"
                arg = Pluto.pack(bonds) |> base64encode |> HTTP.URIs.escapeuri

                HTTP.request(
                    method,
                    "http://localhost:$(port)/staterequest/$(HTTP.URIs.escapeuri(s.current_hash))/$(arg)",
                )
            else
                HTTP.request(
                    method,
                    "http://localhost:$(port)/staterequest/$(HTTP.URIs.escapeuri(s.current_hash))/",
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
                  string(bonds["x"]["value"] + bonds["y"]["value"])

        end
    end

    close(ready_result[].serversocket)

    try
        wait(t)
    catch e
        if !(e isa TaskFailedException)
            rethrow(e)
        end
    end
    # schedule(t, InterruptException(), error=true)
    @info "DONEZO"

    @test true
end