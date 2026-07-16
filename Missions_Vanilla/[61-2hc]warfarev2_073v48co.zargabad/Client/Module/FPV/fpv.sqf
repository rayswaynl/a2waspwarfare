Private ['_buildings','_cap','_capDeadline','_capKey','_capValid','_challenge','_challengeKey','_checks','_class','_closest','_cost','_driver','_drone','_funds','_group','_next','_nextKey','_pendingKey','_purchaseStatus','_resultKey','_seatDeadline','_sendFpvToServer','_statusKey','_statusPollAt','_token'];

//--- fable/fpv-strike-drone: player-piloted kamikaze mini-UAV (Tactical Center support call,
//--- sibling of Client\Module\UAV\uav.sqf). Inert unless WFBE_C_FPV_DRONE > 0.
if ((missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]) <= 0) exitWith {};

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

//--- fable/drones-menu hotfix: GUER is base-less - no command centre ever matches, so the null
//--- exit below silently killed EVERY GUER launch. The FPV is a field launch from the operator.
if (sideJoined == resistance) then {_closest = player};

if (isNull _closest) exitWith {};

_cost = missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST", 7500];
if (sideJoined == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_DRONES_MENU", 1]) > 0}) then {_cost = missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000]}; //--- fable/drones-menu: GUER rate $5k

//--- Correctness pre-checks only; Support_FPV.sqf re-derives and enforces both values on the server.
_funds = Call GetPlayerFunds;
if (isNil "_funds" || {typeName _funds != "SCALAR"}) then {_funds = 0};
if (_funds < _cost) exitWith {hint Format ["FPV strike drone needs $%1.", _cost]};
_nextKey = Format ["wfbe_fpv_next_%1", getPlayerUID player];
_next = missionNamespace getVariable [_nextKey, 0];
if (typeName _next != "SCALAR") then {_next = 0};
if (_next > time) exitWith {hint Format ["FPV launcher rearming: %1s.", round (_next - time)]};

_pendingKey = Format ["wfbe_fpv_launch_pending_%1", getPlayerUID player];
if (missionNamespace getVariable [_pendingKey, false]) exitWith {hint "FPV purchase authorization is already pending."};
missionNamespace setVariable [_pendingKey, true];

//--- OA 1.62+ server-only sender. This preserves the existing RequestSpecial/"fpv" route while
//--- keeping the challenge and capability off every other client.
_sendFpvToServer = {
	Private ["_pvf"];
	_pvf = ["SRVFNCRequestSpecial", _this];
	if (!isHostedServer) then {
		WFBE_PVF_RequestSpecial = _pvf;
		publicVariableServer "WFBE_PVF_RequestSpecial";
	} else {
		_pvf Spawn WFBE_SE_FNC_HandlePVF;
	};
};

_capKey = Format ["wfbe_fpv_cap_client_%1", getPlayerUID player];
_challengeKey = Format ["wfbe_fpv_auth_challenge_%1", getPlayerUID player];
_cap = missionNamespace getVariable [_capKey, []];
_capValid = false;
if (typeName _cap == "ARRAY" && {count _cap >= 2}) then {
	if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"}) then {
		if ((_cap select 0) != "" && {(_cap select 1) > time}) then {_capValid = true};
	};
};
if (!_capValid) then {
	_challenge = Format ["%1:%2:%3", getPlayerUID player, floor (diag_tickTime * 1000), floor (random 1000000000)];
	missionNamespace setVariable [_challengeKey, _challenge];
	["fpv","auth",player,_challenge] Call _sendFpvToServer;
	_capDeadline = time + 5;
	waitUntil {
		sleep 0.05;
		_cap = missionNamespace getVariable [_capKey, []];
		_capValid = false;
		if (typeName _cap == "ARRAY" && {count _cap >= 2}) then {
			if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"}) then {
				if ((_cap select 0) != "" && {(_cap select 1) > time}) then {_capValid = true};
			};
		};
		_capValid || {time >= _capDeadline}
	};
	missionNamespace setVariable [_challengeKey, ""];
};
if (!_capValid) exitWith {
	missionNamespace setVariable [_pendingKey, false];
	hint "FPV purchase authorization timed out. Try again.";
};
_token = _cap select 0;

_drone = createVehicle [_class, getPos _closest, [], 0, "FLY"];
if (isNull _drone) exitWith {
	missionNamespace setVariable [_pendingKey, false];
	hint "FPV airframe creation failed. Nothing was charged.";
};
playerFPV = _drone;
_drone setVariable ["wfbe_fpv_armed", true];
//--- Keep the private purchase capability local so the Killed EH can prove which
//--- server-registered drone is requesting its one-shot detonation.
_drone setVariable ["wfbe_fpv_det_cap", _token];
Call Compile Format ["_drone addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]",sideID];
_drone setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';",sideID];
processInitCommands;

//--- Warhead: fires on kill ONLY while armed. Battery-expiry and abort paths disarm first
//--- (fpv_interface.sqf), so a dead battery never gifts a parked bomb.
//--- Server-side detonation (SCUD pattern): the Killed EH sends the exact drone plus
//--- its private capability and observed position. KAT_FPVDetonate validates/consumes
//--- the matching server-side registry entry before creating the warhead.
_drone addEventHandler ['Killed', {
	Private ['_d','_detCap','_p'];
	_d = _this select 0;
	if (_d getVariable ['wfbe_fpv_armed', false]) then {
		_d setVariable ['wfbe_fpv_armed', false];
		_detCap = _d getVariable ['wfbe_fpv_det_cap', ''];
		if (typeName _detCap == 'STRING' && {_detCap != ''}) then {
			_p = getPos _d;
			["RequestSpecial", ["fpv-detonate", [_d, _detCap, [_p select 0, _p select 1, (_p select 2) + 1]]]] Call WFBE_CO_FNC_SendToServer;
		};
	};
}];

_group = [sideJoined, "misc"] Call WFBE_CO_FNC_CreateGroup;
_driver = [missionNamespace getVariable Format ["WFBE_%1PILOT",sideJoinedText],_group,getPos _drone,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
if (isNull _driver) exitWith {
	//--- BUYFAIL guard (same idea as Client_BuildUnit): no pilot = no purchase, nothing charged yet.
	["WARNING", "fpv.sqf: pilot creation failed - aborting FPV purchase."] Call WFBE_CO_FNC_LogContent;
	_drone setVariable ["wfbe_fpv_armed", false];
	deleteVehicle _drone;
	if (!isNull _group && {count units _group == 0}) then {deleteGroup _group};
	playerFPV = objNull;
	missionNamespace setVariable [_pendingKey, false];
};

//--- Same-frame moveIn can fail under client lag. Retry the local move for one second and fail-clean
//--- before asking the server, so a null/unseated pilot never strands playerFPV or an empty group.
_driver moveInDriver _drone;
_seatDeadline = time + 1;
waitUntil {
	sleep 0.05;
	if (vehicle _driver != _drone) then {_driver moveInDriver _drone};
	(vehicle _driver == _drone) || {time >= _seatDeadline} || {isNull _driver} || {isNull _drone}
};
if (isNull _driver || {isNull _drone} || {vehicle _driver != _drone}) exitWith {
	if (!isNull _driver && {!isPlayer _driver}) then {deleteVehicle _driver};
	if (!isNull _drone) then {_drone setVariable ["wfbe_fpv_armed", false]; deleteVehicle _drone};
	if (!isNull _group && {count units _group == 0}) then {deleteGroup _group};
	playerFPV = objNull;
	missionNamespace setVariable [_pendingKey, false];
	hint "FPV pilot could not enter the drone. Nothing was charged.";
};

//--- The player flies it; the AI pilot must never fight.
{_driver disableAI _x} forEach ["TARGET","AUTOTARGET"];

//--- The private one-shot capability authenticates the sender; exact objects bind result cleanup.
_resultKey = Format ["wfbe_fpv_purchase_token_%1", getPlayerUID player];
_statusKey = Format ["wfbe_fpv_purchase_status_%1", getPlayerUID player];
missionNamespace setVariable [_resultKey, _token];
missionNamespace setVariable [_statusKey, 0];
missionNamespace setVariable [_capKey, []];
["fpv","purchase",sideJoined,_drone,clientTeam,player,_driver,_token] Call _sendFpvToServer;

//--- A missing reply is an ambiguous server outcome. Never delete or unlock locally; poll
//--- the server's idempotent token result until an authoritative outcome is replayed.
_statusPollAt = time + 3;
waitUntil {
	sleep 0.05;
	_purchaseStatus = missionNamespace getVariable [_statusKey, 0];
	if (_purchaseStatus == 0 && {time >= _statusPollAt}) then {
		["fpv","status",player,_drone,_driver,_token] Call _sendFpvToServer;
		_statusPollAt = time + 3;
	};
	_purchaseStatus != 0
};
_purchaseStatus = missionNamespace getVariable [_statusKey, 0];
missionNamespace setVariable [_pendingKey, false];
if (_purchaseStatus != 1) exitWith {};
["INFORMATION", Format ["fpv.sqf: FPV strike drone [%1] launched by [%2].", _class, name player]] Call WFBE_CO_FNC_LogContent;

sleep 0.02;

ExecVM "Client\Module\FPV\fpv_interface.sqf";
