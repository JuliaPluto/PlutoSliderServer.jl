using FromFile
@from "./PlutoHash.jl" import plutohash_contents
@from "./Types.jl" import NotebookSession
@from "./Configuration.jl" import PlutoDeploySettings, get_configuration
@from "./FileHelpers.jl" import find_notebook_files_recursive
import Pluto: without_pluto_file_extension

function d3join(notebook_sessions, new_paths; start_dir::AbstractString)

    desired_notebook_sessions = filter(s -> s.desired_hash !== nothing, notebook_sessions)

    old_paths = map(s -> s.path, desired_notebook_sessions)
    old_hashes = map(s -> s.current_hash, desired_notebook_sessions)

    new_hashes = map(old_paths) do path
        abs_path = joinpath(start_dir, path)
        isfile(abs_path) ? plutohash_contents(abs_path) : nothing
    end

    (
        enter=setdiff(new_paths, old_paths),
        update=String[
            path for (i, path) in enumerate(old_paths) if
            path ∈ new_paths && old_hashes[i] !== new_hashes[i]
        ],
        exit=setdiff(old_paths, new_paths),
    )
end

select(f::Function, xs) =
    for x in xs
        if f(x)
            return x
        end
    end

function update_sessions!(notebook_sessions, new_paths; start_dir::AbstractString)::Bool
    added, updated, removed = d3join(notebook_sessions, new_paths; start_dir)

    if any(!isempty, [added, updated, removed])
        @info "Notebook list updated" added updated removed

        for path in added
            push!(
                notebook_sessions,
                NotebookSession(;
                    path=path,
                    current_hash=nothing,
                    desired_hash=plutohash_contents(joinpath(start_dir, path)),
                    run=nothing,
                ),
            )
        end

        for path in updated ∪ removed
            old = select(s -> s.path == path, notebook_sessions)
            @assert old !== nothing
            new = NotebookSession(;
                path=path,
                current_hash=old.current_hash,
                desired_hash=(
                    path ∈ removed ? nothing :
                    plutohash_contents(joinpath(start_dir, path))
                ),
                run=old.run,
            )
            replace!(notebook_sessions, old => new)
        end

        false
    else
        true
    end
end

