#!/usr/bin/env python3
"""Regression checks for client state that outlives an in-place mission restart."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def read(terrain: Path, relative: str) -> str:
    return (terrain / relative).read_text(encoding="utf-8-sig")


def test_old_confirmation_cannot_become_valid_when_mission_time_restarts() -> None:
    for terrain in TERRAINS:
        source = read(terrain, "Client/Functions/Client_ConfirmAction.sqf")
        assert "_confirmElapsed = time - _pendTime" in source
        assert "_confirmElapsed >= 0" in source
        assert "_confirmElapsed < 6" in source


def test_autosend_key_handler_is_replaced_after_in_place_restart() -> None:
    for terrain in TERRAINS:
        source = read(terrain, "Client/Init/Init_Client.sqf")
        assert '"WFBE_CL_VAR_AutoSendWaypointKeyDownEH"' in source
        assert 'displayRemoveEventHandler ["KeyDown", _autoSendEH]' in source
        assert 'uiNamespace setVariable ["WFBE_CL_VAR_AutoSendWaypointKeyDownEH", _autoSendEH]' in source


if __name__ == "__main__":
    test_old_confirmation_cannot_become_valid_when_mission_time_restarts()
    test_autosend_key_handler_is_replaced_after_in_place_restart()
    print("mission restart state-bleed regression checks: PASS")
