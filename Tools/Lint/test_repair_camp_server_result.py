#!/usr/bin/env python3
"""Regression checks for paid camp-repair server result and refund flow."""

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
    start = source.index(f'case "{name}"')
    end = source.find("\n\tcase ", start + 1)
    return source[start:] if end == -1 else source[start:end]


def test_paid_camp_repair_receives_a_server_result_before_the_client_settles() -> None:
    for mission in MISSIONS:
        server_pvf = _source(mission, "Server/PVFunctions/RequestSpecial.sqf")
        server_handler = _source(mission, "Server/Functions/Server_HandleSpecial.sqf")
        client_handler = _source(mission, "Client/PVFunctions/HandleSpecial.sqf")

        assert "_repairCampReply" in server_pvf
        assert '"repair-camp-result"' in server_pvf
        assert '"repair-camp-result"' in server_handler

        result_handler = _case(client_handler, "repair-camp-result")
        assert "WFBE_CL_FNC_ChangeClientFunds" in result_handler
        assert "WFBE_C_CAMPS_REPAIR_PRICE" in result_handler
