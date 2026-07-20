"""Contract checks for the dark-by-default server-observable chat relay."""

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

    assert 'WFBE_C_CHAT_RELAY = 0' in constants
    assert 'WFBE_SE_FNC_ChatRelayEvent = Compile preprocessFileLineNumbers "Server\\Functions\\Server_ChatRelayEvent.sqf";' in server_init
    assert 'diag_log Format ["CHATRELAY|v1|%1|%2|%3"' in relay
    assert 'WFBE_C_CHAT_RELAY", 0' in relay
    assert "blocked-pending-BE" in relay
    assert 'addPublicVariableEventHandler' not in relay
    assert 'publicVariableServer' not in relay

    for relative in (
        "Server/Functions/Server_OnPlayerConnected.sqf",
        "Server/Functions/Server_OnPlayerDisconnected.sqf",
        "Server/PVFunctions/RequestOnUnitKilled.sqf",
        "Server/FSM/server_town.sqf",
        "Server/Functions/Server_LogGameEnd.sqf",
    ):
        text = read(CH / relative)
        assert "WFBE_SE_FNC_ChatRelayEvent" in text, relative

    for relative in (
        "Common/Init/Init_CommonConstants.sqf",
        "Server/FSM/server_town.sqf",
        "Server/Functions/Server_ChatRelayEvent.sqf",
        "Server/Functions/Server_LogGameEnd.sqf",
        "Server/Functions/Server_OnPlayerConnected.sqf",
        "Server/Functions/Server_OnPlayerDisconnected.sqf",
        "Server/Init/Init_Server.sqf",
        "Server/PVFunctions/RequestOnUnitKilled.sqf",
    ):
        hashes = {(root / relative).read_bytes() for root in (CH, TK, ZG)}
        assert len(hashes) == 1, relative


if __name__ == "__main__":
    main()
