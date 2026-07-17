/*
	Action_BuildForwardFOB.sqf - "Build Forward FOB" addAction handler (flag WFBE_C_STRUCTURES_FOB, 2026-07-17).

	Attached to a WEST/EAST supply truck in Common\Init\Init_Unit.sqf when the flag is on. Resolves a build
	point a short distance in front of the truck, runs client-side PRE-checks (funds / cap / base-area
	placement) purely for instant feedback, then asks the SERVER to build authoritatively - Server\PVFunctions\
	RequestForwardFOB.sqf re-validates all three (this client side is advisory and spoofable) and constructs.
	Mirrors the action->request->construct shape of Client\Action\Action_BuildFOB.sqf (GUER FOB), minus its
	token economy: owner ruling 2 is cash-priced, capped, and has no commander gate.

	A2 OA 1.64 safe: array-form private only, no params/pushBack/isEqualType, lazy && {} short-circuit,
	1-arg getVariable on the side logic (it may be a Group - the GROUPGETVAR trap).

	_this = [target(truck), caller(player), actionId, args]
*/
private ["_truck","_player","_side","_dir","_pos","_cost","_cap","_live","_logik","_areas","_near","_minRange"];

_truck  = _this select 0;
_player = _this select 1;

if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_FOB", 0]) <= 0) exitWith {};
if (isNull _truck || {!alive _truck}) exitWith {};

_side = side group player;
if !(_side in [west, east]) exitWith {};

//--- Funds. Cash, not side supply - the Radio Tower cash-priced-structure precedent
//--- (Client\Module\CoIn\coin_interface.sqf:722-725). The server owns the real charge.
_cost = missionNamespace getVariable ["WFBE_C_FOB_COST", 25000];
if ((Call WFBE_CL_FNC_GetClientFunds) < _cost) exitWith {
	titleText [Format ["Forward FOB costs $%1 - not enough cash.", _cost], "PLAIN DOWN"];
};

//--- Per-side alive cap. Server-authoritative; this is only the instant-feedback mirror of the
//--- broadcast count RequestForwardFOB.sqf / Server_ForwardFOBKilled.sqf publish.
_cap  = missionNamespace getVariable ["WFBE_C_FOB_CAP_PER_SIDE", 2];
_live = missionNamespace getVariable [Format ["WFBE_FOB_%1_COUNT", str _side], 0];
if (_live >= _cap) exitWith {
	titleText [Format ["Your side already has the maximum of %1 Forward FOBs - lose one before building another.", _cap], "PLAIN DOWN"];
};

//--- Placement: WFBE_C_FOB_BUILD_DIST metres directly in front of the truck, snapped to ground
//--- (z=0 in a 3-element array IS the ATL ground literal on A2 OA - Init_Town.sqf:126-128).
_dir = getDir _truck;
_pos = _truck modelToWorld [0, (missionNamespace getVariable ["WFBE_C_FOB_BUILD_DIST", 22]), 0];
_pos set [2, 0];

//--- No-build near a base area: reuses the 250+120=370m spacing idiom from
//--- Server\Construction\Construction_HQSite.sqf:43-49 so a FOB cannot be stacked on the HQ.
_minRange = missionNamespace getVariable ["WFBE_C_FOB_MIN_RANGE", 370];
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
_areas = _logik getVariable "wfbe_basearea";
if (isNil "_areas") then {_areas = []};
_near = [_pos, _areas] Call WFBE_CO_FNC_GetClosestEntity;
if (!isNull _near && {(_near distance _pos) < _minRange}) exitWith {
	titleText [Format ["Too close to base - a Forward FOB must be at least %1m from your base area.", _minRange], "PLAIN DOWN"];
};

["RequestForwardFOB", [_pos, _dir, _truck, _player]] Call WFBE_CO_FNC_SendToServer;
titleText ["Building Forward FOB ...", "PLAIN DOWN"];
