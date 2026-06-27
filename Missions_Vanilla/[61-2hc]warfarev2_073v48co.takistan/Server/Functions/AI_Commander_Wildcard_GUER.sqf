/*
	GUER (resistance) Wildcard Events — a base-less insurgent deck (Ray 2026-06-27).
	Server-side; ONE worker spawned for resistance from Init_Server. GUER has no HQ/economy, so this is a
	separate, base-less deck (the conventional AI_Commander_Wildcard.sqf assumes HQ + commander funds + tiers).

	DECK:
	  G1 Car Bomb (6)        — a driver-detonated SVBIED rolls into an OCCUPIED (WEST/EAST) town; kill-bounty to
	                           whoever destroys it (the proven W21 VBIED idiom under its rightful owner).
	  G2 Pop-up Checkpoint(8) — INTERACTIVE EVENT. Insurgents throw a roadblock onto an occupied town's supply
	                           road and shake down the occupiers. Persistent, two-sided, marker-driven:
	                           * The roadblock FIELDS WHATEVER GUER HAS UNLOCKED — it reads WFBE_GUER_VEHICLE_TIER
	                             (the kill-driven progression from Server_GuerStipend): tier0 technical -> tier1 BRDM
	                             -> tier2 T-55 -> tier3 T-72. The insurgency's progression is visible on the roads.
	                           * While it STANDS: it taxes the occupier (drains their supply) and pays GUER players a
	                             toll. The occupier feels it; GUER players get cash.
	                           * Resolution = faction PROGRESSION for the winner (Ray's model):
	                               - Conventional team CLEARS it (wipes the manning force) -> that team's owning side
	                                 gets a SUPPLY injection (fuels their research/upgrade ladder) + the kill-bounty.
	                               - GUER HOLDS it to timeout -> a FOB FACTORY TOKEN (WFBE_GUER_FOB_AVAIL), type scaled
	                                 by the checkpoint tier: tier0-1 Barracks / tier2 Light Factory / tier3 Heavy Factory.
	                                 i.e. a held checkpoint = captured materiel to deploy a forward factory of that type.

	PAYOUT MODEL: GUER is base-less, so cash goes straight to GUER players via the EXISTING client PVFunction
	  GuerVbiedBounty, sent to the resistance SIDE object (Client_HandlePVF matches a SIDE dest against sideJoined;
	  a STRING "GUER" would be read as a player UID and match no one).

	A2 OA 1.64 compat: private string-array only; reuse proven CreateVehicle/CreateGroup/CreateUnit/AIPatrol idioms.

	Tunables:
	  WFBE_C_GUER_WILDCARD            default 1 (0=disable)
	  WFBE_C_GUER_WILDCARD_INTERVAL  default 1800
	  WFBE_C_GUER_CP_WINDOW          default 600   (checkpoint lifetime, seconds)
	  WFBE_C_GUER_CP_TAX             default 60    (occupier supply drained per 30s tick, scaled by tier)
	  WFBE_C_GUER_CP_TOLL            default 250   (cash paid to GUER players per 30s tick, scaled by tier)
	  WFBE_C_GUER_CP_CLEAR           default 700   (supply granted to the clearing side, scaled by tier)
	  (held-to-timeout grants one FOB factory token of a tier-scaled type - no tunable; always exactly one)
*/

private ["_enabled","_interval","_sideID"];

if (!isServer) exitWith {};

_enabled  = missionNamespace getVariable ["WFBE_C_GUER_WILDCARD", 1];
_interval = missionNamespace getVariable ["WFBE_C_GUER_WILDCARD_INTERVAL", 1800];

["INITIALIZATION", Format ["AI_Commander_Wildcard_GUER.sqf: worker started (interval=%1s, enabled=%2).", _interval, _enabled]] Call WFBE_CO_FNC_AICOMLog;

if (_enabled == 0) exitWith {
	["INFORMATION", "AI_Commander_Wildcard_GUER.sqf: disabled (WFBE_C_GUER_WILDCARD=0)."] Call WFBE_CO_FNC_AICOMLog;
};

_sideID = resistance Call WFBE_CO_FNC_GetSideID;

sleep _interval;

while {!gameOver} do {

	sleep (random 30);   //--- jitter (de-correlate from the WEST/EAST workers)

	[_sideID] spawn {
		private ["_sideID","_westID","_eastID","_occTowns","_owned","_gG1","_gG2","_weights","_cumSum","_roll",
		         "_i","_chosen","_draw","_result","_detail","_soldierClass","_vbiedClass","_target","_nearD",
		         "_candTown","_dd","_targetPos","_ang","_spawnPos","_try","_roads","_truck","_grp","_drv",
		         "_tier","_cpVeh","_cpLabel","_veh","_d1","_d2","_n","_footN","_u","_pos","_mk","_occSide",
		         "_locMsg","_wName","_wDesc","_wMap"];

		_sideID = _this select 0;
		_westID = west Call WFBE_CO_FNC_GetSideID;
		_eastID = east Call WFBE_CO_FNC_GetSideID;

		//--- OCCUPIED towns = held by WEST or EAST (GUER harasses the conventional occupiers).
		_occTowns = [];
		{ if (((_x getVariable ["sideID","?"]) == _westID) || {(_x getVariable ["sideID","?"]) == _eastID}) then {_occTowns = _occTowns + [_x]} } forEach towns;
		_owned = [];
		{ if ((_x getVariable ["sideID","?"]) == _sideID) then {_owned = _owned + [_x]} } forEach towns;

		_soldierClass = missionNamespace getVariable ["WFBE_GUERRESSOLDIER", ""];
		_vbiedClass   = missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"];

		//--- ELIGIBILITY -> weights (0 = ineligible).
		_gG1 = 6; _gG2 = 8;
		if (!(count _occTowns > 0 && {_soldierClass != ""} && {isClass (configFile >> "CfgVehicles" >> _vbiedClass)})) then {_gG1 = 0};
		if (!(count _occTowns > 0 && {_soldierClass != ""})) then {_gG2 = 0};

		_weights = [[1,_gG1],[2,_gG2]];
		_cumSum = 0; { _cumSum = _cumSum + (_x select 1) } forEach _weights;
		_draw = 0;
		if (_cumSum > 0) then {
			_roll = random _cumSum; _i = 0;
			{ _i = _i + (_x select 1); if (_roll < _i && {_draw == 0}) then {_draw = _x select 0} } forEach _weights;
		};
		if (_draw == 0) exitWith {};   //--- nothing eligible this cycle

		_result = "applied"; _detail = "";

		//--- TARGET: occupied town nearest a GUER-held town (the front); else a random occupied town.
		_target = objNull; _nearD = 1e9;
		{
			_candTown = _x; _dd = 1e9;
			{ _dd = _dd min (_candTown distance _x) } forEach _owned;
			if (count _owned == 0) then {_dd = 0};
			if (_dd < _nearD) then {_nearD = _dd; _target = _candTown};
		} forEach _occTowns;
		if (isNull _target && {count _occTowns > 0}) then {_target = _occTowns select floor(random count _occTowns)};

		switch (_draw) do {

			//--- G1: CAR BOMB (SVBIED) — bounty=true -> RequestOnUnitKilled pays the destroyer.
			case 1: {
				if (!isNull _target) then {
					_targetPos = getPos _target;
					_ang = random 360;
					_spawnPos = [(_targetPos select 0) + 700 * sin _ang, (_targetPos select 1) + 700 * cos _ang, 0];
					_try = 0;
					while {surfaceIsWater _spawnPos && {_try < 20}} do {
						_ang = random 360;
						_spawnPos = [(_targetPos select 0) + 700 * sin _ang, (_targetPos select 1) + 700 * cos _ang, 0];
						_try = _try + 1;
					};
					_roads = _spawnPos nearRoads 120;
					if (count _roads > 0) then {_spawnPos = getPos (_roads select 0)};
					_truck = [_vbiedClass, _spawnPos, resistance, random 360, false, true] Call WFBE_CO_FNC_CreateVehicle;
					if (!isNull _truck) then {
						_grp = [resistance, "guer-wc-vbied"] Call WFBE_CO_FNC_CreateGroup;
						if (!isNull _grp) then {
							_drv = [_soldierClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
							if (!isNull _drv) then {
								_drv moveInDriver _truck;
								_drv setVariable ["WFBE_IsTownDefenderAI", true, true];
								_grp setBehaviour "CARELESS"; _grp setCombatMode "BLUE";
								{_drv disableAI _x} forEach ["AUTOTARGET","TARGET"];
								_drv doMove _targetPos;
								[_truck, _targetPos, _grp] spawn {
									private ["_v","_tgt","_g","_el","_boom","_p"];
									_v = _this select 0; _tgt = _this select 1; _g = _this select 2;
									_el = 0; _boom = false;
									waitUntil { sleep 1; _el = _el + 1;
										if (isNull _v || {!alive _v}) then {_boom = true};
										if (!isNull _v && {alive _v} && {(_v distance _tgt) < 25}) then {_boom = true};
										if (_el >= 600) then {_boom = true};
										(_boom || gameOver) };
									if (!isNull _v && {alive _v}) then {
										_p = getPosATL _v; _v setDamage 1;
										"Bo_FAB_250" createVehicle _p; "Bo_FAB_250" createVehicle _p; "Bo_FAB_250" createVehicle _p;
									};
									sleep 3;
									{deleteVehicle _x} forEach (crew _v);
									if (!isNull _v) then {deleteVehicle _v};
									if (!isNull _g) then {deleteGroup _g};
								};
								_detail = Format ["target=%1 chassis=%2 spawnD=%3", _target getVariable ["name","?"], _vbiedClass, round (_spawnPos distance _targetPos)];
							} else { deleteVehicle _truck; deleteGroup _grp; _result = "partial"; _detail = "G1 createUnit null"; };
						} else { deleteVehicle _truck; _result = "partial"; _detail = "G1 group null"; };
					} else { _result = "ineligible"; _detail = Format ["G1 createVehicle null for %1", _vbiedClass]; };
				} else { _result = "ineligible"; _detail = "G1 no occupied town"; };
			};

			//--- G2: POP-UP CHECKPOINT — interactive roadblock that FIELDS GUER'S UNLOCKED TIER vehicle.
			case 2: {
				if (!isNull _target) then {
					_targetPos = getPos _target;
					//--- Spawn anchor ~280m out from the town on a random bearing, snapped to the nearest road
					//--- (the "supply road"); re-roll if it lands in water (mirrors the VBIED idiom).
					_ang = random 360;
					_spawnPos = [(_targetPos select 0) + 280 * sin _ang, (_targetPos select 1) + 280 * cos _ang, 0];
					_try = 0;
					while {surfaceIsWater _spawnPos && {_try < 20}} do {
						_ang = random 360;
						_spawnPos = [(_targetPos select 0) + 280 * sin _ang, (_targetPos select 1) + 280 * cos _ang, 0];
						_try = _try + 1;
					};
					_roads = _spawnPos nearRoads 150;
					if (count _roads > 0) then {_spawnPos = getPos (_roads select 0)};

					//--- READ GUER'S KILL-DRIVEN PROGRESSION: the roadblock fields whatever the insurgency has unlocked.
					_tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
					//--- Map-correct GUER tier vehicle (mirrors Root_GUE_PlayerOverlay's roster).
					if (worldName == "Chernarus") then {
						_cpVeh = switch (_tier) do {case 1:{"BRDM2_Gue"}; case 2:{"T55_TK_GUE_EP1"}; case 3:{"T72_Gue"}; default {"Offroad_DSHKM_Gue"}};
					} else {
						_cpVeh = switch (_tier) do {case 1:{"BRDM2_TK_GUE_EP1"}; case 2:{"T55_TK_GUE_EP1"}; case 3:{"T55_TK_GUE_EP1"}; default {"Offroad_DSHKM_TK_GUE_EP1"}};
					};
					if (!isClass (configFile >> "CfgVehicles" >> _cpVeh)) then {_cpVeh = _vbiedClass};   //--- safety fallback
					_cpLabel = switch (_tier) do {case 1:{"BRDM checkpoint"}; case 2:{"T-55 strongpoint"}; case 3:{"T-72 stronghold"}; default {"technical roadblock"}};

					_grp = [resistance, "guer-wc-checkpoint"] Call WFBE_CO_FNC_CreateGroup;
					if (!isNull _grp) then {
						//--- The manning vehicle (bounty=true -> destroyer paid via RequestOnUnitKilled), crewed.
						_veh = [_cpVeh, _spawnPos, resistance, _ang, false, true] Call WFBE_CO_FNC_CreateVehicle;
						if (!isNull _veh) then {
							_d1 = [_soldierClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
							if (!isNull _d1) then {_d1 moveInDriver _veh; _d1 setVariable ["WFBE_IsTownDefenderAI", true, true]};
							_d2 = [_soldierClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
							if (!isNull _d2) then {_d2 moveInGunner _veh; _d2 setVariable ["WFBE_IsTownDefenderAI", true, true]};
						};
						//--- Foot fireteam manning the block (scaled by tier), dug in on the road.
						_footN = 3 + _tier;
						for "_n" from 1 to _footN do {
							_pos = [(_spawnPos select 0) + (random 16) - 8, (_spawnPos select 1) + (random 16) - 8, 0];
							_u = [_soldierClass, _grp, _pos, _sideID] Call WFBE_CO_FNC_CreateUnit;
							if (!isNull _u) then {_u setVariable ["WFBE_IsTownDefenderAI", true, true]};
						};
						[_grp, _spawnPos, 60] Call AIPatrol;
						_grp setBehaviour "AWARE"; _grp setCombatMode "RED";

						//--- Global map marker (enemy-visible ON PURPOSE - this is a contested objective, not a stealth patrol).
						_mk = Format ["guer_cp_%1_%2", round time, round (random 99999)];
						createMarker [_mk, _spawnPos];
						_mk setMarkerType "mil_warning";
						_mk setMarkerColor "ColorGreen";
						_mk setMarkerText Format ["Insurgent Checkpoint (%1)", _cpLabel];

						//--- Snapshot the occupier we tax + reward (town owner at spawn).
						_occSide = west;
						if ((_target getVariable ["sideID","?"]) == _eastID) then {_occSide = east};

						//--- WATCHER: tax while it stands; resolve to faction progression on clear/timeout; clean up.
						[_grp, _veh, _target, _occSide, _mk, _tier, _cpLabel] spawn {
							private ["_g","_v","_town","_occ","_marker","_t","_label","_el","_window","_cleared",
							         "_taxAmt","_toll","_clear","_fobIdx","_fobAvail","_fobName","_x"];
							_g = _this select 0; _v = _this select 1; _town = _this select 2; _occ = _this select 3;
							_marker = _this select 4; _t = _this select 5; _label = _this select 6;

							_window  = missionNamespace getVariable ["WFBE_C_GUER_CP_WINDOW", 600];
							_taxAmt  = (missionNamespace getVariable ["WFBE_C_GUER_CP_TAX",  60])  * (1 + _t);
							_toll    = (missionNamespace getVariable ["WFBE_C_GUER_CP_TOLL", 250])  * (1 + _t);
							_clear   = (missionNamespace getVariable ["WFBE_C_GUER_CP_CLEAR",700])  * (1 + _t);

							_el = 0; _cleared = false;
							while {!_cleared && {_el < _window} && {!gameOver}} do {
								sleep 30; _el = _el + 30;
								//--- CLEAR check: the manning force (crew + foot all in _g) is wiped.
								if (({alive _x} count (units _g)) == 0) then {_cleared = true};
								if (!_cleared) then {
									//--- TAX tick: drain the occupier's supply, pay GUER players a toll.
									[_occ, -_taxAmt, "Insurgent checkpoint tax.", false] Call ChangeSideSupply;
									[resistance, "GuerVbiedBounty", _toll] Call WFBE_CO_FNC_SendToClients;
								};
							};

							if (_cleared) then {
								//--- WINNER = the occupier whose supply road it threatened: SUPPLY (research fuel) for their ladder.
								[_occ, _clear, "Insurgent checkpoint cleared - supply recovered.", false] Call ChangeSideSupply;
								[nil, "LocalizeMessage", ["Wildcard", Format ["[Wildcard] %1 cleared the Insurgent Checkpoint near %2 (+supply).", str _occ, _town getVariable ["name","?"]]]] Call WFBE_CO_FNC_SendToClients;
								diag_log format ["AICOMSTAT|v2|EVENT|GUER|%1|GUERCP_CLEARED|%2|byOcc=%3|clearSupply=%4", round (time/60), _label, str _occ, _clear];
							} else {
								//--- GUER HELD it to timeout: grant a FOB FACTORY TOKEN (Ray 2026-06-27; REPLACES the old
								//--- vehicle-tier kill-progress). Token TYPE scales with the checkpoint tier (= GUER vehicle tier):
								//--- tier 0-1 Barracks, tier 2 Light Factory, tier 3 Heavy Factory. Mirrors the FOB grant in
								//--- Server_BuildingKilled.sqf (copy [B,LF,HF], bump the index, publicVariable) so the depot FOB-truck
								//--- pool + the RHUD "B|LF|HF" row both pick it up - i.e. a held checkpoint = captured materiel to
								//--- deploy a forward factory of that type.
								_fobIdx = 0;
								if (_t >= 2) then {_fobIdx = 1};
								if (_t >= 3) then {_fobIdx = 2};
								_fobName  = ["Barracks","Light Factory","Heavy Factory"] select _fobIdx;
								_fobAvail = + (missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]]);
								_fobAvail set [_fobIdx, (_fobAvail select _fobIdx) + 1];
								missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _fobAvail];
								publicVariable "WFBE_GUER_FOB_AVAIL";
								[nil, "LocalizeMessage", ["Wildcard", Format ["[Wildcard] The Insurgent Checkpoint near %1 held - captured materiel: %2 FOB unlocked.", _town getVariable ["name","?"], _fobName]]] Call WFBE_CO_FNC_SendToClients;
								diag_log format ["AICOMSTAT|v2|EVENT|GUER|%1|GUERCP_HELD|%2|fobToken=%3|avail=%4", round (time/60), _label, _fobName, str _fobAvail];
							}

							//--- CLEANUP: husk + crew + foot + group + marker.
							if (!isNull _v) then {{deleteVehicle _x} forEach (crew _v); deleteVehicle _v};
							{deleteVehicle _x} forEach (units _g);
							if (!isNull _g) then {deleteGroup _g};
							deleteMarker _marker;
						};

						_detail = Format ["target=%1 tier=%2 veh=%3 foot=%4 window=%5s", _target getVariable ["name","?"], _tier, _cpVeh, _footN, missionNamespace getVariable ["WFBE_C_GUER_CP_WINDOW", 600]];
					} else { _result = "partial"; _detail = "G2 group null at cap"; };
				} else { _result = "ineligible"; _detail = "G2 no occupied town"; };
			};
		};

		//--- Logging (mirror the conventional worker's AICOMSTAT line).
		["INFORMATION", Format ["AI_Commander_Wildcard_GUER.sqf: [GUER-WILDCARD] draw=G%1 result=%2 detail=(%3)", _draw, _result, _detail]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time / 60)) + "|GUERWILDCARD_G" + str _draw + "|" + _result + "|" + _detail);

		//--- Announcement: broadcast the insurgent strike to ALL clients (telegraph). The checkpoint also posts its
		//--- own resolution line from the watcher above; this is the initial "it appeared" beat.
		_wMap = [
			[1,"Car Bomb","a suicide car bomb rolls on an occupied town - destroy it for a bounty"],
			[2,"Pop-up Checkpoint","a roadblock chokes an occupied supply road - clear it for supply, or it bleeds you"]
		];
		_wName = Format ["G%1", _draw]; _wDesc = "";
		{if ((_x select 0) == _draw) exitWith {_wName = _x select 1; _wDesc = _x select 2}} forEach _wMap;
		_locMsg = Format ["[Wildcard] Insurgents (GUER) struck: %1 - %2.", _wName, _wDesc];
		[nil, "LocalizeMessage", ["Wildcard", _locMsg]] Call WFBE_CO_FNC_SendToClients;

	}; //--- end isolation spawn

	sleep _interval;
};
