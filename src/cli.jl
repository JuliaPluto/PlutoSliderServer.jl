"""
TODOs:

Notes:
https://argparsejl.readthedocs.io/en/latest/argparse.html

APIs:

Command line
functionality:
    - export html
    - export statefiles
    - run notebook server

configuration
    --export
    - --output_dir
    - --exclude
    - --ignore_cache
    - --pluto_cdn_root
    - --baked_state
    - --offer_binder
    - --disable_ui
    - --cache_dir
    - --slider_server_url
    - --binder_url

    --run
    - --SliderServer_exclude
    - --SliderServer_port
    - --SliderServer_host
    - --static_export
    - --notebook_paths

    --disable-admin-secret [disable] (otherwise randomly generated, as in pluto)

WEB
    - [CREATE] start notebook by hash or by post
    - [READ] is already there? think more
    - [UPDATE is either POST new or not needed]
    - [DELETE] stop notebook by hash

"""

using ArgParse
import Pkg
import PlutoSliderServer
import UUIDs:uuid4

include("./FileHelpers.jl")

project_relative_path(xs...) = normpath(joinpath(dirname(dirname(pathof(PlutoSliderServer))), xs...))


function parse_commandline()
    clisettings = ArgParseSettings(
        description="""Pluto Slide Server.
    A boutique pluto-notebook runner that gives life to your static exports.

    Can respond to @bind macros updates but also just create static exports that look cool.
    """,
        version='v' * string((VersionNumber(Pkg.TOML.parsefile(project_relative_path("Project.toml"))["version"]))),
        add_version=true
    )

    @add_arg_table clisettings begin
        "start_dir"
            help = "The starting directory"
            default = "."
        "--host"
            help = "host:port"
            default = "127.0.0.1"
            arg_type = String
        "--port"
            help = "port"
            default = 2345
            arg_type = Int
        "--dry-run"
            help = "Stop the the slider server after running once. Useful in conjuction with --export."
            action = :store_true
        "--notebook_paths"
            help = "The paths in which to look for notebooks"
            nargs = '*'
            arg_type = Vector{String}
        "--skip-run-notebooks"
            help = "list of notebook files to skip from running."
            nargs = '*'
            arg_type = Vector{String}
        "--export"
            help = "also export static files"
            action = :store_true
        "--export-only"
            help = "Same as --export --dry-run"
            action = :store_true
        "--export-exclude"
            help = "Export option. list of notebook files to skip from exporting"
    nargs = '*'
            arg_type = Vector{String}
        "--enable-ui"
            help = "Export option. Don't hide all buttons and toolbars. Without this flag, they will be hidden by default to make the page look like an article"
            action = :store_true
        "--separate-pluto-state"
            help = "Export option. If set this flag splits the export to two files: a .plutostate and an .html. Default is to have state 'baked in' the file'"
            action = :store_true
        "--binder-url"
            help = "Export option. This will set the binder URL that will be used as a backend. MIT Math uses: https://mybinder.org/v2/gh/mitmath/18S191/e2dec90"
            default = ""
            arg_type = String
        "--slider-server-url"
            help = "Export option. The URL of the slider server which can respond to requests of @bind elements"
        "--cache-dir"
            help = "if provided, use this directory to read and write cached notebook states. Caches will be indexed by notebook hash, but you need to take care to invalidate the cache when Pluto or this export script updates. Useful in combination with https://github.com/actions/cache."
        "--output-dir"
            help = "folder to write generated HTML files to (will create directories to preserve the input folder structure). Leave at the default to generate each HTML file in the same folder as the notebook file."
            default = "."
        "--config", "-c", "--configuration_file"
            help = "Use this option to provide a configuration TOML"
        "--sample-toml"
            help = "Print a sample TOML configuration file"
        "--enable-api"
            help = "Allow API requests"
    action = :store_true
        "--secret"
            help = "Web API secret"
    end
    return parse_args(clisettings)
end

function cli()
    parsed_args = parse_commandline()
    println("Parsed args:")
    for (arg, val) in parsed_args
        println("  $arg  =>  $val ($(typeof(val)))")
    end
    #= transform options =#
    notebook_paths = parsed_args["notebook_paths"] == [] ? find_notebook_files_recursive(parsed_args["start_dir"]) : [parsed_args["start_dir"]]
    static_export = parsed_args["export"] || parsed_args["export-only"]
    run_server = !parsed_args["dry-run"] && !parsed_args["export-only"]
    config_toml_path = parsed_args["config"]
    SliderServer_exclude = parsed_args["skip-run-notebooks"]
    @info "Server arguments" notebook_paths static_export run_server config_toml_path
    
    Export_exclude = parsed_args["export-exclude"]
    Export_disable_ui = !parsed_args["enable-ui"]
    Export_baked_state = !parsed_args["separate-pluto-state"]
    Export_offer_binder = length(parsed_args["binder-url"]) > 0
    Export_binder_url = parsed_args["binder-url"]
    Export_slider_server_url = parsed_args["slider-server-url"]
    Export_cache_dir = parsed_args["cache-dir"]
    Export_output_dir = parsed_args["output-dir"]

    @info "Export arguments" Export_exclude Export_disable_ui Export_baked_state Export_offer_binder Export_binder_url Export_slider_server_url Export_cache_dir Export_output_dir
    
    PlutoSliderServer.run_directory(
        parsed_args["start_dir"];
        SliderServer_port=parsed_args["port"],
        SliderServer_host=parsed_args["host"],
        SliderServer_exclude=SliderServer_exclude,
        notebook_paths=notebook_paths,
        static_export=static_export,
        run_server=run_server,
        config_toml_path=config_toml_path,
        Export_exclude=Export_exclude,
        Export_disable_ui=Export_disable_ui,
        Export_baked_state=Export_baked_state,
        Export_offer_binder=Export_offer_binder,
        Export_binder_url=Export_binder_url,
        Export_slider_server_url=Export_slider_server_url,
        Export_cache_dir=Export_cache_dir,
        Export_output_dir=Export_output_dir,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    cli()
end

"""
POST a notebook, calculate its hash and start if not already running
"""
function run_notebook()

end

"""
POST a notebook hash and stop it if it's running
"""

function stop_notebook()

end


