"""Regression contract for the side-patrol registry authority replacement.

The public RequestSpecial bus has no trusted sender identity.  The patrol registry must therefore
be written and removed only by server-owned code, with the HC startup transition bound to a private
server-minted capability.  Convoy payout additionally needs a live patrol-to-town proximity check.
"""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
HANDLE = MISSION / "Server/Functions/Server_HandleSpecial.sqf"
RUNNER = MISSION / "Common/Functions/Common_RunSidePatrol.sqf"
PATROL_FSM = MISSION / "Server/FSM/server_side_patrols.sqf"
CLIENT_HANDLE = MISSION / "Client/PVFunctions/HandleSpecial.sqf"
INIT_SERVER = MISSION / "Server/Init/Init_Server.sqf"
REGISTER = MISSION / "Server/Functions/Server_RegisterSidePatrol.sqf"
CONVOY_VALIDATE = MISSION / "Server/Functions/Server_GetSidePatrolConvoy.sqf"
CONVOY_SETTLE = MISSION / "Server/Functions/Server_SettleSidePatrolConvoy.sqf"


def _case(text: str, name: str, next_name: str) -> str:
    start = text.index(f'case "{name}"')
    end = text.index(f'case "{next_name}"', start)
    return text[start:end]


def test_server_lifecycle_cases_are_authoritative_and_start_is_capability_bound():
    source = mask_comments(HANDLE.read_text(encoding="utf-8-sig"))
    started = _case(source, "sidepatrol-started", "sidepatrol-ended")
    ended = _case(source, "sidepatrol-ended", "sidepatrol-convoy-stop")

    assert "(count _args) != 6" in started
    assert "WFBE_SE_FNC_ConsumeCapability" in started
    assert "WFBE_SE_FNC_RegisterSidePatrol" in started
    assert "retry window" in started
    assert "missionNamespace setVariable [\"WFBE_ACTIVE_PATROLS\"" not in started
    assert 'publicVariable "WFBE_ACTIVE_PATROLS"' not in started

    assert "WFBE_ACTIVE_PATROLS" not in ended
    assert "wfbe_side_patrols" not in ended
    assert "publicVariable" not in ended


def test_convoy_payout_requires_exact_registry_tuple_and_live_town_proximity():
    source = mask_comments(HANDLE.read_text(encoding="utf-8-sig"))
    payout = _case(source, "sidepatrol-convoy-stop", "hc-preseat")

    assert "(count _args) != 9" in payout
    assert "WFBE_SE_FNC_ConsumeCapability" in payout
    assert "WFBE_SE_FNC_SettleSidePatrolConvoy" in payout
    assert "owner _cLiveLdr != owner _cAuth" in payout
    challenge = _case(source, "sidepatrol-convoy-challenge", "sidepatrol-convoy-stop")
    assert "WFBE_HEADLESSCLIENTS_ID" in challenge
    assert "owner (leader _x) == owner _qLiveLdr" in challenge

    validate = mask_comments(CONVOY_VALIDATE.read_text(encoding="utf-8-sig"))
    assert "_cLiveLdr distance _cTown" in validate
    assert "_cTruckFound" in validate
    assert "_cTruckType in _cTruckList" in validate
    assert "_cTown in _cPaid" in validate
    assert "_cDispatchID" in validate

    settle = mask_comments(CONVOY_SETTLE.read_text(encoding="utf-8-sig"))
    assert "_cEntry set [3, _cPaid]" in settle
    assert "publicVariable \"WFBE_ACTIVE_PATROLS\"" in settle


def test_honest_runner_carries_one_captured_leader_and_hc_capability():
    source = mask_comments(RUNNER.read_text(encoding="utf-8-sig"))

    assert "_ldr = leader _team;" in source
    assert '["sidepatrol-started", _sideID, _ldr, _authPlayer, _dispatchID, _authToken]' in source
    assert '["sidepatrol-convoy-challenge", _sideID, _target, _dispatchID, _ldr, _truckVeh, _convoyChallenge]' in source
    assert '["sidepatrol-convoy-stop", _sideID, _target, _dispatchID, _ldr, _truckVeh, _authPlayer, _convoyChallenge, _convoyToken]' in source
    assert "WFBE_SE_FNC_SettleSidePatrolConvoy" in source
    assert '"sidepatrol-ended"' not in source
    assert "_dispatchID" in source
    assert "wfbe_sidepatrol_cap_client_" in source


def test_server_dispatch_mints_private_capability_before_hc_run():
    source = mask_comments(PATROL_FSM.read_text(encoding="utf-8-sig"))

    assert "WFBE_SE_FNC_MintCapability" in source
    assert "_dispatchID" in source
    mint = source.index("WFBE_SE_FNC_MintCapability")
    delegate = source.index("'delegate-sidepatrol'")
    assert mint < delegate
    assert "sidepatrol-start" in source
    assert "_entry select 2" in source
    assert "_entry select 3" in source
    assert "publicVariable \"WFBE_ACTIVE_PATROLS\"" in source


def test_client_accepts_only_private_sidepatrol_capability_reply():
    source = mask_comments(CLIENT_HANDLE.read_text(encoding="utf-8-sig"))
    case = _case(source, "sidepatrol-capability", "delegate-townai")

    assert "sidepatrol-start" in case
    assert "wfbe_sidepatrol_cap_client_" in case
    assert "publicVariable" not in case

    convoy_case = _case(source, "sidepatrol-convoy-capability", "delegate-townai")
    assert "sidepatrol-convoy" in convoy_case
    assert "wfbe_sidepatrol_convoy_cap_client_" in convoy_case


def test_server_registration_function_and_init_are_present():
    source = mask_comments(REGISTER.read_text(encoding="utf-8-sig"))
    init = INIT_SERVER.read_text(encoding="utf-8-sig")

    assert "if (!isServer) exitWith" in source
    assert "WFBE_ACTIVE_PATROLS" in source
    assert "publicVariable \"WFBE_ACTIVE_PATROLS\"" in source
    assert "_group, [], _dispatchID" in source
    assert "Server_GetSidePatrolConvoy.sqf" in init
    assert "Server_SettleSidePatrolConvoy.sqf" in init
    assert 'WFBE_SE_FNC_RegisterSidePatrol = Compile preprocessFileLineNumbers "Server\\Functions\\Server_RegisterSidePatrol.sqf";' in init


if __name__ == "__main__":
    for test in (
        test_server_lifecycle_cases_are_authoritative_and_start_is_capability_bound,
        test_convoy_payout_requires_exact_registry_tuple_and_live_town_proximity,
        test_honest_runner_carries_one_captured_leader_and_hc_capability,
        test_server_dispatch_mints_private_capability_before_hc_run,
        test_client_accepts_only_private_sidepatrol_capability_reply,
        test_server_registration_function_and_init_are_present,
    ):
        test()
    print("Side-patrol registry authority contract: PASS")
