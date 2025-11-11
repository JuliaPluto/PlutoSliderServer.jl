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
    explicits::Union{Nothing,Set{Symbol}},
)
    notebook = run.notebook

    names::Vector{Symbol} = Symbol.(keys(bonds))
    # "explicits" defaults to "all bonds"
    explicits = @something(explicits, Set(names))
    
    names_original = names
    names =
        begin
            # REMOVE ALL NAMES that depend on 
            # an explicit bond
            # 
            # Because its new value might no longer be valid.
            # 
            # For exaxmple:
            # @bind xx Slider(1:100)
            # @bind yy Slider(xx:100)
            # 
            # (ignore bond transformatinos for now)
            # 
            # The sliders will be set on (1,1) initially.
            # The user moves the first slider, giving (10,1).
            # The value for `y` will be sent, but this should be ignored. Because it was generated from an outdated bond.
            
            first_layer = PlutoDependencyExplorer.where_referenced(
                notebook.topology,
                explicits,
            )
            
            next_layers = Pluto.MoreAnalysis.downstream_recursive(
                notebook.topology,
                first_layer,
            )

            # all cells that depend on an explicit bond
            cells_depending_on_explicits = union!(first_layer, next_layers)

            # remove any variable `n` from `names` if...
            filter(names) do n
                !(
                    # ...`n` depends on an explicit bond.
                    any(cells_depending_on_explicits) do c
                        n in notebook.topology.nodes[c].definitions
                    end
                )
            end
        end
        
    t35 = time()
        
        
    id(c) = c.cell_id

    @debug "Analysis" names names_original id.(cells_depending_on_explicits)
    
    new_state = withtoken(sesh.run.token) do
        try
            # Set the bond values. We don't need to merge dicts here because the old bond values will never be used.
            notebook.bonds = bonds
            
            # Run the bonds!
            topological_order = Pluto.set_bond_values_reactive(
                session=server_session,
                notebook=notebook,
                bound_sym_names=names,
                is_first_values=[false for _n in names], # because requests should be stateless. We might want to do something special for the (actual) initial request (containing every initial bond value) in the future.
                run_async=false,
            )::Pluto.TopologicalOrder

            @debug "Finished running!" length(topological_order.runnable)
            
            Pluto.notebook_to_js(notebook)
        catch e
            @error "Failed to set bond values" exception = (e, catch_backtrace())
            nothing
        end
    end
    new_state === nothing && return (
        HTTP.Response(500, "Failed to set bond values") |>
        with_cors! |>
        with_not_cacheable!
    )
    
    t4 = time()

    # We only want to send state updates about...
    function only_relevant(state)
        new = copy(state)
        # ... the cells that just ran and ...
        new["cell_results"] = filter(state["cell_results"]) do (id, cell_state)
            id ∈ (c.cell_id for c in cells_depending_on_explicits)
        end
        # ... nothing about bond values, because we don't want to synchronize among clients. and...
        delete!(new, "bonds")
        # ... we ignore changes to the status tree caused by a running bonds.
        delete!(new, "status_tree")
        new
    end

    patches = let
        notebook_patches = Firebasey.diff(
            only_relevant(sesh.run.original_state),
            only_relevant(new_state),
        )

        # Remove bonds that depend on explicit bonds. Because this means that the bond was re-created during this run, and its value must be reset,
        bond_patches = [
            Firebasey.RemovePatch(["bonds", string(k)]) for
            k in keys(bonds) if k ∉ names
        ]

        @debug "patches" notebook_patches bond_patches

        union!(notebook_patches, bond_patches)
    end
    
    return (;
        patches,
        t35,
        t4,
    )
end
