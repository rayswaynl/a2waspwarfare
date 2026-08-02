#!/usr/bin/env python3
"""Regression guard for per-machine GUER side-relation configuration (r85)."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_guer_relations_are_reciprocal_on_server() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/Init/Init_Server.sqf").read_text(encoding="utf-8")

        assert "createCenter resistance;" in source, f"{terrain}: missing resistance center"
        assert "resistance setFriend [west,0];" in source, f"{terrain}: GUER must reject WEST"
        assert "resistance setFriend [east,0];" in source, f"{terrain}: GUER must reject EAST"
        assert "west setFriend [resistance,0];" in source, f"{terrain}: WEST reciprocal relation missing"
        assert "east setFriend [resistance,0];" in source, f"{terrain}: EAST reciprocal relation missing"


def test_reciprocal_relation_is_not_player_side_gated() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/Init/Init_Server.sqf").read_text(encoding="utf-8")
        start = source.index("createCenter resistance;")
        end = source.index("AIBuyUnit", start)
        assert "WFBE_C_GUER_PLAYERSIDE" not in source[start:end], f"{terrain}: reciprocal relation remains gated"


if __name__ == "__main__":
    test_guer_relations_are_reciprocal_on_server()
    test_reciprocal_relation_is_not_player_side_gated()
    print("side relation parity checks passed")
