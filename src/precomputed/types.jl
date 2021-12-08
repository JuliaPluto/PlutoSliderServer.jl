
using FromFile
import Random
import Statistics
using Distributions
import Markdown

@from "../Configuration.jl" import PlutoDeploySettings

const Reason = Symbol

Base.@kwdef struct Judgement
    should_precompute_all::Bool = false
    not_available::Bool = false
    close_to_filesize_limit::Bool = false
    exceeds_filesize_limit::Bool = false
end

struct VariableGroupPossibilities
    names::Vector{Symbol}
    possible_values::Vector
    not_available::Dict{Symbol,Reason}
    # size info:
    file_size_sample_distribution::Union{Nothing,Distribution}
    num_possibilities::BigInt

    judgement::Judgement
end

function VariableGroupPossibilities(;
    names::Vector{Symbol},
    possible_values::Vector,
    not_available::Dict{Symbol,Reason},
    # size info:
    num_possibilities::BigInt,
    file_size_sample_distribution::Union{Nothing,Distribution}=nothing,
    settings::Union{Nothing,PlutoDeploySettings}=nothing,
)
    is_not_available = !isempty(not_available)

    if !isa(file_size_sample_distribution, Nothing)
        @assert settings isa PlutoDeploySettings

        limit = settings.Precompute.max_filesize_per_group
        current = mean(file_size_sample_distribution)

        exceeds_filesize_limit = current > limit
        close_to_filesize_limit = current > limit * 0.7
    else
        exceeds_filesize_limit = close_to_filesize_limit = false
    end

    j = Judgement(;
        should_precompute_all=!is_not_available && !exceeds_filesize_limit,
        exceeds_filesize_limit,
        close_to_filesize_limit,
        not_available=is_not_available,
    )

    VariableGroupPossibilities(
        names,
        possible_values,
        not_available,
        file_size_sample_distribution,
        num_possibilities,
        j,
    )
end

Base.@kwdef struct PrecomputedSampleReport
    groups::Vector{VariableGroupPossibilities}
    # size info:
    file_size_sample_distribution::Union{Nothing,Distribution} = nothing
    num_possibilities::BigInt
    judgement::Judgement
end

function PrecomputedSampleReport(groups::Vector{VariableGroupPossibilities})
    num_possibilities = sum(BigInt[g.num_possibilities for g in groups])

    file_size_sample_distribution =
        map(groups) do group
            group.file_size_sample_distribution
        end |> sum_distributions

    judgement = Judgement(;
        should_precompute_all=all(g.judgement.should_precompute_all for g in groups),
        not_available=any(g.judgement.not_available for g in groups),
        exceeds_filesize_limit=any(g.judgement.exceeds_filesize_limit for g in groups),
        close_to_filesize_limit=any(g.judgement.close_to_filesize_limit for g in groups),
    )

    PrecomputedSampleReport(;
        groups,
        num_possibilities,
        file_size_sample_distribution,
        judgement,
    )
end

function exceeds_limit(j::Judgement, prefix::String="")

    j.exceeds_filesize_limit ? "*($(prefix)exceeding filesize limit)*" :
    j.close_to_filesize_limit ? "*($(prefix)close to filesize limit)*" : ""
end


function Base.show(io::IO, m::MIME"text/plain", p::PrecomputedSampleReport)
    groups = sort(p.groups; by=g -> mean(g.file_size_sample_distribution), rev=true)

    r = Markdown.parse(
        """
# Precomputed state summary

Total size estimate: $(p.num_possibilities) files, $(
    p.file_size_sample_distribution |> format_filesize
) $(exceeds_limit(p.judgement, "some groups are "))

$(map(groups) do group
total_size_dist = group.file_size_sample_distribution

"""
## $(pretty(group.judgement)) Group: $(join(["`$(n)`" for n in group.names], ", "))

$(if isempty(group.not_available)
    """
    Size estimate for this group: $(
        group.num_possibilities
    ) files, $(
        format_filesize(total_size_dist)
    ) $(exceeds_limit(group.judgement))

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


pretty(j::Judgement) =
    if j.should_precompute_all
        j.close_to_filesize_limit ? "⚠️" : "✓"
    else
        "❌"
    end
