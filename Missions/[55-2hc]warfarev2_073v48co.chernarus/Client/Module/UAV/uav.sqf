Private ['_add','_buildings','_built','_checks','_closest','_cw','_d','_dir','_driver','_group','_gunner','_lastWP','_lastWPpos','_logic','_pos','_radius','_sorted','_spawn','_step','_uav','_waypoints','_wp','_wpcount'];
_logic = WF_Logic;

if (!isNull playerUAV) then {if (!alive playerUAV) then {playerUAV = objNull}};
if (!isNull playerUAV) exitWith {
	//--- Disable targetting.
	{(driver playerUAV) disableAI _x} forEach ["TARGET","AUTOTARGET"];
	if (WF_A2_Vanilla) then {
		ExecVM "Client\Module\UAV\uav_interface.sqf";
	} else {
		ExecVM "Client\Module\UAV\uav_interface_oa.sqf";
	};
};

//--- Server-authoritative handoff: a normal terminal use requests an airframe only.
//--- The returned server-created object is passed back into this script so the existing client-local
//--- crew/group and terminal controls retain their OA locality semantics.
//--- fix(exitWith-control-flow g1606): request path used bare exitWith inside else{} which only left
//--- the else and fell through to isNull _uav / crew spawn on an unassigned private.
//--- Outer top-scope exitWith always leaves the script after the request attempt; inner call{} gives
//--- early-abort exitWith a real scope (not a then{}) so SendToServer is skipped cleanly.
if (count _this <= 0) exitWith {
	call {
		if (isNil {missionNamespace getVariable Format ["WFBE_%1UAV",sideJoinedText]}) exitWith {};
		if ((missionNamespace getVariable Format ["WFBE_%1UAV",sideJoinedText]) == "") exitWith {};

		_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
		_checks = [sideJoined,missionNamespace getVariable Format ["WFBE_%1COMMANDCENTERTYPE",sideJoinedText],_buildings] Call GetFactories;
		_closest = objNull;
		if (count _checks > 0) then {
			_closest = [player,_checks] Call WFBE_CO_FNC_GetClosestEntity;
		};

		if (isNull _closest) exitWith {};
		["RequestSpecial", ["uav",sideJoined,clientTeam]] Call WFBE_CO_FNC_SendToServer;
	};
};
_uav = _this select 0;

if (isNull _uav) exitWith {};
playerUAV = _uav;


//--- Client crew fail-clean (r34): server already authorised the hull; local CreateGroup/CreateUnit
//--- / seat can still fail. Never stats-count phantom crew; never moveIn on null soldiers.
_group = [sideJoined, "misc"] Call WFBE_CO_FNC_CreateGroup;
if (isNull _group) exitWith {
	["WARNING", "uav.sqf: client crew group create failed - UAV hull retained without local crew."] Call WFBE_CO_FNC_LogContent;
};
_driver = [missionNamespace getVariable Format ["WFBE_%1SOLDIER",sideJoinedText],_group,getPos _uav,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
if (isNull _driver) exitWith {
	deleteGroup _group;
	["WARNING", "uav.sqf: driver CreateUnit failed - abort local UAV crew."] Call WFBE_CO_FNC_LogContent;
};
_driver moveInDriver _uav;
if (driver _uav != _driver) exitWith {
	deleteVehicle _driver;
	deleteGroup _group;
	["WARNING", "uav.sqf: driver moveInDriver failed - abort local UAV crew."] Call WFBE_CO_FNC_LogContent;
};

//--- Disable targetting.
{(driver playerUAV) disableAI _x} forEach ["TARGET","AUTOTARGET"];

_built = 1;
//--- OPFOR Uav has no gunner slot.
if (sideJoined == west) then {
	_gunner = [missionNamespace getVariable Format ["WFBE_%1SOLDIER",sideJoinedText],_group,getPos _uav,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
	if (isNull _gunner) then {
		["WARNING", "uav.sqf: gunner CreateUnit failed - UAV flies driver-only."] Call WFBE_CO_FNC_LogContent;
	} else {
		_gunner MoveInGunner _uav;
		if (gunner _uav == _gunner) then {
			_built = _built + 1;
		} else {
			deleteVehicle _gunner;
			["WARNING", "uav.sqf: gunner moveInGunner failed - UAV flies driver-only."] Call WFBE_CO_FNC_LogContent;
		};
	};
};
//--- Stats only after a seated driver exists.
[sideJoinedText,'UnitsCreated',_built] Call UpdateStatistics;
[sideJoinedText,'VehiclesCreated',1] Call UpdateStatistics;

sleep 0.02;

if ((count units _uav) > 1) then {[driver _uav] join grpnull};

_radius = 1000;
_wpcount = 4;
_step = 360 / _wpcount;
_add = 0;
_cw = true;
_dir = 0;
if !(isNil "_lastWP") then {deleteWaypoint _lastWP};

//--- No need to preprocess those.
if (WF_A2_Vanilla) then {
	ExecVM "Client\Module\UAV\uav_interface.sqf";
} else {
	ExecVM "Client\Module\UAV\uav_interface_oa.sqf";
};
[_uav] ExecVM 'Client\Module\UAV\uav_spotter.sqf';

_spawn = [] spawn {}; //--- Empty spawn
while {alive _uav} do {
	waituntil {waypointDescription [group _uav,currentWaypoint group _uav] != ' ' || !alive _uav};
	terminate _spawn; //--- Terminate spawn from previous loop
	if !(alive _uav) exitWith {};

	_waypoints = waypoints _uav;
	_lastWP = _waypoints select (count _waypoints - 1);
	_lastWPpos = waypointPosition _lastWP;
	deleteWaypoint _lastWP;
	for "_d" from 0 to (360-_step) step _step do
	{
		_add = _d;
		if !(_cw) then {_add = -_d};
		_pos = [_lastWPpos, _radius, _dir+_add] call bis_fnc_relPos;
		_wp = (group _uav) addWaypoint [_pos,0];
		_wp setWaypointType "MOVE";
		_wp setWaypointDescription ' ';
		_wp setWaypointCompletionRadius (1000/_wpcount);
	};

	_spawn = [_uav,_add,_step,_lastWPpos,_radius,_dir,_cw] spawn {
		Private ['_add','_currentWP','_cw','_dir','_lastWPpos','_pos','_radius','_step','_uav','_wp'];
		scriptname "UAV Route planning";
		_uav = _this select 0;
		_add = _this select 1;
		_step = _this select 2;
		_lastWPpos = _this select 3;
		_radius = _this select 4;
		_dir = _this select 5;
		_cw = _this select 6;
		_currentWP = currentWaypoint group _uav;
		while {alive _uav} do {
			waitUntil {_currentWP != currentWaypoint group _uav};
			sleep .01;
			_add = _add + _step;
			if !(_cw) then {_add = -_add};
			_pos = [_lastWPpos, _radius, _dir+_add] call bis_fnc_relPos;
			_wp = (group _uav) addWaypoint [_pos,0];
			_wp setWaypointType "MOVE";
			_wp setWaypointDescription ' ';
			_wp setWaypointCompletionRadius (1000/_wpcount);
			_currentWP = currentWaypoint group _uav;
		};
	};

	_wpcount = count waypoints _uav;
	waitUntil {waypointDescription [group _uav,currentWaypoint group _uav] == ' ' || _wpcount != count waypoints _uav || !alive _uav};
	if (!(alive _uav)||isNull _uav) exitWith {};
};

//--- SP4: delete the UAV crew group(s) so they don't leak toward the 288-group engine cap.
//--- (the driver is split into its own group at line ~56, so clean both.)
private "_dgrp";
_dgrp = group _driver;
{deleteVehicle _x} forEach (units _group + units _dgrp);
deleteGroup _group;
if (!isNull _dgrp && {_dgrp != _group}) then {deleteGroup _dgrp};
