"""Pruebas independientes de datos, geometría, assets y consistencia.

No sustituyen las pruebas de Godot ni la instalación en Android.
"""
import json
import hashlib
import math
import struct
import unittest
from pathlib import Path

import trimesh

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / 'godot'
CATALOG = json.loads((GODOT / 'data/catalog.json').read_text(encoding='utf-8'))['catalog']
TYPES = {'cpu', 'motherboard', 'ram', 'gpu', 'psu', 'case'}
TARGETS = {
    'cpu': (.31, .31, .12), 'motherboard': (1.26, 1.58, .28),
    'ram': (.16, .75, .24), 'gpu': (1.26, .24, .46),
    'psu': (.70, .47, .53), 'case': (2.28, 2.62, 1.72),
}
POSITIONS = {
    'case': (0, 1.34, -.04), 'motherboard': (-.28, 1.53, -.51),
    'cpu': (-.51, 1.80, -.36), 'ram': (.01, 1.83, -.34),
    'gpu': (-.25, 1.34, -.26), 'psu': (-.24, .46, .06),
}


def compatible(c):
    cpu, mb, ram, gpu, psu, box = (c[t] for t in ['cpu', 'motherboard', 'ram', 'gpu', 'psu', 'case'])
    electric = cpu['tdp_w'] + mb['power_w'] + ram['power_w'] + gpu['tdp_w'] + 40
    return (
        cpu['socket'] == mb['socket']
        and mb['ram_type'] in cpu['ram_types']
        and mb['ram_type'] == ram['ram_type']
        and mb['form_factor'] in box['form_factors']
        and gpu['length_mm'] <= box['max_gpu_mm']
        and psu['watts'] >= math.ceil(electric * 1.2)
    )


def lowest_configuration(profile, max_budget=0):
    best = None
    choices = {key: sorted(rows, key=lambda p: p['price_cop']) for key, rows in CATALOG.items()}
    for cpu in choices['cpu']:
        if cpu['cores'] < profile[0]: continue
        for mb in choices['motherboard']:
            if mb['socket'] != cpu['socket'] or mb['ram_type'] not in cpu['ram_types']: continue
            for ram in choices['ram']:
                if ram['capacity_gb'] < profile[1] or ram['ram_type'] != mb['ram_type']: continue
                for gpu in choices['gpu']:
                    if gpu['vram_gb'] < profile[2]: continue
                    for box in choices['case']:
                        if mb['form_factor'] not in box['form_factors'] or gpu['length_mm'] > box['max_gpu_mm']: continue
                        for psu in choices['psu']:
                            cand = dict(cpu=cpu, motherboard=mb, ram=ram, gpu=gpu, psu=psu, case=box)
                            price = sum(x['price_cop'] for x in cand.values())
                            if (best is None or price < best[0]) and (max_budget <= 0 or price <= max_budget) and compatible(cand):
                                best = (price, cand)
    return best


class CatalogTests(unittest.TestCase):
    def test_six_categories_and_42_models(self):
        self.assertEqual(set(CATALOG), TYPES)
        self.assertEqual(sum(map(len, CATALOG.values())), 42)

    def test_unique_model_paths_and_price_provenance(self):
        all_items = [item for group in CATALOG.values() for item in group]
        self.assertEqual(len({x['id'] for x in all_items}), len(all_items))
        self.assertEqual(len({x['model3d_path'] for x in all_items}), len(all_items))
        for item in all_items:
            self.assertGreater(item['price_cop'], 0)
            self.assertIn('price_status', item)
            self.assertTrue(item['model3d_path'].startswith('res://assets/models/'))

    def test_compatible_builds_of_all_uses(self):
        for name, profile in {
            'ofimatica': (4, 8, 2), 'juegos': (6, 16, 8), 'edicion': (8, 32, 8)
        }.items():
            with self.subTest(uso=name):
                solution = lowest_configuration(profile)
                self.assertIsNotNone(solution)
                self.assertTrue(compatible(solution[1]))
                self.assertEqual(solution[0], sum(p['price_cop'] for p in solution[1].values()))
                self.assertIsNone(lowest_configuration(profile, solution[0] - 1))

    def test_no_invalid_socket_or_memory_combination(self):
        for cpu in CATALOG['cpu']:
            for mb in CATALOG['motherboard']:
                if cpu['socket'] == mb['socket']:
                    self.assertTrue(mb['ram_type'] in cpu['ram_types'])


class GLBTests(unittest.TestCase):
    def test_original_glbs_match_initial_manifest(self):
        manifest = json.loads((ROOT / 'docs/MANIFIESTO_INTEGRIDAD_V4.json').read_text(encoding='utf-8'))
        originals = {p: sha for p, sha in manifest['archivos_esenciales'].items() if p.endswith('.glb')}
        self.assertEqual(len(originals), 42)
        for path, digest in originals.items():
            with self.subTest(path=path):
                self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest)

    def test_all_glbs_load_with_real_triangle_geometry(self):
        for category, items in CATALOG.items():
            for part in items:
                with self.subTest(item=part['id']):
                    path = GODOT / part['model3d_path'].replace('res://', '')
                    self.assertTrue(path.is_file(), path)
                    with path.open('rb') as f:
                        self.assertEqual(f.read(4), b'glTF')
                    scene = trimesh.load(path, force='scene')
                    self.assertTrue(scene.geometry)
                    triangles = sum(len(mesh.faces) for mesh in scene.geometry.values())
                    self.assertGreater(triangles, 100)
                    self.assertLess(triangles, 30_000)
                    self.assertTrue(all(math.isfinite(float(x)) for x in scene.bounds.flatten()))

    def test_all_glbs_have_colors_or_textures(self):
        for items in CATALOG.values():
            for part in items:
                path = GODOT / part['model3d_path'].replace('res://', '')
                with path.open('rb') as f:
                    f.read(12)
                    size, chunk_type = struct.unpack('<I4s', f.read(8))
                    self.assertEqual(chunk_type, b'JSON')
                    gltf = json.loads(f.read(size))
                primitives = [p for mesh in gltf['meshes'] for p in mesh['primitives']]
                self.assertTrue(any('COLOR_0' in p['attributes'] or 'TEXCOORD_0' in p['attributes'] for p in primitives))

    def test_glbs_fit_configured_anchors_after_scaling(self):
        for category, items in CATALOG.items():
            target = TARGETS[category]
            for item in items:
                path = GODOT / item['model3d_path'].replace('res://', '')
                bounds = trimesh.load(path, force='scene').bounds
                size = bounds[1] - bounds[0]
                if category == 'ram':
                    size = size[[2, 0, 1]]
                elif category == 'gpu':
                    size = size[[0, 2, 1]]
                factor = min(.94 * t / max(float(s), .001) for t, s in zip(target, size))
                fitted = size * factor
                for f, t in zip(fitted, target):
                    self.assertLessEqual(f, t * .941)

    def test_all_original_parts_fit_all_case_envelopes(self):
        bounds_by_type = {}
        for category, items in CATALOG.items():
            bounds_by_type[category] = []
            for item in items:
                path = GODOT / item['model3d_path'].replace('res://', '')
                dimensions = trimesh.load(path, force='scene').extents
                if category == 'ram':
                    dimensions = dimensions[[2, 0, 1]]
                elif category == 'gpu':
                    dimensions = dimensions[[0, 2, 1]]
                dimensions = [float(x) for x in dimensions]
                factor = min(.94 * t / max(s, .001) for t, s in zip(TARGETS[category], dimensions))
                fitted = [s * factor for s in dimensions]
                center = list(POSITIONS[category])
                if category == 'gpu':
                    center[0] += (fitted[0] - .94 * TARGETS['gpu'][0]) / 2
                bounds_by_type[category].append((
                    [c - s / 2 for c, s in zip(center, fitted)],
                    [c + s / 2 for c, s in zip(center, fitted)],
                ))
        for case_low, case_high in bounds_by_type['case']:
            for category in ('motherboard', 'cpu', 'ram', 'gpu', 'psu'):
                for part_low, part_high in bounds_by_type[category]:
                    with self.subTest(category=category, part=part_low):
                        self.assertTrue(all(c <= p for c, p in zip(case_low, part_low)))
                        self.assertTrue(all(c >= p for c, p in zip(case_high, part_high)))
        # No hay intersección de volúmenes entre las piezas enchufadas; la placa
        # se excluye porque CPU/RAM/GPU deben tocar sus respectivos conectores.
        for index, a in enumerate(('cpu', 'ram', 'gpu', 'psu')):
            for b in ('cpu', 'ram', 'gpu', 'psu')[index + 1:]:
                for low_a, high_a in bounds_by_type[a]:
                    for low_b, high_b in bounds_by_type[b]:
                        self.assertTrue(any(hi_a <= lo_b or hi_b <= lo_a
                                            for lo_a, hi_a, lo_b, hi_b
                                            in zip(low_a, high_a, low_b, high_b)), (a, b))


class ProjectTests(unittest.TestCase):
    def test_entrypoint_and_architecture(self):
        config = (GODOT / 'project.godot').read_text(encoding='utf-8')
        self.assertIn('run/main_scene="res://scenes/Main.tscn"', config)
        for file in [
            'scripts/view/Main.gd', 'scripts/view/PCViewer.gd',
            'scripts/controller/PCController.gd', 'scripts/model/UseFilter.gd',
            'scripts/model/Recommender.gd', 'scripts/model/CatalogDAO.gd'
        ]:
            self.assertTrue((GODOT / file).is_file())

    def test_ia_fallback_and_separate_backend(self):
        controller = (GODOT / 'scripts/controller/PCController.gd').read_text(encoding='utf-8')
        self.assertIn('clasificar_texto_local', controller)
        self.assertIn('_last_source = "local"', controller)
        self.assertIn('Perfil recomendado:', controller)
        self.assertIn('https://', controller)
        settings = json.loads((GODOT / 'config/app_config.json').read_text())
        self.assertNotIn('GROQ_API_KEY', settings)

    def test_mobile_header_and_visual_corrections(self):
        ui = (GODOT / 'scripts/view/Main.gd').read_text(encoding='utf-8')
        viewer = (GODOT / 'scripts/view/PCViewer.gd').read_text(encoding='utf-8')
        self.assertIn('TextServer.AUTOWRAP_OFF', ui)
        self.assertIn('Basis.from_euler', viewer)
        self.assertIn('SLOTS', viewer)
        self.assertIn('vertex_color_use_as_albedo = true', viewer)
        self.assertIn('_pick_at', viewer)
        self.assertIn('_start_interpretation(true)', ui)

    def test_optional_cc0_gpu_provenance(self):
        directory = GODOT / 'assets/models/cc0'
        self.assertEqual((directory / 'graphics-card-light.glb').read_bytes()[:4], b'glTF')
        self.assertIn('CC0', (directory / 'LICENSE.txt').read_text(encoding='utf-8'))
        manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(manifest['extras']['license'], 'CC0-1.0')

    def test_android_export_includes_data_and_internet(self):
        preset = (GODOT / 'export_presets.cfg').read_text(encoding='utf-8')
        config = (GODOT / 'project.godot').read_text(encoding='utf-8')
        self.assertIn('include_filter="*.json,*.txt"', preset)
        self.assertIn('permissions/internet=true', preset)
        self.assertIn('textures/vram_compression/import_etc2_astc=true', config)


if __name__ == '__main__':
    unittest.main()
