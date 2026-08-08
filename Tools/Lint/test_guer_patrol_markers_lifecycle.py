from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAIN_PATHS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_GuerPatrolMarkers.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_GuerPatrolMarkers.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_GuerPatrolMarkers.sqf",
)


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_guer_patrol_marker_loop_stops_and_cleans_up_at_game_over():
    source = _read(TERRAIN_PATHS[0])

    assert "while {!gameOver} do {" in source
    assert "while {true} do {" not in source
    assert source.rstrip().endswith("{ deleteMarkerLocal _x } forEach _known;")


def test_guer_patrol_marker_lifecycle_change_is_mirrored():
    source = _read(TERRAIN_PATHS[0])

    for path in TERRAIN_PATHS[1:]:
        assert _read(path) == source
