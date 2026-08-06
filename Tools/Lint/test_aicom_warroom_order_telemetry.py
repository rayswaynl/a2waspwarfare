"""Contract for per-team war-room order telemetry."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = "Server/AI/Commander/AI_Commander_Execute.sqf"


def _read(mission: str) -> str:
    return (ROOT / mission / RELATIVE).read_text(encoding="utf-8-sig")


def test_war_room_order_records_team_identity() -> None:
    for mission in MISSIONS:
        source = _read(mission)
        assert '"AICOM2|v1|ORDER|war-room-task|"' in source
        assert '"|team=" + (str _team) + "|mode="' in source


def test_war_room_order_keeps_one_log_per_committed_change() -> None:
    for mission in MISSIONS:
        source = _read(mission)
        assert source.count('AICOM2|v1|ORDER|war-room-task|') == 1
        assert 'if (_changed) then {' in source


def test_execute_mirrors_are_byte_identical() -> None:
    contents = [(ROOT / mission / RELATIVE).read_bytes() for mission in MISSIONS]
    assert contents[0] == contents[1] == contents[2]
