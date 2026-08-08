#!/usr/bin/env python3
"""Regression contract for cross-machine spectator-event timestamps."""

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
FEED = "Common/Functions/Common_SpectatorEventFeed.sqf"


def code_without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return "\n".join(line.split("//", 1)[0] for line in text.splitlines())


class SpectatorEventClockDomainTests(unittest.TestCase):
    def test_hc_event_and_server_packet_stamps_share_server_time(self) -> None:
        """HC events are aged against the server packet, never against per-machine `time`."""
        for root in ROOTS:
            code = code_without_comments((root / FEED).read_text(encoding="utf-8"))
            self.assertIn("WFBE_SPECTATOR_EVENTS = [_seq, serverTime, _batch]", code)
            self.assertEqual(4, code.count("[serverTime, _p2 select 0, _p2 select 1,"))
            self.assertNotIn("[time, _p2 select 0, _p2 select 1,", code)


if __name__ == "__main__":
    unittest.main()
