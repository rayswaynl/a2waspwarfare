#!/usr/bin/env python3
"""Regression checks for client view-distance hotkey persistence (r117)."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_view_distance_hotkeys_persist_their_client_preferences() -> None:
    for terrain in TERRAINS:
        adjust = (ROOT / terrain / "Common/Functions/Common_AdjustViewDistance.sqf").read_text(
            encoding="utf-8"
        )
        timer = (ROOT / terrain / "Common/Functions/Common_AdjustViewDistanceTimerScript.sqf").read_text(
            encoding="utf-8"
        )

        assert "['WFBE_TOOGLE_AUTO_DISTANCE_VIEW', false] Call WFBE_CO_FNC_SetProfileVariable" in adjust, (
            f"{terrain}: User18 must persist auto-view-distance OFF"
        )
        assert "['WFBE_TOOGLE_AUTO_DISTANCE_VIEW', true] Call WFBE_CO_FNC_SetProfileVariable" in adjust, (
            f"{terrain}: User18 must persist auto-view-distance ON"
        )
        assert "['WFBE_PERSISTENT_CONST_VIEW_DISTANCE', _appliedViewDistance] Call WFBE_CO_FNC_SetProfileVariable" in timer, (
            f"{terrain}: debounced User19/User20 changes must persist the applied view distance"
        )


def test_manual_view_distance_controls_keep_the_500m_floor_and_take_manual_control() -> None:
    for terrain in TERRAINS:
        team = (ROOT / terrain / "Client/GUI/GUI_Menu_Team.sqf").read_text(encoding="utf-8")
        adjust = (ROOT / terrain / "Common/Functions/Common_AdjustViewDistance.sqf").read_text(
            encoding="utf-8"
        )
        timer = (ROOT / terrain / "Common/Functions/Common_AdjustViewDistanceTimerScript.sqf").read_text(
            encoding="utf-8"
        )
        profile = (ROOT / terrain / "Client/Init/Init_ProfileVariables.sqf").read_text(
            encoding="utf-8"
        )

        assert 'SliderSetRange[13003, 500, missionNamespace getVariable "WFBE_C_ENVIRONMENT_MAX_VIEW"]' in team, (
            f"{terrain}: Team slider must expose the same 500m floor as Settings"
        )
        assert "_currentVD = (_currentVD max 500) min (missionNamespace getVariable" in team, (
            f"{terrain}: Team slider must clamp its manual value before applying it"
        )
        assert 'missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false];' in team, (
            f"{terrain}: Team manual adjustment must disable adaptive view distance"
        )
        assert 'missionNamespace setVariable ["SAVED_VIEW_DISTANCE", _currentVD];' in team, (
            f"{terrain}: Team manual adjustment must refresh the saved manual value"
        )
        assert "_newViewDistanceToBeSet - _adjustViewDistanceBy max 500" in adjust, (
            f"{terrain}: User19 must not select a sub-500m view distance"
        )
        assert "_appliedViewDistance = (newViewDistance max 500) min" in timer, (
            f"{terrain}: timer must preserve the 500m floor before persistence"
        )
        assert "_profile_var >= 500" in profile, (
            f"{terrain}: stale sub-500m view-distance profiles must not be restored"
        )


if __name__ == "__main__":
    test_view_distance_hotkeys_persist_their_client_preferences()
    test_manual_view_distance_controls_keep_the_500m_floor_and_take_manual_control()
    print("client view-distance persistence regression check passed")
