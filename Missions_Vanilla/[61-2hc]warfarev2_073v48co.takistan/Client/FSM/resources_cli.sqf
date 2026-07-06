private["_pside","_is","_ii","_income","_side","_supply"];

_pside = _this;

//--- JIP nil-guard: use 2-arg getVariable with defaults matching Init_CommonConstants.sqf.
_is = missionNamespace getVariable ["WFBE_C_ECONOMY_INCOME_SYSTEM", 3];
_ii = missionNamespace getVariable ["WFBE_C_ECONOMY_INCOME_INTERVAL", 60];

while {!gameOver} do {
	_income = 0;

	//--- Income Getter.
	{
		_side = (_x getVariable "sideID") Call GetSideFromID;
		_supply = _x getVariable ["supplyValue", 0];
		if (_side == _pside) then {_income = _income + (_supply / _is)};
	} forEach towns;

	//--- Only change the funds if needed.
	if (_income > 0) then {
		(_income) Call ChangePlayerFunds;
	};
	
	sleep _ii;
};