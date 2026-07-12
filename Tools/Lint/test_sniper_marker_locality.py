#!/usr/bin/env python3
"""Regression coverage for Sniper spot-marker locality."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SNIPER_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Sniper.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Module/Skill/Skill_Sniper.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Module/Skill/Skill_Sniper.sqf"),
    Path("Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Client/Module/Skill/Skill_Sniper.sqf"),
)
LOCAL_CREATE = "createMarkerLocal [_markerName,_screenPos];"
GLOBAL_TEXT = "_markerName setMarkerText Format ['SPOTTED: %1',_markertime];"
LOCAL_TEXT = "_markerName setMarkerTextLocal Format ['SPOTTED: %1',_markertime];"


class SniperMarkerLocalityTests(unittest.TestCase):
    def test_initial_spot_marker_text_stays_local(self) -> None:
        for relative_path in SNIPER_PATHS:
            text = (ROOT / relative_path).read_text(encoding="utf-8")

            self.assertIn(LOCAL_CREATE, text, f"local marker creation is missing in {relative_path}")
            self.assertNotIn(GLOBAL_TEXT, text, f"local marker is globalized in {relative_path}")
            self.assertEqual(text.count(LOCAL_TEXT), 1, f"initial local text setter is wrong in {relative_path}")
            self.assertLess(text.index(LOCAL_CREATE), text.index(LOCAL_TEXT))


if __name__ == "__main__":
    unittest.main()
