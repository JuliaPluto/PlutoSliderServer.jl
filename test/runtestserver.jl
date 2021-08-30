using PlutoSliderServer
ENV["JULIA_DEBUG"] = PlutoSliderServer


test_dir = tempname(cleanup=false)
cp(@__DIR__, test_dir)


try
    # open the folder on macos:
    run(`open $(test_dir)`)
catch end

port = 2341

# We want to use our local development version of Pluto for the frontend assets. This allows us to change and test the Pluto assets without having to restart the slider server.
cdn = "http://127.0.0.1:$(port)/pluto_asset/"
# cdn = nothing

PlutoSliderServer.run_directory(test_dir; 
    SliderServer_port=port, SliderServer_host="127.0.0.1", SliderServer_watch_dir=true, Export_pluto_cdn_root=cdn)