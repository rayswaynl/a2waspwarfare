"""Regression contract for discounted AICOM refill affordability.

An active Black Market discount changes the amount actually debited from the
AI-commander treasury.  The affordability gate must therefore compare funds to
that charged amount, rather than rejecting a treasury that cannot cover the
undiscounted catalogue price.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PRODUCE_PATHS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf",
)


def test_black_market_affordability_uses_the_actual_charged_price():
    sources = []
    for path in PRODUCE_PATHS:
        text = path.read_text(encoding="utf-8-sig")
        sources.append(path.read_bytes())
        charged = text.index('_priceCharged = if (!isNil "_w15Exp"')
        affordability = text.index('if (_funds < _priceCharged) exitWith {};')
        debit = text.index('[_side, -_priceCharged] Call ChangeAICommanderFunds;')

        assert charged < affordability < debit
        assert 'if (_funds < _price) exitWith {};' not in text

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_black_market_affordability_uses_the_actual_charged_price()
    print("AICOM discounted affordability contract: PASS")
