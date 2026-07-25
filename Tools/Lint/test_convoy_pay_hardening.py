#!/usr/bin/env python3
"""Contract for the sidepatrol-convoy-stop hardening (2026-07-25 endpoint-inventory finding).

Server_HandleSpecial.sqf's "sidepatrol-convoy-stop" case paid a side's connected
players from WFBE_C_PATROL_CONVOY_PAY with ZERO validation. It is reachable via
the shared RequestSpecial PVF bus (Common_SendToServer.sqf -> plain
publicVariable, no sender authentication under this repo's PVF trust model), so
any forged sender could replay the case in a tight loop for an unbounded
money-printer. The fix requires the payload to name a real, currently-active
patrol (the exact [leader, sideID] tuple already tracked in WFBE_ACTIVE_PATROLS
by "sidepatrol-started"/"sidepatrol-ended") and adds a per-(leader,town)
cooldown plus a per-side per-round payout cap as defense in depth - all of
which reject only inputs a legitimate call could never produce.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
HANDLESPECIAL = "Server/Functions/Server_HandleSpecial.sqf"
RUNSIDEPATROL = "Common/Functions/Common_RunSidePatrol.sqf"


def _case_block(text: str) -> str:
    start = text.index('case "sidepatrol-convoy-stop"')
    end = text.index('case "hc-preseat"', start)
    return text[start:end]


class ConvoyPayHardeningTests(unittest.TestCase):
    def setUp(self) -> None:
        mission = MISSIONS[0]
        self.hs_text = mask_comments(
            (mission / HANDLESPECIAL).read_text(encoding="utf-8-sig")
        )
        self.rsp_text = mask_comments(
            (mission / RUNSIDEPATROL).read_text(encoding="utf-8-sig")
        )
        self.case = _case_block(self.hs_text)

    def test_payload_shape_is_exactly_validated(self) -> None:
        # A forged short/long array must be rejected before any select on it.
        self.assertIn('(count _args) != 4', self.case)
        self.assertLess(
            self.case.index('(count _args) != 4'),
            self.case.index('_cSideID = _args select 1'),
        )

    def test_town_must_be_a_registered_town_object(self) -> None:
        self.assertIn('!(_cTown in towns)', self.case)

    def test_side_must_resolve_to_a_real_combatant_side(self) -> None:
        self.assertIn('!(_cSide in [west, east, resistance])', self.case)

    def test_payout_requires_matching_active_patrol_record(self) -> None:
        # The exact [leader, sideID] tuple must be a live WFBE_ACTIVE_PATROLS entry -
        # "some patrol exists for this side" is NOT enough (blocks a same-side spy
        # from replaying a real town against a real patrol that never actually paid).
        self.assertIn('WFBE_ACTIVE_PATROLS', self.case)
        corr = self.case.index('(_x select 0) == _cLdr')
        self.assertIn('(_x select 1) == _cSideID', self.case[corr : corr + 120])
        # The correlation check must run BEFORE the payout call.
        self.assertLess(corr, self.case.index('Call WFBE_CO_FNC_SendToClients'))

    def test_cooldown_and_round_cap_are_defense_in_depth(self) -> None:
        self.assertIn('WFBE_C_PATROL_CONVOY_COOLDOWN', self.case)
        self.assertIn('WFBE_C_PATROL_CONVOY_MAX_PER_ROUND', self.case)
        # Both gates must run before the payout, not after.
        cooldown_idx = self.case.index('WFBE_C_PATROL_CONVOY_COOLDOWN')
        cap_idx = self.case.index('WFBE_C_PATROL_CONVOY_MAX_PER_ROUND')
        payout_idx = self.case.index('Call WFBE_CO_FNC_SendToClients')
        self.assertLess(cooldown_idx, payout_idx)
        self.assertLess(cap_idx, payout_idx)

    def test_cooldown_keyed_per_leader_not_just_per_side_town(self) -> None:
        # Keying on the leader unit (not just side+town) means two concurrent
        # same-side patrols converging on one town never collide on the cooldown -
        # this guard can never reject a genuine simultaneous second payout.
        self.assertIn('str _cLdr', self.case)

    def test_payout_math_and_recipients_are_unchanged(self) -> None:
        # The legitimate-trigger payout math/recipient logic must stay byte-identical.
        self.assertIn(
            '_cShare = round (_cPool / (_cCount max 1));', self.case
        )
        self.assertIn(
            '[_cSide, "BankPayout", [_cShare]] Call WFBE_CO_FNC_SendToClients;', self.case
        )
        self.assertIn(
            '[_cSide, _cShare] Call WFBE_SE_FNC_CreditSidePlayers;', self.case
        )

    def test_run_side_patrol_sends_leader_identity_on_both_paths(self) -> None:
        # Both the server-local Call and the HC RequestSpecial path must carry _ldr
        # so the server can correlate against the registry it already maintains.
        self.assertIn(
            '["sidepatrol-convoy-stop", _sideID, _target, _ldr] Call HandleSpecial;',
            self.rsp_text,
        )
        self.assertIn(
            '["RequestSpecial", ["sidepatrol-convoy-stop", _sideID, _target, _ldr]] '
            'Call WFBE_CO_FNC_SendToServer;',
            self.rsp_text,
        )

    def test_mirrors_share_identical_hardened_case(self) -> None:
        baseline = self.case
        for mission in MISSIONS[1:]:
            text = mask_comments(
                (mission / HANDLESPECIAL).read_text(encoding="utf-8-sig")
            )
            self.assertEqual(
                _case_block(text), baseline,
                f"{mission}: sidepatrol-convoy-stop case drifted from the Chernarus source",
            )


if __name__ == "__main__":
    unittest.main()
