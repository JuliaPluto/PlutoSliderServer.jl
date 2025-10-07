
using FromFile


import Pluto: Pluto, without_pluto_file_extension

@from "./Configuration.jl" import PlutoDeploySettings
@from "./Types.jl" import NotebookSession, RunningNotebook
@from "./Export.jl" import try_get_exact_pluto_version
@from "./gitpull.jl" import get_git_hash_cached


commit_html(hash::String) = hash == "" ? "" : """
<p style="
    opacity: .3;
    margin-top: 5rem;
">Git commit: <code>$hash</code></p>
"""


function generate_basic_index_html(paths; hash::String="")
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
        $(commit_html(hash))
    </body>
    </html>
    """
end

function generate_index_html(
    sessions::Vector{NotebookSession};
    settings::PlutoDeploySettings,
    start_dir::AbstractString,
)
    if something(settings.Export.create_pluto_featured_index, false)
        Pluto.generate_index_html(;
            pluto_cdn_root=settings.Export.pluto_cdn_root,
            version=try_get_exact_pluto_version(),
            featured_direct_html_links=true,
            featured_sources_js="[{url:`./pluto_export.json`}]",
        )
    else
        generate_basic_index_html((
            without_pluto_file_extension(s.path) =>
                without_pluto_file_extension(s.path) * ".html" for s in sessions
        ); hash=get_git_hash_cached(start_dir))
    end
end



function generate_temp_index_html(
    notebook_sessions::Vector{NotebookSession};
    settings::PlutoDeploySettings,
    start_dir::AbstractString,
)
    generate_basic_index_html(Iterators.map(temp_index_item, notebook_sessions); hash=get_git_hash_cached(start_dir))
end

function temp_index_item(s::NotebookSession)
    without_pluto_file_extension(s.path) => nothing
end
function temp_index_item(s::NotebookSession{String,String,<:Any})
    without_pluto_file_extension(s.path) => without_pluto_file_extension(s.path) * ".html"
end
