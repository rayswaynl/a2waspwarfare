#!/usr/bin/env python3
"""Regression guard for the HC lobby-slot mechanism itself.

Unlike test_pack_pbo.py (synthetic fixtures, fast), this reads the REAL
mission.sqm for all three shipping terrains, because the invariant it checks
is a property of the actual authored slot data, not of the packer code.

The invariant: forceHeadlessClient=1 is proven inert on A2 OA 1.64 -client HC
connections (see commit 5add0bbfd2, "fix(hc): give the two HC CIV lobby
slots the lowest playable ids [correctness fix, no flag]") - the engine
excludes flagged slots from its own lowest-numeric-id auto-seat scan, so a
flagged slot is never actually selected. The ONLY thing that routes an HC
into a specific slot is holding the two lowest player="PLAY CDG" `id=`
values in the whole mission.sqm, combined with a description="Headless
Client N" label (which Tools/Pack/pack_pbo.py's _slot_capacity() reads to
exclude the slot from WF_MAXPLAYERS human-capacity accounting).

This file's own history shows this invariant has drifted silently multiple
times (Takistan shipped zero working HC slots for a period because none of
its four "Headless Client" labeled slots carried the flag at all; id values
and file order diverged more than once; see docs/design/HC-SLOT-SEATING.md
and docs/design/HC-CIV-SLOT-VERIFICATION-20260721.md). A future edit to any
mission.sqm (adding a new low-id logic marker, renumbering slots, etc.)
could silently break HC seating without any error being raised anywhere
else in the toolchain - this test is that error.

Run with:
    python -m pytest Tools/Pack/test_hc_slot_lowest_id.py -q
or:
    python Tools/Pack/test_hc_slot_lowest_id.py
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

TERRAINS = [
    ("Chernarus", REPO_ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "mission.sqm"),
    ("Takistan", REPO_ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "mission.sqm"),
    ("Zargabad", REPO_ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "mission.sqm"),
]

# Matches one player="PLAY CDG" unit block far enough to capture its id=,
# side=, and description= regardless of which order those attributes appear
# in relative to `player=` (id/side come BEFORE player= in this repo's
# authored slot shape; description comes after). Two passes: find id/side
# preceding player=, then description following it, anchored on the same
# id= value so mismatched attribute ordering elsewhere can't cross-match.
UNIT_BLOCK = re.compile(
    r'id=(?P<id>\d+);\s*side="(?P<side>[A-Z]+)";\s*vehicle="[^"]*";\s*'
    r'player="PLAY CDG";(?P<mid>.*?)description="(?P<desc>[^"]*)";',
    re.S,
)


def playable_slots(sqm_text: str) -> list[dict]:
    return [m.groupdict() for m in UNIT_BLOCK.finditer(sqm_text)]


class HcSlotLowestIdInvariant(unittest.TestCase):
    """For each shipping terrain, the two globally-lowest-id playable slots
    must be exactly the two slots labeled 'Headless Client N' - that label
    plus id ordering IS the HC-routing mechanism (no engine flag exists)."""

    def _check_terrain(self, label: str, path: Path) -> None:
        self.assertTrue(path.is_file(), f"{label}: mission.sqm not found at {path}")
        text = path.read_text(encoding="utf-8", errors="surrogateescape")

        slots = playable_slots(text)
        self.assertGreaterEqual(
            len(slots), 4, f"{label}: expected at least 4 playable slots, parsed {len(slots)}"
        )

        # No slot may carry forceHeadlessClient=1: proven inert AND actively
        # harmful (the engine's auto-seat scan skips flagged slots entirely),
        # so its presence anywhere means someone reintroduced dead/harmful
        # config, not a working reservation.
        flagged = [
            s for s in slots
            if re.search(r'(?m)^\s*forceHeadlessClient\s*=\s*[1-9][0-9]*\s*;', s["mid"])
        ]
        self.assertEqual(
            flagged, [],
            f"{label}: forceHeadlessClient=1 found on {len(flagged)} slot(s) - this flag is "
            "proven inert/harmful on A2 OA 1.64 -client HC connections (see commit 5add0bbfd2); "
            "HC reservation must be expressed via lowest id= + description only.",
        )

        hc_slots = [s for s in slots if s["desc"].startswith("Headless Client")]
        self.assertEqual(
            len(hc_slots), 2,
            f"{label}: expected exactly 2 slots with description starting 'Headless Client', "
            f"found {len(hc_slots)}: {[s['desc'] for s in hc_slots]}",
        )

        by_id = sorted(slots, key=lambda s: int(s["id"]))
        two_lowest_ids = {by_id[0]["id"], by_id[1]["id"]}
        hc_ids = {s["id"] for s in hc_slots}
        self.assertEqual(
            two_lowest_ids, hc_ids,
            f"{label}: the two globally-lowest playable id= values {sorted(int(i) for i in two_lowest_ids)} "
            f"are not the two 'Headless Client' slots (ids {sorted(int(i) for i in hc_ids)}) - "
            "the engine's lowest-id auto-seat scan would route an HC onto the wrong slot.",
        )

    def test_chernarus(self) -> None:
        self._check_terrain(*TERRAINS[0])

    def test_takistan(self) -> None:
        self._check_terrain(*TERRAINS[1])

    def test_zargabad(self) -> None:
        self._check_terrain(*TERRAINS[2])


if __name__ == "__main__":
    unittest.main()
