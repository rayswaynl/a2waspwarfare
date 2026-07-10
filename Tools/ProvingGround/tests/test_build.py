import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("wasp_lab_build", ROOT / "build.py")
assert SPEC and SPEC.loader
build = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = build
SPEC.loader.exec_module(build)


class BuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = build.read_catalog()

    def test_every_scenario_resolves(self):
        for name in self.catalog["scenarios"]:
            spec = build.resolve_scenario(name, self.catalog)
            self.assertEqual(name, spec["name"])

    def test_uptier_pin_is_low_population_for_max_ai(self):
        spec = build.resolve_scenario("hc-delegation", self.catalog)
        self.assertEqual(0, spec["popTierPin"])
        self.assertEqual(8, spec["teamCap"])

    def test_current_map_overrides_isolation_flags(self):
        spec = build.resolve_scenario("current-map-fast", self.catalog)
        self.assertEqual(1, spec["featureFlags"]["WFBE_C_NAVAL_HVT"])
        self.assertEqual(1, spec["featureFlags"]["WFBE_C_GUER_PLAYERSIDE"])

    def test_config_is_preinit_and_test_only(self):
        spec = build.resolve_scenario("fast-smoke", self.catalog)
        text = build.render_config(spec)
        self.assertIn('missionNamespace setVariable ["WFBE_C_AI_DELEGATION", 2];', text)
        self.assertIn('missionNamespace setVariable ["WASP_LAB_DISABLE_VICTORY", true];', text)
        self.assertIn('missionNamespace setVariable ["WFBE_C_TEST_TEAM_CAP", 2];', text)
        self.assertIn('missionNamespace setVariable ["WASP_LAB_VARIANT", "control"];', text)
        self.assertIn('missionNamespace setVariable ["WASP_LAB_SCHEDULER_MODE", "off"];', text)
        self.assertIn('missionNamespace setVariable ["WASP_LAB_MIN_HC_FPS", 25];', text)

    def test_scheduler_recipe_is_explicitly_opt_in(self):
        spec = build.resolve_scenario("scheduler-ramp", self.catalog)
        self.assertEqual(spec["schedulerMode"], "off")
        spec["schedulerMode"] = "active"
        build.validate_scenario(spec)

    def test_zero_hc_cli_semantics_disable_ownership_gate(self):
        spec = build.resolve_scenario("hc-delegation", self.catalog)
        spec["expectedHcs"] = 0
        if spec["expectedHcs"] == 0:
            spec["minHcPct"] = 0
            spec["busRate"] = 0
        build.validate_scenario(spec)
        self.assertIn(
            'missionNamespace setVariable ["WASP_LAB_MIN_HC_PCT", 0];',
            build.render_config(spec),
        )
        self.assertIn(
            'missionNamespace setVariable ["WASP_LAB_BUS_RATE", 0];',
            build.render_config(spec),
        )
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "build.py"),
                "hc-delegation",
                "--expected-hcs",
                "0",
                "--bus-rate",
                "20",
                "--validate-only",
            ],
            cwd=str(build.REPO),
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        payload = json.loads(completed.stdout.rsplit("\nvalidation: OK", 1)[0])
        self.assertEqual(payload["expectedHcs"], 0)
        self.assertEqual(payload["minHcPct"], 0)
        self.assertEqual(payload["busRate"], 0)

    def test_modernize_historical_utes_topology(self):
        old = build.UTES_TEMPLATE.read_text(encoding="utf-8")
        new = build.modernize_utes_sqm(old, "TEST")
        self.assertNotIn("forceHeadlessClient", new)
        self.assertEqual(2, new.count('description="RESERVED -- HC / do not use";'))
        self.assertEqual(56, new.count('player="'))
        self.assertIn("\t\titems=83;", new)
        self.assertIn("9001,9002", new)
        for town in ("Strelka", "Airfield", "Kamenyy"):
            self.assertIn(f'text="{town}";', new)

    def test_utes_version_is_isolated(self):
        spec = build.resolve_scenario("fast-smoke", self.catalog)
        template = (build.SOURCE_MISSION / "version.sqf.template").read_text(encoding="utf-8")
        text = build.render_version(template, spec, "candidate", "abc123")
        self.assertIn("#define WF_MAXPLAYERS 56", text)
        self.assertIn("#define STARTING_DISTANCE 900", text)
        self.assertIn("//#define IS_NAVAL_MAP", text)
        self.assertNotRegex(text, r"(?m)^\s*#define\s+WF_DEBUG\b")

    def test_candidate_is_a_single_safe_release_marker_token(self):
        spec = build.resolve_scenario("fast-smoke", self.catalog)
        template = (build.SOURCE_MISSION / "version.sqf.template").read_text(encoding="utf-8")
        text = build.render_version(template, spec, "wasp-lab_candidate.1", "abc123")
        self.assertIn("candidate=wasp-lab_candidate.1", text)
        for unsafe in ('evil"', "evil\n#define BAD 1", "two words", "a|b"):
            with self.subTest(unsafe=unsafe), self.assertRaises(ValueError):
                build.render_version(template, spec, unsafe, "abc123")

    def test_safe_destination_only_allows_repo_output_tree_or_external_leaf(self):
        source = build.SOURCE_MISSION.resolve()
        accepted = build.OUTPUT_ROOT / "safe-test.utes"
        self.assertEqual(accepted.resolve(), build.safe_destination(accepted, source))
        with tempfile.TemporaryDirectory() as temp_dir:
            external = Path(temp_dir) / "safe-test.utes"
            self.assertEqual(external.resolve(), build.safe_destination(external, source))

        unsafe = (
            Path(build.REPO.anchor),
            build.REPO,
            build.REPO / "Missions",
            build.HERE,
            build.REPO / "Tools",
            build.REPO / ".git" / "wasp-output",
            build.OUTPUT_ROOT,
            source,
            source / "nested-output",
        )
        for path in unsafe:
            with self.subTest(path=path), self.assertRaises(ValueError):
                build.safe_destination(path, source)

    def test_force_only_removes_owned_generated_directory(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            parent = Path(temp_dir)
            foreign = parent / "foreign.utes"
            foreign.mkdir()
            keep = foreign / "keep.txt"
            keep.write_text("operator data", encoding="utf-8")
            with self.assertRaises(ValueError):
                build.prepare_destination(foreign, force=True)
            self.assertEqual("operator data", keep.read_text(encoding="utf-8"))

            malformed = parent / "malformed.utes"
            malformed.mkdir()
            (malformed / build.MANIFEST_NAME).write_text("[]", encoding="utf-8")
            with self.assertRaises(ValueError):
                build.prepare_destination(malformed, force=True)
            self.assertTrue(malformed.is_dir())

            owned = parent / "owned.utes"
            owned.mkdir()
            manifest = {
                "schema": build.MANIFEST_SCHEMA,
                "mission": owned.name,
            }
            (owned / build.MANIFEST_NAME).write_text(json.dumps(manifest), encoding="utf-8")
            build.prepare_destination(owned, force=True)
            self.assertFalse(owned.exists())

    def test_pbo_output_requires_explicit_overwrite_and_safe_location(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            parent = Path(temp_dir)
            mission = parent / "generated.utes"
            fresh = parent / "stage" / "generated.utes.pbo"
            self.assertEqual(
                fresh.resolve(),
                build.safe_pbo_destination(fresh, mission, build.SOURCE_MISSION, force=False),
            )

            existing = parent / "existing.pbo"
            existing.write_text("operator data", encoding="utf-8")
            with self.assertRaises(FileExistsError):
                build.safe_pbo_destination(existing, mission, build.SOURCE_MISSION, force=False)
            self.assertEqual(
                existing.resolve(),
                build.safe_pbo_destination(existing, mission, build.SOURCE_MISSION, force=True),
            )
            self.assertEqual("operator data", existing.read_text(encoding="utf-8"))

            for unsafe in (
                parent / "not-a-pbo.bin",
                mission / "nested.pbo",
                build.SOURCE_MISSION / "source.pbo",
                build.REPO / "unsafe.pbo",
            ):
                with self.subTest(path=unsafe), self.assertRaises(ValueError):
                    build.safe_pbo_destination(unsafe, mission, build.SOURCE_MISSION, force=True)

            ancestor = parent / "ancestor.pbo"
            nested_mission = ancestor / "generated.utes"
            with self.assertRaises(ValueError):
                build.safe_pbo_destination(ancestor, nested_mission, build.SOURCE_MISSION, force=True)

    def test_full_pbo_verifier_rejects_truncation_and_hash_damage(self):
        files = [("a.txt", b"alpha"), ("b.bin", b"\x00\x01")]
        packer_spec = importlib.util.spec_from_file_location(
            "test_packer", build.REPO / "Tools" / "Stresstest" / "pack_stresstest.py"
        )
        self.assertIsNotNone(packer_spec)
        self.assertIsNotNone(packer_spec.loader)
        packer = importlib.util.module_from_spec(packer_spec)
        packer_spec.loader.exec_module(packer)
        payload = packer.build_pbo_bytes("lab.utes", files)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "x.pbo"
            path.write_bytes(payload)
            build.verify_pbo(path, "lab.utes", files)
            path.write_bytes(payload[:21])
            with self.assertRaises(RuntimeError):
                build.verify_pbo(path, "lab.utes", files)
            damaged = bytearray(payload)
            damaged[-1] ^= 1
            path.write_bytes(damaged)
            with self.assertRaises(RuntimeError):
                build.verify_pbo(path, "lab.utes", files)

    def test_tree_digest_is_independent_of_parent_staging_path(self):
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "a" / "mission.utes"
            second = Path(directory) / "b" / "mission.utes"
            for root in (first, second):
                (root / "nested").mkdir(parents=True)
                (root / "nested" / "same.sqf").write_text("same", encoding="utf-8")
            self.assertEqual(build.content_digest([first]), build.content_digest([second]))

    def test_catalog_is_json_roundtrippable(self):
        self.assertEqual(self.catalog, json.loads(json.dumps(self.catalog)))


if __name__ == "__main__":
    unittest.main()
