"""Regression contract for paid AICOM transport-heli requisitions.

HC-owned commander teams run their order loop locally, so the server must
authorise and charge the request while the owning HC creates the approved
transport with the normal CreateTeam compositor.  This suite is structural:
an authorised test-server run is still required to prove engine locality and
flight behaviour.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def test_missing_airlift_requests_a_server_paid_transport_and_local_append() -> None:
    for mission in MISSIONS:
        runner = (ROOT / mission / "Common/Functions/Common_RunCommanderTeam.sqf").read_text(
            encoding="utf-8-sig"
        )
        producer = (ROOT / mission / "Server/AI/Commander/AI_Commander_Produce.sqf").read_text(
            encoding="utf-8-sig"
        )

        assert 'if (isNull _amHeli) then {' in runner
        assert 'wfbe_aicom_airlift_req' in runner
        assert 'wfbe_aicom_airlift_grant' in runner
        assert 'Call WFBE_CO_FNC_CreateTeam' in runner
        assert 'wfbe_aicom_airlift_req' in producer
        assert 'wfbe_aicom_airlift_grant' in producer
        assert 'Call GetAICommanderFunds' in producer
        assert 'Call ChangeAICommanderFunds' in producer
        assert 'Call WFBE_CO_FNC_IsUnitUnlocked' in producer


def test_transport_requisition_reserves_existing_ai_and_air_budgets() -> None:
    for mission in MISSIONS:
        producer = (ROOT / mission / "Server/AI/Commander/AI_Commander_Produce.sqf").read_text(
            encoding="utf-8-sig"
        )

        # PR #1854 (staging wave 2026-08-02): airlift crew-cap cost now matches the seats actually
        # spawned (base 1 + gunner + commander) instead of the flat 3 + turret count.
        assert '_alCapCost = 1;' in producer
        assert 'if (_alHasGunner) then {_alCapCost = _alCapCost + 1};' in producer
        assert 'if (_alHasCommander) then {_alCapCost = _alCapCost + 1};' in producer
        assert 'if (_capRemaining >= _alCapCost)' in producer
        assert '_capRemaining = _capRemaining - _alCapCost;' in producer
        assert 'WFBE_C_AICOM_AIR_MAX_TOTAL' in producer
