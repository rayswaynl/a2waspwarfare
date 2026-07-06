Private ['_action_boom','_action_leave','_defaultTeamswitch','_dgrp','_driver','_drone','_ppColor','_t0','_ttl','_warned'];
_defaultTeamswitch = teamswitchenabled;

_drone = playerFPV;
if (isNull _drone) exitWith {};
_driver = driver _drone;
if (isNull _driver) exitWith {};

WFBE_FPV_Boom = nil;
WFBE_FPV_Terminate = nil;

//--- Possess the pilot: full manual flight on the player's own controls (remoteControl of a
//--- client-local unit, same locality model as the UAV interface's gunner possession).
titletext ["","black in"];
enableteamswitch false;
_drone switchcamera "internal";
player remoteControl _driver;
_drone lock true;

_action_boom = _drone addaction ["DETONATE WARHEAD","Client\Module\FPV\fpv_action.sqf",["boom"],10,false,true,"","true"];
_action_leave = _drone addaction ["Abort flight (self-destruct)","Client\Module\FPV\fpv_action.sqf",["leave"],1,false,true,"","true"];

//--- FPV video-feed tint (same pp idiom as the UAV interface).
_ppColor = ppEffectCreate ["ColorCorrections", 1999];
_ppColor ppEffectEnable true;
_ppColor ppEffectAdjust [1, 1, 0, [1, 1, 1, 0], [1, 1, 1, 0.0], [0.2, 0.2, 0.2, 0]];
_ppColor ppEffectCommit 0;

_ttl = missionNamespace getVariable ["WFBE_C_FPV_DRONE_TTL", 240];
_t0 = time;
_warned = false;
hintSilent Format ["FPV drone airborne. Battery: %1s.\nAction menu: DETONATE WARHEAD / abort.", _ttl];

while {alive _drone && {alive player} && {isNil "WFBE_FPV_Boom"} && {isNil "WFBE_FPV_Terminate"}} do {
	sleep 0.5;
	//--- Impact fuze: a hard knock (collision, ground fire) triggers the warhead even when the
	//--- hit alone would not kill the hull, so clipping a wall still detonates.
	if ((getDammage _drone) >= 0.35) exitWith {WFBE_FPV_Boom = true};
	if ((time - _t0) > _ttl) exitWith {WFBE_FPV_Terminate = true};
	if (!_warned && {(time - _t0) > (_ttl - 30)}) then {_warned = true; hintSilent "FPV battery low: 30 seconds."};
};

//--- Resolve the exit: boom = armed kill (the warhead EH in fpv.sqf fires); every other exit
//--- (battery, abort, pilot death) disarms first, then scuttles - no free parked bomb.
if (alive _drone) then {
	if (!isNil "WFBE_FPV_Boom") then {
		_drone setDammage 1;
	} else {
		_drone setVariable ["wfbe_fpv_armed", false];
		_drone setDammage 1;
		hintSilent "FPV drone lost (battery depleted or aborted).";
	};
};

//--- Release control and restore the player.
objnull remoteControl _driver;
player switchcamera "internal";
enableteamswitch _defaultTeamswitch;
titletext ["","black in"];
ppEffectDestroy _ppColor;
if (!isNull _drone) then {
	_drone removeaction _action_boom;
	_drone removeaction _action_leave;
};

//--- Crew + group cleanup (same group-cap hygiene as uav.sqf SP4).
_dgrp = grpNull;
if (!isNull _driver) then {
	_dgrp = group _driver;
	if (alive _driver) then {_driver setDammage 1};
	deleteVehicle _driver;
};
if (!isNull _dgrp) then {deleteGroup _dgrp};

["INFORMATION", "fpv_interface.sqf: FPV flight ended."] Call WFBE_CO_FNC_LogContent;

WFBE_FPV_Boom = nil;
WFBE_FPV_Terminate = nil;
playerFPV = objNull;
