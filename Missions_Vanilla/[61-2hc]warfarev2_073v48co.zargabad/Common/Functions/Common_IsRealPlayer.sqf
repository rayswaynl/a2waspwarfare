/*
	Common_IsRealPlayer.sqf
	Returns true for a player-controlled body that is not an HC body or the dedicated caster.
	A2-OA-1.64 safe: object getVariable, isPlayer, name, missionNamespace getVariable,
	array membership, and lazy && {} only.
*/
Private ["_unit","_hcNames","_hcGroups","_hcGroup","_excluded"];

if (count _this < 1) exitWith {false};
_unit = _this select 0;
if ((typeName _unit) != "OBJECT" || {isNull _unit} || {!isPlayer _unit}) exitWith {false};
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_CASTER_SLOT", 0]) > 0 && {(_unit getVariable ["WFBE_C_SPECTATOR_CASTER_SLOT", 0]) > 0}) exitWith {false};

_hcNames = missionNamespace getVariable ["WFBE_C_HC_NAMES", ["HC","HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3","HC-AI-Control-4"]];
if ((typeName _hcNames) != "ARRAY") then {_hcNames = ["HC","HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3","HC-AI-Control-4"]};
if ((name _unit) in _hcNames) exitWith {false};

_hcGroups = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
if ((typeName _hcGroups) != "ARRAY") then {_hcGroups = []};
_excluded = false;
{
	_hcGroup = _x;
	if (!isNull _hcGroup && {_unit in (units _hcGroup)}) then {_excluded = true};
} forEach _hcGroups;

!_excluded
