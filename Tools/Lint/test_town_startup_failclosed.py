#!/usr/bin/env python3
"""Regression contract for the zero-town startup fail-closed gate."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
TOWN_INIT = Path("Common") / "Init" / "Init_Towns.sqf"
TOWN_WORKER = Path("Common") / "Init" / "Init_Town.sqf"


def _census_gate(source: str) -> str:
    marker = "//--- TOWNINIT|v1|:"
    start = source.find(marker)
    return source[start:] if start >= 0 else source


def test_zero_ready_census_keeps_town_init_blocked() -> None:
    source = (CH / TOWN_INIT).read_text(encoding="utf-8")
    gate = _census_gate(source)

    assert "_townReadyCount = count towns;" in gate
    assert "_townReadyCount = _townReadyCount + 1;" not in gate
    assert "TOWNINIT|v1|BLOCK|reason=NO_READY_TOWNS" in gate
    assert "townInit = false;" in gate


def test_readiness_uses_registered_towns_not_inactive_markers() -> None:
    source = (CH / TOWN_INIT).read_text(encoding="utf-8")
    gate = _census_gate(source)

    assert "_townReadyCount = count towns;" in gate
    assert "_townReadyCount = _townReadyCount + 1;" not in gate

    worker = (CH / TOWN_WORKER).read_text(encoding="utf-8")
    inactive_start = worker.index('if ((str _town) in TownTemplate) exitWith {')
    inactive_end = worker.index('if (isNull _town || (_town getVariable "wfbe_inactive")) exitWith {};')
    inactive_path = worker[inactive_start:inactive_end]
    assert 'setVariable ["wfbe_inactive", true]' in inactive_path
    assert "towns = towns + [_town];" not in inactive_path


def test_ready_census_releases_town_init() -> None:
    source = (CH / TOWN_INIT).read_text(encoding="utf-8")
    gate = _census_gate(source)

    assert "if (_townReadyCount > 0) then {" in gate
    ready_start = gate.index("if (_townReadyCount > 0) then {")
    ready_end = gate.index("} else {", ready_start)
    assert "townInit = true;" in gate[ready_start:ready_end]
    assert "Towns initialization is done." in gate[ready_start:ready_end]


def test_town_init_gate_is_mirrored() -> None:
    digest = (CH / TOWN_INIT).read_bytes()
    for mirror in MIRRORS:
        assert (mirror / TOWN_INIT).read_bytes() == digest


if __name__ == "__main__":
    test_zero_ready_census_keeps_town_init_blocked()
    test_readiness_uses_registered_towns_not_inactive_markers()
    test_ready_census_releases_town_init()
    test_town_init_gate_is_mirrored()
