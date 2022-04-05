using FromFile

import JSON
import Pluto: Pluto, without_pluto_file_extension

@from "./Types.jl" import NotebookSession, RunningNotebook
@from "./Configuration.jl" import PlutoDeploySettings

id(s::NotebookSession) = s.path

function json_data(
    s::NotebookSession;
    settings::PlutoDeploySettings,
    start_dir::AbstractString,
)
    (
        id=id(s),
        hash=s.current_hash,
        html_path=without_pluto_file_extension(s.path) * ".html",
        statefile_path=settings.Export.baked_state ? nothing :
                       without_pluto_file_extension(s.path) * ".plutostate",
        notebookfile_path=settings.Export.baked_notebookfile ? nothing : s.path,
        current_hash=s.current_hash,
        desired_hash=s.desired_hash,
        frontmatter=merge(
            Dict{String,Any}("title" => basename(without_pluto_file_extension(s.path))),
            try
                Pluto.frontmatter(joinpath(start_dir, s.path))
            catch e
                @error "Frontmatter error" exception = (e, catch_backtrace())
                Dict{String,Any}()
            end,
        ),
    )
end


function json_data(
    sessions::Vector{NotebookSession};
    settings::PlutoDeploySettings,
    start_dir::AbstractString,
)
    (
        notebooks=Dict(id(s) => json_data(s; settings, start_dir) for s in sessions),
        collections=[], # TODO
        pluto_version=lstrip(Pluto.PLUTO_VERSION_STR, 'v'),
        julia_version=lstrip(string(VERSION), 'v'),
        format_version="1",
    )
end

generate_index_json(s; kwargs...) = JSON.json(json_data(s; kwargs...))