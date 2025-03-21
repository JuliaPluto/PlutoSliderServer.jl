### A Pluto.jl notebook ###
# v0.20.5

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ bcc82d12-6566-11eb-325f-8b6c4ac362a0
begin
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add("PlutoUI")
	using PlutoUI
end

# ╔═╡ 097db667-a02d-4822-a536-3c0b1f4f7b51
@bind apples Slider(1:10)

# ╔═╡ c8af52d6-17da-49de-b442-b7a154275c52
@bind pears Slider(1:10)

# ╔═╡ 8f6be2a8-14fd-4e2a-ae62-13d87a8e799b
apples + pears

# ╔═╡ af4251d6-e8cb-4ea9-866f-f14661266556


# ╔═╡ d75308ea-9244-46bd-b6cc-3bee26a060f7


# ╔═╡ 7f2c6b8a-6be9-4c64-b0b5-7fc4435153ee
@bind x Slider(50:100)

# ╔═╡ 2995d591-0f74-44e8-9c06-c42c2f9c68f8
@bind y Slider(x:200)

# ╔═╡ 6bc11e12-3bdb-4ca4-a36d-f8067af95ca5
x

# ╔═╡ 80789650-d01f-4d75-8091-6117a66402cb
y

# ╔═╡ 36e1d6cc-73e5-483f-88eb-007ae52e6d00


# ╔═╡ 0f72d9c1-2aa3-4c13-ba8a-1290468124f5


# ╔═╡ f4dbd930-c8aa-43ed-a702-37ada0f8536b
@bind a1 Slider(1:100)

# ╔═╡ e08bdffd-9487-4032-aee8-10f54e9b0606
@bind b1 Slider(a1:100)

# ╔═╡ 65b25bfe-0521-46d4-bad6-6532cd231fde
@bind c1 Slider(b1:100)

# ╔═╡ 1f72f833-fc7c-4fc4-88fd-027fa6258b9d
@bind c2 Slider(a1:100)

# ╔═╡ 87507de2-1f9c-441c-99ec-96095146bd0e
lim = c1 + c2

# ╔═╡ e18cdeb3-1a42-4d3c-876b-d9a5c0872617
@bind d1 Slider(lim:100)

# ╔═╡ Cell order:
# ╠═bcc82d12-6566-11eb-325f-8b6c4ac362a0
# ╠═097db667-a02d-4822-a536-3c0b1f4f7b51
# ╠═c8af52d6-17da-49de-b442-b7a154275c52
# ╠═8f6be2a8-14fd-4e2a-ae62-13d87a8e799b
# ╟─af4251d6-e8cb-4ea9-866f-f14661266556
# ╟─d75308ea-9244-46bd-b6cc-3bee26a060f7
# ╠═7f2c6b8a-6be9-4c64-b0b5-7fc4435153ee
# ╠═2995d591-0f74-44e8-9c06-c42c2f9c68f8
# ╠═6bc11e12-3bdb-4ca4-a36d-f8067af95ca5
# ╠═80789650-d01f-4d75-8091-6117a66402cb
# ╟─36e1d6cc-73e5-483f-88eb-007ae52e6d00
# ╟─0f72d9c1-2aa3-4c13-ba8a-1290468124f5
# ╠═f4dbd930-c8aa-43ed-a702-37ada0f8536b
# ╠═e08bdffd-9487-4032-aee8-10f54e9b0606
# ╠═65b25bfe-0521-46d4-bad6-6532cd231fde
# ╠═1f72f833-fc7c-4fc4-88fd-027fa6258b9d
# ╠═87507de2-1f9c-441c-99ec-96095146bd0e
# ╠═e18cdeb3-1a42-4d3c-876b-d9a5c0872617
