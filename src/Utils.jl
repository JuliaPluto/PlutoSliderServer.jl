module Utils

export add_to_session!, remove_from_session!

using Base64
using SHA
import Pluto

import PlutoSliderServer:generate_html

include("./Settings.jl")
using .Settings

include("./MoreAnalysis.jl")
using .MoreAnalysis
include("./NotebookSession.jl")

include("./Export.jl")
include("./FileHelpers.jl")
import .FileHelpers:generate_static_export
import .Export: try_fromcache, try_tocache, default_index

showall(xs) = Text(join(string.(xs),"\n"))
pluto_version = Export.try_get_exact_pluto_version()

myhash = base64encode ∘ sha256

function path_hash(path)
    myhash(read(path))
end



function add_to_session!(server_session, notebook_sessions, path, settings, pluto_options)
    # Panayiotis: Can we re-set pluto_options???
    hash = path_hash(path) # Before running!
    hindex = findfirst(s -> s.hash == hash, notebook_sessions)
    keep_running = path ∉ settings.SliderServer.exclude
    skip_cache = keep_running || path ∈ settings.Export.ignore_cache

    cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, hash)
    if cached_state !== nothing
        @info "Loaded from cache, skipping notebook run" hash
        original_state = cached_state
    else
        try
            # open and run the notebook (TODO: tell pluto not to write to the notebook file)
            notebook = Pluto.SessionActions.open(server_session, path; run_async=false)
            # get the state object
            original_state = Pluto.notebook_to_js(notebook)
            # shut down the notebook (later)
            try_tocache(settings.Export.cache_dir, hash, original_state)
            if keep_running
                bond_connections = MoreAnalysis.bound_variable_connections_graph(notebook)
                @info "Bond connections" showall(collect(bond_connections))
                session = RunningNotebookSession(;
                    path=path,
                    hash=hash,
                    notebook=notebook, 
                    original_state=original_state, 
                    bond_connections=bond_connections,
                )
                push!(notebook_sessions, session)
            else 
                @info "Shutting down notebook process"
                Pluto.SessionActions.shutdown(server_session, notebook)
                session = FinishedNotebookSession(;
                    path=path,
                    hash=path_hash(path),
                    original_state=original_state, 
                )
            end
            if isnothing(hindex)
                push!(notebook_sessions, session)
            else
                notebook_sessions[hindex] = session
            end
        catch e
            (e isa InterruptException) || rethrow(e)
            @error "Failed to run notebook!" path exception = (e, catch_backtrace())
            return
        end
    end
    if !isnothing(settings.Export.output_dir)
        generate_static_export(path, settings)
    end
end

function remove_from_session!(server_session, notebook_sessions, hash)
    i = findfirst(notebook_sessions) do sesh
        sesh.hash === hash
    end
    if i === nothing
        @warn hash "Don't stop anything"
        return
    end
    sesh = notebook_sessions[i]
    Pluto.SessionActions.shutdown(server_session, sesh.notebook)
    notebook_sessions[i] = FinishedNotebookSession(;
        sesh.path,
        sesh.hash,
        sesh.original_state,
    )
end

end