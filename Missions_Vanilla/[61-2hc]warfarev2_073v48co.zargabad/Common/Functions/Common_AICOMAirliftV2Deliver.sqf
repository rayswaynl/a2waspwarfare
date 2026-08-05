//--- ===================================================================
//--- Common_AICOMAirliftV2Deliver.sqf  (WFBE_CO_FNC_AICOMAirliftV2Deliver)
//--- fable/airlift-v2 (PR #1579 follow-up, owner 2026-07-28): the LIFT half of the requisitioned-
//--- transport handshake, run AT THE DELIVERY POINT instead of the founding air-insert block
//--- (Common_RunCommanderTeam.sqf ~L664), which fires ONCE at team founding, BEFORE the main
//--- loop that later creates this hull - see the AIRLIFT_REQ registration in
//--- Init_CommonConstants.sqf for the full live-evidence writeup (55 granted / 55 delivered /
//--- 0 inserts on the 2026-07-28 soak - every paid transport parked at the factory forever).
//---
//--- Gate: WFBE_C_AICOM_AIRLIFT_V2 (Init_CommonConstants.sqf), default 0. The request gate in
//--- the main order loop (AIRMOBILE TRANSPORT REQUISITION, ~L1670) fires when EITHER this flag
//--- OR the legacy AIRLIFT_REQ flag is >0 - V2 alone is sufficient to run the whole
//--- request -> grant -> deliver -> LIFT pipeline; arming it does NOT re-arm AIRLIFT_REQ.
//---
//--- Called ONLY from the AIRMOBILE TRANSPORT GRANT CONSUMER (Common_RunCommanderTeam.sqf,
//--- immediately after a fresh delivery), Spawned (non-blocking) so the order loop's 8s tick is
//--- never blocked by a multi-minute flight. Mount / unload / RTB deliberately reuse the SAME
//--- idioms as the founding air-insert Spawn (~L777-923) and Common_AICOMAirLeg.sqf -
//--- assignAsCargo + orderGetIn true to mount, unassignVehicle + orderGetIn false to disembark,
//--- and the SHARED WFBE_CO_FNC_AICOMAirReturn helper for RTB (same code the founding
//--- WFBE_C_AICOM_AIR_RETAIN path and every AIR-MOBILE leg already use - no new RTB logic here).
//---
//--- SCOPE (honest, first cut): unlike the founding block / AICOMAirLeg, this does NOT run the
//--- hot-LZ paradrop decision (isFlatEmpty + contested-town eject) - it always lands + GET OUT
//--- near the objective. TODO once soaked: port the hot-LZ branch if landings into contested
//--- towns prove costly. No vehicle sling (VEHLIFT) either - personnel only. Also honest: the
//--- freshly-created hull spawns at the nearest OWNED aircraft factory to the team leader AT
//--- REQUEST time (AI_Commander_Produce.sqf), not at the team's CURRENT position - if the team
//--- has since marched well away from that factory before delivery, the bounded boarding wait
//--- below may routinely time out (fail-safe: abort, transport stays parked+crewed, team
//--- continues its existing ground order unaffected). First thing to check in the soak.
//---
//--- ARGS: [_h, _team, _side, _sideID]
//---   _h      : the freshly-delivered transport hull (isKindOf "Air", transportSoldier > 0,
//---             already stamped wfbe_aicom_transport=true by the grant consumer).
//---   _team   : the AICOM group.
//---   _side   : side of the team.
//---   _sideID : side id (for telemetry).
//---
//--- STAGES (diag_log "AIRLIFT2|v1|stage=<stage>|..."): request (logged by the caller when the
//--- request is stamped) -> mount -> liftoff -> unload -> rtb, with abort at any guard failure
//--- (hull/team invalid, no pilot, no valid current order, no passengers, boarding timeout,
//--- transport lost in flight, team wiped).
//---
//--- MUST be Spawned, never Call'd - this script sleeps/waits throughout (same scheduled-context
//--- requirement as Common_AICOMAirReturn.sqf).
//---
//--- A2-OA-1.64 SAFE: assignAsCargo/orderGetIn, isFlatEmpty, land "GET OUT", unassignVehicle +
//--- orderGetIn false, flyInHeight/doMove, WFBE_CO_FNC_AICOMAirReturn (Call from inside this
//--- already-scheduled script). No A3 commands, no isEqualType, no ==/!= on Booleans, no
//--- pushBack/findIf/params, no inline `private _x =`.
//--- ===================================================================

private ["_h","_team","_side","_sideID"];
_h      = _this select 0;
_team   = _this select 1;
_side   = _this select 2;
_sideID = _this select 3;

if (isNull _h || {isNull _team}) exitWith {
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|reason=hull-or-team-null");
};
if (!alive _h) exitWith {
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|reason=hull-dead");
};
if (isNull (driver _h) || {!alive (driver _h)}) exitWith {
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|reason=no-pilot");
};

//--- CURRENT OBJECTIVE (same idiom the main order loop reads: Common_RunCommanderTeam.sqf
//--- ~L1166-1171, plain group getVariable + isNil, no [name,default] on a GROUP receiver).
private ["_v2Order","_dest"];
_v2Order = _team getVariable "wfbe_aicom_order";
if (isNil "_v2Order") then {_v2Order = []};
_dest = [];
if (count _v2Order >= 3) then {_dest = _v2Order select 2};
if (typeName _dest != "ARRAY" || {count _dest < 2}) exitWith {
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|reason=no-order");
};

//--- ===================================================================
//--- MOUNT (founding idiom, Common_RunCommanderTeam.sqf ~L163-171 / Common_AICOMAirLeg.sqf L54-71):
//--- foot infantry only (crew/driver excluded); cargo-capacity check mirrors the delivery-site
//--- diagnostic already logged by the grant consumer (_alSeats = _alHull emptyPositions "cargo").
//--- ===================================================================
private ["_footPax","_cargoSeats","_lifted","_walkers"];
_footPax = [];
{
	if (alive _x && {vehicle _x == _x} && {_x != (driver _h)}) then {_footPax = _footPax + [_x]};
} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);

_cargoSeats = _h emptyPositions "cargo";
_lifted  = [];
_walkers = [];
{
	if (count _lifted < _cargoSeats) then {
		_x assignAsCargo _h;
		[_x] orderGetIn true;
		_lifted = _lifted + [_x];
	} else {
		_walkers = _walkers + [_x];
	};
} forEach _footPax;

//--- Nobody eligible to lift (team wiped, or every survivor is already crewing something else):
//--- release - leave the hull parked+crewed at the factory (never deleted; it stays a valid team
//--- asset the normal AIRMOBILE order-loop branch or a later delivery pass can still pick up).
if (count _lifted == 0) exitWith {
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|reason=no-pax|walkers=" + str (count _walkers));
};

//--- Overflow beyond cargo capacity walks toward the objective NOW (never idle).
{if (alive _x) then {_x doMove _dest}} forEach _walkers;

//--- BOUNDED BOARDING WAIT (<=60s per design): everyone assigned above must physically be aboard
//--- before liftoff. Compares against the ALIVE subset of _lifted (founding idiom, L790) so one
//--- casualty while boarding cannot itself timeout the whole squad. On hull/pilot loss, on a
//--- fully-wiped lift party, or on an incomplete boarding by the deadline, abort cleanly -
//--- unassign whoever DID make it in and send survivors marching to the objective on foot
//--- instead (never split/strand a partially-boarded squad, never leave the transport waiting
//--- forever on a straggler).
private ["_bt0"];
_bt0 = time + 60;
waitUntil {
	sleep 1;
	time > _bt0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {({alive _x && {vehicle _x == _h}} count _lifted) >= ({alive _x} count _lifted)}
};
if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
	{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _dest}} forEach _lifted;
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|reason=hull-lost-boarding|pax=" + str (count _lifted));
};
private ["_aliveLifted","_boarded"];
_aliveLifted = {alive _x} count _lifted;
if (_aliveLifted == 0) exitWith {
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|reason=team-dead");
};
_boarded = {alive _x && {vehicle _x == _h}} count _lifted;
if (_boarded < _aliveLifted) exitWith {
	{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _dest}} forEach _lifted;
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|reason=boarding-timeout|boarded=" + str _boarded + "|of=" + str _aliveLifted);
};

diag_log ("AIRLIFT2|v1|stage=mount|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|lifted=" + str _boarded + "|walked=" + str (count _walkers) + "|seats=" + str _cargoSeats);
["INFORMATION", Format ["Common_AICOMAirliftV2Deliver.sqf: [%1] team [%2] V2 MOUNT %3 complete (%4 aboard, %5 seats).", _side, _team, typeOf _h, _boarded, _cargoSeats]] Call WFBE_CO_FNC_AICOMLog;

//--- ===================================================================
//--- LIFTOFF (founding idiom L692-696): prefer a flat spot at the objective; else the raw dest.
//--- No hot-LZ paradrop decision in this first cut (see header SCOPE note).
//--- ===================================================================
private ["_lzPos","_flat"];
_lzPos = _dest;
_flat  = _dest isFlatEmpty [12, 0, 2, 12, 0, false, objNull];
if (count _flat > 0) then {_lzPos = _flat};

_h setVariable ["wfbe_aicom_transport", true, true]; //--- already stamped by the grant consumer; re-stamp defensively (belt-and-braces, matches founding L172-173).
_team setVariable ["wfbe_aicom_airborne_until", time + 600, true]; //--- AssignTowns stuck-watcher exemption (mirrors Common_AICOMAirLeg.sqf L140).

diag_log ("AIRLIFT2|v1|stage=liftoff|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|pax=" + str _boarded + "|dest=" + str _dest);
["INFORMATION", Format ["Common_AICOMAirliftV2Deliver.sqf: [%1] team [%2] V2 LIFTOFF %3 -> %4 (%5 pax).", _side, _team, typeOf _h, _dest, _boarded]] Call WFBE_CO_FNC_AICOMLog;

private ["_approachLimited","_t0"];
_approachLimited = (missionNamespace getVariable ["WFBE_C_AICOM_HELI_APPROACH_LIMITED", 0]) > 0;
if (_approachLimited) then {(group (driver _h)) setSpeedMode "LIMITED"};
(driver _h) doMove _lzPos;
_h flyInHeight (60 max (missionNamespace getVariable ["WFBE_C_AICOM_HELI_RUNINFLOOR", 0]));
_t0 = time + 240;
waitUntil {
	sleep 2;
	_team setVariable ["wfbe_aicom_airborne_until", time + 120, true];
	time > _t0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {(_h distance _lzPos) < 120}
};
if (_approachLimited && {!isNull _h} && {alive _h} && {!isNull (driver _h)} && {alive (driver _h)}) then {(group (driver _h)) setSpeedMode "FULL"};

if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
	{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _dest}} forEach _lifted;
	_team setVariable ["wfbe_aicom_airborne_until", 0, true];
	diag_log ("AIRLIFT2|v1|stage=abort|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|reason=lost-runin|pax=" + str _boarded);
};

//--- ===================================================================
//--- UNLOAD (founding idiom L806-812 / Common_AICOMAirLeg.sqf L369-375): land + GET OUT, then
//--- the established disembark idiom (unassignVehicle + orderGetIn false), then an unconditional
//--- ground doMove so the order loop's arrival latch + MOVE/SAD capture chain folds them in
//--- exactly like a road-marched or founding-inserted team (Hook-B sees a normal arrival).
//--- ===================================================================
_h land "GET OUT";
_h flyInHeight 0;
_t0 = time + 40;
waitUntil {sleep 1; time > _t0 || isNull _h || {!alive _h} || {((getPosATL _h) select 2) < 1.5}};
{if (alive _x && {vehicle _x == _h}) then {unassignVehicle _x; [_x] orderGetIn false}} forEach _lifted;
{if (alive _x) then {_x doMove _dest}} forEach _lifted;

diag_log ("AIRLIFT2|v1|stage=unload|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|pax=" + str ({alive _x} count _lifted) + "|dest=" + str _dest);
["INFORMATION", Format ["Common_AICOMAirliftV2Deliver.sqf: [%1] team [%2] V2 UNLOAD %3 near %4.", _side, _team, typeOf _h, _dest]] Call WFBE_CO_FNC_AICOMLog;

//--- ===================================================================
//--- RTB (shared idiom - the SAME helper the founding WFBE_C_AICOM_AIR_RETAIN path and every
//--- AIR-MOBILE leg already Call; no new return-to-base logic here). Handles transport-destroyed
//--- and pilot-dead internally (every wait bounded, every exit path clears the airborne stamp).
//--- ===================================================================
private ["_parked"];
_parked = false;
if (!isNull _h && {alive _h} && {!isNull (driver _h)} && {alive (driver _h)}) then {
	_parked = [_h, _team, _side] Call WFBE_CO_FNC_AICOMAirReturn;
} else {
	_team setVariable ["wfbe_aicom_airborne_until", 0, true];
};
diag_log ("AIRLIFT2|v1|stage=rtb|team=" + str _team + "|side=" + str _sideID + "|hull=" + typeOf _h + "|parked=" + str _parked);
