private ["_sourceTown"];

_sourceTown = _this select 0;

uiSleep WFBE_CO_VAR_SupplyMissionRegenInterval;

missionNamespace setVariable ["WFBE_Server_PV_IsSupplyMissionActiveInTown", [_sourceTown, false]];
_sourceTown setVariable ["supplyMissionCoolDownEnabled", false, true];

publicVariable "WFBE_Server_PV_IsSupplyMissionActiveInTown";
["INFORMATION", Format ["SupplyMissionTimerForTown.sqf: Supply cooldown expired for town %1.", _sourceTown]] Call WFBE_CO_FNC_LogContent;
