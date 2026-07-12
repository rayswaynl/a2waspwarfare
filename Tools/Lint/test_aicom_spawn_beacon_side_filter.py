"""Regression coverage for AICOM forward spawn-beacon side ownership."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BEACON_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Beacon.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Beacon.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Beacon.sqf"),
    Path("Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Server/AI/Commander/AI_Commander_Beacon.sqf"),
)

SIDE_ID_ASSIGNMENT = "_myID = (_side) Call WFBE_CO_FNC_GetSideID;"
SIDE_FILTER = '_x getVariable ["wfbe_aicom_beacon_side", -1]) == _myID'
SIDE_TAG = '_veh setVariable ["wfbe_aicom_beacon_side", _myID, true];'


def test_spawn_beacon_census_and_tag_are_side_scoped() -> None:
    for relative_path in BEACON_PATHS:
        path = ROOT / relative_path
        text = path.read_text(encoding="utf-8")

        assert SIDE_FILTER in text, f"census is not side-filtered in {relative_path}"
        assert SIDE_TAG in text, f"new beacon is not side-tagged in {relative_path}"
        assert text.index(SIDE_ID_ASSIGNMENT) < text.index(
            "//--- 2) Count LIVE beacons"
        ), f"side ID is resolved after the census in {relative_path}"
