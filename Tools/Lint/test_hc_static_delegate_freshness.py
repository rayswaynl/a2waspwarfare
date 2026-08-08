"""Contracts for freshness parity between HC picker and static-defense fanout."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
PICKER = "Server/Functions/Server_PickLeastLoadedHC.sqf"
DELEGATE = "Server/Functions/Server_DelegateAIStaticDefenceHeadless.sqf"


def _read(mission: str, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def test_static_defense_round_robin_uses_picker_freshness_contract() -> None:
    picker_snippets = (
        'WFBE_HCFPS_REG',
        'Format ["HC-%1", netId (leader _x)]',
        'if ((time - (_slot select 2)) <= 150) then {_fresh = true};',
    )
    for mission in MISSIONS:
        picker = _read(mission, PICKER)
        delegate = _read(mission, DELEGATE)
        for snippet in picker_snippets:
            assert snippet in picker
            assert snippet in delegate


def test_static_defense_mirrors_are_byte_identical() -> None:
    contents = [(ROOT / mission / DELEGATE).read_bytes() for mission in MISSIONS]
    assert contents[0] == contents[1] == contents[2]
