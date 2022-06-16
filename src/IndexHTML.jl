
using FromFile


import Pluto: Pluto, without_pluto_file_extension

@from "./Configuration.jl" import PlutoDeploySettings
@from "./Types.jl" import NotebookSession, RunningNotebook


function generate_index_html(paths)
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



function temp_index(notebook_sessions::Vector{NotebookSession})
    generate_index_html(temp_index_item.(notebook_sessions))
end
function temp_index_item(s::NotebookSession)
    without_pluto_file_extension(s.path) => nothing
end
function temp_index_item(s::NotebookSession{String,String,<:Any})
    without_pluto_file_extension(s.path) => without_pluto_file_extension(s.path) * ".html"
end
