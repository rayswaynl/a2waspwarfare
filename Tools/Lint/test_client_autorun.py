from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (CH / relative).read_text(encoding="utf-8")


def test_autorun_contract():
    constants = read("Common/Init/Init_CommonConstants.sqf")
    client_init = read("Client/Init/Init_Client.sqf")
    respawn = read("Client/Functions/Client_OnRespawnHandler.sqf")
    autorun = read("Client/Functions/Client_AutoRun.sqf")

    assert "WFBE_C_CLIENT_AUTORUN = 1" in constants
    assert 'Client\\Functions\\Client_AutoRun.sqf' in client_init
    assert "findDisplay 46" in client_init
    assert "WFBE_CL_FNC_AutoRunAttach" in client_init
    assert "WFBE_CL_FNC_AutoRunAttach" in respawn

    assert "displayAddEventHandler [\"KeyDown\"" in autorun
    assert "_this call WFBE_CL_FNC_AutoRunKeyDown" in autorun
    assert "false" in autorun
    assert "diag_tickTime" in autorun
    assert "<= 0.3" in autorun
    assert "_key == 17" in autorun
    assert "_key in [17,30,31,32]" in autorun
    assert 'playMoveNow "AmovPercMrunSlowWrflDf"' in autorun
    assert "switchMove \"\"" in autorun
    assert "vehicle player" in autorun
    assert "getDammage player" in autorun
    assert 'lifeState player == "UNCONSCIOUS"' in autorun
    assert "surfaceIsWater (getPos player)" in autorun
    assert "stance player" in autorun
    assert "dialog" in autorun
    assert "alive player" in autorun


if __name__ == "__main__":
    test_autorun_contract()
    print("client autorun contract: PASS")
