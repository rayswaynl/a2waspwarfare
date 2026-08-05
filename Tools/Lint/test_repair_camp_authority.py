#!/usr/bin/env python3
"""Regression checks for the "repair-camp" ownership-flip closure (harden-repair-camp,
2026-07-25).

Bug: Server_HandleSpecial.sqf's "repair-camp" case rebuilt a destroyed camp bunker and set its
side from client-supplied args with no ownership/proximity check, no cooldown, and no sender
identity at all - the generic RequestSpecial PVF bus carries no sender authentication, so a
forged ["repair-camp", anyLogic, anySideID] payload could flip ANY camp to ANY side, for free,
from anywhere on the map.

Fix: RequestSpecial.sqf (the PVF entrypoint - the ONLY path a network client can reach this case
through) now requires legitimate player repairs to also send the caller's own `player` object and
rejects the request before it ever reaches HandleSpecial unless that requester is a live player,
within WFBE_C_CAMPS_REPAIR_SERVER_RADIUS of the camp logic, and actually of the claimed repair
side. Server_HandleSpecial.sqf additionally gets a caller-agnostic reentrancy flag (mirrors the
Server_MHQRepair.sqf / PR #1361 precedent) so two near-simultaneous requests for the same camp
cannot double-spawn a bunker.

Deliberately NOT gated: the server-internal presence-repair caller (server_town_camp.sqf, "AI
soldiers repair a destroyed camp by standing in its bubble") drives the same case body via a
direct `call HandleSpecial` that never passes through RequestSpecial.sqf at all - it must keep
working unauthenticated-by-design since it is 100% server-computed, not client input.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)

REQUEST_SPECIAL = "Server/PVFunctions/RequestSpecial.sqf"
HANDLE_SPECIAL = "Server/Functions/Server_HandleSpecial.sqf"
CONSTANTS = "Common/Init/Init_CommonConstants.sqf"
ACTION_FILES = (
    "Client/Action/Action_RepairCamp.sqf",
    "Client/Action/Action_RepairCampEngineer.sqf",
)

RADIUS_CONST = "WFBE_C_CAMPS_REPAIR_SERVER_RADIUS"

# The PVF-gate guards RequestSpecial.sqf must carry - each is a flat top-level
# `_requestType == "repair-camp" && {...}` exitWith (never nested inside an if/then block; see
# a2-sqf-live-burned-traps #7 on exitWith-in-then-block).
GATE_SNIPPETS = (
    '_requestType == "repair-camp" && {(count _this) < 4}',
    "isPlayer (_this select 3)",
    "alive (_this select 3)",
    f'(_this select 3) distance (_this select 1)) > (missionNamespace getVariable ["{RADIUS_CONST}", 50])',
    "(side group (_this select 3)) != ((_this select 2) Call WFBE_CO_FNC_GetSideFromID)",
)

REENTRANCY_GUARD_CHECK = 'if (_logic getVariable ["wfbe_camp_repairing", false]) exitWith {'
REENTRANCY_GUARD_SET = '_logic setVariable ["wfbe_camp_repairing", true, true];'
REENTRANCY_GUARD_RELEASE = '_logic setVariable ["wfbe_camp_repairing", false, true];'

CLIENT_PAYLOAD = '["repair-camp", _camp, WFBE_Client_SideID, player]'
ENGINEER_ON_FOOT_GUARD = 'if (vehicle _vehicle != _vehicle) exitWith {};'
ENGINEER_LOOP_ON_FOOT_GUARD = 'if (!alive _vehicle || (vehicle _vehicle != _vehicle)'


def test_pvf_gate_present_on_all_terrains() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / REQUEST_SPECIAL).read_text(encoding="utf-8")
        for snippet in GATE_SNIPPETS:
            assert snippet in source, f"{terrain}: RequestSpecial.sqf missing repair-camp guard: {snippet!r}"
        # None of the guards may live inside an `if () then {}` wrapper - every occurrence of
        # the gate condition must be a direct top-level exitWith line.
        assert source.count('if (_requestType == "repair-camp"') == 8, (
            f"{terrain}: expected exactly 8 flat repair-camp guards in RequestSpecial.sqf"
        )


def _exitwith_block_spans(source: str) -> list:
    """Return brace-matched (open_brace_index, close_brace_index) spans for every
    `exitWith {...}` block in ``source``. Brace-matched (not regex-greedy) because these
    blocks routinely contain their own nested `{}` - e.g. `&& {isPlayer _x}` conditions or an
    inner `if () then {}` - which would truncate a naive scan early."""
    marker = "exitWith {"
    spans = []
    i = 0
    while True:
        idx = source.find(marker, i)
        if idx == -1:
            break
        open_brace = idx + len(marker) - 1
        depth = 1
        j = open_brace + 1
        while depth > 0 and j < len(source):
            if source[j] == "{":
                depth += 1
            elif source[j] == "}":
                depth -= 1
            j += 1
        spans.append((open_brace, j))
        i = j
    return spans


# Statements that only belong to "the repair actually happened" work. If an early-exit
# release (one sitting inside an `exitWith {}` block) shares a block with any of these, that
# block is not a clean bail-out - it is doing real camp-mutation work AND releasing the guard
# in the same breath, which reopens the double-spawn race harden-repair-camp closed.
_CAMP_MUTATION_MARKERS = (
    "createVehicle [",
    "setDir (",
    "setPos [",
    "setPosASL [",
    "addEventHandler [",
    'setVariable ["wfbe_camp_bunker"',
    'setVariable ["sideID"',
    "WFBE_CO_FNC_SendToClients",
)


def test_handlespecial_reentrancy_guard_present() -> None:
    """Behavioural version of the harden-repair-camp reentrancy contract: the flag must be
    acquired exactly once per call, every early-exit release must be a clean bail-out with no
    camp-mutation work sharing its `exitWith` block, and exactly one release must survive
    outside any `exitWith` block (the success path) - and that one must come only after the
    bunker was actually created and registered, with no further camp mutation after it. This
    intentionally does NOT hard-code a literal release count: a fold may legitimately add
    another early-abort path (e.g. a `createVehicle` failure guard) without invalidating the
    test, so long as that path stays a clean bail-out per the checks above.
    """
    for terrain in TERRAINS:
        source = (ROOT / terrain / HANDLE_SPECIAL).read_text(encoding="utf-8")
        assert REENTRANCY_GUARD_CHECK in source, f"{terrain}: repair-camp reentrancy check missing"
        assert REENTRANCY_GUARD_SET in source, f"{terrain}: repair-camp reentrancy flag never set"

        case_start = source.index('case "repair-camp": {')
        case_end = source.index('\n\tcase "', case_start + 1)
        body = source[case_start:case_end]

        assert body.count(REENTRANCY_GUARD_SET) == 1, (
            f"{terrain}: expected the reentrancy flag to be acquired exactly once per repair-camp call"
        )
        set_index = body.index(REENTRANCY_GUARD_SET)

        release_indices = []
        cursor = 0
        while True:
            idx = body.find(REENTRANCY_GUARD_RELEASE, cursor)
            if idx == -1:
                break
            release_indices.append(idx)
            cursor = idx + 1

        assert len(release_indices) >= 2, (
            f"{terrain}: expected at least 2 reentrancy-flag releases (alive-reject + success)"
        )
        assert all(idx > set_index for idx in release_indices), (
            f"{terrain}: a reentrancy-flag release appears before the flag is even acquired"
        )

        blocks = _exitwith_block_spans(body)

        tail_releases = []
        for idx in release_indices:
            enclosing = next(((o, c) for (o, c) in blocks if o <= idx < c), None)
            if enclosing is None:
                tail_releases.append(idx)
                continue
            block_text = body[enclosing[0]:enclosing[1]]
            for marker in _CAMP_MUTATION_MARKERS:
                assert marker not in block_text, (
                    f"{terrain}: an early-exit reentrancy release shares its exitWith block with "
                    f"camp-mutation work ({marker!r}) - this releases the guard while a repair "
                    f"may still be in flight"
                )

        # Exactly one release must survive outside every exitWith block: the unconditional
        # success-path release taken once the repair is actually finished. Zero means a leaked
        # (never-released) flag on success; two or more means a duplicate/premature release -
        # both are the reentrancy bug shape this test exists to catch.
        assert len(tail_releases) == 1, (
            f"{terrain}: expected exactly 1 unconditional (success-path) reentrancy release, "
            f"found {len(tail_releases)}"
        )
        tail_index = tail_releases[0]

        assert body.index("createVehicle [") < tail_index, (
            f"{terrain}: success-path reentrancy release happens before the bunker is even created"
        )
        assert body.index('setVariable ["wfbe_camp_bunker"') < tail_index, (
            f"{terrain}: success-path reentrancy release happens before the bunker is registered "
            f"- a concurrent request could pass the alive-check while the bunker is still unset"
        )
        tail = body[tail_index + len(REENTRANCY_GUARD_RELEASE):]
        for marker in _CAMP_MUTATION_MARKERS:
            assert marker not in tail, (
                f"{terrain}: camp-mutation work ({marker!r}) still runs AFTER the reentrancy flag "
                f"is released - the guard no longer covers the full repair"
            )


def test_server_radius_constant_defined_and_consistent() -> None:
    for terrain in TERRAINS:
        constants_source = (ROOT / terrain / CONSTANTS).read_text(encoding="utf-8")
        assert f"{RADIUS_CONST} = 50;" in constants_source, (
            f"{terrain}: {RADIUS_CONST} not defined (or value drifted) in Init_CommonConstants.sqf"
        )
        gate_source = (ROOT / terrain / REQUEST_SPECIAL).read_text(encoding="utf-8")
        assert f'"{RADIUS_CONST}", 50' in gate_source, (
            f"{terrain}: RequestSpecial.sqf radius getVariable default drifted from the defined constant"
        )


def test_client_actions_send_requester_identity() -> None:
    for terrain in TERRAINS:
        for relative in ACTION_FILES:
            source = (ROOT / terrain / relative).read_text(encoding="utf-8")
            assert CLIENT_PAYLOAD in source, (
                f"{terrain}/{relative}: repair-camp request no longer sends `player` as the 4th element"
            )


def test_engineer_repair_requires_an_on_foot_animation_subject() -> None:
    """The engineer action must not run its foot medic animation from a vehicle seat.

    Unlike the standard repair-camp action, this action is attached directly to the
    player and repeatedly issues ``playMove`` to that action unit.  A seated unit
    cannot perform the foot animation, so reject a seated caller before charging
    and also cancel/refund if the player boards during the repair delay.
    """
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Client/Action/Action_RepairCampEngineer.sqf").read_text(encoding="utf-8")
        assert ENGINEER_ON_FOOT_GUARD in source, (
            f"{terrain}: engineer repair does not reject a seated player before charging"
        )
        assert source.index(ENGINEER_ON_FOOT_GUARD) < source.index("//--- Check if the repair is free"), (
            f"{terrain}: engineer on-foot guard must precede the funds debit path"
        )
        loop_start = source.index("while {_delay > 0} do {")
        assert ENGINEER_LOOP_ON_FOOT_GUARD in source, (
            f"{terrain}: engineer repair loop does not cancel when the player boards"
        )
        assert source.index(ENGINEER_LOOP_ON_FOOT_GUARD, loop_start) < source.index("_vehicle playMove", loop_start), (
            f"{terrain}: engineer repair issues playMove before checking for a vehicle seat"
        )
        cancellation_start = source.index("if (!(alive _vehicle)")
        cancellation_end = source.index("};", cancellation_start)
        cancellation = source[cancellation_start:cancellation_end]
        assert "(vehicle _vehicle != _vehicle)" in cancellation, (
            f"{terrain}: engineer repair does not refund when boarding cancels the action"
        )


def test_internal_presence_repair_caller_untouched() -> None:
    # server_town_camp.sqf's presence-repair caller must keep calling with exactly 3 args (no
    # player) - it is the one legitimate caller the PVF gate above intentionally cannot see, and
    # it must still reach the (still caller-agnostic) reentrancy/alive guards inside HandleSpecial.
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/FSM/server_town_camp.sqf").read_text(encoding="utf-8")
        assert '["repair-camp", _camp, _repairSideID] call HandleSpecial;' in source, (
            f"{terrain}: server-internal presence-repair call signature changed unexpectedly"
        )


if __name__ == "__main__":
    test_pvf_gate_present_on_all_terrains()
    test_handlespecial_reentrancy_guard_present()
    test_server_radius_constant_defined_and_consistent()
    test_client_actions_send_requester_identity()
    test_internal_presence_repair_caller_untouched()
    print("repair-camp authority-hardening regression checks passed")
