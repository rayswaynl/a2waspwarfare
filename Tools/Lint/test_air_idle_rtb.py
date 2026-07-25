"""Structural contract for the opt-in retained-air idle RTB/recycle path."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONSTANTS = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"
RUNNER = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf"


def test_idle_rtb_constants_are_present_and_inert_by_default():
    source = CONSTANTS.read_text(encoding="utf-8")
    assert 'WFBE_C_AICOM_AIR_IDLE_RTB = 0' in source
    assert 'WFBE_C_AICOM_AIR_IDLE_MINUTES = 0' in source
    assert 'WFBE_C_AICOM_AIR_IDLE_SENSE_R = 0' in source


def test_idle_rtb_reuses_the_existing_hc_air_watcher_and_safety_guards():
    source = RUNNER.read_text(encoding="utf-8")
    start = source.index("//--- B74.2 HELI BASE-REAP")
    end = source.index("}; //--- B66 end if (_hasAttackHeli)", start)
    block = source[start:end]

    assert "WFBE_C_AICOM_AIR_IDLE_RTB" in source
    assert 'if ((missionNamespace getVariable ["WFBE_C_AICOM_HELI_CANNON_NUDGE", 1]) > 0 || {_idleRtbEnabled}) then {' in source
    assert 'if (_rAttack || {_idleRtbEnabled && {_rTransport}}) then {' in block
    assert 'if ((!_rMoving && {_rAtBase}) || {_idleRtbEnabled}) then {' in block
    assert "WFBE_C_AICOM_AIR_IDLE_MINUTES" in block
    assert "WFBE_C_AICOM_AIR_IDLE_SENSE_R" in block
    assert "WFBE_CO_FNC_AICOMAirReturn" in block
    assert "wfbe_aicom_air_idle_at" in block
    assert "wfbe_aicom_transport" in block
    assert "wfbe_aicom_airborne_until" in block
    assert "isPlayer" in block
    assert "(vehicle _x) == _rh" in block
    assert 'if (alive _x && {behaviour _x == "COMBAT"}) then {_rEngaged = true}' in block
    assert 'private ["_h","_tm","_sd","_recheckBusy"' in block
    assert "_recheckEnRoute" in block
    assert "_recheckAirborne" in block
    assert "local _rh" in block

    # The feature must consume the existing proximity read, not add another sweep.
    assert block.count("nearEntities") == 1


def test_idle_rtb_keeps_delete_order_local_and_crew_first():
    source = RUNNER.read_text(encoding="utf-8")
    start = source.index("//--- B74.2 HELI BASE-REAP")
    block = source[start:]
    crew_delete = block.index("deleteVehicle _x")
    hull_delete = block.index("deleteVehicle _rh")
    assert crew_delete < hull_delete
