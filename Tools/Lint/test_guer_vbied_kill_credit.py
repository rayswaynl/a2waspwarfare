#!/usr/bin/env python3
"""Regression contract for direct GUER VBIED kill settlement.

The VBIED driver dies with the blast, so RequestOnUnitKilled exits before its
normal stats block.  The direct settlement path must therefore record the
same category-aware kill stat for each confirmed-dead snapshot victim.
"""

import unittest
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = Path("Server/Functions/Server_HandleSpecial.sqf")


def vbied_credit_block(root: Path) -> str:
    code = mask_comments((root / RELATIVE).read_text(encoding="utf-8-sig"))
    start = code.find('getVariable ["WFBE_C_GUER_VBIED_CREDIT_KILLS", 1]')
    if start == -1:
        return ""
    end = code.find('diag_log ("GUERVBIED|v1|', start)
    return code[start:end]


class GuerVbiedKillCreditTests(unittest.TestCase):
    def test_direct_settlement_records_category_aware_player_kills(self) -> None:
        for root in MAINTAINED_ROOTS:
            block = vbied_credit_block(root)
            self.assertIn("WFBE_STAT_KILLS_INFANTRY", block)
            self.assertIn("WFBE_STAT_KILLS_AIR", block)
            self.assertIn("WFBE_STAT_KILLS_STATIC", block)
            self.assertIn("WFBE_STAT_KILLS_VEHICLE", block)
            self.assertIn("WFBE_SE_FNC_RecordStat", block)
            self.assertIn("WFBE_STAT_PVP_KILLS", block)


if __name__ == "__main__":
    unittest.main()
