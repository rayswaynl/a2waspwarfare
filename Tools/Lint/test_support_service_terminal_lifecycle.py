#!/usr/bin/env python3
"""Regression contract for aborting client service jobs at round end."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SERVICE_FILES = (
    "Client/Functions/Client_SupportRearm.sqf",
    "Client/Functions/Client_SupportRepair.sqf",
    "Client/Functions/Client_SupportRefuel.sqf",
)
ROUND_END_GUARD = "if (gameOver) exitWith {_cts = 0;};"
REFUND = "if (_cts == 0 && {_price > 0}) then {_price Call ChangePlayerFunds;};"


class SupportServiceTerminalLifecycleTests(unittest.TestCase):
    def test_support_workers_abort_and_refund_when_round_ends(self) -> None:
        for relative_path in SERVICE_FILES:
            sources = []
            for root in ROOTS:
                text = (root / relative_path).read_text(encoding="utf-8-sig")
                sources.append(text)

                loop = text.index("while {true} do {")
                sleep = text.index("sleep 1;", loop)
                guard = text.index(ROUND_END_GUARD, sleep)
                support_scan = text.index("//--- Check the distance & alive.", loop)
                refund = text.index(REFUND, guard)

                self.assertLess(sleep, guard, root.name)
                self.assertLess(guard, support_scan, root.name)
                self.assertLess(guard, refund, root.name)

            self.assertEqual(sources[0], sources[1], relative_path)
            self.assertEqual(sources[0], sources[2], relative_path)

        repair = (ROOTS[0] / SERVICE_FILES[1]).read_text(encoding="utf-8-sig")
        self.assertIn(
            '_veh setVariable ["wfbe_repair_inProgress", false];',
            repair,
        )


if __name__ == "__main__":
    unittest.main()
