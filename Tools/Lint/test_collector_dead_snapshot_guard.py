#!/usr/bin/env python3
"""Regression contract for stale allDead entries in the garbage collector."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class CollectorDeadSnapshotGuardTests(unittest.TestCase):
    def test_stale_all_dead_snapshot_entry_is_null_guarded_before_getvariable(self) -> None:
        collector = code("Server/FSM/server_collector_garbage.sqf")
        self.assertIn(
            'if (!isNull _x && {isNil {_x getVariable "wfbe_trashable"}',
            collector,
        )


if __name__ == "__main__":
    unittest.main()
