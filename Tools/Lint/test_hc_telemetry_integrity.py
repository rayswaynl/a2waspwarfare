#!/usr/bin/env python3
"""Regression contract for bounded, registered-HC telemetry."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
]


def read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


def test_hcfps_registry_prunes_invalid_and_expired_rows() -> None:
    sources = [read(root, "Server/PVFunctions/HCStat.sqf") for root in MISSION_ROOTS]

    for text in sources:
        assert 'if ((typeName _reg) != "ARRAY") then {_reg = []};' in text
        assert 'if ((typeName _row) == "ARRAY" && {(count _row) >= 3}' in text
        assert '{((time - (_row select 2)) <= 180)}' in text
        assert '_clean set [count _clean, _row];' in text
        assert 'missionNamespace setVariable ["WFBE_HCFPS_REG", _reg];' in text

    assert sources[0] == sources[1] == sources[2]


def test_waspscale_joins_fresh_telemetry_to_registered_live_hcs() -> None:
    sources = [
        read(root, "Server/AI/Commander/AI_Commander.sqf") for root in MISSION_ROOTS
    ]

    for text in sources:
        assert 'missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]' in text
        assert '(owner (leader _x)) > 2' in text
        assert 'Format ["HC-%1", netId _hcLeader]' in text
        assert '(_x select 0) in _hcLiveKeys' in text
        assert '((time - (_x select 2)) <= 120)' in text
        assert '(_x select 1) < _hcFps' in text
        assert '(_x select 1) > _hc2Fps' in text

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_hcfps_registry_prunes_invalid_and_expired_rows()
    test_waspscale_joins_fresh_telemetry_to_registered_live_hcs()
    print("HC telemetry integrity contract: PASS")
