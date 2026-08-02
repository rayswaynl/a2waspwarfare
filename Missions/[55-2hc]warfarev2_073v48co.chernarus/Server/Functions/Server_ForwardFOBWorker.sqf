/*
	Server_ForwardFOBWorker.sqf - per-FOB server loop (flag WFBE_C_STRUCTURES_FOB).

	Spawned once per Forward FOB by Server\PVFunctions\RequestForwardFOB.sqf. Two v1 effects live here:

	  (a) Passive hostile-proximity ping (owner ruling 3). Polls Common\Functions\Common_GetHostilesInArea.sqf
	      - the same helper the respawn safe-radius already uses - and raises/drops a side-scoped mil_warning
	      marker through the WildcardMarker client PVF, i.e. the createMarkerLocal idiom, so the enemy never
	      sees it (Server\PVFunctions\RequestFOBStructure.sqf:79 precedent; the AI_Commander_Wildcard_GUER.sqf
	      checkpoint markers are deliberately GLOBAL and are the wrong shape to copy here).
	      Requires BOTH tent and mast alive (spec 4d "require both"): the mast is the FOB's comms identity, so
	      losing it kills intel reporting while the tent alone still carries respawn/resupply/repair.

	  (b) Vehicle repair bubble (owner ruling 3). NOTE - the spec's native route (giving the tent the
	      Base_WarfareBVehicleServicePoint facility class so the engine repairs in-radius for free) is a
	      CONFIG-TIME property and cannot be attached to a Camp_EP1 prefab at runtime, so the bubble is
	      scripted here instead: friendly, stationary, damaged vehicles in range lose WFBE_C_FOB_SERVICE_STEP
	      damage per poll. Repair only - no rearm or refuel, neither of which the owner ruled on.

	The loop exits as soon as the tent dies; Server_ForwardFOBKilled.sqf owns the teardown.

	A2 OA 1.64 safe: array-form private only, no params/pushBack/isEqualType, getDammage/setDammage (double-m
	is the correct OA spelling), outer _x captured into a named local, no exitWith inside forEach.

	_this = [campLogic, tent, antenna, side]
*/
private ["_logic","_tent","_antenna","_side","_enemySides","_mk","_shown","_radius","_interval","_hostiles","_svcR","_svcStep","_veh","_dmg"];

_logic   = _this select 0;
_tent    = _this select 1;
_antenna = _this select 2;
_side    = _this select 3;

_radius   = missionNamespace getVariable ["WFBE_C_FOB_PING_RADIUS", 300];
_interval = missionNamespace getVariable ["WFBE_C_FOB_PING_INTERVAL", 15];
_svcR     = missionNamespace getVariable ["WFBE_C_FOB_SERVICE_RADIUS", 30];
_svcStep  = missionNamespace getVariable ["WFBE_C_FOB_SERVICE_STEP", 0.05];

//--- Same hostile-side resolution the respawn safe-radius uses (Common_GetRespawnCamps.sqf:44-49).
_enemySides = if (WFBE_ISTHREEWAY) then {[west, east, resistance] - [_side]} else {if (_side == west) then {[east]} else {[west]}};

//--- Deterministic marker name from the build position, so the death path can delete it without shared state
//--- (RequestFOBStructure.sqf:78 idiom).
_mk = Format ["wfbe_fob_ping_%1_%2", floor ((getPos _tent) select 0), floor ((getPos _tent) select 1)];
_shown = false;

while {!isNull _tent && {alive _tent}} do {
	sleep _interval;

	if (!isNull _tent && {alive _tent}) then {
		//--- (a) intel ping - mast must be alive too.
		if (!isNull _antenna && {alive _antenna}) then {
			_hostiles = [_tent, _enemySides, _radius] Call GetHostilesInArea;
			if (_hostiles > 0 && {!_shown}) then {
				_shown = true;
				[_side, "WildcardMarker", ["create", _mk, getPos _tent, "ColorRed", "mil_warning", "FOB - hostiles near", "enemy activity detected inside the FOB perimeter"]] Call WFBE_CO_FNC_SendToClients;
				["INFORMATION", Format ["Server_ForwardFOBWorker.sqf: [%1] FOB ping ON - %2 hostile(s) within %3m.", str _side, _hostiles, _radius]] Call WFBE_CO_FNC_LogContent;
			};
			if (_hostiles == 0 && {_shown}) then {
				_shown = false;
				[_side, "WildcardMarker", ["delete", _mk]] Call WFBE_CO_FNC_SendToClients;
				["INFORMATION", Format ["Server_ForwardFOBWorker.sqf: [%1] FOB ping OFF - perimeter clear.", str _side]] Call WFBE_CO_FNC_LogContent;
			};
		};

		//--- (b) repair bubble - friendly, stopped, damaged vehicles in range.
		{
			_veh = _x;
			if (!isNull _veh && {alive _veh} && {(side _veh) == _side} && {(speed _veh) < 5}) then {
				_dmg = getDammage _veh;
				if (_dmg > 0) then {
					_dmg = _dmg - _svcStep;
					if (_dmg < 0) then {_dmg = 0};
					_veh setDammage _dmg;
				};
			};
		} forEach (_tent nearEntities [["Car","Motorcycle","Tank","Air","Ship"], _svcR]);
	};
};

//--- Tent died: the ping marker must never outlive it. Server_ForwardFOBKilled.sqf deletes it too; the
//--- WildcardMarker delete op is idempotent (it no-ops on an already-absent marker).
if (_shown) then {
	[_side, "WildcardMarker", ["delete", _mk]] Call WFBE_CO_FNC_SendToClients;
};
