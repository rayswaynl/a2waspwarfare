"""Static regression coverage for AI-only GUER vehicle-tier progression."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STIPEND = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Server_GuerStipend.sqf"


def test_no_human_guer_round_uses_elapsed_tier_fallback():
    source = STIPEND.read_text(encoding="utf-8")

    assert "count _paidGroups" in source
    assert "_fallbackTier" in source
    assert "time >= 1800" in source
    assert "time >= 5400" in source
    assert "time >= 10800" in source


def test_stipend_skips_fund_mutation_without_eligible_guer_group():
    source = STIPEND.read_text(encoding="utf-8")

    skip_at = source.index("GUERSTIPEND|SKIP")
    funds_at = source.index("WFBE_CO_FNC_ChangeTeamFunds")
    assert skip_at < funds_at
    assert "if ((count _paidGroups) == 0)" in source


if __name__ == "__main__":
    test_no_human_guer_round_uses_elapsed_tier_fallback()
    test_stipend_skips_fund_mutation_without_eligible_guer_group()
