import PlutoSliderServer
import PlutoSliderServer.Pluto
import PlutoSliderServer.HTTP

using Test
using UUIDs
using Base64

function poll(query::Function, timeout::Real=Inf64, interval::Real=1/20)
    start = time()
    while time() < start + timeout
        if query()
            return true
        end
        sleep(interval)
    end
    return false
end

select(f::Function, xs) = for x in xs
    if f(x)
        return x
    end
end

@testset "Folder watching" begin
    test_dir = tempname(cleanup=false)
    mkdir(test_dir)

    try
        # open the folder on macos:
        run(`open $(test_dir)`)
    catch end

    notebook_paths_to_copy = [
        "basic2.jl",
    ]

    for p in notebook_paths_to_copy
        cp(joinpath(@__DIR__, p), joinpath(test_dir, p))
    end

    port = rand(12345:65000)


    still_booting = Ref(true)
    ready_result = Ref{Any}(nothing)
    function on_ready(result)
        ready_result[] = result
        still_booting[] = false
    end

    t = Pluto.@asynclog begin
        try
            PlutoSliderServer.run_directory(test_dir;
            Export_enabled=false,
            Export_output_dir=test_dir,
            SliderServer_port=port,
            SliderServer_watch_dir=true,
            on_ready)
        catch e
            if !(e isa TaskFailedException)
                showerror(stderr, e, stacktrace(catch_backtrace()))
            end
        end
    end


    while still_booting[]
        sleep(.1)
    end


    notebook_sessions = ready_result[].notebook_sessions

    @testset "Adding a file" begin

        cp(joinpath(test_dir, "basic2.jl"), joinpath(test_dir, "basic2 copy.jl"))

        @test poll(10, 1/20) do
            length(notebook_sessions) == length(notebook_paths_to_copy) + 1
        end
        
        newsesh = () -> select(s -> s.path == "basic2 copy.jl", notebook_sessions)

        @test !isnothing(newsesh())
        @test newsesh().current_hash != newsesh().desired_hash

        @test poll(60, 1/20) do
            newsesh().current_hash == newsesh().desired_hash
        end

        @test isfile(joinpath(test_dir, "basic2 copy.html"))

        @test !occursin("slider_server_url = undefined", read(joinpath(test_dir, "basic2 copy.html"), String))
        @test occursin("slider_server_url = \".\"", read(joinpath(test_dir, "basic2 copy.html"), String))
    end



    @testset "Removing a file" begin

        rm(joinpath(test_dir, "basic2 copy.jl"))

        @test !isfile(joinpath(test_dir, "basic2 copy.jl"))

        @test poll(30, 1/20) do
            length(notebook_sessions) == length(notebook_paths_to_copy)
        end
        @test !isfile(joinpath(test_dir, "basic2 copy.html"))

    end

    coolsesh = () -> select(s -> s.path == "subdir/cool.jl", notebook_sessions)
    coolcontents() = read(joinpath(test_dir, "subdir", "cool.html"), String)

    @testset "Adding a file (again)" begin

        mkdir(joinpath(test_dir, "subdir"))

        cp(joinpath(test_dir, "basic2.jl"), joinpath(test_dir, "subdir", "cool.jl"))

        @test poll(60, 1/20) do
            isfile(joinpath(test_dir, "subdir", "cool.html"))
        end
        @test poll(5, 1/20) do
            coolsesh().current_hash == coolsesh().desired_hash
        end

        @test !occursin("slider_server_url = undefined", coolcontents())
        @test occursin("slider_server_url = \"..\"", coolcontents())
    end


    @testset "Update an existing file" begin

        function coolconnectionkeys()
            response = HTTP.get("http://localhost:$(port)/bondconnections/$(HTTP.URIs.escapeuri(coolsesh().current_hash))/")
            result = Pluto.unpack(response.body)
            keys(result) |> collect |> sort
        end

        @test coolconnectionkeys() == sort(["x", "y", "s", "s2"])

        old_html_contents = coolcontents()

        Pluto.readwrite(joinpath(@__DIR__, "parallelpaths4.jl"), joinpath(test_dir, "subdir", "cool.jl"))

        @test poll(5, 1/20) do
            coolsesh().current_hash != coolsesh().desired_hash
        end
        @test isfile(joinpath(test_dir, "subdir", "cool.html"))
        @test poll(60, 1/20) do
            coolsesh().current_hash == coolsesh().desired_hash
        end
        @test isfile(joinpath(test_dir, "subdir", "cool.html"))
        @test coolcontents() != old_html_contents

        @test coolconnectionkeys() == sort(["x", "y", "show_dogs", "b", "c", "five1", "five2", "six1", "six2", "six3", "cool1", "cool2", "world", "boring"])
    end

    sleep(2)
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
end