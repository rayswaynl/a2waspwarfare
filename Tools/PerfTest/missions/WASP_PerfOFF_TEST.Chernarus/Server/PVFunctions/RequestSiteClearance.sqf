/*
	RequestSiteClearance.sqf — Server PVF for the Site Clearance commander action.

	Sent by coin_interface.sqf when the player places the 'Land_Pneu' anchor.
	The client passes the real 'player' object in the payload so that Gate 3 in
	Server_SiteClearance.sqf compares the ACTUAL placer against the commander,
	not the result of a server-side leader() lookup (which would always be the
	commander and would make the gate inert).

	TRUST MODEL NOTE: client-supplied player identity is acceptable here because:
	(a) the gate checks the player is the commander group leader — a non-commander
	    cannot forge a passing payload without also somehow being the commander;
	(b) coin_interface only fires on the requesting machine, so the payload player
	    IS the local player; spoofing it gains nothing an attacker could not already
	    do by simply being elected commander.

	Parameters (array sent from coin_interface.sqf):
		_this select 0 : sideJoined (Side)
		_this select 1 : placement position [x, y, z]
		_this select 2 : player (the client who triggered placement)
*/

private ["_side","_pos","_reqPlayer"];

if (isNil "_this") exitWith {
	["WARNING", "RequestSiteClearance.sqf: rejected nil payload."] Call WFBE_CO_FNC_LogContent;
};
if !((typeName _this) in ["ARRAY"]) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected non-array payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if ((count _this) < 3) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected short payload (%1 args).", count _this]] Call WFBE_CO_FNC_LogContent;
};

_side      = _this select 0;
_pos       = _this select 1;
_reqPlayer = _this select 2;

if !((typeName _side) in ["SIDE"]) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected side type [%1].", typeName _side]] Call WFBE_CO_FNC_LogContent;
};
if !((typeName _pos) in ["ARRAY"]) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected position type [%1].", typeName _pos]] Call WFBE_CO_FNC_LogContent;
};
if ((count _pos) < 2) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected short position (%1 fields).", count _pos]] Call WFBE_CO_FNC_LogContent;
};
if !((typeName (_pos select 0)) in ["SCALAR"]) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected position X type [%1].", typeName (_pos select 0)]] Call WFBE_CO_FNC_LogContent;
};
if !((typeName (_pos select 1)) in ["SCALAR"]) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected position Y type [%1].", typeName (_pos select 1)]] Call WFBE_CO_FNC_LogContent;
};
if !((typeName _reqPlayer) in ["OBJECT"]) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected requester type [%1].", typeName _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};
if (isNull _reqPlayer) exitWith {
	["WARNING", "RequestSiteClearance.sqf: rejected null requester."] Call WFBE_CO_FNC_LogContent;
};
if !(isPlayer _reqPlayer) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected non-player requester [%1].", _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};
if !((side group _reqPlayer) in [_side]) exitWith {
	["WARNING", Format ["RequestSiteClearance.sqf: rejected requester side mismatch [%1] for [%2].", side group _reqPlayer, _side]] Call WFBE_CO_FNC_LogContent;
};

[_side, _pos, _reqPlayer] Call WFBE_SE_FNC_SiteClearance;
