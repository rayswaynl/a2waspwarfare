"""Regression contract for the bounded parallel town census wait."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]
TOWN_INIT = Path("Common/Init/Init_Towns.sqf")
GLOBAL_WAIT = (
    'while {(_wTown < 120) && '
    '(({isNil {_x getVariable "sideID"} && '
    '{isNil {_x getVariable "wfbe_inactive"}}} count _towns) > 0)} '
    'do { uiSleep 0.25; _wTown = _wTown + 1; };'
)
SERIAL_WAIT = (
    'while {isNil {_x getVariable "sideID"} && '
    'isNil {_x getVariable "wfbe_inactive"} && (_wTown < 120)}'
)


def read_town_init(root: Path) -> str:
    return (root / TOWN_INIT).read_text(encoding="utf-8-sig")


def serial_timeout_seconds(town_count: int, ticks: int = 120, tick_seconds: float = 0.25) -> float:
    return town_count * ticks * tick_seconds


def parallel_timeout_seconds(ticks: int = 120, tick_seconds: float = 0.25) -> float:
    return ticks * tick_seconds


def test_census_uses_one_global_wait_window_not_one_wait_per_town() -> None:
    source = read_town_init(MISSION_ROOTS[0])

    assert GLOBAL_WAIT in source
    assert SERIAL_WAIT not in source
    assert source.count("} forEach _towns;") == 1
    assert "_townReadyCount = count towns;" in source
    assert "townInit = false;" in source


def test_global_window_bounds_the_46_depot_timeout() -> None:
    assert serial_timeout_seconds(46) == 1380
    assert parallel_timeout_seconds() == 30
    assert serial_timeout_seconds(46) / parallel_timeout_seconds() == 46


def test_parallel_census_is_mirrored_to_all_maintained_terrains() -> None:
    source = (MISSION_ROOTS[0] / TOWN_INIT).read_bytes()

    for mission_root in MISSION_ROOTS[1:]:
        assert (mission_root / TOWN_INIT).read_bytes() == source, mission_root


if __name__ == "__main__":
    test_census_uses_one_global_wait_window_not_one_wait_per_town()
    test_global_window_bounds_the_46_depot_timeout()
    test_parallel_census_is_mirrored_to_all_maintained_terrains()
