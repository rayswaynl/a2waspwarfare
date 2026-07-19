/*
	Server-authoritative UAV2 Forward FOB request.
	Auth phase: ["auth", player, repairTruck, privateChallenge].
	Build phase: ["build", uid, oneShotToken, advisoryPosition]. The server derives the
	player and repair truck from the private capability; no client object identifies the buyer.
*/
private ["_request","_mode","_player","_truck","_clientPos","_uid","_token","_capKey","_cap","_capAccepted","_side","_serverPos","_buildDist","_reserveKey","_reserveUntil","_reserved","_reject","_message","_sideKey","_registry","_live","_spacing","_nearFOB","_sideLogic","_areas","_nearBase","_baseExclusion","_team","_funds","_cost","_tentClass","_tent","_mast","_mastPos","_campGroup","_campLogic","_spawnOK","_sideID","_probeOk","_workerArgs"];

if (!isServer) exitWith {};
if (!((missionNamespace getVariable ["WFBE_C_UAV2_FOB", 0]) > 0)) exitWith {};
_request = _this;
if (typeName _request != "ARRAY" || {count _request < 1}) exitWith {};
_mode = _request select 0;
if (typeName _mode != "STRING") exitWith {};

//--- Senderless-bus handshake: validate the nominated objects, mint/reuse a short capability,
//--- and return it only to owner(player) on a dedicated private PV. The echoed challenge lets
//--- that owner reject tokens triggered by another client nominating the same player object.
if (_mode == "auth") exitWith {
	private ["_authPlayer","_authTruck","_challenge","_authUID","_capValid","_expires","_replyID","_pvf"];
	if (count _request < 4) exitWith {};
	_authPlayer = _request select 1;
	_authTruck = _request select 2;
	_challenge = _request select 3;
	if (typeName _authPlayer != "OBJECT" || {isNull _authPlayer} || {!isPlayer _authPlayer} || {!alive _authPlayer}) exitWith {};
	if (typeName _authTruck != "OBJECT" || {isNull _authTruck} || {!alive _authTruck}) exitWith {};
	if (typeName _challenge != "STRING" || {_challenge == ""} || {(count toArray _challenge) > 96}) exitWith {};
	if !([_authPlayer, _authTruck] Call WFBE_CO_FNC_CanUseUAV2FOB) exitWith {};
	_authUID = getPlayerUID _authPlayer;
	if (_authUID == "") exitWith {};
	_capKey = Format ["wfbe_uav2_fob_cap_server_%1", _authUID];
	_cap = missionNamespace getVariable [_capKey, []];
	_capValid = false;
	if (typeName _cap == "ARRAY" && {count _cap >= 4}) then {
		if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"} && {typeName (_cap select 2) == "OBJECT"} && {typeName (_cap select 3) == "OBJECT"}) then {
			if ((_cap select 0) != "" && {(_cap select 1) > time} && {(_cap select 2) == _authPlayer} && {(_cap select 3) == _authTruck}) then {_capValid = true};
		};
	};
	if (_capValid) then {
		_token = _cap select 0;
		_expires = _cap select 1;
	} else {
		_token = Format ["%1:%2:%3:%4", _authUID, floor (diag_tickTime * 1000), floor (random 1000000000), floor (random 1000000000)];
		_expires = time + 15;
		_cap = [_token, _expires, _authPlayer, _authTruck];
		missionNamespace setVariable [_capKey, _cap];
	};
	_replyID = owner _authPlayer;
	_pvf = [_authUID, "CLTFNCHandleSpecial", ["uav2-fob-auth-token", _token, _expires, _challenge, _authTruck]];
	if (!isHostedServer) then {
		if (_replyID > 0) then {isNil {WFBE_PVF_UAV2FOBPrivate = _pvf; _replyID publicVariableClient "WFBE_PVF_UAV2FOBPrivate"}};
	} else {
		_pvf Spawn WFBE_CL_FNC_HandlePVF;
		if (isMultiplayer && {_replyID > 0}) then {isNil {WFBE_PVF_UAV2FOBPrivate = _pvf; _replyID publicVariableClient "WFBE_PVF_UAV2FOBPrivate"}};
	};
};

if (_mode != "build" || {count _request < 4}) exitWith {};
_uid = _request select 1;
_token = _request select 2;
_clientPos = _request select 3;
if (typeName _uid != "STRING" || {_uid == ""}) exitWith {};
if (typeName _token != "STRING" || {_token == ""}) exitWith {};

//--- Atomically compare-consume the secret and derive both authority objects from server state.
_player = objNull;
_truck = objNull;
_capKey = Format ["wfbe_uav2_fob_cap_server_%1", _uid];
_capAccepted = false;
isNil {
	_cap = missionNamespace getVariable [_capKey, []];
	if (typeName _cap == "ARRAY" && {count _cap >= 4}) then {
		if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"} && {typeName (_cap select 2) == "OBJECT"} && {typeName (_cap select 3) == "OBJECT"}) then {
			if ((_cap select 0) == _token && {(_cap select 1) > time} && {getPlayerUID (_cap select 2) == _uid}) then {
				_player = _cap select 2;
				_truck = _cap select 3;
				missionNamespace setVariable [_capKey, []];
				_capAccepted = true;
			};
		};
	};
};
if (!_capAccepted) exitWith {["WARNING", Format ["RequestUAV2FOB.sqf: rejected invalid capability for UID [%1].", _uid]] Call WFBE_CO_FNC_LogContent};
if (isNull _player || {!isPlayer _player} || {!alive _player} || {isNull _truck} || {!alive _truck}) exitWith {};
if !([_player, _truck] Call WFBE_CO_FNC_CanUseUAV2FOB) exitWith {
	[_player, "LocalizeMessage", ["Wildcard", "UAV2 FOB rejected: Engineer, repair truck and UAV level 2 are required."]] Call WFBE_CO_FNC_SendToClient;
};

_side = side (group _player);
_buildDist = missionNamespace getVariable ["WFBE_C_UAV2_FOB_BUILD_DIST", 22];
_serverPos = _truck modelToWorld [0, _buildDist, 0];
_serverPos set [2, 0];
if (typeName _clientPos != "ARRAY" || {count _clientPos < 2} || {_clientPos distance _serverPos > 5}) exitWith {
	["WARNING", Format ["RequestUAV2FOB.sqf: advisory position mismatch for %1 - rejected.", getPlayerUID _player]] Call WFBE_CO_FNC_LogContent;
};
if (surfaceIsWater _serverPos) exitWith {
	[_player, "LocalizeMessage", ["Wildcard", "UAV2 FOB rejected: deployment point is in water."]] Call WFBE_CO_FNC_SendToClient;
};

//--- Acquire a short per-side unscheduled reservation. There are no sleeps in the transaction below.
_reserveKey = Format ["wfbe_uav2_fob_reserve_%1", str _side];
_reserved = false;
isNil {
	_reserveUntil = missionNamespace getVariable [_reserveKey, 0];
	if (typeName _reserveUntil != "SCALAR") then {_reserveUntil = 0};
	if (_reserveUntil <= time) then {
		missionNamespace setVariable [_reserveKey, time + 10];
		_reserved = true;
	};
};
if (!_reserved) exitWith {
	[_player, "LocalizeMessage", ["Wildcard", "Another UAV2 FOB request is being processed. Try again."]] Call WFBE_CO_FNC_SendToClient;
};

_reject = false;
_message = "";
_sideKey = Format ["wfbe_uav2_fobs_%1", str _side];
_registry = missionNamespace getVariable [_sideKey, []];
_live = [];
{if (!isNull _x && {alive _x}) then {_live = _live + [_x]}} forEach _registry;
_cap = missionNamespace getVariable ["WFBE_C_UAV2_FOB_CAP", 2];
if (typeName _cap != "SCALAR" || {_cap < 1} || {count _live >= _cap}) then {_reject = true; _message = "UAV2 FOB rejected: side cap reached."};

if (!_reject) then {
	_spacing = missionNamespace getVariable ["WFBE_C_UAV2_FOB_SPACING", 250];
	_nearFOB = [_serverPos, _live] Call WFBE_CO_FNC_GetClosestEntity;
	if (!isNull _nearFOB && {_nearFOB distance _serverPos < _spacing}) then {_reject = true; _message = "UAV2 FOB rejected: too close to another Forward FOB."};
};

if (!_reject) then {
	_sideLogic = (_side) Call WFBE_CO_FNC_GetSideLogic;
	_areas = _sideLogic getVariable "wfbe_basearea";
	if (isNil "_areas") then {_areas = []};
	_nearBase = [_serverPos, _areas] Call WFBE_CO_FNC_GetClosestEntity;
	_baseExclusion = missionNamespace getVariable ["WFBE_C_UAV2_FOB_BASE_EXCLUSION", 370];
	if (!isNull _nearBase && {_nearBase distance _serverPos < _baseExclusion}) then {_reject = true; _message = "UAV2 FOB rejected: too close to a base area."};
};

_team = group _player;
_cost = missionNamespace getVariable ["WFBE_C_UAV2_FOB_COST", 25000];
_tentClass = missionNamespace getVariable [Format ["WFBE_%1FARP", str _side], ""];
if (_tentClass == "") then {_tentClass = if (_side == east) then {"CampEast_EP1"} else {"Camp_EP1"}};
if (!_reject && {!(isClass (configFile >> "CfgVehicles" >> _tentClass)) || {!(isClass (configFile >> "CfgVehicles" >> "Land_Vysilac_FM"))}}) then {_reject = true; _message = "UAV2 FOB rejected: required Forward FOB classes are unavailable."};
if (!_reject) then {
	_funds = _team getVariable "wfbe_funds";
	if (isNil "_funds" || {typeName _funds != "SCALAR"} || {typeName _cost != "SCALAR"} || {_cost < 0} || {_funds < _cost}) then {_reject = true; _message = Format ["UAV2 FOB rejected: %1 funds required.", _cost]};
};

if (!_reject) then {
	[_team, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds;
	_tent = objNull;
	_mast = objNull;
	_campGroup = grpNull;
	_campLogic = objNull;
	_spawnOK = true;

	_tent = createVehicle [_tentClass, _serverPos, [], 0, "NONE"];
	if (isNull _tent) then {_spawnOK = false};
	if (_spawnOK) then {
		_tent setDir (getDir _truck);
		_tent setPos _serverPos;
		_mastPos = _tent modelToWorld [8, 0, 0];
		_mastPos set [2, 0];
		_mast = createVehicle ["Land_Vysilac_FM", _mastPos, [], 0, "NONE"];
		if (isNull _mast) then {_spawnOK = false} else {_mast setPos _mastPos};
	};
	if (_spawnOK) then {
		_campGroup = createGroup sideLogic;
		if (isNull _campGroup) then {_spawnOK = false};
	};
	if (_spawnOK) then {
		_campLogic = _campGroup createUnit ["LocationLogicCamp", _serverPos, [], 0, "NONE"];
		if (isNull _campLogic) then {_spawnOK = false};
	};

	//--- Debit is already authoritative. Any partial engine creation failure is one transaction:
	//--- remove each partial exactly once, refund exactly once, release the reservation, and exit
	//--- before any registry/respawn state is published.
	if (!_spawnOK) exitWith {
		if (!isNull _campLogic) then {deleteVehicle _campLogic};
		if (!isNull _campGroup) then {deleteGroup _campGroup};
		if (!isNull _mast) then {deleteVehicle _mast};
		if (!isNull _tent) then {deleteVehicle _tent};
		[_team, _cost] Call WFBE_CO_FNC_ChangeTeamFunds;
		missionNamespace setVariable [_reserveKey, 0];
		diag_log (Format ["UAV2FOB|v1|BUILDFAIL|refunded=%1|uid=%2", _cost, _uid]);
		[_player, "LocalizeMessage", ["Wildcard", "UAV2 FOB creation failed; funds refunded."]] Call WFBE_CO_FNC_SendToClient;
	};

	_campLogic setPos _serverPos;
	_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
	_campLogic setVariable ["sideID", _sideID, true];
	_campLogic setVariable ["supplyValue", 0, true];
	_campLogic setVariable ["wfbe_camp_bunker", _tent, true];
	_campLogic setVariable ["town", _campLogic, true];
	_campLogic setVariable ["wfbe_uav2_fob", true, true];
	_tent setVariable ["wfbe_uav2_fob_logic", _campLogic];
	_tent setVariable ["wfbe_uav2_fob_mast", _mast];
	_tent setVariable ["wfbe_uav2_fob_side", _side, true];

	_registry = _live + [_tent];
	missionNamespace setVariable [_sideKey, _registry];
	if ((missionNamespace getVariable ["WFBE_C_UAV2_FOB_CONSUME_TRUCK", 0]) > 0 && {!isNull _truck}) then {deleteVehicle _truck};

	_workerArgs = [_campLogic, _tent, _mast, _side, _sideKey];
	_workerArgs Spawn {
		private ["_campLogic","_campGroup","_tent","_mast","_side","_sideKey","_interval","_repairRadius","_repairStep","_pingRadius","_vehicles","_crew","_hostiles","_registry"];
		_campLogic = _this select 0; _campGroup = group _campLogic; _tent = _this select 1; _mast = _this select 2; _side = _this select 3; _sideKey = _this select 4;
		_interval = (missionNamespace getVariable ["WFBE_C_UAV2_FOB_WORKER_INTERVAL", 10]) max 5;
		_repairRadius = (missionNamespace getVariable ["WFBE_C_UAV2_FOB_REPAIR_RADIUS", 30]) max 5;
		_repairStep = ((missionNamespace getVariable ["WFBE_C_UAV2_FOB_REPAIR_STEP", 0.02]) max 0) min 0.1;
		_pingRadius = (missionNamespace getVariable ["WFBE_C_UAV2_FOB_PING_RADIUS", 300]) max 0;
		while {alive _tent} do {
			_vehicles = _tent nearEntities ["LandVehicle", _repairRadius];
			{
				_crew = crew _x;
				if (alive _x && {count _crew > 0} && {side (group (_crew select 0)) == _side} && {getDammage _x > 0}) then {_x setDammage ((getDammage _x - _repairStep) max 0)};
			} forEach _vehicles;
			_hostiles = [_tent, if (_side == west) then {[east]} else {[west]}, _pingRadius] Call GetHostilesInArea;
			if (_hostiles > 0) then {diag_log (Format ["UAV2FOB|v1|PING|side=%1|hostiles=%2|pos=%3", str _side, _hostiles, getPos _tent])};
			sleep _interval;
		};
		if (!isNull _mast) then {deleteVehicle _mast};
		if (!isNull _campLogic) then {deleteVehicle _campLogic};
		if (!isNull _campGroup) then {deleteGroup _campGroup};
		_registry = missionNamespace getVariable [_sideKey, []];
		_registry = _registry - [_tent];
		missionNamespace setVariable [_sideKey, _registry];
	};

	_probeOk = _campLogic in (_serverPos nearEntities [WFBE_Logic_Camp, 50]);
	if (_probeOk) then {
		diag_log (Format ["UAV2FOB|v1|FOBCAMPPROBE|ok|side=%1|pos=%2", str _side, _serverPos]);
	} else {
		diag_log (Format ["UAV2FOB|v1|FOBCAMPPROBE|FAILED|side=%1|pos=%2", str _side, _serverPos]);
	};
	[_player, "LocalizeMessage", ["Wildcard", Format ["UAV2 Forward FOB deployed for %1 funds.", _cost]]] Call WFBE_CO_FNC_SendToClient;
};

missionNamespace setVariable [_reserveKey, 0];
if (_reject) then {[_player, "LocalizeMessage", ["Wildcard", _message]] Call WFBE_CO_FNC_SendToClient};
