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
    """D6c v2 (PR #2001): the hard block applies ONLY to a mission with zero depot
    ENTITIES (genuinely town-less / broken sqm). A zero-REGISTERED census with
    candidates present must NOT hold the gate - town workers carry a game-time
    sleep and game time is frozen until match start, so gating startup on
    registration deadlocks the whole boot (burned live on wave0802, 2026-08-03)."""
    source = (CH / TOWN_INIT).read_text(encoding="utf-8")
    gate = _census_gate(source)

    assert "_townReadyCount = count towns;" in gate
    assert "_townReadyCount = _townReadyCount + 1;" not in gate
    # depot-less mission stays blocked, and the old registration-based block is gone
    assert "if ((count _towns) == 0) then {" in gate
    assert "TOWNINIT|v1|BLOCK|reason=NO_DEPOT_ENTITIES" in gate
    assert "TOWNINIT|v1|BLOCK|reason=NO_READY_TOWNS" not in gate
    assert "townInit = false;" in gate
    # zero-ready-with-candidates releases with DEFER + a loud unregistered watcher
    assert "TOWNINIT|v1|DEFER|ready=0" in gate
    assert "TOWNINIT|v1|UNREGISTERED" in gate
    assert "TOWNINIT|v1|LATE_REGISTERED" in gate


def test_readiness_uses_registered_towns_not_inactive_markers() -> None:
    source = (CH / TOWN_INIT).read_text(encoding="utf-8")
    gate = _census_gate(source)

    assert "_townReadyCount = count towns;" in gate
    assert "_townReadyCount = _townReadyCount + 1;" not in gate

    worker = (CH / TOWN_WORKER).read_text(encoding="utf-8")
    # r93 (PR #1904, folded 2026-08-02): the removal check compares the town NAME argument, not
    # str-of-logic — str of a depot LOGIC is "<id>: <class>" and could never match a bare name.
    inactive_start = worker.index('if (_townName in TownTemplate) exitWith {')
    inactive_end = worker.index('if (isNull _town || (_town getVariable "wfbe_inactive")) exitWith {};')
    inactive_path = worker[inactive_start:inactive_end]
    assert 'setVariable ["wfbe_inactive", true]' in inactive_path
    assert "towns = towns + [_town];" not in inactive_path


def test_ready_census_releases_town_init() -> None:
    """D6c v2: when depot entities exist, townInit releases unconditionally (the
    pre-guard, battle-proven semantics) - BEFORE the ready/defer split - and the
    done-marker logs on that shared path."""
    source = (CH / TOWN_INIT).read_text(encoding="utf-8")
    gate = _census_gate(source)

    block_idx = gate.index("townInit = false;")
    release_idx = gate.index("townInit = true;")
    ready_idx = gate.index("if (_townReadyCount > 0) then {")
    assert block_idx < release_idx < ready_idx
    assert "TOWNINIT|v1|READY" in gate
    assert "Towns initialization is done." in gate
    assert gate.index("Towns initialization is done.") > ready_idx


def test_town_init_gate_is_mirrored() -> None:
    digest = (CH / TOWN_INIT).read_bytes()
    for mirror in MIRRORS:
        assert (mirror / TOWN_INIT).read_bytes() == digest


if __name__ == "__main__":
    test_zero_ready_census_keeps_town_init_blocked()
    test_readiness_uses_registered_towns_not_inactive_markers()
    test_ready_census_releases_town_init()
    test_town_init_gate_is_mirrored()
