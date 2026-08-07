#!/usr/bin/env python3
"""Regression checks for OA auto-countermeasure burst teardown."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SOURCE_REL = Path("Client/Module/CM/CM_AutoCM_OA.sqf")


def test_auto_cm_burst_stops_after_aircraft_death() -> None:
    for mission_dir in MISSION_DIRS:
        source = (mission_dir / SOURCE_REL).read_text(encoding="utf-8-sig")

        assert 'for "_i" from 1 to _burst do {' not in source
        assert (
            "for [{_i = 1}, {_i <= _burst && {alive _vehicle}}, "
            "{_i = _i + 1}] do {"
        ) in source

        clear = '_vehicle setVariable ["FlareActive", false];'
        clear_at = source.rfind(clear)
        assert clear_at >= 0
        assert "if (alive _vehicle) then {" in source[clear_at - 96 : clear_at]


def test_auto_cm_source_is_identical_across_maintained_mirrors() -> None:
    sources = [(mission_dir / SOURCE_REL).read_bytes() for mission_dir in MISSION_DIRS]
    for source in sources:
        assert source.replace(b"\r\n", b"").find(b"\n") == -1
    assert sources[1:] == [sources[0], sources[0]]


if __name__ == "__main__":
    test_auto_cm_burst_stops_after_aircraft_death()
    test_auto_cm_source_is_identical_across_maintained_mirrors()
    print("OA auto-countermeasure lifecycle checks passed")
