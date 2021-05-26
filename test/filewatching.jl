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

@testset "HTTP requests" begin
    test_dir = tempname(cleanup=false)
    mkdir(test_dir)

    try
        # open the folder on macos:
        run(`open $(test_dir)`)
    catch end

    notebook_paths_to_copy = [
        "basic2.jl",
        "parallelpaths4.jl",
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
            static_export=false,
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

    cp(joinpath(test_dir, "basic2.jl"), joinpath(test_dir, "basic2 copy.jl"))

    @test poll(10, 1/20) do
        length(notebook_sessions) == 3
    end
    
    newsesh = () -> select(s -> s.path == "basic2 copy.jl", notebook_sessions)
    @test !isnothing(newsesh())
    @test newsesh().current_hash != newsesh().desired_hash

    @test poll(30, 1/20) do
        newsesh().current_hash == newsesh().desired_hash
    end

    @test isfile(joinpath(test_dir, "basic2 copy.html"))


    # rm(joinpath(test_dir, "basic2 copy.jl"))

    # @test poll(10, 1/20) do
    #     length(notebook_sessions) == 2
    # end


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

    @test false
end