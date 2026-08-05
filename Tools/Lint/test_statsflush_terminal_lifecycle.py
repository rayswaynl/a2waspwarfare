from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Stats/StatsFlush.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Stats/StatsFlush.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Stats/StatsFlush.sqf",
)


def test_statsflush_stops_before_post_gameover_credit() -> None:
    sources = []

    for relative_path in RELATIVE_PATHS:
        path = ROOT / relative_path
        source = path.read_text(encoding="utf-8-sig")
        sources.append(path.read_bytes())

        assert "while {!WFBE_GameOver} do {" in source, relative_path
        assert "while {true} do {" not in source, relative_path

        sleep_offset = source.index("sleep WFBE_C_STATS_FLUSH_INTERVAL;")
        guard = "if (WFBE_GameOver) exitWith {};"
        guard_offset = source.index(guard, sleep_offset)
        credit_offset = source.index("[] call WFBE_SE_FNC_CreditPlaytimeConnected;", guard_offset)
        flush_offset = source.index("[] call WFBE_SE_FNC_FlushStatsDirty;", credit_offset)
        assert sleep_offset < guard_offset < credit_offset < flush_offset, relative_path

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_statsflush_stops_before_post_gameover_credit()
