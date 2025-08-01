using FromFile

import JSON
import Pluto: Pluto, without_pluto_file_extension

@from "./Types.jl" import NotebookSession, RunningNotebook
@from "./Configuration.jl" import PlutoDeploySettings

@from "./PathUtils.jl" import to_local_path, to_url_path

id(s::NotebookSession) = to_url_path(s.path)

function index_json_data(
    s::NotebookSession;
    settings::PlutoDeploySettings,
    start_dir::AbstractString,
)
    (
        id=id(s),
        hash=s.current_hash,
        html_path=to_url_path(without_pluto_file_extension(s.path) * ".html"),
        statefile_path=settings.Export.baked_state ? nothing :
                       to_url_path(without_pluto_file_extension(s.path) * ".plutostate"),
        notebookfile_path=settings.Export.baked_notebookfile ? nothing : to_url_path(s.path),
        current_hash=s.current_hash,
        desired_hash=s.desired_hash,
        frontmatter=merge(
            Dict{String,Any}(
                # default title if none given in frontmatter
                "title" => basename(without_pluto_file_extension(s.path)),
            ),
            Pluto.frontmatter(
                # Pluto.frontmatter accepts either a Notebook, or a path (in which case it will parse the file).
                if s.run isa RunningNotebook
                    s.run.notebook
                else
                    joinpath(start_dir, to_local_path(s.path))
                end;
                raise=false,
            ),
        ),
    )
end


function index_json_data(
    sessions::Vector{NotebookSession};
    settings::PlutoDeploySettings,
    start_dir::AbstractString,
    config_data::Dict{String,Any},
)
    (
        notebooks=Dict(id(s) => index_json_data(s; settings, start_dir) for s in sessions),
        pluto_version=lstrip(Pluto.PLUTO_VERSION_STR, 'v'),
        julia_version=lstrip(string(VERSION), 'v'),
        format_version="1",
        # 
        title=get(config_data, "title", nothing),
        description=get(config_data, "description", nothing),
        collections=get(config_data, "collections", nothing),
        # collections=let c = settings.Export.collections
        #     c === nothing ? nothing : [
        #     v for (k,v) in sort(pairs(c); by=((k,v)) -> parse(Int, k))
        # ],
        binder_url=settings.Export.offer_binder ?
                   something(settings.Export.binder_url, Pluto.default_binder_url) :
                   nothing,
        slider_server_url=somethingornothing(
            settings.Export.slider_server_url,
            settings.SliderServer.enabled ? "." : nothing,
        ),
    )
end

function generate_index_json(
    sessions::Vector{NotebookSession};
    settings::PlutoDeploySettings,
    start_dir::AbstractString,
)
    p = joinpath(start_dir, "pluto_export_configuration.json")
    config_data = if isfile(p)
        JSON.parse(read(p, String))::Dict{String,Any}
    else
        Dict{String,Any}()
    end
    result = index_json_data(sessions; settings, start_dir, config_data)
    JSON.json(result)
end

somethingornothing() = nothing
somethingornothing(x::Nothing, y...) = somethingornothing(y...)
somethingornothing(x::Any, y...) = x
