"""Contracts for the air-envelope sweep's epoch-based dedupe."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = "Common/Functions/Common_AICOM_SmallArmsAirEnvelope.sqf"


def _read(mission: str) -> str:
    return (ROOT / mission / RELATIVE).read_text(encoding="utf-8-sig")


def test_each_mirror_uses_a_sweep_epoch_for_local_dedupe() -> None:
    for mission in MISSIONS:
        source = _read(mission)
        assert '"WFBE_AIRENV_SWEEP_ID"' in source
        assert 'getVariable ["WFBE_airenv_seen", -1]' in source
        assert 'setVariable ["WFBE_airenv_seen", _sweepId, false]' in source
        assert 'if ((typeName _seenEpoch) != "SCALAR") then {' in source
        assert '[_team, _range, _seen, _sweepId]' in source


def test_epoch_dedupe_removes_the_per_unit_clear_pass() -> None:
    for mission in MISSIONS:
        source = _read(mission)
        assert 'setVariable ["WFBE_airenv_seen", false, false]' not in source
        assert "_sweepId    = (missionNamespace getVariable [\"WFBE_AIRENV_SWEEP_ID\", 0]) + 1;" in source


def test_airenvelope_mirrors_are_byte_identical() -> None:
    contents = [
        (ROOT / mission / RELATIVE).read_bytes()
        for mission in MISSIONS
    ]
    assert contents[0] == contents[1] == contents[2]
