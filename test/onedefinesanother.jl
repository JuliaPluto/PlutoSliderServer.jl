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

# ╔═╡ bcc82d12-6566-11eb-325f-8b6c4ac362a0
begin
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add("PlutoUI")
	using PlutoUI
end

# ╔═╡ 7f2c6b8a-6be9-4c64-b0b5-7fc4435153ee
@bind x Slider(50:100)

# ╔═╡ 2995d591-0f74-44e8-9c06-c42c2f9c68f8
@bind y Slider(x:200)

# ╔═╡ 6bc11e12-3bdb-4ca4-a36d-f8067af95ca5
x

# ╔═╡ 80789650-d01f-4d75-8091-6117a66402cb
y

# ╔═╡ Cell order:
# ╠═bcc82d12-6566-11eb-325f-8b6c4ac362a0
# ╠═7f2c6b8a-6be9-4c64-b0b5-7fc4435153ee
# ╠═2995d591-0f74-44e8-9c06-c42c2f9c68f8
# ╠═6bc11e12-3bdb-4ca4-a36d-f8067af95ca5
# ╠═80789650-d01f-4d75-8091-6117a66402cb
