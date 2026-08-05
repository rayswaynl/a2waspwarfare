#!/usr/bin/env python3
"""Regression contract for the airfield garrison registry lifecycle.

``Common_CreateTownUnits.sqf`` appends server-local airfield garrison assets to
``wfbe_airfield_garrison_units``.  A normal town deactivation destroys that
episode, so the per-town registry must be cleared in the same deactivation
path.  Otherwise every repeated airfield activation retains another batch of
dead/null object references until a capture happens.
"""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
TOWN_AI = Path("Server") / "FSM" / "server_town_ai.sqf"
CLEANUP = '["cleanup-airfield-garrison", _town]] Call WFBE_CO_FNC_SendToClients;'
CLEAR = '_town setVariable ["wfbe_airfield_garrison_units", [], false];'


def test_airfield_registry_is_cleared_after_normal_deactivation_cleanup():
    source = (CH / TOWN_AI).read_text(encoding="utf-8")
    cleanup_at = source.index(CLEANUP)
    ledger_at = source.index("//--- Commander Town Ledger", cleanup_at)
    deactivation_cleanup = source[cleanup_at:ledger_at]

    assert CLEAR in deactivation_cleanup, (
        "normal town deactivation broadcasts airfield cleanup but leaves "
        "wfbe_airfield_garrison_units populated for the next activation"
    )
    assert deactivation_cleanup.index(CLEAR) > deactivation_cleanup.index(CLEANUP)


def test_town_ai_mirrors_match_chernarus():
    digest = sha256((CH / TOWN_AI).read_bytes()).hexdigest()
    for mirror in MIRRORS:
        assert sha256((mirror / TOWN_AI).read_bytes()).hexdigest() == digest


if __name__ == "__main__":
    test_airfield_registry_is_cleared_after_normal_deactivation_cleanup()
    test_town_ai_mirrors_match_chernarus()
