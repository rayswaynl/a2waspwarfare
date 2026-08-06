"""Contract for AICOM strategy strength snapshot reuse.

The server refreshes ``wfbe_aicom2_snap`` immediately before Strategy.  The
snapshot already computes the exact maneuver-strength values that Strategy
uses for last-stand, posture, and HQ-strike gates.  Keep those values on the
same snapshot path, while retaining the legacy scan for direct/manual calls
that do not have a fresh snapshot.
"""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str, rel: str) -> str:
    return (ROOT / mission / rel).read_text(encoding="utf-8-sig")


def test_snapshot_publishes_strength_fields_for_each_mirror() -> None:
    for mission in MISSIONS:
        snapshot = _read(mission, "Server/AI/Commander/AI_Commander_Snapshot.sqf")
        assert "_snap set [WFBE_SNAP_MYSTR,     _myStr];" in snapshot
        assert "_snap set [WFBE_SNAP_ENSTR,     _enStr];" in snapshot


def test_strategy_consumes_snapshot_strength_and_keeps_manual_fallback() -> None:
    for mission in MISSIONS:
        strategy = _read(mission, "Server/AI/Commander/AI_Commander_Strategy.sqf")

        snap_start = strategy.index("if (_snapOk) then {")
        fallback_start = strategy.index("} else {", snap_start)
        snap_branch = strategy[snap_start:fallback_start]
        strength_fallback = strategy.split("if (!_snapOk) then {", 1)[1].split(
            "};\n//--- 0)", 1
        )[0]

        assert re.search(r"_myStr\s*=\s*_snap select WFBE_SNAP_MYSTR;", snap_branch)
        assert re.search(r"_enStr\s*=\s*_snap select WFBE_SNAP_ENSTR;", snap_branch)
        assert "_myStr = 0;" in strength_fallback
        assert "_enStr = 0;" in strength_fallback


def test_strategy_mirrors_are_byte_identical() -> None:
    paths = [
        ROOT / mission / "Server/AI/Commander/AI_Commander_Strategy.sqf"
        for mission in MISSIONS
    ]
    contents = [path.read_bytes() for path in paths]
    assert contents[0] == contents[1] == contents[2]


def test_snapshot_mirrors_are_byte_identical() -> None:
    paths = [
        ROOT / mission / "Server/AI/Commander/AI_Commander_Snapshot.sqf"
        for mission in MISSIONS
    ]
    contents = [path.read_bytes() for path in paths]
    assert contents[0] == contents[1] == contents[2]
