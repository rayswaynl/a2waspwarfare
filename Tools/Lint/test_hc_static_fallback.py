"""Contracts for fail-fast HC static-defense fallback timing."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
HANDLE_DEFENSE = "Server/Functions/Server_HandleDefense.sqf"


def _read(mission: str, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def test_static_defense_uses_delegate_return_to_choose_grace_window() -> None:
    for mission in MISSIONS:
        source = _read(mission, HANDLE_DEFENSE)
        assert '"_delegated"' in source
        assert "_delegated = [_side, _groups, _positions, _team, _defense, _moveInGunner] Call WFBE_CO_FNC_DelegateAIStaticDefenceHeadless;" in source
        assert "[_defense,_side,_team, if (_delegated > 0) then {45} else {0}] Spawn" in source
        assert "if (_grace > 0) then {sleep 5};" in source
        assert "(_grace <= 0) || {(time > _deadline)}" in source


def test_static_defense_mirrors_are_byte_identical() -> None:
    contents = [(ROOT / mission / HANDLE_DEFENSE).read_bytes() for mission in MISSIONS]
    assert contents[0] == contents[1] == contents[2]
