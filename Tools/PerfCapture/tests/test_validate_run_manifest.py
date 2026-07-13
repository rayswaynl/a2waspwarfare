"""Tests for the immutable performance run-manifest contract."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"
sys.path.insert(0, str(ROOT))

import validate_run_manifest as validator


class ManifestValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = validator.load_schema()
        cls.pending = json.loads(
            (FIXTURES / "valid-pending" / "MANIFEST.json").read_text(encoding="utf-8")
        )
        cls.final = json.loads(
            (FIXTURES / "valid-final" / "MANIFEST.json").read_text(encoding="utf-8")
        )

    def assert_invalid(self, document: dict, fragment: str) -> None:
        errors = validator.validate_document(document, self.schema)
        self.assertTrue(errors, "mutation unexpectedly passed validation")
        self.assertTrue(
            any(fragment in error for error in errors),
            f"expected {fragment!r} in errors: {errors}",
        )

    def test_valid_pending_fixture(self) -> None:
        self.assertEqual(validator.validate_document(self.pending, self.schema), [])

    def test_valid_final_fixture(self) -> None:
        self.assertEqual(validator.validate_document(self.final, self.schema), [])

    def test_missing_required_field_is_rejected(self) -> None:
        document = copy.deepcopy(self.pending)
        del document["run_id"]
        self.assert_invalid(document, "$.run_id")

    def test_unexpected_field_is_rejected(self) -> None:
        document = copy.deepcopy(self.pending)
        document["surprise"] = True
        self.assert_invalid(document, "$.surprise")

    def test_duplicate_specimen_id_is_rejected(self) -> None:
        document = copy.deepcopy(self.pending)
        document["specimens"].append(copy.deepcopy(document["specimens"][0]))
        self.assert_invalid(document, "duplicate specimen id")

    def test_duplicate_process_role_is_rejected(self) -> None:
        document = copy.deepcopy(self.pending)
        document["process_topology"].append(copy.deepcopy(document["process_topology"][0]))
        self.assert_invalid(document, "duplicate process role")

    def test_unknown_executable_specimen_is_rejected(self) -> None:
        document = copy.deepcopy(self.pending)
        document["process_topology"][0]["executable_specimen_id"] = "missing-exe"
        self.assert_invalid(document, "unknown executable specimen")

    def test_redacted_command_line_rejects_raw_password_switches(self) -> None:
        document = copy.deepcopy(self.pending)
        document["process_topology"][0]["command_line_redacted"] = (
            "ArmA2OAServer.exe -config=server.cfg -password=hunter2"
        )
        self.assert_invalid(document, "sensitive command-line switch")

    def test_artifact_directory_must_match_run_identity(self) -> None:
        document = copy.deepcopy(self.pending)
        document["artifact_directory"] = "20260713_WRONG"
        self.assert_invalid(document, "artifact_directory must equal")

    def test_artifact_paths_must_be_relative_and_run_local(self) -> None:
        for unsafe_path in ("../outside.txt", "C:/outside.txt", "analysis\\RESULTS.md"):
            with self.subTest(path=unsafe_path):
                document = copy.deepcopy(self.pending)
                document["artifacts"][0]["path"] = unsafe_path
                self.assert_invalid(document, "relative run-local path")

    def test_warmup_and_end_times_are_ordered(self) -> None:
        document = copy.deepcopy(self.final)
        document["timing"]["warmup_end_utc"] = "2026-07-13T10:31:00Z"
        self.assert_invalid(document, "warmup_end_utc must not be after end_utc")

    def test_pending_manifest_cannot_claim_attained_workload(self) -> None:
        document = copy.deepcopy(self.pending)
        document["workload"]["attained"]["ai_total"] = 300
        self.assert_invalid(document, "pending manifest attained fields must be null")

    def test_valid_manifest_cannot_have_invalid_reasons(self) -> None:
        document = copy.deepcopy(self.final)
        document["validation"]["invalid_reasons"] = ["not actually valid"]
        self.assert_invalid(document, "valid manifest must have no invalid_reasons")

    def test_required_specimen_kinds_are_enforced(self) -> None:
        document = copy.deepcopy(self.pending)
        document["specimens"] = [
            item for item in document["specimens"] if item["kind"] != "mission_pbo"
        ]
        self.assert_invalid(document, "missing required specimen kind: mission_pbo")


class ManifestFinalizationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = Path(tempfile.mkdtemp(prefix="wasp-manifest-test-"))

    def tearDown(self) -> None:
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def copy_fixture(self, name: str) -> Path:
        destination = self.temp_dir / "MANIFEST.json"
        shutil.copyfile(FIXTURES / name / "MANIFEST.json", destination)
        return destination

    def test_finalize_writes_canonical_json_and_matching_seal(self) -> None:
        manifest_path = self.copy_fixture("valid-final")
        digest = validator.finalize_manifest(manifest_path)

        raw = manifest_path.read_bytes()
        self.assertEqual(raw, validator.canonical_bytes(json.loads(raw)))
        self.assertEqual(hashlib.sha256(raw).hexdigest(), digest)
        self.assertEqual(
            (self.temp_dir / "MANIFEST.sha256").read_text(encoding="ascii").strip(),
            f"{digest}  MANIFEST.json",
        )

    def test_finalize_is_idempotent_when_sealed_bytes_match(self) -> None:
        manifest_path = self.copy_fixture("valid-final")
        first = validator.finalize_manifest(manifest_path)
        second = validator.finalize_manifest(manifest_path)
        self.assertEqual(first, second)

    def test_finalize_rejects_pending_manifest(self) -> None:
        manifest_path = self.copy_fixture("valid-pending")
        with self.assertRaisesRegex(ValueError, "pending manifest cannot be finalized"):
            validator.finalize_manifest(manifest_path)
        self.assertFalse((self.temp_dir / "MANIFEST.sha256").exists())

    def test_tampered_sealed_manifest_is_rejected(self) -> None:
        manifest_path = self.copy_fixture("valid-final")
        validator.finalize_manifest(manifest_path)
        manifest_path.write_bytes(manifest_path.read_bytes().replace(b'"valid"', b'"invalid"', 1))

        count, errors = validator.validate_file(manifest_path)
        self.assertEqual(count, 1)
        self.assertTrue(any("seal mismatch" in error for error in errors), errors)
        with self.assertRaisesRegex(ValueError, "sealed manifest does not match"):
            validator.finalize_manifest(manifest_path)

    def test_cli_returns_nonzero_for_invalid_manifest(self) -> None:
        manifest_path = self.copy_fixture("valid-pending")
        document = json.loads(manifest_path.read_text(encoding="utf-8"))
        document["source"]["git_commit"] = "short"
        manifest_path.write_text(json.dumps(document), encoding="utf-8")

        result = subprocess.run(
            [sys.executable, str(ROOT / "validate_run_manifest.py"), str(manifest_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("$.source.git_commit", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
