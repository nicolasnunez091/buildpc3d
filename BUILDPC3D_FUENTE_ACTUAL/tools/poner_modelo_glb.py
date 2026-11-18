"""Importa un GLB local autorizado y lo asocia con un componente.

Ejemplo:
  py tools/poner_modelo_glb.py --id gpu_nvidia_rtx_4060_8gb --glb "C:/Descargas/rtx4060.glb" --licencia "CC BY 4.0" --autor "Autor" --url "https://..."
  py tools/poner_modelo_glb.py --id cpu_amd_ryzen_5_5600 --glb "C:/Modelos/cpu.glb" --rotar 0 0 0

La persona que importa garantiza que posee permiso para usar y redistribuir el archivo.
"""
from __future__ import annotations
import argparse
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "godot/data/catalog.json"
DEST = ROOT / "godot/assets/models/importados"

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--id", required=True)
    p.add_argument("--glb", required=True)
    p.add_argument("--licencia", default="por_verificar")
    p.add_argument("--autor", default="desconocido")
    p.add_argument("--url", default="")
    p.add_argument("--rotar", nargs=3, type=float, default=[0.0, 0.0, 0.0], metavar=("X", "Y", "Z"))
    p.add_argument("--offset", nargs=3, type=float, default=[0.0, 0.0, 0.0], metavar=("X", "Y", "Z"))
    args = p.parse_args()
    src = Path(args.glb).expanduser().resolve()
    if not src.is_file():
        p.error(f"No existe archivo: {src}")
    if src.suffix.lower() != ".glb" or src.stat().st_size < 50 or src.read_bytes()[:4] != b"glTF":
        p.error("El archivo no parece ser un GLB válido")
    if src.stat().st_size > 25_000_000:
        p.error("Se rechazó el archivo: más de 25 MB, optimiza la malla para Android")
    doc = json.loads(CATALOG.read_text(encoding="utf-8"))
    item = next((c for items in doc["catalog"].values() for c in items if c["id"] == args.id), None)
    if item is None:
        p.error("No existe ese ID de componente")
    DEST.mkdir(parents=True, exist_ok=True)
    target = DEST / (args.id + ".glb")
    if target.exists():
        p.error("Ya existe un GLB importado para ese ID; haz una copia y elige otro destino antes de reemplazarlo.")
    shutil.copy2(src, target)
    item["model3d_path"] = "res://assets/models/importados/" + target.name
    item["model3d_source"] = args.url or "archivo_importado_por_usuario"
    item["model3d_license"] = args.licencia
    item["model3d_author"] = args.autor
    item["model3d_exact"] = False
    item["model3d_rotation_deg"] = args.rotar
    item["model3d_offset"] = args.offset
    doc["version"] = int(doc.get("version", 0)) + 1
    CATALOG.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("Modelo instalado para:", item["name"])
    print("Modelo:", target)
    print("Comprueba licencia, escala y orientación desde Godot.")

if __name__ == "__main__":
    main()
