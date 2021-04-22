module Export

export generate_html, default_index

import Pluto
import Pluto: ServerSession, generate_html
using HTTP
using Base64
using SHA
import Pkg

using FromFile

## CACHE

export try_fromcache, try_tocache

cache_filename(cache_dir::String, hash::String) = joinpath(cache_dir, HTTP.URIs.escapeuri(hash) * ".plutostate")

function try_fromcache(cache_dir::String, hash::String)
    p = cache_filename(cache_dir, hash)
    if isfile(p)
        try
            open(Pluto.unpack, p, "r")
        catch e
            @warn "Failed to load statefile from cache" hash exception = (e, catch_backtrace())
        end
    end
end
try_fromcache(cache_dir::Nothing, hash) = nothing


function try_tocache(cache_dir::String, hash::String, state)
    mkpath(cache_dir)
    try
        open(cache_filename(cache_dir, hash), "w") do io
            Pluto.pack(io, state)
        end
    catch e
        @warn "Failed to write to cache file" hash exception = (e, catch_backtrace())
    end
end
try_tocache(cache_dir::Nothing, hash, state) = nothing



## FINDING THE PLUTO VERSION


function try_get_exact_pluto_version()
    try
        deps = Pkg.API.dependencies()

        p_index = findfirst(p -> p.name == "Pluto", deps)
        p = deps[p_index]

        if p.is_tracking_registry
            p.version
        elseif p.is_tracking_path
            error("Do not add the Pluto dependency as a local path, but by specifying its VERSION or an exact COMMIT SHA.")
        else
            # ugh
            is_probably_a_commit_thing = all(in(('0':'9') ∪ ('a':'f')), p.git_revision)
            if !is_probably_a_commit_thing
                error("Do not add the Pluto dependency by specifying its BRANCH, but by specifying its VERSION or an exact COMMIT SHA.")
            end

            p.git_revision
        end
    catch e
        @error "Failed to get exact Pluto version from dependency. Your website is not guaranteed to work forever." exception = (e, catch_backtrace())
        Pluto.PLUTO_VERSION
    end
end


function default_index(paths)
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
            for (name, link) in paths
        ))
        </ul>
    </body>
    </html>
    """
end


end