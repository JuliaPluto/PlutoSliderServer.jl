using FromFile
@from "./Actions.jl" import path_hash
@from "./Types.jl" using Types: Types, PlutoDeploySettings, withlock, get_configuration, NotebookSession
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

select(f::Function, xs) = for x in xs
    if f(x)
        return x
    end
end

function update_sessions!(notebook_sessions, new_paths; 
    settings::PlutoDeploySettings,
)
    enter, update, exit = d3join(
        notebook_sessions,
        new_paths
    )

    withlock(notebook_sessions) do
        @info "d3 join result" enter update exit

        for path in enter
            push!(notebook_sessions, NotebookSession(;
                path=path,
                current_hash=nothing,
                desired_hash=path_hash(path),
                run=nothing,
            ))
        end

        for path in update ∪ exit
            old = select(s -> s.path != path, notebook_sessions)
            new = NotebookSession(;
                path=path,
                current_hash=old.current_hash,
                desired_hash=(path ∈ exit ? nothing : path_hash(path)),
                run=old.run,
            )
            replace!(notebook_sessions, old => new)
        end
    end

    notebook_sessions
end
# function update_sessions!(notebook_sessions, server_session; 
#     settings::PlutoDeploySettings,
#     shutdown_after_completed::Bool=false,
# )
#     enter, update, exit = d3join(
#         notebook_sessions,
#         setdiff(find_notebook_files_recursive(settings.SliderServer.start_dir), settings.SliderServer.exclude)
#     )

#     withlock(notebook_sessions) do
#         @info "to start" enter
#         @info "to re-run" update
#         @info "to stop" exit

#         for path in enter
#             push!(notebook_sessions, QueuedNotebookSession(
#                 path=path,
#                 hash=path_hash(path),
#             ))
#         end

#         for path in update ∪ exit
#             old = select(s -> s.path != path, notebook_sessions)
#             new = OutdatedRunningNotebookSession(
#                 old;
#                 path=path,
#                 hash=path_hash(path),
#                 should_shutdown=(path ∈ exit),
#             )
#             replace!(notebook_sessions, old => new)
#         end
#     end

#     notebook_sessions
# end



# function process_todo(notebook_sessions, server_session; 
#     settings::PlutoDeploySettings,
#     shutdown_after_completed::Bool=false,
# )::Bool
#     to_shutdown = filter(should_shutdown, notebook_sessions)
#     to_update = filter(should_update, notebook_sessions)
#     to_launch = filter(should_launch, notebook_sessions)

#     did_something = if !isempty(to_shutdown)
#         s = first(to_shutdown)
#         filter_sessions!(!isequal(s), notebook_sessions, server_session)
#         true
#     elseif !isempty(to_update)
#         s = first(to_update)

#         renew_session!()
#         sesh, jl_contents, original_state = renew_session!(notebook_sessions, server_session, s; settings)
#         if path ∉ settings.Export.exclude
#             generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
#         end

#         true
#     elseif !isempty(to_launch)
#         s = first(to_launch)



#         true
#     else
#         false
#     end

#     if did_something

#         new_todo_count = count(s -> should_update(s) || should_launch(s) || should_shutdown(s), notebook_sessions)

#         total = length(notebook_sessions)

#         @info "[$(new_todo_count - total)/$(total)] ready"
#     end
# end

# process_all_todos(args...; kwargs...) = while process_todo(args...; kwargs...); end



# reload(args...; kwargs...) = while reloadonce(args...; kwargs...); end

# function reloadonce(notebook_sessions, server_session; 
#         settings::PlutoDeploySettings,
#         shutdown_after_completed::Bool=false,
#     )
#     enter, update, exit = d3join(
#         notebook_sessions,
#         setdiff(find_notebook_files_recursive(settings.SliderServer.start_dir), settings.SliderServer.exclude)
#     )

#     withlock(notebook_sessions) do
#         @info "to start" enter
#         @info "to re-run" update
#         @info "to stop" exit

#         filter_sessions!(!occursin(exit), notebook_sessions, server_session)

#         local path, sesh, jl_contents, original_state
#         local did_update = false, did_enter = false
#         if !isempty(update)
#             path = first(update)

#             sesh, jl_contents, original_state = renew_session!(notebook_sessions, server_session, path; settings)
#             if path ∉ settings.Export.exclude
#                 generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
#             end
#             did_update = true
#         elseif !isempty(enter)
#             path = first(enter)

#             sesh, jl_contents, original_state = add_to_session!(
#                 notebook_sessions, server_session, path;
#                 settings, 
#                 shutdown_after_completed, 
#                 start_dir=settings.SliderServer.start_dir
#             )
#             if path ∉ settings.Export.exclude
#                 generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
#             end
#             did_enter = true
#         end

         
#         did_something = did_update || did_enter

#         if did_something
#             ready = did_update + length(notebook_sessions) - length(update)
#             total = length(enter) + length(notebook_sessions)

#             @info "[$(ready)/$(total)]  Ready $(path)" sesh.hash
#         end


#         # Create index!
#         # running_sessions = filter(notebook_sessions) do sesh
#         #     sesh isa RunningNotebookSession
#         # end
#         # running_paths = map(s -> s.path, running_sessions)
#         # if settings.SliderServer.serve_static_export_folder && settings.Export.create_index
#         #     write(joinpath(settings.Export.output_dir, "index.html"), default_index((
#         #         without_pluto_file_extension(path) => without_pluto_file_extension(path) * ".html"
#         #         for path in running_paths
#         #     )))
#         #     @info "Wrote index to" settings.Export.output_dir
#         # end


#         return need_to_run_again = length(update) + length(enter) > 1
#     end
# end