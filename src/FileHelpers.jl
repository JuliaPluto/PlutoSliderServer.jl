module FileHelpers
import Pluto:is_pluto_notebook

flatmap(args...) = vcat(map(args...)...)

list_files_recursive(dir=".") = let
    paths = flatmap(walkdir(dir)) do (root, dirs, files)
        joinpath.([root], files)
    end
    relpath.(paths, [dir])
end

"""
Search recursively for Pluto notebook files.

Return paths relative to the search directory.
"""
function find_notebook_files_recursive(start_dir)
    notebook_files = filter(is_pluto_notebook, list_files_recursive(start_dir))
    
    not_interal_notebook_files = filter(notebook_files) do f
        !occursin(".julia", f) || occursin(".julia", start_dir)
    end

    # reverse alphabetical order so that week5 becomes available before week4 :)
    reverse(not_interal_notebook_files)
end

function generate_static_export(path, settings)
    export_jl_path = let
        relative_to_notebooks_dir = path
        joinpath(output_dir, relative_to_notebooks_dir)
    end
    export_html_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(path) * ".html"
        joinpath(output_dir, relative_to_notebooks_dir)
    end
    export_statefile_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(path) * ".plutostate"
        joinpath(output_dir, relative_to_notebooks_dir)
    end


    mkpath(dirname(export_jl_path))
    mkpath(dirname(export_html_path))
    mkpath(dirname(export_statefile_path))


    notebookfile_js = if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing)
        repr(basename(export_jl_path))
    else
        "undefined"
    end
    slider_server_url_js = if settings.Export.slider_server_url !== nothing
        repr(settings.Export.slider_server_url)
    else
        "undefined"
    end
    binder_url_js = if settings.Export.offer_binder
        repr(something(settings.Export.binder_url, "https://mybinder.org/v2/gh/fonsp/pluto-on-binder/v$(string(pluto_version))"))
    else
        "undefined"
    end

    statefile_js = if !settings.Export.baked_state
        open(export_statefile_path, "w") do io
            Pluto.pack(io, original_state)
        end
        repr(basename(export_statefile_path))
    else
        statefile64 = base64encode() do io
            Pluto.pack(io, original_state)
        end

        "\"data:;base64,$(statefile64)\""
    end

    html_contents = generate_html(;
        pluto_cdn_root=settings.Export.pluto_cdn_root,
        version=pluto_version,
        notebookfile_js, statefile_js,
        slider_server_url_js, binder_url_js,
        disable_ui=settings.Export.disable_ui
    )
    write(export_html_path, html_contents)

    # TODO: maybe we can avoid writing the .jl file if only the slider server is needed? the frontend only uses it to get its hash
    var"we need the .jl file" = (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing)
    var"the .jl file is already there and might have changed" = isfile(export_jl_path)

    if var"we need the .jl file" || var"the .jl file is already there and might have changed"
        write(export_jl_path, jl_contents)
    end

    @info "Written to $(export_html_path)"
end
end

