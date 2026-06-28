/*
	AI Commander - PLAYER ARTILLERY resolver (COMMAND CONSOLE, claude-gaming 2026-06-28).
	Server-side. Parameter: _this = side.

	Purpose: service a player war-room ARTILLERY-HERE request that the command console stamps via
	Server_HandleSpecial "aicom-arty-here" -> wfbe_aicom_arty_request = [pos, time]. This worker is
	called EVERY supervisor tick from AI_Commander.sqf (right after the Executor), so it runs even
	under a HUMAN commander (assist-mode) - where the autonomous Strategy worker (and its own arty
	block) is dormant. It NEVER builds guns and NEVER changes the AI's own fire cadence; it only fires
	friendly artillery pieces that ALREADY exist on the map at the player's requested impact point.

	Gates (conservative + TTL):
	  - WFBE_C_AICOM_PLAYER_ARTY > 0 (separate opt-in flag; NOT the Steff-locked AI-artillery flag).
	  - WFBE_C_ARTILLERY > 0 (the global artillery system must be on at all).
	  - The request is fresh: (time - t0) < WFBE_C_AICOM_ARTY_REQUEST_TTL.
	  - Friendly-fire guard: no own troops within 400 m of the impact.
	The request is CLEARED whether or not a gun was in range, so it fires EXACTLY once (fire-once),
	and the stale-request TTL is a second safety net if this worker is ever not called.

	A2-OA-1.64 safe: typeName==/!=, ==/!= on numbers/strings/sides/objects, if/else, no params.
	Call shape copied verbatim from the Strategy arty block (AI_Commander_Strategy.sqf:741-793).
*/

private ["_side","_sideText","_logik","_riArtyReq","_riArtyPos","_riArtyT0","_riArtyFresh","_artyTgt","_ownNear","_pieces","_p","_idx","_maxR","_fired"];

_side = _this;
if ((missionNamespace getVariable ["WFBE_C_AICOM_PLAYER_ARTY", 0]) <= 0) exitWith {};
if ((missionNamespace getVariable "WFBE_C_ARTILLERY") <= 0) exitWith {};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

//--- Read + freshness-check the player request.
_riArtyReq = _logik getVariable "wfbe_aicom_arty_request";
_riArtyFresh = false; _riArtyPos = [];
if (!isNil "_riArtyReq" && {typeName _riArtyReq == "ARRAY"} && {count _riArtyReq == 2}) then {
	_riArtyPos = _riArtyReq select 0; _riArtyT0 = _riArtyReq select 1;
	if ((typeName _riArtyPos == "ARRAY") && {(time - _riArtyT0) < (missionNamespace getVariable ["WFBE_C_AICOM_ARTY_REQUEST_TTL", 120])}) then {_riArtyFresh = true};
};
if (!_riArtyFresh) exitWith {};

_sideText = str _side;
_artyTgt = _riArtyPos;

//--- Friendly-fire guard: never drop near our own troops.
_ownNear = 0;
{ if (side _x == _side && {alive _x}) then {_ownNear = _ownNear + 1} } forEach (_artyTgt nearEntities [["Man","Car","Tank","Air"], 400]);
if (_ownNear == 0) then {
	//--- Our base guns (tagged WFBE_CommanderArtillery on construction). With the Steff lock no guns are
	//--- built, so this scan finds nothing and the call is a safe no-op until a build adds artillery.
	_pieces = (getPos ((_side) Call WFBE_CO_FNC_GetSideHQ)) nearEntities [["StaticWeapon","Tank","Car"], 250];
	_fired = false;
	{
		_p = _x;
		if (!_fired && {alive _p} && {(_p getVariable ["WFBE_CommanderArtillery", false])} && {(_p getVariable ["WFBE_CommanderArtillerySide", ""]) == _sideText} && {!isNull (gunner _p)} && {alive (gunner _p)} && {someAmmo _p}) then {
			_idx = [typeOf _p, _side] Call IsArtillery;
			if (_idx >= 0) then {
				_maxR = ((missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MAX", _sideText]) select _idx) / (missionNamespace getVariable "WFBE_C_ARTILLERY");
				if (_p distance _artyTgt <= _maxR) then {
					[_p, _artyTgt, _side, 60] Spawn WFBE_CO_FNC_FireArtillery;
					_fired = true;
					["INFORMATION", Format ["AI_Commander_PlayerArty.sqf: [%1] PLAYER FIRE MISSION [%2] at %3.", _sideText, typeOf _p, _artyTgt]] Call WFBE_CO_FNC_AICOMLog;
					diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|PLAYER_FIRE_MISSION|" + (typeOf _p));
				};
			};
		};
	} forEach _pieces;
	if (!_fired) then {
		diag_log ("AICOM2|v1|ARTYREQ|" + _sideText + "|" + str (round (time / 60)) + "|NO_GUN_IN_RANGE|pos=" + str _artyTgt);
	};
} else {
	diag_log ("AICOM2|v1|ARTYREQ|" + _sideText + "|" + str (round (time / 60)) + "|FRIENDLY_NEAR_SKIP|pos=" + str _artyTgt + "|own=" + str _ownNear);
};

//--- Fire-once: clear the request whether or not a gun fired, so it never re-fires next tick.
_logik setVariable ["wfbe_aicom_arty_request", []];
