//--- Server-authoritative UAV support. The client requests only its side/team; this server
//--- validates the caller's current team state, debits the authoritative wallet, creates the
//--- airframe at the server-derived command centre, then sends it to that player for local control.
if (!isServer) exitWith {};

Private ["_args","_buildings","_checks","_class","_closest","_cooldown","_cooldownKey","_cost","_driver","_funds","_gunner","_last","_operator","_playerTeam","_side","_sideID","_timeStart","_timeout","_uav","_uid"];

_args = _this;
if (typeName _args != "ARRAY" || {count _args < 3}) exitWith { ["WARNING", "Support_UAV.sqf: denied malformed UAV request."] Call WFBE_CO_FNC_LogContent };
_side = _args select 1;
_playerTeam = _args select 2;
if (typeName _side != "SIDE" || {typeName _playerTeam != "GROUP"} || {isNull _playerTeam}) exitWith { ["WARNING", "Support_UAV.sqf: denied invalid UAV requester."] Call WFBE_CO_FNC_LogContent };
if ((side _playerTeam) != _side) exitWith { ["WARNING", "Support_UAV.sqf: denied side/team mismatch."] Call WFBE_CO_FNC_LogContent };
_operator = leader _playerTeam;
if (isNull _operator || {!alive _operator} || {!isPlayer _operator}) exitWith { ["WARNING", "Support_UAV.sqf: denied non-player UAV requester."] Call WFBE_CO_FNC_LogContent };
_uid = getPlayerUID _operator;
if (_uid == "") exitWith { ["WARNING", "Support_UAV.sqf: denied UAV requester without UID."] Call WFBE_CO_FNC_LogContent };

_class = missionNamespace getVariable [Format ["WFBE_%1UAV", str _side], ""];
if (typeName _class != "STRING" || {_class == ""}) exitWith { ["WARNING", "Support_UAV.sqf: denied missing UAV class."] Call WFBE_CO_FNC_LogContent };
_buildings = _side Call WFBE_CO_FNC_GetSideStructures;
_checks = [_side, missionNamespace getVariable Format ["WFBE_%1COMMANDCENTERTYPE", str _side], _buildings] Call GetFactories;
_closest = objNull;
if (count _checks > 0) then {_closest = [_operator, _checks] Call WFBE_CO_FNC_GetClosestEntity};
if (isNull _closest) exitWith { ["INFORMATION", Format ["Support_UAV.sqf: [%1] denied -- no command centre.", str _side]] Call WFBE_CO_FNC_LogContent };

_cost = missionNamespace getVariable ["WFBE_C_PLAYERS_UAV_COST", 12500];
_cooldown = missionNamespace getVariable ["WFBE_C_PLAYERS_UAV_COOLDOWN", 1800];
if (typeName _cost != "SCALAR" || {_cost < 0} || {typeName _cooldown != "SCALAR"} || {_cooldown < 0}) exitWith { ["WARNING", "Support_UAV.sqf: denied invalid UAV cost/cooldown configuration."] Call WFBE_CO_FNC_LogContent };
_cooldownKey = Format ["wfbe_uav_last_%1", str _playerTeam];
_last = missionNamespace getVariable [_cooldownKey, -999999];
if (typeName _last != "SCALAR") then {_last = -999999};
if ((time - _last) < _cooldown) exitWith { ["INFORMATION", Format ["Support_UAV.sqf: [%1] denied -- cooldown (%2s left).", str _side, round (_cooldown - (time - _last))]] Call WFBE_CO_FNC_LogContent };
_funds = _playerTeam getVariable "wfbe_funds";
if (isNil "_funds" || {typeName _funds != "SCALAR"}) then {_funds = 0};
if (_funds < _cost) exitWith { ["INFORMATION", Format ["Support_UAV.sqf: [%1] denied -- insufficient funds (%2 < %3).", str _side, _funds, _cost]] Call WFBE_CO_FNC_LogContent };

//--- Debit and reserve before creation so concurrent client requests cannot obtain a second free hull.
_playerTeam setVariable ["wfbe_funds", (_funds - _cost), true];
[_playerTeam] Call WFBE_SE_FNC_SyncFundsRecord;
missionNamespace setVariable [_cooldownKey, time];

_uav = createVehicle [_class, getPos _closest, [], 0, "FLY"];
//--- Post-debit create fail-clean: restore the reservation if no hull was created.
if (isNull _uav) exitWith {
	_playerTeam setVariable ["wfbe_funds", _funds, true];
	[_playerTeam] Call WFBE_SE_FNC_SyncFundsRecord;
	missionNamespace setVariable [_cooldownKey, _last];
	["WARNING", "Support_UAV.sqf: UAV creation failed after authorization - funds refunded, cooldown restored."] Call WFBE_CO_FNC_LogContent;
};
_sideID = _side Call GetSideID;
Call Compile Format ["_uav addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]", _sideID];
_uav setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';", _sideID];
processInitCommands;

//--- Use the UID-routed broadcast so this works for both OA targeted-PVF and vanilla transports.
[_uid, "HandleSpecial", ["uav-created", _uid, _uav]] Call WFBE_CO_FNC_SendToClients;
["INFORMATION", Format ["Support_UAV.sqf: [%1] team [%2] authorised UAV [%3].", str _side, _playerTeam, _class]] Call WFBE_CO_FNC_LogContent;

_timeStart = time;
_timeout = missionNamespace getVariable ["WFBE_C_UNITS_EMPTY_TIMEOUT", 1800];
while {true} do {
	sleep 5;
	if (!(isPlayer (leader _playerTeam)) || !alive _uav || ((time - _timeStart) > _timeout)) exitWith {};
};

//--- Resolve crew at expiry, after the recipient has created its client-local control group.
_driver = driver _uav;
_gunner = gunner _uav;
if (!isNull _driver) then {if (alive _driver) then {_driver setDammage 1};if (isNil {_driver getVariable "wfbe_trashed"}) then {_driver setVariable ["wfbe_trashed", true];_driver Spawn TrashObject}};
if (!isNull _gunner) then {if (alive _gunner) then {_gunner setDammage 1};if (isNil {_gunner getVariable "wfbe_trashed"}) then {_gunner setVariable ["wfbe_trashed", true];_gunner Spawn TrashObject}};
if (!isNull _uav) then {if (alive _uav) then {_uav setDammage 1};if (isNil {_uav getVariable "wfbe_trashed"}) then {_uav setVariable ["wfbe_trashed", true];_uav Spawn TrashObject}};
