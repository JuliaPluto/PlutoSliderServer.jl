const { pack, unpack } = await import("https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@ae3961c50240eaea5eb4a21dd5cfae1f77155df8/frontend/common/MsgPack.js")

const myhash = async (s) => {
    const data = new TextEncoder().encode(s)
    const hashed_buffer = await window.crypto.subtle.digest("SHA-256", data)

    const base64url = await new Promise((r) => {
        const reader = new FileReader()
        reader.onload = () => r(reader.result)
        reader.readAsDataURL(new Blob([hashed_buffer]))
    })

    return base64url.split(",", 2)[1]
}

const notebook_url = "https://mkhj.fra1.cdn.digitaloceanspaces.com/sample%20Tower%20of%20Hanoi%2016.jl"

const hash = await myhash(await (await fetch(notebook_url)).text())

let patch = {
    a: 1,
    b: [1, 2],
}

const url = `/staterequest/${encodeURIComponent(hash)}/`

let response = await fetch(url, {
    method: "POST",
    body: pack(patch),
})

unpack(new Uint8Array(await response.arrayBuffer()))
