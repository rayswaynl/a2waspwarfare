"""Regression contract for the opt-in dropped-items spatial scan slices."""

from math import hypot
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
CONSTANTS = MISSION / "Common/Init/Init_CommonConstants.sqf"
CLEANER = MISSION / "Server/FSM/cleaners/droppeditems_cleaner.sqf"


def _sources() -> tuple[str, str]:
    return (
        CONSTANTS.read_text(encoding="utf-8-sig"),
        CLEANER.read_text(encoding="utf-8-sig"),
    )


def test_sliced_scan_is_opt_in_and_preserves_the_exact_legacy_query():
    constants, cleaner = _sources()

    assert "WFBE_C_DROPPEDITEMS_CLEANER_SLICED_SCAN = 0" in constants
    assert "WFBE_C_DROPPEDITEMS_CLEANER_SLICE_SLEEP = 0.05" in constants
    assert (
        '_scanSliced = (missionNamespace getVariable '
        '["WFBE_C_DROPPEDITEMS_CLEANER_SLICED_SCAN", 0]) > 0;'
    ) in cleaner
    assert '_scanItems = nearestObjects [_scanCentre, [_class], _scanRadius];' in cleaner


def test_sliced_scan_covers_the_map_in_deduplicated_cooperative_queries():
    _, cleaner = _sources()

    assert '_scanGrid = 3;' in cleaner
    assert 'for "_gridX" from 0 to (_scanGrid - 1) do {' in cleaner
    assert 'for "_gridY" from 0 to (_scanGrid - 1) do {' in cleaner
    assert (
        '_scanSliceRadius = sqrt ((_scanCellHalf * _scanCellHalf) + '
        '(_scanCellHalf * _scanCellHalf)) + 1;'
    ) in cleaner
    assert '_scanSlice = nearestObjects [_scanOrigin, [_class], _scanSliceRadius];' in cleaner
    assert 'if (!(_scanObject in _scanItems)) then {' in cleaner

    query = cleaner.index(
        '_scanSlice = nearestObjects [_scanOrigin, [_class], _scanSliceRadius];'
    )
    active_cut = cleaner.index('_scanActive = _scanActive + _scanSliceDt;', query)
    cooperative_sleep = cleaner.index('sleep _scanSliceSleep;', active_cut)
    assert query < active_cut < cooperative_sleep


def test_three_by_three_half_diagonal_circles_cover_supported_map_squares():
    _, cleaner = _sources()
    grid_match = re.search(r"_scanGrid\s*=\s*(\d+)\s*;", cleaner)
    assert grid_match
    grid = int(grid_match.group(1))
    assert grid == 3

    for map_size in (8192.0, 12800.0, 15360.0, 20500.0, 25600.0):
        cell = map_size / grid
        half = cell / 2
        radius = hypot(half, half) + 1
        origins = [
            (half + x * cell, half + y * cell)
            for x in range(grid)
            for y in range(grid)
        ]
        for x_step in range(31):
            for y_step in range(31):
                point = (map_size * x_step / 30, map_size * y_step / 30)
                assert min(hypot(point[0] - x, point[1] - y) for x, y in origins) <= radius


def test_audit_separates_active_work_from_scan_and_delete_pacing():
    _, cleaner = _sources()

    assert 'slices:%10;sliceMaxMs:%11' in cleaner
    capacity = cleaner.index('_capacity = _capacity - 1;')
    active_cut = cleaner.index(
        '_perfActive = _perfActive + (diag_tickTime - _perfItemStart);', capacity
    )
    delete_sleep = cleaner.index('sleep 0.5;', capacity)
    assert capacity < active_cut < delete_sleep
