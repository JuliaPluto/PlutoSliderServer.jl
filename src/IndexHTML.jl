
using FromFile


import Pluto: Pluto, without_pluto_file_extension

@from "./Configuration.jl" import PlutoDeploySettings
@from "./Types.jl" import NotebookSession, RunningNotebook


function generate_basic_index_html(paths)
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">

        <style>
        body {
            font-family: sans-serif;
        }
        </style>

        <link rel="stylesheet" href="index.css">
        <script src="index.js" type="module" defer></script>
    </head>  
    <body>
        <h1>Notebooks</h1>
        
        <ul>
        $(join(
            if link === nothing
                """<li>$(name) <em style="opacity: .5;">(Loading...)</em></li>"""
            else
                """<li><a href="$(link)">$(name)</a></li>"""
            end
            for (name,link) in paths
        ))
        </ul>
    </body>
    </html>
    """
end

function generate_index_html(
    sessions::Vector{NotebookSession};
    settings::PlutoDeploySettings,
)
    if something(settings.Export.create_pluto_featured_index, false)
        Pluto.generate_index_html(;
            pluto_cdn_root=settings.Export.pluto_cdn_root,
            version=try_get_exact_pluto_version(),
            featured_static=true,
            featured_direct_html_links=true,
            featured_sources_js="[{url:`./pluto_export.json`}]",
        )
    else
        temp_index(sessions)
    end
end



function temp_index(notebook_sessions::Vector{NotebookSession})
    generate_basic_index_html(Iterators.map(temp_index_item, notebook_sessions))
end
function temp_index_item(s::NotebookSession)
    without_pluto_file_extension(s.path) => nothing
end
function temp_index_item(s::NotebookSession{String,String,<:Any})
    without_pluto_file_extension(s.path) => without_pluto_file_extension(s.path) * ".html"
end
