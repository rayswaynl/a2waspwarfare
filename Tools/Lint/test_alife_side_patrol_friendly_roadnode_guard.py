"""Regression contract for side-patrol recovery at shared road chokepoints."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunSidePatrol.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_RunSidePatrol.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_RunSidePatrol.sqf",
)


def test_road_snap_does_not_teleport_onto_a_friendly_vehicle() -> None:
    occupied_scan = '((getPos _pNode) nearEntities [["LandVehicle"], 18])'
    occupancy_guard = 'if (!_pRoadOccupied) then {'
    road_snap = '_pVeh setPos (getPos _pNode);'

    for path in SOURCES:
        source = path.read_text(encoding="utf-8-sig")

        assert 'PATROL_UNSTUCK_BLOCKED' in source
        assert occupied_scan in source
        assert 'side _x == _side' in source
        assert occupancy_guard in source
        assert source.index(occupied_scan) < source.index(occupancy_guard) < source.index(road_snap)


def test_all_terrain_copies_remain_byte_identical() -> None:
    source = SOURCES[0].read_bytes()
    assert SOURCES[1].read_bytes() == source
    assert SOURCES[2].read_bytes() == source
