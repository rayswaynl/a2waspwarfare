#!/usr/bin/env python3
"""Regression contract for the raw-object supply-value request receiver."""

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

RECEIVER = Path("Server/Functions/Server_PV_RequestSupplyValue.sqf")


def read(root: Path) -> str:
    return (root / RECEIVER).read_text(encoding="utf-8-sig")


class SupplyRequestObjectReferenceTests(unittest.TestCase):
    def test_every_mirror_rejects_unusable_object_before_dereference(self) -> None:
        for root in MAINTAINED_ROOTS:
            with self.subTest(root=root.name):
                text = read(root)
                code = mask_comments(text)
                player = code.find("_player = _this select 1")
                object_guard = code.find('typeName _player != "OBJECT"', player)
                null_guard = code.find("isNull _player", player)
                owner = code.find("_id = owner _player", player)
                side = code.find("side _player", player)
                owner_guard = code.find("_id <= 0", owner)
                reply = code.find("publicVariableClient", owner)

                self.assertGreaterEqual(player, 0)
                self.assertGreaterEqual(object_guard, player)
                self.assertGreaterEqual(null_guard, object_guard)
                self.assertGreaterEqual(owner, null_guard)
                self.assertGreaterEqual(side, owner)
                self.assertGreaterEqual(owner_guard, owner)
                self.assertGreaterEqual(reply, owner_guard)

    def test_mirrors_are_byte_identical(self) -> None:
        payloads = [read(root) for root in MAINTAINED_ROOTS]
        self.assertEqual(payloads[0], payloads[1])
        self.assertEqual(payloads[0], payloads[2])


if __name__ == "__main__":
    unittest.main()
