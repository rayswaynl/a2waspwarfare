#!/usr/bin/env python3
"""Contract for stopping the server GlobalGameStats heartbeat at mission end."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/CallExtensions/GlobalGameStats.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/CallExtensions/GlobalGameStats.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/CallExtensions/GlobalGameStats.sqf"),
    Path("Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Server/CallExtensions/GlobalGameStats.sqf"),
)


def test_global_game_stats_stops_before_the_next_post_match_heartbeat() -> None:
    for relative_path in MISSION_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8-sig")

        assert "while {!gameOver} do {" in source, relative_path
        assert "while {true} do {" not in source, relative_path
        assert "sleep 60;" in source, relative_path


if __name__ == "__main__":
    test_global_game_stats_stops_before_the_next_post_match_heartbeat()
    print("global-game-stats lifecycle contract passed")
