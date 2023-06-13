import Pluto:
    Pluto, without_pluto_file_extension, generate_html, @asynclog, withtoken, Firebasey
using Base64
using SHA
using FromFile

@from "./Types.jl" import RunningNotebook

function run_bonds_get_patches(
    server_session::Pluto.ServerSession,
    run::RunningNotebook,
    bonds::AbstractDict{Symbol,<:Any},
)::Union{AbstractDict{String,Any},Nothing}

    notebook = run.notebook

    topological_order, new_state = withtoken(run.token) do
        try
            notebook.bonds = bonds

            names::Vector{Symbol} = Symbol.(keys(bonds))

            topological_order = Pluto.set_bond_values_reactive(
                session=server_session,
                notebook=notebook,
                bound_sym_names=names,
                is_first_values=[false for _n in names], # because requests should be stateless. We might want to do something special for the (actual) initial request (containing every initial bond value) in the future.
                run_async=false,
            )::Pluto.TopologicalOrder

            new_state = Pluto.notebook_to_js(notebook)

            topological_order, new_state
        catch e
            @error "Failed to set bond values" exception = (e, catch_backtrace())
            nothing, nothing
        end
    end
    if topological_order === nothing
        return nothing
    end

    ids_of_cells_that_ran = [c.cell_id for c in topological_order.runnable]

    @debug "Finished running!" length(ids_of_cells_that_ran)

    # We only want to send state updates about...
    function only_relevant(state)
        new = copy(state)
        # ... the cells that just ran and ...
        new["cell_results"] = filter(state["cell_results"]) do (id, cell_state)
            id ∈ ids_of_cells_that_ran
        end
        # ... nothing about bond values, because we don't want to synchronize among clients.
        new["bonds"] = Dict{String,Dict{String,Any}}()
        new
    end

    patches = Firebasey.diff(only_relevant(run.original_state), only_relevant(new_state))
    patches_as_dicts::Array{Dict} = Firebasey._convert(Array{Dict}, patches)

    Dict{String,Any}(
        "patches" => patches_as_dicts,
        "ids_of_cells_that_ran" => ids_of_cells_that_ran,
    )
end
