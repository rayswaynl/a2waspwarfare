#!/usr/bin/env python3
"""Regression contract for player-safe AICOM stranded-artillery recycling.

These are static source contracts: they pin the two required race checks but do
not claim a live Arma runtime exercise.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
BASE_SELL = CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander_BaseSell.sqf"
SAFE_CREW_DELETE = CHERNARUS / "Common" / "Functions" / "Common_SafeCrewDelete.sqf"


def code(path: Path) -> str:
    return mask_comments(path.read_text(encoding="utf-8-sig"))


class BaseSellPlayerCrewGuardContract(unittest.TestCase):
    def test_type_tags_use_the_parallel_type_roster_for_cost_and_live_count(self) -> None:
        base_sell = code(BASE_SELL)
        self.assertIn(
            '"WFBE_%1STRUCTURES", _sideText',
            base_sell,
            "BaseSell must index wfbe_structure_type tags against the type roster",
        )
        self.assertNotIn(
            "STRUCTURENAMES",
            base_sell,
            "class-name roster cannot be used to index logical structure type tags",
        )
        self.assertEqual(base_sell.count('_idx = _types find _stype;'), 3)

    def test_player_boarding_vetoes_sale_before_refund_or_reap(self) -> None:
        base_sell = code(BASE_SELL)
        sell_block = base_sell[base_sell.index('if (_victimType == "CommanderArtillery") then {'):]
        guard = 'if (({isPlayer _x} count (crew _victim)) > 0) exitWith {'
        self.assertIn(guard, sell_block)
        self.assertLess(sell_block.index(guard), sell_block.index('if (_refund > 0) then'))
        self.assertLess(sell_block.index(guard), sell_block.index('Spawn WFBE_CO_FNC_SafeCrewDelete'))

    def test_safe_crew_delete_rechecks_current_crew_before_each_delete_and_hull_reap(self) -> None:
        safe_crew = code(SAFE_CREW_DELETE)
        recheck = '_playerCrewPresent = ({isPlayer _x} count (crew _hull)) > 0;'
        self.assertGreaterEqual(safe_crew.count(recheck), 2)
        self.assertIn('if (!_playerCrewPresent && {!isNull _crewMember}', safe_crew)
        self.assertIn('if (_alsoDeleteHull && {!isNull _hull} && {!_playerCrewPresent}) then {', safe_crew)


if __name__ == "__main__":
    unittest.main()
