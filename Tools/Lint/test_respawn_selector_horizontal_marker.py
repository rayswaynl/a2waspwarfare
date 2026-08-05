#!/usr/bin/env python3
"""Regression coverage for horizontal-only respawn selector marker tracking."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SELECTOR_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_UI_Respawn_Selector.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_UI_Respawn_Selector.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_UI_Respawn_Selector.sqf"),
)
TRACK_POS = "_trackPos = getPos WFBE_MarkerTracking;"
HORIZONTAL_DISTANCE = "_markerPos distance [_trackPos select 0, _trackPos select 1, 0] > 1"
LEGACY_DISTANCE = "getMarkerPos _marker distance WFBE_MarkerTracking > 1"


class RespawnSelectorHorizontalMarkerTests(unittest.TestCase):
    def test_selector_ignores_vertical_only_tracking_motion(self) -> None:
        for relative_path in SELECTOR_PATHS:
            text = (ROOT / relative_path).read_text(encoding="utf-8")

            self.assertIn(TRACK_POS, text, f"tracking position is not captured in {relative_path}")
            self.assertIn(HORIZONTAL_DISTANCE, text, f"marker movement is not horizontal-only in {relative_path}")
            self.assertNotIn(LEGACY_DISTANCE, text, f"3D marker/object distance remains in {relative_path}")


if __name__ == "__main__":
    unittest.main()
