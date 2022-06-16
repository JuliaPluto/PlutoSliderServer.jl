### A Pluto.jl notebook ###
# v0.12.20

#> [frontmatter]
#> title = "Pancakes"
#> description = "are yummy 🥞"
#> tags = ["pancake", "hungry", "snack"]

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

# ╔═╡ 635e5ebc-6567-11eb-1d9d-f98bfca7ec99


# ╔═╡ 635e5ebc-6567-11eb-1d9d-f98bfca7ec27
@bind x html"<input type=range>"

# ╔═╡ ad853ac9-a8a0-44ef-8d41-c8cea165ad57
@bind y html"<input type=range>"

# ╔═╡ 26025270-9b5e-4841-b295-0c47437bc7db
x + y

# ╔═╡ 1352da54-e567-4f59-a3da-19ed3f4bb7c7


# ╔═╡ 09ae27fa-525a-4211-b252-960cdbaf1c1e
b = @bind s html"<input>"

# ╔═╡ ed78a6f1-d282-4d80-8f42-40701aeadb52
b

# ╔═╡ cca2f726-0c25-43c6-85e4-c16ec192d464
s

# ╔═╡ c4f51980-3c30-4d3f-a76a-fc0f0fe16944


# ╔═╡ 8f0bd329-36b8-45ed-b80d-24661242129a
b2 = @bind s2 html"<input>"

# ╔═╡ c55a107f-5d7d-4396-b597-8c1ae07c35be
b2

# ╔═╡ a524ff27-a6a3-4f14-8ed4-f55700647bc4
sleep(1);
s2;

# ╔═╡ Cell order:
# ╠═635e5ebc-6567-11eb-1d9d-f98bfca7ec99
# ╠═635e5ebc-6567-11eb-1d9d-f98bfca7ec27
# ╠═ad853ac9-a8a0-44ef-8d41-c8cea165ad57
# ╠═26025270-9b5e-4841-b295-0c47437bc7db
# ╟─1352da54-e567-4f59-a3da-19ed3f4bb7c7
# ╠═09ae27fa-525a-4211-b252-960cdbaf1c1e
# ╠═ed78a6f1-d282-4d80-8f42-40701aeadb52
# ╠═cca2f726-0c25-43c6-85e4-c16ec192d464
# ╟─c4f51980-3c30-4d3f-a76a-fc0f0fe16944
# ╠═8f0bd329-36b8-45ed-b80d-24661242129a
# ╠═c55a107f-5d7d-4396-b597-8c1ae07c35be
# ╠═a524ff27-a6a3-4f14-8ed4-f55700647bc4
