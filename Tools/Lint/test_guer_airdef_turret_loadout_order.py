#!/usr/bin/env python3
"""Static contracts for GUER AirDef turret loadout application order."""

from pathlib import Path
import re
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Server_GuerAirDef.sqf"


class GuerAirDefTurretLoadoutOrderTests(unittest.TestCase):
    def test_turret_launchers_precede_their_magazines_after_a_swap(self) -> None:
        text = mask_comments(SOURCE.read_text(encoding="utf-8-sig"))
        flare_start = text.index("_applyKaFlares = {")
        flare_end = text.index("[_v, _n] Spawn {", flare_start)
        flare_block = text[flare_start:flare_end]
        self.assertLess(flare_block.index("addWeaponTurret"), flare_block.index("addMagazineTurret"))

        for loadout in ("AT", "AA"):
            with self.subTest(loadout=loadout):
                blocks = re.findall(rf"if \(_use{loadout}\) then \{{(?P<body>.*?)\n\s*\}};", text, re.DOTALL)
                self.assertEqual(2, len(blocks))
                for block in blocks:
                    self.assertLess(block.index("addWeaponTurret"), block.index("addMagazineTurret"))


if __name__ == "__main__":
    unittest.main()
