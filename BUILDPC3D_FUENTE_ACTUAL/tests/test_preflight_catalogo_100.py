"""Pruebas locales del filtro preliminar; no acceden a Firebase."""
import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("preflight_100", ROOT / "tools/preflight_catalogo_100.py")
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.baseline = json.loads((ROOT / "godot/data/catalog.json").read_text(encoding="utf-8"))

    def test_current_catalog_is_not_a_complete_proposal(self):
        self.assertTrue(preflight.validate(self.baseline, self.baseline))

    def test_missing_categories_and_metadata_are_rejected(self):
        candidate = copy.deepcopy(self.baseline)
        candidate["version"] += 1
        candidate["compatibility_overlays"] = {}
        errors = preflight.validate(candidate, self.baseline)
        self.assertTrue(any("ocho categorías" in error for error in errors))
        self.assertTrue(any("metadatos" in error for error in errors))

    def test_changed_existing_product_is_rejected(self):
        candidate = copy.deepcopy(self.baseline)
        candidate["version"] += 1
        candidate["compatibility_overlays"] = {}
        candidate["catalog"]["cpu"][0]["price_cop"] += 1
        self.assertTrue(any("cambiaría un documento existente" in error
                            for error in preflight.validate(candidate, self.baseline)))

    def test_duplicate_ids_are_rejected(self):
        candidate = copy.deepcopy(self.baseline)
        candidate["compatibility_overlays"] = {}
        candidate["catalog"]["cpu"].append(copy.deepcopy(candidate["catalog"]["cpu"][0]))
        self.assertTrue(any("ID inválido o duplicado" in error
                            for error in preflight.validate(candidate, self.baseline)))


if __name__ == "__main__":
    unittest.main()
