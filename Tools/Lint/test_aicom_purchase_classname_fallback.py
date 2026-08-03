"""Regression contract for AICOM unavailable purchase-class fallbacks."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
BUY_UNIT = MISSION / "Server/Functions/Server_BuyUnit.sqf"
PRODUCE = MISSION / "Server/AI/Commander/AI_Commander_Produce.sqf"


def test_buy_worker_rejects_an_unavailable_vehicle_class_before_queueing() -> None:
    """A direct AIBuyUnit call must refund and release an unknown CfgVehicles class."""
    source = BUY_UNIT.read_text(encoding="utf-8-sig")

    assert '_unitConfig = configFile >> "CfgVehicles" >> _unitType;' in source
    assert 'if !(isClass _unitConfig) exitWith {' in source
    assert 'BUYFAIL|v1|aicom-unavailable-class' in source
    assert 'ChangeAICommanderFunds' in source
    assert source.index('_sideText = str _side;') < source.index('if !(isClass _unitConfig) exitWith {')
    assert source.index('if !(isClass _unitConfig) exitWith {') < source.index('_queu = _building getVariable "queu";')
    assert source.index('if !(isClass _unitConfig) exitWith {') < source.index('if (_unitType isKindOf "Man") then {')


def test_producer_skips_unavailable_template_assets_for_available_fallbacks() -> None:
    """A missing template asset must not stop the selection before a valid entry can be bought."""
    source = PRODUCE.read_text(encoding="utf-8-sig")

    assert 'if (_have < ({_x == _d} count _template)) then {' in source
    assert 'if (isClass (configFile >> "CfgVehicles" >> _d)) exitWith {_toBuild = _d};' in source
    assert 'AICOMBUY|v1|UNAVAILABLE_CLASS' in source
    assert source.index('AICOMBUY|v1|UNAVAILABLE_CLASS') < source.index('if (_toBuild == "") exitWith {};')


if __name__ == "__main__":
    test_buy_worker_rejects_an_unavailable_vehicle_class_before_queueing()
    test_producer_skips_unavailable_template_assets_for_available_fallbacks()
