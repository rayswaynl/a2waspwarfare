"""Regression contract for commander relief of a capture-contested owned town.

``server_town.sqf`` publishes ``wfbe_contested`` from its authoritative capture
scan.  Strategy must consume that exact state for relief selection: town AI
activation is a population/materialization concern, not proof of a capture.
"""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_relief_selects_owned_towns_from_authoritative_contest_state() -> None:
    sources = []
    for mission in MISSIONS:
        source = mask_comments(
            (mission / "Server/AI/Commander/AI_Commander_Strategy.sqf").read_text(
                encoding="utf-8-sig"
            )
        )
        sources.append(source)

        relief_start = source.index("_attacked = [];")
        relief_end = source.index("_relieved = 0;", relief_start)
        relief_scan = source[relief_start:relief_end]
        assert 'getVariable ["wfbe_contested", false]' in relief_scan
        assert 'getVariable ["wfbe_active", false]' not in relief_scan

    assert sources[1:] == [sources[0], sources[0]]


if __name__ == "__main__":
    test_relief_selects_owned_towns_from_authoritative_contest_state()
    print("PASS: AICOM relief follows capture contest state")
