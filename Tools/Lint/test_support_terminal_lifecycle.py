"""Regression contracts for client vehicle service at round termination."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVICE_FILES = (
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRefuel.sqf",
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRearm.sqf",
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRepair.sqf",
)


def test_vehicle_service_workers_abort_terminal_waits_before_mutation() -> None:
    for path in SERVICE_FILES:
        source = path.read_text(encoding="utf-8-sig")

        assert "while {!gameOver && {!WFBE_GameOver}} do {" in source, path.name
        terminal_reset = "if (gameOver || {WFBE_GameOver}) then {_cts = 0};"
        assert terminal_reset in source, path.name
        assert source.index(terminal_reset) < source.index("if (_cts == 0 &&")
        assert (
            "if (_cts != 0 && {!gameOver} && {!WFBE_GameOver}) then {" in source
        ), path.name


def test_repair_terminal_abort_releases_the_in_progress_latch() -> None:
    source = SERVICE_FILES[2].read_text(encoding="utf-8-sig")

    assert (
        "if (gameOver || {WFBE_GameOver}) then {_cts = 0};" in source
    )
    assert 'if (!isNull _veh) then {_veh setVariable ["wfbe_repair_inProgress", false];};' in source


def test_rearm_and_refuel_workers_hold_and_release_per_vehicle_latches() -> None:
    for service, path in (("rearm", SERVICE_FILES[1]), ("refuel", SERVICE_FILES[0])):
        source = path.read_text(encoding="utf-8-sig")
        latch = f'"wfbe_{service}_inProgress"'

        assert f'_veh getVariable [{latch}, false]' in source, path.name
        assert f'_veh setVariable [{latch}, true];' in source, path.name
        assert f'if (!isNull _veh) then {{_veh setVariable [{latch}, false];}};' in source, path.name
