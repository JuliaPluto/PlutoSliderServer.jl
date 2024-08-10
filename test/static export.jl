using PlutoSliderServer
using PlutoSliderServer: list_files_recursive
using Test
using Logging
import JSON
import Pluto: without_pluto_file_extension
import Random

original_dir1 = joinpath(@__DIR__, "dir1")
make_test_dir() =
    let
        Random.seed!(time_ns())
        new = tempname(cleanup=false)
        cp(original_dir1, new)
        new
    end

@testset "static - Basic github action" begin
    test_dir = make_test_dir()

    @show test_dir cache_dir
    cd(test_dir)
    @test sort(list_files_recursive()) ==
          sort(["a.jl", "b.pluto.jl", "notanotebook.jl", "subdir/c.plutojl"])

    github_action(Export_cache_dir=cache_dir, Export_baked_state=true)

    @test sort(list_files_recursive()) == sort([
        "index.html",
        "pluto_export.json",
        #
        "a.jl",
        "a.html",
        "b.pluto.jl",
        "b.html",
        "notanotebook.jl",
        "subdir/c.plutojl",
        "subdir/c.html",
    ])

    # Test whether the notebook file did not get changed
    @test read(joinpath(original_dir1, "a.jl"), String) ==
          read(joinpath(test_dir, "a.jl"), String)

    # Test cache
    @test isdir(cache_dir) # should be created 
    @show list_files_recursive(cache_dir)
    @test length(list_files_recursive(cache_dir)) >= 2

    # Test runtime to check that the cache works
    second_runtime = with_logger(NullLogger()) do
        0.1 * @elapsed for i = 1:10
            github_action(Export_cache_dir=cache_dir)
        end
    end
    @show second_runtime
    @test second_runtime < 1.0

    @test occursin("slider_server_url = undefined", read("a.html", String))

    jsonstr = read("pluto_export.json", String)
    json = JSON.parse(jsonstr)
    @test json["slider_server_url"] === nothing
    
    @test PlutoSliderServer.try_get_exact_pluto_version() !== nothing
    ijd = PlutoSliderServer.index_json_data(
        PlutoSliderServer.NotebookSession[];
        settings=Pluto.Configuration.Configurations.from_kwargs(
            PlutoSliderServer.PlutoDeploySettings, 
            Export_slider_server_url="yoyoyo"
        ),
        start_dir="doesnotmatter", 
        config_data=Dict{String,Any}("title" => "fofofo"),
    )
    @test occursin("yoyoyo", JSON.json(ijd))
    @test occursin("fofofo", JSON.json(ijd))
end


@testset "static - Separate state & notebook files" begin
    test_dir = make_test_dir()
    @show test_dir
    cd(test_dir)
    @test sort(list_files_recursive()) ==
          sort(["a.jl", "b.pluto.jl", "notanotebook.jl", "subdir/c.plutojl"])

    config_contents = """
    [Export]
    baked_state = false
    baked_notebookfile = false
    binder_url = "pannenkoek"
    exclude = [
        "subdir/*",
        "sadfsadfdfsadsf",
    ]
    """

    config_path = tempname()
    write(config_path, config_contents)

    github_action(
        Export_offer_binder=true,
        Export_slider_server_url="appelsap",
        config_toml_path=config_path,
    )

    c = PlutoSliderServer.get_configuration(
        config_path;
        Export_slider_server_url="appelsap",
    )

    @test c.Export.slider_server_url == "appelsap"

    @test sort(list_files_recursive()) == sort([
        "index.html",
        "pluto_export.json",
        #
        "a.jl",
        "a.html",
        "a.plutostate",
        "b.pluto.jl",
        "b.html",
        "b.plutostate",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])


    htmlstr_a = replace(read("a.html", String), '\'' => '\"')
    htmlstr_b = read("b.html", String)

    # test that export settings were used in the HTML file
    @test occursin("a.jl", htmlstr_a)
    @test occursin("a.plutostate", htmlstr_a)
    @test occursin("pannenkoek", htmlstr_a)
    @test occursin("appelsap", htmlstr_a)

    # test that frontmatter is used in the HTML
    @test occursin("<title>My&lt;Title</title>", htmlstr_a)
    @test occursin("""<meta name="description" content="ccc">""", htmlstr_a)
    @test occursin("""<meta property="og:description" content="ccc">""", htmlstr_a)
    @test occursin("""<meta property="og:article:tag" content="aaa">""", htmlstr_a)
    @test occursin("""<meta property="og:article:tag" content="bbb">""", htmlstr_a)
    @test occursin("""<meta property="og:type" content="article">""", htmlstr_a)


    @test !occursin("<title>", htmlstr_b)

end

@testset "static - Single notebook" begin
    test_dir = make_test_dir()

    # @show test_dir cache_dir
    cd(test_dir)
    @test sort(list_files_recursive()) ==
          sort(["a.jl", "b.pluto.jl", "notanotebook.jl", "subdir/c.plutojl"])

    export_notebook("a.jl"; Export_cache_dir=cache_dir, Export_baked_state=true)

    @test sort(list_files_recursive()) == sort([
        # no index for single notebooks
        # "index.html",

        "a.jl",
        "a.html",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

end


@testset "static - Index HTML and JSON – fancy=$(fancy)" for fancy ∈ (false, true)
    test_dir = make_test_dir()

    @show test_dir cache_dir
    cd(test_dir)
    @test sort(list_files_recursive()) ==
          sort(["a.jl", "b.pluto.jl", "notanotebook.jl", "subdir/c.plutojl"])

    export_directory(
        Export_cache_dir=cache_dir,
        Export_baked_state=false,
        Export_create_pluto_featured_index=fancy,
        Export_slider_server_url="krat",
    )

    @test sort(list_files_recursive()) == sort([
        "index.html",
        "pluto_export.json",
        #
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

    htmlstr = read("index.html", String)
    jsonstr = read("pluto_export.json", String)
    json = JSON.parse(jsonstr)

    if fancy
        @test occursin("</html>", htmlstr)
        @test occursin("pluto_export.json", htmlstr)
    end
    @test json["slider_server_url"] == "krat"

    nbs = ["subdir/c.plutojl", "b.pluto.jl", "a.jl"]
    for (i, p) in enumerate(nbs)
        @test occursin(p, jsonstr)
        if !fancy
            @test occursin(p |> without_pluto_file_extension, htmlstr)
        end

        @test !isempty(json["notebooks"][p]["frontmatter"]["title"])
        without_pluto_file_extension
    end

    # TODO: use frontmatter.title here instead of the filename? or make the switch to PlutoPages?
end

