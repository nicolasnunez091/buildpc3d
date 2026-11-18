"""Verificaciones locales: no se requieren credenciales ni se escribe en Firebase."""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "firebase"))
import seed_firestore as seed  # noqa: E402
import verificar_firestore as verify  # noqa: E402


class TransientError(Exception):
    pass


class FakeReference:
    def __init__(self, path):
        self.path = path


class FakeSnapshot:
    def __init__(self, reference, stored):
        self.reference = reference
        self.exists = reference.path in stored
        self._value = stored.get(reference.path)

    def to_dict(self):
        return self._value


class FakeCollection:
    def __init__(self, name):
        self.name = name

    def document(self, name):
        return FakeReference(self.name + "/" + name)


class FakeBatch:
    def __init__(self, db):
        self.db = db
        self.items = []

    def create(self, reference, fields):
        self.items.append((reference, fields))

    def commit(self, retry, timeout):
        assert retry is None and timeout == seed.COMMIT_TIMEOUT_SECONDS
        self.db.events.append("commit")
        self.db.batch_sizes.append(len(self.items))
        outcome = self.db.outcomes.pop(0) if self.db.outcomes else "ok"
        if outcome == "partial":
            self.db.stored[self.items[0][0].path] = self.items[0][1]
            raise TransientError()
        if outcome == "permission":
            raise PermissionError()
        if outcome == "timeout_before":
            raise TransientError()
        if any(ref.path in self.db.stored for ref, _ in self.items):
            raise ValueError("already exists")
        self.db.stored.update({ref.path: fields for ref, fields in self.items})
        if outcome == "timeout_after":
            raise TransientError()


class FakeDatabase:
    def __init__(self, outcomes=None):
        self.stored = {}
        self.outcomes = list(outcomes or [])
        self.events = []
        self.batch_sizes = []
        self.fail_read = False

    def collection(self, name):
        return FakeCollection(name)

    def batch(self):
        return FakeBatch(self)

    def get_all(self, references, retry, timeout):
        assert retry is None and timeout == seed.READ_TIMEOUT_SECONDS
        self.events.append("read")
        if self.fail_read:
            raise TransientError()
        return [FakeSnapshot(ref, self.stored) for ref in references]


class SeedTests(unittest.TestCase):
    def test_catalog_matches_42_and_version(self):
        data = seed.read_catalog()
        self.assertEqual(sum(map(len, data["catalog"].values())), 42)
        self.assertEqual(data["version"], 4)

    def test_dao_rules_and_configuration_match(self):
        dao = (ROOT / "godot/scripts/model/CatalogDAO.gd").read_text(encoding="utf-8")
        rules = (ROOT / "firebase/firestore.rules").read_text(encoding="utf-8")
        settings = json.loads((ROOT / "godot/config/app_config.json").read_text(encoding="utf-8"))
        self.assertEqual(settings["firebase_project_id"], "buildpc3d")
        self.assertEqual(settings["catalog_document"], "catalog")
        self.assertIn("match /meta/catalog", rules)
        self.assertIn("allow write: if false", rules)
        for kind, collection in seed.COLLECTIONS.items():
            self.assertIn(f'"{kind}": "{collection}"', dao)
            self.assertIn(f"'{collection}'", rules)

    def test_plan_never_connects_or_writes(self):
        with patch.object(seed, "create_catalog") as create, contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(seed.main(["--project-id", "buildpc3d"]), 0)
        create.assert_not_called()
        self.assertIn("42 componentes + 1", out.getvalue())
        self.assertIn("meta/catalog", out.getvalue())

    def test_documented_plan_matches_current_catalog(self):
        data = seed.read_catalog()
        plan = (ROOT / "docs/PLAN_CARGA_FIRESTORE.md").read_text(encoding="utf-8")
        self.assertIn(seed.plan_digest("buildpc3d", data), plan)
        self.assertIn("meta/catalog", plan)
        for category, collection in seed.COLLECTIONS.items():
            for part in data["catalog"][category]:
                self.assertIn(f"{collection}/{part['id']}", plan)

    def test_apply_requires_matching_project_confirmation(self):
        with patch.object(seed, "create_catalog") as create, contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                seed.main(["--project-id", "buildpc3d", "--apply"])
            with self.assertRaises(SystemExit):
                seed.main(["--project-id", "buildpc3d", "--apply", "--confirm-project", "otroproyecto"])
        create.assert_not_called()

    def test_changed_plan_never_writes(self):
        with patch.object(seed, "create_catalog") as create, contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = seed.main(["--project-id", "buildpc3d", "--apply", "--confirm-project", "buildpc3d", "--confirm-plan", "0" * 64])
        self.assertEqual(result, 1)
        create.assert_not_called()

    def test_duplicate_or_incomplete_data_rejected(self):
        data = seed.read_catalog()
        data["catalog"]["gpu"][0].pop("length_mm")
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "catalog.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaises(ValueError):
                seed.read_catalog(path)

    def test_credentials_inside_project_are_rejected(self):
        with self.assertRaises(ValueError):
            seed.check_credentials_outside_project(ROOT / "firebase" / "private.json")

    def test_create_uses_single_batch_and_create_only(self):
        data = seed.read_catalog()
        db = FakeDatabase()
        self.assertEqual(seed.apply_atomic_create(db, data, (TransientError,), pause=lambda _: None), "created")
        self.assertEqual(db.batch_sizes, [43])
        self.assertEqual(db.events, ["read", "commit", "read"])
        self.assertEqual(len(db.stored), 43)

    def test_timeout_after_commit_reconciles_without_retry(self):
        db = FakeDatabase(["timeout_after"])
        result = seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(result, "reconciled")
        self.assertEqual(db.events, ["read", "commit", "read"])
        self.assertEqual(len(db.stored), 43)

    def test_timeout_before_commit_reads_before_retry(self):
        db = FakeDatabase(["timeout_before", "ok"])
        result = seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(result, "created")
        self.assertEqual(db.events, ["read", "commit", "read", "commit", "read"])
        self.assertEqual(db.batch_sizes, [43, 43])

    def test_partial_or_different_state_stops_without_retry(self):
        db = FakeDatabase(["partial"])
        with self.assertRaises(seed.SafeLoadError):
            seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(db.events, ["read", "commit", "read"])

    def test_existing_document_blocks_any_write(self):
        db = FakeDatabase()
        db.stored["meta/catalog"] = {"version": 4}
        with self.assertRaises(seed.SafeLoadError):
            seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(db.events, ["read"])

    def test_read_failure_blocks_write(self):
        db = FakeDatabase()
        db.fail_read = True
        with self.assertRaises(seed.SafeLoadError):
            seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(db.events, ["read"])

    def test_failed_reconciliation_never_retries(self):
        class ReadFailsAfterCommit(FakeDatabase):
            def get_all(self, references, retry, timeout):
                if "commit" in self.events:
                    self.events.append("read")
                    raise TransientError()
                return super().get_all(references, retry, timeout)

        db = ReadFailsAfterCommit(["timeout_before"])
        with self.assertRaises(seed.SafeLoadError):
            seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(db.events, ["read", "commit", "read"])

    def test_incomplete_read_is_not_treated_as_empty(self):
        class IncompleteRead(FakeDatabase):
            def get_all(self, references, retry, timeout):
                return super().get_all(references[:-1], retry, timeout)

        db = IncompleteRead()
        with self.assertRaises(seed.SafeLoadError):
            seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(db.events, ["read"])

    def test_permission_error_is_not_retried(self):
        db = FakeDatabase(["permission"])
        with self.assertRaises(seed.SafeLoadError):
            seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(db.events, ["read", "commit", "read"])

    def test_retry_limit_and_existing_matching_state(self):
        db = FakeDatabase(["timeout_before"] * 3)
        with self.assertRaises(seed.SafeLoadError):
            seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        self.assertEqual(db.events, ["read", "commit", "read", "commit", "read", "commit", "read"])
        db = FakeDatabase()
        seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None)
        db.events.clear()
        self.assertEqual(seed.apply_atomic_create(db, seed.read_catalog(), (TransientError,), pause=lambda _: None), "already_present")
        self.assertEqual(db.events, ["read"])

    def test_firestore_decode_matches_catalog_field_types(self):
        self.assertEqual(verify.decode({"integerValue": "4"}), 4)
        self.assertEqual(verify.decode({"arrayValue": {"values": [{"stringValue": "DDR4"}]}}), ["DDR4"])
        self.assertFalse(verify.decode({"booleanValue": False}))


if __name__ == "__main__":
    unittest.main()
