/*
	RequestBaseArea.sqf - Client PVF that mirrors the server's new base-area "Logic"
	marker (avail/side copies + append into the owning side's wfbe_basearea array) onto
	every connected client.

	Sent ONLY by Server\Construction\Construction_HQSite.sqf (~line 57):
		[nil, "RequestBaseArea", [_logic, _position, _side, _logik, _areas]] Call WFBE_CO_FNC_SendToClients;
	Verified by a tree-wide grep for "RequestBaseArea": this is the ONLY caller anywhere in
	the mission tree - all 3 mirrors (chernarus/takistan/zargabad) plus every modded/perf-test
	copy send this identical 5-element shape, so the guard below is checked against the real
	live payload, not a guess.

	HARDENING (unauthenticated-endpoint audit 2026-07-25): this variable is a plain
	publicVariable, so ANY client - not only the server - can write it directly with an
	arbitrary payload. Before this patch the handler trusted the array blindly: it setPos'd
	an arbitrary client-named object to an arbitrary client-named position (an arbitrary
	teleport primitive) and appended a client-supplied entry into a client-named side-logic
	object's wfbe_basearea array via a BROADCAST setVariable - corrupting, for every side and
	every client, the base-area range gates that RequestDefense.sqf and RequestStructure.sqf
	both rely on. Fixes:
	  1. Every element is shape/type validated before use (object, side, position, array).
	  2. The side-logic target (_this select 3) is no longer trusted as-passed: it is
	     resolved LOCALLY from the claimed side via WFBE_CO_FNC_GetSideLogic and must match
	     the passed reference exactly, so a forged call cannot point at another side's logic
	     (or a made-up object) to corrupt that side's base-area array.
	  3. The setPos is DROPPED. Construction_HQSite.sqf already positions the very same
	     object server-side (_logic setPos _position, ~line 67) before it ever broadcasts
	     this PVF; that position change happens on the object's OWNING machine (the server)
	     and replicates to every client through normal engine object-state sync - no client
	     needs to (or legitimately would) reapply it. Re-setPos'ing an arbitrary object here
	     was the actual teleport primitive and covered nothing the server hadn't already done.

	This guard rejects nothing a legitimate broadcast ever sends (verified against the one
	real caller above, byte-identical across every mirror), so it ships UNFLAGGED rather than
	behind WFBE_C_SEC_HARDENING (precedent: merged PR #1361/#1364).
*/

Private ["_logic","_pos","_side","_logik","_areas","_posOK","_localLogik"];

//--- Malformed-payload guard: ensure _this is ARRAY with >= 5 elements (object, pos, side, town, area).
if (!((typeName _this) in ["ARRAY"]) || {count _this < 5}) exitWith {};

_logic = _this select 0;
_pos   = _this select 1;
_side  = _this select 2;
_logik = _this select 3;
_areas = _this select 4;

if !((typeName _logic) in ["OBJECT"]) exitWith {};
if (isNull _logic) exitWith {};
if !((typeName _side) in ["SIDE"]) exitWith {};
if !((typeName _pos) in ["ARRAY"]) exitWith {};
if !((count _pos) in [2,3]) exitWith {};

_posOK = true;
{if !((typeName _x) in ["SCALAR"]) then {_posOK = false}} forEach _pos;
if (!_posOK) exitWith {};

//--- Resolve the side logic LOCALLY instead of trusting the passed reference; a forged
//--- payload cannot name another side's (or a fabricated) logic object and have it accepted.
_localLogik = _side Call WFBE_CO_FNC_GetSideLogic;
if (isNull _localLogik) exitWith {};
if !(_logik == _localLogik) exitWith {};
if !((typeName _areas) in ["ARRAY"]) exitWith {};

(_logic) setVariable ["avail",missionNamespace getVariable "WFBE_C_BASE_AV_STRUCTURES"];
(_logic) setVariable ["side",_side];
(_logik) setVariable ["wfbe_basearea", _areas + [_logic], true];
