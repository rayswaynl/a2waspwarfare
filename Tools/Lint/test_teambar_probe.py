#!/usr/bin/env python3
"""Contract for the TEAMBAR reason-coded probe (fable/teambar-probe).

Required by the independent review of wasp-player-group-rank-order-diagnosis-20260718:
the #2-in-own-group instrumentation must capture EVERY guard input of the slot1-rejoin
mitigation, at every lifecycle transition, client-side AND server-side (UID-resolved),
so the first failing transition is named from the RPT.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class TeambarProbeTests(unittest.TestCase):
    def test_probe_captures_every_rejoin_guard_input(self) -> None:
        text = code("Client/Functions/Client_TeambarProbe.sqf")
        for token in (
            "WFBE_C_TEAMBAR_PROBE",
            "alivePlayer=",       # guard 1: alive player
            "sameTeam=",          # guard 2: group player == WFBE_Client_Team
            "isLeader=",          # guard 3: leader (group player) == player
            "arr0IsPlayer=",      # guard 4: (units group player) select 0 != player
            "playerRankId=",
            "rankId _u",          # per-unit rank
            "isPlayer _u",        # per-unit isPlayer
            "local _u",           # per-unit locality (the _slot1Others filter)
            "alive _u",           # per-unit alive (the _slot1Others filter)
            "TEAMBAR|v2|PROBE",
        ):
            self.assertIn(token, text)

    def test_all_lifecycle_transitions_are_probed_with_reason_codes(self) -> None:
        init = code("Client/Init/Init_Client.sqf")
        for phase in ('"init", "post-select"', '"init", "rejoin-check"', '"init", "rejoin-done"',
                      '"init", "rejoin-creategroup-null"', '"init", "rejoin-no-local-others"'):
            self.assertIn(phase, init)
        killed = code("Client/Functions/Client_OnKilled.sqf")
        for phase in ('"respawn", "rejoin-check"', '"respawn", "rejoin-done"',
                      '"respawn", "rejoin-creategroup-null"', '"respawn", "rejoin-no-local-others"'):
            self.assertIn(phase, killed)
        self.assertIn('"skinswap", "post-apply"', code("WASP/actions/SkinSelector/SkinSelector_Apply.sqf"))
        self.assertIn('"kicked", "post-transfer"', code("Client/Functions/Client_FNC_Groups.sqf"))

    def test_check_probe_precedes_the_guard_it_documents(self) -> None:
        init = code("Client/Init/Init_Client.sqf")
        self.assertLess(init.index('"init", "rejoin-check"'),
                        init.index('((units group player) select 0) != player'))
        killed = code("Client/Functions/Client_OnKilled.sqf")
        self.assertLess(killed.index('"respawn", "rejoin-check"'),
                        killed.index('((units group player) select 0) != player'))

    def test_server_side_uid_resolved_probe_exists(self) -> None:
        text = code("Server/Functions/Server_HandleSpecial.sqf")
        self.assertIn("TEAMBAR|v2|SVPROBE", text)
        for token in ("getPlayerUID _leader", "leaderIsGrpLeader=", "rankId _leader", "WFBE_C_TEAMBAR_PROBE"):
            self.assertIn(token, text)

    def test_registration_and_kill_switch(self) -> None:
        self.assertIn("Client_TeambarProbe.sqf", code("Client/Init/Init_Client.sqf"))
        self.assertIn('if (isNil "WFBE_C_TEAMBAR_PROBE") then {WFBE_C_TEAMBAR_PROBE = 1}',
                      code("Common/Init/Init_CommonConstants.sqf"))


if __name__ == "__main__":
    unittest.main()
