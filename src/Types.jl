module Types

import Pluto: Token, Notebook

export NotebookSession, RunningNotebookSession, QueuedNotebookSession, FinishedNotebookSession

abstract type NotebookSession end


Base.@kwdef struct RunningNotebookSession <: NotebookSession
    path::String
    hash::String
    notebook::Notebook
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

end