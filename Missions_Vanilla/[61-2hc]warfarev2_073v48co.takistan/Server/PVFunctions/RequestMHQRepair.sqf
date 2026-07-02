private ["_guardSide","_guardLogik","_guardHQ"];

//--- DR-6: always-on authority guards for RequestMHQRepair PVF.
//--- _this is a raw SIDE value (sent via ["RequestMHQRepair", sideJoined] Call WFBE_CO_FNC_SendToServer).
if (typeName _this != "SIDE") exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: DR-6 rejected - _this is not SIDE [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
_guardSide = _this;
if (_guardSide != west && {_guardSide != east}) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: DR-6 rejected - side [%1] not west/east.", str _guardSide]] Call WFBE_CO_FNC_LogContent;
};
_guardLogik = _guardSide Call WFBE_CO_FNC_GetSideLogic;
if (isNull _guardLogik) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: DR-6 rejected - GetSideLogic returned null for [%1].", str _guardSide]] Call WFBE_CO_FNC_LogContent;
};
_guardHQ = _guardSide Call WFBE_CO_FNC_GetSideHQ;
if (!isNull _guardHQ && {alive _guardHQ}) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: DR-6 rejected - HQ is still alive for [%1]; cannot repair a live HQ.", str _guardSide]] Call WFBE_CO_FNC_LogContent;
};
if (_guardLogik getVariable ["wfbe_hq_repairing", false]) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: DR-6 rejected - repair already in progress for [%1].", str _guardSide]] Call WFBE_CO_FNC_LogContent;
};
if ((_guardLogik getVariable ["wfbe_hq_repair_count", 1]) >= 3) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: DR-6 rejected - repair cap reached for [%1] (repair_count >= 3).", str _guardSide]] Call WFBE_CO_FNC_LogContent;
};
//--- DR-6 guards passed.
[_this] Spawn MHQRepair;