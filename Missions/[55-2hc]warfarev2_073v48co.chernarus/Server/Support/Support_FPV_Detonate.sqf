//--- Support_FPV_Detonate.sqf - server-side warhead detonation for the FPV strike drone.
//--- Called via RequestSpecial "fpv-detonate" from the drone's Killed EH on the owning client.
//--- Pattern mirrors Support_ScudStrike.sqf: server-authoritative createVehicle ensures global
//--- damage propagation (client-created ammo is not authoritative for damage in A2 OA).
//--- Payload shape: ["fpv-detonate", [_drone, _privateCapability, [x, y, z]]]
//--- SECURITY (fpv-detonate-authority): exact-drone capability + atomic consume + input hardening.
//---   1. Support_FPV.sqf appends each drone to a per-side ARRAY registry and stamps the
//---      purchase capability on that exact drone in the server-local object namespace.
//---   2. The client must return that private capability and the exact drone object. We do
//---      not scan by position, side, or alive state, so a forged request cannot select a
//---      nearby sibling or another player's drone (and a killed target remains addressable).
//---   3. Exact-match lookup, capability validation, per-side rate limit, and one-shot removal
//---      run in one unscheduled transaction; replay/concurrent requests cannot double-fire.
//---   4. Input hardening and forensics remain server-side; the client position is never trusted.
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]) <= 0) exitWith {
	["INFORMATION", "Support_FPV_Detonate.sqf: WFBE_C_FPV_DRONE=0, ignoring detonation request."] Call WFBE_CO_FNC_LogContent;
};

private ["_args","_request","_requestedDrone","_detCap","_pos","_ammoClass","_sides","_matchSide","_matchDrone","_matchCount","_token","_sKey","_sStr","_sArr","_sideVal","_tok","_dronePos","_dist","_lastKey","_lastFire","_now","_driver","_stampRadius","_enemySides","_cand","_bestDist","_atomicState","_serverCap","_ownerStamp","_cArr","_retryArgs","_retryDelay","_retryPending","_retryDrone"];
_args = _this;

if (count _args < 2) exitWith {
	["WARNING", Format ["Support_FPV_Detonate.sqf: short payload (%1 args), ignored.", count _args]] Call WFBE_CO_FNC_LogContent;
};

_request = _args select 1;
if (typeName _request != "ARRAY" || {count _request < 3}) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: malformed authority payload, ignored."] Call WFBE_CO_FNC_LogContent;
};
_requestedDrone = _request select 0;
_detCap = _request select 1;
_pos = _request select 2;

//--- INPUT HARDENING 1: reject non-object drone or non-string capability before any use.
if (typeName _requestedDrone != "OBJECT" || {isNull _requestedDrone}) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: drone authority binding rejected."] Call WFBE_CO_FNC_LogContent;
};
if (typeName _detCap != "STRING" || {_detCap == ""}) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: private detonation capability rejected."] Call WFBE_CO_FNC_LogContent;
};

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

//--- AUTHORITY + CONSUME: exact-drone lookup, private capability validation, rate-limit,
//--- and one-shot registry removal are one unscheduled transaction. The dead-drone grace
//--- in Support_FPV.sqf keeps the Killed request addressable while this block rejects every
//--- object/capability pair not minted by the server for this exact flight.
_sides = [west, east, resistance];
_atomicState = 0;
isNil {
	_matchSide = sideUnknown;
	_matchDrone = objNull;
	_matchCount = 0;
	{
		_sideVal = _x;
		_sKey = Format ["wfbe_fpv_det_arr_%1", str _sideVal];
		_sArr = missionNamespace getVariable [_sKey, []];
		if (typeName _sArr == "ARRAY") then {
			{
				_tok = _x;
				if (!isNil "_tok" && {typeName _tok == "OBJECT"} && {_tok == _requestedDrone}) then {
					_matchCount = _matchCount + 1;
					_matchSide = _sideVal;
					_matchDrone = _tok;
				};
			} forEach _sArr;
		};
	} forEach _sides;

	if (_matchCount == 0) then {
		_atomicState = 1;
	} else {
		if (_matchCount > 1) then {
			_atomicState = 2;
		} else {
			_serverCap = _matchDrone getVariable ["wfbe_fpv_det_cap", ""];
			_ownerStamp = _matchDrone getVariable ["wfbe_fpv_det_owner", -1];
			if (typeName _serverCap != "STRING" || {_serverCap == ""} || {_serverCap != _detCap}) then {
				_atomicState = 3;
			} else {
				if (typeName _ownerStamp != "SCALAR" || {_ownerStamp <= 0}) then {
					_atomicState = 4;
				} else {
					if (alive _matchDrone && {owner _matchDrone != _ownerStamp}) then {
						_atomicState = 4;
					} else {
						_now = time;
						_lastKey = Format ["wfbe_fpv_det_last_%1", str _matchSide];
						_lastFire = missionNamespace getVariable [_lastKey, -1e9];
						if (typeName _lastFire != "SCALAR") then {_lastFire = -1e9};
						if ((_now - _lastFire) < 5) then {
							_retryPending = _matchDrone getVariable ["wfbe_fpv_det_retry_pending", false];
							if (typeName _retryPending != "BOOL") then {_retryPending = false};
							if (_retryPending) then {
								_atomicState = 7;
							} else {
								_matchDrone setVariable ["wfbe_fpv_det_retry_pending", true];
								_atomicState = 5;
							};
						} else {
							_cArr = missionNamespace getVariable [Format ["wfbe_fpv_det_arr_%1", str _matchSide], []];
							if (typeName _cArr != "ARRAY") then {_cArr = []};
							_cArr = _cArr - [_matchDrone];
							missionNamespace setVariable [Format ["wfbe_fpv_det_arr_%1", str _matchSide], _cArr];
							missionNamespace setVariable [_lastKey, _now];
							_matchDrone setVariable ["wfbe_fpv_det_cap", ""];
							_dronePos = getPos _matchDrone;
							_atomicState = 6;
						};
					};
				};
			};
		};
	};
};

if (_atomicState == 1) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: exact registered drone not found - request ignored."] Call WFBE_CO_FNC_LogContent;
};
if (_atomicState == 2) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: ambiguous duplicate drone registry - request ignored."] Call WFBE_CO_FNC_LogContent;
};
if (_atomicState == 3) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: drone capability mismatch - request ignored."] Call WFBE_CO_FNC_LogContent;
};
if (_atomicState == 4) exitWith {
	["WARNING", "Support_FPV_Detonate.sqf: drone ownership stamp mismatch - request ignored."] Call WFBE_CO_FNC_LogContent;
};
if (_atomicState == 7) exitWith {
	["WARNING", Format ["Support_FPV_Detonate.sqf: [%1] rate-limited - retry already pending for exact drone.", str _matchSide]] Call WFBE_CO_FNC_LogContent;
};
if (_atomicState == 5) exitWith {
	//--- The Killed EH is one-shot, so preserving the capability alone would lose a valid
	//--- detonation when two same-side drones die within the side cooldown. Retry once after
	//--- the remaining bounded cooldown; the exact object/capability pair is revalidated.
	//--- The server-local pending marker coalesces replayed requests to one retry script.
	_retryDelay = 5 - (_now - _lastFire);
	if (_retryDelay < 0) then {_retryDelay = 0};
	_retryArgs = _args;
	[_retryArgs, _retryDelay] Spawn {
		private ["_retryArgs","_retryDelay","_retryDrone"];
		_retryArgs = _this select 0;
		_retryDelay = _this select 1;
		sleep _retryDelay;
		_retryDrone = ((_retryArgs select 1) select 0);
		if (!isNull _retryDrone) then {_retryDrone setVariable ["wfbe_fpv_det_retry_pending", false]};
		_retryArgs Call KAT_FPVDetonate;
	};
	["WARNING", Format ["Support_FPV_Detonate.sqf: [%1] rate-limited - retry scheduled in %2s.", str _matchSide, round _retryDelay]] Call WFBE_CO_FNC_LogContent;
};

_ammoClass = _matchDrone getVariable ["wfbe_fpv_ammo", ""];
if (typeName _ammoClass != "STRING" || {_ammoClass == ""}) then {_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"]};

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
