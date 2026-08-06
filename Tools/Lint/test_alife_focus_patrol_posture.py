"""Structural contract for the r110 camp-focus patrol close-terrain posture fix.

Bughunt card: wasp-bughunt-alife-formation-selection-and-spacing-in-close-terrain-r110-20260803.

Common_WaypointPatrol.sqf is only ever called from server_town_patrol.sqf with a camp
focus at radius/4 (the tightest close-terrain beat in the town system). Unlike its
town-center sibling Common_WaypointPatrolTown.sqf (DIAMOND-or-STAG-COLUMN + RED), it never
stamped a group posture, so focus garrisons kept engine defaults (WEDGE/YELLOW): a ~40m
wide front inside a camp compound and no maneuver-to-engage. The fix stamps STAG
COLUMN/RED/AWARE/NORMAL behind WFBE_C_TOWNS_FOCUS_PATROL_POSTURE (default 0 = inert).
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONSTANTS = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"
WAYPOINT_PATROL = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_WaypointPatrol.sqf"
TOWN_PATROL = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_patrol.sqf"


def test_focus_patrol_posture_flag_registered_inert_by_default():
    source = CONSTANTS.read_text(encoding="utf-8")
    assert "WFBE_C_TOWNS_FOCUS_PATROL_POSTURE = 0" in source


def test_focus_patrol_posture_block_is_flag_gated_and_null_safe():
    source = WAYPOINT_PATROL.read_text(encoding="utf-8")
    gate = (
        'if (!isNull _team && {(missionNamespace getVariable '
        '["WFBE_C_TOWNS_FOCUS_PATROL_POSTURE", 0]) > 0}) then {'
    )
    assert gate in source
    start = source.index(gate)
    end = source.index("};", start)
    block = source[start:end]
    assert '_team setFormation "STAG COLUMN";' in block
    assert '_team setCombatMode "RED";' in block
    assert '_team setBehaviour "AWARE";' in block
    assert '_team setSpeedMode "NORMAL";' in block
    # One always-on INFORMATION line for the posture state transition (repo log rule).
    assert '["INFORMATION", Format ["Common_WaypointPatrol.sqf:' in block
    # The stamp must run before the waypoint chain is laid.
    assert source.index("_wps = [];") > end


def test_focus_patrol_removes_the_wide_close_terrain_default():
    """The stamped formation must be narrow (STAG COLUMN), never WEDGE/DIAMOND,
    and flag-off leaves the function body without any posture stamp."""
    source = WAYPOINT_PATROL.read_text(encoding="utf-8")
    assert 'setFormation "WEDGE"' not in source
    assert 'setFormation "DIAMOND"' not in source
    # Exactly one formation stamp site (the gated block); legacy path has none.
    assert source.count("setFormation") == 1


def test_focus_patrol_caller_still_uses_the_three_arg_focus_form():
    """server_town_patrol.sqf:67 is the only caller; it passes (team, focus, radius/4)
    so the posture block must not depend on the optional 4th/5th args."""
    source = TOWN_PATROL.read_text(encoding="utf-8")
    assert "[_team,_focus,_patrol_range/4] Spawn WFBE_CO_FNC_WaypointPatrol;" in source
