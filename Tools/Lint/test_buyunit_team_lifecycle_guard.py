"""Regression contract for AIBuyUnit team teardown races."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BUY_UNIT = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/Functions/Server_BuyUnit.sqf"
)


def test_wait_abort_guards_reject_ended_or_empty_commander_teams() -> None:
    """A wiped/disbanded team must not reach unit creation after an async wait."""
    lines = BUY_UNIT.read_text(encoding="utf-8-sig").splitlines()
    prequeue_guard = next(line.strip() for line in lines if line.strip().startswith("if (isPlayer (leader _team)"))
    mid_guard = next(line.strip() for line in lines if line.strip().startswith("if (!(alive _building)"))
    post_guard = next(line.strip() for line in lines if line.strip().startswith("if (_refunded ||"))

    for guard in (prequeue_guard, mid_guard, post_guard):
        assert '"wfbe_aicom_ended_fired"' in guard
        assert "count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0" in guard
