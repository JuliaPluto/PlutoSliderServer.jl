import PlutoSliderServer
import PlutoSliderServer.Pluto
import PlutoSliderServer.HTTP
import PlutoSliderServer: plutohash, base64urlencode, base64urldecode

using Test
using UUIDs, Random

@testset "HTTP requests: dynamic" begin
    Random.seed!(time_ns())
    test_dir = tempname(cleanup=false)
    cp(joinpath(@__DIR__, "notebooks"), test_dir)

    notebook_paths = ["basic2.jl", "parallelpaths4.jl", "onedefinesanother2.jl"]

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
        @test basename(s.path) == name

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
    
    
    @testset "State request - onedefinesanother2.jl" begin
        i = 3
        s = notebook_sessions[i]

        @testset "Method $(method)" for method in ["GET", "POST"]

            v(x) = Dict("value" => x)

            bonds(x,y) = Dict("x" => v(x), "y" => v(y))

            state = Pluto.unpack(Pluto.pack(s.run.original_state))

            x_bond_id = "7f2c6b8a-6be9-4c64-b0b5-7fc4435153ee"
            y_bond_id = "2995d591-0f74-44e8-9c06-c42c2f9c68f8"
            x_id = "6bc11e12-3bdb-4ca4-a36d-f8067af95ca5"
            y_id = "80789650-d01f-4d75-8091-6117a66402cb"
            
            pack64(data) = PlutoSliderServer.base64urlencode(Pluto.pack(data))

            function makerequest(x::Int64, y::Int64, explicits::Vector{Symbol})
                explicit_arg = pack64(explicits)
                response = if method == "GET"
                    arg = pack64(bonds(x,y))

                    # escaping should have no effect
                    @test HTTP.URIs.escapeuri(arg) == arg

                    HTTP.request(
                        method,
                        "http://localhost:$(port)/staterequest/$(s.current_hash)/$(arg)?explicit=$(explicit_arg)",
                    )
                else
                    HTTP.request(
                        method,
                        "http://localhost:$(port)/staterequest/$(s.current_hash)/?explicit=$(explicit_arg)",
                        [],
                        Pluto.pack(bonds(x,y)),
                    )
                end

                patches = Pluto.unpack(response.body)["patches"]
                
                for patch in patches
                    Pluto.Firebasey.applypatch!(
                        state,
                        convert(Pluto.Firebasey.JSONPatch, patch),
                    )
                end
                
                patches
            end
            
            find_patches(patches, path; op::String="replace") = any(p -> p["op"] == op && p["path"] == path, patches)
            y_bond_path = ["cell_results", y_bond_id, "output", "body"]
            max_regex(z) = Regex("max=['\"]$z['\"]")
            
            @testset "Move x" begin
                patches = makerequest(10, 1, [:x])
                @test state["cell_results"][x_id]["output"]["body"] == "59"
                @test state["cell_results"][y_id]["output"]["body"] == "59"
                
                # The slider should now have fewer possible values
                y_max = length(59:200)
                @test occursin(max_regex(y_max), state["cell_results"][y_bond_id]["output"]["body"])
                
                # There should have been a patch for that bond
                @test find_patches(patches, y_bond_path)
                @test find_patches(patches, ["bonds", "y"]; op="remove")
            end
            
            
            
            
            @testset "Move y" begin
                # Now we move y:
                patches2 = makerequest(10, 10, [:y])
                @test state["cell_results"][x_id]["output"]["body"] == "59"
                @test state["cell_results"][y_id]["output"]["body"] == "68"
                
                
                # The slider should have the same possible values
                y_max = length(59:200)
                @test occursin(max_regex(y_max), state["cell_results"][y_bond_id]["output"]["body"])
                
                # There should be no patch for the y bond
                @test !find_patches(patches2, y_bond_path)
            end
            
            
            @testset "Move x and y together" begin
                # Now we move x and y together:
                patches3 = makerequest(20, 20, [:x, :y])
                @test state["cell_results"][x_id]["output"]["body"] == "69"
                
                # Because x changed, the value of y is considered invalid and ignored.
                @test state["cell_results"][y_id]["output"]["body"] == "69"
                
                # There should be a patch for the y bond because x changed
                @test find_patches(patches3, y_bond_path)
                @test find_patches(patches3, ["bonds", "y"]; op="remove")
            end
            
            # The browser would rerender the y bond and send this immediately after:
            makerequest(20, 1, [:y])
            
            @testset "Move y again" begin
                patches4 = makerequest(20, 20, [:y])
                @test state["cell_results"][x_id]["output"]["body"] == "69"
                @test state["cell_results"][y_id]["output"]["body"] == "88"
                
                # There should be no patch for the y bond
                @test !find_patches(patches4, y_bond_path)
            end
            
            
            @testset "Move x again" begin
                # Now we just move x:
                patches5 = makerequest(30, 20, [:x])
                @test state["cell_results"][x_id]["output"]["body"] == "79"
                @test state["cell_results"][y_id]["output"]["body"] == "79"
                
                # There should have been a patch for that bond
                @test find_patches(patches5, y_bond_path)
                @test find_patches(patches5, ["bonds", "y"]; op="remove")
            end
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


original_dir1 = joinpath(@__DIR__, "notebooks", "dir1")
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

    response = HTTP.request(
        "GET",
        "http://localhost:$(port)/bondconnections/$(s_a.current_hash)/";
        status_exception=false,
    )
    @test response.status == 422 # notebook is no longer running since it has no bonds

    types_sym = Symbol(replace("../Types.jl", '/' => Base.Filesystem.path_separator))
    @test s_export_only.run isa getfield(PlutoSliderServer, types_sym).FinishedNotebook

    response_export_only = HTTP.request(
        "GET",
        "http://localhost:$(port)/bondconnections/$(s_export_only.current_hash)/";
        status_exception=false,
    )

    @test response_export_only.status == 422 # this notebook is not in the slider server but was exported

    response_no_notebook = HTTP.request(
        "GET",
        "http://localhost:$(port)/bondconnections/$(plutohash("abc"))/";
        status_exception=false,
    )

    @test response_no_notebook.status == 404 # this notebook is not in the slider server

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