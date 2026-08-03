from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (MISSION / relative).read_text(encoding="utf-8")


def test_stage_a_constants_keep_owner_armed_defaults():
    source = read("Common/Init/Init_CommonConstants.sqf")

    assert 'WFBE_C_AICOM_CARGO_AIRDROP_ENABLE") then {WFBE_C_AICOM_CARGO_AIRDROP_ENABLE = 1}' in source
    assert 'WFBE_C_AICOM_CARGO_AIRDROP_COOLDOWN") then {WFBE_C_AICOM_CARGO_AIRDROP_COOLDOWN = 1800}' in source
    assert 'WFBE_C_AICOM_CARGO_AIRDROP_COST") then {WFBE_C_AICOM_CARGO_AIRDROP_COST = 60000}' in source
    assert 'WFBE_C_AICOM_CARGO_AIRDROP_VEHICLES_MAX") then {WFBE_C_AICOM_CARGO_AIRDROP_VEHICLES_MAX = 2}' in source


def test_stage_a_worker_is_registered_and_triggered():
    # NOTE: this test originally also asserted 'ESCORT not in trigger' as proof Stage A
    # shipped with no escort code. Stage B (test_cargo_airdrop_stage_b.py) intentionally
    # adds escort logic to AI_Commander_CargoAirdrop.sqf behind its own flag, so
    # that assertion is now retired here and re-asserted (as "escort is flag-gated, not
    # unconditional") in the Stage B test file instead.
    init_server = read("Server/Init/Init_Server.sqf")
    commander = read("Server/AI/Commander/AI_Commander.sqf")

    assert "KAT_CargoAirdrop = Compile preprocessFile" in init_server
    assert "WFBE_SE_FNC_AI_Com_CargoAirdrop = Compile preprocessFileLineNumbers" in init_server
    assert "WFBE_SE_FNC_AI_Com_CargoAirdrop" in commander
    assert "ESCORT" not in init_server


def test_stage_a_trigger_reserves_air_headroom_before_debiting():
    source = read("Server/AI/Commander/AI_Commander_CargoAirdrop.sqf")

    assert "WFBE_C_AICOM_CARGO_AIRDROP_ENABLE" in source
    assert "wfbe_aicom_cargo_last" in source
    assert "WFBE_C_AICOM_AIR_MAX_TOTAL" in source
    assert "_airAlive" in source
    assert "_airAlive + 1" in source
    assert "GetAICommanderFunds" in source
    assert "ChangeAICommanderFunds" in source
    assert source.index("_airAlive + 1") < source.index("ChangeAICommanderFunds")


def test_stage_a_delivery_has_ai_bypass_stagger_and_cleanup_order():
    source = read("Server/Support/Support_CargoAirdrop.sqf")
    para_vehicles = read("Server/Support/Support_ParaVehicles.sqf")

    assert "_isAI = !(isPlayer (leader _playerTeam));" in para_vehicles
    assert "_isAI = !(isPlayer (leader _playerTeam));" in source
    assert "_vehicleCount" in source
    assert "attachTo [_vehicle" in source
    assert "sleep 3" in source
    assert "WFBE_C_AICOM_CARGO_AIRDROP_VEHICLES_MAX" in source
    assert source.rindex("deleteVehicle") < source.rindex("deleteGroup")
