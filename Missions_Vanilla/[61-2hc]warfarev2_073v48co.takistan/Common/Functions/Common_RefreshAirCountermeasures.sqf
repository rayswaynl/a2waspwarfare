/*
	Apply the Flares/Countermeasures upgrade to an aircraft that was already alive
	when the side completed WFBE_UP_FLARESCM.  This runs through setVehicleInit on
	each current machine so the same local incomingMissile handler shape used at
	creation is installed without re-running the full Init_Unit action setup.
*/

private ["_vehicle"];
_vehicle = if (typeName _this == "OBJECT") then {_this} else {objNull};
if (isNull _vehicle || {!alive _vehicle} || {!(_vehicle isKindOf "Air")}) exitWith {};
if (_vehicle getVariable ["wfbe_flarecm_refresh_done", false]) exitWith {};

if ((missionNamespace getVariable ["WFBE_C_MODULE_WFBE_FLARES", 0]) == 1) then {
	_vehicle setVariable ["wfbe_flarecm_refresh_done", true];
	[_vehicle] ExecVM "Client\Module\CM\CM_Set.sqf";
	if (WF_A2_Vanilla) then {
		if (isNil "CM_Countermeasures") then {
			CM_Countermeasures = Compile preprocessFile "Client\Module\CM\CM_Countermeasures.sqf";
			CM_Flares = Compile preprocessFile "Client\Module\CM\CM_Flares.sqf";
			CM_Spoofing = Compile preprocessFile "Client\Module\CM\CM_Spoofing.sqf";
		};
		_vehicle addEventHandler ["incomingMissile", {_this Spawn CM_Countermeasures}];
	} else {
		if (!isNil "WFBE_CL_FNC_AutoCM_OA") then {
			_vehicle addEventHandler ["incomingMissile", {_this Spawn WFBE_CL_FNC_AutoCM_OA}];
		};
	};
};
