if (!(sideJoined Call WFBE_CO_FNC_GetSideHQDeployStatus)) then {
private ["_oldActions","_unlockAction","_lockAction"];
_oldActions = _this getVariable ["wfbe_mhq_lock_actions", []];
if (typeName _oldActions == "ARRAY") then {{_this removeAction _x} forEach _oldActions};
_unlockAction = _this addAction [localize "STR_WF_Unlock_MHQ","Client\Action\Action_ToggleLock.sqf", [false], 95, false, true, '', 'alive _target && locked _target'];
_lockAction = _this addAction [localize "STR_WF_Lock_MHQ","Client\Action\Action_ToggleLock.sqf", [true], 94, false, true, '', 'alive _target && !(locked _target)'];
_this setVariable ["wfbe_mhq_lock_actions", [_unlockAction, _lockAction], false];
};