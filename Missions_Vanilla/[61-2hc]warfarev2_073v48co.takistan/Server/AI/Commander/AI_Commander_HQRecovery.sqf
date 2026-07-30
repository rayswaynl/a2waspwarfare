/*
    AI commander HQ recovery after a genuine HQ destruction.
    The HQ-loss handler starts this worker only for a side that was under full AI command.
    After the configured grace, the nearest currently owned town centre to the wreck is used.
    The numeric price mirrors the human HQ deploy lobby parameter, but the debit is from the
    separate AI-commander treasury. No town or insufficient funds abandons recovery so the
    normal HQ-loss victory condition resumes.
*/
private ["_side","_logik","_destroyedAt","_delay","_hq","_origin","_sideID","_town","_nearest","_distance","_funds","_price"];

_side = _this;
if ((missionNamespace getVariable ["WFBE_C_AICOM_HQ_REPURCHASE_ENABLE", 0]) <= 0) exitWith {};
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};
if (!(_logik getVariable ["wfbe_aicom_hq_recovery_pending", false])) exitWith {};

_destroyedAt = _logik getVariable ["wfbe_aicom_hq_recovery_destroyed_at", -1];
if (_destroyedAt < 0) exitWith {_logik setVariable ["wfbe_aicom_hq_recovery_pending", false]};
_delay = missionNamespace getVariable ["WFBE_C_AICOM_HQ_REPURCHASE_DELAY", 1200];
if (_delay < 0) then {_delay = 0};

while {!gameOver && {_logik getVariable ["wfbe_aicom_hq_recovery_pending", false]} && {(time - _destroyedAt) < _delay}} do {sleep 5};

if (gameOver || {(missionNamespace getVariable ["WFBE_C_AICOM_HQ_REPURCHASE_ENABLE", 0]) <= 0}) exitWith {
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
};
if (!(_logik getVariable ["wfbe_aicom_hq_recovery_pending", false])) exitWith {};

_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (!isNull _hq && {alive _hq}) exitWith {_logik setVariable ["wfbe_aicom_hq_recovery_pending", false]};
_origin = _logik getVariable "wfbe_aicom_hq_recovery_origin"; //--- r30 getvar-fallback: do NOT default to [0,0,0]
if (isNil "_origin" || {typeName _origin != "ARRAY"} || {count _origin < 2} || {(_origin select 0) == 0 && {(_origin select 1) == 0}}) then {
	//--- Missing/zero origin: fall back to side startpos (public), never world-origin nearest-town.
	_origin = _logik getVariable "wfbe_startpos";
	if (isNil "_origin" || {typeName _origin != "ARRAY"} || {count _origin < 2}) then {_origin = [0,0,0]};
};
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_town = objNull;
_nearest = 1e9;
{
    if ((_x getVariable ["sideID", -1]) == _sideID) then {
        _distance = _x distance _origin;
        if (_distance < _nearest) then {_nearest = _distance; _town = _x};
    };
} forEach towns;

if (isNull _town) exitWith {
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
    ["INFORMATION", Format ["AI_Commander_HQRecovery.sqf: [%1] HQ recovery expired after %2 seconds - no owned town centre.", str _side, _delay]] Call WFBE_CO_FNC_LogContent;
};

_price = missionNamespace getVariable ["WFBE_C_STRUCTURES_HQ_COST_DEPLOY", 500];
_funds = (_side) Call GetAICommanderFunds;
if (_funds < _price) exitWith {
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
    ["INFORMATION", Format ["AI_Commander_HQRecovery.sqf: [%1] HQ recovery expired - AI treasury has %2, needs %3.", str _side, _funds, _price]] Call WFBE_CO_FNC_LogContent;
};

[_side, -_price] Call ChangeAICommanderFunds;
[_side, objNull, getPos _town] Call MHQRepair;
_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (!isNull _hq && {alive _hq}) then {
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
    ["INFORMATION", Format ["AI_Commander_HQRecovery.sqf: [%1] AI repurchased HQ at town centre [%2] for %3 (treasury now %4).", str _side, _town getVariable ["name", "?"], _price, (_side) Call GetAICommanderFunds]] Call WFBE_CO_FNC_LogContent;
} else {
    [_side, _price] Call ChangeAICommanderFunds;
    _logik setVariable ["wfbe_aicom_hq_recovery_pending", false];
    ["WARNING", Format ["AI_Commander_HQRecovery.sqf: [%1] HQ replacement failed at town centre [%2]; refunded %3 to AI treasury.", str _side, _town getVariable ["name", "?"], _price]] Call WFBE_CO_FNC_LogContent;
};
