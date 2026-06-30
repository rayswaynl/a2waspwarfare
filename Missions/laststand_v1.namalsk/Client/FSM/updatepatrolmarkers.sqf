/*
	Friendly side-patrol map markers (Patrols upgrade).
	Tracks WFBE_ACTIVE_PATROLS (public [[leaderUnit, sideID], ...] maintained by the
	server) and keeps a local yellow circle on each FRIENDLY patrol leader. Side-local
	only - enemy patrols are never marked. Self-contained loop (does not reuse
	MarkerUpdate): create, follow every 5s, delete when the leader dies.
*/

scriptName "Client\FSM\updatepatrolmarkers.sqf";

private ["_list","_tracked","_keep","_unit","_sid","_mk","_known","_i","_k","_pos","_dir","_lastPos","_lastDir","_dirDiff","_t0","_alist","_trackedAir","_airNow"];

//--- B63 (Ray 2026-06-21): bounded gate (mirrors updateaicommarkers) so a stalled client init can't
//--- suppress the friendly patrol arrows forever; proceed after 90s of in-game time at the latest.
_t0 = time;
waitUntil {(!isNil "clientInitComplete" && {clientInitComplete}) || ((time - _t0) > 90)};

_tracked = []; //--- [unit, markerName] pairs
_trackedAir = []; //--- B67: GUER air-defense [vehicle, markerName, lastPos, lastDir]
_i = 0;

while {true} do {
	_list = missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []];

	//--- New friendly patrols.
	{
		_unit = _x select 0;
		_sid = _x select 1;
		if (_sid == WFBE_Client_SideID && {!isNull _unit} && {alive _unit}) then {
			_known = false;
			for "_k" from 0 to (count _tracked - 1) do {
				if (((_tracked select _k) select 0) == _unit) then {_known = true};
			};
			if (!_known) then {
				_i = _i + 1;
				_mk = Format["wfbe_patrolmarker_%1", _i];
				_pos = getPos _unit;
				_dir = getDir _unit;
				createMarkerLocal [_mk, _pos];
				//--- Direction-showing arrow, numbered per patrol (Steff: "marker can be nicer").
				_mk setMarkerTypeLocal "mil_arrow2";
				_mk setMarkerColorLocal "ColorYellow";
				_mk setMarkerSizeLocal [0.6,0.6];
				_mk setMarkerTextLocal Format["Patrol %1", _i];
				_mk setMarkerDirLocal _dir;
				//--- PERF4 - cache last pos/dir (slots 2/3) so the follow pass below skips no-op writes.
				_tracked = _tracked + [[_unit, _mk, _pos, _dir]];
			};
		};
	} forEach _list;

	//--- Follow / drop.
	_keep = [];
	{
		_unit = _x select 0;
		_mk = _x select 1;
		if (!isNull _unit && {alive _unit}) then {
			//--- PERF4 - only re-write pos/dir when the leader actually moved/turned. A stationary
			//--- patrol otherwise paid two setMarker* writes every 5s for zero visible change.
			_pos = getPos _unit;
			_lastPos = _x select 2;
			if (isNil "_lastPos" || {(_pos distance _lastPos) > 3}) then {
				_mk setMarkerPosLocal _pos;
				_x set [2, _pos];
			};
			_dir = getDir _unit;
			_lastDir = _x select 3;
			if (isNil "_lastDir") then {_lastDir = -999};
			_dirDiff = abs (_dir - _lastDir);
			if (_dirDiff > 180) then {_dirDiff = 360 - _dirDiff};
			if (_dirDiff > 7) then { //--- arrow tracks the patrol's heading
				_mk setMarkerDirLocal _dir;
				_x set [3, _dir];
			};
			_keep = _keep + [_x];
		} else {
			deleteMarkerLocal _mk;
		};
	} forEach _tracked;
	_tracked = _keep;

	//--- B67 (Ray 2026-06-21): GUER AIR-DEFENSE markers. Same friendly-only, self-following pattern as the
	//--- patrols above, reading the server feed WFBE_ACTIVE_GUER_AIR = [[vehicle, sideID], ...]; distinct icon
	//--- (blue arrow, "GUER Air") so a GUER player sees their Ka-137/Mi-24 air cover. The alive-check drops a
	//--- destroyed/despawned airframe at once, even before the server list next refreshes.
	_alist = missionNamespace getVariable ["WFBE_ACTIVE_GUER_AIR", []];
	//--- B67: membership set for the follow/drop reconcile below - drop a marker whose airframe was DELISTED
	//--- from the feed while still ALIVE (e.g. a GUER player boards an air-defender that GuerAirDef then
	//--- despawns player-safe: it drops the registry entry but leaves the hull, so the alive-check alone leaks it).
	_airNow = [];
	{ _airNow = _airNow + [_x select 0] } forEach _alist;
	{
		_unit = _x select 0;
		_sid = _x select 1;
		if (_sid == WFBE_Client_SideID && {!isNull _unit} && {alive _unit}) then {
			_known = false;
			for "_k" from 0 to (count _trackedAir - 1) do {
				if (((_trackedAir select _k) select 0) == _unit) then {_known = true};
			};
			if (!_known) then {
				_i = _i + 1;
				_mk = Format["wfbe_guerairmarker_%1", _i];
				_pos = getPos _unit;
				_dir = getDir _unit;
				createMarkerLocal [_mk, _pos];
				_mk setMarkerTypeLocal "mil_arrow2";
				_mk setMarkerColorLocal "ColorBlue";
				_mk setMarkerSizeLocal [0.7,0.7];
				_mk setMarkerTextLocal "GUER Air";
				_mk setMarkerDirLocal _dir;
				_trackedAir = _trackedAir + [[_unit, _mk, _pos, _dir]];
			};
		};
	} forEach _alist;

	_keep = [];
	{
		_unit = _x select 0;
		_mk = _x select 1;
		if (!isNull _unit && {alive _unit} && {_unit in _airNow}) then {
			_pos = getPos _unit;
			_lastPos = _x select 2;
			if (isNil "_lastPos" || {(_pos distance _lastPos) > 3}) then {
				_mk setMarkerPosLocal _pos;
				_x set [2, _pos];
			};
			_dir = getDir _unit;
			_lastDir = _x select 3;
			if (isNil "_lastDir") then {_lastDir = -999};
			_dirDiff = abs (_dir - _lastDir);
			if (_dirDiff > 180) then {_dirDiff = 360 - _dirDiff};
			if (_dirDiff > 7) then {
				_mk setMarkerDirLocal _dir;
				_x set [3, _dir];
			};
			_keep = _keep + [_x];
		} else {
			deleteMarkerLocal _mk;
		};
	} forEach _trackedAir;
	_trackedAir = _keep;

	if (visibleMap || shownGPS) then {sleep 0.5} else {sleep 5};  //--- A2-fix 2026-06-14: map-aware cadence (smooth arrows while map open, idle slow otherwise)
};
