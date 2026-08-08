"""Regression contract for the AICOM2 AIRSTRIKE capability gate."""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = tuple(
    ROOT / mission_root
    for mission_root in (
        "Missions/[55-2hc]warfarev2_073v48co.chernarus",
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
    )
)


def _source(root: Path) -> str:
    path = root / "Server/AI/Commander/AI_Commander_AirStrike.sqf"
    return mask_comments(path.read_text(encoding="utf-8-sig"))


def test_airstrike_capability_gate_honors_captured_airfield_free_air() -> None:
    """A held airfield must enable a strike even without a factory or research tier."""
    sources = [_source(root) for root in MISSION_ROOTS]
    for source in sources:
        free_air = source.index("_freeAirWaive =")
        air_ok = source.index("_airOK =")
        assert free_air < air_ok
        assert "_airOK = _freeAirWaive || {_hasAirFactory ||" in source
    assert sources[0].encode("utf-8") == sources[1].encode("utf-8") == sources[2].encode("utf-8")


if __name__ == "__main__":
    test_airstrike_capability_gate_honors_captured_airfield_free_air()
    print("AICOM AIRSTRIKE captured-airfield gate contract: PASS")
