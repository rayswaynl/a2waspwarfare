#!/usr/bin/env python3
"""Contract for consolidated client marker teardown at mission end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
MARKER_LOOP = Path("Common/Common_MarkerLoop.sqf")


class MarkerLoopLifecycleTests(unittest.TestCase):
    def test_marker_worker_stops_and_cleans_local_state_at_game_over(self) -> None:
        for mission in MISSIONS:
            source = (mission / MARKER_LOOP).read_text(encoding="utf-8-sig")

            self.assertIn("while {!gameOver} do {", source, mission.name)
            self.assertNotIn("while {true} do {", source, mission.name)

            cleanup = source[source.index("//--- round-end cleanup:") :]
            for statement in (
                "deleteMarkerLocal _markerName",
                'deleteMarkerLocal "wfbe_aicom_objective_mk"',
                "WFBE_CL_UnitMarkerRegistry = [];",
                "WFBE_CL_AARMarkerRegistry = [];",
                "WFBE_CL_UnitMarkerLedger = [];",
            ):
                self.assertIn(statement, cleanup, mission.name)

    def test_all_map_mirrors_are_byte_identical_and_crlf(self) -> None:
        sources = [(mission / MARKER_LOOP).read_bytes() for mission in MISSIONS]

        for source in sources:
            self.assertNotIn(b"\n", source.replace(b"\r\n", b""))
        self.assertTrue(all(source == sources[0] for source in sources[1:]))


if __name__ == "__main__":
    unittest.main()
