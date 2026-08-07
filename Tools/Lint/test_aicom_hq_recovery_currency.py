"""Regression contract for HQ recovery currency-pool selection."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def test_hq_recovery_uses_the_active_currency_pool_for_gate_debit_and_refund() -> None:
    for mission in MISSIONS:
        source = (
            ROOT / mission / "Server/AI/Commander/AI_Commander_HQRecovery.sqf"
        ).read_text(encoding="utf-8")

        assert (
            '_dual = (missionNamespace getVariable '
            '["WFBE_C_ECONOMY_CURRENCY_SYSTEM", 0]) == 0;'
        ) in source
        assert (
            "_currency = if (_dual) then {(_side) Call WFBE_CO_FNC_GetSideSupply} "
            "else {(_side) Call GetAICommanderFunds};"
        ) in source
        assert "if (_currency < _price) exitWith {" in source
        assert (
            '[_side, -_price, "AI commander HQ recovery.", false] '
            "Call ChangeSideSupply;"
        ) in source
        assert "[_side, -_price] Call ChangeAICommanderFunds;" in source
        assert (
            '[_side, _price, "AI commander HQ recovery refund.", false] '
            "Call ChangeSideSupply;"
        ) in source
        assert "[_side, _price] Call ChangeAICommanderFunds;" in source


def test_hq_recovery_currency_contract_is_identical_on_maintained_maps() -> None:
    sources = [
        (
            ROOT / mission / "Server/AI/Commander/AI_Commander_HQRecovery.sqf"
        ).read_bytes()
        for mission in MISSIONS
    ]

    assert sources[0] == sources[1] == sources[2]
