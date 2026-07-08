//--- Support_FPV_Detonate.sqf - server-side warhead detonation for the FPV strike drone.
//--- Called via RequestSpecial "fpv-detonate" from the drone's Killed EH on the owning client.
//--- Pattern mirrors Support_ScudStrike.sqf: server-authoritative createVehicle ensures global
//--- damage propagation (client-created ammo is not authoritative for damage in A2 OA).
//--- Payload shape: ["fpv-detonate", [x, y, z]]
//--- SECURITY (fable/fpv-strike-drone): ownership-token + rate-limit + input hardening.
//---   1. Ownership token: Support_FPV.sqf stamps wfbe_fpv_det_<side>=drone on launch, clears on
//---      watchdog exit. We scan west/east/resistance for a non-null alive token whose last-known
//---      server position is within 200m of _pos. Match is CONSUMED (one-shot) before firing.
//---   2. Rate limit: wfbe_fpv_det_last_<side> missionNamespace stamp, min 5s gap per side.
//---   3. Input hardening: typeName + count + A2-safe origin reject BEFORE any use of _pos.
//---   4. Forensics: accepted detonations log side + position.
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]) <= 0) exitWith {
	["INFORMATION", "Support_FPV_Detonate.sqf: WFBE_C_FPV_DRONE=0, ignoring detonation request."] Call WFBE_CO_FNC_LogContent;
};

private ["_args","_pos","_ammoClass","_sides","_matchSide","_matchDrone","_token","_sKey","_sStr","_dronePos","_dist","_lastKey","_lastFire","_now","_driver","_stampRadius","_enemySides","_cand"];
_args = _this;

if (count _args < 2) exitWith {
	["WARNING", Format ["Support_FPV_Detonate.sqf: short payload (%1 args), ignored.", count _args]] Call WFBE_CO_FNC_LogContent;
};

_pos = _args select 1;

//--- INPUT HARDENING 1: reject non-array pos (would crash count on a scalar/string).
if (typeName _pos != "ARRAY") exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: pos is not ARRAY, ignored."] Call WFBE_CO_FNC_LogContent;
};

if ((count _pos) < 3) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: malformed pos array, ignored."] Call WFBE_CO_FNC_LogContent;
};

//--- INPUT HARDENING 2: reject origin [0,0,z] - A2-safe (no isEqualTo).
if ((abs ((_pos select 0)) < 1) && {abs ((_pos select 1)) < 1}) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: origin pos rejected."] Call WFBE_CO_FNC_LogContent;
};

//--- OWNERSHIP LINKAGE: scan all playable sides for an armed-drone token.
//--- Token wfbe_fpv_det_<side> is stamped by Support_FPV.sqf on launch and cleared on
//--- watchdog exit; we must consume it (one-shot) so one launch = at most one detonation.
_sides = [west, east, resistance];
_matchSide = sideUnknown;
_matchDrone = objNull;
{
	_sStr = str _x;
	_sKey = Format ["wfbe_fpv_det_%1", _sStr];
	_token = missionNamespace getVariable _sKey;
	if (!isNil "_token") then {
		if (!isNull _token) then {
			if (alive _token) then {
				_dronePos = getPos _token;
				_dist = ((_dronePos select 0) - (_pos select 0));
				if (_dist < 0) then {_dist = -_dist};
				if (_dist <= 200) then {
					private ["_dy"];
					_dy = ((_dronePos select 1) - (_pos select 1));
					if (_dy < 0) then {_dy = -_dy};
					if (_dy <= 200) then {
						_matchSide = _x;
						_matchDrone = _token;
					};
				};
			};
		};
	};
} forEach _sides;

if (_matchSide == sideUnknown) exitWith {
	["WARNING", Format ["Support_FPV_Detonate.sqf: no armed drone token found for pos %1 - request ignored (no-drone exploit attempt or stale request).", _pos]] Call WFBE_CO_FNC_LogContent;
};

//--- RATE LIMIT: per-side 5s cooldown checked BEFORE consuming the token.
//--- If rate-limited we preserve the one-shot token so the drone keeps its detonation.
//--- WARNING is distinct from the no-token path to tell collisions from exploit attempts.
_now = time;
_lastKey = Format ["wfbe_fpv_det_last_%1", str _matchSide];
_lastFire = missionNamespace getVariable [_lastKey, -1e9];
if ((_now - _lastFire) < 5) exitWith {
	["WARNING", Format ["Support_FPV_Detonate.sqf: [%1] rate-limited (gap %2s < 5s) - token PRESERVED, no warhead fired.", str _matchSide, round (_now - _lastFire)]] Call WFBE_CO_FNC_LogContent;
};
missionNamespace setVariable [_lastKey, _now];

//--- CONSUME the token: one launch = one detonation. Clear before createVehicle.
missionNamespace setVariable [Format ["wfbe_fpv_det_%1", str _matchSide], objNull];

_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"];

//--- FORENSICS: log accepted detonation with side and server-authoritative drone position.
["INFORMATION", Format ["Support_FPV_Detonate.sqf: [%1] side [%2] detonated at drone-pos %3 (client-pos %4).", _ammoClass, str _matchSide, _dronePos, _pos]] Call WFBE_CO_FNC_LogContent;

//--- fable/fix-vbied-attribution (owner pick A3, 2026-07-08): pre-blast victim stamp. This
//--- warhead was previously anonymous (zero wfbe_lasthitby stamping anywhere in this file) --
//--- every kill from this player-purchased, player-guided weapon scored zero credit for the
//--- pilot. Mirrors the VBIED/SCUD pre-blast snapshot pattern: resolve the drone's pilot (the
//--- driver seat occupant, same accessor Support_FPV.sqf already uses to find the pilot for
//--- cleanup) and stamp living enemy Man/crewed-vehicle targets within the warhead's own
//--- CfgAmmo indirectHitRange BEFORE createVehicle, so RequestOnUnitKilled's now-scoped
//--- Man-class fallback (wfbe_explosivesupportkill) can attribute the kill.
_driver = driver _matchDrone;
if (!isNull _driver) then {
	_stampRadius = getNumber (configFile >> "CfgAmmo" >> _ammoClass >> "indirectHitRange");
	if (_stampRadius <= 0) then { _stampRadius = 15; };
	_enemySides = (WFBE_PRESENTSIDES + [resistance]) - [_matchSide];
	{
		_cand = _x;
		if (alive _cand && {(side _cand) in _enemySides}) then {
			if (_cand isKindOf "Man") then {
				_cand setVariable ["wfbe_lasthitby", _driver, true];
				_cand setVariable ["wfbe_lasthittime", time, true];
				_cand setVariable ["wfbe_explosivesupportkill", true, true];
			} else {
				if (({alive _x} count (crew _cand)) > 0) then {
					_cand setVariable ["wfbe_lasthitby", _driver, true];
					_cand setVariable ["wfbe_lasthittime", time, true];
				};
			};
		};
	} forEach (nearestObjects [_dronePos, ["Man","LandVehicle","Air"], _stampRadius]);
};

//--- FIX (fable/fpv-auth-hardening): spawn warhead at the drone's actual server position,
//--- NOT the client-supplied _pos. This eliminates the ~200m free-aim exploit where an
//--- attacker could supply any _pos within the proximity gate and get a remote warhead.
createVehicle [_ammoClass, _dronePos, [], 0, "NONE"];
