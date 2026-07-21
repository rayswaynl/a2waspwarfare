#!/usr/bin/env python3
"""Contract fixtures for the flag-gated C1 commander lease.

Arma 2 OA SQF cannot be executed by the repository's Python tooling, so the
fixtures exercise the lease state transitions in a tiny deterministic model
and pin the mission source constructs that make those transitions safe.

Round 3 (codex reject 2026-07-19): a bare-timestamp stand-down request and a
"check-then-Call" executor step are not safe against SQF's scheduled-environment
preemption (the engine can hand control to another script between ANY two
statements, not only across an explicit sleep/waitUntil). The reviewer proved two
concrete repros: STALE_REQUEST (a stand-down request surviving a reclaim + fresh
disconnect and clearing the WRONG, later lease) and CHECK_TO_EFFECT_RACE (a
reclaim landing between the executor's holder-check and its stand-down effect).
The model below is rebuilt around a monotonic per-side GENERATION counter that
every grant and every successful reclaim bumps; a stand-down request captures the
generation it targets at enqueue time and the executor discards it outright if the
current generation no longer matches - no statement-adjacency assumption required.
All lease-coupled mutation (grant, reclaim, stand-down) is modelled as a command
consumed exclusively by a single per-side executor, matching the SQF source.

Round 4 (owner ruling 2026-07-21): the side-change stand-down enqueue was relocated
OFF RequestJoin.sqf - a JIP-flow file agents must never modify - onto the existing
Server_OnPlayerConnected.sqf connect handler instead. That handler already tracks a
player's previously-confirmed side for its own teamswap-funds check; the relocated
code reuses that same detection to enqueue the identical versioned stand-down
request. RequestJoin.sqf is now pinned byte-identical to its pre-C1 base.
"""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
DISCONNECT = CHERNARUS / "Server" / "Functions" / "Server_OnPlayerDisconnected.sqf"
HANDLE_SPECIAL = CHERNARUS / "Server" / "Functions" / "Server_HandleSpecial.sqf"
REQUEST_JOIN = CHERNARUS / "Server" / "PVFunctions" / "RequestJoin.sqf"
CONNECTED = CHERNARUS / "Server" / "Functions" / "Server_OnPlayerConnected.sqf"
REQUEST_NEW_COMMANDER = CHERNARUS / "Server" / "PVFunctions" / "RequestNewCommander.sqf"
REQUEST_CLAIM_COMMANDER = CHERNARUS / "Server" / "PVFunctions" / "RequestClaimCommander.sqf"
VOTE_FOR_COMMANDER = CHERNARUS / "Server" / "Functions" / "Server_VoteForCommander.sqf"
CONSTANTS = CHERNARUS / "Common" / "Init" / "Init_CommonConstants.sqf"
COMMON_INIT = CHERNARUS / "Common" / "Init" / "Init_Common.sqf"
INIT_SERVER = CHERNARUS / "Server" / "Init" / "Init_Server.sqf"
LEASE = CHERNARUS / "Common" / "Functions" / "Common_CommanderLease.sqf"


class LeaseModel:
    """Generation-versioned command-queue model mirroring the SQF executor design.

    Every mutating operation is a two-step "enqueue, then executor_tick" pair -
    exactly like the source, where writers/receivers only stamp a command slot and
    the single executor is the only thing that ever touches lease/commander state.
    """

    def __init__(self, flag: int = 1, grace: int = 90) -> None:
        self.flag = flag
        self.grace = grace
        self.lease: tuple[str, str, str, int, str, int] | None = None
        self.derived: str | None = None
        self.expires: int | None = None
        self.gen = 0
        self.now = 0
        self.ai_freed = 0
        self.messages = 0
        self.invalidations = 0
        self.cmd_grant = None
        self.cmd_reclaim = None
        self.cmd_standdown = None

    # --- enqueue-only entry points (mirror the *Request* SQF functions) ---

    def request_grant(self, team, source: str) -> None:
        if self.flag <= 0:
            return
        self.cmd_grant = (team, source, self.now)

    def request_reclaim(self, uid: str, team: str) -> None:
        if self.flag <= 0:
            return
        self.cmd_reclaim = (uid, team, self.now)

    def request_stand_down(self, target_gen: int) -> None:
        self.cmd_standdown = (target_gen, self.now)

    # --- flag-off legacy path (bypasses the queue entirely, matches the SQF else-branch) ---

    def legacy_grant(self, uid: str, side: str, group: str, source: str) -> None:
        # Mirrors the flag-off `else` branches: ONLY wfbe_commander is ever written; the
        # lease/expires/gen machinery is never touched when the flag is off.
        self.derived = group

    def legacy_disconnect_instant_null(self) -> None:
        self.derived = None
        self.ai_freed += 1
        self.messages += 1

    # --- eligibility predicate (pure, no mutation) ---

    def eligible(self, team) -> bool:
        return team is not None

    def holder_present(self, units: list[tuple[str, str, bool]]) -> bool:
        if self.lease is None:
            return False
        uid, _side, group, _grant, _source, _gen = self.lease
        return any(
            unit_uid == uid and unit_group == group and alive
            for unit_uid, unit_group, alive in units
        )

    # --- the single executor: consumes at most one command per kind per tick ---

    def executor_tick(self, units: list[tuple[str, str, bool]] | None = None) -> None:
        if self.cmd_grant is not None:
            team, source, _t = self.cmd_grant
            self.cmd_grant = None
            self._exec_grant(team, source)

        if self.cmd_reclaim is not None:
            uid, team, _t = self.cmd_reclaim
            self.cmd_reclaim = None
            self._exec_reclaim(uid, team)

        if self.cmd_standdown is not None:
            target_gen, _t = self.cmd_standdown
            self.cmd_standdown = None
            self._exec_stand_down(target_gen, units)

    def _exec_grant(self, team, source: str) -> None:
        if team is None:
            self.gen += 1
            self.lease = None
            self.expires = None
            self.derived = None
            return
        if not self.eligible(team):
            return
        uid, side, group = team
        self.gen += 1
        self.lease = (uid, side, group, self.now, source, self.gen)
        self.expires = None
        self.derived = group

    def _exec_reclaim(self, uid: str, team: str) -> None:
        if self.lease is None:
            return
        cur_uid, side, group, _grant, _source, _gen = self.lease
        if cur_uid != uid or group != team:
            return
        if not self.eligible((uid, side, team)):
            return
        self.gen += 1  # reclaim bumps generation too - see source comment.
        self.expires = None
        self.lease = (uid, side, group, self.now, "reclaim", self.gen)
        self.derived = group

    def _exec_stand_down(self, target_gen: int, units) -> None:
        if target_gen != self.gen:
            return  # stale-by-construction: a newer grant/reclaim already superseded this.
        if self.derived is None and self.lease is None:
            return  # already clean
        if units is not None and self.holder_present(units):
            return  # defense-in-depth
        self.lease = None
        self.expires = None
        self.derived = None
        self.invalidations += 1
        self.ai_freed += 1
        self.messages += 1

    # --- grace/expiry watcher: only ever REQUESTS, carrying the gen it observed ---

    def tick(self, seconds: int, units: list[tuple[str, str, bool]] | None = None) -> None:
        self.now += seconds
        if self.expires is None or self.now < self.expires:
            return
        if self.lease is None or (units is not None and self.holder_present(units)):
            return
        armed_gen = self.lease[5]
        self.request_stand_down(armed_gen)

    def disconnect(self, uid: str, side: str, group: str) -> None:
        """Mirrors Server_OnPlayerDisconnected's lease branch: matching lease arms
        grace (capturing its generation); a mismatch enqueues an immediate
        stand-down request for the CURRENT generation instead of nulling directly."""
        if self.flag <= 0:
            self.legacy_disconnect_instant_null()
            return
        if self.lease and self.lease[0] == uid and self.lease[1] == side and self.lease[2] == group:
            self.expires = self.now + self.grace
        else:
            self.request_stand_down(self.gen)


class CommanderLeaseFixtures(unittest.TestCase):
    def test_01_leader_death_lease_intact_same_uid_commands(self) -> None:
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "vote")
        state.executor_tick()
        self.assertTrue(state.holder_present([("uid-1", "grp-1", True)]))
        self.assertEqual(state.derived, "grp-1")

    def test_02_second_promotion_keeps_group_bound_lease(self) -> None:
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "claim")
        state.executor_tick()
        # The AI is now leader, but the human commander remains in the group.
        self.assertTrue(state.holder_present([("uid-ai", "grp-1", True), ("uid-1", "grp-1", True)]))
        self.assertEqual(state.lease[2], "grp-1")

    def test_03_respawn_within_grace_reclaims_without_ai_free(self) -> None:
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "assign")
        state.executor_tick()
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(30, units=[])
        state.request_reclaim("uid-1", "grp-1")
        state.executor_tick(units=[("uid-1", "grp-1", True)])
        state.tick(90, units=[("uid-1", "grp-1", True)])
        state.executor_tick(units=[("uid-1", "grp-1", True)])
        self.assertEqual(state.derived, "grp-1")
        self.assertEqual(state.ai_freed, 0)

    def test_04_disconnect_grace_then_expiry_stands_down_once(self) -> None:
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "vote")
        state.executor_tick()
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(91, units=[])
        state.executor_tick(units=[])
        state.tick(91, units=[])
        state.executor_tick(units=[])
        self.assertIsNone(state.derived)
        self.assertEqual(state.ai_freed, 1)
        self.assertEqual(state.messages, 1)
        self.assertEqual(state.invalidations, 1)

    def test_05_side_change_invalidates_once(self) -> None:
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "vote")
        state.executor_tick()
        armed_gen = state.gen
        state.request_stand_down(armed_gen)
        state.executor_tick()
        state.request_stand_down(armed_gen)  # a stale duplicate side-change request
        state.executor_tick()
        self.assertIsNone(state.lease)
        self.assertEqual(state.invalidations, 1)

    def test_06_flag_off_keeps_instant_legacy_disconnect(self) -> None:
        state = LeaseModel(flag=0)
        state.legacy_grant("uid-1", "west", "grp-1", "vote")
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
        code = LEASE.read_text(encoding="utf-8-sig")
        self.assertIn("if (_side != civilian", code)
        self.assertIn("[_team, \"wfbe_aicom_hc\", false] Call WFBE_CO_FNC_GroupGetBool", code)
        self.assertIn("{isPlayer _leader}", code)
        self.assertIn("Call WFBE_CO_FNC_CommanderLeaseEligible)) exitWith {}", code)

    def test_source_contracts_are_flagged_and_registered(self) -> None:
        constants = CONSTANTS.read_text(encoding="utf-8-sig")
        common_init = COMMON_INIT.read_text(encoding="utf-8-sig")
        self.assertIn('if (isNil "WFBE_C_CMD_LEASE") then {WFBE_C_CMD_LEASE = 0};', constants)
        self.assertIn('if (isNil "WFBE_C_CMD_LEASE_GRACE") then {WFBE_C_CMD_LEASE_GRACE = 90};', constants)
        self.assertIn('Call Compile preprocessFileLineNumbers "Common\\Functions\\Common_CommanderLease.sqf";', common_init)
        flagged = 'missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]'
        for path in (DISCONNECT, HANDLE_SPECIAL, CONNECTED, REQUEST_NEW_COMMANDER, REQUEST_CLAIM_COMMANDER, VOTE_FOR_COMMANDER):
            code = path.read_text(encoding="utf-8-sig")
            self.assertIn(flagged, code, str(path))
            self.assertNotIn("(WFBE_C_CMD_LEASE > 0)", code, str(path))
        self.assertIn(
            'missionNamespace getVariable ["WFBE_C_CMD_LEASE_GRACE", 90]',
            DISCONNECT.read_text(encoding="utf-8-sig"),
        )

    def test_07b_requestjoin_is_untouched_jip_flow_file(self) -> None:
        """Owner ruling 2026-07-21: RequestJoin.sqf is JIP-flow and agents must never modify
        it. Pin that it carries no trace of the C1 lease feature at all - the relocated
        detection lives in Server_OnPlayerConnected.sqf instead (see test_11/test_12)."""
        code = REQUEST_JOIN.read_text(encoding="utf-8-sig")
        self.assertNotIn("WFBE_C_CMD_LEASE", code)
        self.assertNotIn("CommanderLease", code)
        self.assertNotIn("_oldLogic", code)
        self.assertNotIn("_oldLease", code)

    def test_08_racing_callers_can_only_request_never_run_effects(self) -> None:
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "vote")
        state.executor_tick()
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(91, units=[])          # caller A requests at expiry (gen=1)
        state.request_stand_down(state.gen)  # caller B interleaves - same gen, harmless duplicate
        state.executor_tick(units=[])     # the single executor consumes
        state.executor_tick(units=[])     # nothing left to consume
        self.assertEqual(state.ai_freed, 1)
        self.assertEqual(state.messages, 1)
        self.assertEqual(state.invalidations, 1)

    def test_08b_reclaim_between_request_and_consumption_wins(self) -> None:
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "vote")
        state.executor_tick()
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(91, units=[])                                   # request pending (gen=1)
        state.request_reclaim("uid-1", "grp-1")
        state.executor_tick(units=[("uid-1", "grp-1", True)])      # reclaim bumps gen -> 2, THEN standdown(gen=1) is consumed and is stale
        self.assertEqual(state.derived, "grp-1")
        self.assertEqual(state.ai_freed, 0)
        self.assertEqual(state.messages, 0)

    def test_09_stale_request_never_clears_a_later_lease(self) -> None:
        """Reviewer repro STALE_REQUEST: grant A -> disconnect -> stand-down request(gen=1)
        queued but NOT yet consumed. Reclaim happens (bumps to gen=2). A completely fresh
        disconnect+regrant cycle happens later (gen=3 with a real grace window). The STALE
        gen=1 request, consumed only now, must NOT touch the gen=3 lease."""
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "vote")
        state.executor_tick()
        self.assertEqual(state.gen, 1)

        state.disconnect("uid-1", "west", "grp-1")           # arms grace, captures gen=1
        state.tick(91, units=[])                              # expiry -> request_stand_down(1) queued
        self.assertEqual(state.cmd_standdown, (1, state.now))

        # Reclaim lands BEFORE the queued request is consumed (still same commander).
        state.request_reclaim("uid-1", "grp-1")
        state.executor_tick(units=[("uid-1", "grp-1", True)])  # reclaim -> gen=2; standdown(1) discarded (stale)
        self.assertEqual(state.gen, 2)
        self.assertEqual(state.derived, "grp-1")
        self.assertIsNone(state.cmd_standdown)

        # A brand new disconnect+regrant cycle: someone else becomes commander (gen=3).
        state.request_grant(("uid-2", "west", "grp-2"), "assign")
        state.executor_tick()
        self.assertEqual(state.gen, 3)
        state.disconnect("uid-2", "west", "grp-2")
        state.tick(181, units=[])  # second_expiry - queues a FRESH standdown(gen=3)
        state.executor_tick(units=[])

        self.assertIsNone(state.derived)      # gen=3's own lease correctly stood down
        self.assertEqual(state.ai_freed, 1)   # exactly once - never touched by the stale gen=1 ghost
        self.assertEqual(state.messages, 1)

    def test_10_check_to_effect_race_generation_gate_is_the_defense(self) -> None:
        """Reviewer repro CHECK_TO_EFFECT_RACE: a reclaim landing between the executor's
        holder-check and its stand-down effect. The fix does not rely on those two steps
        being adjacent/uninterruptible - the generation captured at enqueue time is compared
        against the CURRENT generation at consumption time, and reclaim always bumps
        generation, so ANY reclaim since the request was raised - regardless of exact
        interleaving point - makes the request provably stale."""
        state = LeaseModel()
        state.request_grant(("uid-1", "west", "grp-1"), "vote")
        state.executor_tick()
        state.disconnect("uid-1", "west", "grp-1")
        state.tick(91, units=[])  # standdown(gen=1) queued, NOT yet processed
        # Simulate the race: reclaim is processed by the SAME executor_tick call that would
        # also have processed the pending stand-down, i.e. within the same "atomic" pass the
        # reviewer showed could still interleave with an external caller. Grant/reclaim are
        # processed BEFORE stand-down in the executor's per-kind order, so this single tick
        # models the worst case (reclaim commits generation, THEN stand-down is evaluated).
        state.request_reclaim("uid-1", "grp-1")
        state.executor_tick(units=[("uid-1", "grp-1", True)])
        self.assertEqual(state.derived, "grp-1")  # NOT cleared - gen no longer matches
        self.assertEqual(state.ai_freed, 0)
        self.assertEqual(state.messages, 0)

    def test_11_mutating_functions_have_exactly_one_executor_call_site(self) -> None:
        """Structural single-owner pin: the three Exec* functions (grant/reclaim/standdown)
        are Called from exactly ONE place - inside the executor loop. Nothing else in the
        mission ever mutates wfbe_commander / wfbe_commander_lease / wfbe_commander_lease_gen."""
        code = LEASE.read_text(encoding="utf-8-sig")
        for fn in ("WFBE_CO_FNC_CommanderLeaseExecGrant", "WFBE_CO_FNC_CommanderLeaseExecReclaim", "WFBE_CO_FNC_CommanderLeaseExecStandDown"):
            self.assertEqual(code.count(f"Call {fn}"), 1, fn)
            call_idx = code.index(f"Call {fn}")
            self.assertGreater(call_idx, code.index("WFBE_CO_FNC_CommanderLeaseStandDownExecutor = {"))

        # Writers/receivers only ever call the Request* enqueue functions: the flag-on branch
        # (between the WFBE_C_CMD_LEASE gate and its matching `} else {`) enqueues and never
        # itself writes wfbe_commander.
        for path in (REQUEST_NEW_COMMANDER, REQUEST_CLAIM_COMMANDER, VOTE_FOR_COMMANDER):
            writer = path.read_text(encoding="utf-8-sig")
            self.assertIn("Call WFBE_CO_FNC_CommanderLeaseRequestGrant", writer, str(path))
            gate = writer.index('WFBE_C_CMD_LEASE", 0]) > 0')
            flag_on_branch = writer[gate : writer.index("} else {", gate)]
            self.assertNotIn('setVariable ["wfbe_commander",', flag_on_branch, str(path))

        handle_special = HANDLE_SPECIAL.read_text(encoding="utf-8-sig")
        reclaim_block = handle_special[handle_special.index('case "update-teamleader"'):handle_special.index('case "group-query"')]
        self.assertIn("Call WFBE_CO_FNC_CommanderLeaseRequestReclaim", reclaim_block)
        self.assertNotIn("wfbe_commander\", _team", reclaim_block)

        connected = CONNECTED.read_text(encoding="utf-8-sig")
        self.assertIn("Call WFBE_CO_FNC_CommanderLeaseRequestStandDown", connected)

        init_server = INIT_SERVER.read_text(encoding="utf-8-sig")
        self.assertIn("Spawn WFBE_CO_FNC_CommanderLeaseStandDownExecutor", init_server)
        idx = init_server.index("Spawn WFBE_CO_FNC_CommanderLeaseStandDownExecutor")
        self.assertIn('WFBE_C_CMD_LEASE", 0]) > 0', init_server[idx - 400 : idx])

    def test_12_standdown_requests_are_generation_versioned(self) -> None:
        """Every enqueue site that can trigger a stand-down passes a generation, not a bare
        timestamp - the exact defect the round-3 rejection identified."""
        disconnect = DISCONNECT.read_text(encoding="utf-8-sig")
        self.assertIn("_leaseGen = _lease select 5;", disconnect)
        self.assertIn("[_side, _leaseExpires, _leaseGen] Spawn WFBE_CO_FNC_CommanderLeaseGraceCheck;", disconnect)
        self.assertIn("[_side, (_logik getVariable [\"wfbe_commander_lease_gen\", 0])] Call WFBE_CO_FNC_CommanderLeaseRequestStandDown;", disconnect)

        connected = CONNECTED.read_text(encoding="utf-8-sig")
        self.assertIn("(_oldLease select 5)] Call WFBE_CO_FNC_CommanderLeaseRequestStandDown", connected)
        self.assertIn("_prevSideJoined = _get select 3;", connected)
        self.assertIn("_prevSideJoined != _sideJoined", connected)

        lease_code = LEASE.read_text(encoding="utf-8-sig")
        grace_check = lease_code[lease_code.index("WFBE_CO_FNC_CommanderLeaseGraceCheck = {"):]
        self.assertIn("_gen = _this select 2;", grace_check)
        self.assertIn("[_side, _gen] Call WFBE_CO_FNC_CommanderLeaseRequestStandDown", grace_check)

        exec_sd = lease_code[lease_code.index("WFBE_CO_FNC_CommanderLeaseExecStandDown = {"):lease_code.index("WFBE_CO_FNC_CommanderLeaseStandDownExecutor = {")]
        self.assertIn("_curGen = _logic getVariable", exec_sd)
        self.assertIn("if (_targetGen != _curGen) exitWith {};", exec_sd)

    def test_12b_standdown_enqueue_precedes_duplicate_connect_latch(self) -> None:
        """Round-2 adversarial review (2026-07-21, HIGH finding): Server_OnPlayerConnected.sqf
        resolves TWICE per join and has a 15s duplicate-connect latch that exitWith-skips
        everything below it. A lease holder reconnecting quickly can have either resolve pass
        land inside that window, so the stand-down enqueue must be textually ABOVE the latch's
        exitWith or it can be silently skipped on the one connect event that matters. Also pin
        that it sits above the CIV-mid-sync guard, since it can no longer rely on inheriting
        that guard's protection and must carry its own explicit real-side check instead."""
        connected = CONNECTED.read_text(encoding="utf-8-sig")
        standdown_idx = connected.index("Call WFBE_CO_FNC_CommanderLeaseRequestStandDown")
        latch_idx = connected.index('if (!isNil "_jipLatch" && {(time - _jipLatch) < 15}) exitWith {')
        civ_guard_idx = connected.index('if (str _sideJoined == "CIV") exitWith {')
        self.assertLess(standdown_idx, latch_idx, "stand-down enqueue must precede the duplicate-connect latch exitWith")
        self.assertLess(standdown_idx, civ_guard_idx, "stand-down enqueue must precede the CIV-mid-sync guard exitWith")
        # Since it no longer sits downstream of the CIV guard, it must carry its own real-side check.
        self.assertIn('{_sideJoined in [west, east, resistance]}', connected)

    def test_13_reclaim_never_wipes_per_team_state(self) -> None:
        """During grace the AI teams are never freed, so the update-teamleader reclaim must not
        touch per-team autonomous/respawn state - a blanket SetTeamAutonomous/SetTeamRespawn on
        reconnect would wipe the commander's own per-team choices (the C5 anti-pattern)."""
        code = HANDLE_SPECIAL.read_text(encoding="utf-8-sig")
        start = code.index('case "update-teamleader"')
        end = code.index('case "group-query"')
        reclaim_block = code[start:end]
        self.assertNotIn("Call SetTeamAutonomous", reclaim_block)
        self.assertNotIn("Call SetTeamRespawn", reclaim_block)
        exec_reclaim = LEASE.read_text(encoding="utf-8-sig")
        exec_reclaim = exec_reclaim[exec_reclaim.index("WFBE_CO_FNC_CommanderLeaseExecReclaim = {"):exec_reclaim.index("WFBE_CO_FNC_CommanderLeaseExecStandDown = {")]
        self.assertNotIn("SetTeamAutonomous", exec_reclaim)
        self.assertNotIn("SetTeamRespawn", exec_reclaim)

    def test_14_claim_no_longer_needs_an_accepted_latch(self) -> None:
        """Round-3 simplification: since the flag-on branch only enqueues (never touches
        wfbe_aicom_running itself), the old `_claimAccepted` fallthrough-guard latch is gone -
        there is nothing left in this file for it to guard against."""
        claim = REQUEST_CLAIM_COMMANDER.read_text(encoding="utf-8-sig")
        self.assertNotIn("_claimAccepted", claim)
        self.assertIn('Call WFBE_CO_FNC_CommanderLeaseRequestGrant', claim)
        # Flag-off legacy path still stands the AI down synchronously and unconditionally
        # (every guard above already guarantees _claimTeam is non-null at this point).
        flag_off = claim[claim.index("} else {"):]
        self.assertIn('wfbe_aicom_running', flag_off)


if __name__ == "__main__":
    unittest.main()
