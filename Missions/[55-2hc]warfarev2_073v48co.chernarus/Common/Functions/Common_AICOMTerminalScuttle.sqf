//--- Common_AICOMTerminalScuttle.sqf (P1 stuck-lifecycle, flag WFBE_C_AICOM_TERMINAL_SCUTTLE default 0)
//--- HC-local one-shot visible scuttle for a terminally stuck AICOM team. Owner matrix ruling 2026-07-18:
//--- a visible scripted closure - crew dismounts, a short kneel "last stand" cue, hulls cook off via engine
//--- damage (setDammage 1: fire/smoke wreck, NO thrown-weapon/grenade entity is ever created), bodies and
//--- wrecks persist WFBE_C_AICOM_TERMINAL_WRECK_TTL seconds, then ONE bounded HC-local cleanup pass deletes
//--- them. Exactly-once is guarded by the caller (wfbe_aicom_scuttled); this script never re-arms anything.
//--- Spawned on the HC that owns the units: [_team, _vehicles, _sideID] Spawn WFBE_CO_FNC_AICOMTerminalScuttle.
private ["_team","_vehicles","_sideID","_units","_ttl","_wrecks"];
_team = _this select 0;
_vehicles = _this select 1;
_sideID = _this select 2;
_ttl = missionNamespace getVariable ["WFBE_C_AICOM_TERMINAL_WRECK_TTL", 180];
_units = +(units _team);
_wrecks = [];

//--- (1) visible warning cue: crews bail out, everyone kneels (scripted last stand - a player nearby SEES the
//--- closure instead of a silent vanish; there is intentionally no player-distance check at all).
{ if (!isNil "_x" && {!isNull _x} && {alive _x} && {local _x} && {vehicle _x != _x}) then { _x action ["getOut", vehicle _x] } } forEach _units;
uiSleep 4;
{ if (!isNil "_x" && {!isNull _x} && {alive _x} && {local _x} && {vehicle _x == _x}) then { _x playMove "AmovPknlMstpSrasWrflDnon" } } forEach _units;
uiSleep 3;

//--- (2) hull cook-off: engine damage only. Capture the outer element before the inner count (A2 rebind trap).
//--- Skip any hull a player boarded meanwhile (belt-and-braces; AICOM hulls are AI-crewed).
{
	private ["_rv"];
	_rv = _x;
	if (!isNil "_rv" && {!isNull _rv} && {local _rv} && {({isPlayer _x} count (crew _rv)) == 0}) then {
		_rv setDammage 1;
		_wrecks = _wrecks + [_rv];
	};
} forEach _vehicles;

//--- (3) infantry fold: the last stand ends. setDammage deaths have no killer unit, so no kill credit,
//--- no score event and no economy receipt can fire - nothing to double-pay.
{ if (!isNil "_x" && {!isNull _x} && {alive _x} && {local _x}) then { _x setDammage 1 } } forEach _units;
diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|TERMINAL_SCUTTLE|team=" + (str _team) + "|hulls=" + str (count _wrecks));

//--- (4) bounded cleanup: exactly one pass, TTL later. HC-local deletes only.
uiSleep _ttl;
{ if (!isNil "_x" && {!isNull _x} && {local _x}) then { deleteVehicle _x } } forEach _units;
{
	private ["_rw"];
	_rw = _x;
	if (!isNil "_rw" && {!isNull _rw} && {local _rw} && {({isPlayer _x} count (crew _rw)) == 0}) then { deleteVehicle _rw };
} forEach _wrecks;
diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|TERMINAL_SCUTTLE_CLEAN|team=" + (str _team));
