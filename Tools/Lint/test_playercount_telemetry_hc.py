from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (MISSION / relative).read_text(encoding="utf-8-sig")


def require(relative, needle):
    text = read(relative)
    if needle not in text:
        raise AssertionError(f"{relative} is missing {needle!r}")


def main():
    require("Common/Init/Init_Common.sqf", 'WFBE_CO_FNC_RealPlayers = Compile preprocessFileLineNumbers "Common\\Functions\\Common_RealPlayers.sqf";')
    require("Client/GUI/GUI_Menu.sqf", "count ([] call WFBE_CO_FNC_RealPlayers)")
    require("Server/FSM/server_victory_threeway.sqf", "count ([] call WFBE_CO_FNC_RealPlayers)")
    require("Server/Init/Init_Server.sqf", "count ([] call WFBE_CO_FNC_RealPlayers)")
    for relative in [
        "Server/Module/AntiStack/flushLoop.sqf",
        "Server/Module/AntiStack/mainLoop.sqf",
        "Server/Module/AntiStack/updateScoreInternal.sqf",
        "Common/Functions/Common_LogVehDelete.sqf",
    ]:
        require(relative, "forEach ([] call WFBE_CO_FNC_RealPlayers)")
    require("Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf", "count ([_side] call WFBE_CO_FNC_RealPlayers)")
    helper = read("Common/Functions/Common_RealPlayers.sqf")
    for needle in ["alive _x", "isPlayer _x", "WFBE_HEADLESSCLIENTS_ID", "HC-AI-Control-1"]:
        if needle not in helper:
            raise AssertionError(f"Common_RealPlayers.sqf is missing {needle!r}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"FAIL: {error}")
        sys.exit(1)
    print("PASS: player-count telemetry uses the real-player helper family")
