/*
	WFBE_CO_FNC_CapLock - is this AICOM team CAPTURE-LOCKED right now?

	Capture churn fix (GR-2026-07-03a): a team that has fired BEGIN_CAPTURE and is
	draining a town must be IMMUNE to re-targeting/new orders until the town is taken,
	the team dies, a TTL expires, or the town changes hands to our side by other means.
	The HC driver (Common_RunCommanderTeam.sqf) stamps the lock as a broadcast GROUP var
	wfbe_aicom_caplock = [townObj, t0]; the server-side order ISSUERS call THIS to skip a
	locked team when selecting who to (re)task.

	A team is LOCKED when ALL hold:
	  (kill-switch) WFBE_C_AICOM_CAPTURE_LOCK > 0,
	  (a) wfbe_aicom_caplock is a non-empty [townObj, t0] array,
	  (b) TTL not elapsed: time - t0 < WFBE_C_AICOM_CAPTURE_LOCK_TTL (wedge escape hatch),
	  (c) the locked town is still NOT ours (captured/flipped-to-us => unlocked),
	  (d) the team is still viable: at least one live unit.
	Any miss => NOT locked (the issuer re-tasks normally; never leaves a team idle).

	A2 OA 1.64: the [name,default] getVariable form is unreliable on GROUP receivers, so
	read wfbe_aicom_caplock with the plain 1-arg form + isNil (the G1 idiom). All early
	returns are TOP-SCOPE exitWith (an exitWith INSIDE then{}/else{} only breaks that block
	on A2 OA and would fall through). typeName guards, numeric-only compares, no A3 prims.

	Params: [ group ]
	Returns: BOOL (true = locked, skip re-tasking this team).
*/
private ["_grp","_cl","_town","_t0","_ttl","_mySideID"];
_grp = _this select 0;
if (isNull _grp) exitWith {false};
if ((missionNamespace getVariable ["WFBE_C_AICOM_CAPTURE_LOCK", 1]) <= 0) exitWith {false};   //--- kill-switch off => never locked
_cl = _grp getVariable "wfbe_aicom_caplock";                    //--- A2 G1: 1-arg get + isNil (no [name,default] on a GROUP)
if (isNil "_cl") exitWith {false};                              //--- (a) never stamped / cleared => not locked
if (typeName _cl != "ARRAY") exitWith {false};
if (count _cl < 2) exitWith {false};                            //--- (a) empty/short array => cleared => not locked
_town = _cl select 0;
_t0   = _cl select 1;
if (typeName _t0 != "SCALAR") exitWith {false};
_ttl = missionNamespace getVariable ["WFBE_C_AICOM_CAPTURE_LOCK_TTL", 600];
if ((time - _t0) >= _ttl) exitWith {false};                     //--- (b) TTL elapsed => wedge escape: unlock
//--- (c) town still enemy-held? If the locked town has flipped to THIS group's side, unlock.
_mySideID = (side _grp) Call WFBE_CO_FNC_GetSideID;
if (typeName _town == "OBJECT" && {!isNull _town} && {(_town getVariable ["sideID", -1]) == _mySideID}) exitWith {false};
//--- (d) viability: at least one live unit.
if (({alive _x} count (units _grp)) <= 0) exitWith {false};
true
