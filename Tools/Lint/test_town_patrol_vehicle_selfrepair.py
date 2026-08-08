"""Regression coverage for town-garrison vehicle mobility recovery."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "FSM" / "server_town_patrol.sqf"


def mobility_repair_block(source: str) -> str:
    start = source.index("//--- TOWN-VEHICLE-SELFREPAIR")
    end = source.index("\n\tif !(isNil \"PerformanceAudit_Record\") then", start)
    return source[start:end]


def test_crewed_immobile_town_land_vehicle_repairs_only_after_safe_window() -> None:
    block = mobility_repair_block(SOURCE.read_text(encoding="utf-8"))

    assert "_tvVeh isKindOf \"LandVehicle\"" in block
    assert "!(canMove _tvVeh)" in block
    assert "({alive _x} count (crew _tvVeh)) > 0" in block
    assert "_tvVeh nearEntities [[\"Man\",\"LandVehicle\"], _tvSafe]" in block
    assert "(time - _tvStamp) >= _tvDelay" in block


def test_town_repair_clears_configured_hitpoints_not_only_overall_damage() -> None:
    block = mobility_repair_block(SOURCE.read_text(encoding="utf-8"))

    assert "_tvVeh setDamage 0" in block
    assert 'configFile >> "CfgVehicles" >> (typeOf _tvVeh) >> "HitPoints"' in block
    assert "_tvVeh setHit [_tvHpName, 0]" in block
