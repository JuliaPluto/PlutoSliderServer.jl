### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ 97d42d3a-01af-4627-93dc-7a4ec00d5b70
using Images

# ╔═╡ 87b170fc-ed43-4d65-a096-4b7893248664
using ColorTypes

# ╔═╡ b5070bc4-b689-48a3-8a0d-9dfdf35da9c9
threshold = 0.5

# ╔═╡ 08432c2c-9452-4d49-b043-e54522c64f03
w = 100

# ╔═╡ b0f16f6b-113a-41fc-bd98-1dd3045b5b8a
h = 100

# ╔═╡ 7e77fb5e-0df4-44d7-bf56-3af5fa096695
dimensions = [w, h]

# ╔═╡ 7a767e67-d7a9-457e-afa5-d61b075801de
image = (Float32.(rand(dimensions...) .>= threshold))

# ╔═╡ d57efa08-97e3-42c9-9836-2489feafb7bd
image_out = Gray.(image)

# ╔═╡ Cell order:
# ╠═97d42d3a-01af-4627-93dc-7a4ec00d5b70
# ╠═87b170fc-ed43-4d65-a096-4b7893248664
# ╠═b5070bc4-b689-48a3-8a0d-9dfdf35da9c9
# ╠═08432c2c-9452-4d49-b043-e54522c64f03
# ╠═b0f16f6b-113a-41fc-bd98-1dd3045b5b8a
# ╠═7e77fb5e-0df4-44d7-bf56-3af5fa096695
# ╠═7a767e67-d7a9-457e-afa5-d61b075801de
# ╠═d57efa08-97e3-42c9-9836-2489feafb7bd
