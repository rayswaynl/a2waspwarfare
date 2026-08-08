"""Regression contract for player death attribution when no live killer remains.

RequestOnUnitKilled resets the victim streak before resolving delayed vehicle and
environmental attribution, but its null/dead-killer exit historically skipped the
WFBE_STAT_DEATHS write below the exit.  The death counter must be recorded for a
confirmed dead player even when the killer is unavailable, without accepting a
live-victim forged payload.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
KILL_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestOnUnitKilled.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/RequestOnUnitKilled.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/RequestOnUnitKilled.sqf"
    ),
)


def _early_exit_block(source: str) -> str:
    start = source.index("if !(alive _killer) exitWith")
    end = source.index("//--- Retrieve basic information.", start)
    return source[start:end]


def test_null_or_dead_killer_still_records_confirmed_player_death() -> None:
    source_bytes = []
    for relative in KILL_PATHS:
        path = ROOT / relative
        source = path.read_text(encoding="utf-8-sig")
        block = _early_exit_block(source)
        assert "WFBE_STAT_DEATHS" in block
        assert "getPlayerUID _killed" in block
        assert "WFBE_SE_FNC_RecordStat" in block
        assert "!alive _killed" in block
        assert "isPlayer _killed" in block
        source_bytes.append(path.read_bytes())

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == "__main__":
    test_null_or_dead_killer_still_records_confirmed_player_death()
    print("RequestOnUnitKilled death-attribution contract: PASS")
