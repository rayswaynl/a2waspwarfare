#!/usr/bin/env python3
"""Regression contract for unsupported-side artillery lookups."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
FUNCTION = "Common/Functions/Common_IsArtillery.sqf"


class IsArtilleryMissingRegistryTests(unittest.TestCase):
    def test_missing_or_invalid_side_registry_returns_no_artillery(self) -> None:
        for mission_root in MISSION_ROOTS:
            source = (mission_root / FUNCTION).read_text(encoding="utf-8-sig")
            self.assertIn(
                'missionNamespace getVariable [Format ["WFBE_%1_ARTILLERY_CLASSNAMES",_side], []]',
                source,
                mission_root.name,
            )
            self.assertIn(
                'if (typeName _artyNames != "ARRAY") then {_artyNames = []};',
                source,
                mission_root.name,
            )


if __name__ == "__main__":
    unittest.main()
