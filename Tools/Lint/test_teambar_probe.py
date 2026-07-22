#!/usr/bin/env python3
"""Contract for the TEAMBAR reason-coded probe (fable/teambar-probe, round 2).

Round-2 review additions: buy-unit, generic group-transfer, JIP field, and heartbeat
coverage; full-member capture (no 8-member truncation); skin-swap probe AFTER the final
fallback join; server probe phase-stamped pre-client-rejoin; wave0721 arming ruling
(2026-07-21) flipped the probe default 0->1.

fix/teambar-slot1-ship-20260722: every assertion now runs against BOTH the chernarus
source AND the Missions_Vanilla takistan mirror. The originals hard-coded chernarus only;
that blind spot is how live takistan drift (the un-shipped slot-1 server heal) went uncaught.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = {
    "chernarus": ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    "takistan": ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    "zargabad": ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
}


def code(mission: Path, relative: str) -> str:
    return mask_comments((mission / relative).read_text(encoding="utf-8-sig"))


class TeambarProbeTests(unittest.TestCase):
    def test_probe_captures_every_rejoin_guard_input_for_all_members(self) -> None:
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                text = code(mission, "Client/Functions/Client_TeambarProbe.sqf")
                for token in (
                    'WFBE_C_TEAMBAR_PROBE", 0]',   # round-2: default OFF
                    "alivePlayer=",
                    "sameTeam=",
                    "isLeader=",
                    "arr0IsPlayer=",
                    "playerRankId=",
                    "jip=",                        # round-2: JIP discrimination
                    "didJIP",
                    "rank _u",  # A2-safe: rankId is A3-only (wave0721 live burn)
                    "isPlayer _u",
                    "local _u",
                    "alive _u",
                    "TEAMBAR|v2|PROBE",
                ):
                    self.assertIn(token, text)
                # Round-2: ALL members captured - the truncating `min 8` must be gone.
                self.assertNotIn("min 8", text)
                self.assertIn("_n = count (units _grp)", text)

    def test_all_lifecycle_transitions_are_probed_with_reason_codes(self) -> None:
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                init = code(mission, "Client/Init/Init_Client.sqf")
                for phase in ('"init", "post-select"', '"init", "rejoin-check"', '"init", "rejoin-done"',
                              '"init", "rejoin-creategroup-null"', '"init", "rejoin-no-local-others"',
                              '"heartbeat", "periodic"'):
                    self.assertIn(phase, init)
                killed = code(mission, "Client/Functions/Client_OnKilled.sqf")
                for phase in ('"respawn", "rejoin-check"', '"respawn", "rejoin-done"',
                              '"respawn", "rejoin-creategroup-null"', '"respawn", "rejoin-no-local-others"'):
                    self.assertIn(phase, killed)
                self.assertIn('"buyunit", "post-spawn"', code(mission, "Client/Functions/Client_BuildUnit.sqf"))
                self.assertIn('"group-transfer", "post-join"', code(mission, "Common/Functions/Common_ChangeUnitGroup.sqf"))
                self.assertIn('"kicked", "post-transfer"', code(mission, "Client/Functions/Client_FNC_Groups.sqf"))

    def test_skinswap_probe_fires_after_the_final_fallback_join(self) -> None:
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                text = code(mission, "WASP/actions/SkinSelector/SkinSelector_Apply.sqf")
                self.assertIn('"skinswap", "post-final"', text)
                self.assertNotIn('"skinswap", "post-apply"', text)
                # After the subordinate fallback join path, immediately before the B6 COMPLETE log.
                self.assertLess(text.index("selectLeader player"), text.index('"skinswap", "post-final"'))
                self.assertLess(text.index('"skinswap", "post-final"'), text.index("B6 COMPLETE"))

    def test_group_transfer_probe_is_machine_safe(self) -> None:
        # ChangeUnitGroup runs on server/HC too, where the client probe fn may be nil.
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                text = code(mission, "Common/Functions/Common_ChangeUnitGroup.sqf")
                self.assertIn('_unit == player && {!isNil "WFBE_CL_FNC_TeambarProbe"}', text)

    def test_check_probe_precedes_the_guard_it_documents(self) -> None:
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                init = code(mission, "Client/Init/Init_Client.sqf")
                self.assertLess(init.index('"init", "rejoin-check"'),
                                init.index('((units group player) select 0) != player'))
                killed = code(mission, "Client/Functions/Client_OnKilled.sqf")
                self.assertLess(killed.index('"respawn", "rejoin-check"'),
                                killed.index('((units group player) select 0) != player'))

    def test_server_side_probe_is_phase_stamped(self) -> None:
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                text = code(mission, "Server/Functions/Server_HandleSpecial.sqf")
                self.assertIn("TEAMBAR|v2|SVPROBE", text)
                self.assertIn("phase=pre-client-rejoin", text)
                for token in ("getPlayerUID _leader", "leaderIsGrpLeader=", "rank _leader", 'WFBE_C_TEAMBAR_PROBE", 0]'):
                    self.assertIn(token, text)

    def test_registration_and_armed(self) -> None:
        """wave0721 arming ruling (2026-07-21): WFBE_C_TEAMBAR_PROBE flipped 0->1. The getVariable
        fallback default checked elsewhere in this file ('WFBE_C_TEAMBAR_PROBE", 0]') is the
        2-arg getVariable's own defensive fallback, not the registered constant - unaffected by
        the arming and unrelated to this test."""
        for name, mission in MISSIONS.items():
            with self.subTest(mission=name):
                self.assertIn("Client_TeambarProbe.sqf", code(mission, "Client/Init/Init_Client.sqf"))
                self.assertIn('if (isNil "WFBE_C_TEAMBAR_PROBE") then {WFBE_C_TEAMBAR_PROBE = 1}',
                              code(mission, "Common/Init/Init_CommonConstants.sqf"))


if __name__ == "__main__":
    unittest.main()
