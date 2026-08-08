#!/usr/bin/env python3
"""Regression contract for the MATCH START town-slot identity field."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SERVER_INIT = Path("Server") / "Init" / "Init_Server.sqf"


def _match_start_block(source: str) -> str:
    start = source.index("//--- MATCH|v1|START|")
    end = source.index("//--- AICAP MID/HIGH TRIM", start)
    return source[start:end]


def test_match_start_reads_precomputed_total_towns_on_all_terrains() -> None:
    expected = re.compile(
        r'_mtStartTowns\s*=\s*if\s*\(!isNil\s+"totalTowns"\)\s*then\s*'
        r'\{\s*totalTowns\s*\}\s*else\s*\{\s*-1\s*\}\s*;'
    )

    for mission_root in MISSION_ROOTS:
        source = (mission_root / SERVER_INIT).read_text(encoding="utf-8-sig")
        block = _match_start_block(source)
        assert expected.search(block), mission_root
        assert "count towns" not in block, mission_root


def test_match_start_docs_name_total_towns_as_the_town_slot_source() -> None:
    docs = (ROOT / "docs" / "WASPSTAT-FORMAT.md").read_text(encoding="utf-8")

    assert "| `towns` | `totalTowns` | Selected town slots for this match." in docs


if __name__ == "__main__":
    test_match_start_reads_precomputed_total_towns_on_all_terrains()
    test_match_start_docs_name_total_towns_as_the_town_slot_source()
