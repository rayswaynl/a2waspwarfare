"""Regression contract for role-preserving USV flotilla refills."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
USV = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf"


def test_refill_selects_a_missing_role_before_round_robin_fallback():
    source = USV.read_text(encoding="utf-8-sig")
    maintain = source[source.index("//=== (3) MAINTAIN:"):]

    assert '_nextRole = "";' in maintain
    assert 'if ((_x select 0) == _candidateRole) then {_rolePresent = true};' in maintain
    assert '_nextRole = _candidateRole' in maintain
    assert '_nextRole = (_roles select ((count _flotilla) mod (count _roles)));' in maintain
    assert maintain.index('_nextRole = _candidateRole') < maintain.index(
        '_nextRole = (_roles select ((count _flotilla) mod (count _roles)));'
    )


if __name__ == "__main__":
    test_refill_selects_a_missing_role_before_round_robin_fallback()
