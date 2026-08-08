#!/usr/bin/env python3
"""Regression checks for the carrier SCUD cooldown transport."""

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

SCUD_SERVER = Path("Server/Support/Support_ScudStrike.sqf")
GUER_MENU = Path("Client/GUI/GUI_Menu_GuerDrones.sqf")


class ScudCooldownTransportTests(unittest.TestCase):
    def test_server_and_client_share_public_carrier_cooldown_state(self) -> None:
        for root in MAINTAINED_ROOTS:
            with self.subTest(root=root.name):
                server = mask_comments(
                    (root / SCUD_SERVER).read_text(encoding="utf-8-sig")
                )
                client = mask_comments(
                    (root / GUER_MENU).read_text(encoding="utf-8-sig")
                )

                self.assertIn(
                    '_lastFired = _platform getVariable ["wfbe_scud_last", -99999];',
                    server,
                )
                self.assertIn(
                    '_platform setVariable ["wfbe_scud_last", _now, true];', server
                )
                self.assertIn(
                    '_platform setVariable ["wfbe_scud_last", _lastFired, true];',
                    server,
                )
                self.assertIn(
                    '_scudLast = _platform getVariable ["wfbe_scud_last", -99999];',
                    client,
                )
                self.assertNotIn('Format ["WFBE_SCUD_LAST_%1", str _platform]', server)
                self.assertNotIn('Format ["WFBE_SCUD_LAST_%1", str _platform]', client)


if __name__ == "__main__":
    unittest.main()
