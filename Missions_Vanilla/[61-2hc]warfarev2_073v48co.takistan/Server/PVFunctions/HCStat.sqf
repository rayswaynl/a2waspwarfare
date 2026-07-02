/*
	HCStat.sqf -- server-side sink for the HC load telemetry channel.
	Payload: [profileName (string), fps (number), localUnits (number), localGroups (number)]
	Marty: emits one machine-parseable HCSTAT line per report; box watchdog alerts on
	silence/low fps, window digest aggregates per HC. typeName guards first -- a
	malformed payload must never throw inside a PVF handler.
*/

private ["_name", "_fps", "_units", "_groups"];

if ((typeName _this) != "ARRAY") exitWith {};
if ((count _this) < 4) exitWith {};

_name = _this select 0;
_fps = _this select 1;
_units = _this select 2;
_groups = _this select 3;
if ((typeName _name) != "STRING") exitWith {};

//--- WASPSCALE hc_fps feed (claude-gaming 2026-07-01): cache THIS HC's reported diag_fps (already carried
//--- in every 60s HCStat report) so the server-side WASPSCALE emitter (AI_Commander.sqf) can publish an
//--- hc_fps field without any new cross-machine mechanism. We stamp [fps, time] per HC id in a registry
//--- (WFBE_HCFPS_REG) keyed by name; the emitter takes the MIN across HCs that reported within the last
//--- ~2 min (2x the 60s cadence) so a dead/silent HC ages out instead of pinning a stale value. Pure server
//--- writes; typeName-guarded above; no A3 commands (str-key registry via find, plain arrays).
if ((typeName _fps) == "SCALAR") then {
	private ["_reg","_idx","_slot"];
	_reg = missionNamespace getVariable ["WFBE_HCFPS_REG", []];
	_idx = -1;
	{ if ((_x select 0) == _name) exitWith {_idx = _forEachIndex} } forEach _reg;
	_slot = [_name, _fps, time];
	if (_idx >= 0) then { _reg set [_idx, _slot] } else { _reg = _reg + [_slot] };
	missionNamespace setVariable ["WFBE_HCFPS_REG", _reg];
};

diag_log ("HCSTAT|v1|" + _name + "|fps=" + str _fps + "|units=" + str _units + "|groups=" + str _groups + "|t=" + str (round (time / 60)));
