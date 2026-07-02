//--- Init_SmugAir.sqf — Neutral AN-2 Smuggler Run (periodic bounty event).
//--- Spawns a civilian AN-2 biplane on a fixed cross-map route.  Shooting it down
//--- grants the killer's side a supply bounty (WFBE_C_SMUGGLER_BOUNTY).
//--- SERVER-LOCAL: spawned on the server, visible to all clients by engine replication.
//---
//--- Flag gate : WFBE_C_SMUGGLER_ENABLE (default 0 — dark).  Set to 1 in Parameters.hpp
//--- or WFBE_ServerConfig.sqf to activate.
//---
//--- Routes (per worldName, hardcoded 2D + configurable altitude):
//---   Chernarus  (~15360): [1800,8000] -> [5500,12000] -> [11000,11000] -> [14800,7000] CYCLE
//---   Takistan   (~10240): [1000,4000] -> [3200,7500]  -> [6500,7000]  -> [9000,4500]  CYCLE
//---   Zargabad   ( ~5120): [500,2000]  -> [1600,3800]  -> [3200,3500]  -> [4500,2200]  CYCLE
//---   Other maps: feature skips with a log line.
//---
//--- A2 OA 1.64 safe: no A3 commands; no Boolean == comparisons; no inline private _x=.

scriptName "Server\Init\Init_SmugAir.sqf";

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_SMUGGLER_ENABLE", 0]) != 1) exitWith {
	["INFORMATION", "Init_SmugAir.sqf: WFBE_C_SMUGGLER_ENABLE=0 - feature OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", "Init_SmugAir.sqf: Smuggler AN-2 feature ENABLED."] Call WFBE_CO_FNC_LogContent;

//--- ── tunables (all overridable via missionNamespace before this script runs) ────
private ["_cls","_pilotCls","_alt","_bounty","_interval","_markerOn"];
_cls      = missionNamespace getVariable ["WFBE_C_SMUGGLER_CLASS",    "An2_1_TK_CIV_EP1"];
_pilotCls = missionNamespace getVariable ["WFBE_C_SMUGGLER_PILOT",    "TK_CIV_Woodcutter_EP1"];
_alt      = missionNamespace getVariable ["WFBE_C_SMUGGLER_ALTITUDE", 350];
_bounty   = missionNamespace getVariable ["WFBE_C_SMUGGLER_BOUNTY",   5000];
_interval = missionNamespace getVariable ["WFBE_C_SMUGGLER_INTERVAL", 900];
_markerOn = missionNamespace getVariable ["WFBE_C_SMUGGLER_MARKER",   1];

//--- ── per-world route (4 waypoints + CYCLE back) ────────────────────────────────
//--- Coords kept inside each map's bounds; unsupported maps skip the feature.
private ["_route","_routeDefined"];
_routeDefined = true;
_route = [];
if (worldName == "chernarus") then {
	_route = [
		[1800,  8000, _alt],
		[5500, 12000, _alt],
		[11000,11000, _alt],
		[14800, 7000, _alt]
	];
};
if (worldName == "takistan") then {
	_route = [
		[1000, 4000, _alt],
		[3200, 7500, _alt],
		[6500, 7000, _alt],
		[9000, 4500, _alt]
	];
};
if (worldName == "zargabad") then {
	_route = [
		[ 500, 2000, _alt],
		[1600, 3800, _alt],
		[3200, 3500, _alt],
		[4500, 2200, _alt]
	];
};
if (count _route == 0) then {
	_routeDefined = false;
	["WARNING", "Init_SmugAir.sqf: No smuggler route defined for map '" + worldName + "' - feature disabled on this map."] Call WFBE_CO_FNC_LogContent;
};

if (!_routeDefined) exitWith {};

//--- ── main loop ─────────────────────────────────────────────────────────────────
while {!WFBE_GameOver} do {

	//--- spawn group + plane ─────────────────────────────────────────────────────
	private ["_grp","_wp0","_plane","_pilot","_spawnOk"];
	_wp0 = _route select 0;

	_grp   = createGroup civilian;
	_plane = createVehicle [_cls, _wp0, [], 0, "FLY"];
	_plane setPosASL _wp0;
	_plane flyInHeight _alt;

	//--- null-guard: EP1 class missing on a vanilla-only server.
	//--- Do NOT use exitWith here — it would exit the while and permanently kill the
	//--- feature. Instead set _spawnOk=false, clean up the empty group, sleep and
	//--- let the loop continue on its own.
	_spawnOk = !isNull _plane;
	if (!_spawnOk) then {
		deleteGroup _grp;
		["WARNING", "Init_SmugAir.sqf: createVehicle returned null for class " + _cls + " — skipping this cycle."] Call WFBE_CO_FNC_LogContent;
		sleep _interval;
	};

	//--- everything below runs only when the spawn succeeded
	if (_spawnOk) then {

		//--- register hit-EH so wfbe_lasthitby is maintained (needed by the killed-EH
		//--- fallback and by RequestOnUnitKilled for indirect kills / artillery).
		//--- Pattern matches Common_CreateVehicle line 68.
		_plane addEventHandler ["hit", {_this Spawn WFBE_CO_FNC_OnUnitHit}];

		_pilot = _grp createUnit [_pilotCls, _wp0, [], 0, "NONE"];
		_pilot moveInDriver _plane;

		_grp setBehaviour "SAFE";
		_grp setCombatMode "BLUE";
		_grp setSpeedMode "FULL";

		//--- tag so GC and other loops can identify / ignore this vehicle
		_plane setVariable ["wfbe_smuggler", true, true];
		_plane setVariable ["wfbe_trashed",  false];

		//--- waypoints (CYCLE so the plane loops the route if never shot down)
		private ["_wpList","_i","_wpPos"];
		_wpList = [];
		_i = 0;
		while {_i < count _route} do {
			_wpPos = _route select _i;
			_wpList = _wpList + [[_wpPos, "MOVE", 50, 60, [], [], []]];
			_i = _i + 1;
		};
		//--- close the loop with CYCLE back to the first waypoint
		_wpList = _wpList + [[_route select 0, "CYCLE", 50, 60, [], [], []]];
		[_grp, true, _wpList] Call WFBE_CO_FNC_WaypointsAdd;

		//--- killed event handler (server-side) ──────────────────────────────────────
		_plane addEventHandler ["killed", {
			private ["_veh","_killer","_killerSide","_bountyAmt","_mkID","_mkSuffix"];
			_veh    = _this select 0;
			_killer = _this select 1;

			//--- last-hit fallback (AA/artillery — killer may be ObjNull at EH time)
			if (isNull _killer) then {
				_killer = _veh getVariable ["wfbe_lasthitby", objNull];
			};
			if (isNull _killer) exitWith {};

			_killerSide = side _killer;
			//--- civilian kills are not credited (GUER spawns as resistance, not civilian;
			//--- civilian side check catches editor-placed objects / scripted kills only)
			if (_killerSide == civilian) exitWith {};

			_bountyAmt = missionNamespace getVariable ["WFBE_C_SMUGGLER_BOUNTY", 5000];
			if (_bountyAmt > 0) then {
				[_killerSide, _bountyAmt, "Smuggler AN-2 kill bounty", false] Call ChangeSideSupply;
				["INFORMATION", Format ["Init_SmugAir.sqf: Smuggler downed by side %1, bounty=%2.", _killerSide, _bountyAmt]] Call WFBE_CO_FNC_LogContent;
			};

			//--- optional kill marker (90s TTL, global broadcast via server createMarker).
			//--- Marker name gets floor(time) suffix so each kill within the 90s TTL
			//--- produces a distinct name rather than silently no-oping on the existing one.
			if ((missionNamespace getVariable ["WFBE_C_SMUGGLER_MARKER", 1]) == 1) then {
				private ["_mkID","_mkSuffix"];
				_mkSuffix = floor time;
				_mkID = "smuggler_kill_mk_" + str(_mkSuffix);
				createMarker [_mkID, getPos _veh];
				_mkID setMarkerType  "mil_destroy";
				_mkID setMarkerColor "ColorYellow";
				_mkID setMarkerText  "Smuggler Downed";
				[_mkID] spawn {sleep 90; deleteMarker (_this select 0)};
			};
		}];

		//--- wait until dead or mission over ─────────────────────────────────────────
		waitUntil {sleep 10; (!alive _plane) || WFBE_GameOver};

		//--- cleanup
		private ["_crew","_j"];
		_crew = crew _plane;
		_j = 0;
		while {_j < count _crew} do {
			deleteVehicle (_crew select _j);
			_j = _j + 1;
		};
		deleteVehicle _plane;
		deleteGroup _grp;

		["INFORMATION", "Init_SmugAir.sqf: Smuggler AN-2 cleaned up. Next run in " + str(_interval) + "s."] Call WFBE_CO_FNC_LogContent;

		//--- interval before next run (skip if game over)
		if (!WFBE_GameOver) then {sleep _interval};
	};
};
