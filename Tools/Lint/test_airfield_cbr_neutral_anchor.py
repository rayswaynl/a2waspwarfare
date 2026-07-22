#!/usr/bin/env python3
"""Regression checks for permanent airfield CBR target neutrality."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVER_TOWN_PATHS = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "FSM"
    / "server_town.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Server"
    / "FSM"
    / "server_town.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Server"
    / "FSM"
    / "server_town.sqf",
)
BUILDABLE_CBR_PATH = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "Construction"
    / "Construction_SmallSite.sqf"
)


class AirfieldCbrNeutralAnchorTests(unittest.TestCase):
    def test_airfield_cbr_uses_neutral_anchor_without_changing_buildable_targeting(self) -> None:
        sources = [path.read_text(encoding="utf-8") for path in SERVER_TOWN_PATHS]

        for path, source in zip(SERVER_TOWN_PATHS, sources):
            with self.subTest(path=path):
                self.assertIn('_radarClass = "Land_Antenna";', source)
                self.assertNotIn("Gue_WarfareBArtilleryRadar", source)
                self.assertNotIn("TK_GUE_WarfareBArtilleryRadar_EP1", source)
                self.assertNotIn("_radar setCaptive true;", source)
                self.assertNotIn("WFBE_NEURODEF_CBRADAR_", source)
                self.assertNotIn(
                    "[_radar, _dressTpl, 0] Call WFBE_SE_FNC_SpawnStructureDressing;",
                    source,
                )
                self.assertIn('_radar setVariable ["wfbe_cbr_radius", 2000, true];', source)
                self.assertIn('_radar addEventHandler ["HandleDamage", {0}];', source)
                self.assertIn('_location setVariable ["wfbe_airfield_cbr", _radar, true];', source)

        self.assertEqual(sources[1:], [sources[0], sources[0]])

        buildable_source = BUILDABLE_CBR_PATH.read_text(encoding="utf-8")
        self.assertIn('if (_rlType == "CBRadar"', buildable_source)
        self.assertNotIn("setCaptive", buildable_source)
        self.assertIn("WFBE_NEURODEF_CBRADAR_", buildable_source)


if __name__ == "__main__":
    unittest.main()
