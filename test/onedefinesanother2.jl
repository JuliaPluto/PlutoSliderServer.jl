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
	Pkg.activate()
	# Pkg.activate(mktempdir())
	# Pkg.add("PlutoUI")
	using PlutoUI
end

# ╔═╡ ca736f61-8760-4198-a13a-0e8afefcafef
md"""
Normal:
"""

# ╔═╡ 097db667-a02d-4822-a536-3c0b1f4f7b51
@bind apples Slider(1:10)

# ╔═╡ c8af52d6-17da-49de-b442-b7a154275c52
@bind pears Slider(1:10)

# ╔═╡ 8f6be2a8-14fd-4e2a-ae62-13d87a8e799b
apples + pears

# ╔═╡ af4251d6-e8cb-4ea9-866f-f14661266556


# ╔═╡ d75308ea-9244-46bd-b6cc-3bee26a060f7


# ╔═╡ 39ea3360-2ecd-425c-980c-0e7f0fc5b8e7
md"""
One bond defining another:
"""

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

# ╔═╡ 0788026a-996d-4106-8995-d3cf15f33167
a1

# ╔═╡ e08bdffd-9487-4032-aee8-10f54e9b0606
@bind b1 Slider(a1:100)

# ╔═╡ c82e7b6e-d677-4beb-bec5-c33c139eed95
b1

# ╔═╡ 65b25bfe-0521-46d4-bad6-6532cd231fde
@bind c1 Slider(b1:100)

# ╔═╡ 2ed05065-653e-47b5-97a7-9c3c08bb4482
c1

# ╔═╡ 1f72f833-fc7c-4fc4-88fd-027fa6258b9d
@bind c2 Slider(a1:100)

# ╔═╡ e8e8baf9-282d-4f8f-a5b6-66a937c42fad
c2

# ╔═╡ 87507de2-1f9c-441c-99ec-96095146bd0e
lim = c1 + c2

# ╔═╡ e18cdeb3-1a42-4d3c-876b-d9a5c0872617
@bind d1 Slider(lim:1000)

# ╔═╡ 4bcad3ab-ef02-4a39-a25d-1c165d95701c
d1

# ╔═╡ 2df52930-721d-49ad-8996-83692488d64f
(; a1, b1, c1, c2, d1)

# ╔═╡ c4b7abc3-af33-4558-a26a-0900c4eed7e0


# ╔═╡ d93e8e6f-32e9-45f0-8901-2f131e9b8bf0


# ╔═╡ bfe4566e-3f20-49a9-b1fb-783c336c87f9
md"""
Note: this one is expected to break occasionally (it helps to disable Netork caching in chrome devtools). Leave the `fruit` value and move between options.

The error is expected because in our stateless case we need to rerun the Select definition every time, so the list of options changes (not a pure function of `fruit`).
"""

# ╔═╡ 35d222e3-b3fa-47d9-a85c-3727b62b7378
@bind fruit TextField(default="apple")

# ╔═╡ 267cdd52-10c8-400a-9ea7-17d0e248510d
options = [
	"$fruit$x"
	for x in 1:rand(1:9)
]

# ╔═╡ 9fcf9d42-bcd1-46a0-a2f0-afc07b861577
@bind model Select(options)

# ╔═╡ c6404298-3032-45ae-a234-11be15555925
model

# ╔═╡ aff80fed-920b-4368-9f06-622cff904842


# ╔═╡ 3fa30bad-eea3-4fb3-818d-b242da3566c8


# ╔═╡ c601be55-9f62-4910-8cc6-8de0ee89f19e
yoobind  = @bind yolo Slider(1:100)

# ╔═╡ 0acbe770-f2b6-4024-b3df-a3c06c1882a6
yoobind

# ╔═╡ 55b57711-cd6f-4697-b619-94366274401f
yolo

# ╔═╡ 95a2dab6-dbc1-4ac7-93e9-6939faf80be2


# ╔═╡ d2254fa0-5ce1-4ea0-b4a5-566e58497eb7


# ╔═╡ 9cf788d7-eeaa-4595-bfd8-062bdb196950
@bind joppie Slider(1:100)

# ╔═╡ e34147fe-90a0-49fb-9df7-fdc7e1cb2480
md"""
Check that these two sliders are synced:
"""

# ╔═╡ 85430ba9-f60b-4a70-8030-fe2cb4ddeab0
yooobind2  = @bind yolo2 Slider(joppie:100)

# ╔═╡ ada1feea-76e9-4e60-9c48-1bfebe407472
yooobind2

# ╔═╡ e2133f5d-66f2-4eef-9ebc-8c9817d2312f
yolo2

# ╔═╡ 3b7fc9d8-cf2d-4889-9f7d-e17eecaf0cd9


# ╔═╡ efba337f-7816-4ebe-9a3f-b6e5edbe77c1


# ╔═╡ 3c6385e4-a034-4cfe-8348-ee569c8374d7
@bind maxcat Scrubbable(20)

# ╔═╡ cff52fae-2548-485d-b11c-4aaa1fab291b
coolbond = @bind dogcat PlutoUI.combine() do Child
	md"""
	# Hi there!

	I have $(
		Child(Slider(1:10))
	) dogs and $(
		Child(Slider(5:maxcat; default=6))
	) cats.

	Would you like to see them? $(Child(CheckBox(true)))
	"""
end

# ╔═╡ f489af6f-b8e9-4306-a7ce-e8142498dfc9
# coolbond

# ╔═╡ e97f928d-b53d-4fce-842e-c4312e135f0a
dogcat

# ╔═╡ 0a975647-1f44-4f21-8732-87720c2eb291


# ╔═╡ 2848e74e-17a8-457c-8e08-afd375cd5368


# ╔═╡ 25827619-3256-4176-b9df-4e4459c0d51d
@bind xxx Slider(1:100)

# ╔═╡ e5258f5b-3691-4e5d-ae45-078a30ef3f2e
@bind yyy Slider(xxx:100)

# ╔═╡ 6d484183-7c78-4b0b-a660-c160c3d103d6
xxx, yyy

# ╔═╡ 7eae0bab-9679-4d96-82b1-79328cfa061f
var1 = xxx + yyy

# ╔═╡ b940c23d-4fb4-4ca4-8853-816af7379324
var2 = var1

# ╔═╡ 0e7ad5dc-e098-44fb-83a8-f6d084445129
var3 = var1 + var2

# ╔═╡ eb3a5236-e370-40e2-a9dc-3e32400b7cda
var4 = var1 + var2 + var3

# ╔═╡ 1fd11c79-953b-47bb-9283-7b749afab897
var5 = var1 + var2 + var3 + var4

# ╔═╡ 824fffaf-07ad-4de6-b26d-e17cd8528b6f
var6 = var1 + var2 + var3 + var4 + var5

# ╔═╡ 343b9566-7ea4-4d43-afd8-4ea3fdcd1525
var7 = var1 + var2 + var3 + var4 + var5 + var6

# ╔═╡ 4c37433e-d623-413a-b8fa-349a1f941c2b
var8 = var1 + var2 + var3 + var4 + var5 + var6 + var7

# ╔═╡ 6fe35970-e89c-4dc4-bda2-d2fc1b81136a
var9 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8

# ╔═╡ 3fdcc803-eb81-41c0-9607-8fc02f00eedd
var10 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9

# ╔═╡ e204d6dc-9991-4b42-b1d0-3c17900181f8
var11 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10

# ╔═╡ 59544045-9dcb-4b7f-ac7e-704139036d58
var12 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11

# ╔═╡ 39d29653-4bbb-4d24-902c-5f8b19aaa292
var13 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12

# ╔═╡ 1d63cc3f-fca4-4adb-a96b-1d838024b768
var14 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13

# ╔═╡ d6afb881-73b3-4f7d-bc0a-337879ef965b
var15 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14

# ╔═╡ 51dd1279-9783-4755-91ee-de1a34a5eb46
var16 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15

# ╔═╡ 35ea1333-dcaf-4aad-bd66-92826c325fea
var17 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16

# ╔═╡ b7a89e2d-6216-402a-bf66-4948e33bb963
var18 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17

# ╔═╡ 5810197d-d784-4e79-b9ec-d09c40056245
var19 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18

# ╔═╡ 668f2398-1d11-4cc8-968f-cdf280fbd0a3
var20 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19

# ╔═╡ 1a1c710e-d9f3-42df-8c22-8ff996243958
var21 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20

# ╔═╡ d8751c0d-27a2-464a-9fb6-b2630d48cc48
var22 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21

# ╔═╡ bb506a2f-8fef-445e-9ad4-804874bfcf7b
var23 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22

# ╔═╡ 0995a821-3b7d-41d7-b129-ece5f362e707
var24 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23

# ╔═╡ 7f3aa0f9-c0a5-4113-94f4-e11b143d3307
var25 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24

# ╔═╡ 5b675f64-6b5e-444d-8007-94afcf1c87d1
var26 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25

# ╔═╡ e3978807-1363-480a-9649-783aef442e59
var27 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26

# ╔═╡ 3ec30365-0b24-409b-b800-aa70d164a2dd
var28 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27

# ╔═╡ d11278e2-899f-4f98-9c9b-79361bd2a459
var29 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28

# ╔═╡ cabfe879-222a-45d5-8171-16754763df33
var30 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29

# ╔═╡ e305a9a7-8268-4eda-b4e5-eb3c8ff7ca2d
var31 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30

# ╔═╡ 531fe14d-e1a4-43c9-a637-1d7488681811
var32 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31

# ╔═╡ 8b193412-4635-495c-8fef-32211f49d43a
var33 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32

# ╔═╡ 31f25fa5-c9e8-4dff-9f09-8b9fcffc2394
var34 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33

# ╔═╡ 0fb48e00-8106-4ae2-a9c7-1621569a9c42
var35 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34

# ╔═╡ b4088f4d-a219-456b-ad5e-effe809bb613
var36 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35

# ╔═╡ 21be4431-d880-43dd-abe7-b8d07f8981e6
var37 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36

# ╔═╡ bd3e48b6-75dc-41c4-8abf-32355a74fff4
var38 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37

# ╔═╡ d5575db5-305b-40f6-ad99-a5e37c98d0c4
var39 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38

# ╔═╡ 065fce58-a716-448b-9f9e-71b58eeebcae
var40 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39

# ╔═╡ 297e6542-8f6a-447f-ac84-481bae67a0eb
var41 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40

# ╔═╡ 4f229cf1-c0cc-4764-8be8-196247b5cbe1
var42 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41

# ╔═╡ 1b939086-8902-4160-afac-c600bc4d1389
var43 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42

# ╔═╡ b1ebe5dd-6099-486f-9861-4602884f6fdb
var44 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43

# ╔═╡ 811e3651-6ebc-4672-a6da-1a09873b9d6b
var45 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44

# ╔═╡ 4b2debe0-c3ba-4424-9161-2d9827db886f
var46 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45

# ╔═╡ 1bad8506-bf35-416f-aef0-d9fcff76fa7c
var47 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46

# ╔═╡ 8b73b6b0-e97c-44e0-b2a0-d0157fa4be5b
var48 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47

# ╔═╡ fc926da8-5c33-40e5-80d8-685da515d385
var49 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48

# ╔═╡ b1597789-f8f3-4e81-ab03-c73a1ef4057c
var50 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49

# ╔═╡ 99d9eae1-0d91-43d4-8e5f-810ab87e5ac5
var51 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50

# ╔═╡ 8736f1d0-5504-4455-911b-1d9f91237307
var52 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51

# ╔═╡ 2ab6f199-b046-4d2c-8432-726b150bce49
var53 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52

# ╔═╡ b0a5fbe7-b7f5-485e-bd4b-0b4f0f9ae084
var54 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53

# ╔═╡ ddde6ea7-e09c-45cf-b671-9a86fb4030ce
var55 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54

# ╔═╡ be6bf5f4-faa5-423a-9403-57c48233e7ae
var56 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55

# ╔═╡ 9daefcd2-b875-4977-961c-1ddd52fe1f6d
var57 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56

# ╔═╡ 82736fcb-b394-4af8-9916-468d5a38589a
var58 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57

# ╔═╡ b305045b-8564-4af6-81b1-58782bf15858
var59 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58

# ╔═╡ c6a4abd2-8bf3-4854-8e17-283344b07323
var60 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59

# ╔═╡ 9a57cefc-ca02-4a9f-aed1-46e9acd09cd0
var61 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60

# ╔═╡ d3c0a798-5f01-49e2-82e3-261e9cc46afa
var62 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61

# ╔═╡ a9dc1f05-2e2b-4280-8217-23c7e589083e
var63 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62

# ╔═╡ dc196637-a6fc-4f63-a8b3-c06fc6107b80
var64 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63

# ╔═╡ 78f9cd17-da03-4c38-985f-e5cdebf40078
var65 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64

# ╔═╡ 6a695d72-a5e0-4e70-b5a0-abf4372b7a07
var66 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65

# ╔═╡ f04d2249-757e-491d-8315-94871b12a780
var67 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66

# ╔═╡ 1c8daeab-99a2-47a2-9313-97947c517157
var68 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67

# ╔═╡ c6891daf-bf9e-48ce-a88b-53487f939507
var69 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68

# ╔═╡ 1ceb59da-5073-4007-97a0-1527e52f5982
var70 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69

# ╔═╡ 655c6b18-a66d-4d51-86a6-a3b46bce0279
var71 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70

# ╔═╡ 2f28eccd-0122-4ea3-863f-e2fb3228ba5a
var72 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71

# ╔═╡ aa3bf7f1-f911-4a09-a643-5957c694cd1e
var73 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72

# ╔═╡ e97c09e3-58a7-493b-ad96-7bc91334d958
var74 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73

# ╔═╡ 5862c7a1-a24a-4c1a-a7e1-143bf88627da
var75 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74

# ╔═╡ cb9446f1-f481-48da-8c96-c43859546703
var76 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75

# ╔═╡ 293ff8a1-edfa-4dea-ae8e-49cbaa3aef3a
var77 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76

# ╔═╡ 5995188b-31b6-46a0-bb35-9cacf3717b62
var78 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77

# ╔═╡ 8bbb0643-2983-446d-a12d-75e9d26ebff5
var79 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78

# ╔═╡ d3e7de67-39dd-457b-8a65-9f5d49dc5eb6
var80 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79

# ╔═╡ 2854a620-3dfb-40b4-b351-e8f7a0e78033
var81 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80

# ╔═╡ 689c67a1-1268-4e00-ae7d-ac998bf36890
var82 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81

# ╔═╡ 93f9a961-d506-4475-9df3-e15e13ef0b4e
var83 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82

# ╔═╡ ef5d6064-02d5-4454-bdfc-9d3d2163f4b8
var84 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83

# ╔═╡ f1038c97-2c19-4cb8-8e1b-7a4fbc229525
var85 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84

# ╔═╡ 2e7c5fb4-d388-4947-8d96-b64e0954cd5f
var86 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85

# ╔═╡ 13c7f539-ab21-4579-a5dd-c5dc81f765b2
var87 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86

# ╔═╡ f213f1ef-b697-4dd4-b47c-d0ac55b7097a
var88 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87

# ╔═╡ 690a3fa6-d578-4915-9505-035aee4f905a
var89 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88

# ╔═╡ 3b199256-c0d7-4442-a77b-1046d2b4fa71
var90 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89

# ╔═╡ 49159246-9689-4195-8c0d-0c19e77b8f88
var91 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90

# ╔═╡ 57d0e744-0e85-49af-a4ae-b0ce9db092e7
var92 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91

# ╔═╡ 8e3844e3-1e4d-493f-b51f-e829586c2461
var93 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91 + var92

# ╔═╡ 6141ddd1-9687-4a49-88cd-23f41a665d82
var94 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91 + var92 + var93

# ╔═╡ e6779e8e-70fc-4e71-96eb-c966a9c69a37
var95 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91 + var92 + var93 + var94

# ╔═╡ 46b41b43-d4aa-4a95-8d9a-ee6635667675
var96 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91 + var92 + var93 + var94 + var95

# ╔═╡ e63d2898-f7c2-4cdf-a388-3dd2d3aecf6a
var97 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91 + var92 + var93 + var94 + var95 + var96

# ╔═╡ 2e6eed40-04d7-4af6-9e2c-dbbe25587933
var98 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91 + var92 + var93 + var94 + var95 + var96 + var97

# ╔═╡ 2f5c0e8b-cd3f-4520-afd7-197ea0aa9056
var99 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91 + var92 + var93 + var94 + var95 + var96 + var97 + var98

# ╔═╡ 23cd279d-9733-4f82-8a76-844f539a4890
var100 = var1 + var2 + var3 + var4 + var5 + var6 + var7 + var8 + var9 + var10 + var11 + var12 + var13 + var14 + var15 + var16 + var17 + var18 + var19 + var20 + var21 + var22 + var23 + var24 + var25 + var26 + var27 + var28 + var29 + var30 + var31 + var32 + var33 + var34 + var35 + var36 + var37 + var38 + var39 + var40 + var41 + var42 + var43 + var44 + var45 + var46 + var47 + var48 + var49 + var50 + var51 + var52 + var53 + var54 + var55 + var56 + var57 + var58 + var59 + var60 + var61 + var62 + var63 + var64 + var65 + var66 + var67 + var68 + var69 + var70 + var71 + var72 + var73 + var74 + var75 + var76 + var77 + var78 + var79 + var80 + var81 + var82 + var83 + var84 + var85 + var86 + var87 + var88 + var89 + var90 + var91 + var92 + var93 + var94 + var95 + var96 + var97 + var98 + var99

# ╔═╡ Cell order:
# ╠═bcc82d12-6566-11eb-325f-8b6c4ac362a0
# ╟─ca736f61-8760-4198-a13a-0e8afefcafef
# ╠═097db667-a02d-4822-a536-3c0b1f4f7b51
# ╠═c8af52d6-17da-49de-b442-b7a154275c52
# ╠═8f6be2a8-14fd-4e2a-ae62-13d87a8e799b
# ╟─af4251d6-e8cb-4ea9-866f-f14661266556
# ╟─d75308ea-9244-46bd-b6cc-3bee26a060f7
# ╟─39ea3360-2ecd-425c-980c-0e7f0fc5b8e7
# ╠═7f2c6b8a-6be9-4c64-b0b5-7fc4435153ee
# ╠═2995d591-0f74-44e8-9c06-c42c2f9c68f8
# ╠═6bc11e12-3bdb-4ca4-a36d-f8067af95ca5
# ╠═80789650-d01f-4d75-8091-6117a66402cb
# ╟─36e1d6cc-73e5-483f-88eb-007ae52e6d00
# ╟─0f72d9c1-2aa3-4c13-ba8a-1290468124f5
# ╠═f4dbd930-c8aa-43ed-a702-37ada0f8536b
# ╠═0788026a-996d-4106-8995-d3cf15f33167
# ╠═e08bdffd-9487-4032-aee8-10f54e9b0606
# ╠═c82e7b6e-d677-4beb-bec5-c33c139eed95
# ╠═65b25bfe-0521-46d4-bad6-6532cd231fde
# ╠═2ed05065-653e-47b5-97a7-9c3c08bb4482
# ╠═1f72f833-fc7c-4fc4-88fd-027fa6258b9d
# ╠═e8e8baf9-282d-4f8f-a5b6-66a937c42fad
# ╠═87507de2-1f9c-441c-99ec-96095146bd0e
# ╠═e18cdeb3-1a42-4d3c-876b-d9a5c0872617
# ╠═4bcad3ab-ef02-4a39-a25d-1c165d95701c
# ╠═2df52930-721d-49ad-8996-83692488d64f
# ╟─c4b7abc3-af33-4558-a26a-0900c4eed7e0
# ╟─d93e8e6f-32e9-45f0-8901-2f131e9b8bf0
# ╟─bfe4566e-3f20-49a9-b1fb-783c336c87f9
# ╠═35d222e3-b3fa-47d9-a85c-3727b62b7378
# ╠═267cdd52-10c8-400a-9ea7-17d0e248510d
# ╠═9fcf9d42-bcd1-46a0-a2f0-afc07b861577
# ╠═c6404298-3032-45ae-a234-11be15555925
# ╟─aff80fed-920b-4368-9f06-622cff904842
# ╟─3fa30bad-eea3-4fb3-818d-b242da3566c8
# ╠═c601be55-9f62-4910-8cc6-8de0ee89f19e
# ╠═0acbe770-f2b6-4024-b3df-a3c06c1882a6
# ╠═55b57711-cd6f-4697-b619-94366274401f
# ╟─95a2dab6-dbc1-4ac7-93e9-6939faf80be2
# ╟─d2254fa0-5ce1-4ea0-b4a5-566e58497eb7
# ╠═9cf788d7-eeaa-4595-bfd8-062bdb196950
# ╟─e34147fe-90a0-49fb-9df7-fdc7e1cb2480
# ╠═85430ba9-f60b-4a70-8030-fe2cb4ddeab0
# ╠═ada1feea-76e9-4e60-9c48-1bfebe407472
# ╠═e2133f5d-66f2-4eef-9ebc-8c9817d2312f
# ╟─3b7fc9d8-cf2d-4889-9f7d-e17eecaf0cd9
# ╟─efba337f-7816-4ebe-9a3f-b6e5edbe77c1
# ╠═3c6385e4-a034-4cfe-8348-ee569c8374d7
# ╠═cff52fae-2548-485d-b11c-4aaa1fab291b
# ╠═f489af6f-b8e9-4306-a7ce-e8142498dfc9
# ╠═e97f928d-b53d-4fce-842e-c4312e135f0a
# ╟─0a975647-1f44-4f21-8732-87720c2eb291
# ╟─2848e74e-17a8-457c-8e08-afd375cd5368
# ╠═25827619-3256-4176-b9df-4e4459c0d51d
# ╠═e5258f5b-3691-4e5d-ae45-078a30ef3f2e
# ╠═6d484183-7c78-4b0b-a660-c160c3d103d6
# ╠═7eae0bab-9679-4d96-82b1-79328cfa061f
# ╠═b940c23d-4fb4-4ca4-8853-816af7379324
# ╠═0e7ad5dc-e098-44fb-83a8-f6d084445129
# ╠═eb3a5236-e370-40e2-a9dc-3e32400b7cda
# ╠═1fd11c79-953b-47bb-9283-7b749afab897
# ╠═824fffaf-07ad-4de6-b26d-e17cd8528b6f
# ╠═343b9566-7ea4-4d43-afd8-4ea3fdcd1525
# ╠═4c37433e-d623-413a-b8fa-349a1f941c2b
# ╠═6fe35970-e89c-4dc4-bda2-d2fc1b81136a
# ╠═3fdcc803-eb81-41c0-9607-8fc02f00eedd
# ╠═e204d6dc-9991-4b42-b1d0-3c17900181f8
# ╠═59544045-9dcb-4b7f-ac7e-704139036d58
# ╠═39d29653-4bbb-4d24-902c-5f8b19aaa292
# ╠═1d63cc3f-fca4-4adb-a96b-1d838024b768
# ╠═d6afb881-73b3-4f7d-bc0a-337879ef965b
# ╠═51dd1279-9783-4755-91ee-de1a34a5eb46
# ╠═35ea1333-dcaf-4aad-bd66-92826c325fea
# ╠═b7a89e2d-6216-402a-bf66-4948e33bb963
# ╠═5810197d-d784-4e79-b9ec-d09c40056245
# ╠═668f2398-1d11-4cc8-968f-cdf280fbd0a3
# ╠═1a1c710e-d9f3-42df-8c22-8ff996243958
# ╠═d8751c0d-27a2-464a-9fb6-b2630d48cc48
# ╠═bb506a2f-8fef-445e-9ad4-804874bfcf7b
# ╠═0995a821-3b7d-41d7-b129-ece5f362e707
# ╠═7f3aa0f9-c0a5-4113-94f4-e11b143d3307
# ╠═5b675f64-6b5e-444d-8007-94afcf1c87d1
# ╠═e3978807-1363-480a-9649-783aef442e59
# ╠═3ec30365-0b24-409b-b800-aa70d164a2dd
# ╠═d11278e2-899f-4f98-9c9b-79361bd2a459
# ╠═cabfe879-222a-45d5-8171-16754763df33
# ╠═e305a9a7-8268-4eda-b4e5-eb3c8ff7ca2d
# ╠═531fe14d-e1a4-43c9-a637-1d7488681811
# ╠═8b193412-4635-495c-8fef-32211f49d43a
# ╠═31f25fa5-c9e8-4dff-9f09-8b9fcffc2394
# ╠═0fb48e00-8106-4ae2-a9c7-1621569a9c42
# ╠═b4088f4d-a219-456b-ad5e-effe809bb613
# ╠═21be4431-d880-43dd-abe7-b8d07f8981e6
# ╠═bd3e48b6-75dc-41c4-8abf-32355a74fff4
# ╠═d5575db5-305b-40f6-ad99-a5e37c98d0c4
# ╠═065fce58-a716-448b-9f9e-71b58eeebcae
# ╠═297e6542-8f6a-447f-ac84-481bae67a0eb
# ╠═4f229cf1-c0cc-4764-8be8-196247b5cbe1
# ╠═1b939086-8902-4160-afac-c600bc4d1389
# ╠═b1ebe5dd-6099-486f-9861-4602884f6fdb
# ╠═811e3651-6ebc-4672-a6da-1a09873b9d6b
# ╠═4b2debe0-c3ba-4424-9161-2d9827db886f
# ╠═1bad8506-bf35-416f-aef0-d9fcff76fa7c
# ╠═8b73b6b0-e97c-44e0-b2a0-d0157fa4be5b
# ╠═fc926da8-5c33-40e5-80d8-685da515d385
# ╠═b1597789-f8f3-4e81-ab03-c73a1ef4057c
# ╠═99d9eae1-0d91-43d4-8e5f-810ab87e5ac5
# ╠═8736f1d0-5504-4455-911b-1d9f91237307
# ╠═2ab6f199-b046-4d2c-8432-726b150bce49
# ╠═b0a5fbe7-b7f5-485e-bd4b-0b4f0f9ae084
# ╠═ddde6ea7-e09c-45cf-b671-9a86fb4030ce
# ╠═be6bf5f4-faa5-423a-9403-57c48233e7ae
# ╠═9daefcd2-b875-4977-961c-1ddd52fe1f6d
# ╠═82736fcb-b394-4af8-9916-468d5a38589a
# ╠═b305045b-8564-4af6-81b1-58782bf15858
# ╠═c6a4abd2-8bf3-4854-8e17-283344b07323
# ╠═9a57cefc-ca02-4a9f-aed1-46e9acd09cd0
# ╠═d3c0a798-5f01-49e2-82e3-261e9cc46afa
# ╠═a9dc1f05-2e2b-4280-8217-23c7e589083e
# ╠═dc196637-a6fc-4f63-a8b3-c06fc6107b80
# ╠═78f9cd17-da03-4c38-985f-e5cdebf40078
# ╠═6a695d72-a5e0-4e70-b5a0-abf4372b7a07
# ╠═f04d2249-757e-491d-8315-94871b12a780
# ╠═1c8daeab-99a2-47a2-9313-97947c517157
# ╠═c6891daf-bf9e-48ce-a88b-53487f939507
# ╠═1ceb59da-5073-4007-97a0-1527e52f5982
# ╠═655c6b18-a66d-4d51-86a6-a3b46bce0279
# ╠═2f28eccd-0122-4ea3-863f-e2fb3228ba5a
# ╠═aa3bf7f1-f911-4a09-a643-5957c694cd1e
# ╠═e97c09e3-58a7-493b-ad96-7bc91334d958
# ╠═5862c7a1-a24a-4c1a-a7e1-143bf88627da
# ╠═cb9446f1-f481-48da-8c96-c43859546703
# ╠═293ff8a1-edfa-4dea-ae8e-49cbaa3aef3a
# ╠═5995188b-31b6-46a0-bb35-9cacf3717b62
# ╠═8bbb0643-2983-446d-a12d-75e9d26ebff5
# ╠═d3e7de67-39dd-457b-8a65-9f5d49dc5eb6
# ╠═2854a620-3dfb-40b4-b351-e8f7a0e78033
# ╠═689c67a1-1268-4e00-ae7d-ac998bf36890
# ╠═93f9a961-d506-4475-9df3-e15e13ef0b4e
# ╠═ef5d6064-02d5-4454-bdfc-9d3d2163f4b8
# ╠═f1038c97-2c19-4cb8-8e1b-7a4fbc229525
# ╠═2e7c5fb4-d388-4947-8d96-b64e0954cd5f
# ╠═13c7f539-ab21-4579-a5dd-c5dc81f765b2
# ╠═f213f1ef-b697-4dd4-b47c-d0ac55b7097a
# ╠═690a3fa6-d578-4915-9505-035aee4f905a
# ╠═3b199256-c0d7-4442-a77b-1046d2b4fa71
# ╠═49159246-9689-4195-8c0d-0c19e77b8f88
# ╠═57d0e744-0e85-49af-a4ae-b0ce9db092e7
# ╠═8e3844e3-1e4d-493f-b51f-e829586c2461
# ╠═6141ddd1-9687-4a49-88cd-23f41a665d82
# ╠═e6779e8e-70fc-4e71-96eb-c966a9c69a37
# ╠═46b41b43-d4aa-4a95-8d9a-ee6635667675
# ╠═e63d2898-f7c2-4cdf-a388-3dd2d3aecf6a
# ╠═2e6eed40-04d7-4af6-9e2c-dbbe25587933
# ╠═2f5c0e8b-cd3f-4520-afd7-197ea0aa9056
# ╠═23cd279d-9733-4f82-8a76-844f539a4890
