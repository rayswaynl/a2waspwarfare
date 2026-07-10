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
        self.assertIn('missionNamespace setVariable ["WASP_LAB_TARGET_SYNTHETIC_UNITS", 0];', text)
        self.assertIn('missionNamespace setVariable ["WASP_LAB_SPAWN_ANCHORS", 0];', text)
        self.assertIn('missionNamespace setVariable ["WASP_LAB_SETTLE_SEC", 60];', text)
        self.assertRegex(text, r'missionNamespace setVariable \["WASP_LAB_PARTITION_ID", "[0-9a-f]{16}"\];')

    def test_group_partition_catalog_has_equal_240_member_arms(self):
        expected = {
            4: 60,
            6: 40,
            8: 30,
            10: 24,
            12: 20,
        }
        partition_ids = set()
        for arm, groups in expected.items():
            with self.subTest(arm=arm):
                spec = build.resolve_scenario(f"density-{arm}", self.catalog)
                self.assertEqual(groups, spec["syntheticGroups"])
                self.assertEqual(arm, spec["unitsPerGroup"])
                self.assertEqual(240, spec["targetSyntheticUnits"])
                self.assertEqual(2, spec["spawnAnchors"])
                self.assertEqual(0, spec["vehicleEvery"])
                self.assertEqual(0, spec["expectedHcs"])
                partition_ids.add(build.partition_digest(spec))
        self.assertEqual(1, len(partition_ids))

    def test_partition_digest_removes_only_intentional_arm_fields(self):
        spec = build.resolve_scenario("density-4", self.catalog)
        digest = build.partition_digest(spec)
        mutations = {
            "description": "non-runtime label does not affect partition identity",
            "name": "density-12",
            "syntheticGroups": 20,
            "unitsPerGroup": 12,
            "batchGroups": 2,
        }
        for field, value in mutations.items():
            with self.subTest(ignored_field=field):
                changed = json.loads(json.dumps(spec))
                changed[field] = value
                self.assertEqual(digest, build.partition_digest(changed))
        for field, value in (
            ("targetSyntheticUnits", 360),
            ("spawnAnchors", 3),
            ("durationSec", 901),
            ("minFps", 24),
        ):
            with self.subTest(retained_field=field):
                changed = json.loads(json.dumps(spec))
                changed[field] = value
                self.assertNotEqual(digest, build.partition_digest(changed))
        changed = json.loads(json.dumps(spec))
        changed["featureFlags"]["WFBE_C_CAMPS_CREATE"] = 1
        self.assertNotEqual(digest, build.partition_digest(changed))

    def test_group_partition_360_override_derives_three_equal_anchors(self):
        expected = {4: 90, 6: 60, 8: 45, 10: 36, 12: 30}
        partition_ids = set()
        for arm, groups in expected.items():
            with self.subTest(arm=arm):
                spec = build.resolve_scenario(f"density-{arm}", self.catalog)
                spec["syntheticGroups"] = groups
                spec.pop("targetSyntheticUnits")
                spec.pop("spawnAnchors")
                build.validate_scenario(spec)
                self.assertEqual(360, spec["targetSyntheticUnits"])
                self.assertEqual(3, spec["spawnAnchors"])
                self.assertEqual(120, (groups // 3) * arm)
                partition_ids.add(build.partition_digest(spec))
        self.assertEqual(1, len(partition_ids))

    def test_group_partition_rejects_one_anchor_120_unit_campaign(self):
        spec = build.resolve_scenario("density-4", self.catalog)
        spec["syntheticGroups"] = 30
        spec.pop("targetSyntheticUnits")
        spec.pop("spawnAnchors")
        with self.assertRaisesRegex(ValueError, "exactly 240 or 360"):
            build.validate_scenario(spec)

    def test_group_partition_rejects_unequal_anchor_work(self):
        spec = build.resolve_scenario("density-8", self.catalog)
        spec["syntheticGroups"] = 44
        spec.pop("targetSyntheticUnits")
        spec.pop("spawnAnchors")
        with self.assertRaisesRegex(ValueError, "exact 120-member anchors"):
            build.validate_scenario(spec)

    def test_group_partition_rejects_more_than_three_utes_anchors(self):
        spec = build.resolve_scenario("density-8", self.catalog)
        spec["syntheticGroups"] = 60
        spec.pop("targetSyntheticUnits")
        spec.pop("spawnAnchors")
        with self.assertRaisesRegex(ValueError, "exceeds the three fixed Utes anchors"):
            build.validate_scenario(spec)

    def test_group_partition_rejects_bus_load(self):
        spec = build.resolve_scenario("density-8", self.catalog)
        spec["busRate"] = 1
        with self.assertRaisesRegex(ValueError, "busRate=0"):
            build.validate_scenario(spec)

    def test_group_partition_rejects_scheduler_load(self):
        spec = build.resolve_scenario("density-8", self.catalog)
        spec["schedulerMode"] = "active"
        with self.assertRaisesRegex(ValueError, "schedulerMode=off"):
            build.validate_scenario(spec)

    def test_group_partition_rejects_non_utes_terrain(self):
        spec = build.resolve_scenario("density-8", self.catalog)
        spec["terrain"] = "chernarus"
        with self.assertRaisesRegex(ValueError, "require the Utes terrain"):
            build.validate_scenario(spec)

    def test_group_partition_cli_rejects_coupled_dimension_overrides(self):
        for option, value in (("--bus-rate", "1"), ("--scheduler-mode", "active")):
            with self.subTest(option=option):
                completed = subprocess.run(
                    [
                        sys.executable,
                        str(ROOT / "build.py"),
                        "density-8",
                        option,
                        value,
                        "--validate-only",
                    ],
                    cwd=str(build.REPO),
                    check=False,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                self.assertNotEqual(completed.returncode, 0)
                self.assertIn("group-partition recipes require", completed.stderr)

    def test_partition_barrier_preserves_legacy_recipe_timing(self):
        text = (ROOT / "mission" / "test" / "ProvingGround_Server.sqf").read_text(
            encoding="utf-8"
        )
        self.assertIn("_end = _start + _duration;", text)
        self.assertIn("if (_partitionMode) then {_end = -1};", text)
        self.assertIn(
            'missionNamespace setVariable ["WASP_LAB_PARTITION_MODE", _partitionMode];',
            text,
        )
        self.assertIn(
            'if (_partitionModeNow) then {_group setVariable ["wasp_lab_initial_target_idx", _targetIdx]} else {[_group, _targetIdx] Call WASP_LAB_FNC_AssignLeg};',
            text,
        )
        self.assertIn(
            '_sampleExpected = if (_partitionMode) then {floor (_duration / _sampleSec)} else {floor (((_duration - _warmup) max 0) / _sampleSec)};',
            text,
        )
        self.assertIn(
            '_busExpected = if (_partitionMode) then {round (_duration * _busRate)} else {round (((_duration - _warmup) max 0) * _busRate)};',
            text,
        )
        self.assertIn(
            '_isBenchmark = if (_partitionModeNow) then {_phaseNow == "MEASURE"} else {_elapsed >= _warmupSec};',
            text,
        )

    def test_scheduler_recipe_is_explicitly_opt_in(self):
        spec = build.resolve_scenario("scheduler-ramp", self.catalog)
        self.assertEqual(spec["schedulerMode"], "off")
        spec["schedulerMode"] = "active"
        build.validate_scenario(spec)

    def test_non_finite_recipe_numbers_are_rejected(self):
        for value in (float("nan"), float("inf"), float("-inf")):
            with self.subTest(value=value):
                spec = build.resolve_scenario("fast-smoke", self.catalog)
                spec["durationSec"] = value
                with self.assertRaisesRegex(ValueError, "durationSec"):
                    build.validate_scenario(spec)
                with self.assertRaisesRegex(ValueError, "non-finite"):
                    build.sqf_literal(value)

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
