#!/usr/bin/env python3
"""Regression contract for the retired gear-filler keybind path."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]
KEYBIND_REL = Path("Client/Init/Init_Keybind.sqf")


class InertGearHotkeyTests(unittest.TestCase):
    def test_retired_gear_filler_handler_is_not_compiled(self) -> None:
        for mission_dir in MISSION_DIRS:
            source = (mission_dir / KEYBIND_REL).read_text(encoding="utf-8-sig")
            self.assertNotIn("WF_Gear_Hotkeys", source, mission_dir.name)
            for action in ("User15", "User16", "User17", "User18", "User19", "User20"):
                self.assertNotIn(f'actionKeys "{action}"', source, mission_dir.name)
            self.assertNotIn("setVariable ['filler'", source, mission_dir.name)

    def test_maintained_keybind_mirrors_remain_byte_identical(self) -> None:
        sources = [(mission_dir / KEYBIND_REL).read_bytes() for mission_dir in MISSION_DIRS]
        self.assertTrue(all(b"\n" not in source.replace(b"\r\n", b"") for source in sources))
        self.assertTrue(all(source == sources[0] for source in sources[1:]))


if __name__ == "__main__":
    unittest.main()
