from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_lock_actions_carry_explicit_intent_and_handler_uses_it():
    handler = (SOURCE / "Client" / "Action" / "Action_ToggleLock.sqf").read_text(encoding="utf-8")

    assert "_intent = (_this select 3) select 0;" in handler
    assert "_vehicle lock _intent;" in handler
    assert "if (locked _vehicle) then {false} else {true}" not in handler

    for relative in (
        "Client/PVFunctions/SetMHQLock.sqf",
        "Client/Module/CoIn/coin_interface.sqf",
        "Client/Functions/Client_BuildUnit.sqf",
        "Client/FSM/updateclient.sqf",
    ):
        text = (SOURCE / relative).read_text(encoding="utf-8")
        assert '"Client\\Action\\Action_ToggleLock.sqf", [false]' in text
        assert '"Client\\Action\\Action_ToggleLock.sqf", [true]' in text
