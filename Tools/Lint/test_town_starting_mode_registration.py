#!/usr/bin/env python3
"""Regression contracts for the server starting-mode registration handoff."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]
SERVER_INIT_REL = Path("Server/Init/Init_Towns.sqf")


class TownStartingModeRegistrationTests(unittest.TestCase):
    def test_starting_mode_waits_for_registered_towns_and_camps(self) -> None:
        source = (MISSION_DIRS[0] / SERVER_INIT_REL).read_text(encoding="utf-8-sig")
        gate_start = source.index("waitUntil {townInit};")
        gate_end = source.index("//--- Special Towns mode.", gate_start)
        gate = source[gate_start:gate_end]

        self.assertIn(
            '_townExpected = missionNamespace getVariable ["totalTowns", 0];',
            gate,
        )
        self.assertIn("_wTownReady = 0;", gate)
        self.assertIn("count towns", gate)
        self.assertIn('isNil {_x getVariable "camps"}', gate)
        self.assertIn("TOWNINIT|v1|START_MODE_DEFER", gate)
        self.assertIn("townInitServer = true;", gate)

    def test_normal_town_server_release_stays_after_starting_mode(self) -> None:
        source = (MISSION_DIRS[0] / SERVER_INIT_REL).read_text(encoding="utf-8-sig")
        switch_index = source.index("//--- Special Towns mode.")
        self.assertGreater(source.rfind("townInitServer = true;"), switch_index)

    def test_all_maintained_server_town_files_are_byte_identical(self) -> None:
        sources = [(mission_dir / SERVER_INIT_REL).read_bytes() for mission_dir in MISSION_DIRS]
        self.assertTrue(all(b"\n" not in source.replace(b"\r\n", b"") for source in sources))
        self.assertTrue(all(source == sources[0] for source in sources[1:]))


if __name__ == "__main__":
    unittest.main()
