#!/usr/bin/env python3
"""Regression checks for the commander disband executor wiring."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def _source(mission: Path, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8")


def test_commander_disband_is_dispatched_to_the_team_owner() -> None:
    for mission in MISSIONS:
        source = _source(mission, "Server/Functions/Server_HandleSpecial.sqf")
        assert '["aicom-team-disband-execute", _dTeam]' in source


def test_team_owner_has_a_destructive_local_disband_executor() -> None:
    for mission in MISSIONS:
        source = _source(mission, "Client/PVFunctions/HandleSpecial.sqf")
        assert 'case "aicom-team-disband-execute"' in source
        assert 'Call WFBE_CO_FNC_AICOMDisbandTeam' in source
        executor = _source(mission, "Common/Functions/Common_AICOMDisbandTeam.sqf")
        assert 'setDamage 1' in executor
        assert 'GrenadeHandTimedWest' in executor
        assert 'DISBAND|v1|exec|mode=destructive' in executor
        assert 'deleteVehicle' not in executor


def test_map_click_disband_does_not_kill_the_selected_ai() -> None:
    for mission in MISSIONS:
        source = _source(mission, "Client/Functions/Client_HandleMapSingleClick.sqf")
        assert '_target setDamage 1' not in source
