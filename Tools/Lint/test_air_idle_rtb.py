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
    assert 'private ["_h","_tm","_sd","_recheckCrew","_recheckBusy"' in block
    assert "_recheckCrew = [];" in block
    assert "_recheckCrew = crew _h;" in block
    assert "_recheckEnRoute" in block
    assert "_recheckAirborne" in block
    assert "local _rh" in block

    # The feature must consume the existing proximity read, not add another sweep.
    assert block.count("nearEntities") == 1


def test_idle_rtb_keeps_delete_order_local_and_crew_first():
    # PR #1885 (staging wave 2026-08-02): the reap now dispatches to the seat-safe helper instead of
    # inline deletes; the crew-before-hull invariant lives in Common_SafeCrewDelete.sqf.
    source = RUNNER.read_text(encoding="utf-8")
    start = source.index("//--- B74.2 HELI BASE-REAP")
    block = source[start:]
    assert "[_rh, true] Spawn WFBE_CO_FNC_SafeCrewDelete" in block
    helper = (RUNNER.parent / "Common_SafeCrewDelete.sqf").read_text(encoding="utf-8")
    crew_delete = helper.index("deleteVehicle _crewMember")
    hull_delete = helper.index("deleteVehicle _hull")
    assert crew_delete < hull_delete


def test_idle_rtb_timer_resets_when_a_veto_interrupts_the_idle_streak():
    """Regression test for the PR #1452 review defect: the idle-RTB
    if-statement's own then-block closed with no else, so a veto (busy /
    airborne / engaged / en-route-to-order / player-crewed) that interrupted
    an in-progress idle streak never cleared wfbe_aicom_air_idle_at. Once the
    veto lifted, the stale timestamp let RTB fire immediately instead of only
    after a fresh WFBE_C_AICOM_AIR_IDLE_MINUTES of genuinely uninterrupted
    idleness. The fix mirrors the legacy reap timer's own else, which already
    resets wfbe_heli_baseidle_at the same way."""
    source = RUNNER.read_text(encoding="utf-8")
    start = source.index("//--- B74.2 HELI BASE-REAP")
    end = source.index("}; //--- B66 end if (_hasAttackHeli)", start)
    block = source[start:end]

    idle_if = (
        "if (_idleRtbEnabled && {!_rAtBase} && {!_rPlayerCrew} && {!_rBusy} "
        "&& {!_rAirborne} && {!_rEngaged} && {!_rEnRoute}) then {"
    )
    assert idle_if in block

    # This exact, deeply-indented else belongs to the idle-RTB if itself (its
    # indentation matches the if, not the shallower outer wrapper's own
    # differently-indented else a few lines further down that resets the same
    # variable for an unrelated, pre-existing reason).
    reset_else = (
        "} else {\n"
        '\t\t\t\t\t\t\t\t\t\t\t_rh setVariable ["wfbe_aicom_air_idle_at", nil];\n'
        "\t\t\t\t\t\t\t\t\t\t};"
    )
    assert reset_else in block, (
        "idle-RTB if-statement has no else resetting wfbe_aicom_air_idle_at "
        "on veto interruption (mirror the legacy wfbe_heli_baseidle_at reset)"
    )
    assert block.index(reset_else) > block.index(idle_if)
