"""Pruebas de integridad para los GLB CC0 usados en el visor 3D."""
import io
import json
import struct
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "godot/assets/models/realismo_cc0"
TRIANGLES = {
    "gabinete": 23108, "placa": 14468, "gpu": 19732,
    "ram": 3796, "fuente": 12732, "cpu_refrigerador": 6684,
}


def read_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError("GLB inválido")
    json_size, kind = struct.unpack_from("<I4s", data, 12)
    if kind != b"JSON":
        raise ValueError("Bloque JSON ausente")
    gltf = json.loads(data[20:20 + json_size])
    bin_start = 20 + json_size
    bin_size, kind = struct.unpack_from("<I4s", data, bin_start)
    if kind != b"BIN\x00":
        raise ValueError("Bloque BIN ausente")
    return gltf, data[bin_start + 8:bin_start + 8 + bin_size]


class VisualModelTests(unittest.TestCase):
    def test_each_catalog_product_has_an_approximate_variant(self):
        catalog = json.loads((ROOT / "godot/data/catalog.json").read_text(encoding="utf-8"))["catalog"]
        variants = json.loads((ROOT / "godot/data/variantes_3d.json").read_text(encoding="utf-8"))["productos"]
        ids = {item["id"] for items in catalog.values() for item in items}
        self.assertEqual(set(variants), ids)
        for category, items in catalog.items():
            for item in items:
                entry = variants[item["id"]]
                self.assertEqual(entry["categoria"], category)
                self.assertEqual(entry["precision"], "aproximada")
                self.assertTrue((ROOT / "godot" / entry["modelo"].removeprefix("res://")).is_file())

    def test_geometry_retained(self):
        for name, expected in TRIANGLES.items():
            with self.subTest(model=name):
                gltf, _ = read_glb(MODELS / f"{name}.glb")
                triangles = 0
                for mesh in gltf["meshes"]:
                    for primitive in mesh["primitives"]:
                        count = gltf["accessors"][primitive["indices"]]["count"]
                        triangles += count // 3
                self.assertEqual(triangles, expected)

    def test_pbr_textures_and_resolution(self):
        for name in TRIANGLES:
            with self.subTest(model=name):
                gltf, binary = read_glb(MODELS / f"{name}.glb")
                materials = gltf["materials"]
                self.assertTrue(any("normalTexture" in material for material in materials))
                self.assertTrue(any("baseColorTexture" in material.get("pbrMetallicRoughness", {})
                                    for material in materials))
                for image in gltf["images"]:
                    view = gltf["bufferViews"][image["bufferView"]]
                    start = view.get("byteOffset", 0)
                    with Image.open(io.BytesIO(binary[start:start + view["byteLength"]])) as texture:
                        self.assertLessEqual(max(texture.size), 1024)

    def test_texture_import_settings_and_credit(self):
        imports = list(MODELS.glob("*.png.import")) + list(MODELS.glob("*.jpg.import"))
        self.assertGreaterEqual(len(imports), 100)
        for path in imports:
            with self.subTest(path=path.name):
                self.assertIn("compress/mode=2", path.read_text(encoding="utf-8"))
        self.assertIn("CC0 1.0", (MODELS / "LICENCIA_Y_FUENTES.txt").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
