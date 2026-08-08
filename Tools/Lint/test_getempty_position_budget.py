"""Contracts for bounded nested GetEmptyPosition probes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
EMPTY = "Common/Functions/Common_GetEmptyPosition.sqf"
BASE = "Server/AI/Commander/AI_Commander_Base.sqf"


def _read(mission: str, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def test_empty_position_accepts_a_bounded_optional_attempt_budget() -> None:
    for mission in MISSIONS:
        source = _read(mission, EMPTY)
        assert 'count _this > 2' in source
        assert '_maxAttempts = 1000' in source
        assert '_bandAttempts = floor (_maxAttempts / 4)' in source
        assert '_attempts < _maxAttempts' in source
        assert 'after %4 attempts' in source


def test_factory_road_settle_uses_the_outer_try_loop_as_the_retry_budget() -> None:
    for mission in MISSIONS:
        source = _read(mission, BASE)
        assert '[_cand, 8, 32] Call WFBE_CO_FNC_GetEmptyPosition' in source


def test_factory_offroad_probes_use_a_bounded_retry_budget() -> None:
    for mission in MISSIONS:
        source = _read(mission, BASE)
        assert '[_p, 30, 32] Call WFBE_CO_FNC_GetEmptyPosition' in source


def test_bounded_getempty_mirrors_are_byte_identical() -> None:
    for relative in (EMPTY, BASE):
        contents = [(ROOT / mission / relative).read_bytes() for mission in MISSIONS]
        assert contents[0] == contents[1] == contents[2]
