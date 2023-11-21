import satori from "npm:satori@0.10";
import React from "npm:react@18.2";
import { Resvg } from "npm:@resvg/resvg-js@2.6";

import { encodeBase64 } from "https://deno.land/std@0.207.0/encoding/base64.ts";
import { walk } from "https://deno.land/std@0.202.0/fs/walk.ts";
import { join } from "https://deno.land/std@0.202.0/path/mod.ts";

// ES6 import for msgpack-lite, we use the fonsp/msgpack-lite fork to make it ES6-importable (without nodejs)
import msgpack from "https://cdn.jsdelivr.net/gh/fonsp/msgpack-lite@0.1.27-es.1/dist/msgpack-es.min.mjs";

// based on https://github.com/kawanet/msgpack-lite/blob/5b71d82cad4b96289a466a6403d2faaa3e254167/lib/ext-packer.js
const codec = msgpack.createCodec();
const packTypedArray = (x) =>
  new Uint8Array(x.buffer, x.byteOffset, x.byteLength);
codec.addExtPacker(0x11, Int8Array, packTypedArray);
codec.addExtPacker(0x12, Uint8Array, packTypedArray);
codec.addExtPacker(0x13, Int16Array, packTypedArray);
codec.addExtPacker(0x14, Uint16Array, packTypedArray);
codec.addExtPacker(0x15, Int32Array, packTypedArray);
codec.addExtPacker(0x16, Uint32Array, packTypedArray);
codec.addExtPacker(0x17, Float32Array, packTypedArray);
codec.addExtPacker(0x18, Float64Array, packTypedArray);

codec.addExtPacker(0x12, Uint8ClampedArray, packTypedArray);
codec.addExtPacker(0x12, ArrayBuffer, (x) => new Uint8Array(x));
codec.addExtPacker(0x12, DataView, packTypedArray);

// Pack and unpack dates. However, encoding a date does throw on Safari because it doesn't have BigInt64Array.
// This isn't too much a problem, as Safari doesn't even support <input type=date /> yet...
// But it does throw when I create a custom @bind that has a Date value...
// For decoding I now also use a "Invalid Date", but the code in https://stackoverflow.com/a/55338384/2681964 did work in Safari.
// Also there is no way now to send an "Invalid Date", so it just does nothing
codec.addExtPacker(0x0d, Date, (d) => new BigInt64Array([BigInt(+d)]));
codec.addExtUnpacker(0x0d, (uintarray) => {
  if ("getBigInt64" in DataView.prototype) {
    let dataview = new DataView(
      uintarray.buffer,
      uintarray.byteOffset,
      uintarray.byteLength,
    );
    let bigint = dataview.getBigInt64(0, true); // true here is "littleEndianes", not sure if this only Works On My Machine©
    if (bigint > Number.MAX_SAFE_INTEGER) {
      throw new Error(
        `Can't read too big number as date (how far in the future is this?!)`,
      );
    }
    return new Date(Number(bigint));
  } else {
    return new Date(NaN);
  }
});

codec.addExtUnpacker(0x11, (x) => new Int8Array(x.buffer));
codec.addExtUnpacker(0x12, (x) => new Uint8Array(x.buffer));
codec.addExtUnpacker(0x13, (x) => new Int16Array(x.buffer));
codec.addExtUnpacker(0x14, (x) => new Uint16Array(x.buffer));
codec.addExtUnpacker(0x15, (x) => new Int32Array(x.buffer));
codec.addExtUnpacker(0x16, (x) => new Uint32Array(x.buffer));
codec.addExtUnpacker(0x17, (x) => new Float32Array(x.buffer));
codec.addExtUnpacker(0x18, (x) => new Float64Array(x.buffer));

/** @param {any} x */
export const pack = (x) => {
  return msgpack.encode(x, { codec: codec });
};

/** @param {Uint8Array} x */
export const unpack = (x) => {
  return msgpack.decode(x, { codec: codec });
};

const fluentEmoji = (code) =>
  "https://cdn.jsdelivr.net/gh/shuding/fluentui-emoji-unicode/assets/" +
  code.toLowerCase() +
  "_color.svg";

const emojiCache = {};
const loadEmoji = (type, code) => {
  const key = type + ":" + code;
  if (key in emojiCache) return emojiCache[key];

  emojiCache[key] = fetch(fluentEmoji(code)).then((r) => r.text());
  return emojiCache[key];
};

const loadDynamicAsset = async (type, code) => {
  if (type === "emoji") {
    const emojiSvg = await loadEmoji(type, code);
    return `data:image/svg+xml;base64,` + encodeBase64(emojiSvg);
  }

  return null;
};

const HeaderComponent = ({
  author,
  authorImage,
  title,
  description,
  imageUrl,
}) => (
  <div
    style={{
      display: "flex",
      height: "100%",
      width: "100%",
      alignItems: "center",
      flexDirection: "column",
      letterSpacing: "-0.02em",
      fontWeight: 700,
      fontFamily: 'Roboto,  "Material Icons"',
      background: "#8E7DBE",
    }}
  >
    <div
      style={{
        height: "62%",
        width: "100%",
        backgroundImage:
          "linear-gradient(90deg, rgb(0, 124, 240), rgb(0, 223, 216))",
        display: "flex",
      }}
    >
      {imageUrl && (
        <img
          style={{ objectFit: "cover" }}
          height="100%"
          width="100%"
          src={imageUrl}
        />
      )}
    </div>
    <div
      style={{
        display: "flex",
        alignItems: "center",
        position: "absolute",
        right: "20px",
        top: "20px",
        background: "rgba(255,255,255,200)",
        padding: "5px",
        borderRadius: "30px",
      }}
    >
      <div
        style={{
          height: "25px",
          width: "25px",
          background: "salmon",
          backgroundImage: authorImage
            ? `url(${authorImage})`
            : "url(https://avatars.githubusercontent.com/u/74617459?s=400&u=85ab12d22312806d5e577de6c5a8b6bf983c21a6&v=4)",
          backgroundClip: "border-box",
          backgroundSize: "25px 25px",
          borderRadius: "12px",
        }}
      >
      </div>
      <div
        style={{ display: "flex", marginLeft: "10px", marginRight: "10px" }}
      >
        {author}
      </div>
    </div>
    <div
      style={{
        position: "absolute",
        bottom: 0,
        display: "flex",
        flexDirection: "column",
        borderRadius: "30px 30px 0px 0px",
        width: "100%",
        height: "45%",
        padding: "20px",
        background: "white",
      }}
    >
      <div style={{ lineClamp: 1, fontSize: "2em", marginBottom: "15px" }}>
        {title}
      </div>
      <div style={{ lineClamp: 3, fontSize: "1.3em", color: "#aaa" }}>
        {description}
      </div>
    </div>
  </div>
);

// TODO(paul): cache this and other files in DENO_DIR?
const roboto = await (await fetch(
  "https://github.com/vercel/satori/raw/main/test/assets/Roboto-Regular.ttf",
)).arrayBuffer();

const generateOgImage = async (pathToNotebook) => {
  const statefileBuf = await Deno.readFile(pathToNotebook + ".plutostate");
  const statefile = unpack(statefileBuf);

  let authorName = statefile.metadata.frontmatter.author_name;
  let authorImage = statefile.metadata.frontmatter.author_image;

  if (authorName === undefined) {
    authorName = statefile.metadata.frontmatter.author.map(({ name }) => name)
      .join(", ", " and ");
  }

  if (authorImage === undefined) {
    authorImage = statefile.metadata.frontmatter.author.map(({ image }) =>
      image
    ).findLast(() => true);
  }

  if (!authorImage) {
    authorImage = statefile.metadata.frontmatter.author.find(() => true)?.url +
      ".png?size=48";
  }

  const svg = await satori(
    <HeaderComponent
      author={authorName}
      authorImage={authorImage}
      title={statefile.metadata.frontmatter.title ??
        pathToNotebook.split("/").findLast(() => true)}
      description={statefile.metadata.frontmatter.description}
      imageUrl={statefile.metadata.frontmatter.image}
    />,
    {
      width: 600,
      height: 400,
      fonts: [
        {
          name: "Roboto",
          // Use `fs` (Node.js only) or `fetch` to read the font as Buffer/ArrayBuffer and provide `data` here.
          data: roboto,
          weight: 400,
          style: "normal",
        },
      ],
      loadAdditionalAsset: loadDynamicAsset,
    },
  );
  const opts = {
    background: "rgba(238, 235, 230, .9)",
    fitTo: {
      mode: "width",
      value: 1200,
    },
  };

  // await Deno.writeTextFile("satori.svg", svg);

  const resvg = new Resvg(svg, opts);
  const pngData = resvg.render();
  const pngBuffer = pngData.asPng();

  const b64 = encodeBase64(pngBuffer);
  const dataUrl = `data:image/png;base64,${b64}`;

  const pngPath = pathToNotebook + ".og-image.png";
  await Deno.writeFile(pngPath, pngBuffer);

  console.log(pngPath);
};

const plutostateFilePath = Deno.args[0]
const pathToNotebook = plutostateFilePath.replace(".plutostate", "");
await generateOgImage(pathToNotebook);
