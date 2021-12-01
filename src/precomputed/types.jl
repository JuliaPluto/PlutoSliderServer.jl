
using FromFile
import Random
import Statistics
using Distributions
import Markdown


const Reason = Symbol

Base.@kwdef struct VariableGroupPossibilities
    names::Vector{Symbol}
    possible_values::Vector{Any}
    not_available::Dict{Symbol,Reason}
    # size info:
    file_size_sample_distribution::Union{Nothing,Distribution} = nothing
    num_possibilities::Int64
end

Base.@kwdef struct PrecomputedSampleReport
    groups::Vector{VariableGroupPossibilities}
    # size info:
    file_size_sample_distribution::Union{Nothing,Distribution} = nothing
    num_possibilities::Int64
end

function PrecomputedSampleReport(groups::Vector{VariableGroupPossibilities})
    num_possibilities = sum(Int64[g.num_possibilities for g in groups])

    file_size_sample_distribution =
        map(groups) do group
            group.file_size_sample_distribution
        end |> sum_distributions

    PrecomputedSampleReport(; groups, num_possibilities, file_size_sample_distribution)
end

function Base.show(io::IO, m::MIME"text/plain", p::PrecomputedSampleReport)
    groups = sort(p.groups; by=g -> mean(g.file_size_sample_distribution), rev=true)

    r = Markdown.parse(
        """
# Precomputed state summary

Total size estimate: $(p.num_possibilities) files, $(
    p.file_size_sample_distribution |> format_filesize
)

$(map(groups) do group
total_size_dist = group.file_size_sample_distribution

"""
## Group: $(join(["`$(n)`" for n in group.names], ", "))

$(if isempty(group.not_available)
    """
    Size estimate for this group: $(
        group.num_possibilities
    ) files, $(
        format_filesize(total_size_dist)
    )

    | Name | Possible values | File size per value |
    |---|---|---|
    $(map(zip(group.names, group.possible_values)) do (n, vs)
        "| `$(n)` | **$(length(vs))** | $(format_filesize(total_size_dist / length(vs))) | \n"
    end |> join)
    """
else
    notgivens = [k for (k,v) in group.not_available if v == :NotGiven]
    infinites = [k for (k,v) in group.not_available if v == :InfinitePossibilities]
    remainder = setdiff(keys(group.not_available), notgivens ∪ infinites)
    
    """
    This group could not be precomputed because:
    $(
        isempty(notgivens) ? "" : "- The set of possible values for $(join(("`$(s)`" for s in notgivens), ", ")) is not known. If you are using PlutoUI, be sure to use an up-to-date version. If this input element is custom-made, take a look at `AbstractPlutoDingetjes.jl`. \n"
    )$(
        isempty(infinites) ? "" : "- The set of possible values for $(join(("`$(s)`" for s in infinites), ", ")) is infinite. \n"
    )$(
        isempty(remainder) ? "" : "- The set of possible values for $(join(("`$(s)`" for s in remainder), ", ")) could not be determined because of an unknown reason: $(
            join((group.not_available[k] for k in remainder), ", ")
        ). \n"
    )
    """
end)

""" 
end |> join)
""",
    )
    show(io, m, r)
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




# Some missing functionality


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

sum_distributions(ds; init=Normal(0, 0)) =
    any(isnothing, ds) ? nothing : reduce(convolve, ds; init=init)
