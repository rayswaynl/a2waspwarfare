"""Regression contracts for vehicle service locality and airlifted wreck cleanup."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVICE_MENU = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Service.sqf"
)
TRASH_OBJECT = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_TrashObject.sqf"
)
ZETA_HOOK = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/ZetaCargo/Zeta_Hook.sqf"
)
MEDIUM_SITE = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Construction/Construction_MediumSite.sqf"
)


def test_repair_truck_service_list_excludes_remote_vehicles() -> None:
    text = SERVICE_MENU.read_text(encoding="utf-8-sig")
    assert (
        "if (!(_x in _effective) && {side _x in [sideJoined, civilian]} && {local _x}) then {"
        in text
    ), "repair-truck service still admits a remote vehicle whose local service write can no-op"


def test_repair_truck_queries_exclude_destroyed_supports() -> None:
    # lane w807e-L16: the original `{alive _x} select (nearEntities[...])` shape asserted here
    # is A3-only (CODE used as select's array operand) and is not valid on A2/OA 1.64 - it threw
    # 'Error select: Type code, expected Array,Config entry' at runtime and silently killed the
    # town-service support scan (owner-reported: no vehicle/repair/heal costs at service points).
    # Fixed to an explicit for-loop filter that keeps the same alive-only invariant this test
    # guards; the assertions below were updated to the new (A2-legal) query shape.
    text = SERVICE_MENU.read_text(encoding="utf-8-sig")
    per_target_query = (
        "_nearRepairTrucks = (getPos _x) nearEntities[_typeRepair, "
        'missionNamespace getVariable "WFBE_C_UNITS_REPAIR_TRUCK_RANGE"];'
    )
    player_query = (
        "_nearRepairTrucks = (getPos player) nearEntities[_typeRepair, "
        'missionNamespace getVariable "WFBE_C_UNITS_REPAIR_TRUCK_RANGE"];'
    )
    alive_filter = (
        "if (alive (_nearRepairTrucks select _rtIdx)) then "
        "{_checks set [count _checks, _nearRepairTrucks select _rtIdx]};"
    )
    assert per_target_query in text, "per-target repair-truck lookup still admits wrecks"
    assert player_query in text, "nearby-unit repair-truck lookup still selects a wreck"
    assert text.count(alive_filter) == 2, (
        "both repair-truck lookups (per-target and nearby-unit) must filter their "
        "nearEntities result down to alive entries only"
    )


def test_nearby_service_expands_from_every_repair_truck() -> None:
    text = SERVICE_MENU.read_text(encoding="utf-8-sig")
    assert "_repair = _checks select 0;" not in text, (
        "nearEntities is unsorted: selecting one repair truck can omit vehicles "
        "that are serviceable only from another nearby repair truck"
    )
    assert "} forEach _checks;" in text, (
        "nearby service expansion must examine every alive repair truck in range"
    )


def test_airlift_hook_blocks_only_living_crew() -> None:
    text = ZETA_HOOK.read_text(encoding="utf-8-sig")
    assert "if ({alive _x} count crew _vehicle > 0) exitWith" in text, (
        "a seated corpse still makes a towable vehicle look occupied"
    )


def test_medium_site_replaces_dead_static_gunners() -> None:
    text = MEDIUM_SITE.read_text(encoding="utf-8-sig")
    assert (
        "if (alive _x && {_x isKindOf \"StaticWeapon\"} && "
        "{({alive _x} count crew _x) == 0}) then {"
    ) in text, "a dead seated gunner still prevents a live reserve guard from manning a static"


def test_trash_delay_releases_airlifted_wreck_without_deleting_it() -> None:
    text = TRASH_OBJECT.read_text(encoding="utf-8-sig")
    assert (
        'if (_object getVariable ["wfbe_airlifted", false]) exitWith {' in text
    ), "delayed wreck trash still deletes cargo while the Zeta airlift flag is active"
    assert "gc_collector = gc_collector - [_object]" in text, (
        "an airlifted wreck would remain permanently suppressed from later cleanup"
    )
