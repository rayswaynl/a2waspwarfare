#!/usr/bin/env python3
"""Regression contract for the late-join commander vacancy snapshot.

The commander team is stored on a side logic object.  A2 OA does not replay an
earlier public object-variable write to a late-joining client reliably, while
the commander-assigned and disconnected notifications are event-only.  The
connect handler must therefore re-dirty the current value for every terrain.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = {
    "chernarus": ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    "takistan": ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    "zargabad": ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
}


def test_connect_rebroadcasts_commander_state_for_jip_clients() -> None:
    """A join after a commander leaves receives the current AI/vacancy value."""
    needle = '_jipLogik setVariable ["wfbe_commander", (_jipLogik getVariable "wfbe_commander"), true];'
    for terrain, mission in MISSIONS.items():
        source = (mission / "Server" / "Functions" / "Server_OnPlayerConnected.sqf").read_text(
            encoding="utf-8-sig"
        )
        assert needle in source, terrain
        assert source.index(needle) < source.index('if !(isNil {_jipLogik getVariable "wfbe_votetime"}) then {'), terrain
