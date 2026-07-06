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
		  (G4 Mortar Pit card SHELVED — Ray 2026-07-02 "Shelve mortar pit"; see wiki Shelved-GUER-wildcard-mortar-pit.)
	  G5 Scavenger Team (5)  — flag WFBE_C_GUER_SCAV default 0. Eligibility = >=2 alive mission objects with
	                           wfbe_aicom_abandoned=true; spawn a 4-man foot team (GUE_Soldier_1) at a GUER-owned
	                           town; MOVE to the nearest abandoned wreck; 30s scavenge delay; award
	                           WFBE_C_GUER_SCAV_REWARD (default 300) per wreck to GUER players via GuerVbiedBounty
	                           PVF + deleteVehicle the wreck; player-kill bounty WFBE_C_GUER_SCAV_PLAYER_BONUS
	                           (default 150) via WFBE_IsTownDefenderAI=true on crew; despawn after
	                           WFBE_C_GUER_SCAV_TTL (default 300s) or crew wiped.

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
	  WFBE_C_GUER_SCAV               default 0     (0=disable G5 Scavenger Team card)
	  WFBE_C_GUER_SCAV_REWARD        default 300   (cash per wreck scrapped, paid to GUER players)
	  WFBE_C_GUER_SCAV_PLAYER_BONUS  default 150   (extra kill-bounty on each scav team member)
	  WFBE_C_GUER_SCAV_TTL           default 300   (scav team despawn timeout in seconds)
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
		private ["_sideID","_westID","_eastID","_occTowns","_owned","_gG1","_gG2","_gG5",
		         "_weights","_cumSum","_roll",
		         "_i","_chosen","_draw","_result","_detail","_soldierClass","_vbiedClass","_target","_nearD",
		         "_candTown","_dd","_targetPos","_ang","_spawnPos","_try","_roads","_truck","_grp","_drv",
		         "_tier","_cpVeh","_cpLabel","_veh","_d1","_d2","_n","_footN","_u","_pos","_mk","_occSide",
		         "_locMsg","_wName","_wDesc","_wMap","_g1Mk",
		         "_abandVehs","_scavTeam","_scavGrp","_nearWreck","_scavDist","_scavReward",
		         "_scavBonus","_scavTTL","_scavMember","_scavPos"];

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
		//--- G4 Mortar Pit card SHELVED (Ray 2026-07-02) — removed from the deck so it can never be drawn.
		_gG1 = 6; _gG2 = 8; _gG5 = 0;
		if (!(count _occTowns > 0 && {_soldierClass != ""} && {isClass (configFile >> "CfgVehicles" >> _vbiedClass)})) then {_gG1 = 0};
		if (!(count _occTowns > 0 && {_soldierClass != ""})) then {_gG2 = 0};

		//--- G5: SCAVENGER TEAM eligibility: flag on, >=2 abandoned wrecks, GUER owns at least one town (spawn anchor).
		if ((missionNamespace getVariable ["WFBE_C_GUER_SCAV", 0]) > 0 && {_soldierClass != ""} && {count _owned > 0}) then {
			_abandVehs = [];
			{ if (!isNull _x && {alive _x} && {_x getVariable ["wfbe_aicom_abandoned", false]}) then {_abandVehs = _abandVehs + [_x]} } forEach allMissionObjects "LandVehicle";
			{ if (!isNull _x && {alive _x} && {_x getVariable ["wfbe_aicom_abandoned", false]}) then {_abandVehs = _abandVehs + [_x]} } forEach allDead;
			if (count _abandVehs >= 2) then {_gG5 = 5};
		};

		_weights = [[1,_gG1],[2,_gG2],[5,_gG5]];
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
								//--- MAP MARKER (feature: wildcard events show on the map for the OWNING side).
								//--- G1 belongs to GUER, so the marker is broadcast to the resistance SIDE object
								//--- via WFBE_CO_FNC_SendToClients - Client_HandlePVF matches a SIDE dest against
								//--- sideJoined, so ONLY GUER players' clients createMarkerLocal it (the occupiers it
								//--- targets do NOT see this telegraph; it points GUER players at their car bomb).
								//--- A short-lived watcher deletes it when the truck resolves (death/arrival) or at the
								//--- 600s watcher cap - one marker per active event, always cleaned up.
								_g1Mk = Format ["wc_GUER_G1_%1", round time];
								[resistance, "WildcardMarker", ["create", _g1Mk, _targetPos, "ColorGreen", "mil_destroy", "Car Bomb", "GUER VBIED rolling toward the marked town"]] Call WFBE_CO_FNC_SendToClients;
								[_truck, _targetPos, _g1Mk] spawn {
									private ["_v","_tgt","_mk","_el"];
									_v = _this select 0; _tgt = _this select 1; _mk = _this select 2; _el = 0;
									waitUntil { sleep 2; _el = _el + 2;
										(isNull _v || {!alive _v} || {(_v distance _tgt) < 25} || {_el >= 600} || gameOver) };
									[resistance, "WildcardMarker", ["delete", _mk]] Call WFBE_CO_FNC_SendToClients;
								};
								_detail = Format ["target=%1 chassis=%2 spawnD=%3", _target getVariable ["name","?"], _vbiedClass, round (_spawnPos distance _targetPos)];
							} else { deleteVehicle _truck; deleteGroup _grp; _result = "partial"; _detail = "G1 createUnit null"; };
						} else { deleteVehicle _truck; _result = "partial"; _detail = "G1 group null"; };
					} else { _result = "ineligible"; _detail = Format ["G1 createVehicle null for %1", _vbiedClass]; };
				} else { _result = "ineligible"; _detail = "G1 no occupied town"; };
			};

			//--- G2: POP-UP CHECKPOINT — interactive roadblock that FIELDS GUER'S UNLOCKED TIER vehicle.
			case 2: {
				//--- ===== G2 v2 (flag WFBE_C_GUER_CP_V2, default 0): road-snapped, road-aligned, physically
				//--- blocking checkpoint - FORT_CHECKPOINT composition + manned MG statics + posted garrison +
				//--- a one-shot reinforcement pulse. Flag 0 = ONLY the untouched v1 block (else-branch) runs.
				if ((missionNamespace getVariable ["WFBE_C_GUER_CP_V2", 0]) > 0) then {
					private ["_cp2Radius","_cp2FootBase","_cp2FootPer","_cands","_road","_rPos","_dTown","_conn",
					         "_bestRoad","_bestScore","_bestConn","_score","_dir","_dx","_dy","_neighbor","_nPos",
					         "_roadDist","_cpTmpl","_cpObjs","_statics","_tCls","_tRelPos","_tRelDir","_wPos","_obj",
					         "_statCls","_statSpecs","_sOff","_sDir","_statPos","_stat","_sGunner","_gpOffs","_gOff",
					         "_gPos","_vehPos",
					         "_armExtra","_armN","_ax","_aLat","_aBack","_aPos","_aVeh","_ad1","_ad2"];
					if (!isNull _target) then {
						_targetPos = getPos _target;
						_cp2Radius   = missionNamespace getVariable ["WFBE_C_GUER_CP2_ROAD_RADIUS", 400];
						_cp2FootBase = missionNamespace getVariable ["WFBE_C_GUER_CP2_FOOT_BASE", 4];
						_cp2FootPer  = missionNamespace getVariable ["WFBE_C_GUER_CP2_FOOT_PER_TIER", 2];

						//--- (1) ROAD-FIRST PLACEMENT: real road segments around the town, never a random-bearing offset.
						//--- Filter: dry land, junction connectivity >=2 (guarded roadsConnectedTo idiom copied from the
						//--- _isUsableRoad helper in AI_Commander_Base.sqf - OA-only command, degrades to ACCEPT on Vanilla),
						//--- stand-off band 180-380m from the town centre. Pick the candidate nearest the v1 280m feel.
						_cands = _targetPos nearRoads _cp2Radius;
						_bestRoad = objNull; _bestScore = 1e9; _bestConn = [];
						{
							_road = _x;   //--- capture outer _x before any nested code (house rule).
							_rPos = getPos _road;
							if (!(surfaceIsWater _rPos)) then {
								_dTown = _rPos distance _targetPos;
								if (_dTown >= 180 && {_dTown <= 380}) then {
									_conn = [];
									//--- roadsConnectedTo exists only on OA-class builds; never let it throw on Vanilla.
									if (!isNil {missionNamespace getVariable "WF_A2_Vanilla"} && {!WF_A2_Vanilla}) then {
										_conn = _road call {private "_c"; _c = []; if (!isNil {roadsConnectedTo _this}) then {_c = roadsConnectedTo _this}; _c};
										if (count _conn < 2) then {_road = objNull};   //--- dead-end stub / field path: reject.
									};
									if (!isNull _road) then {
										_score = abs (_dTown - 280);
										if (_score < _bestScore) then {_bestScore = _score; _bestRoad = _road; _bestConn = _conn};
									};
								};
							};
						} forEach _cands;

						if (!isNull _bestRoad) then {
							_spawnPos = getPos _bestRoad;
							_roadDist = _spawnPos distance _targetPos;

							//--- (2) ROAD ALIGNMENT: face the block along the road axis (segment -> connected neighbour);
							//--- fall back to the town bearing when the connectivity probe returned empty (Vanilla path).
							if (count _bestConn > 0) then {
								_neighbor = _bestConn select 0;
								_nPos = getPos _neighbor;
								_dx = (_nPos select 0) - (_spawnPos select 0);
								_dy = (_nPos select 1) - (_spawnPos select 1);
							} else {
								_dx = (_targetPos select 0) - (_spawnPos select 0);
								_dy = (_targetPos select 1) - (_spawnPos select 1);
							};
							//--- zero-guard idiom as AI_Commander_Base.sqf ~L418 (atan2 [0,0] would degenerate).
							_dir = if (_dx == 0 && {_dy == 0}) then {random 360} else {_dx atan2 _dy};
							if (_dir < 0) then {_dir = _dir + 360};

							//--- READ GUER'S KILL-DRIVEN PROGRESSION (same roster + fallback as v1).
							_tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
							if (worldName == "Chernarus") then {
								_cpVeh = switch (_tier) do {case 1:{"BRDM2_Gue"}; case 2:{"T55_TK_GUE_EP1"}; case 3:{"T72_Gue"}; default {"Offroad_DSHKM_Gue"}};
							} else {
								_cpVeh = switch (_tier) do {case 1:{"BRDM2_TK_GUE_EP1"}; case 2:{"T55_TK_GUE_EP1"}; case 3:{"T55_TK_GUE_EP1"}; default {"Offroad_DSHKM_TK_GUE_EP1"}};
							};
							if (!isClass (configFile >> "CfgVehicles" >> _cpVeh)) then {_cpVeh = _vbiedClass};   //--- safety fallback
							_cpLabel = switch (_tier) do {case 1:{"BRDM checkpoint"}; case 2:{"T-55 strongpoint"}; case 3:{"T-72 stronghold"}; default {"technical roadblock"}};

							_grp = [resistance, "guer-wc-checkpoint"] Call WFBE_CO_FNC_CreateGroup;
							if (!isNull _grp) then {
								//--- (3) PHYSICAL BLOCK: the WFBE_NEURODEF_FORT_CHECKPOINT composition (Init_Defenses.sqf)
								//--- spawned on the road, rotated to the road axis. Model-space trig mirrors
								//--- Server_ConstructPosition.sqf; setDir convention (_dir - _relDir) mirrors
								//--- Server_CreateDefenseTemplate.sqf. Props are deliberately NOT wfbe_defense-tagged:
								//--- basearea.sqf _onAreaRemoved DELETES tagged objects whose class is in WFBE_%1DEFENSENAMES
								//--- (CncBlock_Stripes/fort_bagfence_long ARE on the WEST/EAST lists) near a removed base
								//--- area; OUR watcher below owns the full teardown, so the tag would only invite that sweep.
								_cpObjs = [];
								_cpTmpl = missionNamespace getVariable ["WFBE_NEURODEF_FORT_CHECKPOINT", []];
								{
									_tCls    = _x select 0;
									_tRelPos = _x select 1;
									_tRelDir = _x select 2;
									_wPos = [(_spawnPos select 0) + (_tRelPos select 0) * (cos _dir) + (_tRelPos select 1) * (sin _dir),
									         (_spawnPos select 1) - (_tRelPos select 0) * (sin _dir) + (_tRelPos select 1) * (cos _dir),
									         0];
									_obj = createVehicle [_tCls, [0,0,0], [], 0, "NONE"];
									_obj setDir (_dir - _tRelDir);
									_obj setPos _wPos;
									_cpObjs set [count _cpObjs, _obj];
								} forEach _cpTmpl;

								//--- Manning vehicle sits BEHIND the chicane on the road axis (bounty=true, road-aligned).
								_vehPos = [(_spawnPos select 0) + (-8) * (sin _dir),
								           (_spawnPos select 1) + (-8) * (cos _dir),
								           0];
								_veh = [_cpVeh, _vehPos, resistance, _dir, false, true] Call WFBE_CO_FNC_CreateVehicle;
								if (!isNull _veh) then {
									_d1 = [_soldierClass, _grp, _vehPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _d1) then {_d1 moveInDriver _veh; _d1 setVariable ["WFBE_IsTownDefenderAI", true, true]};
									_d2 = [_soldierClass, _grp, _vehPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _d2) then {_d2 moveInGunner _veh; _d2 setVariable ["WFBE_IsTownDefenderAI", true, true]};
								};

								//--- (4) STATICS: two GUER-manned DShKM MGs behind the bagfence guard positions
								//--- (composition-relative [-6,1] / [6,-1]; one covers each approach). Classnames are the
								//--- side's EXISTING statics (Core_GUE.sqf 'DSHKM_Gue' / Core_TKGUE.sqf 'DSHKM_TK_GUE_EP1' -
								//--- both already in the mission tree). Gunners join _grp so the CLEAR check counts them.
								//--- NOT wfbe_defense-tagged: AI_Commander_Base.sqf counts StaticWeapon entities by that tag
								//--- for BASE defense budgeting and these are not base defenses.
								_statCls = if (worldName == "Chernarus") then {"DSHKM_Gue"} else {"DSHKM_TK_GUE_EP1"};
								_statics = [];
								_statSpecs = [[[-6,1,0], 0], [[6,-1,0], 180]];
								{
									_sOff = _x select 0;
									_sDir = _dir + (_x select 1);
									_statPos = [(_spawnPos select 0) + (_sOff select 0) * (cos _dir) + (_sOff select 1) * (sin _dir),
									            (_spawnPos select 1) - (_sOff select 0) * (sin _dir) + (_sOff select 1) * (cos _dir),
									            0];
									_stat = [_statCls, _statPos, resistance, _sDir, false, true] Call WFBE_CO_FNC_CreateVehicle;
									if (!isNull _stat) then {
										_stat setPos _statPos;   //--- pin the exact composition spot (helper placement radius is 7m).
										_sGunner = [_soldierClass, _grp, _statPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
										if (!isNull _sGunner) then {
											_sGunner moveInGunner _stat;
											_sGunner setVariable ["WFBE_IsTownDefenderAI", true, true];
										};
										_statics set [count _statics, _stat];
									};
								} forEach _statSpecs;

								//--- (4b) EXTRA ARMOR (tier>=2, sub-tunable WFBE_C_GUER_CP2_ARMOR_EXTRA, default 1): additional
								//--- hull(s) of the SAME _cpVeh class posted as overwatch 25-35m BEHIND the block on the road
								//--- axis (never blocking the chicane). Tier 2 = extra T-55, tier 3 = extra T-72 - the "T-72
								//--- stronghold" fields 2x T-72. Map-correct for free: _cpVeh is already worldName-switched.
								//--- Hulls join _statics so BOTH watcher resolutions run the same player-safe teardown.
								_armN = 0;
								_armExtra = missionNamespace getVariable ["WFBE_C_GUER_CP2_ARMOR_EXTRA", 1];
								if (_tier >= 2 && {_armExtra > 0}) then {
									for "_ax" from 1 to _armExtra do {
										_aLat  = (_ax * 7) - 10;      //--- small lateral stagger so hulls never stack on the axis.
										_aBack = -25 - (random 10);   //--- 25-35m behind the block (manning hull sits at -8).
										_aPos = [(_spawnPos select 0) + _aLat * (cos _dir) + _aBack * (sin _dir),
										         (_spawnPos select 1) - _aLat * (sin _dir) + _aBack * (cos _dir),
										         0];
										_aVeh = [_cpVeh, _aPos, resistance, _dir, false, true] Call WFBE_CO_FNC_CreateVehicle;
										if (!isNull _aVeh) then {
											_aVeh setPos _aPos;   //--- pin the overwatch spot (helper placement radius is 7m).
											_ad1 = [_soldierClass, _grp, _aPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
											if (!isNull _ad1) then {_ad1 moveInDriver _aVeh; _ad1 setVariable ["WFBE_IsTownDefenderAI", true, true]};
											_ad2 = [_soldierClass, _grp, _aPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
											if (!isNull _ad2) then {_ad2 moveInGunner _aVeh; _ad2 setVariable ["WFBE_IsTownDefenderAI", true, true]};
											_statics set [count _statics, _aVeh];
											_armN = _armN + 1;
										};
									};
								};

								//--- (5) GARRISON: posted at composition guard positions (fixed offsets rotated by _dir),
								//--- not random scatter. doStop holds each man on his post; COMBAT/RED (below) keeps him
								//--- fighting, so nobody reads as a frozen AI. Tier bump: +0.05*_tier on "general" skill.
								_gpOffs = [[-5,2,0],[5,0,0],[-2,-3,0],[2,6,0],[-7,-1,0],[7,3,0],[0,-5,0],[-4,7,0],[4,-4,0],[0,10,0]];
								_footN = _cp2FootBase + (_cp2FootPer * _tier);
								for "_n" from 1 to _footN do {
									_gOff = _gpOffs select ((_n - 1) mod (count _gpOffs));
									_gPos = [(_spawnPos select 0) + (_gOff select 0) * (cos _dir) + (_gOff select 1) * (sin _dir),
									         (_spawnPos select 1) - (_gOff select 0) * (sin _dir) + (_gOff select 1) * (cos _dir),
									         0];
									_u = [_soldierClass, _grp, _gPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _u) then {
										_u setVariable ["WFBE_IsTownDefenderAI", true, true];
										if (_tier > 0) then {_u setSkill ["general", ((skill _u) + (0.05 * _tier)) min 1]};
										_u setPos _gPos;
										doStop _u;
									};
								};
								_grp setBehaviour "COMBAT"; _grp setCombatMode "RED";

								//--- Global map marker (enemy-visible ON PURPOSE - a contested objective, exactly as v1).
								_mk = Format ["guer_cp_%1_%2", round time, round (random 99999)];
								createMarker [_mk, _spawnPos];
								_mk setMarkerType "mil_warning";
								_mk setMarkerColor "ColorGreen";
								_mk setMarkerText Format ["Insurgent Checkpoint (%1)", _cpLabel];

								//--- Snapshot the occupier we tax + reward (town owner at spawn).
								_occSide = west;
								if ((_target getVariable ["sideID","?"]) == _eastID) then {_occSide = east};

								//--- Always-on grep-smoke line (house pipe pattern; str-concat is the proven RPT-safe idiom).
								diag_log ("GUERCP|v2|spawn|" + _cpLabel + "|" + (str (round _roadDist)) + "m|armor=" + (str _armN));

								//--- WATCHER v2: v1 tax/resolution logic + (6) one-shot reinforcement pulse at half-window
								//--- + (7) 900-base clear reward (v1: 700) and full composition/static teardown on BOTH paths.
								[_grp, _veh, _target, _occSide, _mk, _tier, _cpLabel, _cpObjs, _statics, _spawnPos, _soldierClass, _sideID] spawn {
									private ["_g","_v","_town","_occ","_marker","_t","_label","_objs","_stats","_sp","_cls2","_sID2",
									         "_el","_window","_cleared","_taxAmt","_toll","_clear","_fobIdx","_fobAvail","_fobName",
									         "_reinforced","_rn","_ri","_rPos2","_ru","_s","_x"];
									_g = _this select 0; _v = _this select 1; _town = _this select 2; _occ = _this select 3;
									_marker = _this select 4; _t = _this select 5; _label = _this select 6;
									_objs = _this select 7; _stats = _this select 8; _sp = _this select 9;
									_cls2 = _this select 10; _sID2 = _this select 11;

									_window  = missionNamespace getVariable ["WFBE_C_GUER_CP_WINDOW", 600];
									_taxAmt  = (missionNamespace getVariable ["WFBE_C_GUER_CP_TAX",  60])  * (1 + _t);
									_toll    = (missionNamespace getVariable ["WFBE_C_GUER_CP_TOLL", 250])  * (1 + _t);
									_clear   = 900 * (1 + _t);   //--- v2: the fortified block is worth more to crack (v1 base: 700).

									_el = 0; _cleared = false; _reinforced = false;
									while {!_cleared && {_el < _window} && {!gameOver}} do {
										sleep 30; _el = _el + 30;
										//--- CLEAR check: the manning force (crew + statics gunners + foot, all in _g) is wiped.
										if (({alive _x} count (units _g)) == 0) then {_cleared = true};
										if (!_cleared) then {
											//--- TAX tick: drain the occupier supply, pay GUER players a toll (unchanged from v1).
											[_occ, -_taxAmt, "Insurgent checkpoint tax.", false] Call ChangeSideSupply;
											[resistance, "GuerVbiedBounty", _toll] Call WFBE_CO_FNC_SendToClients;
											//--- (6) REINFORCEMENT PULSE: once, at half-window, while the block still stands.
											if (!_reinforced && {_el >= (_window / 2)}) then {
												_reinforced = true;
												_rn = 2 + _t;
												for "_ri" from 1 to _rn do {
													_rPos2 = [(_sp select 0) + (random 12) - 6, (_sp select 1) + (random 12) - 6, 0];
													_ru = [_cls2, _g, _rPos2, _sID2] Call WFBE_CO_FNC_CreateUnit;
													if (!isNull _ru) then {_ru setVariable ["WFBE_IsTownDefenderAI", true, true]};
												};
												diag_log Format ["AICOMSTAT|v2|EVENT|GUER|%1|GUERCP_REINFORCED|%2", round (time/60), _label];
											};
										};
									};

									if (_cleared) then {
										//--- WINNER = the occupier whose supply road it threatened (same as v1, bigger base).
										[_occ, _clear, "Insurgent checkpoint cleared - supply recovered.", false] Call ChangeSideSupply;
										[nil, "LocalizeMessage", ["Wildcard", Format ["[Wildcard] %1 cleared the Insurgent Checkpoint near %2 (+supply).", str _occ, _town getVariable ["name","?"]]]] Call WFBE_CO_FNC_SendToClients;
										diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time/60)) + "|GUERCP_CLEARED|" + (str _label) + "|byOcc=" + (str _occ) + "|clearSupply=" + (str _clear));
									} else {
										//--- GUER HELD it to timeout: FOB factory token, tier-scaled (identical to v1).
										_fobIdx = 0;
										if (_t >= 2) then {_fobIdx = 1};
										if (_t >= 3) then {_fobIdx = 2};
										_fobName  = ["Barracks","Light Factory","Heavy Factory"] select _fobIdx;
										_fobAvail = + (missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]]);
										_fobAvail set [_fobIdx, (_fobAvail select _fobIdx) + 1];
										missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _fobAvail];
										publicVariable "WFBE_GUER_FOB_AVAIL";
										[nil, "LocalizeMessage", ["Wildcard", Format ["[Wildcard] The Insurgent Checkpoint near %1 held - captured materiel: %2 FOB unlocked.", _town getVariable ["name","?"], _fobName]]] Call WFBE_CO_FNC_SendToClients;
										diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time/60)) + "|GUERCP_HELD|" + (str _label) + "|fobToken=" + (str _fobName) + "|avail=" + (str _fobAvail));
									};

									//--- (7) CLEANUP (runs after BOTH resolution paths): composition props, then statics
									//--- (player-safe, Server_GuerAirDef.sqf teardown idiom), then hull+crew, foot, group, marker.
									{if (!isNull _x) then {deleteVehicle _x}} forEach _objs;
									{
										_s = _x;   //--- capture outer _x before the inner crew forEach (house rule).
										if (!isNull _s && {({isPlayer _x} count (crew _s)) == 0}) then {
											{deleteVehicle _x} forEach (crew _s);
											deleteVehicle _s;
										};
									} forEach _stats;
									if (!isNull _v && {({isPlayer _x} count (crew _v)) == 0}) then {{deleteVehicle _x} forEach (crew _v); deleteVehicle _v};
									if (!isNull _g) then {{if (!(isPlayer _x)) then {deleteVehicle _x}} forEach (units _g); deleteGroup _g};
									deleteMarker _marker;
								};

								_detail = Format ["G2v2 target=%1 tier=%2 veh=%3 foot=%4 roadD=%5m window=%6s", _target getVariable ["name","?"], _tier, _cpVeh, _footN, round _roadDist, missionNamespace getVariable ["WFBE_C_GUER_CP_WINDOW", 600]];
							} else { _result = "partial"; _detail = "G2v2 group null at cap"; };
						} else { _result = "ineligible"; _detail = "G2v2 no road candidate"; };
					} else { _result = "ineligible"; _detail = "G2v2 no occupied town"; };
				} else {
				//--- v1 (legacy) G2 block below - UNTOUCHED bytes; the ONLY path while WFBE_C_GUER_CP_V2 = 0.
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
								diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time/60)) + "|GUERCP_CLEARED|" + (str _label) + "|byOcc=" + (str _occ) + "|clearSupply=" + (str _clear)); //--- same format->concatenation fix as GUERCP_HELD.
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
								diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time/60)) + "|GUERCP_HELD|" + (str _label) + "|fobToken=" + (str _fobName) + "|avail=" + (str _fobAvail)); //--- fix (Ray boot-smoke 2026-06-27): was diag_log format[...] which threw "Error in expression" at runtime; the + concatenation (str-safe) is the proven AICOM2 pattern.
							};

							//--- CLEANUP: husk + crew + foot + group + marker.
							if (!isNull _v) then {{deleteVehicle _x} forEach (crew _v); deleteVehicle _v};
							{deleteVehicle _x} forEach (units _g);
							if (!isNull _g) then {deleteGroup _g};
							deleteMarker _marker;
						};

						_detail = Format ["target=%1 tier=%2 veh=%3 foot=%4 window=%5s", _target getVariable ["name","?"], _tier, _cpVeh, _footN, missionNamespace getVariable ["WFBE_C_GUER_CP_WINDOW", 600]];
					} else { _result = "partial"; _detail = "G2 group null at cap"; };
				} else { _result = "ineligible"; _detail = "G2 no occupied town"; };
				}; //--- end v1 (legacy) G2 else-branch (flag WFBE_C_GUER_CP_V2 = 0 path).
			};

			//--- G5: SCAVENGER TEAM — 4-man foot team moves to abandoned wrecks, scraps them, pays GUER players.
			case 5: {
				if (count _owned > 0) then {
					//--- Re-scan abandoned vehicles (state may have changed since eligibility check).
					_abandVehs = [];
					{ if (!isNull _x && {alive _x} && {_x getVariable ["wfbe_aicom_abandoned", false]}) then {_abandVehs = _abandVehs + [_x]} } forEach allMissionObjects "LandVehicle";
					{ if (!isNull _x && {alive _x} && {_x getVariable ["wfbe_aicom_abandoned", false]}) then {if (!(_x in _abandVehs)) then {_abandVehs = _abandVehs + [_x]}} } forEach allDead;

					if (count _abandVehs >= 2) then {
						_scavReward = missionNamespace getVariable ["WFBE_C_GUER_SCAV_REWARD", 300];
						_scavBonus  = missionNamespace getVariable ["WFBE_C_GUER_SCAV_PLAYER_BONUS", 150];
						_scavTTL    = missionNamespace getVariable ["WFBE_C_GUER_SCAV_TTL", 300];

						//--- Spawn anchor: GUER-owned town nearest the wreck cluster.
						_nearWreck = _abandVehs select 0;
						_scavDist  = 1e9;
						{ _dd = _target distance _x; if (_dd < _scavDist) then {_scavDist = _dd; _nearWreck = _x} } forEach _abandVehs;

						_spawnPos = getPos (_owned select floor (random count _owned));

						_scavGrp = [resistance, "guer-wc-scav"] Call WFBE_CO_FNC_CreateGroup;
						if (!isNull _scavGrp) then {
							for "_n" from 1 to 4 do {
								_scavPos = [(_spawnPos select 0) + (random 20) - 10,
								            (_spawnPos select 1) + (random 20) - 10, 0];
								_scavMember = [_soldierClass, _scavGrp, _scavPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
								if (!isNull _scavMember) then {
									_scavMember setVariable ["WFBE_IsTownDefenderAI", true, true];
								};
							};
							_scavGrp setBehaviour "CARELESS"; _scavGrp setCombatMode "BLUE";

							_detail = Format ["spawnTown=%1 wrecks=%2 nearWreck=%3 ttl=%4s",
							                  (_owned select 0) getVariable ["name","?"], count _abandVehs, typeOf _nearWreck, _scavTTL];

							//--- WATCHER: iterate wrecks, scav each, pay reward, delete; TTL or wipe -> cleanup.
							[_scavGrp, _abandVehs, _spawnPos, _scavReward, _scavBonus, _scavTTL, _sideID] spawn {
								private ["_sg","_vehs","_base","_rew","_bonus","_ttl","_sID",
								         "_el","_alive","_v","_nearD","_bestV","_dd","_ldr"];
								_sg    = _this select 0; _vehs  = _this select 1; _base  = _this select 2;
								_rew   = _this select 3; _bonus = _this select 4; _ttl   = _this select 5;
								_sID   = _this select 6;
								_el    = 0; _alive = true;

								//--- Iterate wrecks while team lives and TTL not expired.
								while {_alive && {_el < _ttl} && {!gameOver} && {count _vehs > 0}} do {
									//--- Find nearest surviving wreck.
									_ldr    = leader _sg;
									_bestV  = objNull; _nearD = 1e9;
									{
										if (!isNull _x && {alive _x} && {_x getVariable ["wfbe_aicom_abandoned", false]}) then {
											_dd = if (!isNull _ldr && {alive _ldr}) then {_ldr distance _x} else {_nearD};
											if (_dd < _nearD) then {_nearD = _dd; _bestV = _x};
										};
									} forEach _vehs;

									if (isNull _bestV) exitWith {};   //--- no wrecks left.

									//--- Move to wreck.
									{if (alive _x) then {_x doMove (getPos _bestV)}} forEach (units _sg);
									waitUntil {
										sleep 5; _el = _el + 5;
										if (({alive _x} count (units _sg)) == 0) then {_alive = false};
										(!_alive || {_el >= _ttl} || {(!isNull _ldr && {alive _ldr} && {(_ldr distance _bestV) < 15})} || gameOver)
									};
									if (!_alive || {_el >= _ttl}) exitWith {};

									//--- 30s scavenge delay.
									sleep 30; _el = _el + 30;
									if (({alive _x} count (units _sg)) == 0) then {_alive = false; _el = _ttl};

									if (_alive && {_el < _ttl}) then {
										//--- Reward + delete wreck.
										[resistance, "GuerVbiedBounty", _rew] Call WFBE_CO_FNC_SendToClients;
										if (!isNull _bestV) then {deleteVehicle _bestV};
										_vehs = _vehs - [_bestV];
										diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time/60)) + "|GUERSCAV_WRECK|reward=" + str _rew + "|type=" + typeOf _bestV + "|remaining=" + str (count _vehs));
									};
								};

								//--- Cleanup: units -> group.
								{deleteVehicle _x} forEach (units _sg);
								if (!isNull _sg) then {deleteGroup _sg};
								diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time/60)) + "|GUERSCAV_DESPAWN|el=" + str _el + "|ttl=" + str _ttl);
							};
						} else {
							_result = "partial"; _detail = "G5 scav group null at cap";
						};
					} else {
						_result = "ineligible"; _detail = "G5 re-scan found <2 abandoned wrecks";
					};
				} else {
					_result = "ineligible"; _detail = "G5 no GUER-owned town for spawn anchor";
				};
			};
		};

		//--- Logging (mirror the conventional worker's AICOMSTAT line).
		["INFORMATION", Format ["AI_Commander_Wildcard_GUER.sqf: [GUER-WILDCARD] draw=G%1 result=%2 detail=(%3)", _draw, _result, _detail]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time / 60)) + "|GUERWILDCARD_G" + str _draw + "|" + _result + "|" + _detail);

		//--- Announcement: broadcast the insurgent strike to ALL clients (telegraph). The checkpoint also posts its
		//--- own resolution line from the watcher above; this is the initial "it appeared" beat.
		_wMap = [
			[1,"Car Bomb","a suicide car bomb rolls on an occupied town - destroy it for a bounty"],
			[2,"Pop-up Checkpoint","a roadblock chokes an occupied supply road - clear it for supply, or it bleeds you"],
			[5,"Scavenger Team","insurgent scavengers are stripping abandoned wrecks off the battlefield"]
		];
		_wName = Format ["G%1", _draw]; _wDesc = "";
		{if ((_x select 0) == _draw) exitWith {_wName = _x select 1; _wDesc = _x select 2}} forEach _wMap;
		_locMsg = Format ["[Wildcard] Insurgents (GUER) struck: %1 - %2.", _wName, _wDesc];
		[nil, "LocalizeMessage", ["Wildcard", _locMsg]] Call WFBE_CO_FNC_SendToClients;

	}; //--- end isolation spawn

	sleep _interval;
};
