/*
	File: Common_RealPlayers.sqf
	Author: WASP Warfare
	Description: Returns living human players, excluding registered and known headless-client bodies.
	Parameters:
		0 - optional side filter (SIDE), or BOOLEAN to exclude CIVILIAN players
	Returns: ARRAY
	A2-OA-1.64 safe: playableUnits / isPlayer / alive / side / name / lazy && {} and || {} only.
*/
Private ["_side","_filter","_useSide","_excludeCivilian","_hcUnits","_players"];

_useSide = false;
_excludeCivilian = false;
if (count _this > 0) then {
	_filter = _this select 0;
	if (typeName _filter == "BOOL") then {
		_excludeCivilian = _filter;
	} else {
		_useSide = true;
		_side = _filter;
	};
};

_hcUnits = [];
{
	if (!isNull _x) then {
		{_hcUnits set [count _hcUnits, _x]} forEach (units _x);
	};
} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

_players = [];
{
	if (alive _x && {isPlayer _x} && {!(_x in _hcUnits)} && {!_excludeCivilian || {(side _x) != civilian}} && {!((name _x) in ["HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3","HC"])} && {!_useSide || {side _x == _side}}) then {
		_players set [count _players, _x];
	};
} forEach playableUnits;

_players
