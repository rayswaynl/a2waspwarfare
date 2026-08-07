#!/usr/bin/env python3
"""Regression checks for the Zargabad KOTH startup readiness gate."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
KOTH_FILES = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_ZgKoth.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Init/Init_ZgKoth.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Init/Init_ZgKoth.sqf",
)


def test_koth_startup_gate_is_bounded_and_fail_closed() -> None:
    sources = [path.read_text(encoding="utf-8-sig") for path in KOTH_FILES]

    for path, source in zip(KOTH_FILES, sources):
        assert "waitUntil {townInit};" not in source, f"{path}: unbounded town wait remains"
        assert "_townInitDeadline = diag_tickTime + 420;" in source
        assert "sleep 0.25;" in source
        assert 'missionNamespace getVariable ["townInit", false]' in source
        assert 'missionNamespace getVariable ["WFBE_GameOver", false]' in source
        assert "ZGKOTH|STARTUP_TIMEOUT|" in source

        gate = source.index("_townInitDeadline = diag_tickTime + 420;")
        registration = source.index("] call WFBE_CO_FNC_RadiusHold_Register;")
        assert gate < registration
        assert source.index("ZGKOTH|STARTUP_TIMEOUT|", gate) < registration

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_koth_startup_gate_is_bounded_and_fail_closed()
    print("Zargabad KOTH startup readiness regression checks passed")
