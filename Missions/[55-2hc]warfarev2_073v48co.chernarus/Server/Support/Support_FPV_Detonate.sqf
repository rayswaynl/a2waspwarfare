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

private ["_args","_pos","_ammoClass","_sides","_matchSide","_matchDrone","_tier","_token","_sKey","_sStr","_dronePos","_dist","_lastKey","_lastFire","_now"];
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

//--- CONSUME the token: one launch = one detonation. Clear before createVehicle.
missionNamespace setVariable [Format ["wfbe_fpv_det_%1", str _matchSide], objNull];

//--- RATE LIMIT: per-side 5s cooldown. Mirror ArtySharedCooldown idiom.
_now = time;
_lastKey = Format ["wfbe_fpv_det_last_%1", str _matchSide];
_lastFire = missionNamespace getVariable [_lastKey, -1e9];
if ((_now - _lastFire) < 5) exitWith {
	["WARNING", Format ["Support_FPV_Detonate.sqf: [%1] rate-limited (gap %2s < 5s), ignored.", str _matchSide, round (_now - _lastFire)]] Call WFBE_CO_FNC_LogContent;
};
missionNamespace setVariable [_lastKey, _now];

//--- WARHEAD TIER: bound server-side at launch (Support_FPV.sqf, whitelist-validated) and read
//--- off the matched ownership-token drone - never off the request payload.
_tier = _matchDrone getVariable ["wfbe_fpv_tier", "standard"];
_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"];
if (_tier == "light") then {_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO_LIGHT", "R_OG7_AT"]};
if (_tier == "heavy") then {_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO_HEAVY", "M_Hellfire_AT"]};

//--- FORENSICS: log accepted detonation with tier, side and position.
["INFORMATION", Format ["Support_FPV_Detonate.sqf: [%1] tier [%2] side [%3] detonated at %4.", _ammoClass, _tier, str _matchSide, _pos]] Call WFBE_CO_FNC_LogContent;

createVehicle [_ammoClass, _pos, [], 0, "NONE"];
