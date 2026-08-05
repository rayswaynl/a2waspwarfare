#!/usr/bin/env python3
"""Contracts for client-local ambulance redeploy marker teardown at round end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
ACTION_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_AmbulanceRedeployCircles.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_AmbulanceRedeployCircles.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_AmbulanceRedeployCircles.sqf"),
)

ENDGAME_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {"
RING_CLEANUP = "{deleteMarkerLocal (_x select 1)} forEach (+_rings);"


class AmbulanceRedeployCirclesTerminalLifecycleTests(unittest.TestCase):
    def test_worker_stops_and_cleans_local_rings_at_round_end(self) -> None:
        for relative_path in ACTION_PATHS:
            source = (ROOT / relative_path).read_text(encoding="utf-8-sig")
            loop_start = source.index("while {true} do {")
            guard_start = source.index(ENDGAME_GUARD, loop_start)
            cleanup_start = source.index(RING_CLEANUP, guard_start)
            guard_end = source.index("};", guard_start)
            settings_start = source.index(
                'if !(missionNamespace getVariable ["WFBE_AMBULANCE_CIRCLES_ENABLED", true])',
                loop_start,
            )

            self.assertEqual(source.count(ENDGAME_GUARD), 1, relative_path)
            self.assertLess(loop_start, guard_start, relative_path)
            self.assertLess(guard_start, cleanup_start, relative_path)
            self.assertLess(cleanup_start, guard_end, relative_path)
            self.assertLess(guard_end, settings_start, relative_path)

    def test_maintained_mission_mirrors_match(self) -> None:
        reference = (ROOT / ACTION_PATHS[0]).read_bytes()
        for relative_path in ACTION_PATHS[1:]:
            self.assertEqual(reference, (ROOT / relative_path).read_bytes(), relative_path)


if __name__ == "__main__":
    unittest.main()
