from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_OnPlayerDisconnected.sqf"


def test_disconnect_cancels_uid_owned_factory_queue_entries_before_wallet_snapshot():
    text = SOURCE.read_text(encoding="utf-8")

    assert '_queuePrefix = toArray (_uid + "_");' in text
    assert '_queueBuildings = _queueBuildings + (if (isNil "towns") then {[]} else {towns}) + (if (isNil "airports") then {[]} else {airports});' in text
    assert '_queueBuilding setVariable ["queu", _queueKeep, true];' in text
    assert '_queueBuilding setVariable ["queu_costs", _queueCostsKeep, true];' in text
    assert '_queueBuilding setVariable ["queu_cpts", _queueCptsKeep, true];' in text
    assert '_queueBuilding setVariable ["queu_labels", _queueLabelsKeep, true];' in text
    assert 'if (_queueRefund > 0) then {[_team, _queueRefund] Call ChangeTeamFunds};' in text
    assert text.index('if (_queueRefund > 0) then {[_team, _queueRefund] Call ChangeTeamFunds};') < text.index('//--- We save the disconnect client funds.')
