"""Regression contract for road-route samples collapsing onto one road node.

BuildRoadRoute samples several fraction points.  In sparse road regions those
samples can all resolve to the same road object.  The returned chain must not
inflate that single point into a CYCLE patrol route: callers use its count to
decide whether the direct-move fallback is required.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROUTE_FILES = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_BuildRoadRoute.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_BuildRoadRoute.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_BuildRoadRoute.sqf"),
)

DISTINCT_NODE_GUARD = "if (!_rmRouteDuplicate) then {_route = _route + [_rmPos]};"


def test_repeated_road_snap_is_not_counted_as_a_new_route_node() -> None:
    for relative_path in ROUTE_FILES:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert "_rmRouteDuplicate" in text, (
            f"route builder lacks duplicate-node detection in {relative_path}"
        )
        assert DISTINCT_NODE_GUARD in text, (
            f"duplicate road node can still inflate the route in {relative_path}"
        )
