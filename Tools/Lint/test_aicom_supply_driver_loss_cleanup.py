from pathlib import Path


SOURCE = Path(__file__).parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Server_AicomSupplySquad.sqf"


def test_supply_squad_retires_and_reaps_a_driverless_aircraft_group():
    text = SOURCE.read_text(encoding="utf-8")
    prune = text[text.index("//=== (1) TICK + PRUNE existing squads"):text.index("//=== (2) MAINTAIN")]

    assert '_reason = "driver-lost"' in prune
    assert "forEach (units _eGrp)" in prune
    assert prune.index("forEach (units _eGrp)") < prune.index("deleteVehicle _eVeh") < prune.index("deleteGroup _eGrp")
