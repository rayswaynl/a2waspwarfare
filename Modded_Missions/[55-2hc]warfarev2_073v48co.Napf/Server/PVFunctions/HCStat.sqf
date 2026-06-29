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

diag_log ("HCSTAT|v1|" + _name + "|fps=" + str _fps + "|units=" + str _units + "|groups=" + str _groups + "|t=" + str (round (time / 60)));
