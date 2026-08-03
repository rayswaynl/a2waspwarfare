"""Regression contract for AICOM wildcard town-alert intelligence boundaries."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
WILDCARD_PATH = "Server/Functions/AI_Commander_Wildcard.sqf"


def _block(source: str, start: str, end: str) -> str:
    return source[source.index(start) : source.index(end, source.index(start))]


def test_w13_and_w19_use_town_alerts_not_global_enemy_unit_scans():
    """Wildcard strike/QRF selection must consume town alerts, not allUnits."""
    sources = []
    for mission_root in MISSION_ROOTS:
        source = (mission_root / WILDCARD_PATH).read_text(encoding="utf-8-sig")
        sources.append(source.encode("utf-8"))

        w13_eligibility = _block(source, "//--- W13: gunship strike", "//--- W14: iron dome")
        w19_eligibility = _block(source, "//--- W19: HELIBORNE QRF", "//--- -----------------------------------------------------------------------\n\t\t\t\t//--- BASE WEIGHTS")
        w13_apply = _block(source, "case 13: {", "//--- W15: BLACK MARKET")
        w19_apply = _block(source, "case 19: {", "//--- W20: CAPTURED CACHE")

        for block in (w13_eligibility, w19_eligibility, w13_apply, w19_apply):
            assert "allUnits" not in block
            assert 'getVariable ["wfbe_active", false]' in block

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_w13_and_w19_use_town_alerts_not_global_enemy_unit_scans()
    print("AICOM wildcard alert-intel contract: PASS")
