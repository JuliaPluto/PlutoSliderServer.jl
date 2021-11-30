import Pluto:
    Pluto, without_pluto_file_extension, generate_html, @asynclog, withtoken, Firebasey
using Base64
using SHA
using OrderedCollections
using FromFile
import HTTP.URIs
import Random
import Statistics
using Distributions
import Markdown

@from "./MoreAnalysis.jl" import bound_variable_connections_graph
@from "./Export.jl" import try_get_exact_pluto_version, try_fromcache, try_tocache
@from "./Types.jl" import NotebookSession, RunningNotebook, FinishedNotebook
@from "./Configuration.jl" import PlutoDeploySettings
@from "./FileHelpers.jl" import find_notebook_files_recursive
myhash = base64encode ∘ sha256
function path_hash(path)
    myhash(read(path))
end

showall(xs) = Text(join(string.(xs), "\n"))


###
# Shutdown
function process(
    s::NotebookSession{String,Nothing,<:Any};
    server_session::Pluto.ServerSession,
    settings::PlutoDeploySettings,
    output_dir::AbstractString,
    start_dir::AbstractString,
    progress,
)::NotebookSession


    if s.run isa RunningNotebook
        Pluto.SessionActions.shutdown(server_session, s.run.notebook)
    end

    try
        remove_static_export(s.path; settings, output_dir)
    catch e
        @warn "Failed to remove static export files" s.path exception =
            (e, catch_backtrace())
    end

    @info "### ✓ $(progress) Shutdown complete" s.path

    NotebookSession(; path=s.path, current_hash=nothing, desired_hash=nothing, run=nothing)
end

###
# Launch
function process(
    s::NotebookSession{Nothing,String,<:Any};
    server_session::Pluto.ServerSession,
    settings::PlutoDeploySettings,
    output_dir::AbstractString,
    start_dir::AbstractString,
    progress,
)::NotebookSession

    path = s.path
    abs_path = joinpath(start_dir, path)

    @info "###### ◐ $(progress) Launching..." s.path

    jl_contents = read(abs_path, String)
    new_hash = myhash(jl_contents)
    if new_hash != s.desired_hash
        @warn "Notebook file does not have desired hash. This probably means that the file changed too quickly. Continuing and hoping for the best!" s.path new_hash s.desired_hash
    end

    keep_running = settings.SliderServer.enabled || settings.Export.static_export_state
    skip_cache = keep_running || path ∈ settings.Export.ignore_cache

    cached_state = skip_cache ? nothing : try_fromcache(settings.Export.cache_dir, new_hash)

    run = if cached_state !== nothing
        @info "Loaded from cache, skipping notebook run" s.path new_hash
        original_state = cached_state
        FinishedNotebook(; path, original_state)
    else
        try
            # open and run the notebook
            notebook = Pluto.SessionActions.open(server_session, abs_path; run_async=false)
            # get the state object
            original_state = Pluto.notebook_to_js(notebook)
            # shut down the notebook
            if !keep_running
                @info "Shutting down notebook process" s.path
                Pluto.SessionActions.shutdown(server_session, notebook)
            end
            try_tocache(settings.Export.cache_dir, new_hash, original_state)
            if keep_running
                bond_connections = bound_variable_connections_graph(notebook)
                @info "Bond connections" s.path showall(collect(bond_connections))

                RunningNotebook(; path, notebook, original_state, bond_connections)
            else
                FinishedNotebook(; path, original_state)
            end
        catch e
            (e isa InterruptException) || rethrow(e)
            @error "$(progress) Failed to run notebook!" path exception =
                (e, catch_backtrace())
            # continue
            nothing
        end
    end

    generate_static_export(
        path,
        run.original_state,
        jl_contents;
        settings,
        start_dir,
        output_dir,
    )
    new_session = NotebookSession(;
        path=s.path,
        current_hash=new_hash,
        desired_hash=s.desired_hash,
        run=run,
    )
    if settings.Export.static_export_state
        generate_static_staterequests(
            new_session;
            settings,
            pluto_session=server_session,
            output_dir,
        )
        # TODO shutdown
    end

    @info "### ✓ $(progress) Ready" s.path new_hash

    new_session
end

###
# Update if needed
function process(
    s::NotebookSession{String,String,<:Any};
    server_session::Pluto.ServerSession,
    settings::PlutoDeploySettings,
    output_dir::AbstractString,
    start_dir::AbstractString,
    progress,
)::NotebookSession

    if s.current_hash != s.desired_hash
        @info "Updating notebook... will shut down and relaunch" s.path

        # Simple way to update: shut down notebook and start new one
        if s.run isa RunningNotebook
            Pluto.SessionActions.shutdown(server_session, s.run.notebook)
        end

        @info "Shutdown complete" s.path

        result = process(
            NotebookSession(;
                path=s.path,
                current_hash=nothing,
                desired_hash=s.desired_hash,
                run=nothing,
            );
            server_session,
            settings,
            output_dir,
            start_dir,
            progress,
        )

        result
    else
        s
    end
end

###
# Leave it shut down
process(s::NotebookSession{Nothing,Nothing,<:Any}; kwargs...)::NotebookSession = s


should_shutdown(::NotebookSession{String,Nothing,<:Any}) = true
should_shutdown(::NotebookSession) = false
should_update(s::NotebookSession{String,String,<:Any}) = s.current_hash != s.desired_hash
should_update(::NotebookSession) = false
should_launch(::NotebookSession{Nothing,String,<:Any}) = true
should_launch(::NotebookSession) = false

will_process(s) = should_update(s) || should_launch(s) || should_shutdown(s)


"""
Core Action: Generate static export for a Pluto Notebook

# Arguments:
1. slider_server_url: URL of the slider server. This will be the URL of your server, if you deploy
2. offer_binder: Flag to enable the Binder button
3. binder_url: URL of the binder link that will be invoked. Use a compatible pluto-enabled binder 
4. baked_state: Whether to export pluto state within the html or in a separate file.
5. pluto_cdn_root: URL where pluto will go to find the static frontend assets 
"""
function generate_static_export(
    path,
    original_state,
    jl_contents;
    settings,
    output_dir,
    start_dir,
)
    pluto_version = try_get_exact_pluto_version()
    export_jl_path = let
        relative_to_notebooks_dir = path
        joinpath(output_dir, relative_to_notebooks_dir)
    end
    export_html_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(path) * ".html"
        joinpath(output_dir, relative_to_notebooks_dir)
    end
    export_statefile_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(path) * ".plutostate"
        joinpath(output_dir, relative_to_notebooks_dir)
    end


    mkpath(dirname(export_jl_path))
    mkpath(dirname(export_html_path))
    mkpath(dirname(export_statefile_path))


    slider_server_running_somewhere =
        settings.Export.slider_server_url !== nothing ||
        (settings.SliderServer.serve_static_export_folder && settings.SliderServer.enabled)

    notebookfile_js = if settings.Export.offer_binder || slider_server_running_somewhere
        if settings.Export.baked_notebookfile
            "\"data:text/julia;charset=utf-8;base64,$(base64encode(jl_contents))\""
        else
            repr(basename(export_jl_path))
        end
    else
        "undefined"
    end
    slider_server_url_js = if slider_server_running_somewhere
        abs_path = joinpath(start_dir, path)
        url_of_root = relpath(start_dir, dirname(abs_path)) # e.g. "." or "../../.." 
        repr(something(settings.Export.slider_server_url, url_of_root))
    else
        "undefined"
    end
    binder_url_js = if settings.Export.offer_binder
        repr(something(settings.Export.binder_url, Pluto.default_binder_url))
    else
        "undefined"
    end
    statefile_js = if !settings.Export.baked_state
        open(export_statefile_path, "w") do io
            Pluto.pack(io, original_state)
        end
        repr(basename(export_statefile_path))
    else
        statefile64 = base64encode() do io
            Pluto.pack(io, original_state)
        end

        "\"data:;base64,$(statefile64)\""
    end

    html_contents = generate_html(;
        pluto_cdn_root=settings.Export.pluto_cdn_root,
        version=pluto_version,
        notebookfile_js,
        statefile_js,
        slider_server_url_js,
        binder_url_js,
        disable_ui=settings.Export.disable_ui,
    )
    write(export_html_path, html_contents)

    if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing) &&
       !settings.Export.baked_notebookfile
        write(export_jl_path, jl_contents)
    end

    @debug "Written to $(export_html_path)"
end

tryrm(x) = isfile(x) && rm(x)

function remove_static_export(path; settings, output_dir)
    export_jl_path = let
        relative_to_notebooks_dir = path
        joinpath(output_dir, relative_to_notebooks_dir)
    end
    export_html_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(path) * ".html"
        joinpath(output_dir, relative_to_notebooks_dir)
    end
    export_statefile_path = let
        relative_to_notebooks_dir = without_pluto_file_extension(path) * ".plutostate"
        joinpath(output_dir, relative_to_notebooks_dir)
    end


    if !settings.Export.baked_state
        tryrm(export_statefile_path)
    end
    tryrm(export_html_path)
    if (settings.Export.offer_binder || settings.Export.slider_server_url !== nothing) &&
       !settings.Export.baked_notebookfile
        tryrm(export_jl_path)
    end



end

function run_bonds_get_patch_info(
    server_session,
    notebook_session::NotebookSession,
    bonds::AbstractDict{Symbol,<:Any},
)::Union{AbstractDict{String,Any},Nothing}
    sesh = notebook_session

    notebook = sesh.run.notebook

    topological_order, new_state = withtoken(sesh.run.token) do
        try
            notebook.bonds = bonds

            names::Vector{Symbol} = Symbol.(keys(bonds))

            topological_order = Pluto.set_bond_values_reactive(
                session=server_session,
                notebook=notebook,
                bound_sym_names=names,
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

    patches =
        Firebasey.diff(only_relevant(sesh.run.original_state), only_relevant(new_state))
    patches_as_dicts::Array{Dict} = patches

    Dict{String,Any}(
        "patches" => patches_as_dicts,
        "ids_of_cells_that_ran" => ids_of_cells_that_ran,
    )
end

const Reason = Symbol

Base.@kwdef struct VariableGroupPossibilities
    names::Vector{Symbol}
    file_size_sample_statistics::Union{Nothing,Distribution} = nothing
    num_possibilities::Int64
    possible_values::Vector{Any}
    not_available::Dict{Symbol,Reason}
end

struct PrecomputedSampleReport
    groups::Vector{VariableGroupPossibilities}
end

# TODO
# - if one of the fields in the group has no possible values then we cant precompute anything, that should be displayed, but its actually cool that it works




function variable_groups(
    connections;
    pluto_session::Pluto.ServerSession,
    notebook::Pluto.Notebook,
)
    map(collect(Set(values(connections)))) do variable_group

        names = sort(variable_group)

        not_available = Dict{Symbol,Reason}()

        possible_values = [
            let
                result = Pluto.possible_bond_values(
                    pluto_session::Pluto.ServerSession,
                    notebook::Pluto.Notebook,
                    n::Symbol,
                )
                if result isa Symbol
                    # @error "Failed to get possible values for $(n)" result
                    not_available[n] = result
                    []
                else
                    result
                end
            end for n in names
        ]

        VariableGroupPossibilities(
            names=names,
            # file_size_sample_statistics=(
            #     Statistics.mean(file_size_sample),
            #     Statistics.stddev(file_size_sample),
            # ),
            num_possibilities=prod(Int64.(length.(possible_values))),
            possible_values=possible_values,
            not_available=not_available,
        )
    end
end


function combination_iterator(group::VariableGroupPossibilities)
    Iterators.map(Iterators.product(group.possible_values...)) do combination
        bonds_dict = OrderedDict{Symbol,Any}(
            n => OrderedDict{String,Any}("value" => v, "is_first_value" => true) for
            (n, v) in zip(group.names, combination)
        )

        return (combination, bonds_dict)
    end
end

format_filesize(x::Real) = isnan(x) ? "NaN" : try
    Base.format_bytes(floor(Int64, x))
catch
    "$(x / 1e6) MB"
end

function format_filesize(x::Distribution)
    m, s = mean(x), std(x)
    if s / m > 0.05
        format_filesize(m) * " ± " * format_filesize(s)
    else
        format_filesize(m)
    end
end

sum_distributions(ds; init=Normal(0, 0)) = reduce(convolve, ds; init=init)

function Base.show(io::IO, m::MIME"text/plain", p::PrecomputedSampleReport)
    groups = sort(p.groups; by=g -> mean(g.file_size_sample_statistics), rev=true)

    r = Markdown.parse(
        """
# Summary of precomputed

Total size estimate: $(
    sum(Int64[g.num_possibilities for g in groups])
) files, $(map(groups) do group
    group.file_size_sample_statistics
end |> sum_distributions |> format_filesize)

$(map(groups) do group
total_size_dist = group.file_size_sample_statistics

"""
## Group: $(join(["`$(n)`" for n in group.names], ", "))

$(
    if isempty(group.not_available)
        """
        Size estimate for this group: $(
            group.num_possibilities
        ) files, $(
            format_filesize(total_size_dist)
        )
    
        | Name | Possible values | File size per value |
        |---|---|---|
        $(map(zip(group.names, group.possible_values)) do (n, vs)
            "| `$(n)` | $(length(vs)) | $(format_filesize(total_size_dist / length(vs))) | \n"
        end |> join)
        """
    else
        notgivens = [k for (k,v) in group.not_available if v == :NotGiven]
        infitesss = [k for (k,v) in group.not_available if v == :InfinitePossibilities]
        
        """
        This group could not be precomputed because:
        $(
            isempty(notgivens) ? "" : "- The set of possible values for $(join(("`$(s)`" for s in notgivens), ", ")) is not known. If you are using PlutoUI, be sure to use an up-to-date version. If this input element is custom-made, take a look at `AbstractPlutoDingetjes.jl`. \n"
        )$(
            isempty(infitesss) ? "" : "- The set of possible values for $(join(("`$(s)`" for s in infitesss), ", ")) is infinite. \n"
        )
        """
    end
)

""" 
end |> join)
""",
    )
    show(io, m, r)
end

# function static_staterequest_report(; connections)

#     groups = variable_groups(connections; pluto_session, notebook=notebook_session.run.notebook)

#     map(Set(values(connections))) do variable_group

#         names = sort(variable_group)

#         not_available = Dict{Symbol,Reason}()

#         possible_values = [
#             let
#                 result = Pluto.possible_bond_values(
#                     pluto_session::Pluto.ServerSession,
#                     run.notebook::Pluto.Notebook,
#                     n::Symbol,
#                 )
#                 if result isa Symbol
#                     # @error "Failed to get possible values for $(n)" result
#                     not_available[n] = result
#                     []
#                 else
#                     result
#                 end
#             end for n in names
#         ]


#         file_size_sample = map(
#             rand(Iterators.product(possible_values...), length(names) * 3),
#         ) do combination
#             bonds = OrderedDict{Symbol,Any}(
#                 n => OrderedDict{String,Any}("value" => v, "is_first_value" => true)
#                 for (n, v) in zip(names, combination)
#             )

#             result = run_bonds_get_patch_info(pluto_session, sesh, bonds)

#             if result !== nothing
#                 length(Pluto.pack(result))
#             else
#                 0
#             end
#         end

#         VariableGroupPossibilities(
#             variables=variable_group,
#             file_size_sample_statistics=(
#                 Statistics.mean(file_size_sample),
#                 Statistics.stddev(file_size_sample),
#             ),
#             num_possible_values=Dict{Symbol,Int64}(n => Int64(length(possible_values[n]))),
#             not_available=not_available,
#         )
#     end |> PrecomputedSampleReport
# end


function generate_static_staterequests_report(
    groups::Vector{VariableGroupPossibilities},
    notebook_session::NotebookSession;
    settings::PlutoDeploySettings,
    pluto_session::Pluto.ServerSession,
)
    sesh = notebook_session
    run = sesh.run

    @assert run isa RunningNotebook

    map(groups) do group
        stat = if !isempty(group.not_available) || isempty(combination_iterator(group))
            Normal(0, 0)
        else
            iterator = combination_iterator(group)
            file_size_sample =
                map(rand(iterator, length(group.names) * 3)) do (combination, bonds_dict)

                    result = run_bonds_get_patch_info(pluto_session, sesh, bonds_dict)

                    if result !== nothing
                        length(Pluto.pack(result))
                    else
                        0
                    end
                end .* length(iterator) # multiply by number of combinations to get an estimate of the total file size

            fit(Normal, file_size_sample)
        end
        VariableGroupPossibilities(
            names=group.names,
            possible_values=group.possible_values,
            num_possibilities=group.num_possibilities,
            not_available=group.not_available,
            file_size_sample_statistics=stat,
        )
    end |> PrecomputedSampleReport
end


function generate_static_staterequests(
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
    @info "Written bond connections to " bondconnections_path

    groups =
        variable_groups(connections; pluto_session, notebook=notebook_session.run.notebook)

    report = generate_static_staterequests_report(groups, sesh; settings, pluto_session)

    println(stderr)
    println(stderr)
    show(stderr, MIME"text/plain"(), report)
    println(stderr)
    println(stderr)

    foreach(groups) do group
        foreach(combination_iterator(group)) do (combination, bonds_dict)

            result = run_bonds_get_patch_info(pluto_session, sesh, bonds_dict)

            if result !== nothing
                write_path = joinpath(
                    output_dir,
                    "staterequest",
                    URIs.escapeuri(current_hash),
                    Pluto.pack(bonds_dict) |> base64encode |> URIs.escapeuri,
                )

                write(write_path, Pluto.pack(result))

                @info "Written state request to " write_path values =
                    (; (zip(group.names, combination))...)
            end
        end
    end
end

function Random.rand(
    rng::Random.AbstractRNG,
    iterator::Random.SamplerTrivial{Base.Iterators.ProductIterator{T}},
) where {T}
    r(x) = rand(rng, x)
    r.(iterator[].iterators)
end

function Random.rand(
    rng::Random.AbstractRNG,
    iterator::Random.SamplerTrivial{Base.Generator{T,F}},
) where {T,F}
    iterator[].f(rand(rng, iterator[].iter))
end