Private['_amount','_team','_funds'];

_team = _this select 0;
_amount = _this select 1;

if (isNull _team) exitWith {};

_funds = _team getVariable "wfbe_funds";
if (isNil "_funds") then {_funds = 0};
_team setVariable ["wfbe_funds", _funds + _amount, true];
