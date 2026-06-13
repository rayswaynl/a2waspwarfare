/*
	HC_StatLoop.sqf -- headless-client load telemetry.
	Marty: every 60s ship fps + local unit/group counts to the server, which logs
	one HCSTAT line per report (consumed by aicom-watch.ps1 and the window digest).
	profileName distinguishes HC1/HC2. Runs only on headless clients (spawned from Init_HC.sqf).
*/

private ["_units", "_groups"];

while {true} do {
	_units = {local _x} count allUnits;
	_groups = {local _x} count allGroups;
	["HCStat", [profileName, round diag_fps, _units, _groups]] Call WFBE_CO_FNC_SendToServer;
	sleep 60;
};
