### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 635e5ebc-6567-11eb-1d9d-f98bfca7ec27
@bind x html"<input type=range>"

# ╔═╡ ad853ac9-a8a0-44ef-8d41-c8cea165ad57
@bind y html"<input type=range>"

# ╔═╡ 26025270-9b5e-4841-b295-0c47437bc7db
x + y

# ╔═╡ Cell order:
# ╠═635e5ebc-6567-11eb-1d9d-f98bfca7ec27
# ╠═ad853ac9-a8a0-44ef-8d41-c8cea165ad57
# ╠═26025270-9b5e-4841-b295-0c47437bc7db
