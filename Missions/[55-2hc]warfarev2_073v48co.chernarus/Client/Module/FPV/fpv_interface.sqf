Private ['_action_boom','_action_leave','_defaultTeamswitch','_dgrp','_driver','_drone','_firstFlightShown','_ppColor','_t0','_ttl','_warned'];
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
//--- fable/fpv-spawn-safety: impact-fuze arming delay + the damage baseline captured when it arms.
Private ["_fpvArmDelay","_fpvArmDmg","_fpvArmed"];
_fpvArmDelay = missionNamespace getVariable ["WFBE_C_FPV_ARM_DELAY", 3];
_fpvArmDmg = -1;
hintSilent Format ["FPV drone airborne. Battery: %1s.\nAction menu: DETONATE WARHEAD / abort.", _ttl];

//--- fable/drones-menu: one-time first-flight drill (per profile, TAGS persistence idiom).
//--- Sanitize corrupt profile data before the BOOL-only negation.
_firstFlightShown = profileNamespace getVariable ["WFBE_FPV_FIRSTFLIGHT_SHOWN", false];
if (typeName _firstFlightShown != "BOOL") then {_firstFlightShown = false};
if (!_firstFlightShown) then {
	if (!isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_FPV_FIRSTFLIGHT_SHOWN", true] Call WFBE_CO_FNC_SetProfileVariable; if !(isNil "WFBE_CO_FNC_SaveProfile") then {Call WFBE_CO_FNC_SaveProfile}};
	hint parseText "<t size='1.1' color='#ffd24d'>FPV STRIKE DRONE - FIRST FLIGHT</t><br/><br/>You ARE the drone now - fly it like a light helicopter. Your body stays safe where you launched.<br/><br/><t color='#ffd24d'>DETONATE WARHEAD</t> (action menu) - ram your target; an armed crash detonates too.<br/><t color='#ffd24d'>Abort flight</t> - safe self-destruct, no warhead.<br/><br/>The battery is your flight time - at zero the drone is lost. After each flight the launcher rearms before the next buy.";
};

while {alive _drone && {alive player} && {isNil "WFBE_FPV_Boom"} && {isNil "WFBE_FPV_Terminate"}} do {
	sleep 0.5;
	//--- Impact fuze: a hard knock (collision, ground fire) triggers the warhead even when the
	//--- hit alone would not kill the hull, so clipping a wall still detonates.
	//--- fable/fpv-spawn-safety part 2 of 3: the fuze went live on the very first 0.5s tick, so any
	//--- damage carried off the spawn pad (clipping the anchor building or another drone) detonated
	//--- the warhead before the pilot had control. Hold the fuze for a short arming delay AND
	//--- measure damage as a DELTA from what the airframe already had once armed, so pre-existing
	//--- spawn scuffing can never count as an impact. A real hit still trips it instantly.
	_fpvArmed = ((time - _t0) >= _fpvArmDelay);
	if (_fpvArmed && {_fpvArmDmg < 0}) then {_fpvArmDmg = getDammage _drone};
	//--- Flat exitWith on purpose: a nested exitWith would leave only the inner block, not this loop.
	if (_fpvArmed && {_fpvArmDmg >= 0} && {((getDammage _drone) - _fpvArmDmg) >= 0.35}) exitWith {WFBE_FPV_Boom = true};
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
if (playerFPV == _drone) then {playerFPV = objNull};
