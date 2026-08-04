if (!(sideJoined Call WFBE_CO_FNC_GetSideHQDeployStatus)) then {
_this addAction [localize "STR_WF_Unlock_MHQ","Client\Action\Action_ToggleLock.sqf", [false], 95, false, true, '', 'alive _target && locked _target'];
_this addAction [localize "STR_WF_Lock_MHQ","Client\Action\Action_ToggleLock.sqf", [true], 94, false, true, '', 'alive _target && !(locked _target)'];
};