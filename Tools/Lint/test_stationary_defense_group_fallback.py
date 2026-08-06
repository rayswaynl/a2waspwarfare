#!/usr/bin/env python3
"""Regression checks for player/base static-defense crew-group allocation."""

from __future__ import annotations

import unittest
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
STATIONARY_DEFENSE = Path("Server/Construction/Construction_StationaryDefense.sqf")


def read(root: Path) -> str:
    return (root / STATIONARY_DEFENSE).read_text(encoding="utf-8-sig")


class StationaryDefenseGroupFallbackTests(unittest.TestCase):
    def test_failed_area_group_creation_uses_the_existing_side_defense_group(self) -> None:
        code = mask_comments(read(MAINTAINED_ROOTS[0]))
        create = '_team = [_side, "defense"] Call WFBE_CO_FNC_CreateGroup;'
        fallback = '_team = missionNamespace getVariable Format ["WFBE_%1_DefenseTeam", _side];'
        self.assertGreaterEqual(code.find(create), 0)
        self.assertGreaterEqual(code.find(fallback), 0)
        self.assertLess(code.find(create), code.find(fallback))

    def test_generated_stationary_defense_copies_match_source(self) -> None:
        copies = [read(root).encode("utf-8-sig") for root in MAINTAINED_ROOTS]
        self.assertEqual(len(set(copies)), 1)


if __name__ == "__main__":
    unittest.main()
