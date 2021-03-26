using PlutoSliderServer
ENV["JULIA_DEBUG"] = PlutoSliderServer


test_dir = tempname(cleanup=false)
cp(@__DIR__, test_dir)


try
    # open the folder on macos:
    run(`open $(test_dir)`)
catch end

port = 2345

# cdn = nothing
cdn = "http://127.0.0.1:$(port)/pluto_asset/"

PlutoSliderServer.run_directory(test_dir; 
    static_export=true,
    run_server=true,
    SliderServer_serve_static_export_folder=true,
    SliderServer_port=port,
    SliderServer_host="127.0.0.1",
    Export_baked_state=false,
    Export_slider_server_url="http://127.0.0.1:$(port)/",
    Export_pluto_cdn_root=cdn)
