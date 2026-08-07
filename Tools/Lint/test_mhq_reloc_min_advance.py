#!/usr/bin/env python3
"""Regression contract for the MHQ minimum-advance abort boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_MHQReloc.sqf",
    ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_MHQReloc.sqf",
    ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_MHQReloc.sqf",
)


def test_min_advance_abort_is_script_scoped_and_precedes_trigger() -> None:
    raw_mirrors = [path.read_bytes() for path in MIRRORS]
    assert all(raw == raw_mirrors[0] for raw in raw_mirrors[1:])
    assert all(raw.count(b"\r\n") == raw.count(b"\n") == raw.count(b"\r") for raw in raw_mirrors)
    texts = [raw.decode("utf-8-sig") for raw in raw_mirrors]

    for text in texts:
        start = text.index("//--- B74 MIN-ADVANCE")
        no_buffer = text.index("//--- No friendly town", start)
        trigger = text.index("|TRIGGER|frontDist=", no_buffer)
        block = text[start:no_buffer]
        assignment = "_advanceBelowMin = ((_advD < _minAdv) && ((!_relaxSkip) || (_usedRing >= (600 + _townBuffer))));"
        script_exit = text.index("if (_advanceBelowMin) exitWith {", start)

        assert "_advanceBelowMin" in block
        assert "_advanceBelowMin = false;" in block
        assert assignment in block
        assert "if ((_advD < _minAdv) && ((!_relaxSkip) || (_usedRing >= (600 + _townBuffer)))) exitWith {" not in block
        assert script_exit > text.index(assignment, start)
        assert script_exit < no_buffer < trigger


if __name__ == "__main__":
    test_min_advance_abort_is_script_scoped_and_precedes_trigger()
