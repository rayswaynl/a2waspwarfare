"""Contracts for bounded town-AI empty-position probes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
TOWN_AI = "Server/FSM/server_town_ai.sqf"


def _read(mission: str, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def test_town_ai_uses_the_shared_optional_probe_budget() -> None:
    for mission in MISSIONS:
        source = _read(mission, TOWN_AI)
        assert "[_position, 50, 256] call WFBE_CO_FNC_GetEmptyPosition;" in source


def test_town_ai_mirrors_are_byte_identical() -> None:
    contents = [(ROOT / mission / TOWN_AI).read_bytes() for mission in MISSIONS]
    assert contents[0] == contents[1] == contents[2]
