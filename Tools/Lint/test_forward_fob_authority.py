from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REQUEST = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "PVFunctions"
    / "RequestForwardFOB.sqf"
)


def test_forward_fob_server_binds_request_to_live_repair_truck_and_server_target():
    source = REQUEST.read_text(encoding="utf-8-sig")

    assert (
        'if (!((typeName _truck) in ["OBJECT"]) || {isNull _truck} || {!alive _truck}) exitWith'
        in source
    )
    assert (
        '(typeOf _truck) in (missionNamespace getVariable [Format ["WFBE_%1REPAIRTRUCKS", str _side], []])'
        in source
    )
    assert 'if (side _truck != _side) exitWith' in source
    assert (
        'if ((_player distance _truck) > (missionNamespace getVariable ["WFBE_C_FOB_BUILD_RANGE", 30])) exitWith'
        in source
    )
    assert '_dir = getDir _truck;' in source
    assert '_pos = _truck modelToWorld [0, (missionNamespace getVariable ["WFBE_C_FOB_BUILD_DIST", 22]), 0];' in source
