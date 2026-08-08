"""Contract tests for the client-side proximity getters.

The nearEntities command returns an unsorted collection.  These helpers are
named GetClosest* and feed purchase, gear, hangar, and service decisions, so
each eligible candidate must be compared by distance before it replaces the
current result.
"""

from pathlib import Path
import re


REPO_ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOT = REPO_ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"

GETTERS = (
    MISSION_ROOT / "Client" / "Functions" / "Client_GetClosestDepot.sqf",
    MISSION_ROOT / "Client" / "Functions" / "Client_GetClosestCamp.sqf",
    MISSION_ROOT / "Client" / "Functions" / "Client_GetClosestAirport.sqf",
)


def test_each_structure_getter_selects_the_nearest_eligible_candidate() -> None:
    comparison = re.compile(
        r"if\s*\(\s*_candidateDistance\s*<\s*_closestDistance\s*\)\s*"
        r"then\s*\{\s*_closest\s*=\s*_x\s*;\s*_closestDistance\s*=\s*_candidateDistance\s*;?\s*\}",
        re.IGNORECASE | re.DOTALL,
    )

    for path in GETTERS:
        source = path.read_text(encoding="utf-8")
        assert "nearEntities" in source, path
        assert re.search(r"_candidateDistance\s*=\s*_x\s+distance\s+_pos", source, re.IGNORECASE), path
        assert comparison.search(source), path

    airport_source = GETTERS[-1].read_text(encoding="utf-8")
    assert "&& isNull _closest" not in airport_source
    assert re.search(r"_candidateDistance\s*=\s*_xn\s+distance\s+_pos", airport_source, re.IGNORECASE)
