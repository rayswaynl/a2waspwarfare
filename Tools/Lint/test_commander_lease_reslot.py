#!/usr/bin/env python3
"""Contracts for relinquishing a commander lease after a same-side re-slot."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEASE = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Functions"
    / "Common_CommanderLease.sqf"
)


def request_reclaim_block() -> str:
    code = LEASE.read_text(encoding="utf-8-sig")
    start = code.index("WFBE_CO_FNC_CommanderLeaseRequestReclaim = {")
    end = code.index("WFBE_CO_FNC_CommanderLeaseRequestStandDown = {", start)
    return code[start:end]


class CommanderLeaseReslotContracts(unittest.TestCase):
    def test_same_uid_different_group_enqueues_versioned_standdown_before_reclaim(self) -> None:
        block = request_reclaim_block()
        mismatch = (
            'if (typeName _lease == "ARRAY" && {count _lease >= 6} '
            '&& {(_lease select 0) == _uid} && {(_lease select 2) != (str _team)}) then {'
        )
        standdown = (
            '[_side, (_lease select 5)] Call '
            'WFBE_CO_FNC_CommanderLeaseRequestStandDown;'
        )
        reclaim = (
            '_logic setVariable ["wfbe_commander_lease_cmd_reclaim", '
            '[_uid, _team, time]];'
        )

        self.assertIn(mismatch, block)
        self.assertIn(standdown, block)
        self.assertIn(reclaim, block)
        self.assertLess(block.index(standdown), block.index(reclaim))
        self.assertNotIn("WFBE_CO_FNC_CommanderLeaseRequestGrant", block)

    def test_reslot_cleanup_requires_uid_membership_in_the_new_group(self) -> None:
        block = request_reclaim_block()
        membership = (
            'if (!isNull _x && {isPlayer _x} && '
            '{(getPlayerUID _x) == _uid}) then {_member = true};'
        )
        standdown = (
            '[_side, (_lease select 5)] Call '
            'WFBE_CO_FNC_CommanderLeaseRequestStandDown;'
        )

        self.assertIn("_member = false;", block)
        self.assertIn(membership, block)
        self.assertIn("forEach units _team;", block)
        self.assertIn(standdown, block)
        self.assertLess(block.index(membership), block.index(standdown))


if __name__ == "__main__":
    unittest.main()
