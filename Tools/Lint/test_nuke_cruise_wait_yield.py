#!/usr/bin/env python3
"""Regression checks for the classic ICBM cruise wait scheduler yield."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

CRUISE_SCRIPT = Path("Client/Module/Nuke/nukeincoming.sqf")
EXPECTED_WAIT = (
    "waitUntil {sleep 0.05; !alive _cruise || {isNull _cruise} || "
    "{time > _deadline}};"
)


class NukeCruiseWaitYieldTests(unittest.TestCase):
    def test_classic_cruise_deadline_wait_yields_scheduler(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = (root / CRUISE_SCRIPT).read_text(encoding="utf-8-sig")
            with self.subTest(root=root):
                self.assertEqual(source.count(EXPECTED_WAIT), 1)


if __name__ == "__main__":
    unittest.main()
