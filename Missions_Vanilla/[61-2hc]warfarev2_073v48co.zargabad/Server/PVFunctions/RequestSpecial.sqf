private ["_requestType"];

//--- Block E: RequestSpecial is a broad command bus, so keep the PVF guard to the shared envelope.
if (isNil "_this") exitWith {
	["WARNING", "RequestSpecial.sqf: rejected nil payload."] Call WFBE_CO_FNC_LogContent;
};
if !((typeName _this) in ["ARRAY"]) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected non-array payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if ((count _this) < 1) exitWith {
	["WARNING", "RequestSpecial.sqf: rejected empty payload."] Call WFBE_CO_FNC_LogContent;
};

_requestType = _this select 0;
if !((typeName _requestType) in ["STRING"]) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected non-string request type [%1].", typeName _requestType]] Call WFBE_CO_FNC_LogContent;
};

//--- harden-repair-camp (2026-07-25): "repair-camp" rebuilds a destroyed camp bunker and sets its
//--- side from client-supplied args with NO ownership/proximity check - this generic PVF bus carries
//--- no sender authentication, so a forged ["repair-camp", anyLogic, anySideID] payload could flip
//--- ANY camp to ANY side, for free, from anywhere on the map. Legitimate player repairs
//--- (Action_RepairCamp.sqf / Action_RepairCampEngineer.sqf) now send the caller's own `player`
//--- object as a 4th element; every check below only narrows against that. Flat top-level
//--- `_requestType == "repair-camp" && {...}` guards deliberately avoid nesting inside an
//--- `if () then {}` block (A2 exitWith-in-then-block trap - see a2-sqf-live-burned-traps #7).
//---
//--- NOT gated here: the server-internal presence-repair caller (server_town_camp.sqf, "AI soldiers
//--- repair a destroyed camp by standing in its bubble") drives the SAME case body via a direct
//--- `call HandleSpecial` that never passes through this PVF entrypoint at all - it is unaffected by
//--- (and does not need) this network-ingress gate. Idempotency for BOTH callers is handled inside
//--- Server_HandleSpecial.sqf's repair-camp case via a caller-agnostic reentrancy flag.
if (_requestType == "repair-camp" && {(count _this) < 4}) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected repair-camp short payload (%1 args).", count _this]] Call WFBE_CO_FNC_LogContent;
};
if (_requestType == "repair-camp" && {(!((typeName (_this select 1)) in ["OBJECT"])) || {isNull (_this select 1)}}) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected repair-camp null/invalid logic [%1].", typeName (_this select 1)]] Call WFBE_CO_FNC_LogContent;
};
if (_requestType == "repair-camp" && {!((typeName (_this select 2)) in ["SCALAR"])}) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected repair-camp sideID type [%1].", typeName (_this select 2)]] Call WFBE_CO_FNC_LogContent;
};
if (_requestType == "repair-camp" && {(!((typeName (_this select 3)) in ["OBJECT"])) || {isNull (_this select 3)}}) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected repair-camp null/invalid requester [%1].", typeName (_this select 3)]] Call WFBE_CO_FNC_LogContent;
};
if (_requestType == "repair-camp" && {!(isPlayer (_this select 3))}) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected repair-camp non-player requester [%1].", (_this select 3)]] Call WFBE_CO_FNC_LogContent;
};
if (_requestType == "repair-camp" && {!(alive (_this select 3))}) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected repair-camp dead requester [%1].", name (_this select 3)]] Call WFBE_CO_FNC_LogContent;
};
if (_requestType == "repair-camp" && {((_this select 3) distance (_this select 1)) > (missionNamespace getVariable ["WFBE_C_CAMPS_REPAIR_SERVER_RADIUS", 50])}) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected repair-camp out-of-range requester [%1] dist=%2.", name (_this select 3), (_this select 3) distance (_this select 1)]] Call WFBE_CO_FNC_LogContent;
};
if (_requestType == "repair-camp" && {(side group (_this select 3)) != ((_this select 2) Call WFBE_CO_FNC_GetSideFromID)}) exitWith {
	["WARNING", Format ["RequestSpecial.sqf: rejected repair-camp side mismatch requester=%1 claimedSideID=%2.", side group (_this select 3), (_this select 2)]] Call WFBE_CO_FNC_LogContent;
};

//--- HS-TRACE dispatch breadcrumb (picklist 4 phase 1): last-dispatched case attribution for
//--- the next mid-match burn. Verbose (fires per request, incl. update-clientfps), so gated
//--- behind WFBE_C_HS_DISPATCH_LOG (default 0 = INERT; registered in Init_CommonConstants.sqf).
if ((missionNamespace getVariable ["WFBE_C_HS_DISPATCH_LOG", 0]) > 0) then {
	diag_log Format ["HSDISPATCH|t=%1|type=%2|argc=%3", round time, _requestType, count _this];
};

_this Spawn HandleSpecial;
