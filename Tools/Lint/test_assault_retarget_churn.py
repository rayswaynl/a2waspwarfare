"""Regression contracts for the assault-team retarget-churn repair.

These are static contracts because the repository has no Arma 2 OA runtime in
the lint suite. They pin the source-level gates and the state transitions that
prevent a slow assault team from being re-tasked forever.
"""

from hashlib import sha256
from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
CH = REPO / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
ASSIGN = Path("Server") / "AI" / "Commander" / "AI_Commander_AssignTowns.sqf"
CONSTANTS = Path("Common") / "Init" / "Init_CommonConstants.sqf"


class AssaultRetargetChurnContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assign = (CH / ASSIGN).read_text(encoding="utf-8")
        cls.constants = (CH / CONSTANTS).read_text(encoding="utf-8")

    def test_new_behavior_flags_are_default_zero(self):
        for flag in (
            "WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES",
            "WFBE_C_AICOM2_ALLOC_TTL_HARDEN",
            "WFBE_C_AICOM_RETARGET_RECYCLE",
        ):
            self.assertIn("if (isNil \"%s\") then {%s = 0}" % (flag, flag), self.constants)

    def test_retarget_grace_reissues_current_enemy_target_before_other_town(self):
        self.assertIn("WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES", self.assign)
        self.assertIn("wfbe_aicom_retarget_grace", self.assign)
        self.assertIn("_target = _goto", self.assign)
        self.assertIn("_graceCount < _graceLimit", self.assign)
        self.assertIn(
            'missionNamespace getVariable ["WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES", 0]) > 0',
            self.assign,
        )

    def test_allocator_ttl_hardening_is_flagged_and_exceeds_two_worker_ticks(self):
        self.assertIn("WFBE_C_AICOM2_ALLOC_TTL_HARDEN", self.assign)
        self.assertIn("_allocTtl = 300", self.assign)
        self.assertIn(
            'missionNamespace getVariable ["WFBE_C_AICOM2_ALLOC_TTL_HARDEN", 0]) > 0',
            self.assign,
        )

    def test_stale_allocator_record_is_cleared_after_its_single_diagnostic(self):
        stale = self.assign.index("|ALLOC_TICK_STALE|")
        release = self.assign.index(
            '_team setVariable ["wfbe_aicom_alloc_target", nil];', stale
        )
        self.assertLess(stale, release)
        self.assertIn(
            '_team setVariable ["wfbe_aicom_alloc_tick", nil];',
            self.assign[release:],
        )

    def test_retarget_elapsed_uses_the_prior_dispatch_timestamp(self):
        self.assertIn("_priorDispT0", self.assign)
        self.assertIn("_priorDispT0 = if (count _priorOrd >= 2)", self.assign)
        self.assertIn("then {_priorOrd select 1}", self.assign)
        self.assertIn("time - _priorDispT0", self.assign)

    def test_retarget_recycle_counts_uncommitted_retarget_and_foot_stage_closures(self):
        self.assertIn("WFBE_C_AICOM_RETARGET_RECYCLE", self.assign)
        self.assertIn("wfbe_aicom_journey_commit_seen", self.assign)
        self.assertIn("RETARGET_RECYCLE", self.assign)
        self.assertIn("FOOT_STAGE_RECYCLE", self.assign)
        self.assertGreaterEqual(self.assign.count("_fjR"), 2)

    def test_mirrors_match_chernarus_for_source_and_flags(self):
        assign_digest = sha256((CH / ASSIGN).read_bytes()).hexdigest()
        for mirror in MIRRORS:
            self.assertEqual(
                assign_digest,
                sha256((mirror / ASSIGN).read_bytes()).hexdigest(),
                "%s drifted on %s" % (ASSIGN, mirror.name),
            )
            mirror_constants = (mirror / CONSTANTS).read_text(encoding="utf-8")
            for flag in (
                "WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES",
                "WFBE_C_AICOM2_ALLOC_TTL_HARDEN",
                "WFBE_C_AICOM_RETARGET_RECYCLE",
            ):
                self.assertIn(
                    'if (isNil "%s") then {%s = 0}' % (flag, flag),
                    mirror_constants,
                )


if __name__ == "__main__":
    unittest.main()
