"""Make the Meshy pin usable as a Mapbox 3D location puck.

The exported .glb carries positions and indices and nothing else — no
normals, no material. Rendered as-is it comes out flat grey: with no normals
there is nothing for the light to fall on, and with no material glTF's default
is a white metal.

So this computes smooth per-vertex normals from the geometry and attaches an
amber PBR material, then writes the result into assets/. Scripted rather than
done in Blender so a re-export gets the same treatment and the reason is
written down.
"""
import json
import os
import struct

import numpy as np

SRC = os.path.expanduser(
    r"~/Downloads/Meshy_AI_Golden_Loop_0925130945_generate.glb"
)
DEST = "assets/models/passim_puck.glb"

# Passim amber. emissive keeps it readable at night, when the basemap goes
# dark and a purely lit model would sink into the street.
BASE_COLOR = [1.0, 0.761, 0.102, 1.0]   # #FFC21A
EMISSIVE = [0.35, 0.26, 0.03]
ROUGHNESS = 0.38
METALLIC = 0.05


def read_glb(path):
    raw = open(path, "rb").read()
    magic, version, _ = struct.unpack("<4sII", raw[:12])
    if magic != b"glTF" or version != 2:
        raise SystemExit("not a glTF 2.0 binary: %s" % path)
    off, gltf, bin_chunk = 12, None, b""
    while off < len(raw):
        clen, ctype = struct.unpack("<I4s", raw[off : off + 8])
        body = raw[off + 8 : off + 8 + clen]
        if ctype == b"JSON":
            gltf = json.loads(body)
        elif ctype == b"BIN\x00":
            bin_chunk = body
        off += 8 + clen + (-(clen) % 4)
    return gltf, bytearray(bin_chunk)


def accessor_array(gltf, blob, index, dtype, per):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"] * per
    return np.frombuffer(
        bytes(blob[start : start + count * np.dtype(dtype).itemsize]), dtype=dtype
    ).reshape(acc["count"], per)


def pad4(b):
    b.extend(b"\x00" * (-len(b) % 4))


gltf, blob = read_glb(SRC)
prim = gltf["meshes"][0]["primitives"][0]
if "NORMAL" in prim["attributes"]:
    raise SystemExit("already has normals — nothing to do")

pos = accessor_array(gltf, blob, prim["attributes"]["POSITION"], np.float32, 3)
idx = accessor_array(gltf, blob, prim["indices"], np.uint32, 1).reshape(-1)
tris = idx.reshape(-1, 3)

# Area-weighted vertex normals: the cross product's length is proportional to
# the triangle's area, so accumulating the raw vectors weights big faces more
# than slivers, which is what makes a curved surface read as smooth.
a, b, c = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
face = np.cross(b - a, c - a)
normals = np.zeros_like(pos)
for col in range(3):
    np.add.at(normals, tris[:, col], face)
lengths = np.linalg.norm(normals, axis=1, keepdims=True)
normals = np.divide(normals, lengths, out=np.zeros_like(normals), where=lengths > 0)
normals = normals.astype(np.float32)

pad4(blob)
normal_offset = len(blob)
blob.extend(normals.tobytes())
pad4(blob)

gltf["bufferViews"].append(
    {"buffer": 0, "byteOffset": normal_offset, "byteLength": normals.nbytes, "target": 34962}
)
gltf["accessors"].append(
    {
        "bufferView": len(gltf["bufferViews"]) - 1,
        "componentType": 5126,  # float
        "count": len(normals),
        "type": "VEC3",
        "min": normals.min(axis=0).tolist(),
        "max": normals.max(axis=0).tolist(),
    }
)
prim["attributes"]["NORMAL"] = len(gltf["accessors"]) - 1

gltf.setdefault("materials", []).append(
    {
        "name": "passim_amber",
        "pbrMetallicRoughness": {
            "baseColorFactor": BASE_COLOR,
            "metallicFactor": METALLIC,
            "roughnessFactor": ROUGHNESS,
        },
        "emissiveFactor": EMISSIVE,
        "doubleSided": True,
    }
)
prim["material"] = len(gltf["materials"]) - 1
gltf["buffers"][0]["byteLength"] = len(blob)

json_chunk = bytearray(json.dumps(gltf, separators=(",", ":")).encode("utf-8"))
json_chunk.extend(b" " * (-len(json_chunk) % 4))

os.makedirs(os.path.dirname(DEST), exist_ok=True)
total = 12 + 8 + len(json_chunk) + 8 + len(blob)
with open(DEST, "wb") as f:
    f.write(struct.pack("<4sII", b"glTF", 2, total))
    f.write(struct.pack("<I4s", len(json_chunk), b"JSON"))
    f.write(json_chunk)
    f.write(struct.pack("<I4s", len(blob), b"BIN\x00"))
    f.write(blob)

print("%s -> %s" % (os.path.basename(SRC), DEST))
print("  %d vertices, %d triangles" % (len(pos), len(tris)))
print("  bounds x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f"
      % (pos[:, 0].min(), pos[:, 0].max(), pos[:, 1].min(), pos[:, 1].max(),
         pos[:, 2].min(), pos[:, 2].max()))
print("  %d kB" % (total // 1024))
