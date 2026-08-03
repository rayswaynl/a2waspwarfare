/*
	Trash an entity. Groups can only be removed once that all it's units are DELETED!
	 Parameters:
		- Object.
*/

Private ["_delay","_group","_isMan","_object","_town","_remoteAttempt","_remoteBackoff","_remoteOwner"];

_object = _this;
_town = [_object] Call GetClosestLocation;
if !(isNull _object) then {
	_isMan = if (_object isKindOf "Man") then {true} else {false};

	_group = if (_isMan) then {group _object} else {grpNull};
	if !(_isMan) then {_object removeAllEventHandlers "hit"};
	_object removeAllEventHandlers "killed";

	//--- crash 014EFCF4 #6 (2026-08-01 15:37 live, Takistan): queue-time seat observation. The
	//--- crashing corpse was SEATED in its dead hull when queued here, the engine ejected it during
	//--- the sleep below (GetOutAny "already in landscape"), and the post-sleep delete then freed it
	//--- ~8s after the eject while the engine's move-out bookkeeping still held the pointer (fault
	//--- registers: ESI = this corpse). Seat state sampled only AFTER the sleep never sees that
	//--- transition - remember it was seated NOW; the post-eject cooldown below acts on this stamp.
	if (_isMan && {vehicle _object != _object}) then {_object setVariable ["wfbe_seatSeen", true]};

	//--- B35 (claude-gaming 2026-06-15): man bodies -> fixed BODIES_TIMEOUT (60s); vehicle wrecks -> lobby-tunable CLEAN_TIMEOUT.
	//--- Prior bug: this read BODIES_TIMEOUT for BOTH then x2'd vehicles, so the lobby "Bodies Timeout" slider was silently ignored (wrecks pinned at 120s).
	//--- Split restored; x2 dropped so the slider value IS the wreck timeout (Parameters default lowered to 120s to keep prior effective behavior). Rollback: single BODIES read + x2.
	_delay = if (_isMan) then { missionNamespace getVariable "WFBE_C_UNITS_BODIES_TIMEOUT" } else { missionNamespace getVariable "WFBE_C_UNITS_CLEAN_TIMEOUT" };

	sleep _delay;

	//--- crash 014EFCF4: concurrent cleanup may delete the body while the 60s delay is sleeping.
	if (isNull _object) exitWith {};

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

	//--- crash 014EFCF4 #4 (2026-07-30 09:44 live, m0730j): all four faults sit in the engine's vehicle
	//--- move-out position math. This pass had deleted seated corpses out of a still-crewed vehicle team
	//--- (one body 19s before the fault) and 15 more out of a fresh AAV wreck in one frame, and the fault
	//--- registers held a sibling crew corpse mid-GetOutAny. Never deleteVehicle a body still seated while
	//--- its hull is alive or holds living crew - the engine's dead-crew eject / survivor get-out walks
	//--- those seats exactly then. Release the body back to the collector (airlifted-wreck idiom above) so
	//--- deletion is retried ~65s later, once the hull is a cold wreck. Cold-wreck seat deletion (hull dead,
	//--- crew all dead) keeps today's behaviour so the later hull pass still finds an empty wreck
	//--- (A2 OA refuses deleteVehicle on a crewed hull).
	if (_isMan && {!isNull _object} && {vehicle _object != _object} && {(alive (vehicle _object)) || {({alive _x} count crew (vehicle _object)) > 0}}) exitWith {
		if !(isNil "gc_collector") then {gc_collector = gc_collector - [_object]};
		_object setVariable ["wfbe_trashed", nil]; //--- crash 014EFCF4 review: without this reset the collector NEVER re-queues the deferred body (server_collector_garbage only re-spawns TrashObject when wfbe_trashed is nil), so the defer traded the crash for a permanent body leak. Established idiom: server_groupsGC.sqf.
		_object setVariable ["wfbe_seatSeen", true]; //--- crash 014EFCF4 #6: seated at THIS check too - keep the post-eject cooldown armed for the retry.
		["INFORMATION", Format["Common_TrashObject.sqf: deferring corpse [%1] still seated in live vehicle [%2].", _object, vehicle _object]] Call WFBE_CO_FNC_LogContent;
	};

	//--- crash 014EFCF4 #6 (2026-08-01 15:37 live, register-proven: fault ESI held this corpse's
	//--- pointer): a crew corpse queued while seated was engine-ejected during the sleep above and
	//--- the delete then freed it ~8s post-eject, while the engine's GetOutAny/move-out walk still
	//--- referenced it. If this body was EVER observed seated (queue-time stamp or a prior seated-
	//--- defer) and is unseated now, hold it ONE more collector cycle (>=60s re-queue) so the real
	//--- delete lands well clear of the eject window. Corpses never observed seated carry no stamp
	//--- and delete exactly as before. Same release idiom as the seated-defer above.
	if (_isMan && {!isNull _object} && {vehicle _object == _object} && {_object getVariable ["wfbe_seatSeen", false]}) exitWith {
		_object setVariable ["wfbe_seatSeen", nil];
		if !(isNil "gc_collector") then {gc_collector = gc_collector - [_object]};
		_object setVariable ["wfbe_trashed", nil]; //--- same re-queue reset as the branches above - the hold must not leak the body.
		["INFORMATION", Format["Common_TrashObject.sqf: post-eject cooldown - holding corpse [%1] one more cycle.", _object]] Call WFBE_CO_FNC_LogContent;
	};

	//--- crash 014EFCF4 instrumentation (always-on, unconditional diag_log): captures seat state at the
	//--- exact instant of every real delete so the NEXT crash window - if any - shows second-by-second
	//--- whether a seated-corpse delete preceded the fault, discriminating this hypothesis from the
	//--- CargoAirdrop/ParaVehicles attach-then-delete race.
	diag_log Format ["WASPCRASH014E|TRASH|obj=%1|isMan=%2|seat=%3|seatAlive=%4|seatCrewAlive=%5|t=%6|seatSeen=%7",
		_object, _isMan,
		(if (_isMan) then {vehicle _object} else {objNull}),
		(if (_isMan && {vehicle _object != _object}) then {str (alive (vehicle _object))} else {"-"}),
		(if (_isMan && {vehicle _object != _object}) then {str ({alive _x} count crew (vehicle _object))} else {"-"}),
		diag_tickTime,
		(if (_isMan) then {_object getVariable ["wfbe_seatSeen", false]} else {false})
	];
	["INFORMATION", Format["Server_TrashObject.sqf: Deleting [%1], it has been [%2] seconds.", _object, _delay]] Call WFBE_CO_FNC_LogContent;

	//--- LOCALITY GATE (WFBE_C_TRASH_REMOTE_DELETE, default 1 = locality-aware cleanup). A server-side
	//--- deleteVehicle on a NON-LOCAL object silently no-ops in A2 OA, so every HC-local body/hull handed
	//--- to this shared path survived the whole match. When the flag is on, route the delete to the owning
	//--- machine over the SAME server->HC channel server_groupsGC.sqf uses for commander-artillery wrecks
	//--- (WFBE_CO_FNC_SendToClient routes by the object's own owner). The public reap stamp lets the
	//--- receiver refuse anything this function did not itself queue; combined with its own !alive test
	//--- the worst a forged dispatch can do is despawn a corpse/wreck early - never a live object.
	if ((missionNamespace getVariable ["WFBE_C_TRASH_REMOTE_DELETE", 0]) > 0 && {!local _object}) then {
		_remoteOwner = owner _object;
		//--- RPT deep-dive 2026-08-01: owner dispatch is fire-and-forget. If the owner is
		//--- unavailable or rejects a stale locality/seat state, clearing wfbe_trashed immediately
		//--- lets the 5s collector spawn another 60s worker forever. Keep eventual retry, but add
		//--- exponential collector cooldown (cleanup delay floored at 60s, then doubled up to
		//--- a 900s cap) so one dead remote object cannot generate a one-minute dispatch storm.
		//--- The normal worker sleep remains after the cooldown, preserving cleanup grace.
		_remoteAttempt = (_object getVariable ["wfbe_trash_remote_attempts", 0]) + 1;
		_remoteBackoff = ((_delay max 60) * (2 ^ ((_remoteAttempt - 1) min 4)));
		if (_remoteBackoff > 900) then {_remoteBackoff = 900};
		_object setVariable ["wfbe_trash_remote_attempts", _remoteAttempt];
		_object setVariable ["wfbe_trash_remote_retry_after", diag_tickTime + _remoteBackoff];
		_object setVariable ["wfbe_trash_reap", true, true];
		["INFORMATION", Format["Common_TrashObject.sqf: [%1] is not server-local; remote owner %4; retry %2, backoff %3s.", _object, _remoteAttempt, _remoteBackoff, _remoteOwner]] Call WFBE_CO_FNC_LogContent;
		//--- owner() can be zero while HC locality is transferring. Common_SendToClient drops that
		//--- packet by design; keep the retry state but avoid constructing an impossible PVF.
		if (_remoteOwner > 0) then {
			[_object, "HandleSpecial", ["cleanup-trash-object", _object]] Call WFBE_CO_FNC_SendToClient;
		};
		//--- crash 014EFCF4 #4: release the dispatched body back to the collector. If the owner-side executor
		//--- rejects a mid-flight seat race, the next collector pass re-queues it instead of leaking the body;
		//--- if the owner deleted it, the reference nulls and the collector's objNull prune drops it.
		if !(isNil "gc_collector") then {gc_collector = gc_collector - [_object]};
		_object setVariable ["wfbe_trashed", nil]; //--- crash 014EFCF4 review: same re-queue reset as the seat-defer above - an owner-side refusal must not leak the body forever.
	} else {
		_object setVariable ["wfbe_trash_remote_attempts", nil];
		_object setVariable ["wfbe_trash_remote_retry_after", nil];
		deleteVehicle _object;
	};

	if (_isMan) then {
		if !(isNull _group) then {
			if (isNil {_group getVariable "wfbe_persistent"}) then {if (count (units _group) <= 0) then {deleteGroup _group}};
		};
	};
};
