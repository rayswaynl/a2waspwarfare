from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_EndGame.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Client_EndGame.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Client_EndGame.sqf",
)


def test_endgame_camera_commit_waits_yield_in_all_terrain_copies() -> None:
    source_bytes = []

    for relative_path in RELATIVE_PATHS:
        path = ROOT / relative_path
        source = path.read_text(encoding="utf-8-sig")
        source_bytes.append(path.read_bytes())

        assert source.count("waitUntil {sleep 0.05; camCommitted _camera};") == 4, relative_path
        assert source.count("waitUntil {camCommitted _camera};") == 0, relative_path

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == "__main__":
    test_endgame_camera_commit_waits_yield_in_all_terrain_copies()
    print("endgame camera wait-yield regression check passed")
