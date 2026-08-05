#!/usr/bin/env python3
"""Contracts for the client-local GUER barrel-bomb cooldown lifecycle."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
ACTION_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Action/Action_GuerHeliBombCall.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Action/Action_GuerHeliBombCall.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Action/Action_GuerHeliBombCall.sqf"),
)

ENDGAME_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {deleteMarkerLocal _marker;};"


class GuerHeliBombTerminalLifecycleTests(unittest.TestCase):
    def test_marker_worker_cleans_up_and_stops_before_ready_notification(self) -> None:
        for relative_path in ACTION_PATHS:
            source = (ROOT / relative_path).read_text(encoding="utf-8-sig")
            worker_start = source.index("[_m, _p, _start, _cool] spawn {")
            loop_start = source.index("while {true} do {", worker_start)
            guard_index = source.index(ENDGAME_GUARD, loop_start)
            null_player_index = source.index("if (isNull _player) exitWith {};", loop_start)
            ready_title_index = source.index("titleText ['Barrel bomb heli ready.", loop_start)

            self.assertEqual(source.count(ENDGAME_GUARD), 1, relative_path)
            self.assertLess(loop_start, guard_index, relative_path)
            self.assertLess(guard_index, null_player_index, relative_path)
            self.assertLess(guard_index, ready_title_index, relative_path)

    def test_maintained_mission_mirrors_match(self) -> None:
        reference = (ROOT / ACTION_PATHS[0]).read_bytes()
        for relative_path in ACTION_PATHS[1:]:
            self.assertEqual(reference, (ROOT / relative_path).read_bytes(), relative_path)


if __name__ == "__main__":
    unittest.main()
