#!/usr/bin/env python3
"""Regression contract for the pre-registration town worker delay."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_town_worker_pre_registration_delay_uses_real_time_yield() -> None:
    for mission_root in MISSION_ROOTS:
        source = (mission_root / "Common" / "Init" / "Init_Town.sqf").read_text(encoding="utf-8")
        start = source.index("//--- Prevent the isServer bug on the client.")
        end = source.index('if (isNull _town || (_town getVariable "wfbe_inactive")) exitWith {};', start)
        block = source[start:end]

        assert "uiSleep (1.2 + random 0.2);" in block, mission_root
        assert "sleep (1.2 + random 0.2);" not in block, mission_root


if __name__ == "__main__":
    test_town_worker_pre_registration_delay_uses_real_time_yield()
