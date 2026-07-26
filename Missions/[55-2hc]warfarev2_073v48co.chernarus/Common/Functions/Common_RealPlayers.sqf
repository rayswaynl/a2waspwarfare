/*
	File: Common_RealPlayers.sqf
	Author: WASP Warfare
	Description: Returns living human players, excluding registered and known headless-client bodies.
	Parameters:
		0 - optional side filter (SIDE), or BOOLEAN to exclude CIVILIAN players
	Returns: ARRAY
	A2-OA-1.64 safe: playableUnits / isPlayer / alive / side / name / lazy && {} and || {} only.
*/
Private ["_side","_filter","_useSide","_excludeCivilian","_hcUnits","_hcGroup","_hcNames","_players"];

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

//--- WFBE_HEADLESSCLIENTS_ID holds GROUPS, not ids (Server_HandleSpecial.sqf:1798 stores `group _hc`), so
//--- isNull/units are the right operators. It is SERVER-ONLY state: on a headless client this always reads
//--- back [] and _hcNames below is the only HC exclusion that fires. Capture the outer _x before the inner
//--- forEach - it permanently rebinds _x. Kept symmetric with Common_RealPlayersNear.sqf.
_hcUnits = [];
{
	_hcGroup = _x;
	if (!isNull _hcGroup) then {
		{_hcUnits set [count _hcUnits, _x]} forEach (units _hcGroup);
	};
} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

//--- Single source of truth (Init_CommonConstants.sqf); complete-for-4-HCs literal fallback.
_hcNames = missionNamespace getVariable ["WFBE_C_HC_NAMES", ["HC","HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3","HC-AI-Control-4"]];
if ((typeName _hcNames) != "ARRAY") then {_hcNames = ["HC","HC-AI-Control-1","HC-AI-Control-2","HC-AI-Control-3","HC-AI-Control-4"]};

_players = [];
{
	if (alive _x && {isPlayer _x} && {!(_x in _hcUnits)} && {!_excludeCivilian || {(side _x) != civilian}} && {!((name _x) in _hcNames)} && {!_useSide || {side _x == _side}}) then {
		_players set [count _players, _x];
	};
} forEach playableUnits;

_players
