/*
	HCStat.sqf -- server-side sink for the HC load telemetry channel.
	Payload: [profileName (string), fps (number), localUnits (number), localGroups (number), who (string, optional)]
	Marty: emits one machine-parseable HCSTAT line per report; box watchdog alerts on
	silence/low fps, window digest aggregates per HC. typeName guards first -- a
	malformed payload must never throw inside a PVF handler.
*/

private ["_name", "_fps", "_units", "_groups", "_who"];

if ((typeName _this) != "ARRAY") exitWith {};
if ((count _this) < 4) exitWith {};

_name = _this select 0;
_fps = _this select 1;
_units = _this select 2;
_groups = _this select 3;
if ((typeName _name) != "STRING") exitWith {};

//--- Optional 5th payload element (wave0723c telemetry, HCSTAT label fix): human-readable unit name
//--- appended by HC_StatLoop.sqf as [.., name player]. Backward compatible -- the join KEY stays _name
//--- ("HC-<netId>"; server_hcreg_heal.sqf joins WFBE_HCFPS_REG on this SAME key, so it must never change).
//--- Older 4-element payloads leave _who empty and the diag_log line below is byte-identical to today.
_who = "";
if (((count _this) >= 5) && {(typeName (_this select 4)) == "STRING"}) then { _who = "|who=" + (_this select 4); };

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

diag_log ("HCSTAT|v1|" + _name + "|fps=" + str _fps + "|units=" + str _units + "|groups=" + str _groups + _who + "|t=" + str (round (time / 60)));
