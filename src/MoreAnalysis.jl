import Pluto
import Pluto: Cell, Notebook, NotebookTopology, ExpressionExplorer, ServerSession
import PlutoDependencyExplorer

# TODO: this should use the function from Pluto.jl
# the difference is that this one uses Pluto.get_bond_names(session, notebook) which is more accurate than getting it from the topology only.


"Return a `Dict{Symbol,Vector{Symbol}}` where the _keys_ are the bound variables of the notebook.

For each key (a bound symbol), the value is the list of (other) bound variables whose values need to be known to compute the result of setting the bond."
function bound_variable_connections_graph(
    session::ServerSession,
    notebook::Notebook,
)::Dict{Symbol,Vector{Symbol}}
    topology = notebook.topology
    bound_variables = Pluto.get_bond_names(session, notebook)
    Dict{Symbol,Vector{Symbol}}(
        var => let
            cells = Pluto.MoreAnalysis.codependents(notebook, topology, var)
            defined_there = union!(
                Set{Symbol}(),
                (topology.nodes[c].definitions for c in cells)...,
            )
            # Set([var]) ∪ 
            collect((defined_there ∩ bound_variables))
        end for var in bound_variables
    )
end
