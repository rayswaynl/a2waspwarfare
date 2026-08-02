#!/usr/bin/env python3
"""Regression coverage for AICOM deep-drop horizontal arrival detection."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AIRLEG_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_AICOMAirLeg.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_AICOMAirLeg.sqf"),
)
HORIZONTAL_POS = "_hDropPos = getPosATL _h;"
HORIZONTAL_ARRIVAL = "(_hDropPos distance [_vdrop select 0, _vdrop select 1, _hDropPos select 2]) < 90"
LEGACY_3D_ARRIVAL = "(_h distance _vdrop) < 90"


class AicomAirLegDeepDropHorizontalArrivalTests(unittest.TestCase):
    def test_deep_drop_arrival_disregards_cruise_altitude(self) -> None:
        for relative_path in AIRLEG_PATHS:
            text = (ROOT / relative_path).read_text(encoding="utf-8")

            self.assertIn(HORIZONTAL_POS, text, f"arrival position is not captured in {relative_path}")
            self.assertIn(HORIZONTAL_ARRIVAL, text, f"arrival test is not horizontal-only in {relative_path}")
            self.assertNotIn(LEGACY_3D_ARRIVAL, text, f"3D arrival gate remains in {relative_path}")


if __name__ == "__main__":
    unittest.main()
