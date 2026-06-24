Private ['_amount','_change','_currentSupply','_side','_maxSupplyLimit','_reason','_includeStagnation'];

_side = _this select 0;
_amount = _this select 1;
_includeStagnation = false;
_reason = "ERROR! No reason specified. This should not happen! Check logs.";

if (count _this > 3) then {
	_includeStagnation = _this select 3;
};

if (count _this > 3) then {
	_reason = _this select 2;
};

if (_amount > 0 && _includeStagnation) then {
	_amount = [_amount, _side] call WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers;
};

//--- B66: removed dead clamp arithmetic (_maxSupplyLimit/_currentSupply/_change). It was never
//--- consumed — only the temp-channel publish below matters; the server-side handler in
//--- Server_ChangeSideSupply.sqf recomputes + clamps the authoritative value.

missionNamespace setVariable [format ["wfbe_supply_temp_%1", _side], [_side, _amount, _reason]];

publicVariableServer format ["wfbe_supply_temp_%1", _side];

// (_side Call WFBE_CO_FNC_GetSideLogic) setVariable ["wfbe_supply", _change, true];