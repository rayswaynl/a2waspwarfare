#!/usr/bin/env python3
"""Regression checks for defensive vehicle crew-cost parameter construction."""

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
BUY_UNITS = Path("Client/GUI/GUI_Menu_BuyUnits.sqf")


def read(root: Path) -> str:
    return (root / BUY_UNITS).read_text(encoding="utf-8-sig")


class BuyUnitsCrewCostDefaultTests(unittest.TestCase):
    def test_non_infantry_params_fall_back_to_flat_crew_cost(self) -> None:
        code = mask_comments(read(MAINTAINED_ROOTS[0]))
        fallback = (
            'if (!_isInfantry && {isNil "_crewCostPerHead"}) then {\n'
            '\t\t\t\t\t\t_crewCostPerHead = missionNamespace getVariable '
            '"WFBE_C_UNITS_CREW_COST";\n'
            '\t\t\t\t\t};'
        )
        params = (
            '_params = if (_isInfantry) then '
            '{[_closest,_unit,[],_type,_cpt,_clientPaidCost]} else '
            '{[_closest,_unit,[profilenamespace getvariable '
            '"wfbe_c_driver_enabled_by_default" ,_gunner,_commander,_extracrew,'
            '_isLocked,_crewCostPerHead],_type,_cpt,_clientPaidCost]};'
        )
        fallback_at = code.find(fallback)
        params_at = code.find(params)
        self.assertGreaterEqual(fallback_at, 0)
        self.assertGreaterEqual(params_at, 0)
        self.assertLess(fallback_at, params_at)

    def test_generated_buy_menu_copies_match_source(self) -> None:
        copies = [read(root).encode("utf-8-sig") for root in MAINTAINED_ROOTS]
        self.assertEqual(len(set(copies)), 1)


if __name__ == "__main__":
    unittest.main()
