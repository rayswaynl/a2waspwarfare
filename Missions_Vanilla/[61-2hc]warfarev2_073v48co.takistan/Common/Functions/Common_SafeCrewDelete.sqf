/*
	Common_SafeCrewDelete.sqf - shared crew+hull teardown for crash 014EFCF4 (register-level proven,
	memory wasp-crash-014efcf4-mechanism.md, 2026-07-31 live). Fault 014EFCF4 = deleteVehicle called on a
	Man object STILL SEATED in a live/crewed hull, racing the engine's own seat-array move-out math. Every
	inline "{deleteVehicle _x} forEach (crew _hull)" idiom in this codebase is a candidate for that race.

	Called as `[_hull, _alsoDeleteHull] Spawn WFBE_CO_FNC_SafeCrewDelete`. MUST be dispatched via Spawn, not
	Call: Spawn always creates a fresh SCHEDULED execution thread, so `sleep` is legal here even when the
	call site itself is unscheduled (a Compile-Call'd function, or an FSM-adjacent .sqf) - this is what lets
	one shared helper serve both scheduled and unscheduled callers without duplicating the fix per site. The
	`sleep` between each crew delete yields a frame so the engine's dead-crew-eject / survivor get-out seat
	walk never overlaps this script's own deleteVehicle on an adjacent seat of the same still-alive hull -
	the exact mechanism proven at Common_TrashObject.sqf's B35/#4 defer (2026-07-30 live, m0730j: seated
	corpses deleted out of a still-crewed vehicle team, one body 19s before the fault, the fault register
	held a sibling crew corpse mid-GetOutAny).

	Params: [0] _hull (OBJECT, the crewed hull) [1] _alsoDeleteHull (BOOL, also delete the hull once its
	crew is clear). Telemetry line mirrors the seat-state shape already proven at Common_TrashObject.sqf's
	always-on WASPCRASH014E|TRASH diag_log (obj/isMan/seat/seatAlive/seatCrewAlive/t), tagged SWEEP here to
	mark this second sweep pass distinctly from the original TrashObject instrumentation.

	A2-OA-1.64 safe: Private[] declarations only (no inline private _x=), outer _x captured into _crewMember
	before the inner `count` sub-expression rebinds _x, no params/pushBack/isEqualType/isEqualType, Spawn/Call
	capitalized per repo style, if/then blocks only (no ternary).
*/
Private ["_hull","_alsoDeleteHull","_crewMember"];
_hull = _this select 0;
_alsoDeleteHull = _this select 1;
if (isNull _hull) exitWith {};

{
	_crewMember = _x;
	if (!isNull _crewMember && {_crewMember != _hull}) then {
		diag_log Format ["WASPCRASH014E|SWEEP|obj=%1|isMan=%2|seat=%3|seatAlive=%4|seatCrewAlive=%5|t=%6",
			_crewMember, true, _hull, str (alive _hull), str ({alive _x} count crew _hull), diag_tickTime];
		deleteVehicle _crewMember;
		sleep 0.05;
	};
} forEach (crew _hull);

if (_alsoDeleteHull && {!isNull _hull}) then {
	sleep 0.05;
	deleteVehicle _hull;
};
