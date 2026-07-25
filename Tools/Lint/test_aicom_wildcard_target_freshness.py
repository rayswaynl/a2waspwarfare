"""Regression contract for stale published AICOM wildcard targets."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
WILDCARD_PATH = "Server/Functions/AI_Commander_Wildcard.sqf"

W4_STALE_TARGET_GUARD = (
    'if (!isNull _bestTown && {(_bestTown getVariable ["sideID", -1]) == _sideID}) '
    'then {_bestTown = objNull};'
)
W6_STALE_TARGET_GUARD = (
    'if (!isNull _w6BestTown && {(_w6BestTown getVariable ["sideID", -1]) == _sideID}) '
    'then {_w6BestTown = objNull};'
)
W22_STALE_TARGET_GUARD = (
    'if (!isNull _w22Target && {(_w22Target getVariable ["sideID", -1]) == _sideID}) '
    'then {_w22Target = objNull};'
)


def test_wildcard_falls_back_when_a_published_target_has_been_captured():
    """W4/W6/W22 must not reuse a still-live town now owned by their own side."""
    sources = []
    for mission_root in MISSION_ROOTS:
        source = (mission_root / WILDCARD_PATH).read_text(encoding="utf-8-sig")
        sources.append(source.encode("utf-8"))

        assert W4_STALE_TARGET_GUARD in source
        assert W6_STALE_TARGET_GUARD in source
        assert W22_STALE_TARGET_GUARD in source
        assert source.index(W4_STALE_TARGET_GUARD) < source.index("if (isNull _bestTown) then {")
        assert source.index(W6_STALE_TARGET_GUARD) < source.index("_detail = Format [\"air_template=%1")
        assert source.index(W22_STALE_TARGET_GUARD) < source.index("if (isNull _w22Target && {count _cands > 0})")

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_wildcard_falls_back_when_a_published_target_has_been_captured()
    print("AICOM wildcard target freshness contract: PASS")
