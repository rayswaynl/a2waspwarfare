#!/usr/bin/env python3
"""Regression checks for the owner rule that AICOM never targets naval HVTs."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
ASSIGN = MISSION / "Server/AI/Commander/AI_Commander_AssignTowns.sqf"
SNAPSHOT = MISSION / "Server/AI/Commander/AI_Commander_Snapshot.sqf"
STRATEGY = MISSION / "Server/AI/Commander/AI_Commander_Strategy.sqf"


class AicomCarrierTargetPolicyTests(unittest.TestCase):
    def test_assign_towns_filters_every_selection_and_repick_path(self) -> None:
        source = ASSIGN.read_text(encoding="utf-8")

        self.assertIn(
            '((_x getVariable "sideID") != _sideID) && {!(_x getVariable ["wfbe_is_naval_hvt", false])}',
            source,
            "the shared uncaptured pool still admits naval HVTs into bootstrap/fallback selection",
        )
        self.assertIn(
            'if (_goto getVariable ["wfbe_is_naval_hvt", false]) then {',
            source,
            "a sticky pre-existing naval goto is not forcibly repicked",
        )
        self.assertIn(
            'if (_needs && {!_navalRetarget} && {(missionNamespace getVariable ["WFBE_C_AICOM_JOURNEY_COMMIT", 1]) > 0}) then {',
            source,
            "journey commitment can still suppress the mandatory naval repick",
        )
        self.assertIn(
            'if (_needs && {!_navalRetarget} && {[_team] Call WFBE_CO_FNC_CapLock}) then {',
            source,
            "capture lock can still suppress the mandatory naval repick",
        )
        self.assertIn(
            '&& {!(_allocT getVariable ["wfbe_is_naval_hvt", false])}',
            source,
            "the allocator handoff still accepts a naval target",
        )
        self.assertIn(
            '&& {!(_spearT getVariable ["wfbe_is_naval_hvt", false])}',
            source,
            "the primary spearhead path still accepts a naval target",
        )
        self.assertIn(
            '&& {!(_x getVariable ["wfbe_is_naval_hvt", false])}) then {_nearReachD',
            source,
            "the nearest-reachable path still accepts a naval target",
        )
        self.assertIn(
            '_target = [leader _team, _uncapturedF] Call WFBE_CO_FNC_GetClosestEntity;',
            source,
            "the absolute-nearest fallback no longer consumes the shared filtered pool",
        )

    def test_snapshot_and_strategy_never_publish_naval_candidates(self) -> None:
        snapshot = SNAPSHOT.read_text(encoding="utf-8")
        strategy = STRATEGY.read_text(encoding="utf-8")

        self.assertIn(
            'if (!(_x getVariable ["wfbe_is_naval_hvt", false])) then {\n\t\t\t_tgtTownObjs',
            snapshot,
            "the shared v2 snapshot still publishes naval capture candidates",
        )
        self.assertIn(
            'if (!(_x getVariable ["wfbe_is_naval_hvt", false])) then {\n\t\t\t\t_candTowns',
            strategy,
            "Strategy's direct-scan fallback still publishes naval spearheads",
        )
        self.assertIn(
            '&& {!(_fhPrim getVariable ["wfbe_is_naval_hvt", false])}) then {_fhValid = true};',
            strategy,
            "front-dwell hysteresis can still reinsert a stale naval primary",
        )


if __name__ == "__main__":
    unittest.main()
