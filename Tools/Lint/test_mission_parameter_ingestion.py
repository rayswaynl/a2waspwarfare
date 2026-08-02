#!/usr/bin/env python3
"""Regression checks for mission lobby-parameter precedence."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_guer_lobby_value_is_not_clobbered_by_schema_default() -> None:
    """A valid lobby-disabled GUER setting must survive parameter bootstrap."""
    legacy_force = (
        'WFBE_C_GUER_PLAYERSIDE = getNumber (missionConfigFile >> "Params" '
        '>> "WFBE_C_GUER_PLAYERSIDE" >> "default");'
    )
    fallback = (
        'if (isNil "WFBE_C_GUER_PLAYERSIDE") then {'
        'WFBE_C_GUER_PLAYERSIDE = getNumber (missionConfigFile >> "Params" '
        '>> "WFBE_C_GUER_PLAYERSIDE" >> "default")};'
    )
    for terrain in TERRAINS:
        source = (ROOT / terrain / "initJIPCompatible.sqf").read_text(encoding="utf-8")
        assert legacy_force not in source, f"{terrain}: lobby value is overwritten by the schema default"
        assert fallback in source, f"{terrain}: missing nil-only schema-default fallback"


if __name__ == "__main__":
    test_guer_lobby_value_is_not_clobbered_by_schema_default()
    print("mission parameter ingestion regression checks passed")
