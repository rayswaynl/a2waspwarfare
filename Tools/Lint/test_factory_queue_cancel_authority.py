from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_cancel_queue_is_a_server_transaction_with_a_targeted_result():
    client = (MISSION / "Client" / "Action" / "Action_CancelQueue.sqf").read_text(encoding="utf-8")
    handler_path = MISSION / "Server" / "PVFunctions" / "RequestCancelQueue.sqf"
    public_variables = (MISSION / "Common" / "Init" / "Init_PublicVariables.sqf").read_text(encoding="utf-8")

    assert '"RequestCancelQueue"' in public_variables
    assert handler_path.exists()
    handler = handler_path.read_text(encoding="utf-8")
    assert 'Call WFBE_CO_FNC_SendToServer' in client
    assert 'RequestCancelQueue' in client
    assert 'setVariable ["queu"' not in client
    assert 'setVariable ["queu_costs"' not in client
    assert 'setVariable ["queu_cpts"' not in client
    assert 'setVariable ["queu_labels"' not in client
    assert 'isNil {' in handler
    assert 'wfbe_cancel_queue_lock' in handler
    assert '"HandleSpecial"' in handler
    special = (MISSION / "Client" / "PVFunctions" / "HandleSpecial.sqf").read_text(encoding="utf-8")
    assert 'case "cancel-queue-result"' in special


def test_buy_menu_cancel_button_uses_the_server_transaction():
    buy_menu = (MISSION / "Client" / "GUI" / "GUI_Menu_BuyUnits.sqf").read_text(encoding="utf-8")
    cancel_block = buy_menu.split('if (MenuAction == 501) then {', 1)[1].split('//--- Player funds', 1)[0]

    assert '["RequestCancelQueue", [player, _closest, _type]] Call WFBE_CO_FNC_SendToServer;' in cancel_block
    assert 'setVariable ["queu"' not in cancel_block
    assert 'Call ChangePlayerFunds' not in cancel_block
