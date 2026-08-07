#!/usr/bin/env python3
"""Regression checks for server-authoritative paid camp-repair debit."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def _source(mission: Path, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8")


def _case(source: str, name: str) -> str:
    start = source.index(f'case "{name}": {{')
    end = source.find("\n\tcase ", start + 1)
    return source[start:] if end == -1 else source[start:end]


def test_paid_camp_repair_is_debited_only_by_the_server_after_final_validation() -> None:
    for mission in MISSIONS:
        truck_action = _source(mission, "Client/Action/Action_RepairCamp.sqf")
        engineer_action = _source(mission, "Client/Action/Action_RepairCampEngineer.sqf")
        client_result = _case(_source(mission, "Client/PVFunctions/HandleSpecial.sqf"), "repair-camp-result")
        server_case = _case(_source(mission, "Server/Functions/Server_HandleSpecial.sqf"), "repair-camp")

        assert "(-_price) Call WFBE_CL_FNC_ChangeClientFunds" not in truck_action
        assert "(-_price) Call WFBE_CL_FNC_ChangeClientFunds" not in engineer_action
        assert "WFBE_CL_FNC_ChangeClientFunds" not in client_result

        debit = server_case.index("[_repairTeam, -_repairPrice] Call WFBE_CO_FNC_ChangeTeamFunds")
        latch = server_case.index('_logic setVariable ["wfbe_camp_repairing", true, true]')
        create = server_case.index("createVehicle")
        assert latch < debit < create
        assert "_repairFunds >= _repairPrice" in server_case


if __name__ == "__main__":
    test_paid_camp_repair_is_debited_only_by_the_server_after_final_validation()
