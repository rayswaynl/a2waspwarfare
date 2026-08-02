"""Regression contract for convoy recovery when the leader has dismounted.

The AICOM town-assignment watchdog must judge physical convoy progress from a
movable land hull when one exists.  A dismounted leader can advance on foot
while the actual convoy remains wedged, which otherwise suppresses both the
timeout recovery and the sticky-order strike ladder.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ASSIGN_FILES = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_AssignTowns.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_AssignTowns.sqf"),
)


def test_convoy_watchdogs_anchor_progress_on_a_movable_land_hull() -> None:
    for relative_path in ASSIGN_FILES:
        source = (ROOT / relative_path).read_text(encoding="utf-8-sig")

        assert "_aicomProgressAnchor = {" in source
        assert '_paCandidate isKindOf "LandVehicle"' in source
        assert "canMove _paCandidate" in source

        assert "_danchor = [_team] Call _aicomProgressAnchor;" in source
        assert "_ddist  = _danchor distance _dtgt;" in source
        assert "then {_moved = _danchor distance (_dord select 2)};" in source

        assert "_anchor = [_team] Call _aicomProgressAnchor;" in source
        assert "_notProgressing = if (_goalDeltaOn) then {((_goto distance (_ord select 2)) - (_goto distance _anchor)) < _movedThr} else {(_anchor distance (_ord select 2)) < _movedThr};" in source
