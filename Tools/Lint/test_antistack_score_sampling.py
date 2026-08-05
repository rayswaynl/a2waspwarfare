"""Regression contract for the one-second AntiStack score sampler."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SCORE_SAMPLER = Path("Server/Module/AntiStack/updateScoreInternal.sqf")


def test_score_sampler_does_not_census_all_units_each_second() -> None:
    sources = [
        (root / SCORE_SAMPLER).read_text(encoding="utf-8-sig")
        for root in MISSION_ROOTS
    ]

    for source in sources:
        assert "count allUnits" not in source
        assert "_perfAllUnits" not in source
        assert "[] call WFBE_CO_FNC_RealPlayers" in source
        assert 'Format["players:%1", _perfPlayers]' in source

    normalized = [source.replace("\r\n", "\n") for source in sources]
    assert normalized[0] == normalized[1] == normalized[2]
