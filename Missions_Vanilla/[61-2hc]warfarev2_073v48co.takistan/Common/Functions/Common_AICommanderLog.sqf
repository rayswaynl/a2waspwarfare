/*
	AI Commander logger - ALWAYS-ON, independent of WF_LOG_CONTENT (which is a
	compile-time define in the generated version.sqf and therefore OFF on live
	servers). The AI commander must stay observable in the RPT at all times.
	Parameters: _this = [type, message] (same signature as WFBE_CO_FNC_LogContent).
	Toggle: WFBE_C_AI_COMMANDER_LOG (Init_CommonConstants, default 1).
*/

private ["_type","_msg"];

_type = _this select 0;
_msg  = _this select 1;

if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOG", 1]) > 0) then {
	diag_log Format ["[AICOM %1] %2", _type, _msg];
};
