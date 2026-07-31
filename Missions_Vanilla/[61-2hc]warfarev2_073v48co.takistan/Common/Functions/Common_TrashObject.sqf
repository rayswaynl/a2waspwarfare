/*
	Trash an entity. Groups can only be removed once that all it's units are DELETED!
	 Parameters:
		- Object.
*/

Private ["_delay","_group","_isMan","_object","_town","_crewDead"];

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

	//--- crash 014EFCF4: concurrent cleanup may delete the body while the 60s delay is sleeping.
	if (isNull _object) exitWith {};

	//--- A slung wreck is intentionally crewless; release the queued deletion so it can be reconsidered after unhook.
	//--- r66 corpse/wreck reap: kill-path stamps wfbe_trashed before Spawn TrashObject. Collector nil-gates on
	//--- that stamp, so only releasing gc_collector left airlifted-then-unhooked wrecks permanent leaks.
	//--- Clear the stamp so the next collector pass re-queues once wfbe_airlifted drops on unhook.
	if (_object getVariable ["wfbe_airlifted", false]) exitWith {
		if !(isNil "gc_collector") then {gc_collector = gc_collector - [_object]};
		_object setVariable ["wfbe_trashed", nil];
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
		while {_held < _delay && {!isNull _object}} do {
			_near = false;
			_nearResult = 0;
			_nearResult = [getPos _object, _prox] Call WFBE_CO_FNC_RealPlayersNear;
			if ((typeName _nearResult) == "SCALAR" && {_nearResult > 0}) then {_near = true};
			if (!_near) exitWith {};
			sleep 3; _held = _held + 3;
		};
		if (isNull _object) exitWith {};
	};

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
		//--- r66: fire-and-forget remote delete. If the owner rejects (not local / stamp race / seated
		//--- guard on open #1688) the body must re-enter the collector. Kill-path leaves wfbe_trashed set,
		//--- which blocks re-queue — clear stamp + drop from gc_collector so the next pass retries.
		if !(isNil "gc_collector") then {gc_collector = gc_collector - [_object]};
		_object setVariable ["wfbe_trashed", nil];
	} else {
		//--- r66 wreck never reaped: A2 OA refuses deleteVehicle on a crewed hull (living OR dead crew).
		//--- TrashObject is one-shot; if the wreck still holds corpses the delete no-ops and wfbe_trashed
		//--- blocks collector re-queue → permanent leak. Purge non-player dead crew first (cold-wreck seats
		//--- only — living crew never reach this branch as hulls are !alive). Then delete the hull.
		if (!_isMan && {!isNull _object}) then {
			_crewDead = [];
			{ if (!isNull _x && {!alive _x} && {!isPlayer _x}) then { _crewDead set [count _crewDead, _x] } } forEach (crew _object);
			{ deleteVehicle _x } forEach _crewDead;
		};
		if (!isNull _object) then { deleteVehicle _object };
	};

	if (_isMan) then {
		if !(isNull _group) then {
			if (isNil {_group getVariable "wfbe_persistent"}) then {if (count (units _group) <= 0) then {deleteGroup _group}};
		};
	};
};
