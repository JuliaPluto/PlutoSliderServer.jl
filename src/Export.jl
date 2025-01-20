import Pluto: Pluto, ServerSession
using HTTP
import Pkg
import Base64

export write_statefile

function write_statefile(path, state; verify::Bool=true)
    data = Pluto.pack(state)
    write(path, data)
    if verify
        local input_data, input_state
        try
            input_data = read(path)
            @assert input_data == data
            input_state = Pluto.unpack(input_data)
            # small sanity check
            s(x) = sort(collect(keys(x)); by=hash)
            @assert s(state) == s(input_state)
        catch e
            @error "The statefile was corrupted!" path

            if @isdefined(input_data)
                println(stderr)
                println(stderr, "Here is the statefile as I read it:")
                println(stderr, Base64.base64encode(input_data))
                println(stderr)
            end
            let
                println(stderr)
                println(stderr, "Here is the state as I wrote it:")
                println(stderr, Base64.base64encode(data))
                println(stderr)
            end
            if @isdefined(input_state)
                println(stderr)
                println(stderr, "Here is the state as I read it:")
                println(stderr, input_state)
                println(stderr)
            end

            rethrow(e)
        end
    end
end


## CACHE

export try_fromcache, try_tocache

cache_filename(cache_dir::String, current_hash::String) = joinpath(
    cache_dir,
    replace(
        HTTP.URIs.escapeuri(string(try_get_exact_pluto_version(), current_hash)),
        "." => "_",
    ) * ".plutostate",
)

function try_fromcache(cache_dir::String, current_hash::String)
    p = cache_filename(cache_dir, current_hash)
    if isfile(p)
        try
            open(Pluto.unpack, p, "r")
        catch e
            @warn "Failed to load statefile from cache" current_hash exception =
                (e, catch_backtrace())
        end
    end
end
try_fromcache(cache_dir::Nothing, current_hash) = nothing


function try_tocache(cache_dir::String, current_hash::String, state)
    mkpath(cache_dir)
    try
        write_statefile(cache_filename(cache_dir, current_hash), state)
    catch e
        @warn "Failed to write to cache file" current_hash exception =
            (e, catch_backtrace())
    end
end
try_tocache(cache_dir::Nothing, current_hash, state) = nothing



## FINDING THE PLUTO VERSION

const found_pluto_version = Ref{Any}(nothing)

function try_get_exact_pluto_version()
    if found_pluto_version[] !== nothing
        return found_pluto_version[]
    end
    found_pluto_version[] = try
        deps = Pkg.API.dependencies()

        p_index = findfirst(p -> p.name == "Pluto", deps)
        p = deps[p_index]

        if p.is_tracking_registry
            p.version
        elseif p.is_tracking_path
            error(
                "Do not add the Pluto dependency as a local path, but by specifying its VERSION or an exact COMMIT SHA.",
            )
        else
            # ugh
            is_probably_a_commit_thing =
                all(in(('0':'9') ∪ ('a':'f')), p.git_revision) &&
                length(p.git_revision) ∈ (8, 40)
            if !is_probably_a_commit_thing
                error(
                    "Do not add the Pluto dependency by specifying its BRANCH, but by specifying its VERSION or an exact COMMIT SHA.",
                )
            end

            p.git_revision
        end
    catch e
        if get(ENV, "HIDE_PLUTO_EXACT_VERSION_WARNING", "false") == "false"
            @error "Failed to get exact Pluto version from dependency. Your website is not guaranteed to work forever." exception =
                (e, catch_backtrace()) maxlog = 1
        end
        Pluto.PLUTO_VERSION
    end
end

