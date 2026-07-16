#!/usr/bin/env python3
"""Regression checks for server-authoritative FPV detonation.

Covers the three surfaces PR #1096 introduces and that previously had zero
coverage: the Support_FPV_Detonate.sqf authority state machine, the 15s
dead-drone rearm grace in Support_FPV.sqf, and the bounded retry/coalescing
path taken when a same-side drone dies inside the 5s side cooldown.

These are source-structure assertions in the established style of
test_fpv_purchase_authority.py: A2 OA SQF cannot be executed off-engine, so
each invariant is pinned to the construct that enforces it. A refactor that
drops an invariant fails here rather than silently reopening the exploit.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

DETONATE = Path("Server/Support/Support_FPV_Detonate.sqf")
FPV_SERVER = Path("Server/Support/Support_FPV.sqf")


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


def detonate_code() -> str:
    return mask_comments(read(MAINTAINED_ROOTS[0], DETONATE))


def fpv_server_code() -> str:
    return mask_comments(read(MAINTAINED_ROOTS[0], FPV_SERVER))


class FpvDetonateGateTests(unittest.TestCase):
    """The request never reaches any effect while the feature flag is off."""

    def test_server_only(self) -> None:
        self.assertIn("if (!isServer) exitWith {}", detonate_code())

    def test_flag_gate_is_first_and_numeric(self) -> None:
        code = detonate_code()
        gate = code.find('getVariable ["WFBE_C_FPV_DRONE", 0]) <= 0')
        self.assertNotEqual(gate, -1, "flag gate must use the <= 0 numeric form")
        # Nothing may mutate world state before the gate.
        self.assertNotIn("createVehicle", code[:gate])
        self.assertNotIn("setVariable", code[:gate])

    def test_flag_off_creates_no_warhead(self) -> None:
        code = detonate_code()
        gate = code.find('getVariable ["WFBE_C_FPV_DRONE", 0]) <= 0')
        create = code.find("createVehicle")
        self.assertLess(gate, create, "warhead must be created only past the flag gate")


class FpvDetonateInputHardeningTests(unittest.TestCase):
    """Client payload is validated before any use."""

    def test_short_and_malformed_payloads_rejected(self) -> None:
        code = detonate_code()
        self.assertIn("if (count _args < 2) exitWith", code)
        self.assertIn(
            'if (typeName _request != "ARRAY" || {count _request < 3}) exitWith', code
        )

    def test_drone_must_be_a_non_null_object(self) -> None:
        self.assertIn(
            'if (typeName _requestedDrone != "OBJECT" || {isNull _requestedDrone}) exitWith',
            detonate_code(),
        )

    def test_capability_must_be_a_non_empty_string(self) -> None:
        self.assertIn(
            'if (typeName _detCap != "STRING" || {_detCap == ""}) exitWith',
            detonate_code(),
        )

    def test_origin_position_rejected(self) -> None:
        code = detonate_code()
        self.assertIn("abs ((_pos select 0)) < 1", code)
        self.assertIn("abs ((_pos select 1)) < 1", code)


class FpvDetonateStateMachineTests(unittest.TestCase):
    """Every _atomicState branch is reachable, distinct, and terminal."""

    REJECT_STATES = (1, 2, 3, 4, 7)

    def test_all_reject_states_exit(self) -> None:
        code = detonate_code()
        for state in self.REJECT_STATES:
            self.assertIn(
                "if (_atomicState == %d) exitWith {" % state,
                code,
                "reject state %d must be terminal" % state,
            )

    def test_state_five_schedules_retry_and_exits(self) -> None:
        code = detonate_code()
        self.assertIn("if (_atomicState == 5) exitWith {", code)

    def test_accept_state_is_the_only_fallthrough(self) -> None:
        """State 6 has no exitWith - it falls through to createVehicle."""
        code = detonate_code()
        self.assertIn("_atomicState = 6", code)
        self.assertNotIn("if (_atomicState == 6) exitWith", code)

    def test_each_state_assigned_exactly_once(self) -> None:
        code = detonate_code()
        for state in (1, 2, 3, 6, 7):
            hits = len(re.findall(r"_atomicState = %d\b" % state, code))
            self.assertEqual(hits, 1, "state %d assigned %d times" % (state, hits))
        # State 4 is the shared ownership-stamp rejection: bad stamp shape OR
        # a live drone whose network owner no longer matches the mint stamp.
        self.assertEqual(len(re.findall(r"_atomicState = 4\b", code)), 2)
        # State 5 is the retry mint, guarded by the pending marker.
        self.assertEqual(len(re.findall(r"_atomicState = 5\b", code)), 1)

    def test_transaction_is_unscheduled(self) -> None:
        """The lookup/validate/consume block must run inside isNil {} so it
        cannot yield mid-transaction and let a replay double-fire."""
        code = detonate_code()
        begin = code.find("_atomicState = 0;")
        self.assertNotEqual(begin, -1)
        self.assertIn("isNil {", code[begin : begin + 60])
        body_end = code.find("if (_atomicState == 1) exitWith")
        body = code[begin:body_end]
        for yielding in ("sleep ", "waitUntil ", "spawn ", "execVM "):
            self.assertNotIn(
                yielding, body, "%r would break atomicity of the transaction" % yielding
            )


class FpvDetonateExactDroneAuthorityTests(unittest.TestCase):
    """The core fix: only the exact server-minted drone+capability pair fires."""

    def test_match_is_object_identity_not_proximity(self) -> None:
        code = detonate_code()
        self.assertIn("_tok == _requestedDrone", code)
        # A forged request must not be able to select a target by scanning.
        transaction = code[code.find("_atomicState = 0;") : code.find("if (_atomicState == 1) exitWith")]
        self.assertNotIn("nearestObjects", transaction)
        self.assertNotIn("nearEntities", transaction)

    def test_capability_must_match_server_mint(self) -> None:
        code = detonate_code()
        self.assertIn('_serverCap = _matchDrone getVariable ["wfbe_fpv_det_cap", ""]', code)
        self.assertIn("_serverCap != _detCap", code)

    def test_ambiguous_registry_is_refused_not_guessed(self) -> None:
        code = detonate_code()
        self.assertIn("if (_matchCount > 1) then {", code)
        self.assertIn("_atomicState = 2", code)

    def test_ownership_stamp_checked_against_live_owner(self) -> None:
        code = detonate_code()
        self.assertIn('_ownerStamp = _matchDrone getVariable ["wfbe_fpv_det_owner", -1]', code)
        self.assertIn("alive _matchDrone && {owner _matchDrone != _ownerStamp}", code)

    def test_capability_is_one_shot_on_accept(self) -> None:
        """Accepting must consume: drop from the registry AND clear the cap."""
        code = detonate_code()
        accept = code.find("_atomicState = 6")
        window = code[:accept]
        self.assertIn("_cArr = _cArr - [_matchDrone]", window)
        self.assertIn('_matchDrone setVariable ["wfbe_fpv_det_cap", ""]', window)

    def test_warhead_spawns_at_server_position_not_client_position(self) -> None:
        code = detonate_code()
        self.assertIn("createVehicle [_ammoClass, _dronePos,", code)
        self.assertNotIn("createVehicle [_ammoClass, _pos,", code)


class FpvDetonateRateLimitTests(unittest.TestCase):
    """Per-side 5s cooldown, and the retry that keeps it from eating a kill."""

    def test_rate_limit_is_per_side_and_five_seconds(self) -> None:
        code = detonate_code()
        self.assertIn('_lastKey = Format ["wfbe_fpv_det_last_%1", str _matchSide]', code)
        self.assertIn("if ((_now - _lastFire) < 5) then {", code)

    def test_last_fire_stamped_only_on_accept(self) -> None:
        """A rate-limited request must not push the cooldown window forward."""
        code = detonate_code()
        stamp = "missionNamespace setVariable [_lastKey, _now]"
        self.assertEqual(code.count(stamp), 1)
        self.assertLess(code.find(stamp), code.find("_atomicState = 6"))

    def test_retry_delay_is_bounded_by_the_remaining_cooldown(self) -> None:
        code = detonate_code()
        self.assertIn("_retryDelay = 5 - (_now - _lastFire)", code)
        self.assertIn("if (_retryDelay < 0) then {_retryDelay = 0}", code)

    def test_retry_revalidates_rather_than_detonating_directly(self) -> None:
        """The retry re-enters the full authority path; it must not shortcut
        to createVehicle with the already-validated match."""
        code = detonate_code()
        retry = code[code.find("if (_atomicState == 5) exitWith {") :]
        retry_body = retry[: retry.find("\n};")]
        self.assertIn("_retryArgs Call KAT_FPVDetonate", retry_body)
        self.assertNotIn("createVehicle", retry_body)


class FpvDetonateRetryCoalescingTests(unittest.TestCase):
    """Replayed requests during a pending retry collapse to one retry script."""

    def test_pending_marker_read_defensively(self) -> None:
        code = detonate_code()
        self.assertIn(
            '_retryPending = _matchDrone getVariable ["wfbe_fpv_det_retry_pending", false]',
            code,
        )
        self.assertIn('if (typeName _retryPending != "BOOL") then {_retryPending = false}', code)

    def test_pending_marker_uses_boolean_truth_not_equality(self) -> None:
        """BOOLCMP trap: A2 OA must not compare Booleans with == / !=."""
        code = detonate_code()
        self.assertIn("if (_retryPending) then {", code)
        self.assertNotIn("_retryPending == true", code)
        self.assertNotIn("_retryPending != false", code)

    def test_second_request_while_pending_is_refused(self) -> None:
        code = detonate_code()
        pending = code.find("if (_retryPending) then {")
        self.assertNotEqual(pending, -1)
        self.assertIn("_atomicState = 7", code[pending : pending + 120])

    def test_marker_set_inside_the_atomic_block_before_scheduling(self) -> None:
        """Set-then-schedule ordering is what makes coalescing race-free."""
        code = detonate_code()
        set_marker = code.find('_matchDrone setVariable ["wfbe_fpv_det_retry_pending", true]')
        self.assertNotEqual(set_marker, -1)
        self.assertLess(set_marker, code.find("if (_atomicState == 1) exitWith"))
        self.assertLess(set_marker, code.find("Spawn {"))

    def test_marker_cleared_before_the_retry_re_enters(self) -> None:
        code = detonate_code()
        clear = code.find('_retryDrone setVariable ["wfbe_fpv_det_retry_pending", false]')
        self.assertNotEqual(clear, -1)
        self.assertLess(clear, code.find("_retryArgs Call KAT_FPVDetonate"))

    def test_retry_tolerates_a_deleted_drone(self) -> None:
        self.assertIn("if (!isNull _retryDrone) then {", detonate_code())


class FpvRearmGraceTests(unittest.TestCase):
    """The 15s dead-drone grace in Support_FPV.sqf."""

    def test_grace_is_fifteen_seconds(self) -> None:
        self.assertIn("_detGrace = 15;", fpv_server_code())

    def test_grace_applies_only_to_a_dead_drone(self) -> None:
        self.assertIn("if (!alive _drone) then {sleep _detGrace};", fpv_server_code())

    def test_grace_precedes_registry_removal(self) -> None:
        """The grace exists so the Killed EH request still finds the drone in
        the exact-match registry. Removing first would defeat it."""
        code = fpv_server_code()
        grace = code.find("if (!alive _drone) then {sleep _detGrace};")
        self.assertNotEqual(grace, -1)
        removal = code.find("_fpvArr2", grace)
        self.assertNotEqual(removal, -1, "registry cleanup must follow the grace")

    def test_grace_grants_no_authority_by_itself(self) -> None:
        """Detonate must still demand the capability; the grace only keeps the
        object addressable."""
        code = detonate_code()
        self.assertIn("_serverCap != _detCap", code)

    def test_registry_is_per_side_array_not_singleton(self) -> None:
        code = fpv_server_code()
        self.assertIn('_fpvKey = Format ["wfbe_fpv_det_arr_%1", str _side]', code)
        self.assertIn("_fpvArr set [count _fpvArr, _drone]", code)


class FpvDetonateA2SafetyTests(unittest.TestCase):
    """No A3-only commands may reach the OA 1.64 engine."""

    BANNED = (
        "isEqualType", "isEqualTo", "pushBack", "findIf", "apply", "remoteExec",
        "distance2D", "getPosVisual", "selectRandom", "params ", "worldSize",
        "joinGroup", "setGroupOwner", "getOrDefault", "deleteAt",
    )

    def test_no_a3_commands(self) -> None:
        for root in MAINTAINED_ROOTS:
            for rel in (DETONATE, FPV_SERVER):
                code = mask_comments(read(root, rel))
                for cmd in self.BANNED:
                    self.assertNotIn(
                        cmd, code, "%s: A3-only %r in %s" % (root.name, cmd, rel)
                    )

    def test_array_append_uses_set_idiom(self) -> None:
        self.assertIn("_fpvArr set [count _fpvArr, _drone]", fpv_server_code())


class FpvDetonateMirrorParityTests(unittest.TestCase):
    """Chernarus is source; Takistan/Zargabad must carry an identical file."""

    def test_all_three_terrains_identical(self) -> None:
        for rel in (DETONATE, FPV_SERVER):
            source = read(MAINTAINED_ROOTS[0], rel)
            for mirror in MAINTAINED_ROOTS[1:]:
                self.assertEqual(
                    source,
                    read(mirror, rel),
                    "%s drifted from the Chernarus source in %s" % (rel, mirror.name),
                )


if __name__ == "__main__":
    unittest.main()
