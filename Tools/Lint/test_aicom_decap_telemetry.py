"""Contracts for truthful AICOM DECAP state telemetry."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = "Server/AI/Commander/AI_Commander_Decapitate.sqf"


def _read(mission: str) -> str:
    return (ROOT / mission / RELATIVE).read_text(encoding="utf-8-sig")


def test_committed_state_overrides_stale_arm_gate_reason() -> None:
    for mission in MISSIONS:
        source = _read(mission)
        override = 'if (_state == "COMMITTED") then {_gateReason = "committed"};'
        assert override in source
        assert source.index(override) < source.index(
            '_logik setVariable ["wfbe_aicom2_decap_streak"'
        )


def test_decap_telemetry_still_emits_the_gate_field() -> None:
    for mission in MISSIONS:
        source = _read(mission)
        telemetry = source[source.index('diag_log ("AICOM2|v1|DECAP|') :]
        assert '+ "|gate=" + _gateReason' in telemetry


def test_decap_mirrors_are_byte_identical() -> None:
    contents = [
        (ROOT / mission / RELATIVE).read_bytes()
        for mission in MISSIONS
    ]
    assert contents[0] == contents[1] == contents[2]
