import Pluto
import Pluto: Cell, Notebook, NotebookTopology, ExpressionExplorer, ServerSession


"Return the given cells, and all cells that depend on them (recursively)."
function downstream_recursive(
    notebook::Notebook,
    topology::NotebookTopology,
    from::Union{Vector{Cell},Set{Cell}},
)
    found = Set{Cell}(copy(from))
    downstream_recursive!(found, notebook, topology, from)
    found
end

function downstream_recursive!(
    found::Set{Cell},
    notebook::Notebook,
    topology::NotebookTopology,
    from::Vector{Cell},
)
    for cell in from
        one_down = Pluto.where_referenced(notebook, topology, cell)
        for next in one_down
            if next ∉ found
                push!(found, next)
                downstream_recursive!(found, notebook, topology, Cell[next])
            end
        end
    end
end




"Return all cells that are depended upon by any of the given cells."
function upstream_recursive(
    notebook::Notebook,
    topology::NotebookTopology,
    from::Union{Vector{Cell},Set{Cell}},
)
    found = Set{Cell}(copy(from))
    upstream_recursive!(found, notebook, topology, from)
    found
end

function upstream_recursive!(
    found::Set{Cell},
    notebook::Notebook,
    topology::NotebookTopology,
    from::Vector{Cell},
)
    for cell in from
        references = topology.nodes[cell].references
        for upstream in Pluto.where_assigned(notebook, topology, references)
            if upstream ∉ found
                push!(found, upstream)
                upstream_recursive!(found, notebook, topology, Cell[upstream])
            end
        end
    end
end

"All cells that can affect the outcome of changing the given variable."
function codependents(notebook::Notebook, topology::NotebookTopology, var::Symbol)
    assigned_in = filter(notebook.cells) do cell
        var ∈ topology.nodes[cell].definitions
    end

    downstream = collect(downstream_recursive(notebook, topology, assigned_in))

    downupstream = upstream_recursive(notebook, topology, downstream)
end

"Return a `Dict{Symbol,Vector{Symbol}}` where the _keys_ are the bound variables of the notebook.

For each key (a bound symbol), the value is the list of (other) bound variables whose values need to be known to compute the result of setting the bond."
function bound_variable_connections_graph(session::ServerSession, notebook::Notebook)::Dict{Symbol,Vector{Symbol}}
    topology = notebook.topology
    bound_variables = Pluto.get_bond_names(session, notebook)
    Dict{Symbol,Vector{Symbol}}(
        var => let
            cells = codependents(notebook, topology, var)
            defined_there = union!(
                Set{Symbol}(),
                (topology.nodes[c].definitions for c in cells)...,
            )
            # Set([var]) ∪ 
            collect((defined_there ∩ bound_variables))
        end for var in bound_variables
    )
end
