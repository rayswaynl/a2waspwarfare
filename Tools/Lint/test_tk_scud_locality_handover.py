"""Regression contracts for player-bought SCUD client-local controls."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
BUILD_UNIT = MISSION / "Client/Functions/Client_BuildUnit.sqf"
CLIENT_INIT = MISSION / "Client/Init/Init_Client.sqf"
INIT_UNIT = MISSION / "Common/Init/Init_Unit.sqf"
ARMER = MISSION / "Client/Functions/Client_ArmTkScud.sqf"


def test_tk_scud_arm_helper_is_client_wide_and_registered() -> None:
    init_text = CLIENT_INIT.read_text(encoding="utf-8-sig")
    armer_text = ARMER.read_text(encoding="utf-8-sig")

    assert (
        'WFBE_CL_FNC_ArmTkScud = Compile preprocessFileLineNumbers "Client\\Functions\\Client_ArmTkScud.sqf";'
        in init_text
    )
    assert "wfbe_is_tk_scud" in armer_text
    assert 'addAction [' in armer_text
    assert "SCUD Fire Mission (map-click)" in armer_text
    assert "while {alive _v && {driver _v == player}" in armer_text


def test_tk_scud_getin_rearms_every_client_not_only_the_buyer() -> None:
    init_text = INIT_UNIT.read_text(encoding="utf-8-sig")
    build_text = BUILD_UNIT.read_text(encoding="utf-8-sig")

    assert '"MAZ_543_SCUD_TK_EP1"' in init_text
    assert 'addEventHandler ["GetIn"' in init_text
    assert "_v Call WFBE_CL_FNC_ArmTkScud" in init_text
    assert "_vehicle Call WFBE_CL_FNC_ArmTkScud" in build_text
