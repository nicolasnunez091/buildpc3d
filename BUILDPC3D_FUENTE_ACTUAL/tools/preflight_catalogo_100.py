"""Validación local de una propuesta; jamás conecta ni escribe en Firebase.

La propuesta contiene `catalog` y `compatibility_overlays`. Los overlays
agregan metadatos verificables sin sobrescribir los 42 documentos existentes.
Esta herramienta no constituye autorización ni implementa una carga remota.
"""
import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "godot/data/catalog.json"
COUNTS = {"cpu": 16, "motherboard": 16, "ram": 14, "gpu": 18,
          "psu": 10, "case": 10, "ssd": 10, "cooler": 6}
DETAILS = {
    "ssd": ("capacity_gb", "interface", "form_factor"),
    "cooler": ("sockets", "cooling_type"),
}


def validate(proposal, baseline):
    errors = []
    catalog = proposal.get("catalog")
    overlays = proposal.get("compatibility_overlays")
    if not isinstance(catalog, dict) or not isinstance(overlays, dict):
        return ["Faltan catalog o compatibility_overlays."]
    if set(catalog) != set(COUNTS):
        errors.append("Se requieren exactamente ocho categorías.")
    if type(proposal.get("version")) is not int or proposal["version"] <= baseline.get("version", 0):
        errors.append("La versión propuesta debe superar la versión local existente.")
    ids = set()
    names = set()
    previous = {part["id"]: part for parts in baseline["catalog"].values() for part in parts}
    for category, target in COUNTS.items():
        parts = catalog.get(category, [])
        if not isinstance(parts, list):
            errors.append(f"{category}: lista inválida")
            continue
        if len(parts) != target:
            errors.append(f"{category}: {len(parts)} de {target}")
        for part in parts:
            if not isinstance(part, dict):
                errors.append(f"{category}: registro inválido")
                continue
            part_id = part.get("id")
            if not isinstance(part_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,150}", part_id) or part_id in ids:
                errors.append(f"{category}: ID inválido o duplicado")
                continue
            ids.add(part_id)
            name = part.get("name", "")
            brand = part.get("brand", "")
            if not isinstance(name, str) or not name.strip() or not isinstance(brand, str) or not brand.strip():
                errors.append(f"{part_id}: nombre o marca ausente")
            name_key = name.strip().casefold() if isinstance(name, str) else ""
            if name_key in names:
                errors.append(f"{part_id}: nombre duplicado")
            names.add(name_key)
            if part.get("type") != category or type(part.get("price_cop")) not in (int, float) or part["price_cop"] <= 0:
                errors.append(f"{part_id}: tipo o precio inválido")
            if part_id in previous:
                if part != previous[part_id]:
                    errors.append(f"{part_id}: cambiaría un documento existente")
            else:
                source = part.get("spec_source_url", "")
                if not isinstance(source, str) or urlparse(source).scheme != "https" or not urlparse(source).netloc:
                    errors.append(f"{part_id}: falta fuente técnica HTTPS")
                if not isinstance(part.get("price_status"), str) or not part["price_status"].strip():
                    errors.append(f"{part_id}: falta procedencia del precio")
                for field in DETAILS.get(category, ()):
                    if not part.get(field):
                        errors.append(f"{part_id}: falta {field}")
    missing = set(previous) - ids
    if missing:
        errors.append(f"Faltan {len(missing)} documentos existentes.")
    # Es imposible verificar ranuras y dimensiones sin datos adicionales; la
    # presencia de URLs no verifica que los valores sean reales.
    for category, required in {
        "motherboard": ("storage_interfaces",),
        "case": ("max_cooler_height_mm", "radiator_sizes_mm"),
        "cpu": ("integrated_graphics", "included_cooler"),
    }.items():
        for part in catalog.get(category, []):
            if not isinstance(part, dict):
                continue
            record = overlays.get(part.get("id"), {})
            if not isinstance(record, dict) or any(field not in record for field in required) \
                    or not isinstance(record.get("source_url"), str) \
                    or urlparse(record.get("source_url", "")).scheme != "https":
                errors.append(f"{part.get('id', '?')}: faltan metadatos o fuente de compatibilidad")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proposal", type=Path)
    args = parser.parse_args()
    try:
        proposal = json.loads(args.proposal.read_text(encoding="utf-8"))
        baseline = json.loads(BASE.read_text(encoding="utf-8"))
        errors = validate(proposal, baseline)
    except (OSError, ValueError, TypeError, KeyError):
        print("No se pudo leer la propuesta o el catálogo base.", file=sys.stderr)
        return 2
    for error in errors:
        print("FALLO:", error)
    if errors:
        print("Vista previa rechazada. No se ha escrito en Firebase.")
        return 1
    print("Validación estructural aprobada; falta verificar manualmente fuentes y compatibilidad.")
    print("No se ha escrito en Firebase.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
