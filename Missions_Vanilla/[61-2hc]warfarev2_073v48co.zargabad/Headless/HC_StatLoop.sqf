/*
	HC_StatLoop.sqf -- headless-client load telemetry.
	Marty: every 60s ship fps + local unit/group counts to the server, which logs
	one HCSTAT line per report (consumed by aicom-watch.ps1 and the window digest).
	HC id = "HC-<netId of player>". profileName is UNDEFINED on headless clients,
	and 'owner player' returns 0 on the HC itself (both HCs collapse to HC0), so
	neither works. netId of the HC's own unit is network-unique and distinct per
	HC slot. Runs only on headless clients (from Init_HC.sqf).
*/

private ["_units", "_groups", "_hcId"];

//--- Stable per-HC identifier: netId of this HC's own unit. Unique per HC slot and
//--- defined on HCs (unlike profileName; and unlike 'owner player' which is 0 here).
//--- The server/generator relabels these to HC1/HC2 by sort order.
_hcId = format ["HC-%1", netId player];

while {true} do {
	_units = {local _x} count allUnits;
	//--- A2: 'local' accepts OBJECT only - a GROUP argument throws. Use the leader as proxy.
	_groups = {local (leader _x)} count allGroups;
	["HCStat", [_hcId, round diag_fps, _units, _groups]] Call WFBE_CO_FNC_SendToServer;
	sleep 60;
};
