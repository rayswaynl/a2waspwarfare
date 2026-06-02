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

_maxSupplyLimit = missionNameSpace getvariable "WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT";

_currentSupply = (_side) Call GetSideSupply;
if (isNil '_currentSupply') then {_currentSupply = 0};
_change = _currentSupply + _amount;
if (_change < 0) then {_change = _currentSupply - _amount};
if (_change >= _maxSupplyLimit) then {_change = _maxSupplyLimit};

missionNamespace setVariable [format ["wfbe_supply_temp_%1", _side], [_side, _amount, _reason]];

publicVariableServer format ["wfbe_supply_temp_%1", _side];

// (_side Call WFBE_CO_FNC_GetSideLogic) setVariable ["wfbe_supply", _change, true];