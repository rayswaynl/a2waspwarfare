#!/usr/bin/env python3
"""Regression contract for HC-local action-perform dispatches."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def read(mission: Path, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def test_hc_action_perform_dispatch_is_allowlisted_and_consumed() -> None:
    for mission in MISSIONS:
        pvf = read(mission, "Client/Functions/Client_HandlePVF.sqf")
        sender = read(mission, "Client/Action/Action_EjectCargo.sqf")
        receiver = read(mission, "Client/PVFunctions/HandleSpecial.sqf")

        assert '"action-perform"' in pvf
        assert '["action-perform", _x, "EJECT", _vehicle]' in sender
        assert 'case "action-perform": {_args spawn WFBE_CL_FNC_Perform_Action};' in receiver


def test_hc_action_perform_contract_is_byte_identical_across_maintained_mirrors() -> None:
    relative_files = (
        "Client/Functions/Client_HandlePVF.sqf",
        "Client/Action/Action_EjectCargo.sqf",
        "Client/PVFunctions/HandleSpecial.sqf",
    )
    for relative in relative_files:
        sources = [read(mission, relative) for mission in MISSIONS]
        assert sources[0] == sources[1] == sources[2], relative
