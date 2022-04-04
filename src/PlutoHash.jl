using Base64
using SHA

const plus = codeunit("+", 1)
const minus = codeunit("-", 1)
const slash = codeunit("/", 1)
const equals = codeunit("=", 1)
const underscore = codeunit("_", 1)

without_equals(s) = rstrip(s, '=') # is a lazy SubString! yay

const base64url_docs_info = """
This function implements the *`base64url` algorithm*, which is like regular `base64` but it produces legal URL/filenames: it uses `-` instead of `+`, `_` instead of `/`, and it does not pad (with `=` originally). 

See [the wiki](https://en.wikipedia.org/wiki/Base64#Variants_summary_table) or [the official spec (RFC 4648 §5)](https://datatracker.ietf.org/doc/html/rfc4648#section-5).
"""



"""
```julia
base64urldecode(s::AbstractString)::Vector{UInt8}
```

$base64url_docs_info
"""
function base64urldecode(s::AbstractString)::Vector{UInt8}
    # This is roughly 0.5 as fast as `base64decode`. See https://gist.github.com/fonsp/d2b84265012942dc40d0082b1fd405ba for benchmark and even slower alternatives. Of course, we could copy-paste the Base64 code and modify it to do base64url, but then Donald Knuth would get angry.
    cs = codeunits(s)
    io = IOBuffer(; sizehint=length(cs) + 2)
    iob64_decode = Base64DecodePipe(io)
    write(io, replace(codeunits(s), minus => plus, underscore => slash))

    for _ = 1:mod(-length(cs), 4)
        write(io, equals)
    end
    seekstart(io)
    read(iob64_decode)
end


"""
```julia
base64urlencode(data)::String
```

$base64url_docs_info
"""
function base64urlencode(data)::String
    # This is roughly 0.5 as fast as `base64encode`. See comment above.
    String(
        replace(
            base64encode(data) |> without_equals |> codeunits,
            plus => minus,
            slash => underscore,
        ),
    )
end

const plutohash = base64urlencode ∘ sha256

plutohash_contents(path) = plutohash(read(path))