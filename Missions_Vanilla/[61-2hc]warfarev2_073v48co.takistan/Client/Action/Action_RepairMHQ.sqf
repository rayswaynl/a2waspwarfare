Private ["_currency","_currencySym","_currency_system","_hq","_repairPrice","_vehicle","_counter","_nextCount","_nextPrice"];

_vehicle = _this select 0;

_hq = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
if (alive _hq || (_hq distance _vehicle > 30)) exitWith {hint (localize "STR_WF_INFO_Repair_MHQ_None")};

//--- Is HQ already being fixed?
if (WFBE_Client_Logic getVariable "wfbe_hq_repairing") exitWith {hint (localize "STR_WF_INFO_Repair_MHQ_BeingRepaired")};

_currency_system = missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM";

if ((missionNamespace getVariable ["WFBE_C_HQ_REPAIR_SCALING", 1]) > 0) exitWith {
	private ["_scalingAvg185","_scalingRatio185","_repairCost185","_scalingCurr185","_scalingSym185"];
	_scalingAvg185 = if (isNil "WFBE_HQ_REPAIR_AVG_SEC") then {21600} else {WFBE_HQ_REPAIR_AVG_SEC};
	if (_scalingAvg185 <= 0) then {_scalingAvg185 = 21600};
	_scalingRatio185 = time / _scalingAvg185;
	if (_scalingRatio185 > 1) then {_scalingRatio185 = 1};
	_repairCost185 = round (7500 + 42000 * _scalingRatio185);
	_scalingCurr185 = if (_currency_system == 0) then {(sideJoined) Call GetSideSupply} else {Call GetPlayerFunds};
	_scalingSym185  = if (_currency_system == 0) then {"S"} else {"$"};
	if (_scalingCurr185 < _repairCost185) exitWith {hint Format [localize "STR_WF_INFO_Repair_MHQ_Funds", _scalingSym185, _repairCost185 - _scalingCurr185]};
	if (_currency_system == 0) then {
		[sideJoined, -_repairCost185, "MHQ repaired.", false] Call ChangeSideSupply;
	} else {
		-(_repairCost185) Call ChangePlayerFunds;
	};
	["RequestMHQRepair", sideJoined] Call WFBE_CO_FNC_SendToServer;
	WF_Logic setVariable [Format ["%1MHQRepair", sideJoinedText], true, true];
	_counter = missionNamespace getVariable Format ['WFBE_C_BASE_HQ_REPAIR_COUNT_%1', sideJoined];
	missionNamespace setVariable [Format ['WFBE_C_BASE_HQ_REPAIR_COUNT_%1', sideJoined], _counter + 1];
	hint Format [localize "STR_WF_INFO_Repair_MHQ_Repair", Format ["%1%2", _scalingSym185, _repairCost185]];
};


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

//--- LIVE next-repair price for the post-repair hint. _counter is the PRE-increment count, so the
//--- next repair uses index (_counter + 1). When that reaches the cap (>= 3) there is no further
//--- repair; show "-" here (the explicit cap message STR_WF_INFO_MHQ_Repairs_Used still fires on the
//--- next attempt at line 22). This hint computes the price live, unlike the spawn-time menu label.
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