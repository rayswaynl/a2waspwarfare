from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/AI/Commander/AI_Commander_Produce.sqf"
)


def test_aicom_factory_selector_accounts_for_live_queue_and_same_cycle_reservations():
    text = SOURCE.read_text(encoding="utf-8")

    assert "_factoryReservations = [];" in text
    assert '_facQueue = _facCandidate getVariable "queu";' in text
    assert "_facLoad = (count _facQueue) + _facReserved;" in text
    assert "if (!_facReservationFound) then {_factoryReservations set [count _factoryReservations, [_facObj, 1]]};" in text

    selection = text.index("//--- Queue-balanced factory selection")
    charge = text.index("[_side, -_priceCharged] Call ChangeAICommanderFunds;")
    reservation = text.index("if (!_facReservationFound) then {_factoryReservations set [count _factoryReservations, [_facObj, 1]]};")
    spawn = text.index("Spawn AIBuyUnit;")
    assert selection < charge
    assert charge < reservation < spawn
