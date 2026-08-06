"""Regression coverage for AICOM relief-slot accounting."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STRATEGY_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Server/AI/Commander/AI_Commander_Strategy.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Server/AI/Commander/AI_Commander_Strategy.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Server/AI/Commander/AI_Commander_Strategy.sqf"
    ),
)


def test_dead_reliever_does_not_occupy_the_only_relief_slot() -> None:
    """A destroyed QRF must not block a live replacement for its threatened town."""
    expected = (
        '{ if (!isNull _x && {(count ((units _x) Call WFBE_CO_FNC_GetLiveUnits)) > 0} '
        '&& {([_x, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool) '
        '== _town}) exitWith {_free = _x} } forEach _teams;'
    )
    for relative_path in STRATEGY_PATHS:
        assert expected in (ROOT / relative_path).read_text(encoding="utf-8")
