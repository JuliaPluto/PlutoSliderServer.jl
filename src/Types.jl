using Configurations
import Pluto: Pluto, Token, Notebook
export NotebookSession,
    SliderServerSettings, ExportSettings, PlutoDeploySettings, get_configuration
using TerminalLoggers: TerminalLogger

###
# SESSION DEFINITION

abstract type RunResult end

Base.@kwdef struct RunningNotebook <: RunResult
    path::String
    notebook::Pluto.Notebook
    original_state::Any
    token::Token = Token()
    bond_connections::Dict{Symbol,Vector{Symbol}}
end
Base.@kwdef struct FinishedNotebook <: RunResult
    path::String
    original_state::Any
end

"""
Represents a notebook tracked by the slider server.

`path` stores the notebook location relative to the root directory using
forward slashes (`/`), independent of the host OS. Use `to_local_path` to
convert it before joining with the start directory.
"""
Base.@kwdef struct NotebookSession{
    C<:Union{Nothing,String},
    D<:Union{Nothing,String},
    R<:Union{Nothing,RunResult},
}
    path::String
    current_hash::C
    desired_hash::D
    run::R
end
