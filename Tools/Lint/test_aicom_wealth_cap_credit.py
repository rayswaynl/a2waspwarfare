from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UPDATE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "FSM" / "updateresources.sqf"


def test_aicom_income_credits_are_limited_to_remaining_wealth_cap():
    source = UPDATE.read_text(encoding="utf-8")

    assert "(_wealthCap - _aicomFunds) max 0" in source
    assert "(_incomeCredit min ((_wealthCap - _aicomFunds) max 0))" in source
    assert "(_stipendCredit min ((_wealthCap - _aicomFunds) max 0))" in source
