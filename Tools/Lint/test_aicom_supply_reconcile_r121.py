from pathlib import Path


SOURCE = (
    Path(__file__).parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "Server_AicomSupplySquad.sqf"
)
OPEN = chr(123)
CLOSE = chr(125)
LBRACKET = chr(91)
RBRACKET = chr(93)


def _prune(text: str) -> str:
    return text[text.index("//=== (1) TICK + PRUNE existing squads") : text.index("//=== (2) MAINTAIN")]


def test_destroyed_drop_reaps_group_units_and_group_slot() -> None:
    prune = _prune(SOURCE.read_text(encoding="utf-8"))

    assert ('if (_reason != "destroyed" && ' + OPEN + '!isNull _eGrp' + CLOSE + ') then ' + OPEN) not in prune
    assert ('if (_reason != "destroyed" && ' + OPEN + '!isNull _eGrp' + CLOSE + ' && ' + OPEN + '({isPlayer _x} count (units _eGrp)) == 0' + CLOSE + ') then ' + OPEN + 'deleteGroup _eGrp' + CLOSE + ';') not in prune
    assert "forEach (units _eGrp)" in prune
    assert "deleteGroup _eGrp" in prune


def test_destroyed_race_reaps_the_surviving_supply_group() -> None:
    prune = _prune(SOURCE.read_text(encoding="utf-8"))
    race_marker = 'if (isNull _eVeh || ' + OPEN + '!alive _eVeh' + CLOSE + ') then ' + OPEN
    race = prune[prune.index(race_marker) : prune.index(CLOSE + ' else ' + OPEN, prune.index(race_marker))]

    assert "forEach (units _eGrp)" in race
    assert "deleteGroup _eGrp" in race


def test_unstuck_supply_truck_ground_snaps_with_atl_coordinates() -> None:
    text = SOURCE.read_text(encoding="utf-8")

    assert ("_eVeh setPosATL " + LBRACKET + "(_eCur select 0) + 60 * sin _ang2") in text
    assert ("_eVeh setPos " + LBRACKET + "(_eCur select 0) + 60 * sin _ang2") not in text


def test_failed_supply_escort_boarding_is_reaped_at_spawn() -> None:
    text = SOURCE.read_text(encoding="utf-8")

    assert "_esc moveInCargo _veh;" in text
    assert ("if (!(_esc in (crew _veh))) then " + OPEN) in text
    assert (LBRACKET + '"aicomsupply-unit", _esc, ""' + RBRACKET + ' Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _esc' + CLOSE) in text
