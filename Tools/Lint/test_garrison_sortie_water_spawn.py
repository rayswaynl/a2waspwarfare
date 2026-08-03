"""Regression contract: garrison sorties must not create infantry at water positions."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_GarrisonSortie.sqf"


def test_sortie_spawn_position_is_bounded_and_water_rejected() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "while {surfaceIsWater _spawnPos && {_waterTry < _waterRetryCap}} do {" in source
    assert '"GARSORTIE|SPAWNSKIP|town=%1|reason=water"' in source
    assert "if (!(surfaceIsWater _spawnPos)) then {" in source
