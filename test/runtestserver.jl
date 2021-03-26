using PlutoSliderServer
ENV["JULIA_DEBUG"] = PlutoSliderServer


test_dir = tempname(cleanup=false)
cp(@__DIR__, test_dir)


try
    # open the folder on macos:
    run(`open $(test_dir)`)
catch end


cdn = let
    import Pkg
    deps = Pkg.API.dependencies()

    p_index = findfirst(p -> p.name == "Pluto", deps)
    p = deps[p_index]

    if p.is_tracking_path
        @warn """
        The Pluto dependency was added via its path, so I am assuming that you are a Pluto developer. 
        
        >> Using `localhost:1234` as the "Pluto CDN", so open Pluto if you haven't already.

        If you do not want to develop Pluto, then launch this script with the PlutoSliderServer.jl repository as environment.
        """

        "http://localhost:1234/"
    else
        nothing
    end
end

PlutoSliderServer.run_directory(test_dir; 
    static_export=true,
    run_server=true,
    SliderServer_serve_static_export_folder=true,
    SliderServer_port=2345,
    SliderServer_host="127.0.0.1",
    Export_baked_state=false,
    Export_slider_server_url="http://localhost:2345/",
    Export_pluto_cdn_root=cdn
)
