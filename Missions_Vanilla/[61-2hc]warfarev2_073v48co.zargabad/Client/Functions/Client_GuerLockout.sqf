//--- fable/guer-lockout (owner 2026-07-07): resistance is "unplayable" for the first
//--- WFBE_C_GUER_LOCKOUT_MIN minutes. Deploy is clamped in GUI_RespawnMenu, buy/gear/Town Actions
//--- are held in GUI_Menu; THIS script confines an alive-at-roundstart insurgent near his start
//--- position with a periodic countdown, then announces activation. 0 = feature off.
Private ["_lockSec","_hold","_left","_m","_s","_lastHint"];

if ((side group player) != resistance) exitWith {};
_lockSec = (missionNamespace getVariable ["WFBE_C_GUER_LOCKOUT_MIN", 0]) * 60;
if (_lockSec <= 0) exitWith {};
if (time >= _lockSec) exitWith {};

waitUntil {sleep 1; alive player || time >= _lockSec};
if (time >= _lockSec) exitWith {};
_hold = getPosASL player;
_lastHint = -60;

while {time < _lockSec} do {
	sleep 2;
	if (alive player) then {
		if ((player distance [_hold select 0, _hold select 1, _hold select 2]) > 150) then {
			player setPosASL _hold;
		};
		if ((time - _lastHint) >= 60) then {
			_lastHint = time;
			_left = _lockSec - time;
			_m = floor (_left / 60);
			_s = floor (_left - (_m * 60));
			hintSilent Format ["RESISTANCE LOCKDOWN\nThe insurgency activates in %1:%2", _m, if (_s < 10) then {"0" + str _s} else {str _s}];
		};
	};
};

hint "RESISTANCE ACTIVATED\nThe insurgency is live - deploy, buying, and the Towns menu are unlocked.";
