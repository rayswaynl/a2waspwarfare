"""Regression contract for the GUER air-defence enemy-air cache."""

from pathlib import Path


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "Server_GuerAirDef.sqf"
)


def test_enemy_air_cache_yields_while_scanning_global_vehicle_registry():
    source = SOURCE.read_text(encoding="utf-8")
    assert "_enemyAirScanBudget" in source
    assert "_enemyAirScanCount" in source
    assert "Call _sliceYield;" in source[source.index("_enemyAirVehicles = [];") : source.index("//=== (3) MAINTAIN")]


def test_per_town_enemy_air_uses_the_cached_candidates():
    source = SOURCE.read_text(encoding="utf-8")
    maintain = source[source.index("//=== (3) MAINTAIN") :]
    assert "count _enemyAirVehicles" in maintain
    assert "count vehicles" not in maintain
