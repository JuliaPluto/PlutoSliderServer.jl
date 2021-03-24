using PlutoSliderServer

test_dir = tempname(cleanup=false)
cp(@__DIR__, test_dir)


PlutoSliderServer.run_directory(test_dir; SliderServer_serve_static_export_folder=true, SliderServer_port=2345, SliderServer_host="127.0.0.1", Export_slider_server_url="http://localhost:2345/")