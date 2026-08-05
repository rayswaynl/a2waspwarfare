Private["_logik","_side","_value","_teams"];

_side = _this select 0;
_value = _this select 1;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Guard: forEach nil throws in A2-OA (count nil is safe 0; forEach is not). A broken/empty
//--- side roster must not abort the vote-start path that called us.
_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") then {_teams = []};
if (typeName _teams != "ARRAY") exitWith {};

{
	if (!isNull _x) then {
		if ((_x getVariable "wfbe_vote") != _value) then {_x setVariable ["wfbe_vote", _value, true]};
	};
} forEach _teams;