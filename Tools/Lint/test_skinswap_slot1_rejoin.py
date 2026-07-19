#!/usr/bin/env python3
"""Contract for the skin-swap slot1-rejoin (fable/teambar-skinswap-rejoin).

Owner live-confirmed 2026-07-19 (own client RPT): both skin swaps that session re-set
COLONEL but never ran the rejoin - the new body stays at the join-order tail and the
A2 command bar renders the player #2+. Init_Client and Client_OnKilled already carry
the identical dance; this pins the third (previously missing) lifecycle point.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments

ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class SkinswapRejoinTests(unittest.TestCase):
    def test_skinswap_carries_the_same_flag_gated_rejoin_as_init_and_respawn(self) -> None:
        swap = code("WASP/actions/SkinSelector/SkinSelector_Apply.sqf")
        idx = swap.index("SkinSelector_Apply slot1-rejoin")
        block = swap[idx - 1600 : idx + 200]
        for token in (
            'WFBE_C_PLAYER_TEAMBAR_FIRST", 0]) > 0',
            "group player == WFBE_Client_Team",
            "leader (group player) == player",
            "((units group player) select 0) != player",
            "{!isPlayer _x} && {local _x}",
            "joinSilent",
            "selectLeader player",
        ):
            self.assertIn(token, block)

    def test_rejoin_runs_after_all_paths_settle_and_before_completion_log(self) -> None:
        swap = code("WASP/actions/SkinSelector/SkinSelector_Apply.sqf")
        rejoin = swap.index("SkinSelector_Apply slot1-rejoin")
        self.assertLess(swap.index("_wasLeader) then {(group _newUnit) selectLeader"), rejoin)
        self.assertLess(swap.rindex("WFBE_SkinSelector_InProgress = false"), rejoin)
        self.assertLess(rejoin, swap.index("B6 COMPLETE"))

    def test_reference_implementations_unchanged(self) -> None:
        for rel, marker in (("Client/Init/Init_Client.sqf", "Init_Client slot1-rejoin"),
                            ("Client/Functions/Client_OnKilled.sqf", "slot1-rejoin")):
            self.assertIn(marker, code(rel))


if __name__ == "__main__":
    unittest.main()

