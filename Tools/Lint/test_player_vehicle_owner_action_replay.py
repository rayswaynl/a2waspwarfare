"""Regression contract for player-bought vehicle lock actions after reconnect.

The buy-team tag is the mission's ownership record.  Lock/Unlock actions are
client-local, so an owner-team player who reconnects must receive them again
from the server's authoritative empty-vehicle queue.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def read(mission: Path, relative: str) -> str:
    return (mission / relative).read_text(encoding="utf-8-sig")


def test_buyer_lock_actions_require_the_current_owner_team() -> None:
    for mission in MISSIONS:
        source = read(mission, "Client/Functions/Client_BuildUnit.sqf")
        assert '(_target getVariable "wfbe_buyteam") == group player' in source


def test_reconnect_receiver_reinstalls_owner_team_actions_idempotently() -> None:
    for mission in MISSIONS:
        receiver = read(mission, "Client/PVFunctions/SetVehicleOwnerActions.sqf")
        assert '(_vehicle getVariable "wfbe_buyteam") != group player' in receiver
        assert 'wfbe_buyteam_unlock_aid' in receiver
        assert 'wfbe_buyteam_lock_aid' in receiver
        assert 'Client\\Action\\Action_ToggleLock.sqf' in receiver


def test_connected_owner_team_receives_its_bought_hulls_from_server_queue() -> None:
    for mission in MISSIONS:
        source = read(mission, "Server/Functions/Server_OnPlayerConnected.sqf")
        assert '"SetVehicleOwnerActions"' in source
        assert '_pvorVeh getVariable "wfbe_buyteam"' in source
        assert 'WF_Logic getVariable "emptyVehicles"' in source


def test_owner_action_receiver_is_registered() -> None:
    for mission in MISSIONS:
        source = read(mission, "Common/Init/Init_PublicVariables.sqf")
        assert '"SetVehicleOwnerActions"' in source
