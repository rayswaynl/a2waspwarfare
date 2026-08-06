"""Regression coverage for the duplicate AICOM side-live census scan."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEAMS_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Teams.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Teams.sqf",
)

SIDE_LIVE_SCAN = "_aicomSideLive = {alive _x && {side _x == _side} && {!isPlayer _x}} count _allUnits;"
SIDE_LIVE_REUSE = "_sideAINow = _aicomSideLive;"
DUPLICATE_SIDE_SCAN = "_sideAINow = {alive _x && {side _x == _side} && {!isPlayer _x}} count _allUnits;"


def test_side_ai_cap_reuses_existing_side_live_census() -> None:
    for path in TEAMS_PATHS:
        source = path.read_text(encoding="utf-8")
        assert SIDE_LIVE_SCAN in source
        assert SIDE_LIVE_REUSE in source
        assert DUPLICATE_SIDE_SCAN not in source
