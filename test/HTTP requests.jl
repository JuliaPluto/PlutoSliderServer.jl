import PlutoSliderServer
import PlutoSliderServer.Pluto
import PlutoSliderServer.HTTP

using Test
using UUIDs, Random

@testset "HTTP requests: dynamic" begin
    Random.seed!(time_ns())
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
        PlutoSliderServer.run_directory(
            test_dir;
            Export_enabled=false,
            Export_cache_dir=cache_dir,
            SliderServer_port=port,
            notebook_paths,
            on_ready,
        )
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

        response = HTTP.get("http://localhost:$(port)/bondconnections/$(s.current_hash)/")

        result = Pluto.unpack(response.body)

        @test result == Dict(String(k) => String.(v) for (k, v) in s.run.bond_connections)
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
                arg = Pluto.pack(bonds) |> PlutoSliderServer.base64urlencode

                # escaping should have no effect
                @test HTTP.URIs.escapeuri(arg) == arg

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
                  string(bonds["x"]["value"] + bonds["y"]["value"])

        end
    end

    close(ready_result[].http_server)

    try
        wait(t)
    catch e
        if !(e isa TaskFailedException)
            rethrow(e)
        end
    end
    # schedule(t, InterruptException(), error=true)
    @info "DONEZO"
end


find(f, xs) = xs[findfirst(f, xs)]


original_dir1 = joinpath(@__DIR__, "dir1")
make_test_dir() =
    let
        Random.seed!(time_ns())
        new = tempname(cleanup=false)
        cp(original_dir1, new)
        new
    end

@testset "HTTP requests: static" begin
    test_dir = make_test_dir()
    let
        # add one more file that we will only export, but not run in the slider server
        old = read(joinpath(test_dir, "a.jl"), String)
        new = replace(old, "Hello" => "Hello again")
        @assert old != new

        mkpath(joinpath(test_dir, "x", "y", "z"))
        write(joinpath(test_dir, "x", "y", "z", "export_only.jl"), new)
    end

    port = rand(12345:65000)


    still_booting = Ref(true)
    ready_result = Ref{Any}(nothing)
    function on_ready(result)
        ready_result[] = result
        still_booting[] = false
    end

    t = Pluto.@asynclog begin
        PlutoSliderServer.run_directory(
            test_dir;
            Export_enabled=true,
            Export_baked_notebookfile=false,
            Export_baked_state=false,
            Export_cache_dir=cache_dir,
            SliderServer_port=port,
            SliderServer_exclude=["*/export_only*"],
            on_ready,
        )
    end


    while still_booting[]
        sleep(0.1)
    end


    notebook_sessions = ready_result[].notebook_sessions



    s_a = find(s -> occursin("a.jl", s.path), notebook_sessions)
    s_export_only = find(s -> occursin("export_only", s.path), notebook_sessions)

    response =
        HTTP.request("GET", "http://localhost:$(port)/bondconnections/$(s_a.current_hash)/")
    data = Pluto.unpack(response.body)

    @test data isa Dict
    @test isempty(data) # these notebooks don't have any bonds

    @test s_export_only.run isa PlutoSliderServer.var"../Types.jl".FinishedNotebook

    response_export_only = HTTP.request(
        "GET",
        "http://localhost:$(port)/bondconnections/$(s_export_only.current_hash)/";
        status_exception=false,
    )

    @test response_export_only.status == 404 # this notebook is not in the slider server

    asset_urls = [
        ""
        "pluto_export.json"
        # 
        "a.html"
        "a.jl"
        "a.plutostate"
        "b.html"
        "b.pluto.jl"
        "b.plutostate"
        "subdir/c.html"
        "subdir/c.plutojl"
        "subdir/c.plutostate"
    ]

    @testset "Static asset - $(name)" for (i, name) in enumerate(asset_urls)

        response = HTTP.request("GET", "http://localhost:$(port)/$(name)")

        @show response.headers
        @test response.status == 200
        if endswith(name, "html")
            @test HTTP.hasheader(response, "Content-Type", "text/html; charset=utf-8")
        end
        @test HTTP.hasheader(response, "Access-Control-Allow-Origin", "*")
        @test HTTP.hasheader(response, "Referrer-Policy", "origin-when-cross-origin")
        if i > 2
            @test HTTP.hasheader(response, "Content-Length")
        end
    end

    close(ready_result[].http_server)

    try
        wait(t)
    catch e
        if !(e isa TaskFailedException)
            rethrow(e)
        end
    end
    # schedule(t, InterruptException(), error=true)
    @info "DONEZO"

end