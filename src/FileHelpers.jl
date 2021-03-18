
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
            return s[1:end-length(e)]
        end
    end
    s
end


function find_notebook_files_recursive(start_dir)
    jlfiles = vcat(
        map(walkdir(start_dir)) do (root, dirs, files)
            map(
                filter(endswith_pluto_file_extension, files)
            ) do file
                joinpath(root, file)
            end
        end...
    )
    plutofiles = filter(jlfiles) do f
        readline(f) == "### A Pluto.jl notebook ###" &&
        (!occursin(".julia", f) || occursin(".julia", start_dir))
    end

    # reverse alphabetical order so that week5 becomes available before week4 :)
    reverse(plutofiles)
end