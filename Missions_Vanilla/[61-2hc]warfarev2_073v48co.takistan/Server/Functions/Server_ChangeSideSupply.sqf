WFBE_SE_FNC_HandleSideSupplyChange = {
	Private ['_amount','_change','_channel','_cmdName','_cmdTeam','_currentSupply','_event','_expectedSide','_maxSupplyLimit','_payload','_reason','_side'];

	_event = _this select 0;
	_expectedSide = _this select 1;
	_channel = _event select 0;
	_payload = _event select 1;

	if (typeName _payload != "ARRAY") exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected malformed side-supply payload on %1 (type %2): %3.", _channel, typeName _payload, _payload]] call WFBE_CO_FNC_LogContent;
	};

	if (count _payload < 3) exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected short side-supply payload on %1: %2.", _channel, _payload]] call WFBE_CO_FNC_LogContent;
	};

	_side = _payload select 0;
	_amount = _payload select 1;
	_reason = _payload select 2;

	if (typeName _side != "SIDE") exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply payload on %1 with invalid side type %2: %3.", _channel, typeName _side, _payload]] call WFBE_CO_FNC_LogContent;
	};

	if (_side != _expectedSide) exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply channel mismatch on %1. Payload side: %2.", _channel, _side]] call WFBE_CO_FNC_LogContent;
	};

	if (typeName _amount != "SCALAR") exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply payload on %1 with invalid amount type %2: %3.", _channel, typeName _amount, _payload]] call WFBE_CO_FNC_LogContent;
	};

	if (typeName _reason != "STRING") then {_reason = str _reason};
	if (_reason == "") then {_reason = "No reason provided for supply value update! This might indicate a malicious supply update request. Check stuff if you see this message."};
	_maxSupplyLimit = missionNameSpace getvariable "WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT";

	_currentSupply = (_side) Call GetSideSupply;
	if (isNil '_currentSupply') then {_currentSupply = 0};
	_change = _currentSupply + _amount;
	if (_change < 0) then {_change = 0}; //--- B66: floor supply at 0 on overdraw (was windfall bug: _currentSupply - _amount).
	if (_change > _maxSupplyLimit) then {_change = _maxSupplyLimit};

	// (_side Call WFBE_CO_FNC_GetSideLogic) setVariable ["wfbe_supply", _change, true];

	_cmdTeam = (_side) call WFBE_CO_FNC_GetCommanderTeam;
	_cmdName = "AI/None";
	if (!isNull _cmdTeam) then {_cmdName = name leader _cmdTeam};
	["INFORMATION", format ["Server_ChangeSideSupply.sqf: Changing supply value of team %1 with value: %2. New supply value for team: %3. Reason: %4 - Current commander of team: %5.", _side, _amount, _change, _reason, _cmdName]] call WFBE_CO_FNC_LogContent;

	missionNamespace setVariable [format ["wfbe_supply_%1", str _side],_change];

	publicVariable format ["wfbe_supply_%1", _side];

};

"wfbe_supply_temp_west" addPublicVariableEventHandler {
	[_this, west] Call WFBE_SE_FNC_HandleSideSupplyChange;
};

"wfbe_supply_temp_resistance" addPublicVariableEventHandler {
	//--- B67 [guer-side-supply]: wire GUER (resistance) side-supply; mirrors west/east. Additive plumbing, no-op until something credits GUER supply, does not touch west/east behavior.
	[_this, resistance] Call WFBE_SE_FNC_HandleSideSupplyChange;
};

"wfbe_supply_temp_east" addPublicVariableEventHandler {
	[_this, east] Call WFBE_SE_FNC_HandleSideSupplyChange;
};
