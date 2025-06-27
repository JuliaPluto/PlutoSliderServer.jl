using PlutoSliderServer
using FromFile
using Test

toml_path = tempname()

write(toml_path, PlutoSliderServer.sample_config_toml_file)

result = PlutoSliderServer.get_configuration(toml_path; Export_binder_url="yayy")

@test result.Export.binder_url == "yayy"
@test result.Pluto.compiler.threads == 1

@test PlutoSliderServer.default_config_path() isa String





