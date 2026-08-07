"""Regression contract for AI commander HQ recovery after destruction."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def test_ai_hq_repurchase_is_delayed_town_scoped_and_treasury_paid() -> None:
    for mission in MISSIONS:
        recovery = (ROOT / mission / "Server/AI/Commander/AI_Commander_HQRecovery.sqf").read_text(
            encoding="utf-8"
        )
        hq_killed = (ROOT / mission / "Server/Functions/Server_OnHQKilled.sqf").read_text(
            encoding="utf-8"
        )
        victory = (ROOT / mission / "Server/FSM/server_victory_threeway.sqf").read_text(
            encoding="utf-8"
        )

        assert 'WFBE_C_AICOM_HQ_REPURCHASE_ENABLE", 0]) > 0' in hq_killed
        assert 'wfbe_aicom_hq_recovery_pending' in hq_killed
        assert 'WFBE_C_AICOM_HQ_REPURCHASE_DELAY' in recovery
        assert 'WFBE_C_STRUCTURES_HQ_COST_DEPLOY' in recovery
        assert 'Call GetAICommanderFunds' in recovery
        assert 'Call ChangeAICommanderFunds' in recovery
        assert 'forEach towns' in recovery
        assert 'getVariable ["sideID", -1]' in recovery
        assert 'Call MHQRepair' in recovery
        assert 'wfbe_aicom_hq_recovery_pending' in victory


def test_repurchase_flag_and_delay_constant_are_registered_once_in_each_mission() -> None:
    for mission in MISSIONS:
        constants = (ROOT / mission / "Common/Init/Init_CommonConstants.sqf").read_text(
            encoding="utf-8"
        )

        assert constants.count('if (isNil "WFBE_C_AICOM_HQ_REPURCHASE_ENABLE")') == 1
        assert constants.count('if (isNil "WFBE_C_AICOM_HQ_REPURCHASE_DELAY")') == 1


def test_repeat_hq_loss_cannot_reuse_an_older_recovery_worker() -> None:
    for mission in MISSIONS:
        recovery = (ROOT / mission / "Server/AI/Commander/AI_Commander_HQRecovery.sqf").read_text(
            encoding="utf-8"
        )
        hq_killed = (ROOT / mission / "Server/Functions/Server_OnHQKilled.sqf").read_text(
            encoding="utf-8"
        )

        assert 'wfbe_aicom_hq_recovery_epoch' in hq_killed
        assert '[_side, _recoveryEpoch] Spawn WFBE_SE_FNC_AI_Com_HQRecovery' in hq_killed
        assert '_recoveryEpoch = _this select 1;' in recovery
        assert 'getVariable ["wfbe_aicom_hq_recovery_epoch", -1]) != _recoveryEpoch' in recovery


def test_hq_loss_winner_must_still_have_a_live_hq() -> None:
    for mission in MISSIONS:
        victory = (ROOT / mission / "Server/FSM/server_victory_threeway.sqf").read_text(
            encoding="utf-8"
        )

        assert '_candidateHQ = _candSide Call WFBE_CO_FNC_GetSideHQ;' in victory
        assert 'if (!isNull _candidateHQ && {alive _candidateHQ}) then {' in victory
        assert '_candidatePool = WFBE_PRESENTSIDES - [WFBE_DEFENDER];' in victory
        assert 'HQ-loss double-wipe tie-break:' in victory
