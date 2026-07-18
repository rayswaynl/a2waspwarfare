//--- Server_StructureCapAdmit.sqf (P0 atomic structure cap, card wasp-p0-aicom-atomic-structure-cap-20260718)
//--- THE single server-owned admission gate for every AICOM structure-build path (general / forward / rebase).
//--- Live defect it kills: BUILD_CAP_SKIP CommandCenter have=3|max=2 - the general and forward builders each
//--- counted ALIVE structures from their own stale snapshots with separate pending namespaces, so both could
//--- admit (and pay for) the same capped type inside the async construction window.
//---
//--- Invariant enforced here: aliveOfType + activeReservations < perTypeCap.
//--- Reservation lifecycle (card contract): RESERVE before debit (admit mode grants + appends a timestamp);
//--- release on SUCCESS via alive-delta (when the alive count rises above the stored baseline, that many
//--- oldest reservations are consumed - their builds completed); release on TIMEOUT via TTL prune (300s =
//--- the same 5-minute async build window wfbe_aicom_built_%1 already guards); release on FAILURE/CANCEL via
//--- explicit "release" mode. SQF is non-preemptive within a frame, so check+reserve in one call IS atomic
//--- for the cross-path/cross-tick races this closes.
//---
//--- Params: [mode ("check"|"admit"|"release"), _logik (side logic), typeKey, structuresArray]
//--- Returns BOOL: check/admit = under-cap (admit also reserved); release = always true.
private ["_mode","_logik","_type","_structures","_limit","_basesMax","_aliveN","_resKey","_store","_lastAlive","_times","_timesLive","_now","_ttl","_delta","_ret"];
_mode = _this select 0; _logik = _this select 1; _type = _this select 2;
_structures = if (count _this > 3) then {_this select 3} else {[]};
_ttl = 300;
if ((missionNamespace getVariable ["WFBE_C_AICOM_OBEY_BUILD_LIMITS", 1]) <= 0) exitWith {true}; //--- caps off: always grant, never reserve
_limit = missionNamespace getVariable [Format ["WFBE_C_STRUCTURES_MAX_%1", _type], 3];
if (typeName _limit != "SCALAR") then {_limit = 3};
if (_type == "CommandCenter") then {
	_basesMax = missionNamespace getVariable ["WFBE_C_AICOM_BASES_MAX", 2];
	if (_basesMax > 0 && {_basesMax < _limit}) then {_limit = _basesMax};
};
_now = time;
_resKey = Format ["wfbe_aicom_capres_%1", _type];
_store = _logik getVariable [_resKey, [0, []]];
_lastAlive = _store select 0;
_times = _store select 1;
_aliveN = {((_x getVariable ["wfbe_structure_type", ""]) == _type) && {alive _x}} count _structures;
//--- SUCCESS release: alive rose above the stored baseline -> that many oldest reservations completed.
_delta = _aliveN - _lastAlive;
if (_delta > 0) then {
	private ["_kept"];
	_kept = [];
	{ if (_forEachIndex >= _delta) then {_kept set [count _kept, _x]} } forEach _times;
	_times = _kept;
};
//--- TIMEOUT release: prune reservations older than the build window.
private ["_pruned"];
_pruned = [];
{ if (!isNil "_x" && {(_now - _x) < _ttl}) then {_pruned set [count _pruned, _x]} } forEach _times;
_times = _pruned;
_ret = true;
if (_mode == "release") then {
	//--- FAILURE/CANCEL release: drop the newest reservation (the attempt that just aborted).
	if (count _times > 0) then {
		private ["_trimmed"];
		_trimmed = [];
		{ if (_forEachIndex < ((count _times) - 1)) then {_trimmed set [count _trimmed, _x]} } forEach _times;
		_times = _trimmed;
	};
} else {
	_ret = (_aliveN + (count _times)) < _limit;
	if (_mode == "admit" && {_ret}) then {
		_times set [count _times, _now];
	};
};
_logik setVariable [_resKey, [_aliveN, _times]];
_ret
