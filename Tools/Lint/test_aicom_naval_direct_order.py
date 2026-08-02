"""Regression contract for direct commander orders issued to ship teams.

A long direct order must not put a ship through the land-only road-route
builder: its intermediate waypoints can be on shore and strand the vessel
before it reaches the actual destination.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EXECUTOR_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Execute.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Execute.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Execute.sqf"),
)

SHIP_EXCLUSION = '!((vehicle _x) isKindOf "Ship")'


def test_direct_commander_orders_do_not_road_march_ship_teams() -> None:
    sources = []
    for relative_path in EXECUTOR_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        sources.append(source)
        assert SHIP_EXCLUSION in source, (
            f"server-local direct-order vehicle gate still includes ships in {relative_path}"
        )

    assert sources[1:] == [sources[0], sources[0]]
