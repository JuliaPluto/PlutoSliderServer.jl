import Pluto
using Base64
using OrderedCollections
using FromFile
import HTTP.URIs
import Random
import Statistics
using Distributions
import Markdown

# @from "../MoreAnalysis.jl" import bound_variable_connections_graph
@from "../Types.jl" import NotebookSession, RunningNotebook
@from "../Configuration.jl" import PlutoDeploySettings
@from "../run_bonds.jl" import run_bonds_get_patches

@from "./types.jl" import VariableGroupPossibilities, PrecomputedSampleReport, Reason


function variable_groups(
    connections;
    pluto_session::Pluto.ServerSession,
    notebook::Pluto.Notebook,
)::Vector{VariableGroupPossibilities}
    VariableGroupPossibilities[
        let
            names = sort(variable_group)

            not_available = Dict{Symbol,Reason}()

            possible_values = [
                let
                    result = try
                        Pluto.possible_bond_values(
                            pluto_session::Pluto.ServerSession,
                            notebook::Pluto.Notebook,
                            n::Symbol,
                        )
                    catch e
                        Symbol("Failed ", string(e))
                    end
                    if result isa Symbol
                        # @error "Failed to get possible values for $(n)" result
                        not_available[n] = result
                        []
                    else
                        result
                    end
                end for n in names
            ]

            VariableGroupPossibilities(;
                names=names,
                possible_values=possible_values,
                not_available=not_available,
                num_possibilities=prod(BigInt.(length.(possible_values))),
            )
        end for variable_group in Set(values(connections))
    ]
end


function combination_iterator(group::VariableGroupPossibilities)
    Iterators.map(Iterators.product(group.possible_values...)) do combination
        bonds_dict = OrderedDict{Symbol,Any}(
            n => OrderedDict{String,Any}("value" => v) for
            (n, v) in zip(group.names, combination)
        )

        return (combination, bonds_dict)
    end
end

biglength(pr::Iterators.ProductIterator) = prod(BigInt[biglength(i) for i in pr.iterators])
biglength(x) = BigInt(length(x))

function generate_precomputed_staterequests_report(
    groups::Vector{VariableGroupPossibilities},
    run::RunningNotebook;
    settings::PlutoDeploySettings,
    pluto_session::Pluto.ServerSession,
)::PrecomputedSampleReport
    map(groups) do group
        stat = if !isempty(group.not_available)
            Normal(0.0, 0.0)
        else
            iterator = combination_iterator(group)
            if isempty(iterator) || isempty(group.names)
                Normal(0.0, 0.0)
            else
                file_size_sample =
                    map(
                        rand(iterator, length(group.names) * 3),
                    ) do (combination, bonds_dict)

                        result = run_bonds_get_patches(pluto_session, run, bonds_dict)

                        if result !== nothing
                            length(Pluto.pack(result))
                        else
                            0
                        end
                    end .* biglength(iterator) # multiply by number of combinations to get an estimate of the total file size

                fit(Normal, file_size_sample)
            end
        end
        VariableGroupPossibilities(;
            names=group.names,
            possible_values=group.possible_values,
            num_possibilities=group.num_possibilities,
            not_available=group.not_available,
            file_size_sample_distribution=stat,
            settings,
        )
    end |> PrecomputedSampleReport
end


function generate_precomputed_staterequests(
    notebook_session::NotebookSession;
    settings::PlutoDeploySettings,
    pluto_session::Pluto.ServerSession,
    output_dir=".",
)

    sesh = notebook_session
    run = sesh.run
    connections = run.bond_connections
    current_hash = sesh.current_hash

    @assert run isa RunningNotebook

    mkpath(joinpath(output_dir, "bondconnections"))
    mkpath(joinpath(output_dir, "staterequest", URIs.escapeuri(current_hash)))

    bondconnections_path =
        joinpath(output_dir, "bondconnections", URIs.escapeuri(current_hash))
    write(bondconnections_path, Pluto.pack(run.bond_connections))
    @debug "Written bond connections to " bondconnections_path

    unanalyzed_groups = variable_groups(connections; pluto_session, notebook=run.notebook)

    report = generate_precomputed_staterequests_report(
        unanalyzed_groups,
        run;
        settings,
        pluto_session,
    )
    groups = report.groups

    if report.judgement.should_precompute_all
        @info "Notebook can be fully precomputed!" report
    else
        @warn "Notebook cannot be (fully) precomputed" report
    end

    foreach(groups) do group::VariableGroupPossibilities
        if group.judgement.should_precompute_all
            foreach(combination_iterator(group)) do (combination, bonds_dict)

                result = run_bonds_get_patches(pluto_session, run, bonds_dict)

                if result !== nothing
                    write_path = joinpath(
                        output_dir,
                        "staterequest",
                        URIs.escapeuri(current_hash),
                        Pluto.pack(bonds_dict) |> base64encode |> URIs.escapeuri,
                    )

                    write(write_path, Pluto.pack(result))

                    @debug "Written state request to " write_path values =
                        (; (zip(group.names, combination))...)
                end
            end
        end
    end
end