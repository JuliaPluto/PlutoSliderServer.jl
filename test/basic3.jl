### A Pluto.jl notebook ###
# v0.17.2

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 22dc8ce8-392e-4202-a549-f0fd46152322
import AbstractPlutoDingetjes.Bonds

# ╔═╡ 9b342ef4-fff9-46d0-b316-cc383fe71a59
begin
	struct CoolSlider
	end
	function Base.show(io::IO, ::MIME"text/html", ::CoolSlider)
		write(io, "<input type=range value=1 min=1 max=10>")
	end
	Bonds.initial_value(::CoolSlider) = 1
	Bonds.possible_values(::CoolSlider) = 1:10
end

# ╔═╡ 635e5ebc-6567-11eb-1d9d-f98bfca7ec27
@bind x CoolSlider()

# ╔═╡ ad853ac9-a8a0-44ef-8d41-c8cea165ad57
@bind y CoolSlider()

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
sleep(1); s2

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AbstractPlutoDingetjes = "6e696c72-6542-2067-7265-42206c756150"

[compat]
AbstractPlutoDingetjes = "~1.1.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "abb72771fd8895a7ebd83d5632dc4b989b022b5b"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.2"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╠═22dc8ce8-392e-4202-a549-f0fd46152322
# ╠═9b342ef4-fff9-46d0-b316-cc383fe71a59
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
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
