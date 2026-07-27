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
	arbitrary payload. Before this patch the handler trusted the array blindly.

	⚠️ 2026-07-25 CORRECTION (see memory a2-pvf-fake-identity-binding): the original version of
	this patch claimed to have "resolved the corruption" - that is only half true. Honest scope:

	CLOSED - the teleport primitive. The handler used to setPos an arbitrary client-named
	object to an arbitrary client-named position. Construction_HQSite.sqf already positions the
	same object server-side (_logic setPos _position, ~line 67) BEFORE it ever broadcasts this
	PVF; that position change happens on the object's OWNING machine and replicates to every
	client through normal engine object-state sync. The setPos here is DROPPED entirely - no
	client needs to (or legitimately would) reapply it. This half is confirmed good and kept.

	NOT CLOSED - wfbe_basearea array corruption. The "side-logic must match locally-resolved
	side logic" check below is satisfiable by ANY forger: WFBE_CO_FNC_GetSideLogic is a pure,
	deterministic function of _side (its own existence as a client-callable lookup proves this),
	so matching its output proves nothing about the sender's identity - it's the identical trap
	already burned on RespawnST (PR #1398): validating a client-supplied reference against a
	value the client can also compute. A forger can still corrupt _side's wfbe_basearea array
	(the range gate RequestDefense.sqf/RequestStructure.sqf both use) by broadcasting a crafted
	_areas + a client-chosen _logic centre. The real fix is a server-minted capability token
	(Init_IcbmTel.sqf/Support_FPV.sqf pattern), tracked as claude/u3-capability-helper-20260725.
	Until that lands, treat "corruption closed" as FALSE for this endpoint.

	Real (non-token) narrowing added this revision, defensible without a capability token:
	  1. _logic must be typeOf "Logic" - Construction_HQSite.sqf always creates it via
	     `_grp createUnit ["Logic",[0,0,0],[],0,"NONE"]`; rejects a forger substituting a
	     player/vehicle/other object as the base-area centre.
	  2. _areas may only GROW, never shrink or replace: the receiver compares the payload's
	     _areas against this client's OWN locally-known wfbe_basearea for the same side-logic.
	     A forged _areas shorter than what this client already knows is rejected outright (blocks
	     wholesale-replace/wipe), and where an existing array exists its elements must exactly
	     prefix-match the payload's corresponding entries (blocks corrupting/rewriting already-
	     established base-area entries). This tolerates legitimate same-tick races (another HQ on
	     the same side landing concurrently can only ever make the local view longer, never rewrite
	     it) while refusing a forger's most damaging move: silently replacing the whole array.
	  3. The dead _pos/_posOK validation is REMOVED - _pos (payload element 1) has not been used
	     since the setPos was dropped; validating a value that is never read is not protection,
	     it is a false sense of coverage. The payload's element-1 slot is still skipped/ignored.

	This does NOT ship UNFLAGGED-and-done as "fixed" - it ships unflagged because it still
	rejects nothing the one real caller sends (traced above, byte-identical across every mirror),
	matching the #1361/#1364 unflagged-guard precedent, but it is explicitly a PARTIAL mitigation.
	See PR body / a2-pvf-fake-identity-binding for the residual risk and remaining fix owner.
*/

Private ["_logic","_side","_logik","_areas","_localLogik","_curAreas","_prefixOK"];

//--- Malformed-payload guard: ensure _this is ARRAY with >= 5 elements (object, pos, side, town, area).
if (!((typeName _this) in ["ARRAY"]) || {count _this < 5}) exitWith {};

_logic = _this select 0;
//--- element 1 (_pos) is intentionally unread: the setPos that consumed it was dropped below,
//--- and validating a value nothing uses is dead code, not protection.
_side  = _this select 2;
_logik = _this select 3;
_areas = _this select 4;

if !((typeName _logic) in ["OBJECT"]) exitWith {};
if (isNull _logic) exitWith {};
if (typeOf _logic != "Logic") exitWith {};
if !((typeName _side) in ["SIDE"]) exitWith {};

//--- Resolve the side logic LOCALLY instead of trusting the passed reference. NOTE: this is
//--- identity-narrowing, not authentication - WFBE_CO_FNC_GetSideLogic is a deterministic
//--- function of _side, so a forger can compute the same match (see header). Kept because it
//--- still rejects a forger naming a DIFFERENT/fabricated logic object outright.
_localLogik = _side Call WFBE_CO_FNC_GetSideLogic;
if (isNull _localLogik) exitWith {};
if !(_logik == _localLogik) exitWith {};
if !((typeName _areas) in ["ARRAY"]) exitWith {};

//--- Append-only narrowing: _areas may not be shorter than what this client already knows, and
//--- where an existing array exists it must exactly prefix-match - a forged wholesale-replace
//--- (shrink or silently-rewritten entries) is rejected; legitimate concurrent growth is not.
//--- A2/OA 1.64: no isEqualTo, no select [start,count] (both A3-only) - compare element-by-element
//--- with a flag, checked with a top-level exitWith AFTER the loop (loops are an exitWith boundary
//--- in A2 - an exitWith placed directly inside the for-loop body would only break the loop, not
//--- reject the payload, silently falling through to the write below).
_curAreas = _localLogik getVariable ["wfbe_basearea", []];
if !((typeName _curAreas) in ["ARRAY"]) then {_curAreas = []};
if (count _areas < count _curAreas) exitWith {};
_prefixOK = true;
if (count _curAreas > 0) then {
	for "_i" from 0 to (count _curAreas - 1) do {
		if !((_areas select _i) == (_curAreas select _i)) then {_prefixOK = false};
	};
};
if (!_prefixOK) exitWith {};

(_logic) setVariable ["avail",missionNamespace getVariable "WFBE_C_BASE_AV_STRUCTURES"];
(_logic) setVariable ["side",_side];
(_logik) setVariable ["wfbe_basearea", _areas + [_logic], true];
