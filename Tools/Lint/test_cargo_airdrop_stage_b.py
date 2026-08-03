from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (MISSION / relative).read_text(encoding="utf-8")


def test_stage_b_constants_keep_owner_armed_defaults():
    source = read("Common/Init/Init_CommonConstants.sqf")

    assert 'WFBE_C_AICOM_CARGO_AIRDROP_CREW_VEHICLES") then {WFBE_C_AICOM_CARGO_AIRDROP_CREW_VEHICLES = 1}' in source
    assert 'WFBE_C_AICOM_CARGO_AIRDROP_PARATROOP_EXTRA") then {WFBE_C_AICOM_CARGO_AIRDROP_PARATROOP_EXTRA = 0}' in source
    assert 'WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_ENABLE") then {WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_ENABLE = 1}' in source
    assert 'WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_COST") then {WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_COST = 35000}' in source
    assert 'WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_CLASSES") then {WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_CLASSES' in source


def test_stage_b_escort_is_flag_gated_not_unconditional():
    trigger = read("Server/AI/Commander/AI_Commander_CargoAirdrop.sqf")
    worker = read("Server/Support/Support_CargoAirdrop.sqf")

    # Escort logic exists (Stage A's own regression test now only forbids it from
    # Init_Server.sqf, since the master flag/dispatch wiring never changed there).
    assert "WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_ENABLE" in trigger
    assert "_spawnEscort" in trigger
    assert "_spawnEscort" in worker
    # The escort decision is gated behind the enable flag, not fired unconditionally.
    assert 'if (_escortEnable > 0) then {' in trigger


def test_stage_b_headroom_reserves_two_hulls_for_escort_and_degrades_gracefully():
    source = read("Server/AI/Commander/AI_Commander_CargoAirdrop.sqf")

    # Base 1-hull reservation (Stage A, unchanged) must still run before the Stage B
    # escort reservation, which itself requires headroom for 2 hulls together.
    assert source.index("_airAlive + 1 > _airMax") < source.index("_airAlive + 2 <= _airMax")
    # Escort degrades to off (not a full-call skip) when only cargo-alone fits.
    assert "cargo drop escort dropped this call at shared air cap" in source
    # Escort degrades to off (not a full-call skip) when funds cover cargo but not both.
    assert "cargo drop escort dropped this call for funds" in source


def test_stage_b_escort_cost_is_additive_and_conditional():
    source = read("Server/AI/Commander/AI_Commander_CargoAirdrop.sqf")

    assert "_escortCost = missionNamespace getVariable [\"WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_COST\"" in source
    assert "_cost = _cost + _escortCost" in source
    # The base funds gate (unmodified Stage A check) runs before any escort cost is added.
    assert source.index("if (_funds < _cost) exitWith") < source.index("_cost = _cost + _escortCost")


def test_stage_b_log_line_is_byte_identical_to_stage_a_when_escort_is_off():
    source = read("Server/AI/Commander/AI_Commander_CargoAirdrop.sqf")

    stage_a_log = (
        '["INFORMATION", Format ["AI_Commander_CargoAirdrop.sqf: [%1] cargo drop called to '
        '[%2] (para level %3, cost %4, air %5/%6).", _sideText, _objName, _paraLvl, _cost, '
        '_airAlive + 1, _airMax]] Call WFBE_CO_FNC_AICOMLog;'
    )
    assert stage_a_log in source
    assert "if (!_spawnEscort) then {" in source


def test_stage_b_crew_vehicles_flag_wired_with_mount_on_landing_guard():
    source = read("Server/Support/Support_CargoAirdrop.sqf")

    assert "WFBE_C_AICOM_CARGO_AIRDROP_CREW_VEHICLES" in source
    assert "_crewVehicles" in source
    # Never mounts crew without first confirming the vehicle has settled (near-ground,
    # near-zero vertical speed) - the mount-on-landing safety gate.
    assert "_settled" in source
    assert "getPosATL _cargo" in source
    assert "velocity _cargo" in source
    assert source.index("_settled = true") < source.index("moveInDriver _cargo")


def test_stage_b_paratroop_extra_is_clamped_to_plane_capacity():
    source = read("Server/Support/Support_CargoAirdrop.sqf")

    assert "WFBE_C_AICOM_CARGO_AIRDROP_PARATROOP_EXTRA" in source
    assert "_extraCount = _vehicleCargo - count _units" in source
    assert "if (_extraCount > _paratroopExtra) then {_extraCount = _paratroopExtra}" in source


def test_stage_b_escort_cleanup_precedes_group_delete():
    source = read("Server/Support/Support_CargoAirdrop.sqf")

    # The same deleteGroup-non-empty-group trap Stage A already fixed for the vehicle/pilot
    # path must also hold for the Stage B escort: every escort member deleted before the
    # shared _transportGroup is deleted.
    assert source.rindex("deleteVehicle") < source.rindex("deleteGroup")
    # Use rindex on the group-delete side: earlier failure-exit branches (transport group
    # create failed, plane create failed, etc.) also call deleteGroup _transportGroup before
    # the escort ever exists - only the FINAL cleanup's occurrence matters here.
    final_group_delete = source.rindex("deleteGroup _transportGroup")
    assert source.index("deleteVehicle _escortJet") < final_group_delete
    assert source.index("deleteVehicle _escortPilot") < final_group_delete
    assert source.index("deleteVehicle _escortGunner") < final_group_delete


def test_stage_b_flag_off_leaves_units_array_unchanged():
    source = read("Server/Support/Support_CargoAirdrop.sqf")

    # With PARATROOP_EXTRA at its 0 default this whole block is skipped (count-guarded),
    # leaving _units exactly as Stage A produced it.
    assert "if (_paratroopExtra > 0 && {count _units > 0}) then {" in source
