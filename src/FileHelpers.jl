
const pluto_file_extensions = [
    ".pluto.jl",
    ".jl",
    ".plutojl",
    ".pluto",
]

endswith_pluto_file_extension(s) = any(endswith(s, e) for e in pluto_file_extensions)

function without_pluto_file_extension(s)
    for e in pluto_file_extensions
        if endswith(s, e)
            return s[1:end - length(e)]
        end
    end
    s
end

flatmap(args...) = vcat(map(args...)...)

list_files_recursive(dir=".") = let
    paths = flatmap(walkdir(dir)) do (root, dirs, files)
        joinpath.([root], files)
    end
    relpath.(paths, [dir])
end

"""
Search recursively for Pluto notebook files.

Return paths relative to the search directory.
"""
function find_notebook_files_recursive(start_dir)
    jlfiles = filter(endswith_pluto_file_extension, list_files_recursive(start_dir))
    
    plutofiles = filter(jlfiles) do f
        readline(joinpath(start_dir, f)) == "### A Pluto.jl notebook ###" &&
        (!occursin(".julia", f) || occursin(".julia", start_dir))
    end

    # reverse alphabetical order so that week5 becomes available before week4 :)
    reverse(plutofiles)
end
