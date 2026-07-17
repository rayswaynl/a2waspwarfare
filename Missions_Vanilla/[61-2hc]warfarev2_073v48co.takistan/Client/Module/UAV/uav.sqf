Private ['_add','_buildings','_built','_cap','_capDeadline','_capKey','_capValid','_challenge','_challengeKey','_checks','_closest','_cost','_cw','_d','_dir','_driver','_funds','_group','_gunner','_lastWP','_lastWPpos','_logic','_pendingKey','_pos','_radius','_resultKey','_sendUavToServer','_spawn','_step','_uav','_waypoints','_wp','_wpcount'];
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

if (isNil {missionNamespace getVariable Format ["WFBE_%1UAV",sideJoinedText]}) exitWith {};
if ((missionNamespace getVariable Format ["WFBE_%1UAV",sideJoinedText]) == "") exitWith {};

_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
_checks = [sideJoined,missionNamespace getVariable Format ["WFBE_%1COMMANDCENTERTYPE",sideJoinedText],_buildings] Call GetFactories;
_closest = objNull;
if (count _checks > 0) then {
	_closest = [player,_checks] Call WFBE_CO_FNC_GetClosestEntity;
};

if (isNull _closest) exitWith {};
_cost = 12500; _funds = Call GetPlayerFunds;
if (isNil "_funds" || {typeName _funds != "SCALAR"}) then {_funds = 0};
if (_funds < _cost) exitWith {hint Format ["UAV needs $%1.", _cost]};
_pendingKey = Format ["wfbe_uav_purchase_pending_%1", getPlayerUID player];
if (missionNamespace getVariable [_pendingKey, false]) exitWith {hint "UAV purchase authorization is already pending."};
missionNamespace setVariable [_pendingKey, true];
_sendUavToServer = {Private ["_pvf"]; _pvf = ["SRVFNCRequestSpecial", _this]; if (!isHostedServer) then {WFBE_PVF_RequestSpecial = _pvf; publicVariableServer "WFBE_PVF_RequestSpecial"} else {_pvf Spawn WFBE_SE_FNC_HandlePVF}};
_capKey = Format ["wfbe_uav_cap_client_%1", getPlayerUID player]; _challengeKey = Format ["wfbe_uav_auth_challenge_%1", getPlayerUID player];
_challenge = Format ["%1:%2:%3", getPlayerUID player, floor (diag_tickTime * 1000), floor (random 1000000000)]; missionNamespace setVariable [_challengeKey, _challenge];
["uav","auth",player,_challenge] Call _sendUavToServer; _capDeadline = time + 5; _cap = []; _capValid = false;
waitUntil {sleep 0.05; _cap = missionNamespace getVariable [_capKey, []]; _capValid = typeName _cap == "ARRAY" && {count _cap >= 2} && {typeName (_cap select 0) == "STRING"} && {typeName (_cap select 1) == "SCALAR"} && {(_cap select 0) != ""} && {(_cap select 1) > time}; _capValid || {time >= _capDeadline}};
missionNamespace setVariable [_challengeKey, ""]; if (!_capValid) exitWith {missionNamespace setVariable [_pendingKey, false]; hint "UAV purchase authorization timed out. Nothing was charged."};

_uav = createVehicle [missionNamespace getVariable Format ["WFBE_%1UAV",sideJoinedText],getPos _closest, [], 0, "FLY"];
playerUAV = _uav;
Call Compile Format ["_uav addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]",sideID];
_uav setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';",sideID];
processInitCommands;

_group = [sideJoined, "misc"] Call WFBE_CO_FNC_CreateGroup;
_driver = [missionNamespace getVariable Format ["WFBE_%1SOLDIER",sideJoinedText],_group,getPos _uav,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
_driver moveInDriver _uav;

//--- Disable targetting.
{(driver playerUAV) disableAI _x} forEach ["TARGET","AUTOTARGET"];

_built = 1;
//--- OPFOR Uav has no gunner slot.
if (sideJoined == west) then {
	_gunner = [missionNamespace getVariable Format ["WFBE_%1SOLDIER",sideJoinedText],_group,getPos _uav,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
	_gunner MoveInGunner _uav;
	_built = _built + 1;
};
_resultKey = Format ["wfbe_uav_purchase_token_%1", getPlayerUID player]; missionNamespace setVariable [_resultKey, _cap select 0]; missionNamespace setVariable [Format ["wfbe_uav_purchase_status_%1", getPlayerUID player], 0];
["uav","purchase",sideJoined,_uav,clientTeam,player,_driver,_gunner,_cap select 0] Call _sendUavToServer;
waitUntil {sleep 0.05; (missionNamespace getVariable [Format ["wfbe_uav_purchase_status_%1", getPlayerUID player], 0]) != 0};
missionNamespace setVariable [_pendingKey, false]; if ((missionNamespace getVariable [Format ["wfbe_uav_purchase_status_%1", getPlayerUID player], 0]) != 1) exitWith {};

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
