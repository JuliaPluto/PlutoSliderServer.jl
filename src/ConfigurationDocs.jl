begin
    struct KWDefField
        name::Symbol
        typename::Union{Nothing,Some}
        default::Union{Nothing,Some}
        docstring::Union{Nothing,Some}
    end

    function KWDefField(expr::Expr, docstring)
        default, expr = if Meta.isexpr(expr, :(=))
            Some(expr.args[2]), expr.args[1]
        else
            nothing, expr
        end

        typename, expr = if Meta.isexpr(expr, :(::))
            Some(expr.args[2]), expr.args[1]
        else
            nothing, expr
        end

        @assert expr isa Symbol

        KWDefField(
            expr,
            typename,
            default,
            docstring isa Nothing ? nothing : Some(docstring),
        )
    end

    KWDefField(expr::Symbol, docstring) = KWDefField(
        expr,
        nothing,
        nothing,
        docstring isa Nothing ? nothing : Some(docstring),
    )
end

function get_kwdocs end

function list_options_md(t::Type; 
        prefix::Union{Nothing,String}=nothing,
        hide_undocumented_fields::Bool=true,
    )
    fields = get_kwdocs(t)
    fields = hide_undocumented_fields ? filter(f -> f.docstring !== nothing, fields) : fields
    
    lines = map(fields) do field
        "- `$(
            prefix === nothing ? "" : "$(prefix)_"
        )$(
            field.name
        )$(
            field.typename === nothing ? "" : "::$(something(field.typename))"
        )$(
            field.default === nothing ? "" : " = $(something(field.default))"
        )`$(
            field.docstring === nothing ? "" : ": $(something(field.docstring))"
        )"
    end
    join(lines, "\n") 
end

function list_options_toml(t::Type; 
        hide_undocumented_fields::Bool=true,
    )
    fields = get_kwdocs(t)
    fields = hide_undocumented_fields ? filter(f -> f.docstring !== nothing, fields) : fields

    lines = map(fields) do field
        "$(
            field.name
        )$(
            field.default === nothing ? "" : " = $(something(field.default))"
        ) # $(
            field.typename === nothing ? "" : "($(something(field.typename))) "
        )$(
            field.docstring === nothing ? "" : "$(something(field.docstring))"
        )"
    end
    join(lines, "\n") 
end

this_mod = @__MODULE__

macro extract_docs(raw_expr::Expr)
    
    struct_def = let
        local e = raw_expr
        while e.head != :struct
            e = e.args[end]
        end
        e
    end
    
    struct_name = struct_def.args[2]
    
    
    found = collect_field_info(struct_def)

    return quote
        result = $(esc(raw_expr))
        
        m = $(this_mod)
        m.get_kwdocs(::Type{$(esc(struct_name))}) = $(found)

        result
    end
end


function collect_field_info(struct_def::Expr)::Vector{KWDefField}


    struct_lines = filter(s -> !isa(s, LineNumberNode), struct_def.args[3].args)

    last_docstring = nothing
    found = KWDefField[]
    for line in struct_lines
        if line isa String
            last_docstring = line
        else
            push!(found, KWDefField(line, last_docstring))
            last_docstring = nothing
        end
    end

    found
end

