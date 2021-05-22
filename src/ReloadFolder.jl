using FromFile
@from "./Actions.jl" using Actions: Actions, path_hash
@from "./Types.jl" using Types: Types, withlock, get_configuration
@from "./FileHelpers.jl" import FileHelpers: find_notebook_files_recursive
@from "./Export.jl" import Export: default_index
import Pluto: without_pluto_file_extension

function d3join(notebook_sessions, new_paths)
    old_paths = map(s -> s.path, notebook_sessions)
    old_hashes = map(s -> s.hash, notebook_sessions)

    new_hashes = path_hash.(new_paths)

    (
        enter = setdiff(new_paths, old_paths),
        update = String[
            path for (i,path) in enumerate(old_paths)
            if path ∈ new_paths && old_hashes[i] !== new_hashes[i]
        ],
        exit = setdiff(old_paths, new_paths),
    )
end

function reload(notebook_sessions, server_session, settings)
    enter, update, exit = d3join(
        notebook_sessions,
        setdiff(find_notebook_files_recursive(settings.SliderServer.start_dir), settings.SliderServer.exclude)
    )

    withlock(notebook_sessions) do
        @info "to start" enter
        @info "to re-run" update
        @info "to stop" exit

        filter_sessions!(!occursin(exit), notebook_sessions, server_session)
        
        for path in update
            sesh, jl_contents, original_state = renew_session!(notebook_sessions, server_session, path; settings)
            if path ∉ settings.Export.exclude
                generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
            end
        end

        for path in enter
            sesh, jl_contents, original_state = add_to_session!(
                notebook_sessions, server_session, path;
                settings=settings, 
                shutdown_after_completed=false, 
                start_dir=settings.SliderServer.start_dir
            )
            if path ∉ settings.Export.exclude
                generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
            end
        end
        # Create index!
        running_sessions = filter(notebook_sessions) do sesh
            sesh isa RunningNotebookSession
        end
        running_paths = map(s -> s.path, running_sessions)
        if settings.SliderServer.serve_static_export_folder && settings.Export.create_index
            write(joinpath(settings.Export.output_dir, "index.html"), default_index((
                without_pluto_file_extension(path) => without_pluto_file_extension(path) * ".html"
                for path in running_paths
            )))
            @info "Wrote index to" settings.Export.output_dir
        end
    end
end