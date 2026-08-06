#!/usr/bin/env python3
"""Regression contract for CoIn callback defense-list lookups."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COIN_INTERFACE_PATHS = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/CoIn/coin_interface.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Module/CoIn/coin_interface.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Module/CoIn/coin_interface.sqf",
]
SAFE_LOOKUP = 'missionNamespace getVariable [Format["WFBE_%1DEFENSENAMES",sideJoinedText], []]'
LEGACY_LOOKUP = 'missionNamespace getVariable Format["WFBE_%1DEFENSENAMES",sideJoinedText]'


def test_coin_interface_defense_registry_defaults_to_empty_list() -> None:
    for path in COIN_INTERFACE_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        assert source.count(SAFE_LOOKUP) == 4, path
        assert LEGACY_LOOKUP not in source, path


if __name__ == "__main__":
    test_coin_interface_defense_registry_defaults_to_empty_list()
