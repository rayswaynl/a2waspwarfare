#!/usr/bin/env python3
"""Regression checks for player-facing fixed-sleep channels."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

LOCKPICK = Path("Client/Action/Action_GuerLockpick.sqf")


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


class FixedSleepClockDeadlineTests(unittest.TestCase):
    def test_lockpick_uses_a_time_deadline_for_progress_and_completion(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, LOCKPICK))
            with self.subTest(root=root):
                self.assertRegex(
                    source,
                    r'_started\s*=\s*time;\s*_deadline\s*=\s*_started\s*\+\s*_dur;',
                )
                self.assertRegex(source, r'while\s*\{\s*time\s*<\s*_deadline\s*&&\s*_ok\s*\}')
                self.assertRegex(source, r'\(time\s*-\s*_started\)\s*/\s*_dur')
                self.assertNotIn('_t = _t + 1', source)


if __name__ == "__main__":
    unittest.main()
