//--- ===================================================================
//--- Common_AICOMAirReturn.sqf  (WFBE_CO_FNC_AICOMAirReturn)
//--- cmdcon42-f shared RETURN-TO-BASE-AND-HOLD for an AICOM team transport after a drop.
//--- ONE implementation, called from BOTH:
//---   (1) the FOUNDING air-insert retained-transport path (WFBE_C_AICOM_AIR_RETAIN,
//---       Common_RunCommanderTeam.sqf founding disembark Spawn), and
//---   (2) the AIR-MOBILE leg runner (Common_AICOMAirLeg.sqf destination legs),
//--- so the post-drop transport fate is never duplicated.
//---
//--- The empty transport flies toward the side HQ/base and HOLDS there (lands; the crew stays
//--- with the hull) so it is available for the team's NEXT order - it PERSISTS (no fly-off, no
//--- refund, no despawn: it IS the team's vehicle). While it flies home the team's broadcast
//--- wfbe_aicom_airborne_until window is refreshed so the AssignTowns stuck-watcher never
//--- misreads the return leg; the window is CLEARED on completion (every exit path).
//---
//--- MUST be Called from a SCHEDULED context (it sleeps/waits) - both call sites are inside
//--- Spawned scripts. ARGS: [_h, _tm, _sd] (transport hull, team group, side). Returns true
//--- when the hull parked at base alive, false otherwise (hull/driver lost or timeout).
//--- A2-OA-1.64 safe: flyInHeight / doMove / land "LAND" / broadcast setVariable on a group /
//--- getPos / distance. No A3 commands, no ==/!= on Booleans.
//--- ===================================================================

private ["_h","_tm","_sd","_t0","_reapHQ","_hqPos","_parked"];
_h  = _this select 0;
_tm = _this select 1;
_sd = _this select 2;
_parked = false;

if (!isNull _h && {alive _h} && {!isNull (driver _h)} && {alive (driver _h)}) then {
	_reapHQ = (_sd) Call WFBE_CO_FNC_GetSideHQ;
	_hqPos = if (!isNull _reapHQ) then {getPos _reapHQ} else {getPos _h};
	_h flyInHeight (90 + random 30);
	(driver _h) doMove _hqPos;
	//--- Bounded run-home; land + hold when near base (or on loss/timeout). Keep the airborne
	//--- exemption alive while it flies home so the return leg is not misread as a stuck team.
	_t0 = time + 300;
	waitUntil {
		sleep 3;
		if (!isNull _tm) then {_tm setVariable ["wfbe_aicom_airborne_until", time + 120, true]};
		time > _t0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {(_h distance _hqPos) < (missionNamespace getVariable ["WFBE_C_BASEGC_RANGE", 800])}
	};
	if (!isNull _h && {alive _h} && {!isNull (driver _h)} && {alive (driver _h)}) then {
		_h land "LAND";      //--- full hold-landing at base (crew stays aboard for the next lift; "GET OUT" is the pax-insert idiom, not needed here - nobody disembarks).
		_h flyInHeight 0;
		_parked = true;
		["INFORMATION", Format ["Common_AICOMAirReturn.sqf: [%1] team transport %2 returned to base + holding for next order.", _sd, typeOf _h]] Call WFBE_CO_FNC_AICOMLog;
	};
};
//--- Done: clear the airborne exemption so the ground team is watched normally again.
if (!isNull _tm) then {_tm setVariable ["wfbe_aicom_airborne_until", 0, true]};

_parked
