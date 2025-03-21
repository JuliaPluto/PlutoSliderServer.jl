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


function get_bond_setting_stages(
    remaining_keys::Union{Vector{Symbol},Set{Symbol}},
    notebook,
)
    isempty(remaining_keys) && return Set{Symbol}[]

    in_this_stage = Set{Symbol}()

    for k in remaining_keys
        where_as = PlutoDependencyExplorer.where_assigned(notebook.topology, Set([k]))

        # TODO: this line is the perf bottleneck. Can be optimized by:
        # - Making it return an iterator
        # - Memoizing this entire function
        downstreams =
            Pluto.MoreAnalysis.downstream_recursive(notebook, notebook.topology, where_as)

        is_not_at_the_front = any(downstreams) do down_cell
            def = notebook.topology.nodes[down_cell].definitions

            !disjoint(setdiff(remaining_keys, (k,)), def)
        end

        if !is_not_at_the_front
            push!(in_this_stage, k)
        end
    end

    return [
        get_bond_setting_stages(setdiff(remaining_keys, in_this_stage), notebook)...,
        in_this_stage,
    ]
end

disjoint(a, b) = !any(x in a for x in b)