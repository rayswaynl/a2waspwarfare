#!/usr/bin/env python3
"""Regression contract for salvage claim ordering across all maintained mirrors."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SALVAGE_PATHS = (
    "Client/FSM/updatesalvage.sqf",
    "Client/Module/Skill/Skill_Salvage.sqf",
)
CLAIM = 'setVariable ["wfbe_trash_reap", true, true];'


class SalvageClaimOrderTests(unittest.TestCase):
    def test_every_salvage_path_claims_before_credit_and_local_delete(self) -> None:
        for mission_root in MISSION_ROOTS:
            for relative_path in SALVAGE_PATHS:
                source = mission_root / relative_path
                text = source.read_text(encoding="utf-8-sig")
                with self.subTest(source=source):
                    self.assertEqual(text.count(CLAIM), 1)
                    claim_index = text.index(CLAIM)
                    self.assertLess(
                        claim_index,
                        text.index("_overAllCost = _overAllCost + _salvageCost;"),
                    )
                    self.assertLess(claim_index, text.index("deleteVehicle _x;"))


if __name__ == "__main__":
    unittest.main()
