#!/usr/bin/env python3
"""Contract for the skin-swap slot1-rejoin (fable/teambar-skinswap-rejoin).

Owner live-confirmed 2026-07-19 (own client RPT): both skin swaps that session re-set
COLONEL but never ran the rejoin - the new body stays at the join-order tail and the
A2 command bar renders the player #2+. Init_Client and Client_OnKilled already carry
the identical dance; this pins the third (previously missing) lifecycle point.

fix/teambar-slot1-ship-20260722: (1) every assertion now runs against BOTH the chernarus
source AND the Missions_Vanilla takistan mirror. The originals hard-coded chernarus only,
and that blind spot is exactly how the slot-1 server heal reached live takistan (wave0722g)
without ever landing on master. (2) Adds coverage for the mid-swap SERVER ping that heals a
SERVER/HC-local squadmate the client-side (`local _x`) rejoin can never move.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments

ROOT = Path(__file__).resolve().parents[2]
MISSIONS = {
    "chernarus": ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    "takistan": ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
}


def code(mission: Path, relative: str) -> str:
    return mask_comments((mission / relative).read_text(encoding="utf-8-sig"))


class SkinswapRejoinTests(unittest.TestCase):
    def test_skinswap_carries_the_same_flag_gated_rejoin_as_init_and_respawn(self) -> None:
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                swap = code(mission, "WASP/actions/SkinSelector/SkinSelector_Apply.sqf")
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
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                swap = code(mission, "WASP/actions/SkinSelector/SkinSelector_Apply.sqf")
                rejoin = swap.index("SkinSelector_Apply slot1-rejoin")
                self.assertLess(swap.index("_wasLeader) then {(group _newUnit) selectLeader"), rejoin)
                self.assertLess(swap.rindex("WFBE_SkinSelector_InProgress = false"), rejoin)
                self.assertLess(rejoin, swap.index("B6 COMPLETE"))

    def test_skinswap_pings_server_heal_after_client_rejoin(self) -> None:
        # fix/teambar-slot1-ship-20260722: the client-side rejoin above filters `local _x`, so a
        # mission-start / HC-owned AI squadmate (SERVER-local) is never moved and #2 recurs after a
        # mid-session skin swap. The swap must ALSO ping the server "update-teamleader" heal, which runs
        # WFBE_SE_FNC_TeambarSlot1Rejoin server-side where those units are local. The ping lives inside
        # the WFBE_C_PLAYER_TEAMBAR_FIRST flag gate (flag-off stays byte-identical) and after the client
        # rejoin, before the post-final probe / B6 COMPLETE log.
        ping = '["RequestSpecial", ["update-teamleader", WFBE_Client_Team, player]] Call WFBE_CO_FNC_SendToServer'
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                swap = code(mission, "WASP/actions/SkinSelector/SkinSelector_Apply.sqf")
                self.assertIn(ping, swap)
                self.assertLess(swap.index("SkinSelector_Apply slot1-rejoin"), swap.index(ping))
                self.assertLess(swap.index(ping), swap.index("B6 COMPLETE"))

    def test_server_heal_asserts_leader_first_no_not_leader_skip(self) -> None:
        # fix/teambar-slot1-ship-20260722 (fix 2): at a fresh connect the mission-start AI squadmate is
        # still the engine leader, so the old `not-leader` skip no-op'd the heal exactly when it was
        # needed. The shared server heal must instead selectLeader the human FIRST (client pattern) and
        # keep only the team-null / human-null / already-index-0 guards.
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                fn = code(mission, "Server/Functions/Server_TeambarSlot1Rejoin.sqf")
                self.assertNotIn('"not-leader"', fn)
                self.assertIn("(leader _tbTeam) != _tbHuman) then {_tbTeam selectLeader _tbHuman}", fn)
                self.assertIn('_tbSkip = "team-null"', fn)
                self.assertIn('_tbSkip = "human-null"', fn)
                self.assertIn("((units _tbTeam) select 0) == _tbHuman) exitWith", fn)

    def test_server_heal_is_wired_to_both_call_sites(self) -> None:
        # Registered once and invoked from the connect handler AND the respawn/connect ping receiver.
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                self.assertIn("WFBE_SE_FNC_TeambarSlot1Rejoin = Compile preprocessFileLineNumbers",
                              code(mission, "Server/Init/Init_Server.sqf"))
                self.assertIn('"connect"] Call WFBE_SE_FNC_TeambarSlot1Rejoin',
                              code(mission, "Server/Functions/Server_OnPlayerConnected.sqf"))
                self.assertIn('"teamleader-update"] Call WFBE_SE_FNC_TeambarSlot1Rejoin',
                              code(mission, "Server/Functions/Server_HandleSpecial.sqf"))

    def test_reference_implementations_unchanged(self) -> None:
        for name, mission in MISSIONS.items():
            for rel, marker in (("Client/Init/Init_Client.sqf", "Init_Client slot1-rejoin"),
                                ("Client/Functions/Client_OnKilled.sqf", "slot1-rejoin")):
                with self.subTest(mission=name, ref=rel):
                    self.assertIn(marker, code(mission, rel))


if __name__ == "__main__":
    unittest.main()
