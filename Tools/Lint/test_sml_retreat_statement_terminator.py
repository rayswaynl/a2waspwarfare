#!/usr/bin/env python3
"""Regression checks for the SML retreat logging-block terminator."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)

BLOCK_START = "if (count _detachedBySML3 > 0) then {"
WATCHDOG_MARKER = "//--- WATCHDOG: poll every 3s until TTL or exit condition."


def test_continuous_retreat_logging_block_is_terminated_and_mirrored() -> None:
    raw_sources = []
    for terrain in TERRAINS:
        path = ROOT / terrain / "Common/Functions/Common_SMLRetreat.sqf"
        raw_sources.append(path.read_bytes())
        source = path.read_text(encoding="utf-8-sig")
        block_start = source.index(BLOCK_START)
        watchdog_start = source.index(WATCHDOG_MARKER, block_start)
        logging_block = source[block_start:watchdog_start].rstrip()

        assert logging_block.endswith("};"), (
            f"{terrain}: continuous retreat if/else must end with '}};' before the watchdog"
        )

    assert raw_sources[0] == raw_sources[1] == raw_sources[2], (
        "Common_SMLRetreat.sqf differs across terrains"
    )


if __name__ == "__main__":
    test_continuous_retreat_logging_block_is_terminated_and_mirrored()
    print("SML retreat statement-terminator regression checks passed")
