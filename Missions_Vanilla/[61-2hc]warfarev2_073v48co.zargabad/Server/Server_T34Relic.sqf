/*
	Server_T34Relic.sqf - lane 183 capturable T-34 relic.

	Default-off a-life objective: park one uncrewed T34_TK_GUE_EP1 at a resistance-held town.
	The tank has no bounty while neutral. The first WEST/EAST/GUER crew side to board it claims
	the relic, stamps wfbe_side_id, and receives the normal killed/hit event handlers so destroying
	it pays through RequestOnUnitKilled like any other mission-created vehicle.
*/

scriptName "Server\Server_T34Relic.sqf";

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_T34_RELIC_ENABLE", 0]) < 1) exitWith {};

private ["_class","_candidates","_sid","_town","_townName","_relic","_marker","_spawnPos","_owner","_claimer","_claimSide","_crewSid","_msg"];

waitUntil { sleep 1; (!isNil "townInitServer") && {townInitServer} && {!isNil "towns"} && {(count towns) > 0} };
sleep (missionNamespace getVariable ["WFBE_C_T34_RELIC_START_DELAY", 20]);

_class = missionNamespace getVariable ["WFBE_C_T34_RELIC_CLASS", "T34_TK_GUE_EP1"];
_candidates = [];

{
	_sid = _x getVariable ["sideID", -1];
	if (_sid == WFBE_C_GUER_ID) then {_candidates = _candidates + [_x]};
} forEach towns;

if ((count _candidates) == 0) exitWith {
	["WARNING", "Server_T34Relic.sqf: no resistance-held town found; T-34 relic not spawned."] Call WFBE_CO_FNC_LogContent;
	diag_log "T34RELIC|SKIP|reason=no_resistance_town";
};

_town = _candidates select floor(random (count _candidates));
_townName = _town getVariable ["name", "unknown"];
_spawnPos = getPos _town;

_relic = [_class, _spawnPos, resistance, random 360, false, false] Call WFBE_CO_FNC_CreateVehicle;
if (isNull _relic) exitWith {
	["WARNING", Format ["Server_T34Relic.sqf: failed to create relic class [%1] near [%2].", _class, _townName]] Call WFBE_CO_FNC_LogContent;
	diag_log format ["T34RELIC|SPAWNFAIL|class=%1|town=%2", _class, _townName];
};

[_relic, _spawnPos, (missionNamespace getVariable ["WFBE_C_T34_RELIC_MIN_RADIUS", 70]), (missionNamespace getVariable ["WFBE_C_T34_RELIC_MAX_RADIUS", 150]), true, true, true] Call PlaceNear;
//--- Common_CreateVehicle needs a side for init/faction visuals; keep this ownerless until a crew claims it.
_relic setVariable ["wfbe_side_id", -1, true];
_relic setVariable ["wfbe_t34_relic", true, true];
_relic setVariable ["wfbe_t34_relic_owner", -1, true];
_relic setFuel (missionNamespace getVariable ["WFBE_C_T34_RELIC_FUEL", 0.65]);

_marker = "WFBE_T34_RELIC";
if (getMarkerColor _marker != "") then {deleteMarker _marker};
createMarker [_marker, getPos _relic];
_marker setMarkerType "mil_objective";
_marker setMarkerColor "ColorYellow";
_marker setMarkerSize [0.8, 0.8];
_marker setMarkerText Format ["T-34 Relic near %1", _townName];

missionNamespace setVariable ["WFBE_T34_RELIC_VEHICLE", _relic];
missionNamespace setVariable ["WFBE_T34_RELIC_OWNER", -1];
publicVariable "WFBE_T34_RELIC_OWNER";

_msg = Format ["A neutral T-34 relic has been spotted near %1. First side to crew it claims the bounty target.", _townName];
[nil, "DashboardAnnounce", [_msg]] Call WFBE_CO_FNC_SendToClients;
["INFORMATION", Format ["Server_T34Relic.sqf: spawned [%1] near [%2] at [%3].", _class, _townName, getPos _relic]] Call WFBE_CO_FNC_LogContent;
diag_log format ["T34RELIC|SPAWN|class=%1|town=%2|pos=%3", _class, _townName, getPos _relic];

_owner = -1;
while {!WFBE_GameOver && {alive _relic} && {_owner < 0}} do {
	sleep 3;
	{
		if (alive _x) then {
			_crewSid = (side _x) Call WFBE_CO_FNC_GetSideID;
			if ((_crewSid == WESTID) || {_crewSid == EASTID} || {_crewSid == WFBE_C_GUER_ID}) exitWith {
				_owner = _crewSid;
				_claimer = _x;
			};
		};
	} forEach crew _relic;
};

if (_owner >= 0 && {alive _relic}) then {
	_claimSide = _owner Call WFBE_CO_FNC_GetSideFromID;
	_relic setVariable ["wfbe_side_id", _owner, true];
	_relic setVariable ["wfbe_t34_relic_owner", _owner, true];
	missionNamespace setVariable ["WFBE_T34_RELIC_OWNER", _owner];
	publicVariable "WFBE_T34_RELIC_OWNER";
	_relic addEventHandler ["killed", Format ['[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled', _owner]];
	_relic addEventHandler ["hit", {_this Spawn WFBE_CO_FNC_OnUnitHit}];
	_marker setMarkerColor (switch (_owner) do {case WESTID: {"ColorBlue"}; case EASTID: {"ColorRed"}; case WFBE_C_GUER_ID: {"ColorGreen"}; default {"ColorYellow"}});
	_marker setMarkerText Format ["%1 T-34 Relic", str _claimSide];
	_msg = Format ["%1 claimed the T-34 relic near %2. Destroy it for normal vehicle bounty.", str _claimSide, _townName];
	[nil, "DashboardAnnounce", [_msg]] Call WFBE_CO_FNC_SendToClients;
	["INFORMATION", Format ["Server_T34Relic.sqf: [%1] claimed relic [%2] near [%3] by [%4].", _claimSide, _relic, _townName, _claimer]] Call WFBE_CO_FNC_LogContent;
	diag_log format ["T34RELIC|CLAIM|side=%1|town=%2|claimer=%3", _owner, _townName, _claimer];
};

waitUntil { sleep 10; WFBE_GameOver || {isNull _relic} || {!alive _relic} };
if (getMarkerColor _marker != "") then {deleteMarker _marker};
diag_log format ["T34RELIC|END|owner=%1|alive=%2|t=%3", _owner, alive _relic, round time];
