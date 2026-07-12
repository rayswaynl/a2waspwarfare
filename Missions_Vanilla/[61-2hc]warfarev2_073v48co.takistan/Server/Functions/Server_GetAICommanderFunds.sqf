//--- NIL-GUARD (mirrors Common_GetTeamFunds.sqf): wfbe_aicom_funds is nil until the wallet is first
//--- funded, and a null side-logic object (GUER / two-side maps) yields nil too. Returning nil here makes
//--- every caller's `... + _amount` arithmetic destroy the wallet (cf Server_ChangeAICommanderFunds:7, which
//--- calls this) or hard-error. Treat a missing/non-numeric balance as 0. A2-OA-1.64 safe (getVariable /
//--- typeName == / plain arithmetic).
private ["_logik","_funds"];
_logik = _this Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {0};
_funds = _logik getVariable "wfbe_aicom_funds";
if (isNil "_funds" || {typeName _funds != "SCALAR"}) exitWith {0};
_funds
