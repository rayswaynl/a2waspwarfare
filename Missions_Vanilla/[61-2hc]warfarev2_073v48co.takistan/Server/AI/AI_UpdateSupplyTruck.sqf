Private ["_AITrucks","_hq","_isDeployed","_logik","_maist","_side"];
_side = _this select 0;
//--- r54: defaulted max so a missing constant never makes count/compare throw.
_maist = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_SUPPLY_TRUCKS_MAX", 5];
if (_maist < 0) then {_maist = 0};

waitUntil {townInit};

sleep random 1;

while {!gameOver} do {
	sleep 60;
	//--- r54: side logic / truck registry may be nil before side init or after logic teardown.
	_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
	if (isNil "_logik" || {isNull _logik}) then {} else {
	_AITrucks = _logik getVariable "wfbe_ai_supplytrucks";
	if (isNil "_AITrucks" || {typeName _AITrucks != "ARRAY"}) then {_AITrucks = []};
	if (count _AITrucks < _maist) then {
		_isDeployed = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;
		_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
		//--- r54: never treat a null HQ object as a live deploy origin.
		if (_isDeployed && {!isNull _hq} && {alive _hq}) then {
			["INFORMATION", Format ["AI_UpdateSupplyTruck.sqf: [%1] Supply truck was created.", _side]] Call WFBE_CO_FNC_LogContent;
			[_side] ExecFSM "Server\FSM\supplytruck.fsm";
		};
	};
	};
};