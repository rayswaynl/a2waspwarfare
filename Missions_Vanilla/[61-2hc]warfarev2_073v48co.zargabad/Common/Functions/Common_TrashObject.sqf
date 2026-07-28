/*
	Trash an entity. Groups can only be removed once that all it's units are DELETED!
	 Parameters:
		- Object.
*/

Private ["_delay","_group","_isMan","_object","_town"];

_object = _this;
_town = [_object] Call GetClosestLocation;
if !(isNull _object) then {
	_isMan = if (_object isKindOf "Man") then {true} else {false};

	_group = if (_isMan) then {group _object} else {grpNull};
	if !(_isMan) then {_object removeAllEventHandlers "hit"};
	_object removeAllEventHandlers "killed";

	//--- B35 (claude-gaming 2026-06-15): man bodies -> fixed BODIES_TIMEOUT (60s); vehicle wrecks -> lobby-tunable CLEAN_TIMEOUT.
	//--- Prior bug: this read BODIES_TIMEOUT for BOTH then x2'd vehicles, so the lobby "Bodies Timeout" slider was silently ignored (wrecks pinned at 120s).
	//--- Split restored; x2 dropped so the slider value IS the wreck timeout (Parameters default lowered to 120s to keep prior effective behavior). Rollback: single BODIES read + x2.
	_delay = if (_isMan) then { missionNamespace getVariable "WFBE_C_UNITS_BODIES_TIMEOUT" } else { missionNamespace getVariable "WFBE_C_UNITS_CLEAN_TIMEOUT" };

	sleep _delay;

	//--- A slung wreck is intentionally crewless; release the queued deletion so it can be reconsidered after unhook.
	if (_object getVariable ["wfbe_airlifted", false]) exitWith {
		if !(isNil "gc_collector") then {gc_collector = gc_collector - [_object]};
		["INFORMATION", Format["Common_TrashObject.sqf: retaining airlifted wreck [%1].", _object]] Call WFBE_CO_FNC_LogContent;
	};

	//--- qol-polish-pack: optional player-proximity guard for bodies — never pop a corpse in a player's face. Holds deletion while a player
	//--- is within WFBE_C_UNITS_BODIES_PROX m, capped at one extra _delay so a camper can't pin a body forever. 0 = off (vanilla behaviour).
	if (_isMan && {(missionNamespace getVariable ["WFBE_C_UNITS_BODIES_PROX", 0]) > 0}) then {
		private ["_prox","_held","_near","_nearResult"];
		_prox = missionNamespace getVariable ["WFBE_C_UNITS_BODIES_PROX", 0];
		_held = 0;
		_near = false;
		_nearResult = 0;
		while {_held < _delay} do {
			_near = false;
			_nearResult = 0;
			_nearResult = [getPos _object, _prox] Call WFBE_CO_FNC_RealPlayersNear;
			if ((typeName _nearResult) == "SCALAR" && {_nearResult > 0}) then {_near = true};
			if (!_near) exitWith {};
			sleep 3; _held = _held + 3;
		};
	};

	//--- claude/trash-nullobj SENDTOCLIENT drop fix (correctness, no flag): the object can be deleted
	//--- by another path (killed EH, HC-owned reap, a second GC pass) DURING the trash-delay sleep
	//--- above. A now-null _object has owner 0, so the non-local branch fired
	//--- [objNull,"HandleSpecial",["cleanup-trash-object",objNull]] into WFBE_CO_FNC_SendToClient, which
	//--- dropped it every cycle (SENDTOCLIENT|v1|DROPPED|func=HandleSpecial|owner=0-or-negative - the
	//--- steady RPT noise), plus a misleading "Deleting [<NULL-object>]" log and a no-op deleteVehicle.
	//--- Nothing remains to delete, so skip the delete stanza when it is already gone; the empty-group
	//--- cleanup below still runs.
	if !(isNull _object) then {
		["INFORMATION", Format["Server_TrashObject.sqf: Deleting [%1], it has been [%2] seconds.", _object, _delay]] Call WFBE_CO_FNC_LogContent;

		//--- LOCALITY GATE (WFBE_C_TRASH_REMOTE_DELETE, default 1 = locality-aware cleanup). A server-side
		//--- deleteVehicle on a NON-LOCAL object silently no-ops in A2 OA, so every HC-local body/hull handed
		//--- to this shared path survived the whole match. When the flag is on, route the delete to the owning
		//--- machine over the SAME server->HC channel server_groupsGC.sqf uses for commander-artillery wrecks
		//--- (WFBE_CO_FNC_SendToClient routes by the object's own owner). The public reap stamp lets the
		//--- receiver refuse anything this function did not itself queue; combined with its own !alive test
		//--- the worst a forged dispatch can do is despawn a corpse/wreck early - never a live object.
		if ((missionNamespace getVariable ["WFBE_C_TRASH_REMOTE_DELETE", 0]) > 0 && {!local _object}) then {
			_object setVariable ["wfbe_trash_reap", true, true];
			["INFORMATION", Format["Common_TrashObject.sqf: [%1] is not server-local; dispatching the delete to its owner.", _object]] Call WFBE_CO_FNC_LogContent;
			[_object, "HandleSpecial", ["cleanup-trash-object", _object]] Call WFBE_CO_FNC_SendToClient;
		} else {
			deleteVehicle _object;
		};
	};

	if (_isMan) then {
		if !(isNull _group) then {
			if (isNil {_group getVariable "wfbe_persistent"}) then {if (count (units _group) <= 0) then {deleteGroup _group}};
		};
	};
};
