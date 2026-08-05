"""Regression contract for the post-match dashboard-announcer stop guard."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ANNOUNCER_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_dashboard_announcer.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_dashboard_announcer.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/FSM/server_dashboard_announcer.sqf"),
)

ENDGAME_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {};"


def test_dashboard_announcer_stops_before_post_match_broadcast() -> None:
    for relative_path in ANNOUNCER_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        loop_start = source.index("while {true} do {")
        sleep_index = source.index("sleep _interval;", loop_start)
        guard_index = source.index(ENDGAME_GUARD, loop_start)
        broadcast_index = source.index('"DashboardAnnounce"', loop_start)

        assert sleep_index < guard_index < broadcast_index, (
            f"{relative_path}: endgame guard must run after the interval sleep and before broadcast"
        )


if __name__ == "__main__":
    test_dashboard_announcer_stops_before_post_match_broadcast()
    print("endgame dashboard-announcer guard contract passed")
