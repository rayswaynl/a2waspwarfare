#!/usr/bin/env python3
"""Regression contract for the base-repair client worker cadence."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

FALLBACK_YIELD = (
    'if (!_isCommander && WFBE_SK_V_Type != "Spotter") then {\n'
    '\t\tsleep 1;\n'
    '\t};'
)


def test_base_repair_worker_yields_for_regular_clients_in_all_mirrors() -> None:
    for mission in MISSIONS:
        source = (mission / "WASP" / "baserep" / "viem.sqf").read_text(encoding="utf-8")

        assert source.count(FALLBACK_YIELD) == 1, (
            f"{mission.name}: regular-client fallback yield must be present exactly once"
        )
        assert source.index(FALLBACK_YIELD) > source.index("\t\tsleep 3;"), (
            f"{mission.name}: fallback yield must follow the commander cadence branch"
        )


if __name__ == "__main__":
    test_base_repair_worker_yields_for_regular_clients_in_all_mirrors()
    print("base-repair client cadence contract: PASS")
