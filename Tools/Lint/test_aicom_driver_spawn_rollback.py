"""Regression contract for an AICOM vehicle whose mandatory driver cannot spawn."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/Functions/Server_BuyUnit.sqf"
)


def test_failed_aicom_driver_spawn_rolls_back_paid_vehicle() -> None:
    """A crewless hull is not a delivered AICOM purchase."""
    text = SOURCE.read_text(encoding="utf-8-sig")
    driver_failure = text.index('seat=driver|spawnPos=%3')
    driver_success = text.index('} else {', driver_failure)
    rollback = text[driver_failure:driver_success]

    assert 'emptyQueu = emptyQueu - [_vehicle];' in rollback
    assert 'deleteVehicle _vehicle;' in rollback
    assert '[_side, _price] Call ChangeAICommanderFunds' in rollback
