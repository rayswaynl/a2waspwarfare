#!/usr/bin/env python3
"""Regression checks for the two startup waits that previously hung silently."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def test_version_wait_is_bounded_and_keeps_legacy_fallback() -> None:
    source = (MISSION / "initJIPCompatible.sqf").read_text(encoding="utf-8")

    assert 'WFBE_INIT_HANDLE_VERSION = execVM "Common\\Init\\Init_Version.sqf";' in source
    assert "waitUntil {!isNil 'VERSION_SET'};" not in source
    assert "_versionInitDeadline = diag_tickTime + 15;" in source
    assert 'uiSleep 0.25; (!isNil "VERSION_SET") || {diag_tickTime > _versionInitDeadline}' in source
    assert "INITFAIL|v1|VERSION_SET_TIMEOUT|handleDone=" in source
    assert "VERSION_SET = nil;" in source


def test_common_town_wait_is_bounded_diagnostic_and_fail_closed() -> None:
    init_source = (MISSION / "initJIPCompatible.sqf").read_text(encoding="utf-8")
    server_source = (MISSION / "Server/Init/Init_Server.sqf").read_text(encoding="utf-8")

    assert 'WFBE_INIT_HANDLE_COMMON = ExecVM "Common\\Init\\Init_Common.sqf";' in init_source
    assert 'WFBE_INIT_HANDLE_TOWNS = ExecVM "Common\\Init\\Init_Towns.sqf";' in init_source
    assert "waitUntil {commonInitComplete && townInit};" not in server_source
    assert "_initGateDeadline = diag_tickTime + 120;" in server_source
    assert "INITWAIT|v1|COMMON_TOWN|elapsed=" in server_source
    assert "WFBE_INIT_FAILURE = [\"COMMON_TOWN_TIMEOUT\"" in server_source
    assert 'publicVariable "WFBE_INIT_FAILURE";' in server_source
    assert "INITFAIL|v1|COMMON_TOWN_TIMEOUT|common=" in server_source

    failure_start = server_source.index('if (!(commonInitComplete && townInit)) exitWith {')
    failure_block = server_source[failure_start : failure_start + 900]
    assert "exitWith" in failure_block
    assert "serverInitFull = true;" not in failure_block


if __name__ == "__main__":
    test_version_wait_is_bounded_and_keeps_legacy_fallback()
    test_common_town_wait_is_bounded_diagnostic_and_fail_closed()
    print("core startup wait-bound regression checks passed")
