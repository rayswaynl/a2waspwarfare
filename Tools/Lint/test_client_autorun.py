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

    # The KeyDown handler is attached ONCE in Init_Client.sqf (display 46 persists
    # across respawn) rather than re-added by Client_AutoRun.sqf on every respawn.
    assert "displayAddEventHandler [\"KeyDown\"" in client_init
    assert "_this call WFBE_CL_FNC_AutoRunKeyDown" in client_init
    assert "displayAddEventHandler [\"KeyDown\"" not in autorun
    assert "WFBE_CL_VAR_AutoRunDisplay" not in autorun
    assert "displayRemoveEventHandler" not in autorun

    # Bindable custom keybind (engine-native User12 action slot) replaces the old
    # hardcoded double-tap-W detection, which thrashed on A2's KeyDown auto-repeat.
    assert 'actionKeys "User12"' in autorun
    assert "WFBE_CL_VAR_AutoRunLastToggle" in autorun
    assert ">= 0.4" in autorun
    assert "_lastW" not in autorun
    assert "_key == 17" not in autorun

    assert "false" in autorun
    assert "diag_tickTime" in autorun
    assert "_key in [17,30,31,32]" in autorun
    assert 'playMoveNow "AmovPercMrunSlowWrflDf"' in autorun
    assert 'playMoveNow "AmovPercMstpSlowWrflDnon"' in autorun
    assert "animationState player" in autorun
    assert 'toArray "amovperc"' in autorun
    assert 'currentWeapon player == primaryWeapon player' in autorun
    assert 'primaryWeapon player != ""' in autorun
    assert 'toArray "wrfl"' in autorun
    assert "getPos player" in autorun
    assert "distance _progressAnchor" in autorun
    assert "0.5" in autorun
    assert "1.5" in autorun
    assert "vehicle player" in autorun
    assert "getDammage player" in autorun
    assert 'lifeState player == "UNCONSCIOUS"' in autorun
    assert "surfaceIsWater (getPos player)" in autorun
    assert "dialog" in autorun
    assert "alive player" in autorun
    assert "stance player" not in autorun
    assert "switchMove" not in autorun


def test_stance_is_registered_as_an_a2_forbidden_command():
    linter = (ROOT / "Tools/Lint/check_sqf.py").read_text(encoding="utf-8")
    assert '"stance"' in linter


if __name__ == "__main__":
    test_autorun_contract()
    test_stance_is_registered_as_an_a2_forbidden_command()
    print("client autorun contract: PASS")
