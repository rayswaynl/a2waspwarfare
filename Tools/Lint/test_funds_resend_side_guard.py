#!/usr/bin/env python3
"""Contract for the B76 funds-resend side guard (fable/funds-resend-side-guard).

Live incident 2026-07-19 (ZG): a CIV-drifted group passed the wfbe_side presence
check, had no group funds and no JIP record, and branch (3) stamped+broadcast the
getVariable default 0 as "START funds" - latching a zero wallet the self-heal then
kept re-confirming. The guard must make a heal-invented zero impossible: defer on
any non-playable side, and defer when the START constant is missing.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
RESEND = MISSION / "Server" / "PVFunctions" / "RequestFundsResend.sqf"


class FundsResendSideGuardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.text = mask_comments(RESEND.read_text(encoding="utf-8-sig"))

    def test_non_playable_side_defers_before_any_stamp(self) -> None:
        guard = self.text.index("_sideJoined == civilian")
        # The guard must sit BEFORE the record/stamp machinery so no branch can run for CIV.
        self.assertLess(guard, self.text.index('_team getVariable "wfbe_funds"'))
        self.assertIn("in [west, east, resistance]", self.text)

    def test_start_stamp_requires_an_existing_scalar_constant(self) -> None:
        # Branch (3) must read the constant WITHOUT a default and defer when it is nil/non-scalar:
        # stamping `getVariable [name, 0]` is the exact zero-invention this fix removes.
        self.assertIn(
            'missionNamespace getVariable Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _sideJoined]',
            self.text,
        )
        self.assertNotIn(
            'missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _sideJoined], 0]',
            self.text,
        )
        self.assertIn('isNil "_funds"', self.text)

    def test_playable_side_stamp_path_is_preserved(self) -> None:
        # The legitimate first-join START stamp for real factions must still exist.
        self.assertIn('_team setVariable ["wfbe_funds", _funds, true]', self.text)
        self.assertIn("stamped START funds", self.text)

    def test_server_known_bindings_resolve_before_the_client_passed_body(self) -> None:
        """Round-2 review: the PV bus has no sender identity, so the client-passed body is
        the LEAST trusted input. Server-known bindings (stored RequestJoin body, then a
        playableUnits UID scan) must be consulted first; the client body is last resort."""
        jip_body = self.text.index("WFBE_JIP_BODY_%1")
        uid_scan = self.text.index("forEach playableUnits")
        client_last = self.text.index('{group _player) getVariable "wfbe_side"}'.replace("{group", "(group"))
        self.assertLess(jip_body, uid_scan)
        self.assertLess(uid_scan, client_last)


if __name__ == "__main__":
    unittest.main()
