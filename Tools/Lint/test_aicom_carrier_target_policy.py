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
    def test_zero_legal_land_targets_scrubs_stale_carrier_orders_before_exit(self) -> None:
        source = ASSIGN.read_text(encoding="utf-8")

        scrub = source.index("NO_LEGAL_TOWN_SCRUB")
        early_exit = source.index("if (count _uncaptured == 0) exitWith {};")
        self.assertLess(
            scrub,
            early_exit,
            "the no-land-target exit still runs before stale carrier orders are neutralized",
        )
        pre_exit = source[scrub:early_exit]
        self.assertIn('[_team, "wfbe_teamgoto", objNull] Call WFBE_CO_FNC_GroupGetBool', pre_exit)
        self.assertIn('_goto getVariable ["wfbe_is_naval_hvt", false]', pre_exit)
        self.assertIn('_team setVariable ["wfbe_teamgoto", objNull, true];', pre_exit)
        self.assertIn('_team setVariable ["wfbe_aicom_townorder", [], false];', pre_exit)
        self.assertIn('_team setVariable ["wfbe_aicom_dispatch_open", false];', pre_exit)
        self.assertIn('_team setVariable ["wfbe_aicom_route", [], true];', pre_exit)
        self.assertIn('_team setVariable ["wfbe_teammode", "towns", true];', pre_exit)
        self.assertIn('"towns", getPos (leader _team)], true];', pre_exit)
        self.assertIn('[_team, getPos (leader _team), "MOVE", 20] Call AIMoveTo;', pre_exit)

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
