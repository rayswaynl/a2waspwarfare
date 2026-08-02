"""Regression contract for bounded crater-cleaner maintenance cycles."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CRATER_CLEANERS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/cleaners/crater_cleaner.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/cleaners/crater_cleaner.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/FSM/cleaners/crater_cleaner.sqf"
    ),
)


def test_maintained_crater_cleaners_bound_each_cycle() -> None:
    for relative_path in CRATER_CLEANERS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        assert "WFBE_C_CRATER_CLEANER_MAX_PER_CYCLE" in source
        assert "_capacity = _maxPerCycle" in source
        assert source.count("if (_capacity <= 0) exitWith {};") == 2
        assert source.count("_capacity = _capacity - 1;") == 2
        assert "cap:%" in source
        assert "deferred:%" in source


def test_maintained_crater_cleaners_have_identical_source() -> None:
    sources = [
        (ROOT / relative_path).read_text(encoding="utf-8")
        for relative_path in CRATER_CLEANERS
    ]
    assert sources[0] == sources[1] == sources[2]
