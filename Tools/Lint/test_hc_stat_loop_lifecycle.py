#!/usr/bin/env python3
"""Regression contract for HC telemetry loop termination at round end."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
]

LOOP_GUARD = "while {!WFBE_GameOver} do {"
TERMINAL_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {};"


def read(root: Path) -> str:
    return (root / "Headless/HC_StatLoop.sqf").read_text(encoding="utf-8-sig")


def test_hc_stat_loop_stops_after_round_end() -> None:
    sources = [read(root) for root in MISSION_ROOTS]

    for text in sources:
        loop_index = text.index(LOOP_GUARD)
        send_index = text.index('["HCStat"', loop_index)
        sleep_index = text.index("sleep 60;", send_index)
        terminal_index = text.index(TERMINAL_GUARD, sleep_index)

        assert "while {true} do {" not in text[loop_index : loop_index + len(LOOP_GUARD)]
        assert loop_index < send_index < sleep_index < terminal_index

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_hc_stat_loop_stops_after_round_end()
    print("HC stat loop lifecycle contract: PASS")
