#!/usr/bin/env python3
"""Regression checks for the remaining J6 town-initialization wait guards."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

SITES = (
    (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Towns.sqf"),
        "waitUntil {townModeSet};",
        "_wTownMode",
    ),
    (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Town.sqf"),
        "waitUntil {townModeSet && WFBE_Parameters_Ready};",
        "_wTownMode",
    ),
    (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Town.sqf"),
        "waitUntil {commonInitComplete};",
        "_wCommonInit",
    ),
    (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Town.sqf"),
        "waitUntil {serverInitComplete};",
        "_wServerInit",
    ),
    (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Town.sqf"),
        'waitUntil {!isNil {_town getVariable "supplyValue"}};',
        "_wSupplyValue",
    ),
    (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Town.sqf"),
        "waitUntil {townInitServer};",
        "_wTownInitServer",
    ),
    (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Town.sqf"),
        'waitUntil {!isNil {_town getVariable "camps"}};',
        "_wCamps",
    ),
    (
        Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_TownMode.sqf"),
        "waitUntil {WFBE_Parameters_Ready};",
        "_wParameters",
    ),
)


def test_remaining_j6_wait_sites_are_bounded_and_diagnostic() -> None:
    seen = 0
    for relative_path, old_wait, guard_token in SITES:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        assert old_wait not in source, f"{relative_path}: legacy wait remains"
        assert f"{guard_token} = 0;" in source, f"{relative_path}: missing counter {guard_token}"
        start = source.index(f"{guard_token} = 0;")
        # Window widened 700 -> 1200 (2026-07-21). The guard shape is unchanged; the Init_Town.sqf
        # _wSupplyValue site drifted out of the old window when kimi/bughunt-mission-core (2026-07-20)
        # inserted a 5-line comment between the bounded while and its HANGGUARD diag_log, pushing the
        # diagnostic to 938 chars past the counter. Largest current gap is 938, so 1200 keeps margin
        # while still failing if a site loses its diagnostic entirely.
        block = source[start : start + 1200]
        assert "while {" in block, f"{relative_path}: missing bounded while guard"
        assert "uiSleep 0.25" in block, f"{relative_path}: missing uiSleep yield"
        assert "HANGGUARD|" in block, f"{relative_path}: missing timeout diagnostic"
        seen += 1

    assert seen == 8

    all_source = "\n".join(
        (ROOT / relative_path).read_text(encoding="utf-8")
        for relative_path in {
            relative_path for relative_path, _, _ in SITES
        }
    )
    assert all_source.count("while {") >= 8
    assert all_source.count("uiSleep 0.25") >= 8
    assert all_source.count("HANGGUARD|") >= 8


if __name__ == "__main__":
    test_remaining_j6_wait_sites_are_bounded_and_diagnostic()
