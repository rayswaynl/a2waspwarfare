from pathlib import Path


ROOT = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def text(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


def test_uav_purchase_is_server_certified():
    client = text("Client/Module/UAV/uav.sqf")
    server = text("Server/Support/Support_UAV.sqf")
    assert '"uav","auth",player,_challenge' in client
    assert '"uav","purchase",sideJoined,_uav,clientTeam,player,_driver,_gunner,_cap select 0' in client
    assert '-12500 Call ChangePlayerFunds;' not in client
    assert '[_playerTeam, -12500] Call WFBE_CO_FNC_ChangeTeamFunds' in server
    assert 'UAV purchase capability expired.' in server


def test_uav_interfaces_do_not_dereference_missing_gunner_and_speed_uses_speed():
    vanilla = text("Client/Module/UAV/uav_interface.sqf")
    oa = text("Client/Module/UAV/uav_interface_oa.sqf")
    assert 'if (!isNull (gunner _uav)) then {(gunner _uav) removeweapon "nvgoggles"};' in vanilla
    assert 'if (!isNull (gunner _uav)) then {player remoteControl (gunner _uav)};' in vanilla
    assert 'if (_newspeed < 200) then {_newspeed = 200};' in vanilla
    assert 'if (!isNull (gunner _uav)) then {(gunner _uav) removeweapon "nvgoggles"};' in oa
    assert 'if (!isNull (gunner _uav)) then {player remoteControl (gunner _uav)};' in oa


if __name__ == "__main__":
    test_uav_purchase_is_server_certified()
    test_uav_interfaces_do_not_dereference_missing_gunner_and_speed_uses_speed()
