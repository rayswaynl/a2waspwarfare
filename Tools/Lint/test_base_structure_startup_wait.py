#!/usr/bin/env python3
"""Regression contract for BaseStructure marker startup waits."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SOURCE = Path("Client") / "Init" / "Init_BaseStructure.sqf"


def test_base_structure_startup_waits_yield_and_fail_closed() -> None:
    source = (CH / SOURCE).read_text(encoding="utf-8")

    assert "waitUntil {commonInitComplete};" not in source
    assert 'waitUntil {!isNil "WFBE_Client_SideID"};' not in source
    assert "_baseStructureInitStarted = time;" in source
    assert "_baseStructureInitDeadline = _baseStructureInitStarted + 120;" in source
    assert "_baseStructureInitDeadline = time + 90;" in source
    assert source.count("sleep 0.25;") >= 3
    assert "BASE-STRUCTURE-INIT-TIMEOUT" in source
    assert "BASE-STRUCTURE-CLIENT-TIMEOUT" in source
    assert "BASE-STRUCTURE-SIDEID-TIMEOUT" in source


def test_base_structure_startup_wait_is_mirrored() -> None:
    digest = (CH / SOURCE).read_bytes()
    for mirror in MIRRORS:
        assert (mirror / SOURCE).read_bytes() == digest


if __name__ == "__main__":
    test_base_structure_startup_waits_yield_and_fail_closed()
    test_base_structure_startup_wait_is_mirrored()
    print("base-structure startup wait regression checks passed")
