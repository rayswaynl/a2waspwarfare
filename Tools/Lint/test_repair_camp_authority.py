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


def test_handlespecial_reentrancy_guard_present() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / HANDLE_SPECIAL).read_text(encoding="utf-8")
        assert REENTRANCY_GUARD_CHECK in source, f"{terrain}: repair-camp reentrancy check missing"
        assert REENTRANCY_GUARD_SET in source, f"{terrain}: repair-camp reentrancy flag never set"
        # Set once (top of case) + released on the two exit paths (alive-camp reject, success) = 3.
        assert source.count(REENTRANCY_GUARD_RELEASE) == 2, (
            f"{terrain}: expected exactly 2 reentrancy-flag releases (alive-reject + success)"
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
