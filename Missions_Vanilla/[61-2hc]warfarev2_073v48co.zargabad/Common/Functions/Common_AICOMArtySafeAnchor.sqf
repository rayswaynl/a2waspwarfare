/*
	Common_AICOMArtySafeAnchor.sqf   (claude 2026-07-18, flag WFBE_C_AICOM_ARTY_ECHELON)

	Pick a SAFE owned-town anchor to REDEPLOY a base-built self-propelled AICOM artillery gun so it can
	service _tgt. The base guns are constructed in a 25-38m ring around HQ and never move, so once the
	front advances past a gun's max range the piece can no longer reach any valid target. This helper
	returns the position of an owned town centre that is:
	  - within the gun's max range of the target (with a margin so PlaceSafe drift cannot push it out),
	  - at least MIN_STANDOFF from the target (never redeployed on top of the objective),
	  - NOT on water,
	  - SAFE: no enemy within SAFE_DIST of the town centre (owned town => behind the front).
	Among the safe in-range candidates it prefers the town CLOSEST to the target (most forward).

	params:  _this select 0 = _side           (side)
	         _this select 1 = _piece          (the arty OBJECT being repositioned)
	         _this select 2 = _tgt            (target position ARRAY)
	         _this select 3 = _maxR           (gun max range, metres - caller already divides by WFBE_C_ARTILLERY)
	         _this select 4 = _ownTownObjs    (ARRAY of this side's owned town objects)
	returns: anchor position ARRAY, or [] if no safe in-range owned-town anchor exists.

	A2-OA-1.64 safe: getPos / distance / surfaceIsWater / nearEntities / condition-count-forEach only;
	no A3 primitives (no params/pushBack/findIf); the outer _x is captured (_twn) BEFORE the inner
	condition-count-forEach so the inner loop's _x rebind cannot corrupt the town iteration.
*/
private ["_side","_piece","_tgt","_maxR","_ownTownObjs","_safeDist","_minStand","_margin","_best","_bestD","_tc","_dTgt"];
_side        = _this select 0;
_piece       = _this select 1;
_tgt         = _this select 2;
_maxR        = _this select 3;
_ownTownObjs = _this select 4;

if (isNull _piece) exitWith {[]};
if (typeName _tgt != "ARRAY" || {count _tgt < 2}) exitWith {[]};
if (typeName _ownTownObjs != "ARRAY" || {count _ownTownObjs == 0}) exitWith {[]};
if (typeName _maxR != "SCALAR" || {_maxR <= 0}) exitWith {[]};

//--- review-fix (codex reject 2026-07-19, HIGH): the SAFE gate below used to compare against a
//--- single hardcoded _enemySide (west<->east only, defaulting to east for GUER), so it could pick
//--- a town that was actually GUER-occupied as a "safe" anchor. Now uses the repo-wide any-hostile
//--- idiom (side != own && side != civilian - see Common_RunCommanderTeam.sqf threat checks,
//--- AI_Commander_DisbandLowTier.sqf, AI_Commander_Teams.sqf) so EVERY hostile faction disqualifies
//--- a candidate anchor, not just the strategy-designated binary enemy.
_safeDist  = missionNamespace getVariable ["WFBE_C_AICOM_ARTY_ECHELON_SAFE_DIST", 400];
_minStand  = missionNamespace getVariable ["WFBE_C_AICOM_ARTY_ECHELON_MIN_STANDOFF", 500];
_margin    = 0.9; //--- keep the anchor comfortably inside max range so PlaceSafe drift cannot push the gun out of range.

_best = []; _bestD = 1e9;
{
	private ["_twn","_enemyNear"];
	_twn = _x;   //--- capture the town BEFORE the inner condition-count-forEach rebinds _x (A2 trap).
	if (!isNull _twn) then {
		_tc = getPos _twn;
		if (typeName _tc == "ARRAY" && {count _tc >= 2}) then {
			_dTgt = _tc distance _tgt;
			if ((_dTgt <= (_maxR * _margin)) && {_dTgt >= _minStand} && {!(surfaceIsWater _tc)}) then {
				//--- SAFE gate: no live enemy man/vehicle within SAFE_DIST of the town centre.
				_enemyNear = {alive _x && {side _x != _side} && {side _x != civilian}} count (_tc nearEntities [["Man","LandVehicle"], _safeDist]);
				if (_enemyNear == 0 && {_dTgt < _bestD}) then {_bestD = _dTgt; _best = _tc};
			};
		};
	};
} forEach _ownTownObjs;

_best
