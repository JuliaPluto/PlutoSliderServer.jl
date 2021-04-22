abstract type NotebookSession end

import Pluto:Token

Base.@kwdef struct RunningNotebookSession <: NotebookSession
    path::String
    hash::String
    notebook::Pluto.Notebook
    original_state
    token::Token = Token()
    bond_connections::Dict{Symbol,Vector{Symbol}}
end

Base.@kwdef struct QueuedNotebookSession <: NotebookSession
    path::String
    hash::String
end

Base.@kwdef struct FinishedNotebookSession <: NotebookSession
    path::String
    hash::String
    original_state
end
