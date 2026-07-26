"""Regression contract for clear AICOM airfield runway spawns.

HC-founded air teams must resolve from the ``LocationLogicAirport`` runway
anchor, then accept only a clear point along that runway.  The aircraft-buy
hangar is an interaction building, not a safe vehicle spawn surface.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEAM_FILES = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Teams.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Teams.sqf"),
)


def test_airfield_air_teams_use_a_clear_runway_candidate_not_the_hangar() -> None:
    sources = []
    for relative_path in TEAM_FILES:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        sources.append(source)

        assert "_runwayOffsets = [120,-120,240,-240,60,-60];" in source
        assert "_runwayCandidate = [_runwayAnchor, _runwayOffset, _runwayDir] Call GetPositionFrom;" in source
        assert "_runwayCandidate isFlatEmpty [18, 0, 2, 18, 0, false, objNull]" in source
        assert "_spawnPos = _runwayCandidate;" in source
        assert "if (!_runwayClear) then {_spawnPos = _runwayAnchor};" in source

    assert sources[1:] == [sources[0], sources[0]]


if __name__ == "__main__":
    test_airfield_air_teams_use_a_clear_runway_candidate_not_the_hangar()
    print("PASS: AICOM airfield teams require a clear runway candidate")
