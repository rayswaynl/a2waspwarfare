#!/usr/bin/env python3
"""Regression checks for invalid player UID isolation in JIP identity state."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_invalid_uids_cannot_enter_uid_keyed_jip_state() -> None:
    for terrain in TERRAINS:
        root = ROOT / terrain
        request_join = (root / "Server/PVFunctions/RequestJoin.sqf").read_text(encoding="utf-8-sig")
        connected = (root / "Server/Functions/Server_OnPlayerConnected.sqf").read_text(encoding="utf-8-sig")
        disconnected = (root / "Server/Functions/Server_OnPlayerDisconnected.sqf").read_text(encoding="utf-8-sig")

        request_uid = request_join.index("_uid = getPlayerUID(_player);")
        request_keys = request_join.index("WFBE_JIP_USER%1_TEAM_JOINED", request_uid)
        request_guard = request_join.index('_uid == "0"', request_uid)
        assert request_guard < request_keys, f"{terrain}: RequestJoin writes UID 0 into JIP keys"

        connected_guard = connected.index("_uid == '0'")
        connected_keys = connected.index("WFBE_JIP_BODY_%1")
        assert connected_guard < connected_keys, f"{terrain}: connect resolver accepts UID 0"

        disconnected_guard = disconnected.index("_uid == '0'")
        disconnected_keys = disconnected.index("WFBE_JIP_USER%1")
        assert disconnected_guard < disconnected_keys, f"{terrain}: disconnect resolver mutates UID 0 state"


if __name__ == "__main__":
    test_invalid_uids_cannot_enter_uid_keyed_jip_state()
    print("player identity UID guard regression check passed")
