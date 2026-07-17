Private ["_amount","_logik","_side","_syncAicomState"];
_side = _this select 0;
_amount = _this select 1;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
_syncAicomState = (missionNamespace getVariable ["WFBE_C_AICOM_PUBLIC_STATE_SYNC", 0]) > 0;
if (isNull _logik) exitWith {diag_log Format ["AICOMFUNDS|NULL_LOGIK|side=%1|amount=%2", str _side, _amount]}; //--- GUER/two-side maps lack the side logic object; preserve the safe bail but make the rejected delta traceable.
_logik setVariable ["wfbe_aicom_funds", (_side Call GetAICommanderFunds) + _amount, _syncAicomState];
