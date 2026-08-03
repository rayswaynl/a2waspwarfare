"""Regression contract for the client deadspawn damage-protection watchdog."""

from pathlib import Path


MISSION = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
INIT = MISSION / "Client" / "Init" / "Init_Client.sqf"


def test_rearmed_deadspawn_watchdogs_cannot_release_newer_holds() -> None:
    source = INIT.read_text(encoding="utf-8")

    assert "WFBE_CL_FNC_ArmDeadspawnDamageGuard" in source
    assert "WFBE_Client_DeadspawnDamageGuardEpoch" in source
    assert source.count("[] Call WFBE_CL_FNC_ArmDeadspawnDamageGuard;") == 3
    assert "_epoch == (missionNamespace getVariable [\"WFBE_Client_DeadspawnDamageGuardEpoch\", 0])" in source
