module Export

export github_action, export_paths, generate_html

import Pluto
import Pluto: ServerSession
using HTTP
using Base64
using SHA
import Pkg


myhash = base64encode ∘ sha256

function generate_html(;
        version=nothing, pluto_cdn_root=nothing,
        notebookfile_js="undefined", statefile_js="undefined", 
        slider_server_url_js="undefined", binder_url_js="undefined", 
        disable_ui=true
    )::String

    original = read(Pluto.project_relative_path("frontend", "editor.html"), String)

    cdn_root = if pluto_cdn_root === nothing
        if version isa Nothing
            version = try_get_pluto_version()
        end
        "https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@$(string(version))/frontend/"
    else
        pluto_cdn_root
    end

    @info "Using CDN for Pluto assets:" cdn_root

    cdnified = replace(
	replace(original, 
		"href=\"./" => "href=\"$(cdn_root)"),
        "src=\"./" => "src=\"$(cdn_root)")
    
    result = replace(cdnified, 
        "<!-- [automatically generated launch parameters can be inserted here] -->" => 
        """
        <script data-pluto-file="launch-parameters">
        window.pluto_notebookfile = $(notebookfile_js)
        window.pluto_disable_ui = $(disable_ui ? "true" : "false")
        window.pluto_statefile = $(statefile_js)
        window.pluto_slider_server_url = $(slider_server_url_js)
        window.pluto_binder_url = $(binder_url_js)
        </script>
        <!-- [automatically generated launch parameters can be inserted here] -->
        """
    )

    return result
end


## CACHE

export try_fromcache, try_tocache

cache_filename(cache_dir::String, hash::String) = joinpath(cache_dir, HTTP.URIs.escapeuri(hash) * ".jlstate")

function try_fromcache(cache_dir::String, hash::String)
    p = cache_filename(cache_dir, hash)
    if isfile(p)
        try
            open(Pluto.unpack, p, "r")
        catch e
            @warn "Failed to load statefile from cache" hash exception=(e,catch_backtrace())
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
        @warn "Failed to write to cache file" hash exception=(e,catch_backtrace())
    end
end
try_tocache(cache_dir::Nothing, hash, state) = nothing



## FINDING THE PLUTO VERSION


function try_get_pluto_version()
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
        @error "Failed to get exact Pluto version from dependency. Your website is not guaranteed to work forever." exception=(e, catch_backtrace())
        Pluto.PLUTO_VERSION
    end
end





end