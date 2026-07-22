/*
	Quietly retire one local AI commander team after a validated commander disband.
	The server owns validation and routes explicit requests to the leader owner; this
	function owns only local deletion. It deliberately retains the combat veto.
*/

Private ["_team","_leader","_units","_vehicles","_vehicle","_sideID","_cmd"];

if (count _this < 1) exitWith {false};
_team = _this select 0;
if (isNull _team) exitWith {false};
_leader = leader _team;
if (isNull _leader || {!local _leader} || {behaviour _leader == "COMBAT"}) exitWith {false};

_sideID = (side _team) Call WFBE_CO_FNC_GetSideID;
_cmd = _team getVariable "wfbe_aicom_disband_cmd";
if (isNil "_cmd") then {_cmd = false};
_units = +(units _team);
_vehicles = [];
{
	if (!isNull _x) then {
		_vehicle = vehicle _x;
		if (_vehicle != _x && {!(_vehicle in _vehicles)}) then {_vehicles = _vehicles + [_vehicle]};
	};
} forEach _units;

{if (!isNull _x && {local _x} && {!isPlayer _x}) then {["aicom-retire-unit", _x, Format ["cmd=%1", _cmd]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x}} forEach _units;
{
	if (!isNull _x && {local _x} && {({isPlayer _x} count (crew _x)) == 0}) then {["aicom-retire-hull", _x, Format ["cmd=%1", _cmd]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x};
} forEach _vehicles;

diag_log ("AICOMSTAT|v1|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|TEAM_RETIRE_LOCAL|quiet-delete");
if (isServer) then {
	["aicom-team-ended", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-ended", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};
if (!isNull _team) then {deleteGroup _team};
true
