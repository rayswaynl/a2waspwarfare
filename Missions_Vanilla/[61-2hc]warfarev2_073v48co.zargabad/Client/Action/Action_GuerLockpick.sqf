/*
	Action_GuerLockpick.sqf - fable/guer-field-utils (owner 2026-07-28).
	Timed insurgent lockpick channel on a locked vehicle. Aborts if the picker moves away/mounts/
	dies, the vehicle moves off, dies, or gets unlocked mid-channel. On success mirrors
	Action_ToggleLock.sqf's unlock call (lock false - argument-local call, globally effective lock
	state, same as every other lock write in this mission).
*/

private ["_veh","_t","_dur","_ok","_startPos"];

_veh = _this select 0;
if (isNull _veh || {!alive _veh} || {(locked _veh) == 0}) exitWith {};

_dur = missionNamespace getVariable ["WFBE_C_GUER_LOCKPICK_TIME", 20];
if (_dur < 1) then {_dur = 1};
_startPos = getPos player;
_ok = true;
_t = 0;
while {_t < _dur && _ok} do {
	sleep 1;
	_t = _t + 1;
	if (isNull _veh || {!alive _veh} || {(locked _veh) == 0} || {player distance _veh > 8} || {(getPos player) distance _startPos > 10} || {vehicle player != player} || {!alive player}) then {_ok = false};
	if (_ok) then {hintSilent Format ["Lockpicking... %1%2", floor ((_t / _dur) * 100), "%"]};
};

if (_ok && {!isNull _veh} && {alive _veh} && {(locked _veh) > 0}) then {
	_veh lock false;
	hintSilent "Lock picked - the vehicle is open.";
	diag_log Format ["GUERLOCKPICK|v1|uid=%1|veh=%2|t=%3", getPlayerUID player, typeOf _veh, round time];
} else {
	hintSilent "Lockpicking interrupted.";
};
