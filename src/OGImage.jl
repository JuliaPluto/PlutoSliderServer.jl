using Deno_jll: deno
using Scratch

"Is frontmatter complete enough to generate an OG image?"
function can_generate_og_image(frontmatter)
    (haskey(frontmatter, "author") || haskey(frontmatter, "author_name")) &&
        haskey(frontmatter, "title") &&
        haskey(frontmatter, "image")
end

"""
Run the deno command with a [DENO_DIR](https://docs.deno.com/runtime/manual/basics/env_variables#special-environment-variables)
tied to a Scratch.jl scratch space where the deps and cache files will be installed.
"""
deno_pss(args) = withenv("DENO_DIR" => get_scratch!(@__MODULE__, "deno_dir")) do
    buf = IOBuffer()
    run(`$(deno()) $(args)`, Base.DevNull(), buf)
    #                        ﬌ stdin         ﬌ stdout
    String(take!(buf))
end

function generate_og_image(path_to_pluto_state_file)
    deno_pss([
        "run",
        "--allow-all", # Do we need stricter permissions?
        joinpath(@__DIR__, "og_image_gen.jsx"),
        path_to_pluto_state_file,
    ]) |> strip
end
