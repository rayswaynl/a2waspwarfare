#!/usr/bin/env python3
"""Contract for the camp null-count fix (fable/camp-null-count).

Owner live ZG deadlock 2026-07-19: a camp logic deleted mid-match (cmdcon44q loss
class) stayed in GetTotalCamps but could never appear in GetTotalCampsOnSide, so
every Total == OnSide consumer (capture gate server_town.sqf:275-281, respawn
eligibility, BuyUnits UI) wedged forever, and a deleted logic is unrepairable.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments

ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


def model_total(camps):
    """Python mirror of the fixed Common_GetTotalCamps."""
    if camps is None or len(camps) == 0:
        return 1
    live = sum(1 for c in camps if c is not None)
    return live if live > 0 else 1


def model_on_side(camps, side):
    """Python mirror of the fixed Common_GetTotalCampsOnSide."""
    if camps is None or len(camps) == 0:
        return 1
    live = sum(1 for c in camps if c is not None)
    if live == 0:
        return 1
    return sum(1 for c in camps if c is not None and c == side)


class CampNullCountTests(unittest.TestCase):
    def test_deleted_camp_no_longer_deadlocks_capture(self) -> None:
        # Town with 2 camps, one deleted, survivor held by the attacker:
        camps = ["west", None]
        self.assertEqual(model_total(camps), 1)
        self.assertEqual(model_on_side(camps, "west"), 1)
        self.assertEqual(model_total(camps), model_on_side(camps, "west"))  # capture gate passes

    def test_all_deleted_behaves_like_no_camp_town(self) -> None:
        camps = [None, None]
        self.assertEqual(model_total(camps), 1)
        self.assertEqual(model_on_side(camps, "west"), 1)
        self.assertEqual(model_on_side(camps, "east"), 1)  # symmetric, same as camps=[]

    def test_healthy_towns_unchanged(self) -> None:
        camps = ["west", "east"]
        self.assertEqual(model_total(camps), 2)
        self.assertEqual(model_on_side(camps, "west"), 1)
        self.assertNotEqual(model_total(camps), model_on_side(camps, "west"))  # still gated
        self.assertEqual(model_on_side(["west", "west"], "west"), 2)           # full hold passes

    def test_source_counts_only_live_camps_with_floor(self) -> None:
        total = code("Common/Functions/Common_GetTotalCamps.sqf")
        self.assertIn("{if (!isNull _x) then {_total = _total + 1}} forEach _camps", total)
        self.assertIn("if (_total == 0) exitWith {1}", total)
        self.assertNotIn("\ncount _camps", total.replace("count _camps == 0", ""))
        on_side = code("Common/Functions/Common_GetTotalCampsOnSide.sqf")
        self.assertIn("{if (!isNull _x) then {_live = _live + 1}} forEach _camps", on_side)
        self.assertIn("if (_live == 0) exitWith {1}", on_side)

    def test_division_consumer_protected(self) -> None:
        # server_town.sqf:295 divides by GetTotalCamps - the floor of 1 must hold on every path.
        self.assertGreaterEqual(model_total(None), 1)
        self.assertGreaterEqual(model_total([]), 1)
        self.assertGreaterEqual(model_total([None]), 1)


if __name__ == "__main__":
    unittest.main()
