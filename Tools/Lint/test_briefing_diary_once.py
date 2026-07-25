#!/usr/bin/env python3
"""Regression check: a client re-init must not duplicate its briefing diary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_briefing_is_once_per_client_session() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Client/Init/Init_Client.sqf").read_text(encoding="utf-8")
        assert 'if (isNil "WFBE_Client_BriefingLoaded") then {' in source, (
            f"{terrain}: missing briefing re-init guard"
        )
        assert "WFBE_Client_BriefingLoaded = true;" in source, (
            f"{terrain}: missing briefing session latch"
        )
        assert source.count('[] Call Compile preprocessFile "briefing.sqf";') == 1, (
            f"{terrain}: briefing must have one guarded call site"
        )


def test_class_guide_is_not_added_twice_on_first_join() -> None:
    for terrain in TERRAINS:
        actions = (ROOT / terrain / "WASP/actions/AddActions.sqf").read_text(encoding="utf-8")
        assert 'player createDiaryRecord ["Diary", ["Class Guide",' not in actions, (
            f"{terrain}: obsolete legacy Class Guide duplicates the briefing page"
        )


if __name__ == "__main__":
    test_briefing_is_once_per_client_session()
    test_class_guide_is_not_added_twice_on_first_join()
    print("briefing diary once regression check passed")
