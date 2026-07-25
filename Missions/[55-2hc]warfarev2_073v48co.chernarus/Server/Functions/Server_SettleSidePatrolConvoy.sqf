Private ["_cState","_cSideID","_cTown","_cDispatchID","_cLdr","_cTruck","_cSide","_cRegistry","_cEntryIndex","_cEntry","_cPaid","_cNow","_cCdKey","_cCountVar","_cRoundCount","_cPool","_cCount","_cShare"];
if (!isServer) exitWith {false};
if (typeName _this != "ARRAY" || {count _this != 5}) exitWith {false};
_cSideID = _this select 0; _cTown = _this select 1; _cDispatchID = _this select 2; _cLdr = _this select 3; _cTruck = _this select 4;
_cState = [_cSideID, _cTown, _cDispatchID, _cLdr, _cTruck] Call WFBE_SE_FNC_GetSidePatrolConvoy;
if (typeName _cState != "ARRAY" || {count _cState < 12} || {!(_cState select 0)}) exitWith {false};
_cSide = _cState select 1; _cRegistry = _cState select 2; _cEntryIndex = _cState select 3; _cEntry = _cState select 4; _cPaid = _cState select 7; _cCdKey = _cState select 8; _cNow = _cState select 9; _cCountVar = _cState select 10; _cRoundCount = _cState select 11;
_cPaid set [count _cPaid, _cTown]; _cEntry set [3, _cPaid]; _cRegistry set [_cEntryIndex, _cEntry]; missionNamespace setVariable ["WFBE_ACTIVE_PATROLS", _cRegistry]; publicVariable "WFBE_ACTIVE_PATROLS";
_cTown setVariable [_cCdKey, _cNow, false]; missionNamespace setVariable [_cCountVar, _cRoundCount + 1];
_cPool = if (isNil "WFBE_C_PATROL_CONVOY_PAY") then {750} else {WFBE_C_PATROL_CONVOY_PAY}; _cCount = 0;
{if ((isPlayer _x) && (alive _x) && (side _x == _cSide)) then {_cCount = _cCount + 1}} forEach playableUnits;
_cShare = round (_cPool / (_cCount max 1)); [_cSide, "BankPayout", [_cShare]] Call WFBE_CO_FNC_SendToClients; [_cSide, _cShare] Call WFBE_SE_FNC_CreditSidePlayers;
["INFORMATION", Format ["Server_SettleSidePatrolConvoy.sqf: [%1] convoy payout $%2 x %3 players at [%4].", str _cSide, _cShare, _cTown getVariable ["name", "?"]]] Call WFBE_CO_FNC_LogContent;
true
