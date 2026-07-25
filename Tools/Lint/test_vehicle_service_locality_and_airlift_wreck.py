"""Regression contracts for vehicle service locality and airlifted wreck cleanup."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVICE_MENU = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Service.sqf"
)
TRASH_OBJECT = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_TrashObject.sqf"
)


def test_repair_truck_service_list_excludes_remote_vehicles() -> None:
    text = SERVICE_MENU.read_text(encoding="utf-8-sig")
    assert (
        "if (!(_x in _effective) && {side _x in [sideJoined, civilian]} && {local _x}) then {"
        in text
    ), "repair-truck service still admits a remote vehicle whose local service write can no-op"


def test_trash_delay_releases_airlifted_wreck_without_deleting_it() -> None:
    text = TRASH_OBJECT.read_text(encoding="utf-8-sig")
    assert (
        'if (_object getVariable ["wfbe_airlifted", false]) exitWith {' in text
    ), "delayed wreck trash still deletes cargo while the Zeta airlift flag is active"
    assert "gc_collector = gc_collector - [_object]" in text, (
        "an airlifted wreck would remain permanently suppressed from later cleanup"
    )
