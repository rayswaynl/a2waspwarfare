#!/usr/bin/env python3
"""Regression contract for CoIn defense-list lookups during side re-slots."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_PATHS = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Coin.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Init/Init_Coin.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Init/Init_Coin.sqf",
]
EXPECTED_LOOKUP = (
    'missionNamespace getVariable '
    '[Format["WFBE_%1DEFENSENAMES",sideJoinedText], []]'
)


def test_coin_defense_registry_defaults_to_empty_when_side_list_is_absent() -> None:
    for mission_path in MISSION_PATHS:
        source = mission_path.read_text(encoding="utf-8-sig")
        assert EXPECTED_LOOKUP in source, mission_path


if __name__ == "__main__":
    test_coin_defense_registry_defaults_to_empty_when_side_list_is_absent()
