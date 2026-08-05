"""Regression contract for stopping restart broadcasts after match end."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ANNOUNCER_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_restart_announcer.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_restart_announcer.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/FSM/server_restart_announcer.sqf"),
)

LOOP_GUARD = "while {!WFBE_GameOver} do {"
ENDGAME_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {};"


def test_restart_announcer_stops_after_terminal_sleep_before_next_poll() -> None:
    for relative_path in ANNOUNCER_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        loop_start = source.index(LOOP_GUARD)
        sleep_index = source.index("sleep 5;", loop_start)
        guard_index = source.index(ENDGAME_GUARD, sleep_index)
        broadcast_index = source.index('"RestartAnnounce"', loop_start)

        assert broadcast_index < sleep_index < guard_index, (
            f"{relative_path}: terminal guard must run after the polling sleep before the next loop poll"
        )
        assert "while {true} do {" not in source[loop_start : loop_start + len(LOOP_GUARD)]


if __name__ == "__main__":
    test_restart_announcer_stops_after_terminal_sleep_before_next_poll()
    print("restart-announcer lifecycle contract passed")
