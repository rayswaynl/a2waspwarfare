/*
	Restore local Lock/Unlock actions for a player-bought vehicle when its
	buying team is resolved on this client after reconnect or slot reclaim.
*/

Private ["_lockAid","_unlockAid","_vehicle"];
if (typeName _this != "ARRAY" || {count _this != 1}) exitWith {};
_vehicle = _this select 0;
if (typeName _vehicle != "OBJECT" || {isNull _vehicle} || {!alive _vehicle}) exitWith {};
if (isNil {_vehicle getVariable "wfbe_buyteam"}) exitWith {};
if ((_vehicle getVariable "wfbe_buyteam") != group player) exitWith {};

_unlockAid = _vehicle getVariable "wfbe_buyteam_unlock_aid";
if (!isNil "_unlockAid") then {_vehicle removeAction _unlockAid};
_lockAid = _vehicle getVariable "wfbe_buyteam_lock_aid";
if (!isNil "_lockAid") then {_vehicle removeAction _lockAid};

_vehicle setVariable ["wfbe_buyteam_unlock_aid", _vehicle addAction [localize "STR_WF_Unlock", "Client\Action\Action_ToggleLock.sqf", [false], 95, false, true, "", 'alive _target && {!isNil {_target getVariable "wfbe_buyteam"}} && {(_target getVariable "wfbe_buyteam") == group player} && {(locked _target) > 0}']];
_vehicle setVariable ["wfbe_buyteam_lock_aid", _vehicle addAction [localize "STR_WF_Lock", "Client\Action\Action_ToggleLock.sqf", [true], 94, false, true, "", 'alive _target && {!isNil {_target getVariable "wfbe_buyteam"}} && {(_target getVariable "wfbe_buyteam") == group player} && {(locked _target) == 0}']];
