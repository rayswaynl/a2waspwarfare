"""Static contract for the semantic PR #1464 reconcile port.

Arma 2 OA is not available to the repository test runner, so these checks
pin the cross-file contracts that would otherwise be easy to lose while
porting the old PR onto the much newer wave tip: the decision worker must be
registered and called at the intended strategy boundary, the disabled feature
must have five zero defaults, and the locality-side executor must receive a
signal for server-local as well as HC-owned teams while preserving the live
order payload and invalidating stale road geometry.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def _read(rel: str) -> str:
    return (MISSION / rel).read_text(encoding="utf-8-sig")


def test_strategy_worker_is_registered_and_called_before_hq_hunt() -> None:
    init_server = _read("Server/Init/Init_Server.sqf")
    strategy = _read("Server/AI/Commander/AI_Commander_Strategy.sqf")

    assert (
        'WFBE_SE_FNC_AI_Com_EndgameTeleport = Compile '
        'preprocessFileLineNumbers "Server\\AI\\Commander\\AI_Commander_EndgameTeleport.sqf";'
    ) in init_server
    call = "[_side, _teams, _attacked, _ownTownObjs, _myHQ] Call WFBE_SE_FNC_AI_Com_EndgameTeleport;"
    assert call in strategy
    assert strategy.index(call) < strategy.index("//--- 3) HQ HUNT:")


def test_constants_keep_every_endgame_teleport_default_disabled() -> None:
    constants = _read("Common/Init/Init_CommonConstants.sqf")
    names = (
        "ENABLE",
        "MIN_TIME",
        "COOLDOWN",
        "MAX_PER_TICK",
        "MIN_DIST",
    )

    for suffix in names:
        needle = f'WFBE_C_AICOM_ENDGAME_TELEPORT_{suffix} = 0'
        assert needle in constants


def test_decision_worker_stamps_server_and_hc_teams_with_the_same_signal() -> None:
    decision = _read("Server/AI/Commander/AI_Commander_EndgameTeleport.sqf")

    assert 'WFBE_C_AICOM_ENDGAME_TELEPORT_ENABLE", 0' in decision
    assert 'if !(_side in [west, east]) exitWith {};' in decision
    assert "!isPlayer _leader" in decision
    assert "{isPlayer _x} count (units _team)" in decision
    assert "local _leader" in decision
    assert "_leader distance _myHQ" in decision
    assert "_team setVariable [\"wfbe_aicom_endgame_tp\", [_destination, time], true];" in decision

    signal_at = decision.index(
        '_team setVariable ["wfbe_aicom_endgame_tp", [_destination, time], true];'
    )
    hc_gate_at = decision.index(
        'if ([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool'
    )
    hc_region = decision[hc_gate_at:signal_at]
    assert hc_region.count("{") == hc_region.count("}")


def test_executor_has_player_water_and_stale_route_guards() -> None:
    driver = _read("Common/Functions/Common_RunCommanderTeam.sqf")

    assert '_egtSig = _team getVariable "wfbe_aicom_endgame_tp";' in driver
    assert "WFBE_CO_FNC_RealPlayersNear" in driver
    assert "!surfaceIsWater _egtPos" in driver
    assert '_team setVariable ["wfbe_aicom_route", [], true];' in driver
    assert '_team setVariable ["wfbe_aicom_route_seq", _egtFlushSeq + 1, true];' in driver
    assert "_egtFlushOrder select 3" in driver
    assert "_team setVariable [\"wfbe_aicom_order\", _egtFlushOrder, true];" not in driver
