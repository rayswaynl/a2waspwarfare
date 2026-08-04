"""Regression contract for completed NEURO group waypoint lookup."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = Path("Server/Module/NEURO/NEURO.sqf")


def test_neuro_avoids_completed_waypoint_index():
    sources = []
    for mission_root in MISSION_ROOTS:
        source = (mission_root / RELATIVE).read_text(encoding="utf-8-sig")
        sources.append(source.encode("utf-8"))

        assert '"_destination","_waypointCount","_waypointIndex"' in source
        assert "_waypointCount = count (waypoints _this);" in source
        assert "_waypointIndex = currentWaypoint _this;" in source
        assert "if (_waypointIndex < _waypointCount) then {" in source
        assert "_destination = waypointPosition [_this, _waypointIndex];" in source
        assert "waypointPosition [_this, currentWaypoint _this]" not in source

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_neuro_avoids_completed_waypoint_index()
    print("NEURO waypoint bounds contract: PASS")
