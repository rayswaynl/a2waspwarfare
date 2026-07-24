#!/usr/bin/env python3
"""Regression checks for side-scoped town ownership marker intelligence."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
TOWN_UNKNOWN = 'missionNamespace getVariable ["WFBE_C_UNKNOWN_COLOR", "ColorGreen"]'
TOWN_FRIENDLY = "if (_town_side_value_new == WFBE_Client_SideID || _town_side_value_new == WFBE_C_GUER_ID) then {"
TOWN_RECOLOR = "_townMarker setMarkerColorLocal _color;"
NAVAL_UNKNOWN = 'missionNamespace getVariable ["WFBE_C_UNKNOWN_COLOR", "ColorGreen"]'
NAVAL_FRIENDLY = "if (_navNewSID == WFBE_Client_SideID || _navNewSID == WFBE_C_GUER_ID) then {"
NAVAL_RECOLOR = "_navMkr setMarkerColorLocal _navColor;"
JIP_OWN_COUNT = "if (_townSide == _myID) then {_owned = _owned + 1};"
JIP_GUER_COUNT = "if (_townSide == WFBE_C_GUER_ID) then {_guer = _guer + 1};"
JIP_NEUTRAL_COUNT = "if (_townSide == WFBE_C_UNKNOWN_ID) then {_neutral = _neutral + 1};"
JIP_SUMMARY = "Towns  </t><t color='#b8c4cc'>Own %1</t>  <t color='#7ed37e'>GUER %2</t>  <t color='#b8b8b8'>Free %3</t><br/>"


def _source(mission: Path, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8")


def test_town_capture_recolor_only_identifies_the_new_owner_to_that_side() -> None:
    for mission in MISSIONS:
        source = _source(mission, "Client/PVFunctions/TownCaptured.sqf")
        assert TOWN_UNKNOWN in source, f"{mission}: TownCaptured has no unknown-color fallback"
        assert TOWN_FRIENDLY in source, f"{mission}: TownCaptured has no friendly-owner color gate"
        assert TOWN_RECOLOR in source, f"{mission}: TownCaptured local recolor missing"
        assert source.index(TOWN_UNKNOWN) < source.index(TOWN_FRIENDLY) < source.index(TOWN_RECOLOR), (
            f"{mission}: TownCaptured can expose an enemy owner color"
        )


def test_naval_capture_recolor_only_identifies_the_new_owner_to_that_side() -> None:
    for mission in MISSIONS:
        source = _source(mission, "Client/PVFunctions/HandleSpecial.sqf")
        assert NAVAL_UNKNOWN in source, f"{mission}: naval capture has no unknown-color fallback"
        assert NAVAL_FRIENDLY in source, f"{mission}: naval capture has no friendly-owner color gate"
        assert NAVAL_RECOLOR in source, f"{mission}: naval local recolor missing"
        assert source.index(NAVAL_UNKNOWN) < source.index(NAVAL_FRIENDLY) < source.index(NAVAL_RECOLOR), (
            f"{mission}: naval capture can expose an enemy owner color"
        )


def test_jip_briefing_does_not_enumerate_enemy_town_ownership() -> None:
    for mission in MISSIONS:
        source = _source(mission, "Client/Functions/Client_JIPCatchupBriefing.sqf")
        for expected in (JIP_OWN_COUNT, JIP_GUER_COUNT, JIP_NEUTRAL_COUNT, JIP_SUMMARY):
            assert expected in source, f"{mission}: JIP briefing missing safe town summary token: {expected}"
        for forbidden in (
            "WFBE_C_WEST_ID",
            "WFBE_C_EAST_ID",
            "distance _x",
            '_x getVariable ["name",',
            "switch (_townSide)",
        ):
            assert forbidden not in source, (
                f"{mission}: JIP briefing can derive foreign ownership intelligence: {forbidden}"
            )
