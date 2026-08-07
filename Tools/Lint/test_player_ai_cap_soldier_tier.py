"""Regression contract for the Soldier AI-cap bonus with population tiers."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
TARGETS = [
    MISSION / "Client" / "GUI" / "GUI_Menu_BuyUnits.sqf",
    MISSION / "Client" / "Client_UpdateRHUD.sqf",
]


def test_soldier_bonus_is_applied_after_tier_resolution() -> None:
    """The Soldier's 1.5x cap must survive the live tier-array override."""
    marker = 'WFBE_SK_V_AI_CAP_MULTIPLIER'
    tier_marker = "_mbu = _mbuByTier select _mbuPT"

    for target in TARGETS:
        source = target.read_text(encoding="utf-8")
        assert marker in source, f"{target} does not apply the Soldier cap multiplier"
        assert source.index(marker) > source.index(tier_marker), (
            f"{target} applies the Soldier multiplier before its tier override"
        )


if __name__ == "__main__":
    test_soldier_bonus_is_applied_after_tier_resolution()
