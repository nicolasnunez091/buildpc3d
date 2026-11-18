"""Descarga opcional de seis modelos GLB CC0 para integrarlos en BUILDPC3D.

Uso:
  python tools/instalar_modelos_cc0.py
  python tools/instalar_modelos_cc0.py --asignar gpu_nvidia_rtx_4060_8gb graphics-card

Los modelos son genéricos, NO reproducen exactamente las marcas del catálogo.
Requiere Internet. Si el servidor rechaza la descarga, usa la página del modelo
para descargar el GLB a mano y guardarlo en godot/assets/models/cc0/.
"""
from __future__ import annotations
import argparse
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'godot/assets/models/cc0'
CATALOG = ROOT / 'godot/data/catalog.json'
SLUGS = {
    'pc-case': 'case',
    'motherboard': 'motherboard',
    'graphics-card': 'gpu',
    'ram-stick': 'ram',
    'cpu': 'cpu',
    'power-supply-unit': 'psu',
}
SOURCES = {key: f'https://grab3d.com/models/electronics/{key}/' for key in SLUGS}

def fetch(slug: str) -> Path:
    name = f'{slug}.glb'
    dest = DEST / name
    if dest.exists():
        if dest.read_bytes()[:4] == b'glTF':
            print('Ya existe', dest)
            return dest
        raise FileExistsError('Se conserva el archivo existente; no se sobrescribe: ' + str(dest))
    url = f'https://grab3d.com/dl/{slug}/{name}'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 BUILDPC3D/1.0'})
    with urllib.request.urlopen(req, timeout=40) as response:
        data = response.read(25_000_001)
    if len(data) < 100 or len(data) > 25_000_000 or data[:4] != b'glTF':
        raise ValueError('No recibimos un GLB válido. Descárgalo desde ' + SOURCES[slug])
    dest.write_bytes(data)
    print(f'Descargado {name}: {len(data)//1024} KB')
    return dest

DEFAULT_MVP_MAPPING = {
    'cpu_amd_ryzen_5_5600': 'cpu',
    'motherboard_gigabyte_a520m_s2h': 'motherboard',
    'ram_kingston_fury_beast_16gb_2x8_ddr4_3200mhz': 'ram-stick',
    'gpu_amd_radeon_rx_6600_8gb': 'graphics-card',
    'psu_thermaltake_smart_500w_80_white': 'power-supply-unit',
    'case_chasis_aerocool_cs_107_matx_mesh': 'pc-case',
}

def assign(item_id: str, slug: str):
    data = json.loads(CATALOG.read_text(encoding='utf-8'))
    found = False
    for group in data['catalog'].values():
        for p in group:
            if p['id'] == item_id:
                if p['type'] != SLUGS[slug]:
                    raise ValueError('Tipo incompatible: ' + str(p['type']) + ' ≠ ' + str(SLUGS[slug]))
                p['model3d_path'] = f'res://assets/models/cc0/{slug}.glb'
                p['model3d_exact'] = False
                p['model3d_source'] = SOURCES[slug]
                found = True
    if not found:
        raise ValueError('No existe ID de componente: '+item_id)
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
    print('Se asignó un modelo genérico CC0 a',item_id)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asignar', nargs=2, metavar=('ID_COMPONENTE','MODELO'))
    parser.add_argument('--solo', choices=SLUGS.keys(), help='Descargar una sola pieza')
    parser.add_argument('--aplicar-mvp', action='store_true', help='Descarga los seis modelos de prueba sin reemplazar automáticamente los GLB actuales')
    args = parser.parse_args()
    DEST.mkdir(parents=True, exist_ok=True)
    slugs=[args.solo] if args.solo else ([args.asignar[1]] if args.asignar else list(SLUGS))
    for slug in slugs:
        try:
            fetch(slug)
        except Exception as exc:
            print('No se pudo descargar', slug, ':', str(exc))
            print('Descarga manual desde:', SOURCES[slug])
    if args.asignar:
        path=DEST/(args.asignar[1]+'.glb')
        if path.exists() and path.read_bytes()[:4]==b'glTF':
            assign(*args.asignar)
        else:
            print('No se asignó porque falta el archivo GLB.')
    if args.aplicar_mvp:
        print("No se asignan automáticamente los 6 GLB genéricos.")
        print("En la versión anterior sus materiales y orientaciones tapaban el ensamble.")
        print("Los modelos propios incluidos quedan activos. Para asignar un GLB revisado")
        print("usa: py tools/poner_modelo_glb.py --id ID --glb RUTA --licencia ...")
    manifest = DEST/'FUENTES_CC0.json'
    if not manifest.exists():
        manifest.write_text(json.dumps(SOURCES,indent=2)+'\n',encoding='utf-8')
