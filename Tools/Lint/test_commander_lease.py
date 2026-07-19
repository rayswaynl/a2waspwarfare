#!/usr/bin/env python3
"""Contract fixtures for the flag-gated C1 commander lease.

Arma 2 OA SQF cannot be executed by the repository's Python tooling, so the
fixtures exercise the lease state transitions in a tiny deterministic model
and pin the mission source constructs that make those transitions safe.
"""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
DISCONNECT = CHERNARUS / "Server" / "Functions" / "Server_OnPlayerDisconnected.sqf"
HANDLE_SPECIAL = CHERNARUS / "Server" / "Functions" / "Server_HandleSpecial.sqf"
REQUEST_JOIN = CHERNARUS / "Server" / "PVFunctions" / "RequestJoin.sqf"
CONSTANTS = CHERNARUS / "Common" / "Init" / "Init_CommonConstants.sqf"
COMMON_INIT = CHERNARUS / "Common" / "Init" / "Init_Common.sqf"
LEASE = CHERNARUS / "Common" / "Functions" / "Common_CommanderLease.sqf"


class LeaseModel:
    """Small race model for the seven acceptance scenarios."""

    def __init__(self, flag: int = 1, grace: int = 90) -> None:
        self.flag = flag
        self.grace = grace
        self.lease: tuple[str, str, str, int, str] | None = None
        self.derived: str | None = None
        self.expires: int | None = None
        self.now = 0
        self.ai_freed = 0
        self.messages = 0
        self.invalidations = 0

    def grant(self, uid: str, side: str, group: str, source: str) -> None:
        if self.flag > 0 and side != "civilian":
            self.lease = (uid, side, group, self.now, source)
            self.derived = group
            self.expires = None

    def holder_present(self, units: list[tuple[str, str, bool]]) -> bool:
        if self.lease is None:
            return False
        uid, _side, group, _grant, _source = self.lease
        return any(
            unit_uid == uid and unit_group == group and alive
            for unit_uid, unit_group, alive in units
        )

    def disconnect(self, uid: str, side: str, group: str) -> None:
        if self.flag <= 0:
            self.derived = None
            self.ai_freed += 1
            self.messages += 1
            return
        if self.lease and self.lease[0] == uid and self.lease[1] == side and self.lease[2] == group:
            self.expires = self.now + self.grace

    def reclaim(self, uid: str, side: str, group: str) -> None:
        if self.lease and self.lease[0] == uid and self.lease[1] == side and self.lease[2] == group:
            self.expires = None
            self.derived = group

    def tick(self, seconds: int, units: list[tuple[str, str, bool]] | None = None) -> None:
        """A grace checker reaching expiry REQUESTS a stand-down; it never runs effects."""
        self.now += seconds
        if self.expires is None or self.now < self.expires:
            return
        if self.lease is None or (units is not None and self.holder_present(units)):
            return
        self.request_stand_down()

    def request_stand_down(self) -> None:
        """Mirrors WFBE_CO_FNC_CommanderLeaseRequestStandDown: callers only stamp a
        request. Any number of racing callers collapse into one pending request."""
        self.sd_request = True

    def executor_tick(self, units: list[tuple[str, str, bool]] | None = None) -> None:
        """Mirrors the ONE per-side executor: the only code path that performs the
        stand-down effects. Single-owner by construction - interleaving callers can
        only ever add requests, never run effects."""
        if not getattr(self, "sd_request", False):
            return
        self.sd_request = False
        if units is not None and self.holder_present(units):
            return  # a reclaim between request and consumption wins
        self.stand_down()

    def stand_down(self) -> None:
        """Executor-internal: clear state before effects (guarded single-fire)."""
        if self.derived is None and self.lease is None:
            return
        self.lease = None
        self.expires = None
        self.derived = None
        self.invalidations += 1
        self.ai_freed += 1
        self.messages += 1

    def invalidate(self) -> None:
        if self.lease is not None or self.derived is not None or self.expires is not None:
            self.invalidations += 1
        self.lease = None
        self.expires = None
        self.derived = None


class CommanderLeaseFixtures(unittest.TestCase):
    def test_01_leader_death_lease_intact_same_uid_commands(self) -> None:
        state = LeaseModel()
        state.grant("uid-1", "west", "grp-1", "vote")
        self.assertTrue(state.holder_present([("uid-1", "grp-1", True)]))
        self.assertEqual(state.derived, "grp-1")

    def test_02_second_promotion_keeps_group_bound_lease(self) -> None:
        state = LeaseModel()
        state.grant("uid-1", "west", "grp-1", "claim")
        # The AI is now leader, but the human commander remains in the group.
        self.assertTrue(state.holder_present([("uid-ai", "grp-1", True), ("uid-1", "grp-1", True)]))
        self.assertEqual(state.lease[2], "grp-1")

    def test_03_respawn_within_grace_reclaims_without_ai_free(self) -> None:
        state = LeaseModel()
        state.grant("uid-1", "west", "grp-1", "assign")
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(30, units=[])
        state.reclaim("uid-1", "west", "grp-1")
        state.tick(90, units=[])
        state.executor_tick(units=[("uid-1", "grp-1", True)])
        self.assertEqual(state.derived, "grp-1")
        self.assertEqual(state.ai_freed, 0)

    def test_04_disconnect_grace_then_expiry_stands_down_once(self) -> None:
        state = LeaseModel()
        state.grant("uid-1", "west", "grp-1", "vote")
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(91, units=[])
        state.tick(91, units=[])
        state.executor_tick(units=[])
        state.executor_tick(units=[])
        self.assertIsNone(state.derived)
        self.assertEqual(state.ai_freed, 1)
        self.assertEqual(state.messages, 1)
        self.assertEqual(state.invalidations, 1)

    def test_05_side_change_invalidates_once(self) -> None:
        state = LeaseModel()
        state.grant("uid-1", "west", "grp-1", "vote")
        state.invalidate()
        state.invalidate()
        self.assertIsNone(state.lease)
        self.assertEqual(state.invalidations, 1)

    def test_06_flag_off_keeps_instant_legacy_disconnect(self) -> None:
        state = LeaseModel(flag=0)
        state.grant("uid-1", "west", "grp-1", "vote")
        state.disconnect("uid-1", "west", "grp-1")
        self.assertIsNone(state.lease)
        self.assertIsNone(state.expires)
        self.assertEqual(state.ai_freed, 1)
        self.assertEqual(state.messages, 1)

        disconnect = DISCONNECT.read_text(encoding="utf-8-sig")
        self.assertIn("_logik setVariable [\"wfbe_commander\", objNull, true];", disconnect)
        self.assertIn("[_side, \"LocalizeMessage\", ['CommanderDisconnected']] Call WFBE_CO_FNC_SendToClients;", disconnect)
        self.assertIn("{[_x,false] Call SetTeamAutonomous;[_x, \"\"] Call SetTeamRespawn} forEach (_logik getVariable \"wfbe_teams\");", disconnect)

    def test_07_civilian_and_civ_hc_never_receive_a_lease(self) -> None:
        state = LeaseModel()
        state.grant("uid-civ", "civilian", "grp-civ", "claim")
        self.assertIsNone(state.lease)

        code = LEASE.read_text(encoding="utf-8-sig")
        self.assertIn("if (_side == civilian) exitWith {}", code)
        self.assertIn("[_team, \"wfbe_aicom_hc\", false] Call WFBE_CO_FNC_GroupGetBool", code)
        # Grant delegates the player-leader test to the shared eligibility helper.
        self.assertIn("{isPlayer _leader}", code)
        self.assertIn("Call WFBE_CO_FNC_CommanderLeaseEligible)) exitWith {}", code)

    def test_source_contracts_are_flagged_and_registered(self) -> None:
        constants = CONSTANTS.read_text(encoding="utf-8-sig")
        common_init = COMMON_INIT.read_text(encoding="utf-8-sig")
        self.assertIn('if (isNil "WFBE_C_CMD_LEASE") then {WFBE_C_CMD_LEASE = 0};', constants)
        self.assertIn('if (isNil "WFBE_C_CMD_LEASE_GRACE") then {WFBE_C_CMD_LEASE_GRACE = 90};', constants)
        self.assertIn('Call Compile preprocessFileLineNumbers "Common\\Functions\\Common_CommanderLease.sqf";', common_init)
        # Nil-safe defaulted read only: a bare `WFBE_C_CMD_LEASE > 0` on A2 OA throws if the
        # constant is ever undefined at eval time and kills the WHOLE calling script (e.g. the
        # rest of the disconnect handler, including the score DB save).
        flagged = 'missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]'
        for path in (DISCONNECT, HANDLE_SPECIAL, REQUEST_JOIN):
            code = path.read_text(encoding="utf-8-sig")
            self.assertIn(flagged, code, str(path))
            self.assertNotIn("(WFBE_C_CMD_LEASE > 0)", code, str(path))
        self.assertIn(
            'missionNamespace getVariable ["WFBE_C_CMD_LEASE_GRACE", 90]',
            DISCONNECT.read_text(encoding="utf-8-sig"),
        )

    def test_08_racing_callers_can_only_request_never_run_effects(self) -> None:
        """Round-2 review fix: ANY number of racing callers (grace checkers, side-change,
        a caller interleaving at any statement boundary) only stamp requests. Effects run
        exactly once because exactly one executor consumes them."""
        state = LeaseModel()
        state.grant("uid-1", "west", "grp-1", "vote")
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(91, units=[])          # caller A requests at expiry
        state.request_stand_down()        # caller B interleaves - just another request
        state.request_stand_down()        # caller C interleaves mid-anything - same
        state.executor_tick(units=[])     # the single executor consumes
        state.executor_tick(units=[])     # nothing left to consume
        self.assertEqual(state.ai_freed, 1)
        self.assertEqual(state.messages, 1)
        self.assertEqual(state.invalidations, 1)

    def test_08b_reclaim_between_request_and_consumption_wins(self) -> None:
        """A request is pending, then the commander reclaims before the executor runs:
        the executor's consumption-time holder re-check absorbs the stale request."""
        state = LeaseModel()
        state.grant("uid-1", "west", "grp-1", "vote")
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(91, units=[])                                   # request pending
        state.reclaim("uid-1", "west", "grp-1")                    # holder returns
        state.executor_tick(units=[("uid-1", "grp-1", True)])      # stale request absorbed
        self.assertEqual(state.derived, "grp-1")
        self.assertEqual(state.ai_freed, 0)
        self.assertEqual(state.messages, 0)

    def test_09_stand_down_effects_have_exactly_one_executor_call_site(self) -> None:
        """Structural single-owner pin: WFBE_CO_FNC_CommanderLeaseStandDown is Called from
        exactly ONE site - inside the per-side executor. Grace checker and side-change go
        through RequestStandDown. Init_Server spawns the executor flag-gated."""
        code = LEASE.read_text(encoding="utf-8-sig")
        self.assertEqual(code.count("Call WFBE_CO_FNC_CommanderLeaseStandDown;"), 1)
        exec_body = code[code.index("WFBE_CO_FNC_CommanderLeaseStandDownExecutor"):]
        self.assertIn("Call WFBE_CO_FNC_CommanderLeaseStandDown;", exec_body)
        self.assertIn("Call WFBE_CO_FNC_CommanderLeaseRequestStandDown", code)  # grace checker requests
        request_join = (CHERNARUS / "Server" / "PVFunctions" / "RequestJoin.sqf").read_text(encoding="utf-8-sig")
        self.assertIn("Call WFBE_CO_FNC_CommanderLeaseRequestStandDown", request_join)
        self.assertNotIn("Call WFBE_CO_FNC_CommanderLeaseStandDown}", request_join)
        init_server = (CHERNARUS / "Server" / "Init" / "Init_Server.sqf").read_text(encoding="utf-8-sig")
        self.assertIn("Spawn WFBE_CO_FNC_CommanderLeaseStandDownExecutor", init_server)
        idx = init_server.index("Spawn WFBE_CO_FNC_CommanderLeaseStandDownExecutor")
        self.assertIn('WFBE_C_CMD_LEASE", 0]) > 0', init_server[idx - 400 : idx])
        # State still clears before effects inside the executor-internal stand-down (defense in depth).
        body = code[code.index("WFBE_CO_FNC_CommanderLeaseStandDown = {"):code.index("WFBE_CO_FNC_CommanderLeaseStandDownExecutor")]
        self.assertLess(body.index('setVariable ["wfbe_commander_lease", nil, true]'), body.index("LocalizeMessage"))

    def test_10_writers_fail_closed_behind_eligibility(self) -> None:
        """Flag-on seat writers must validate BEFORE publishing wfbe_commander, and the
        reclaim must repeat the eligibility test (incl. aicom-hc denial)."""
        lease_code = LEASE.read_text(encoding="utf-8-sig")
        self.assertIn("WFBE_CO_FNC_CommanderLeaseEligible", lease_code)
        self.assertIn("side _team == _side", lease_code)
        new_cmdr = (CHERNARUS / "Server" / "PVFunctions" / "RequestNewCommander.sqf").read_text(encoding="utf-8-sig")
        claim_cmdr = (CHERNARUS / "Server" / "PVFunctions" / "RequestClaimCommander.sqf").read_text(encoding="utf-8-sig")
        vote_cmdr = (CHERNARUS / "Server" / "Functions" / "Server_VoteForCommander.sqf").read_text(encoding="utf-8-sig")
        for name, code in (("RequestNewCommander", new_cmdr), ("RequestClaimCommander", claim_cmdr), ("Server_VoteForCommander", vote_cmdr)):
            self.assertIn("WFBE_CO_FNC_CommanderLeaseEligible", code, name)
        # Deny on claim must not stop the AI commander (latch, no exitWith fallthrough).
        self.assertIn("_claimAccepted", claim_cmdr)
        handle = HANDLE_SPECIAL.read_text(encoding="utf-8-sig")
        reclaim_block = handle[handle.index('case "update-teamleader"'):handle.index('case "group-query"')]
        self.assertIn("WFBE_CO_FNC_CommanderLeaseEligible", reclaim_block)

    def test_reclaim_never_wipes_per_team_state(self) -> None:
        """During grace the AI teams are never freed, so the update-teamleader reclaim must not
        touch per-team autonomous/respawn state - a blanket SetTeamAutonomous/SetTeamRespawn on
        reconnect would wipe the commander's own per-team choices (the C5 anti-pattern)."""
        code = HANDLE_SPECIAL.read_text(encoding="utf-8-sig")
        start = code.index('case "update-teamleader"')
        end = code.index('case "group-query"')
        reclaim_block = code[start:end]
        self.assertIn("wfbe_commander_lease_expires", reclaim_block)
        self.assertNotIn("Call SetTeamAutonomous", reclaim_block)
        self.assertNotIn("Call SetTeamRespawn", reclaim_block)


if __name__ == "__main__":
    unittest.main()
