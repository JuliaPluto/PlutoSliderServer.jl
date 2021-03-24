module Export

export github_action, export_paths, generate_html

import Pluto
import Pluto: ServerSession
using HTTP
using Base64
using SHA
import Pkg


myhash = base64encode ∘ sha256

# """
# Search recursively for all Pluto notebooks in the current folder, and for each notebook:
# - Run the notebook and wait for all cells to finish
# - Export the state object
# - Create a .html file with the same name as the notebook, which has:
#   - The JS and CSS assets to load the Pluto editor
#   - The state object embedded
#   - Extra functionality enabled, such as hidden UI, binder button, and a live bind server

# # Arguments
# - `export_dir::String="."`: folder to write generated HTML files to (will create directories to preserve the input folder structure). Leave at the default `"."` to generate each HTML file in the same folder as the notebook file.
# - `disable_ui::Bool=true`: hide all buttons and toolbars to make it look like an article.
# - `baked_state::Bool=true`: base64-encode the state object and write it inside the .html file. If `false`, a separate `.plutostate` file is generated.
# - `offer_binder::Bool=false`: show a "Run on Binder" button on the notebooks. Use `binder_url` to choose a binder repository.
# - `binder_url::Union{Nothing,String}=nothing`: e.g. `https://mybinder.org/v2/gh/mitmath/18S191/e2dec90` TODO docs
# - `slider_server_url::Union{Nothing,String}=nothing`: e.g. `https://bindserver.mycoolproject.org/` TODO docs
# - `cache_dir::Union{Nothing,String}=nothing`: if provided, use this directory to read and write cached notebook states. Caches will be indexed by notebook hash, but you need to take care to invalidate the cache when Pluto or this export script updates. Useful in combination with https://github.com/actions/cache.

# Additional keyword arguments will be passed on to the configuration of `Pluto`. See [`Pluto.Configuration`](@ref) for more info.
# """
# function export_paths(notebook_paths::Vector{String}; export_dir::String=".", baked_state::Bool=true, offer_binder::Bool=false, disable_ui::Bool=true, slider_server_url::Union{Nothing,String}=nothing, binder_url::Union{Nothing,String}=nothing, cache_dir::Union{Nothing,String}=nothing, kwargs...)
#     # TODO how can we fix the binder version to a Pluto version? We can't use the Pluto hash because the binder repo is different from Pluto.jl itself. We can use Pluto versions, tag those on the binder repo.
#     if offer_binder && binder_url === nothing
#         @warn "We highly recommend setting the `binder_url` keyword argument with a fixed commit hash. The default is not fixed to a specific version, and the binder button will break when Pluto updates.
        
#         This might be automated in the future."
#     end
#     export_dir = Pluto.tamepath(export_dir)

#     pluto_options = Pluto.Configuration.from_flat_kwargs(; kwargs...)
#     session = Pluto.ServerSession(;options=pluto_options)

#     cache_dir !== nothing && mkpath(cache_dir)

#     for (i, path) in enumerate(notebook_paths)
#         try
#             export_jl_path = let
#                 relative = path
#                 joinpath(export_dir, relative)
#             end
#             export_html_path = let
#                 relative = without_pluto_file_extension(path) * ".html"
#                 joinpath(export_dir, relative)
#             end
#             export_statefile_path = let
#                 relative = without_pluto_file_extension(path) * ".plutostate"
#                 joinpath(export_dir, relative)
#             end
#             mkpath(dirname(export_jl_path))
#             mkpath(dirname(export_html_path))
#             mkpath(dirname(export_statefile_path))

#             jl_contents = read(path)



#             @info "[$(i)/$(length(notebook_paths))] Opening $(path)"

#             hash = myhash(jl_contents)

#             cached_state = try_fromcache(cache_dir, hash)
#             if cached_state !== nothing
#                 @info "Loaded from cache, skipping notebook run" hash
#                 state = cached_state
#             else
#                 # open and run the notebook (TODO: tell pluto not to write to the notebook file)
#                 local notebook = Pluto.SessionActions.open(session, path; run_async=false)
#                 # get the state object
#                 state = Pluto.notebook_to_js(notebook)
#                 # shut down the notebook
#                 Pluto.SessionActions.shutdown(session, notebook)

#                 if cache_dir !== nothing
#                     try
#                         open(cache_filename(cache_dir, hash), "w") do io
#                             Pluto.pack(io, state)
#                         end
#                     catch e
#                         @warn "Failed to write to cache file" hash exception=(e,catch_backtrace())
#                     end
#                 end
#             end

#             @info "Ready $(path)" hash

#             notebookfile_js = if offer_binder
#                 repr(basename(export_jl_path))
#             else
#                 "undefined"
#             end

#             slider_server_url_js = if slider_server_url !== nothing
#                 repr(slider_server_url)
#             else
#                 "undefined"
#             end

#             binder_url_js = if binder_url !== nothing
#                 repr(binder_url)
#             else
#                 "undefined"
#             end

#             statefile_js = if !baked_state
#                 open(export_statefile_path, "w") do io
#                     Pluto.pack(io, state)
#                 end
#                 repr(basename(export_statefile_path))
#             else
#                 statefile64 = base64encode() do io
#                     Pluto.pack(io, state)
#                 end

#                 "\"data:;base64,$(statefile64)\""
#             end


#             html_contents = generate_html(; 
#                 notebookfile_js=notebookfile_js, statefile_js=statefile_js,
#                 slider_server_url_js=slider_server_url_js, binder_url_js=binder_url_js,
#                 disable_ui=disable_ui
#             )

#             write(export_html_path, html_contents)
            
#             if (var"we need the .jl file" = offer_binder) || 
#                 (var"the .jl file is already there and might have changed" = isfile(export_jl_path))
#                 write(export_jl_path, jl_contents)
#             end

#             @info "Written to $(export_html_path)"
#         catch e
#             @error "$path failed to run" exception=(e, catch_backtrace())
#         end
#     end
#     @info "All notebooks processed"
# end


function generate_html(;
        version=nothing, 
        notebookfile_js="undefined", statefile_js="undefined", 
        slider_server_url_js="undefined", binder_url_js="undefined", 
        disable_ui=true
    )::String

    original = read(Pluto.project_relative_path("frontend", "editor.html"), String)

    if version isa Nothing
        version = try_get_pluto_version()
    end

    cdn_root = "https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@$(string(version))/frontend/"

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