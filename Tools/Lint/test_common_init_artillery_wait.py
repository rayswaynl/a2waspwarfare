#!/usr/bin/env python3
"""Regression checks for the BIS artillery UI initialization waiter."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Common_InitArtillery.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Common_InitArtillery.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Common_InitArtillery.sqf",
)


def test_artillery_ui_wait_yields_bounds_and_exits_for_deleted_vehicle():
    source_bytes = []

    for relative_path in RELATIVE_PATHS:
        path = ROOT / relative_path
        source = path.read_text(encoding="utf-8-sig")
        source_bytes.append(path.read_bytes())

        wait_start = source.index("waitUntil {")
        wait_end = source.index("};", wait_start) + 2
        wait_block = source[wait_start:wait_end]

        assert "sleep 0.25;" in wait_block, relative_path
        assert "_artyWaitDeadline = diag_tickTime + 120;" in source, relative_path
        assert "isNull _arty" in wait_block, relative_path
        assert "diag_tickTime >= _artyWaitDeadline" in wait_block, relative_path
        assert "waitUntil {BIS_ARTY_LOADED};" not in source, relative_path

        deleted_guard = "if (isNull _arty) exitWith {};"
        unloaded_guard = 'if (isNil "BIS_ARTY_LOADED" || {!BIS_ARTY_LOADED}) exitWith {};'
        init_call = "[_arty] call BIS_ARTY_F_initVehicle;"
        assert deleted_guard in source, relative_path
        assert unloaded_guard in source, relative_path
        assert source.index(deleted_guard) < source.index(init_call), relative_path
        assert source.index(unloaded_guard) < source.index(init_call), relative_path

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == "__main__":
    test_artillery_ui_wait_yields_bounds_and_exits_for_deleted_vehicle()
    print("common artillery initialization wait regression checks passed")
