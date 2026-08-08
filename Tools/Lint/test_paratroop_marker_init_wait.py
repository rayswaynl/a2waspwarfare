#!/usr/bin/env python3
"""Regression contracts for the paratrooper marker client-init gate."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]
HANDLER_REL = Path("Client/PVFunctions/HandleParatrooperMarkerCreation.sqf")


class ParatroopMarkerInitWaitTests(unittest.TestCase):
    def test_marker_handler_has_a_real_time_client_init_deadline(self) -> None:
        for mission_dir in MISSION_DIRS:
            source = (mission_dir / HANDLER_REL).read_text(encoding="utf-8-sig")
            self.assertNotRegex(
                source,
                r"waitUntil\s*\{\s*clientInitComplete\s*\};",
                mission_dir.name,
            )
            self.assertRegex(
                source,
                r"(?s)_wClientInit\s*=\s*0;.*?"
                r"while\s*\{.*?_wClientInit\s*<\s*360.*?"
                r"uiSleep\s+0\.25.*?_wClientInit\s*=\s*_wClientInit\s*\+\s*1",
                mission_dir.name,
            )
            self.assertIn(
                "PARATROOP|MARKER_SKIP|reason=CLIENT_INIT_TIMEOUT",
                source,
                mission_dir.name,
            )

    def test_all_maintained_terrain_handlers_are_byte_identical(self) -> None:
        sources = [(mission_dir / HANDLER_REL).read_bytes() for mission_dir in MISSION_DIRS]
        self.assertTrue(all(b"\n" not in source.replace(b"\r\n", b"") for source in sources))
        self.assertTrue(all(source == sources[0] for source in sources[1:]))


if __name__ == "__main__":
    unittest.main()
