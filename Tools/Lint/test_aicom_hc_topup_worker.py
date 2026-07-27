#!/usr/bin/env python3
"""Static contract for the HC attrition top-up/merge worker."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative_path: str) -> str:
    return (MISSION / relative_path).read_text(encoding="utf-8")


def test_hc_topup_worker_is_registered_and_uses_the_existing_hc_consumer_contract() -> None:
    worker_path = MISSION / "Server" / "AI" / "Commander" / "AI_Commander_HCTopUp.sqf"
    assert worker_path.is_file(), "HC top-up worker source must exist"

    worker = worker_path.read_text(encoding="utf-8")
    init_server = read("Server/Init/Init_Server.sqf")
    client_pvf = read("Client/Functions/Client_HandlePVF.sqf")
    constants = read("Common/Init/Init_CommonConstants.sqf")

    assert 'WFBE_SE_FNC_AI_Com_HCTopUp = Compile preprocessFileLineNumbers "Server\\AI\\Commander\\AI_Commander_HCTopUp.sqf";' in init_server
    assert 'wfbe_aicom_topup_req' in worker
    assert 'GetAICommanderFunds' in worker
    assert 'ChangeAICommanderFunds' in worker
    assert 'aicom-team-merge' in worker
    assert '"aicom-team-merge"' in client_pvf
    # Armed 2026-07-27 (owner go): both worker gates flipped from their shipped default-0.
    assert 'WFBE_C_AICOM_HC_TOPUP_ENABLE = 1' in constants
    assert 'WFBE_C_AICOM_HC_MERGE_ENABLE = 1' in constants


if __name__ == "__main__":
    test_hc_topup_worker_is_registered_and_uses_the_existing_hc_consumer_contract()
