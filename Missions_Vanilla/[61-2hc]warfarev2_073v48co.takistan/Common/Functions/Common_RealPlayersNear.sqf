/*
	File: Common_RealPlayersNear.sqf
	Author: WASP Warfare
	Description: Counts living human players near a position. Registered and known headless-client bodies are excluded.
	Parameters:
		0 - position (ARRAY)
		1 - radius (SCALAR)
		2 - optional side filter (SIDE), or BOOLEAN to exclude CIVILIAN players
	Returns: SCALAR
	A2-OA-1.64 safe: playableUnits / isPlayer / alive / side / name / lazy && {} and || {} only.
*/
Private ["_position","_radius","_side","_filter","_useSide","_excludeCivilian","_hcUnits","_hcGroup","_hcNames","_count"];

if ((typeName _this) != "ARRAY") exitWith {0};
if (count _this < 2) exitWith {0};
_position = _this select 0;
_radius = _this select 1;
if ((typeName _position) != "ARRAY" || {(count _position) < 2} || {(count _position) > 3}) exitWith {0};
if ((typeName (_position select 0)) != "SCALAR" || {(typeName (_position select 1)) != "SCALAR"}) exitWith {0};
if (count _position > 2 && {(typeName (_position select 2)) != "SCALAR"}) exitWith {0};
if ((typeName _radius) != "SCALAR" || {_radius <= 0}) exitWith {0};
_useSide = false;
_excludeCivilian = false;
if (count _this > 2) then {
	_filter = _this select 2;
	if (typeName _filter == "BOOL") then {
		_excludeCivilian = _filter;
	} else {
		_useSide = true;
		_side = _filter;
	};
};

//--- WFBE_HEADLESSCLIENTS_ID holds GROUPS, not ids (Server_HandleSpecial.sqf:1798 stores `group _hc`;
//--- Server_OnPlayerDisconnected.sqf:45 removes the same group), so isNull/units are the right operators.
//--- It is SERVER-ONLY state though: on a headless client this always reads back [] and _hcNames below is
//--- the only HC exclusion that actually fires. Capture the outer _x first - the inner forEach rebinds it.
_hcUnits = [];
{
	_hcGroup = _x;
	if (!isNull _hcGroup) then {
		{_hcUnits set [count _hcUnits, _x]} forEach (units _hcGroup);
	};
} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

//--- Single source of truth (Init_CommonConstants.sqf). The literal fallback is kept complete-for-4-HCs so
//--- a stripped-down constants file can never silently reintroduce the missing-HC4 veto bug.
_hcNames = missionNamespace getVariable ["WFBE_C_HC_NAMES", ["HC","HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3","HC-AI-Control-4"]];
if ((typeName _hcNames) != "ARRAY") then {_hcNames = ["HC","HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3","HC-AI-Control-4"]};

_count = 0;
{
	if (alive _x && {isPlayer _x} && {!(_x in _hcUnits)} && {!_excludeCivilian || {(side _x) != civilian}} && {!((name _x) in _hcNames)} && {(_x distance _position) < _radius} && {!_useSide || {side _x == _side}}) then {
		_count = _count + 1;
	};
} forEach playableUnits;

_count
