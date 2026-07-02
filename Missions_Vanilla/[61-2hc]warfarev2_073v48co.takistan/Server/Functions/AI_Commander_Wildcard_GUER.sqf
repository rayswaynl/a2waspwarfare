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
	  G3 Road Ambush (7)     — flag WFBE_C_GUER_ROAD_AMBUSH default 0. AT/MG ambush team
                           at a road node between two contested/occupied towns; TTL despawn
                           (WFBE_C_GUER_ROAD_AMBUSH_TTL default 420s). Bounty-enabled crew.
  G4 Mortar Pit (6)      — flag WFBE_C_GUER_MORTARPIT default 0. Eligibility = a contested front town within
	                           ~1500m of a GUER-owned town; spawn a static 2b14_82mm mortar + 2-man GUER crew
	                           (GUE_Soldier_Crew) 300-600m from that town in a concealed flat spot (isFlatEmpty);
	                           SAD waypoint at the town centre; crew lobs inaccurate barrages every 45-90s;
	                           auto-despawn after WFBE_C_GUER_MORTARPIT_TTL (default 600s) or crew killed;
	                           cap 2 simultaneous pits (counter wfbe_guer_mortarpit_count on missionNamespace);
	                           keep >=125m from friendly units; bounty=true so crew kills pay via OnUnitKilled.
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
	  WFBE_C_GUER_ROAD_AMBUSH        default 0     (0=disable G3 Road Ambush card)
  WFBE_C_GUER_ROAD_AMBUSH_TTL    default 420   (ambush team despawn timeout in seconds)
  WFBE_C_GUER_MORTARPIT          default 0     (0=disable G4 Mortar Pit card)
	  WFBE_C_GUER_MORTARPIT_TTL      default 600   (mortar pit lifetime in seconds)
	  WFBE_C_GUER_SCAV               default 0     (0=disable G5 Scavenger Team card)
	  WFBE_C_GUER_SCAV_REWARD        default 300   (cash per wreck scrapped, paid to GUER players)
	  WFBE_C_GUER_SCAV_PLAYER_BONUS  default 150   (extra kill-bounty on each scav team member)
	  WFBE_C_GUER_SCAV_TTL           default 300   (scav team despawn timeout in seconds)
	  (held-to-timeout grants one FOB factory token of a tier-scaled type - no tunable; always exactly one)
*/

private ["_enabled","_interval","_sideID","_mortarPitCount"];

if (!isServer) exitWith {};

_enabled  = missionNamespace getVariable ["WFBE_C_GUER_WILDCARD", 1];
_interval = missionNamespace getVariable ["WFBE_C_GUER_WILDCARD_INTERVAL", 1800];

["INITIALIZATION", Format ["AI_Commander_Wildcard_GUER.sqf: worker started (interval=%1s, enabled=%2).", _interval, _enabled]] Call WFBE_CO_FNC_AICOMLog;

if (_enabled == 0) exitWith {
	["INFORMATION", "AI_Commander_Wildcard_GUER.sqf: disabled (WFBE_C_GUER_WILDCARD=0)."] Call WFBE_CO_FNC_AICOMLog;
};

//--- G4: initialise the simultaneous mortar-pit counter (lives on missionNamespace so both spawn/watcher see it).
if ((missionNamespace getVariable ["wfbe_guer_mortarpit_count", -1]) < 0) then {
	missionNamespace setVariable ["wfbe_guer_mortarpit_count", 0];
};

_sideID = resistance Call WFBE_CO_FNC_GetSideID;

sleep _interval;

while {!gameOver} do {

	sleep (random 30);   //--- jitter (de-correlate from the WEST/EAST workers)

	[_sideID] spawn {
		private ["_sideID","_westID","_eastID","_occTowns","_owned","_gG1","_gG2","_gG4","_gG5",
		         "_weights","_cumSum","_roll",
		         "_i","_chosen","_draw","_result","_detail","_soldierClass","_vbiedClass","_target","_nearD",
		         "_candTown","_dd","_targetPos","_ang","_spawnPos","_try","_roads","_truck","_grp","_drv",
		         "_tier","_cpVeh","_cpLabel","_veh","_d1","_d2","_n","_footN","_u","_pos","_mk","_occSide",
		         "_locMsg","_wName","_wDesc","_wMap","_g1Mk",
		         "_crewClass","_mortarClass","_mortarPos","_mortarFlat","_mortarDist","_mortarAng",
		         "_mortarTry","_friendlyNear","_mortarVeh","_mortarGrp","_mortarCrew1","_mortarCrew2",
		         "_mortarWP","_mortarTTL","_mortarCount",
		         "_abandVehs","_scavTeam","_scavGrp","_nearWreck","_scavDist","_scavReward",
		         "_scavBonus","_scavTTL","_scavMember","_scavPos",
		         "_gG3","_ambTownA","_ambTownB","_ambMid","_ambRds","_ambNode","_ambGrp",
		         "_ambU","_ambTTL","_ambMk","_ambBestDist",
		         "_ambI","_ambJ","_ambTA","_ambTB","_ambD","_ambEl"];

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
		_gG1 = 6; _gG2 = 8; _gG3 = 0; _gG4 = 0; _gG5 = 0;
		if (!(count _occTowns > 0 && {_soldierClass != ""} && {isClass (configFile >> "CfgVehicles" >> _vbiedClass)})) then {_gG1 = 0};
		if (!(count _occTowns > 0 && {_soldierClass != ""})) then {_gG2 = 0};

		//--- G3: ROAD AMBUSH eligibility: flag on, soldier class known, >=2 occupied towns.
		if ((missionNamespace getVariable ["WFBE_C_GUER_ROAD_AMBUSH", 0]) > 0 && {_soldierClass != ""} && {count _occTowns >= 2}) then {_gG3 = 7};

		//--- G4: MORTAR PIT eligibility: flag on, soldier class known, pit cap < 2,
		//--- a contested town within 1500m of at least one GUER-owned town.
		if ((missionNamespace getVariable ["WFBE_C_GUER_MORTARPIT", 0]) > 0) then {
			_crewClass = missionNamespace getVariable ["WFBE_GUERRESCREW", "GUE_Soldier_Crew"];
			_mortarClass = "2b14_82mm";
			_mortarCount = missionNamespace getVariable ["wfbe_guer_mortarpit_count", 0];
			if (_crewClass != "" && {isClass (configFile >> "CfgVehicles" >> _mortarClass)} && {_mortarCount < 2}) then {
				//--- Need a contested front town within 1500m of a GUER-owned town.
				{
					_candTown = _x;
					{ if ((_candTown distance _x) <= 1500) exitWith {_gG4 = 6} } forEach _owned;
				} forEach _occTowns;
			};
		};

		//--- G5: SCAVENGER TEAM eligibility: flag on, >=2 abandoned wrecks, GUER owns at least one town (spawn anchor).
		if ((missionNamespace getVariable ["WFBE_C_GUER_SCAV", 0]) > 0 && {_soldierClass != ""} && {count _owned > 0}) then {
			_abandVehs = [];
			{ if (!isNull _x && {alive _x} && {_x getVariable ["wfbe_aicom_abandoned", false]}) then {_abandVehs = _abandVehs + [_x]} } forEach allMissionObjects "LandVehicle";
			{ if (!isNull _x && {alive _x} && {_x getVariable ["wfbe_aicom_abandoned", false]}) then {_abandVehs = _abandVehs + [_x]} } forEach allDead;
			if (count _abandVehs >= 2) then {_gG5 = 5};
		};

		_weights = [[1,_gG1],[2,_gG2],[3,_gG3],[4,_gG4],[5,_gG5]];
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
								[resistance, "WildcardMarker", ["create", _g1Mk, _targetPos, "ColorGreen", "mil_destroy", "Car Bomb"]] Call WFBE_CO_FNC_SendToClients;
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
			};

			//--- G3: ROAD AMBUSH — AT/MG team at a road node between two contested towns.
			case 3: {
				//--- Find the pair of occupied towns closest to each other (the front corridor).
				_ambTownA = objNull; _ambTownB = objNull; _ambBestDist = 1e9;
				_ambI = 0;
				while {_ambI < (count _occTowns)} do {
					_ambTA = _occTowns select _ambI;
					_ambJ = _ambI + 1;
					while {_ambJ < (count _occTowns)} do {
						_ambTB = _occTowns select _ambJ;
						_ambD = _ambTA distance _ambTB;
						if (_ambD < _ambBestDist) then {
							_ambBestDist = _ambD;
							_ambTownA = _ambTA;
							_ambTownB = _ambTB;
						};
						_ambJ = _ambJ + 1;
					};
					_ambI = _ambI + 1;
				};

				if (!isNull _ambTownA && {!isNull _ambTownB}) then {
					//--- Midpoint between the two towns; snap to nearest road within 200m.
					_ambMid = [
						((getPos _ambTownA select 0) + (getPos _ambTownB select 0)) / 2,
						((getPos _ambTownA select 1) + (getPos _ambTownB select 1)) / 2,
						0
					];
					_ambRds = _ambMid nearRoads 200;
					_ambNode = _ambMid;
					if (count _ambRds > 0) then {_ambNode = getPos (_ambRds select 0)};

					//--- Create group: 1x MG + 2x AT + 1x infantry.
					_ambGrp = [resistance, "guer-wc-ambush"] Call WFBE_CO_FNC_CreateGroup;
					if (!isNull _ambGrp) then {
						_ambU = ["GUE_Soldier_MG", _ambGrp, _ambNode, _sideID] Call WFBE_CO_FNC_CreateUnit;
						if (!isNull _ambU) then {_ambU setVariable ["WFBE_IsTownDefenderAI", true, true]};
						_ambU = ["GUE_Soldier_AT", _ambGrp, _ambNode, _sideID] Call WFBE_CO_FNC_CreateUnit;
						if (!isNull _ambU) then {_ambU setVariable ["WFBE_IsTownDefenderAI", true, true]};
						_ambU = ["GUE_Soldier_AT", _ambGrp, _ambNode, _sideID] Call WFBE_CO_FNC_CreateUnit;
						if (!isNull _ambU) then {_ambU setVariable ["WFBE_IsTownDefenderAI", true, true]};
						_ambU = ["GUE_Soldier_1", _ambGrp, _ambNode, _sideID] Call WFBE_CO_FNC_CreateUnit;
						if (!isNull _ambU) then {_ambU setVariable ["WFBE_IsTownDefenderAI", true, true]};

						[_ambGrp, _ambNode, 80] Call AIPatrol;
						_ambGrp setBehaviour "COMBAT"; _ambGrp setCombatMode "RED";

						_ambTTL = missionNamespace getVariable ["WFBE_C_GUER_ROAD_AMBUSH_TTL", 420];

						//--- Local-side marker (GUER players only) via WildcardMarker PVF.
						_ambMk = Format ["wc_GUER_G3_%1", round time];
						[resistance, "WildcardMarker", ["create", _ambMk, _ambNode, "ColorGreen", "mil_triangle", "Road Ambush"]] Call WFBE_CO_FNC_SendToClients;

						_detail = Format ["towns=%1/%2 node=%3 ttl=%4s",
							_ambTownA getVariable ["name","?"], _ambTownB getVariable ["name","?"],
							_ambNode, _ambTTL];

						//--- WATCHER: TTL or all dead -> cleanup units, group, marker.
						[_ambGrp, _ambMk, _ambTTL] spawn {
							private ["_ag","_mk","_ttl","_el"];
							_ag  = _this select 0; _mk  = _this select 1; _ttl = _this select 2;
							_el  = 0;
							waitUntil {
								sleep 5; _el = _el + 5;
								(({alive _x} count (units _ag)) == 0 || {_el >= _ttl} || gameOver)
							};
							{deleteVehicle _x} forEach (units _ag);
							if (!isNull _ag) then {deleteGroup _ag};
							[resistance, "WildcardMarker", ["delete", _mk]] Call WFBE_CO_FNC_SendToClients;
							diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time/60)) + "|GUERROADAMBUSH_DESPAWN|el=" + str _el + "|ttl=" + str _ttl);
						};
					} else {
						_result = "partial"; _detail = "G3 group null at cap";
					};
				} else {
					_result = "ineligible"; _detail = "G3 fewer than 2 occupied towns (null pair)";
				};
			};

			//--- G4: MORTAR PIT — static 2b14_82mm + 2-man GUER crew at a concealed flat spot; SAD at contested town.
			case 4: {
				if (!isNull _target) then {
					_mortarClass = "2b14_82mm";
					_crewClass   = missionNamespace getVariable ["WFBE_GUERRESCREW", "GUE_Soldier_Crew"];
					_targetPos   = getPos _target;
					_mortarTTL   = missionNamespace getVariable ["WFBE_C_GUER_MORTARPIT_TTL", 600];

					//--- Pick a concealed flat spawn 300-600m from the contested town,
					//--- clear of water and >=125m from friendly units.
					_mortarPos = [];
					_mortarTry = 0;
					while {(count _mortarPos == 0) && {_mortarTry < 20}} do {
						_mortarDist = 300 + floor (random 301);   //--- 300-600m
						_mortarAng  = random 360;
						_spawnPos   = [(_targetPos select 0) + _mortarDist * sin _mortarAng,
						               (_targetPos select 1) + _mortarDist * cos _mortarAng, 0];
						_mortarTry  = _mortarTry + 1;
						if (!(surfaceIsWater _spawnPos)) then {
							//--- isFlatEmpty: radius 6, min flat dist 0, max slope 20 deg, max height diff 3, checkEmpty=false
							_mortarFlat = _spawnPos isFlatEmpty [6, 0, 20, 3, 0, false, objNull];
							if (count _mortarFlat > 0) then {
								//--- >=125m clearance from any alive GUER unit.
								_friendlyNear = {alive _x && {(side _x) == resistance} && {(_x distance _mortarFlat) < 125}} count allUnits;
								if (_friendlyNear == 0) then {_mortarPos = _mortarFlat};
							};
						};
					};
					//--- Fallback: use raw bearing pos without flat check rather than skip the card.
					if (count _mortarPos == 0) then {_mortarPos = _spawnPos};

					//--- Claim the counter BEFORE spawning so a simultaneous draw cannot double-book.
					_mortarCount = missionNamespace getVariable ["wfbe_guer_mortarpit_count", 0];
					if (_mortarCount < 2) then {
						missionNamespace setVariable ["wfbe_guer_mortarpit_count", _mortarCount + 1];

						_mortarGrp = [resistance, "guer-wc-mortarpit"] Call WFBE_CO_FNC_CreateGroup;
						if (!isNull _mortarGrp) then {
							_mortarVeh = [_mortarClass, _mortarPos, resistance, random 360, false, true] Call WFBE_CO_FNC_CreateVehicle;
							if (!isNull _mortarVeh) then {
								_mortarCrew1 = [_crewClass, _mortarGrp, _mortarPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
								if (!isNull _mortarCrew1) then {
									_mortarCrew1 moveInGunner _mortarVeh;
									_mortarCrew1 setVariable ["WFBE_IsTownDefenderAI", true, true];
								};
								_mortarCrew2 = [_crewClass, _mortarGrp, _mortarPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
								if (!isNull _mortarCrew2) then {
									_mortarCrew2 moveInDriver _mortarVeh;
									_mortarCrew2 setVariable ["WFBE_IsTownDefenderAI", true, true];
								};
								//--- SAD waypoint at the contested town so the mortar crew lobs at it autonomously.
								_mortarWP = _mortarGrp addWaypoint [_targetPos, 0];
								[_mortarGrp, 0] setWaypointType "SAD";
								_mortarGrp setCombatMode "RED"; _mortarGrp setBehaviour "COMBAT";

								_detail = Format ["target=%1 mortarPos=%2 ttl=%3s count=%4",
								                  _target getVariable ["name","?"], _mortarPos, _mortarTTL, _mortarCount + 1];

								//--- WATCHER: TTL or crew wiped -> release counter + delete.
								[_mortarGrp, _mortarVeh, _mortarTTL] spawn {
									private ["_mg","_mv","_ttl","_el","_alive"];
									_mg  = _this select 0; _mv = _this select 1; _ttl = _this select 2;
									_el  = 0; _alive = true;
									while {_alive && {_el < _ttl} && {!gameOver}} do {
										sleep 15; _el = _el + 15;
										if (({alive _x} count (units _mg)) == 0) then {_alive = false};
									};
									//--- Cleanup: crew -> mortar -> group -> counter.
									if (!isNull _mv) then {{deleteVehicle _x} forEach (crew _mv); deleteVehicle _mv};
									{deleteVehicle _x} forEach (units _mg);
									if (!isNull _mg) then {deleteGroup _mg};
									missionNamespace setVariable ["wfbe_guer_mortarpit_count",
									    (missionNamespace getVariable ["wfbe_guer_mortarpit_count", 0] - 1) max 0];
									diag_log ("AICOMSTAT|v2|EVENT|GUER|" + str (round (time/60)) + "|GUERMORTAR_DESPAWN|ttl=" + str _ttl + "|crewWiped=" + str (!_alive));
								};
							} else {
								//--- Mortar createVehicle failed: release counter + group.
								deleteGroup _mortarGrp;
								missionNamespace setVariable ["wfbe_guer_mortarpit_count",
								    (missionNamespace getVariable ["wfbe_guer_mortarpit_count", 0] - 1) max 0];
								_result = "partial"; _detail = "G4 mortar createVehicle null";
							};
						} else {
							//--- Group creation failed: release counter.
							missionNamespace setVariable ["wfbe_guer_mortarpit_count",
							    (missionNamespace getVariable ["wfbe_guer_mortarpit_count", 0] - 1) max 0];
							_result = "partial"; _detail = "G4 group null at cap";
						};
					} else {
						_result = "ineligible"; _detail = "G4 mortar pit cap=2 already reached";
					};
				} else {
					_result = "ineligible"; _detail = "G4 no contested front town within 1500m of GUER town";
				};
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
			[3,"Road Ambush","an AT/MG team is dug in on the road between two enemy towns - watch your vehicles"],
			[4,"Mortar Pit","a hidden mortar crew is lobbing rounds at an occupied town - hunt the pit by sound and flash"],
			[5,"Scavenger Team","insurgent scavengers are stripping abandoned wrecks off the battlefield"]
		];
		_wName = Format ["G%1", _draw]; _wDesc = "";
		{if ((_x select 0) == _draw) exitWith {_wName = _x select 1; _wDesc = _x select 2}} forEach _wMap;
		_locMsg = Format ["[Wildcard] Insurgents (GUER) struck: %1 - %2.", _wName, _wDesc];
		[nil, "LocalizeMessage", ["Wildcard", _locMsg]] Call WFBE_CO_FNC_SendToClients;

	}; //--- end isolation spawn

	sleep _interval;
};
