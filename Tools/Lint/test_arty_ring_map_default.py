#!/usr/bin/env python3
"""Regression contract for terrain-aware artillery ring defaults."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


class ArtyRingMapDefaultTests(unittest.TestCase):
    def test_first_arty_ring_registration_is_map_aware(self) -> None:
        pattern = re.compile(
            r'if \(isNil "WFBE_C_ARTY_RING"\) then \{'
            r'\s*WFBE_C_ARTY_RING = 1;'
            r'\s*if \(\(toLower worldName\) in \["zargabad", "takistan"\]\) then \{WFBE_C_ARTY_RING = 0\};'
            r'\s*\};',
            re.MULTILINE,
        )
        for root in ROOTS:
            text = (root / "Common/Init/Init_CommonConstants.sqf").read_text(
                encoding="utf-8-sig"
            )
            self.assertRegex(text, pattern, root.name)
            self.assertEqual(
                text.count('if (isNil "WFBE_C_ARTY_RING")'),
                1,
                root.name,
            )


if __name__ == "__main__":
    unittest.main()
