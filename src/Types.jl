module Types
    import Pluto: Pluto, Token, Notebook
    export NotebookSession, RunningNotebookSession, QueuedNotebookSession, FinishedNotebookSession
    ###
    # SESSION DEFINITION
    
    abstract type NotebookSession end
    
    Base.@kwdef struct RunningNotebookSession <: NotebookSession
        path::String
        current_hash::String
        notebook::Pluto.Notebook
        original_state
        token::Token=Token()
        bond_connections::Dict{Symbol,Vector{Symbol}}
    end
    
    Base.@kwdef struct QueuedNotebookSession <: NotebookSession
        path::String
        current_hash::String
    end
    
    Base.@kwdef struct FinishedNotebookSession <: NotebookSession
        path::String
        current_hash::String
        original_state
    end
end