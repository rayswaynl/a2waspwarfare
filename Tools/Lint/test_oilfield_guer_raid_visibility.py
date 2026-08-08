"""Regression coverage for oilfield GUER raid spawn suppression."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAIN_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def test_oilfield_raid_checks_actual_ring_position_before_group_creation() -> None:
    """A nearby human must defer the raid before it materializes any group."""
    for terrain_root in TERRAIN_ROOTS:
        source = (ROOT / terrain_root / "Server/Server_Oilfields.sqf").read_text(
            encoding="utf-8"
        )
        ring = source.index("_ringPos = [")
        group = source.index('_grp = [resistance, "oilfield-guer-raid"]')
        gate = source[ring:group]

        assert "WFBE_C_OILFIELD_GUER_RAID_PLAYER_RADIUS" in gate
        assert "playableUnits" in gate
        assert "isPlayer _x" in gate
        assert "alive _x" in gate
        assert 'WFBE_C_HC_NAMES' in gate
        assert "_playerDist = _playerRadius + 15" in gate
        assert "_dx = ((getPos _x) select 0) - (_ringPos select 0)" in gate
        assert "_dy = ((getPos _x) select 1) - (_ringPos select 1)" in gate
        assert "(sqrt ((_dx * _dx) + (_dy * _dy))) < _playerDist" in gate
        assert "_denyLogInterval" in gate
        assert "WFBE_C_OILFIELD_GUER_RAID_DENY_LOG_INTERVAL" in gate
        assert "WFBE_OILFIELD_GUER_DENY_LOG_LAST" in gate
        assert "if ((time - _denyLogLast) >= _denyLogInterval) then" in gate
        assert (
            "if (_playerNear) exitWith {\n"
            "\t\tif ((time - _denyLogLast) >= _denyLogInterval) then {"
        ) in gate
        assert "if (_playerNear) exitWith" in gate
        assert "deny=player_near" in gate
        assert 'within %1m of ring position %2.", _playerDist, _ringPos]] Call' in gate


def test_oilfield_raid_player_radius_is_declared_in_all_terrain_constants() -> None:
    for terrain_root in TERRAIN_ROOTS:
        source = (ROOT / terrain_root / "Common/Init/Init_CommonConstants.sqf").read_text(
            encoding="utf-8"
        )
        assert (
            'if (isNil "WFBE_C_OILFIELD_GUER_RAID_PLAYER_RADIUS") '
            'then {WFBE_C_OILFIELD_GUER_RAID_PLAYER_RADIUS = 400};'
        ) in source
        assert (
            'if (isNil "WFBE_C_OILFIELD_GUER_RAID_DENY_LOG_INTERVAL") '
            'then {WFBE_C_OILFIELD_GUER_RAID_DENY_LOG_INTERVAL = 300};'
        ) in source


def test_oilfield_raiders_do_not_receive_town_defender_marker() -> None:
    """The non-town oilfield encounter must remain visible to town activation scans."""
    for terrain_root in TERRAIN_ROOTS:
        source = (ROOT / terrain_root / "Server/Server_Oilfields.sqf").read_text(
            encoding="utf-8"
        )
        raid_start = source.index("WFBE_FNC_OilfieldTryGuerRaid = {")
        raid_end = source.index(
            "//------------------------------------------------------------------------------------\n"
            "//--- (3)+(4)+(5)+(6)+(7)+(8) LIVE LOOP",
            raid_start,
        )
        raid_source = source[raid_start:raid_end]

        assert "WFBE_IsTownDefenderAI" not in raid_source


if __name__ == "__main__":
    test_oilfield_raid_checks_actual_ring_position_before_group_creation()
    test_oilfield_raid_player_radius_is_declared_in_all_terrain_constants()
    test_oilfield_raiders_do_not_receive_town_defender_marker()
