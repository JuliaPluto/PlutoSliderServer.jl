using PlutoSliderServer
using PlutoSliderServer: list_files_recursive
using Test
using Logging

original_dir1 = joinpath(@__DIR__, "dir1")
make_test_dir() = let
    new = tempname(cleanup=false)
    cp(original_dir1, new)
    new
end


@testset "Basic github action" begin
    test_dir = make_test_dir()
    cache_dir = tempname(cleanup=false)

    @show test_dir cache_dir
    cd(test_dir)
    @test sort(list_files_recursive()) == sort([
        "a.jl",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

    github_action(
        Export_cache_dir=cache_dir,
        Export_baked_state=true,
    )

    @test sort(list_files_recursive()) == sort([ 
        "index.html",
        "a.jl",
        "a.html",
        "b.pluto.jl",
        "b.html",
        "notanotebook.jl",
        "subdir/c.plutojl",
        "subdir/c.html",
    ])

    # Test whether the notebook file did not get changed
    @test read(joinpath(original_dir1, "a.jl")) == read(joinpath(test_dir, "a.jl"))

    # Test cache
    @test isdir(cache_dir) # should be created 
    @show list_files_recursive(cache_dir)
    @test length(list_files_recursive(cache_dir)) >= 2

    # Test runtime to check that the cache works
    second_runtime = with_logger(NullLogger()) do
        .1 * @elapsed for i in 1:10
            github_action(
                Export_cache_dir=cache_dir,
            )
        end
    end
    @show second_runtime
    @test second_runtime < 1.0
end


@testset "Separate state files" begin
    test_dir = make_test_dir()
    @show test_dir
    cd(test_dir)
    @test sort(list_files_recursive()) == sort([
        "a.jl",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

    config_contents = """
    [Export]
    baked_state = false
    binder_url = "pannenkoek"
    """

    config_path = tempname()
    write(config_path, config_contents)

    github_action(
        Export_offer_binder=true,
        Export_slider_server_url="appelsap",
        config_toml_path=config_path,
    )

    @test sort(list_files_recursive()) == sort([
        "index.html",

        "a.jl",
        "a.html",
        "a.plutostate",

        "b.pluto.jl",
        "b.html",
        "b.plutostate",

        "notanotebook.jl",

        "subdir/c.plutojl",
        "subdir/c.html",
        "subdir/c.plutostate",
    ])

    @test occursin("a.jl", read("a.html", String))
    @test occursin("a.plutostate", read("a.html", String))
    @test occursin("pannenkoek", read("a.html", String))
    @test occursin("appelsap", read("a.html", String))
end

