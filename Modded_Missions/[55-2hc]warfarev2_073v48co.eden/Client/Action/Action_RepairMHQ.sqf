Private ["_currency","_currencySym","_currency_system","_hq","_repairPrice","_vehicle","_counter","_nextCount","_nextPrice"];

_vehicle = _this select 0;

_hq = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
if (alive _hq || (_hq distance _vehicle > 30)) exitWith {hint (localize "STR_WF_INFO_Repair_MHQ_None")};

//--- Is HQ already being fixed?
if (WFBE_Client_Logic getVariable "wfbe_hq_repairing") exitWith {hint (localize "STR_WF_INFO_Repair_MHQ_BeingRepaired")};

_currency_system = missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM";

switch (missionNamespace getVariable Format ['WFBE_C_BASE_HQ_REPAIR_COUNT_%1', sideJoined]) do {
    case 1: {
        missionNamespace setVariable [Format ['WFBE_C_BASE_HQ_REPAIR_PRICE_%1', sideJoined], missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_2ND'];
    };
    case 2: {
        missionNamespace setVariable [Format ['WFBE_C_BASE_HQ_REPAIR_PRICE_%1', sideJoined], missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_3RD'];
    };
};

if (missionNamespace getVariable Format ['WFBE_C_BASE_HQ_REPAIR_PRICE_%1', sideJoined] == (missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_3RD')) exitWith {hint Format [localize "STR_WF_INFO_MHQ_Repairs_Used"]};

_repairPrice = (missionNamespace getVariable Format ['WFBE_C_BASE_HQ_REPAIR_PRICE_%1', sideJoined]);
_currency = if (_currency_system == 0) then {(sideJoined) Call GetSideSupply} else {Call GetPlayerFunds};
_currencySym = if (_currency_system == 0) then {"S"} else {"$"};
if (_currency < _repairPrice) exitWith {hint Format [localize "STR_WF_INFO_Repair_MHQ_Funds",_currencySym,_repairPrice - _currency]};

if (_currency_system == 0) then {
	[sideJoined,-_repairPrice, "MHQ repaired.", false] Call ChangeSideSupply;
} else {
	-(_repairPrice) Call ChangePlayerFunds;
};

["RequestMHQRepair", sideJoined] Call WFBE_CO_FNC_SendToServer;

WF_Logic setVariable [Format ["%1MHQRepair",sideJoinedText],true,true];

_counter = missionNamespace getVariable Format ['WFBE_C_BASE_HQ_REPAIR_COUNT_%1', sideJoined];
missionNamespace setVariable [Format ['WFBE_C_BASE_HQ_REPAIR_COUNT_%1', sideJoined], _counter + 1];

_nextCount = _counter + 1;
if (_nextCount >= 3) then {
	hint Format [localize "STR_WF_INFO_Repair_MHQ_Repair", "-"];
} else {
	_nextPrice = [
		missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_1ST',
		missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_2ND',
		missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_3RD'
	] select _nextCount;
	hint Format [localize "STR_WF_INFO_Repair_MHQ_Repair", Format ["%1%2", _currencySym, _nextPrice]];
};
