"""Reduce texturas de un GLB sin alterar sus mallas ni sobrescribir el original.

Uso: python tools/optimizar_texturas_glb.py entrada.glb salida.glb
Conserva UV, materiales, canales y mapas normales. Requiere Pillow.
"""
from __future__ import annotations

import argparse
import io
import json
import struct
from pathlib import Path

from PIL import Image


def optimized_image(raw: bytes, name: str, mime: str) -> bytes:
    # La mayoría de texturas del kit son materiales planos repetibles de 2K.
    # PCB y carcasas conservan más resolución para sus pistas y serigrafía.
    detailed = ("mobo_pcb", "gpu_pcb", "mobo_shroud", "gpu_shroud",
                "midtower", "psu_label", "ram_spreader")
    limit = 1024 if any(key in name for key in detailed) else 512
    if name.startswith("el102_col_"):
        limit = 128
    with Image.open(io.BytesIO(raw)) as image:
        image.load()
        image.thumbnail((limit, limit), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        if mime == "image/jpeg":
            image.convert("RGB").save(out, "JPEG", quality=88, optimize=True)
        elif mime == "image/png":
            image.save(out, "PNG", optimize=True)
        else:
            raise ValueError(f"Formato de imagen no soportado: {mime}")
        return out.getvalue()


def optimize(source: Path, target: Path) -> None:
    if target.exists():
        raise FileExistsError(f"No se sobrescribe un archivo existente: {target}")
    blob = source.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", blob)
    if magic != b"glTF" or version != 2 or total != len(blob):
        raise ValueError("El archivo de entrada no es un GLB 2 válido")
    json_size, json_type = struct.unpack_from("<I4s", blob, 12)
    if json_type != b"JSON":
        raise ValueError("Falta el bloque JSON")
    gltf = json.loads(blob[20:20 + json_size])
    binary_at = 20 + json_size
    bin_size, bin_type = struct.unpack_from("<I4s", blob, binary_at)
    if bin_type != b"BIN\x00" or binary_at + 8 + bin_size != len(blob):
        raise ValueError("Se esperaba un único bloque BIN")
    binary = blob[binary_at + 8:]
    if len(gltf.get("buffers", [])) != 1 or gltf["buffers"][0].get("uri"):
        raise ValueError("Solo se admiten recursos con un buffer embebido")

    replacements = {}
    for image in gltf.get("images", []):
        view_id = image.get("bufferView")
        if view_id is None or view_id in replacements:
            raise ValueError("Se esperaban imágenes embebidas en vistas independientes")
        view = gltf["bufferViews"][view_id]
        start = view.get("byteOffset", 0)
        original = binary[start:start + view["byteLength"]]
        replacements[view_id] = optimized_image(original, image.get("name", ""), image["mimeType"])

    packed = bytearray()
    for index, view in enumerate(gltf["bufferViews"]):
        if view.get("buffer", 0) != 0 or "extensions" in view:
            raise ValueError("BufferView externo o comprimido no soportado")
        start = view.get("byteOffset", 0)
        chunk = replacements.get(index, binary[start:start + view["byteLength"]])
        packed.extend(b"\0" * (-len(packed) % 4))
        view["byteOffset"] = len(packed)
        view["byteLength"] = len(chunk)
        packed.extend(chunk)
    gltf["buffers"][0]["byteLength"] = len(packed)
    packed.extend(b"\0" * (-len(packed) % 4))
    text = json.dumps(gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    size = 12 + 8 + len(text) + 8 + len(packed)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("xb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, size))
        out.write(struct.pack("<I4s", len(text), b"JSON"))
        out.write(text)
        out.write(struct.pack("<I4s", len(packed), b"BIN\0"))
        out.write(packed)
    print(f"{source.name}: {len(blob):,} -> {size:,} bytes ({len(replacements)} texturas)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    args = parser.parse_args()
    optimize(args.source, args.target)
