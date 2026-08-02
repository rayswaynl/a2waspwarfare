#!/usr/bin/env python3
"""Regression checks for r85 side recovery and captive-player A-Life gates."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_advanced_respawn_recomputes_side_id_after_civilian_fallback() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Server/AI/AI_AdvancedRespawn.sqf").read_text(encoding="utf-8")
        fallback = source.index("if (_side == civilian) then {")
        side_text = source.index("_sideText = str _side;", fallback)
        recovered = source[fallback:side_text]
        assert "_sideID = (_side) Call GetSideID;" in recovered, f"{terrain}: fallback side ID is stale"


def test_captive_spectator_bodies_do_not_trigger_sorties() -> None:
    for terrain in TERRAINS:
        garrison = (ROOT / terrain / "Server/Server_GarrisonSortie.sqf").read_text(encoding="utf-8")
        town_ai = (ROOT / terrain / "Server/FSM/server_town_ai.sqf").read_text(encoding="utf-8")
        assert "{!(captive _x)}" in garrison, f"{terrain}: captive spectator passes garrison sortie gate"
        assert "{!(captive _x)}" in town_ai, f"{terrain}: captive spectator passes town sortie gate"


if __name__ == "__main__":
    test_advanced_respawn_recomputes_side_id_after_civilian_fallback()
    test_captive_spectator_bodies_do_not_trigger_sorties()
    print("A-Life side and neutral handling checks passed")
