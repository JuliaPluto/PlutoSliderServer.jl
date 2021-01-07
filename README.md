# PlutoBindServer.jl

Web server to run just the @bind parts of a [Pluto.jl](https://github.com/fonsp/Pluto.jl) notebook

```julia
julia> ]
pkg> activate --temp
pkg> add https://github.com/fonsp/PlutoBindServer.jl

julia> notebookfiles = ["~/a.jl", "~/b.jl"]
julia> import PlutoBindServer; PlutoBindServer.run_paths(notebookfiles)
```

```sh
julia --project=. -e "import PlutoBindServer; PlutoBindServer.run_paths(ARGS)" ~/a.jl ~/b.jl
```
