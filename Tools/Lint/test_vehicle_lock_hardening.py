"""Static contract checks for the flag-gated RequestVehicleLock hardening lane."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def read(relative: str) -> str:
    return (CH / relative).read_text(encoding="utf-8-sig")


def test_server_guard_revalidates_identity_scope_and_consumes_before_unlock():
    source = read("Server/PVFunctions/RequestVehicleLock.sqf")

    for required in (
        'missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]',
        "WFBE_SE_FNC_MintCapability",
        "WFBE_SE_FNC_ConsumeCapability",
        '"vehicle-lock"',
        'getVariable ["wfbe_side_id", -1]',
        "alive _actor",
        "isPlayer _actor",
        "_actor distance _vehicle",
        "_locked",
        "if (_rejected) exitWith {};",
    ):
        assert required in source, required

    assert source.index("WFBE_SE_FNC_ConsumeCapability") < source.index("_vehicle lock _locked")


def test_honest_client_completes_private_capability_handshake_only_for_matching_challenge():
    caller = read("Client/Module/Skill/Skill_SpecOps.sqf")
    receiver = read("Client/PVFunctions/HandleSpecial.sqf")

    for required in (
        "wfbe_vehicle_lock_pending",
        "diag_tickTime",
        '"vehicle-lock-capability"',
        '"RequestVehicleLock"',
    ):
        assert required in caller or required in receiver, required

    assert 'case "vehicle-lock-capability"' in receiver
    assert "_lockChallenge != _lockExpectedChallenge" in receiver
    assert receiver.index('case "vehicle-lock-capability"') < receiver.index('case "fpv-auth-token"')


def test_hardening_is_flag_off_and_mirrored_source_is_expected_to_be_identical():
    source = read("Server/PVFunctions/RequestVehicleLock.sqf")
    assert 'getVariable ["WFBE_C_SEC_HARDENING", 0]' in source
    assert "WFBE_C_SEC_HARDENING               = 0" in read("Common/Init/Init_CommonConstants.sqf")
