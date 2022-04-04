import JSON
import Pluto:
    Pluto,
    without_pluto_file_extension
    
@from "./Types.jl" import NotebookSession, RunningNotebook
@from "./Configuration.jl" import PlutoDeploySettings


function json_data(s::NotebookSession; settings::PlutoDeploySettings)
    (
        id=s.path,
        hash=s.current_hash,
        
        html_path=without_pluto_file_extension(s.path) * ".html",
        
        statefile_path=settings.Export.baked_state ? nothing : without_pluto_file_extension(s.path) * ".plutostate",
        notebookfile_path=settings.Export.baked_notebookfile ? nothing : s.path,
        
        current_hash=s.current_hash,
        desired_hash=s.desired_hash,
        
        frontmatter = merge(
            Dict{String,Any}(
                "title" => basename(without_pluto_file_extension(s.path)),
            ), 
            try
                Pluto.frontmatter(s.path)
            catch e
                @error "Frontmatter error" exception=(e,catch_backtrace())
                Dict{String,Any}()
            end
        )
    )
end


function index_json_data(sessions::Vector{NotebookSession}; settings::PlutoDeploySettings)
    (
        notebooks=[
            json_data(s; settings)
            for s in sessions
        ],
        collections=[],
        pluto_version=lstrip(Pluto.PLUTO_VERSION_STR, 'v'),
        julia_version=lstrip(string(VERSION), 'v'),
        format_version="1",
    )
end

function 