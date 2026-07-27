"""Regression contract for recyclable USV carrier-approach gating."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
USV = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf"


def test_gate_open_clears_quiet_timer_before_prune_or_refill():
    source = USV.read_text(encoding="utf-8-sig")
    timer_update = "if (_gateActive) then { _gateInactiveTime = 0; } else { _gateInactiveTime = _gateInactiveTime + _tickInterval; };"

    assert source.count(timer_update) == 1
    assert source.index("_gateWasActive = _gateActive;") < source.index(timer_update)
    assert source.index(timer_update) < source.index("//=== (2) PRUNE + SELF-CLEAN + MOVEMENT TICK")
    assert source.index(timer_update) < source.index("if (_gateActive && {count _flotilla < _count}")


if __name__ == "__main__":
    test_gate_open_clears_quiet_timer_before_prune_or_refill()
