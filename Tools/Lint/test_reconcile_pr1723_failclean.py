"""Regression contracts for the non-overlapping #1723 fail-clean ports."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def _read(relative: str) -> str:
    return (CHERNARUS / relative).read_text(encoding="utf-8")


def test_ruins_cleaner_guards_null_after_yield_and_bad_timer_values() -> None:
    source = _read("Server/FSM/cleaners/ruins_cleaner.sqf")

    assert 'missionNamespace getVariable ["WFBE_C_RUINS_CLEANER_TIME_PERIOD", 1800]' in source
    assert 'typeName _timer != "SCALAR"' in source
    assert "if (!isNull _x && {local _x}) then {" in source


def test_town_defense_operator_cleanup_rejects_malformed_values() -> None:
    source = _read("Server/Functions/Server_OperateTownDefensesUnits.sqf")

    assert 'typeName _opUnit == "OBJECT"' in source
    assert '&& {!isNull _opUnit} && {alive _opUnit}' in source
    assert '"cleanup-town-defense-gunner", _opUnit, "remove-case"' in source


def test_garrison_sortie_cleanup_ignores_null_units() -> None:
    source = _read("Server/Server_GarrisonSortie.sqf")

    assert "{ if (!isNull _x && {!(isPlayer _x)}) then {" in source
    assert "{!isNull _x && {isPlayer _x}} count (units _eGrp)" in source
