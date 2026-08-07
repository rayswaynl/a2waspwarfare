#!/usr/bin/env python3
"""Regression contract for bounded Naval HVT startup readiness."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
NAVAL_HVT = Path("Server") / "Init" / "Init_NavalHVT.sqf"


def _source() -> str:
    return (ROOT / TERRAINS[0] / NAVAL_HVT).read_text(encoding="utf-8")


def test_naval_hvt_does_not_treat_empty_town_census_as_ready() -> None:
    source = _source()

    assert 'waitUntil { !isNil "townInit" && townInit };' not in source
    assert 'waitUntil { !isNil "towns" };' not in source
    assert 'missionNamespace getVariable ["townInit", false]' in source
    assert "count towns > 0" in source


def test_naval_hvt_waits_for_all_named_carrier_logics_with_deadline() -> None:
    source = _source()
    gate_start = source.index("_navalHvtDeadline")
    gate_end = source.index("//--- HELPER", gate_start)
    gate = source[gate_start:gate_end]

    assert "diag_tickTime + 420" in gate
    assert "diag_tickTime + 90" not in gate
    assert "while {!_navalHvtReady" in gate
    assert '"Khe Sanh Alpha"' in gate
    assert '"Khe Sanh Bravo"' in gate
    assert '"Khe Sanh Charlie"' in gate
    assert "if (!_navalHvtReady) exitWith {" in gate
    assert "NAVALHVT|STARTUP_TIMEOUT" in gate
    assert '["WARNING", "Init_NavalHVT.sqf : pre-placed naval town logic(s) not found' in gate
    assert "Call WFBE_CO_FNC_LogContent;" in gate
    assert source.index("_navalHvtDeadline") < source.index("//--- FIND PRE-PLACED TOWN LOGICS")


def test_naval_hvt_startup_contract_is_mirrored() -> None:
    digest = (ROOT / TERRAINS[0] / NAVAL_HVT).read_bytes()
    for terrain in TERRAINS[1:]:
        assert (ROOT / terrain / NAVAL_HVT).read_bytes() == digest


if __name__ == "__main__":
    test_naval_hvt_does_not_treat_empty_town_census_as_ready()
    test_naval_hvt_waits_for_all_named_carrier_logics_with_deadline()
    test_naval_hvt_startup_contract_is_mirrored()
    print("naval HVT startup readiness regression checks passed")
