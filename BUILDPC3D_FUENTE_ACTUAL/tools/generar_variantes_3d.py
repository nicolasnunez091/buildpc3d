"""Genera una asignación inicial por SKU; no modifica el catálogo ni los GLB.

Los valores son decisiones visuales aproximadas, no especificaciones técnicas.
No sobrescribe un mapa existente: los ajustes posteriores son manuales.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "godot/data/catalog.json"
OUTPUT = ROOT / "godot/data/variantes_3d.json"
ASSETS = {
    "cpu": "cpu_refrigerador", "motherboard": "placa", "ram": "ram",
    "gpu": "gpu", "psu": "fuente", "case": "gabinete",
}
# Son acabados orientativos; no reproducen colores comerciales certificados.
PALETTES = {
    "cpu": ["d7dce4", "b7c3d2", "e1d8d2", "d6d8e0", "e9cbd2", "b5cad8", "c8c7d9", "e7d3bf"],
    "motherboard": ["b7c8ca", "e1e0df", "bbbcc2", "c5d1c4", "c3c9d4", "b1c6dc", "e0d6cc", "d4c5dc"],
    "ram": ["b0b9c4", "d3d5d9", "dfdce4", "c3c7d0", "b4c9d0", "e0dfd9", "c9d3db", "dad0dc"],
    "gpu": ["aeb8c2", "c5c6cd", "c1b9ba", "d4bdba", "bbc3d0", "d3d5d8", "ded7cd", "d8b9bd"],
    "psu": ["adb7c3", "c3c8cf", "b7bdc9", "d6d7d6", "cbd0d9"],
    "case": ["aeb8c2", "c2c8cf", "dad8d3", "c4cbd7", "d9cec5"],
}


def main():
    if OUTPUT.exists():
        raise SystemExit("El mapa ya existe: se conserva; edítalo manualmente.")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["catalog"]
    entries = {}
    for category, parts in catalog.items():
        for index, part in enumerate(parts):
            entry = {
                "categoria": category,
                "modelo": "res://assets/models/realismo_cc0/" + ASSETS[category] + ".glb",
                "acabado": PALETTES[category][index],
                "variante": index,
                "precision": "aproximada",
            }
            if category == "gpu":
                length = int(part.get("length_mm", 300))
                entry["longitud_mm"] = length
                entry["ventiladores"] = 1 if length < 200 else (2 if length < 290 else 3)
            elif category == "case":
                entry["ventiladores_frontales"] = [1, 2, 2, 2, 3][index]
            elif category == "ram":
                entry["iluminacion"] = "rgb" in part["name"].lower()
            entries[part["id"]] = entry
    OUTPUT.write_text(json.dumps({"version": 1, "productos": entries},
                                 ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Mapa creado para", len(entries), "productos:", OUTPUT)


if __name__ == "__main__":
    main()
