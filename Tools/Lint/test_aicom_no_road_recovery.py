"""Regression contract for the AICOM foot no-road recovery landing check.

Tier-3 recovery runs when a foot/dead-hull commander team has no road nearby.
The recovery must only teleport the leader to an ``isFlatEmpty`` result; the
raw goalward guess can be steep or occupied and would create another wedge.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMMANDER_TEAM_FILES = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_RunCommanderTeam.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_RunCommanderTeam.sqf"),
)

RAW_GUESS_FALLBACK = "_nrPos  = if (count _nrFlat > 0) then {_nrFlat} else {_nrGuess};"
SAFE_LANDING_GUARD = "if (count _nrFlat > 0 && {!surfaceIsWater _nrFlat}) then {"


def test_no_road_foot_recovery_requires_flat_non_water_landing() -> None:
    for relative_path in COMMANDER_TEAM_FILES:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert RAW_GUESS_FALLBACK not in text, (
            f"unsafe raw no-road landing fallback still present in {relative_path}"
        )
        assert SAFE_LANDING_GUARD in text, (
            f"no-road recovery lacks flat non-water landing guard in {relative_path}"
        )
