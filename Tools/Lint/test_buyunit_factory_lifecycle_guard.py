"""Regression contract for factory ownership changes during an AICOM buy wait."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BUY_UNIT = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/Functions/Server_BuyUnit.sqf"
)


def test_post_wait_buy_revalidates_factory_side_registry() -> None:
    """A live but no-longer-owned factory must not deliver the paid unit."""
    lines = BUY_UNIT.read_text(encoding="utf-8-sig").splitlines()
    wait_index = next(i for i, line in enumerate(lines) if line.strip() == "sleep _waitTime;")
    post_guard_index = next(
        i for i, line in enumerate(lines) if line.strip().startswith("if (_refunded ||")
    )
    post_guard = lines[post_guard_index].strip()

    assert any(
        "WFBE_CO_FNC_GetSideStructures" in line
        for line in lines[wait_index:post_guard_index]
    )
    assert "!(_building in _sideStructs)" in post_guard
