"""Contract checks for the server-observable chat relay.

wave0721 arming ruling (2026-07-21): WFBE_C_CHAT_RELAY flipped 0->1 (was dark-by-default).
"""

from pathlib import Path


ROOT = Path(__file__).parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
TK = ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan"
ZG = ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad"
CONSTANTS = CH / "Common" / "Init" / "Init_CommonConstants.sqf"
SERVER_INIT = CH / "Server" / "Init" / "Init_Server.sqf"
RELAY = CH / "Server" / "Functions" / "Server_ChatRelayEvent.sqf"


def read(path: Path) -> str:
    return path.read_text(encoding="cp1252")


def main() -> None:
    constants = read(CONSTANTS)
    server_init = read(SERVER_INIT)
    relay = read(RELAY)

    assert 'WFBE_C_CHAT_RELAY = 1' in constants
    assert 'WFBE_SE_FNC_ChatRelayEvent = Compile preprocessFileLineNumbers "Server\\Functions\\Server_ChatRelayEvent.sqf";' in server_init
    assert 'diag_log Format ["CHATRELAY|v1|%1|%2|%3"' in relay
    assert 'WFBE_C_CHAT_RELAY", 0' in relay
    assert "blocked-pending-BE" in relay
    assert "WFBE_CHATRELAY_EMITTED" in relay
    assert "WFBE_CHATRELAY_DROPPED" in relay
    assert "SUMMARY" in relay
    assert "_lastWindow >= 0" in relay
    assert ">= 19" in relay
    assert 'addPublicVariableEventHandler' not in relay
    assert 'publicVariableServer' not in relay

    for relative in (
        "Server/Functions/Server_BuildingKilled.sqf",
        "Server/Functions/Server_OnHQKilled.sqf",
        "Server/Functions/Server_OnPlayerConnected.sqf",
        "Server/Functions/Server_OnPlayerDisconnected.sqf",
        "Server/FSM/server_town.sqf",
        "Server/Functions/Server_LogGameEnd.sqf",
    ):
        text = read(CH / relative)
        assert "WFBE_SE_FNC_ChatRelayEvent" in text, relative
        if relative == "Server/Functions/Server_OnPlayerConnected.sqf":
            assert '["JOIN", _name, "player joined"]' in text
        if relative == "Server/Functions/Server_OnPlayerDisconnected.sqf":
            assert '["LEAVE", _name, "player left"]' in text

    assert "WFBE_SE_FNC_ChatRelayEvent" not in read(CH / "Server/PVFunctions/RequestOnUnitKilled.sqf")

    for relative in (
        "Common/Init/Init_CommonConstants.sqf",
        "Server/FSM/server_town.sqf",
        "Server/Functions/Server_ChatRelayEvent.sqf",
        "Server/Functions/Server_LogGameEnd.sqf",
        "Server/Functions/Server_BuildingKilled.sqf",
        "Server/Functions/Server_OnHQKilled.sqf",
        "Server/Functions/Server_OnPlayerConnected.sqf",
        "Server/Functions/Server_OnPlayerDisconnected.sqf",
        "Server/PVFunctions/RequestOnUnitKilled.sqf",
    ):
        hashes = {(root / relative).read_bytes() for root in (CH, TK, ZG)}
        assert len(hashes) == 1, relative

    # fix(mirrors) 8ab2fcba77 unified the per-terrain SET_MAP literal into one shared
    # worldName-conditional line, identical across CH/TK/ZG - pin the current shared form.
    set_map_line = (
        '["SET_MAP", if (worldName == "Takistan") then {2} else '
        '{if (worldName == "Zargabad") then {3} else {1}}] call WFBE_SE_FNC_CallDatabaseSetMap;'
    )
    for root in (CH, TK, ZG):
        text = read(root / "Server/Init/Init_Server.sqf")
        assert 'WFBE_SE_FNC_ChatRelayEvent = Compile preprocessFileLineNumbers "Server\\Functions\\Server_ChatRelayEvent.sqf";' in text
        assert set_map_line in text


if __name__ == "__main__":
    main()
