/*
	HC_StatLoop.sqf -- headless-client load telemetry.
	Marty: every 60s ship fps + local unit/group counts to the server, which logs
	one HCSTAT line per report (consumed by aicom-watch.ps1 and the window digest).
	HC id = "HC<netID>" (owner player); profileName is UNDEFINED on headless clients
	(no profile), so it cannot be used. Runs only on headless clients (from Init_HC.sqf).
*/

private ["_units", "_groups", "_hcId"];

//--- Stable per-HC identifier: network owner ID. Distinct per HC, defined on HCs
//--- (unlike profileName). The server/generator relabels these to HC1/HC2 by sort order.
_hcId = format ["HC%1", owner player];

while {true} do {
	_units = {local _x} count allUnits;
	//--- A2: 'local' accepts OBJECT only - a GROUP argument throws. Use the leader as proxy.
	_groups = {local (leader _x)} count allGroups;
	["HCStat", [_hcId, round diag_fps, _units, _groups]] Call WFBE_CO_FNC_SendToServer;
	sleep 60;
};
