#!/usr/bin/env python3
"""Regression contract for owner-routed timed mine cleanup."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def read(mission: Path, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def test_mine_cleaner_retries_non_local_objects_and_reports_dispatches() -> None:
    for mission in MISSIONS:
        source = read(mission, "Server/FSM/cleaners/mines_cleaner.sqf")
        assert "if (local _mineObj || {(missionNamespace getVariable [\"WFBE_C_TRASH_REMOTE_DELETE\", 0]) <= 0} || {(missionNamespace getVariable [\"WF_A2_Vanilla\", false])}) then {" in source
        assert "[\"cleanup-mine\", _mineObj]" in source
        assert "_keptMines = _keptMines + [_x];" in source
        assert "_perfDispatched" in source
        assert "dispatched:%4" in source


def test_mine_dispatch_is_allowlisted_and_owner_validated() -> None:
    for mission in MISSIONS:
        pvf = read(mission, "Client/Functions/Client_HandlePVF.sqf")
        receiver = read(mission, "Client/PVFunctions/HandleSpecial.sqf")
        drop_rpg = read(mission, "WASP/rpg_dropping/DropRPG.sqf")
        server_handler = read(mission, "Server/Functions/Server_HandleSpecial.sqf")
        assert '["RequestSpecial", ["register-mine", _bomb]] Call WFBE_CO_FNC_SendToServer;' in drop_rpg
        assert 'case "register-mine":' in server_handler
        assert '"cleanup-mine"' in pvf
        assert 'case "cleanup-mine":' in receiver
        assert "local _mineObj" in receiver
        assert 'getVariable ["wfbe_mine_reap", false]' in receiver
        assert 'typeOf _mineObj) in ["Mine","MineE","MineMine","MineMineE"]' in receiver


def test_mine_fix_is_byte_identical_across_maintained_mirrors() -> None:
    relative_files = (
        "Server/FSM/cleaners/mines_cleaner.sqf",
        "Client/Functions/Client_HandlePVF.sqf",
        "Client/PVFunctions/HandleSpecial.sqf",
    )
    for relative in relative_files:
        sources = [read(mission, relative) for mission in MISSIONS]
        assert sources[0] == sources[1] == sources[2], relative
