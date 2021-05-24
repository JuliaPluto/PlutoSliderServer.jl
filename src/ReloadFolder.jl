using FromFile
@from "./Actions.jl" using Actions: Actions, path_hash
@from "./Types.jl" using Types: Types, PlutoDeploySettings, withlock, get_configuration
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

reload(args...; kwargs...) = while reloadonce(args...; kwargs...); end

function reloadonce(notebook_sessions, server_session; 
        settings::PlutoDeploySettings,
        shutdown_after_completed::Bool=false,
    )
    enter, update, exit = d3join(
        notebook_sessions,
        setdiff(find_notebook_files_recursive(settings.SliderServer.start_dir), settings.SliderServer.exclude)
    )

    withlock(notebook_sessions) do
        @info "to start" enter
        @info "to re-run" update
        @info "to stop" exit

        filter_sessions!(!occursin(exit), notebook_sessions, server_session)

        local path, sesh, jl_contents, original_state
        local did_update = false, did_enter = false
        if !isempty(update)
            path = first(update)

            sesh, jl_contents, original_state = renew_session!(notebook_sessions, server_session, path; settings)
            if path ∉ settings.Export.exclude
                generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
            end
            did_update = true
        elseif !isempty(enter)
            path = first(enter)

            sesh, jl_contents, original_state = add_to_session!(
                notebook_sessions, server_session, path;
                settings, 
                shutdown_after_completed, 
                start_dir=settings.SliderServer.start_dir
            )
            if path ∉ settings.Export.exclude
                generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
            end
            did_enter = true
        end

         
        did_something = did_update || did_enter

        if did_something
            ready = did_update + length(notebook_sessions) - length(update)
            total = length(enter) + length(notebook_sessions)

            @info "[$(ready)/$(total)]  Ready $(path)" sesh.hash
        end


        # Create index!
        # running_sessions = filter(notebook_sessions) do sesh
        #     sesh isa RunningNotebookSession
        # end
        # running_paths = map(s -> s.path, running_sessions)
        # if settings.SliderServer.serve_static_export_folder && settings.Export.create_index
        #     write(joinpath(settings.Export.output_dir, "index.html"), default_index((
        #         without_pluto_file_extension(path) => without_pluto_file_extension(path) * ".html"
        #         for path in running_paths
        #     )))
        #     @info "Wrote index to" settings.Export.output_dir
        # end


        return need_to_run_again = length(update) + length(enter) > 1
    end
end