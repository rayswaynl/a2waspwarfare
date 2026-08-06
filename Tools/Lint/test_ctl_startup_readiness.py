#!/usr/bin/env python3
"""Regression checks for Commander Town Ledger startup readiness."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

CTL_SCRIPTS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Server/AI/Server_CmdTownLedger.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Server/AI/Server_CmdTownLedger.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Server/AI/Server_CmdTownLedger.sqf"
    ),
)

INIT_SERVER = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf"
)
INIT_JIP = Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/initJIPCompatible.sqf")


def test_ctl_waits_for_true_starting_mode_with_a_bounded_fail_closed_gate() -> None:
    init_server = (ROOT / INIT_SERVER).read_text(encoding="utf-8")
    init_jip = (ROOT / INIT_JIP).read_text(encoding="utf-8")
    ctl_start = init_server.index('[] execVM "Server\\AI\\Server_CmdTownLedger.sqf";')
    towns_start = init_server.index(
        'preprocessFile "Server\\Init\\Init_Towns.sqf"'
    )

    assert ctl_start < towns_start, "the regression depends on CTL starting before Init_Towns"
    assert "townInitServer = false;" in init_jip

    for relative_path in CTL_SCRIPTS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        assert 'waitUntil {!isNil "townInitServer"};' not in source
        gate_start = source.index("_ctlTownInitDeadline")
        gate = source[gate_start : source.index("sleep 5;", gate_start)]
        assert "missionNamespace getVariable [\"townInitServer\", false]" in gate
        assert "diag_tickTime + 90" in gate
        assert "while {" in gate
        assert "sleep 0.25" in gate
        assert "CTLSTAT|v1|BOTH|STARTUP_TIMEOUT" in gate
        assert "exitWith" in gate


if __name__ == "__main__":
    test_ctl_waits_for_true_starting_mode_with_a_bounded_fail_closed_gate()
