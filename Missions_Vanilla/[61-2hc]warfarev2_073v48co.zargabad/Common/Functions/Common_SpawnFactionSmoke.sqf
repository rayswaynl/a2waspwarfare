/*
	WFBE_CO_FNC_SpawnFactionSmoke — server-only triggered faction smoke (cosmetic).

	Drops ONE faction-coloured smoke shell at a leader/town position to flag an
	assault onset or a town garrison. Event-triggered (never periodic), hard-capped,
	TTL-cleaned, and per-key cooldown'd so it cannot stack or churn the particle
	budget. Server-only: the smoke object replicates to clients by the engine, so
	there is NO per-client plumbing and NO unit-throws-grenade (which would interrupt
	AI animation). This must never gate/freeze AI or touch antistack.

	Params: [ _pos (positionATL), _side ]
	Returns: nothing.
*/
private ["_pos","_side","_color","_active","_pruned","_key","_cd","_s"];

//--- Master gate (default OFF unless the constant turns it on).
if ((missionNamespace getVariable ["WFBE_C_FSMOKE_ENABLED", 0]) <= 0) exitWith {};

_pos  = _this select 0;
_side = _this select 1;

//--- Resolve smoke colour by side; unknown sides drop nothing.
_color = switch (_side) do {
	case west:       {"SmokeShellGreen"};
	case east:       {"SmokeShellRed"};
	case resistance: {"SmokeShellOrange"};
	default          {""};
};
if (_color == "") exitWith {};

//--- GLOBAL CAP: prune dead/null entries, then bail if we are already at the cap.
_active = missionNamespace getVariable ["WFBE_FSMOKE_ACTIVE", []];
_pruned = [];
{
	if (!isNil "_x" && {!isNull _x} && {alive _x}) then {_pruned = _pruned + [_x]};
} forEach _active;
_active = _pruned;
if ((count _active) >= (missionNamespace getVariable ["WFBE_C_FSMOKE_MAX", 8])) exitWith {
	missionNamespace setVariable ["WFBE_FSMOKE_ACTIVE", _active];
};

//--- PER-KEY COOLDOWN: coarse 100m grid key so the same spot can't re-trigger spam.
_key = Format ["WFBE_FSMOKE_CD_%1_%2", floor ((_pos select 0) / 100), floor ((_pos select 1) / 100)];
_cd  = missionNamespace getVariable [_key, 0];
if (time < _cd) exitWith {missionNamespace setVariable ["WFBE_FSMOKE_ACTIVE", _active]};
missionNamespace setVariable [_key, time + (missionNamespace getVariable ["WFBE_C_FSMOKE_COOLDOWN", 150])];

//--- Spawn the shell, register it, and schedule a TTL cleanup that also de-lists it.
_s = _color createVehicle _pos;
_active = _active + [_s];
missionNamespace setVariable ["WFBE_FSMOKE_ACTIVE", _active];

[_s] spawn {
	private ["_smk","_list"];
	_smk = _this select 0;
	sleep (missionNamespace getVariable ["WFBE_C_FSMOKE_TTL", 20]);
	if (!isNull _smk) then {deleteVehicle _smk};
	_list = missionNamespace getVariable ["WFBE_FSMOKE_ACTIVE", []];
	missionNamespace setVariable ["WFBE_FSMOKE_ACTIVE", _list - [_smk]];
};
