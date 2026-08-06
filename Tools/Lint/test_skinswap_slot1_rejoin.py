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

    def test_skinswap_pings_server_heal_after_client_rejoin(self) -> None:
        # The client-side rejoin filters local AI, while mission-start/HC-owned AI is server-local.
        # The wave tip already carries the ping as a separate multiplayer-safe call; the new server
        # helper gates the actual reorder on WFBE_C_PLAYER_TEAMBAR_FIRST.
        swap = code("WASP/actions/SkinSelector/SkinSelector_Apply.sqf")
        ping = '["RequestSpecial", ["update-teamleader", WFBE_Client_Team, player]] Call WFBE_CO_FNC_SendToServer'
        gate = swap.index('if ((missionNamespace getVariable ["WFBE_C_PLAYER_TEAMBAR_FIRST", 0]) > 0) then {')
        rejoin = swap.index("SkinSelector_Apply slot1-rejoin", gate)
        self.assertIn(ping, swap)
        self.assertLess(rejoin, swap.index(ping))
        self.assertLess(swap.index(ping), swap.index("B6 COMPLETE"))
        self.assertEqual(swap.count(ping), 1)

    def test_server_heal_asserts_leader_first_and_is_wired_to_both_call_sites(self) -> None:
        fn = code("Server/Functions/Server_TeambarSlot1Rejoin.sqf")
        self.assertNotIn('"not-leader"', fn)
        self.assertIn("(leader _tbTeam) != _tbHuman) then {_tbTeam selectLeader _tbHuman}", fn)
        self.assertIn('_tbSkip = "team-null"', fn)
        self.assertIn('_tbSkip = "human-null"', fn)
        self.assertIn('!(_tbHuman in (units _tbTeam))}) then {_tbSkip = "not-member"}', fn)
        self.assertIn("((units _tbTeam) select 0) == _tbHuman) exitWith", fn)

        self.assertIn("WFBE_SE_FNC_TeambarSlot1Rejoin = Compile preprocessFileLineNumbers",
                      code("Server/Init/Init_Server.sqf"))
        self.assertIn('"connect"] Call WFBE_SE_FNC_TeambarSlot1Rejoin',
                      code("Server/Functions/Server_OnPlayerConnected.sqf"))
        self.assertIn('"teamleader-update"] Call WFBE_SE_FNC_TeambarSlot1Rejoin',
                      code("Server/Functions/Server_HandleSpecial.sqf"))

    def test_reference_implementations_unchanged(self) -> None:
        for rel, marker in (("Client/Init/Init_Client.sqf", "Init_Client slot1-rejoin"),
                            ("Client/Functions/Client_OnKilled.sqf", "slot1-rejoin")):
            self.assertIn(marker, code(rel))


if __name__ == "__main__":
    unittest.main()

