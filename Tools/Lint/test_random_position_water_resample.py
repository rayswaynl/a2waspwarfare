"""Regression contract for water retries in Common_GetRandomPosition."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GetRandomPosition.sqf"


def test_water_retries_resample_from_original_center():
    source = SOURCE.read_text(encoding="utf-8")

    assert "_origin = +_position;" in source
    assert source.count("(_origin select 0)+((sin _direction)*_radius)") == 2
    assert "(_position select 0)+((sin _direction)*_radius)" not in source
