Private ['_buildings','_checks','_class','_closest','_cost','_driver','_drone','_group','_tier'];

//--- fable/fpv-strike-drone: player-piloted kamikaze mini-UAV (Tactical Center support call,
//--- sibling of Client\Module\UAV\uav.sqf). Inert unless WFBE_C_FPV_DRONE > 0.
//--- Optional arg 0: warhead tier "light" | "standard" | "heavy" (default "standard"). The tier
//--- only selects the PRICE here; the warhead is bound SERVER-side at launch (Support_FPV.sqf
//--- whitelist) so a client can never escalate a paid tier or inject an ammo classname.
if ((missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]) <= 0) exitWith {};

_tier = "standard";
if (!isNil "_this") then {
	if ((typeName _this) == "ARRAY") then {
		if ((count _this) > 0) then {
			if ((typeName (_this select 0)) == "STRING") then {
				if ((_this select 0) in ["light","standard","heavy"]) then {_tier = _this select 0};
			};
		};
	};
};

if (!isNull playerFPV) then {if (!alive playerFPV) then {playerFPV = objNull}};
if (!isNull playerFPV) exitWith {hint "You already have an FPV drone in the air."};

_class = missionNamespace getVariable [Format ["WFBE_%1FPVDRONE",sideJoinedText], ""];
if (_class == "") exitWith {};

_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
_checks = [sideJoined,missionNamespace getVariable Format ["WFBE_%1COMMANDCENTERTYPE",sideJoinedText],_buildings] Call GetFactories;
_closest = objNull;
if (count _checks > 0) then {
	_closest = [player,_checks] Call WFBE_CO_FNC_GetClosestEntity;
};

if (isNull _closest) exitWith {};

_cost = missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST", 7500];
if (_tier == "light") then {_cost = missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_LIGHT", 4500]};
if (_tier == "heavy") then {_cost = missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_HEAVY", 12500]};

_drone = createVehicle [_class, getPos _closest, [], 0, "FLY"];
playerFPV = _drone;
_drone setVariable ["wfbe_fpv_armed", true];
Call Compile Format ["_drone addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]",sideID];
_drone setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf'; if ((missionNamespace getVariable ['WFBE_C_FPV_DRONE_MARK',1]) > 0) then {this spawn {private ['_v','_l','_on']; _v = _this; _l = '#lightpoint' createVehicleLocal (position _v); _l attachTo [_v,[0,0,0.4]]; _l setLightColor [1.0,0.25,0.05]; _l setLightAmbient [1.0,0.25,0.05]; _on = true; while {alive _v} do {_l setLightBrightness (if (_on) then {0.06} else {0.004}); _on = !_on; sleep 0.45}; deleteVehicle _l}};",sideID];
processInitCommands;

//--- Warhead: fires on kill ONLY while armed. Battery-expiry and abort paths disarm first
//--- (fpv_interface.sqf), so a dead battery never gifts a parked bomb.
//--- Server-side detonation (SCUD pattern): the Killed EH sends the impact pos to the server;
//--- KAT_FPVDetonate creates the warhead server-side so damage is globally authoritative.
_drone addEventHandler ['Killed', {
	Private ['_d','_p'];
	_d = _this select 0;
	if (_d getVariable ['wfbe_fpv_armed', false]) then {
		_d setVariable ['wfbe_fpv_armed', false];
		_p = getPos _d;
		["RequestSpecial", ["fpv-detonate", [_p select 0, _p select 1, (_p select 2) + 1]]] Call WFBE_CO_FNC_SendToServer;
	};
}];

_group = [sideJoined, "misc"] Call WFBE_CO_FNC_CreateGroup;
_driver = [missionNamespace getVariable Format ["WFBE_%1PILOT",sideJoinedText],_group,getPos _drone,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
if (isNull _driver) exitWith {
	//--- BUYFAIL guard (same idea as Client_BuildUnit): no pilot = no purchase, nothing charged yet.
	["WARNING", "fpv.sqf: pilot creation failed - aborting FPV purchase."] Call WFBE_CO_FNC_LogContent;
	_drone setVariable ["wfbe_fpv_armed", false];
	deleteVehicle _drone;
	playerFPV = objNull;
};
_driver moveInDriver _drone;

//--- The player flies it; the AI pilot must never fight.
{_driver disableAI _x} forEach ["TARGET","AUTOTARGET"];

[sideJoinedText,'UnitsCreated',1] Call UpdateStatistics;
[sideJoinedText,'VehiclesCreated',1] Call UpdateStatistics;

-(_cost) Call ChangePlayerFunds;

["RequestSpecial", ["fpv",sideJoined,_drone,clientTeam,_tier]] Call WFBE_CO_FNC_SendToServer;
["INFORMATION", Format ["fpv.sqf: FPV strike drone [%1] tier [%2] launched by [%3].", _class, _tier, name player]] Call WFBE_CO_FNC_LogContent;

sleep 0.02;

ExecVM "Client\Module\FPV\fpv_interface.sqf";
