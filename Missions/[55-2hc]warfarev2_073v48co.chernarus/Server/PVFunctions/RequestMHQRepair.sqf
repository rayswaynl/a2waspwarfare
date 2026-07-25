/*
	RequestMHQRepair.sqf - Server PVF for the Mobile HQ repair/rebuild action.

	Sent by Action_RepairMHQ.sqf (supply/funds repair) and Action_RepairMHQDepot.sqf
	(cash repair). The client now passes the real 'player' object so the server can bind
	the request to the caller's ACTUAL side. Without it any client could name EITHER side
	and force-delete that side's HQ (BLOCKER: unauthenticated, cross-side, free, repeatable).

	TRUST MODEL NOTE (mirrors RequestSiteClearance.sqf): client-supplied identity is
	acceptable because the gate compares (side group _reqPlayer) against the claimed _side -
	a WEST client cannot forge a payload that passes for EAST. Aliveness and reentrancy are
	enforced server-side in Server_MHQRepair.sqf; the client is never trusted.

	Parameters (array sent from the client actions):
		_this select 0 : sideJoined (Side)
		_this select 1 : player (the client that triggered the repair)
*/

private ["_side","_reqPlayer"];

if (isNil "_this") exitWith {
	["WARNING", "RequestMHQRepair.sqf: rejected nil payload."] Call WFBE_CO_FNC_LogContent;
};
if !((typeName _this) in ["ARRAY"]) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: rejected non-array payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if ((count _this) < 2) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: rejected short payload (%1 args).", count _this]] Call WFBE_CO_FNC_LogContent;
};

_side      = _this select 0;
_reqPlayer = _this select 1;

if !((typeName _side) in ["SIDE"]) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: rejected side type [%1].", typeName _side]] Call WFBE_CO_FNC_LogContent;
};
if !((typeName _reqPlayer) in ["OBJECT"]) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: rejected requester type [%1].", typeName _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};
if (isNull _reqPlayer) exitWith {
	["WARNING", "RequestMHQRepair.sqf: rejected null requester."] Call WFBE_CO_FNC_LogContent;
};
if !(isPlayer _reqPlayer) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: rejected non-player requester [%1].", _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};
if !((side group _reqPlayer) in [_side]) exitWith {
	["WARNING", Format ["RequestMHQRepair.sqf: rejected requester side mismatch [%1] for [%2].", side group _reqPlayer, _side]] Call WFBE_CO_FNC_LogContent;
};

[_side, _reqPlayer] Spawn MHQRepair;
