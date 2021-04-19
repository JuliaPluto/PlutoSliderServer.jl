using ArgParse
import Pkg
import UUIDs:uuid4

project_relative_path(xs...) = normpath(joinpath(dirname(dirname(pathof(PlutoSliderServer))), xs...))

global github_url = nothing

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
        "startdir"
            help = "The starting directory"
            default = "."
        "--host"
            help = "Host. you may want to use 0.0.0.0 if you run on server / behind a reverse proxy"
            default = "127.0.0.1"
            arg_type = String
    "--port"
            help = "port"
            default = 2345
            arg_type = Int
        "--dry-run"
            help = "Stop the the slider server after running once. Useful in conjuction with --export."
            action = :store_true
        "--serve-static-folder"
            help = "Serve the HTML files found in the folder"
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
        "--run-test-server-shortcut"
            help = """Runs a test server that servers all assets locally. Useful for development.
Shortcut for running:
    julia --project=. -e "using PlutoSliderServer; cli()" --
        --host 127.0.0.1 --port 2345 --separate-pluto-state --serve-static-folder --export\\
        --pluto-root http://127.0.0.1:2345/pluto_asset/ --slider-server-url http://127.0.0.1:2345/ """
    action = :store_true
        "--sample-toml"
            help = "Print a sample TOML configuration file"
    "--enable-api"
            help = "Allow API requests"
            action = :store_true
        "--secret"
            help = "Web API secret"
        "--debug"
            help = "Enable debugging of PlutoSliderServer"
            action = :store_true
        "--config", "-c", "--configuration_file"
            help = "Use this option to provide a configuration TOML"
    end
    return parse_args(clisettings)
end
    
function cli()
    parsed_args = parse_commandline()
    # That's bad, I know
    if parsed_args["run-test-server-shortcut"]
        if parsed_args["debug"]
            ENV["JULIA_DEBUG"] = PlutoSliderServer
        end
        test_dir = tempname(cleanup=false)
        cp(parsed_args["startdir"], test_dir)
        try
            # open the folder on macos:
            run(`open $(test_dir)`)
        catch end

        # cdn = nothing
        cdn = "http://$(parsed_args["host"]):$(parsed_args["port"])/pluto_asset/"
        slider_url = "http://$(parsed_args["host"]):$(parsed_args["port"])/"
        @info "You can now go to $(slider_url) to test your notebooks!"
        PlutoSliderServer.run_directory(
            test_dir; 
            static_export=true,
            run_server=true,
            SliderServer_serve_static_export_folder=true,
            SliderServer_port=parsed_args["port"],
            SliderServer_host=parsed_args["host"],
            Export_baked_state=false,
            Export_slider_server_url=slider_url,
            Export_pluto_cdn_root=cdn
        )
        return
    end
    #= transform options =#
    notebook_paths = parsed_args["notebook_paths"] == [] ? find_notebook_files_recursive(parsed_args["startdir"]) : [parsed_args["startdir"]]
    static_export = parsed_args["export"] || parsed_args["export-only"]
    run_server = !parsed_args["dry-run"] && !parsed_args["export-only"]
    config_toml_path = parsed_args["config"]
    SliderServer_exclude = parsed_args["skip-run-notebooks"]
    serve_static_files = parsed_args["serve-static-folder"]

    Export_exclude = parsed_args["export-exclude"]
    Export_disable_ui = !parsed_args["enable-ui"]
    Export_baked_state = !parsed_args["separate-pluto-state"]
    Export_offer_binder = length(parsed_args["binder-url"]) > 0
    Export_binder_url = parsed_args["binder-url"]
    Export_slider_server_url = parsed_args["slider-server-url"]
    Export_cache_dir = parsed_args["cache-dir"]
    Export_output_dir = parsed_args["output-dir"]
    Export_pluto_cdn_root = parsed_args["pluto-static-root"]

    PlutoSliderServer.run_directory(
        parsed_args["startdir"];
        SliderServer_port=parsed_args["port"],
        SliderServer_host=parsed_args["host"],
        SliderServer_exclude=SliderServer_exclude,
        SliderServer_serve_static_export_folder=serve_static_files,
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
Export_pluto_cdn_root=Export_pluto_cdn_root
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    cli()
end
