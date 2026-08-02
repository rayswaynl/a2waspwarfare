#!/usr/bin/env python3
"""Regression checks for player-built minefield budget accounting."""

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
REQUEST_DEFENSE = Path("Server/PVFunctions/RequestDefense.sqf")


def read(root: Path, relative_path: Path) -> str:
    return (root / relative_path).read_text(encoding="utf-8-sig")


class MinefieldBudgetRegistryTests(unittest.TestCase):
    def test_minefield_mines_keep_a_shared_side_and_field_identity(self) -> None:
        code = mask_comments(read(MAINTAINED_ROOTS[0], STATIONARY_DEFENSE))
        self.assertIn('_fieldID = str _defense;', code)
        self.assertEqual(code.count('mines set [count mines, [_mine, time, _side, _fieldID]];'), 3)

    def test_mine_budget_counts_distinct_live_fields_from_the_registry(self) -> None:
        code = mask_comments(read(MAINTAINED_ROOTS[0], REQUEST_DEFENSE))
        self.assertIn('forEach mines;', code)
        self.assertIn('_mineSide = _mineEntry select 2;', code)
        self.assertIn('_mineFieldID = _mineEntry select 3;', code)
        self.assertIn('!(_mineFieldID in _mineFields)', code)
        self.assertIn('_countM = count _mineFields;', code)

    def test_generated_mirrors_match_source(self) -> None:
        for relative_path in (STATIONARY_DEFENSE, REQUEST_DEFENSE):
            copies = [read(root, relative_path).encode("utf-8-sig") for root in MAINTAINED_ROOTS]
            self.assertEqual(len(set(copies)), 1, relative_path)


if __name__ == "__main__":
    unittest.main()
