/*
	Run one AI-commander combat team: create it and execute the brain's orders locally.
	feat/ai-commander V0.3. Runs on a HEADLESS CLIENT (delegate-aicom-team) or on the
	server as fallback - the whole team lifecycle stays on the creating machine so
	waypoints keep locality (the proven side-patrol pattern).

	 Parameters: [ sideID, template (unit class array), spawnPos ]

	The server brain communicates through ONE public group variable:
	  wfbe_aicom_order = [seq, mode, pos]   (mode: "towns-target" | "defense" | "rally")
	The driver applies an order once per seq bump: MOVE to pos, SAD on arrival
	(towns-target) or a tight defensive SAD at pos (defense). Team wipe releases
	the slot via aicom-team-ended.
	//--- cmdcon41-w2 "rally" = bounding withdrawal: the EXISTING transit lay drives a fast MOVE to pos
	//--- (returns fire + uses cover en route, never a stand-and-die SAD); at the arrival latch a rallying
	//--- team does NOT lay the assault SAD but re-tasks itself back to "towns" so it re-engages (never idles).
*/

Private ["_townOrderArr","_chkVeh","_sideID","_template","_pos","_side","_team","_retVal","_units","_vehicles","_ldr","_alive","_order","_seq","_lastSeq","_mode","_dest","_arrived",
         "_captureDone","_townObj","_townCamps","_campObj","_campRange",
         "_liveUnits","_dismounted","_veh","_u","_settleTimeout","_hasCargo",
         "_townCenter","_capRange","_footInf","_holdEnd","_resNear","_enemyNear","_townFlipped",
         "_unheldCamps","_campFirstEnd","_nearCamp","_campTgtPos",
         "_airVeh","_grndVehs","_footPax","_cargoSeats","_lifted","_walkers","_lzPos","_flat","_pilot","_crewVeh","_pax","_abVeh","_left","_dropPos","_cv","_dismountDest","_cn","_ud","_heliCost","_truckSeq",
         "_rmHasVeh","_rmRoute","_rmWPs","_usTier","_arrivalGate","_arrivalDist","_arrivalTraceAt",
         "_govLdr","_govNz","_govSteep","_govStrk","_govWantSlow","_govIsSlow","_skillSend","_foundType",
         "_capPasses","_capMaxPasses","_capReleased","_isPlaneTeam","_planeDir","_pressPos","_pressOn","_pressAct","_pressSyn","_pressPrev"];

_sideID = _this select 0;
_template = _this select 1;
_pos = _this select 2;
_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

//--- PLANE AIRFIELD-SPAWN (Ray 2026-07-01, PLANE-ONLY "free air at captured airfields", gate WFBE_C_AICOM_PLANE_AIRSTART default-ON):
//--- AI_Commander_Teams appends two trailing delegate args for a fixed-wing founding: slot 7 = is-plane-team flag (bool), slot 8 =
//--- the runway/airfield heading (deg, resolved server-side from the airfield logic getDir). Read both count-guarded so every OTHER
//--- delegate caller (W6/W19 server-local 3-arg, non-air foundings) is byte-identical. A2-OA-safe: typeName guards, no A3 commands.
_isPlaneTeam = false;
if (count _this > 7) then { private ["_ipt"]; _ipt = _this select 7; if (typeName _ipt == "BOOL") then {_isPlaneTeam = _ipt} };
_planeDir = -1;
if (count _this > 8) then { private ["_ipd"]; _ipd = _this select 8; if (typeName _ipd == "SCALAR") then {_planeDir = _ipd} };
//--- Belt-and-braces: if the flag is set but no valid heading arrived, self-resolve the runway heading HERE from the nearest
//--- airfield logic (getDir of the LocationLogicAirport), else fall back to 0 so a plane never air-starts on a nil heading.
//--- Only runs for a flagged plane team; ground/heli founding never touches this.
if (_isPlaneTeam && {(!(typeName _planeDir == "SCALAR")) || {_planeDir < 0}}) then {
	private ["_afLog"];
	_afLog = (_pos nearEntities [["LocationLogicAirport"], 2000]);
	if (count _afLog > 0) then {
		_planeDir = getDir (_afLog select 0);
	} else {
		_planeDir = 0;
	};
};

//--- SCATTER: ground/heli teams keep the proven GetRandomPosition[30,120] + GetEmptyPosition[40] scatter so hulls do not stack on the
//--- factory pad. A PLANE team SKIPS the scatter entirely and air-starts directly ABOVE the resolved airfield/runway threshold (server
//--- passed getPos of the captured airfield hangar/logic), which is the most reliable A2 fixed-wing start (ground-takeoff off a runway is
//--- finicky). The airborne "FLY" hulls are lifted + fanned in Common_CreateTeam so multiple planes never air-spawn stacked.
if (!_isPlaneTeam) then {
	_pos = [_pos, 30, 120] Call WFBE_CO_FNC_GetRandomPosition;
	_pos = [_pos, 40] Call WFBE_CO_FNC_GetEmptyPosition;
};

_team = [_side, "aicom"] Call WFBE_CO_FNC_CreateGroup;
//--- PLANE-ONLY 8th CreateTeam arg = the runway heading; CreateTeam air-starts each Plane hull ("FLY" + this heading). -1 (all other
//--- teams) leaves CreateTeam on its byte-identical grounded "FORM"/dir-0 path for helis + ground hulls.
_retVal = [_template, _pos, _side, true, _team, true, 90, (if (_isPlaneTeam) then {_planeDir} else {-1})] call WFBE_CO_FNC_CreateTeam;
_units = _retVal select 0;
_vehicles = _retVal select 1;
_team = _retVal select 2;

if (isNull _team || {((count _units) + (count _vehicles)) == 0}) exitWith {
	["WARNING", Format ["Common_RunCommanderTeam.sqf: [%1] team creation failed - releasing the slot.", _side]] Call WFBE_CO_FNC_AICOMLog;
	if (isServer) then {
		["aicom-team-ended", _sideID, grpNull] Call HandleSpecial;
	} else {
		["RequestSpecial", ["aicom-team-ended", _sideID, grpNull]] Call WFBE_CO_FNC_SendToServer;
	};
};

_team allowFleeing 0;

//--- W7 "Veteran Company" skill boost: optional 4th delegate arg (0/absent = default skill). Only the
//--- AICOM-Teams HC dispatch (delegate-aicom-team) sends it (0.85 when the veteran flag was set, else 0);
//--- the W6/W19 server-local 3-arg calls omit it, so guard on count. AI-only; _units are local on the
//--- founding HC/server. typeName guard (not A3 isEqualType) keeps this A2 OA safe. [needs live verification]
if (count _this > 3) then {
	_skillSend = _this select 3;
	if (typeName _skillSend == "SCALAR" && {_skillSend > 0}) then {
		{_x setSkill _skillSend} forEach _units;
	};
};
//--- STANCE (task #1): set an aggressive posture ONCE at founding so the team is "advance and
//--- engage" before any order. AWARE+RED+FULL = fast, will-engage transit (not banzai - AWARE
//--- still uses cover/returns fire sanely). Covers infantry-only + pure-armour teams whose props
//--- would otherwise stay engine-default. The on-objective SAD waypoints still flip to COMBAT/WEDGE.
_team setCombatMode "RED"; _team setBehaviour "AWARE"; _team setSpeedMode "FULL";
_team setVariable ["wfbe_aicom_hc", true, true];   //--- brain: do not Produce/waypoint this one directly.
//--- DISBAND-LOW-TIER STAMP (2026-06-28): HC-founded teams SKIP AssignTypes (which is where server-local teams get
//--- wfbe_teamtype), so without this the disband-low-tier worker can never classify them (and used to throw on the
//--- A2-unsafe 2-arg getVariable). AI_Commander_Teams ships the picked TEMPLATE INDEX _pick (same value AssignTypes
//--- stores at L241; readers resolve the 0-3 type from it) as a TRAILING delegate arg; here it lands at _this index 6 (the
//--- inner array's slot after _padClass, request string already stripped by HandleSpecial). Guard on count so the
//--- 4-arg Wildcard / 3-arg server-local calls are unaffected (mirrors the _skillSend count>3 guard above), and
//--- validate SCALAR (typeName, not A3 isEqualType) before stamping the GROUP object the disband worker iterates.
if (count _this > 6) then {
	_foundType = _this select 6;
	if (typeName _foundType == "SCALAR" && {_foundType >= 0}) then {_team setVariable ["wfbe_teamtype", _foundType, true]};
};
_team setVariable ["wfbe_queue", [], false];
_team setVariable ["wfbe_aicom_decap", [], true];   //--- stack-pass: A2 recycles group slots - a re-founded team must never inherit a stale press stamp ([] = cleared sentinel)
_team setVariable ["wfbe_aicom_press_on", nil];      //--- stack-pass: same for the HC-local press latch

if (isServer) then {
	["aicom-team-created", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-created", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};

["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] commander team spawned (%2 units, %3 vehicles).", _side, count _units, count _vehicles]] Call WFBE_CO_FNC_AICOMLog;

//--- ARROW-HEADING FEED (task #3, verify BLOCKER fix): the order-execution loop below
//--- sleeps 20s and, mid-capture, blocks on sleep 75 / sleep 25 - far too coarse and starved
//--- to drive a responsive direction arrow. So DO NOT push headings from inside that loop.
//--- Instead run this tiny self-contained loop on its own ~8s cadence. It reads the team's
//--- current objective bearing (leader -> order destination, slot 2 of wfbe_aicom_order) and
//--- ships ["aicom-team-heading",[team, dir]] to the server via the same SendToServer /
//--- RequestSpecial path the create/end messages use. The server re-broadcasts only when the
//--- arrow moved >7 deg. Exits when the team is null or wiped (mirrors the marker lifecycle).
[_team, _side] Spawn {
	Private ["_hTeam","_hSide","_hOrder","_hDest","_hLdr","_hDir","_hLastDir","_hDelta","_hSend"]; //--- cmdcon41-w3c +_hLastDir/_hDelta/_hSend
	_hTeam = _this select 0;
	_hSide = _this select 1;
	//--- cmdcon41-w3c (HC-LOAD): SENDER-SIDE heading dedup. Previously this loop shipped an
	//--- aicom-team-heading PV to the server EVERY 8s per team unconditionally; the server then
	//--- discarded it unless the arrow moved >7 deg (Server_HandleSpecial:568). With ~36 AICOM
	//--- teams/side that is a steady stream of HC->server PVs the server throws away. Cache the
	//--- last DIR we actually sent and skip the PV when the new bearing is within the SAME 7 deg
	//--- the server uses, so a team holding a bearing sends nothing. First send always fires
	//--- (sentinel _hLastDir=-999) and any real >7 deg turn still reports immediately -> the arrow
	//--- feed is behaviour-identical, just far quieter. A2-OA-safe: abs + 360 wrap for the angular
	//--- delta (no A3 ops), plain scalar cache in this spawn scope.
	_hLastDir = -999;
	while {!WFBE_GameOver && !isNull _hTeam && {(count ((units _hTeam) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
		_hLdr = leader _hTeam;
		if (!isNull _hLdr && {alive _hLdr}) then {
			//--- Default: face the way the leader is actually pointing.
			_hDir = getDir _hLdr;
			//--- Prefer the objective bearing: leader -> order destination pos (slot 2).
			//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
			_hOrder = _hTeam getVariable "wfbe_aicom_order";
			if (!isNil "_hOrder" && {count _hOrder >= 3}) then {
				_hDest = _hOrder select 2;
				if (!isNil "_hDest" && {(_hLdr distance _hDest) > 5}) then {
					_hDir = ((_hDest select 0) - ((getPosATL _hLdr) select 0)) atan2 ((_hDest select 1) - ((getPosATL _hLdr) select 1)); //--- A2-safe bearing leader->dest (binary getDir is A3-only).
				};
			};
			//--- cmdcon41-w3c: only send when the bearing moved beyond the server's own 7 deg gate.
			_hSend = false;
			if (_hLastDir < -900) then {
				_hSend = true; //--- first report: always send so the arrow appears.
			} else {
				_hDelta = abs (_hDir - _hLastDir);
				if (_hDelta > 180) then {_hDelta = 360 - _hDelta}; //--- wrap-around shortest angle (A2-safe).
				if (_hDelta > 7) then {_hSend = true};
			};
			if (_hSend) then {
				_hLastDir = _hDir;
				if (isServer) then {
					["aicom-team-heading", [_hTeam, _hDir]] Call HandleSpecial;
				} else {
					["RequestSpecial", ["aicom-team-heading", [_hTeam, _hDir]]] Call WFBE_CO_FNC_SendToServer;
				};
			};
		};
		sleep 8;
	};
};

//--- HC locality note: this file is spawned exclusively via delegate-aicom-team ->
//--- HandleSpecial.sqf on the Headless Client (AI_Commander_Teams.sqf line 171).
//--- The created group is local to the HC for its entire lifetime, so waypoints,
//--- doMove, assignAsCargo, and orderGetIn all execute with correct locality here.

//--- B60 HELI CANNON-NUDGE (Ray 2026-06-21, default-ON): A2-OA heli gunners self-pick guided ATGMs at
//--- standoff and ignore the cannon/rockets. For each alive non-transport attack heli in this team with a
//--- live gunner and a revealed enemy within cannon band, drop to a low gun-run altitude and one-shot force
//--- the gunner onto a NON-guided (cannon/gun) muzzle. HC-local, self-exits on team wipe; no disableAI, no
//--- sim-gating - the heli stays fully active and re-engages on proximity.
if ((missionNamespace getVariable ["WFBE_C_AICOM_HELI_CANNON_NUDGE", 1]) > 0) then {
	//--- B66: the nudge Spawn used to start for EVERY team (an endless ~7s sleep-loop per team, even
	//--- pure-infantry/armour teams with no aircraft). Gate it: only spawn the loop when this team
	//--- actually HAS a NON-transport attack helicopter in its vehicles. A2-OA-safe: classname-literal
	//--- isKindOf "Helicopter" + getNumber transportSoldier==0 (mirrors the per-tick test below).
	private ["_hasAttackHeli"]; //--- B66
	_hasAttackHeli = false;     //--- B66
	{ if (!isNull _x && {_x isKindOf "Helicopter"} && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "transportSoldier")) == 0}) exitWith {_hasAttackHeli = true} } forEach _vehicles; //--- B66
	if (_hasAttackHeli) then { //--- B66 only run the cannon-nudge loop for teams that own an attack heli
	[_team, _side, _vehicles] Spawn {
		private ["_tm","_sd","_vehs","_liveVehs","_h","_tgt","_cannon","_cannonMuzzle","_muzzles","_isGuided","_ammo","_band"]; //--- B66 +_cannonMuzzle/_muzzles; lane341 hostile filter uses getFriend
		_tm = _this select 0; _sd = _this select 1; _vehs = _this select 2;
		while {!WFBE_GameOver && !isNull _tm && {(count _vehs) > 0} && {(count ((units _tm) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
			_liveVehs = [];
			{ if (!isNull _x && {alive _x}) then {_liveVehs = _liveVehs + [_x]} } forEach _vehs;
			_vehs = _liveVehs;
			{
				_h = _x;
				if (!isNull _h && {alive _h} && {_h isKindOf "Helicopter"} && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _h) >> "transportSoldier")) == 0} && {!isNull (gunner _h)} && {alive (gunner _h)}) then {
					_cannon = "";
					{
						_isGuided = false;
						{ _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo"); if (_ammo != "" && {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "airLock")) == 1 || {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "maxControlRange")) > 0}}) then {_isGuided = true} } forEach (getArray (configFile >> "CfgWeapons" >> _x >> "magazines"));
						if (!_isGuided && {_cannon == ""}) then {_cannon = _x};
					} forEach (weapons _h);
					if (_cannon != "") then {
						_band = missionNamespace getVariable ["WFBE_C_AICOM_HELI_CANNON_RANGE", 700];
						_tgt = objNull;
						{ if (alive _x && {(_sd getFriend (side _x)) < 0.6} && {(_h distance _x) < _band}) exitWith {_tgt = _x} } forEach ((getPos _h) nearEntities [["Man","Car","Wheeled_APC","Tank"], _band]);
						if (!isNull _tgt) then {
							_h flyInHeight ((missionNamespace getVariable ["WFBE_C_AICOM_HELI_GUN_ALT", 35]) max (missionNamespace getVariable ["WFBE_C_AICOM_HELI_GUNFLOOR", 0]));
							//--- B66 MUZZLE FIX: in OA selectWeapon wants a MUZZLE, not a weapon classname; a
							//--- multi-muzzle cannon (e.g. M197/2A42 with HE+AP muzzles) is never switched if you
							//--- pass the weapon name. Resolve the weapon`s muzzles (CfgWeapons >> _cannon >> muzzles):
							//--- a single-muzzle weapon lists ["this"] -> the muzzle IS the weapon name; otherwise pick
							//--- the first real muzzle. A2-OA-safe: getArray + count/select 0 (no findIf/selectRandom).
							_cannonMuzzle = _cannon;
							_muzzles = getArray (configFile >> "CfgWeapons" >> _cannon >> "muzzles");
							if (count _muzzles > 0) then {
								_cannonMuzzle = _muzzles select 0;
								if ((toLower _cannonMuzzle) == "this") then {_cannonMuzzle = _cannon};
							};
							(gunner _h) selectWeapon _cannonMuzzle; //--- B66: muzzle, not weapon name
							(gunner _h) doTarget _tgt;
							(gunner _h) doFire _tgt;
						};
					};
				};
			} forEach _vehs;
			sleep (missionNamespace getVariable ["WFBE_C_AICOM_HELI_NUDGE_PERIOD", 7]);
			//--- B74.2 HELI BASE-REAP (Ray 2026-06-24): the server-side BASE-GC cannot reap these hulls (HC-local +
			//--- ownership-exempt at server_groupsGC.sqf:209), so do it HERE on the HC where the heli IS local. Any
			//--- alive attack heli that has sat crewed-idle (speed < idle band, no enemy near) at its OWN base for
			//--- WFBE_C_AICOM_HELI_BASE_REAP_TIMEOUT continuous seconds is deleted (crew first, then hull) so empties
			//--- stop piling. First-seen stamp resets the moment it moves/engages. 0 = off. A2-OA-safe: getPos guarded
			//--- by !isNull, nearEntities side-compare (no getFriend), deleteVehicle on HC-local crew+hull.
			//--- FLAW-FIX: use _vehs (the Spawn-local rebind of _vehicles at L134), NOT _vehicles (not inherited).
			private ["_reapTO"]; _reapTO = missionNamespace getVariable ["WFBE_C_AICOM_HELI_BASE_REAP_TIMEOUT", 0];
			if (_reapTO > 0) then {
				private ["_reapHQ","_reapVehs"];
				_reapHQ = (_sd) Call WFBE_CO_FNC_GetSideHQ;
				if (!isNull _reapHQ) then {
					_reapVehs = _vehs;
					{
						private ["_rh","_rEnemy","_rSeen"];
						_rh = _x;
						if (!isNull _rh && {alive _rh} && {local _rh} && {_rh isKindOf "Helicopter"} && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _rh) >> "transportSoldier")) == 0}) then {
							if (((_rh distance _reapHQ) <= (missionNamespace getVariable ["WFBE_C_BASEGC_RANGE", 800])) && {(abs (speed _rh)) < (missionNamespace getVariable ["WFBE_C_BASEGC_IDLE_SPEED", 5])}) then {
								_rEnemy = {alive _x && {(side _x) != _sd} && {(side _x) != civilian}} count ((getPos _rh) nearEntities [["Man","LandVehicle","Air"], 400]);
								if (_rEnemy > 0) then {
									_rh setVariable ["wfbe_heli_baseidle_at", nil];
								} else {
									_rSeen = _rh getVariable "wfbe_heli_baseidle_at";
									if (isNil "_rSeen") then {
										_rh setVariable ["wfbe_heli_baseidle_at", time];
									} else {
										if ((time - _rSeen) >= _reapTO) then {
											{ if (!isPlayer _x) then {deleteVehicle _x} } forEach (crew _rh);
											deleteVehicle _rh;
											["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] B74.2 base-reaped idle attack heli %2 (idle %3s at base).", _sd, typeOf _rh, _reapTO]] Call WFBE_CO_FNC_AICOMLog;
										};
									};
								};
							} else {
								_rh setVariable ["wfbe_heli_baseidle_at", nil];
							};
						};
					} forEach _reapVehs;
				};
			};
		};
	};
	}; //--- B66 end if (_hasAttackHeli)
};

//--- Order-execution loop: apply each new order seq from the server brain.
_lastSeq = -1;
_arrived = false;
_captureDone = false;     //--- guard: run dismount-capture phase only once per order
_alive = true;

//--- ===================================================================
//--- AIR-INSERTION (task #11) — OWN-HELI architecture. Runs ONCE before the
//--- order loop. Fires only for teams whose OWN template already spawned a
//--- troop-capable AIR transport (e.g. Build-29 UH60M/MV22/Mi17/CH-47F air
//--- squads). We use the team's OWN heli (already spawned, already piloted by
//--- Common_CreateTeam crew pass) — NO second transport is created. The team's
//--- FOOT infantry load into that heli (respect live emptyPositions 'cargo');
//--- overflow walks by ground. Teams with no air transport skip this entirely.
//---
//--- FROZEN-#1 GUARD: ground vehicles + their crews are NOT blocked on the air
//--- flag. They receive an immediate concurrent MOVE toward the objective here,
//--- and the order loop below re-tasks the WHOLE team (MOVE then SAD) regardless.
//--- No crewed hull ever sits un-ordered.
_airVeh   = objNull;
_grndVehs = [];
{
	if (!isNull _x && {alive _x}) then {
		//--- FROZEN-AIR FIX (Ray): NO "Air" hull ever enters _grndVehs (jets + pure gunships -
		//--- isKindOf "Air" but transportSoldier=0, e.g. A10/Su39/Su34/Ka52/AH64D - were getting
		//--- ground doMove/taxi orders instead of flying). Transport air (transportSoldier>0)
		//--- becomes the lift _airVeh; all other air is left out of BOTH lists and flies via the
		//--- team's normal MOVE/SAD order loop. Only true ground hulls go to _grndVehs.
		if (_x isKindOf "Air") then {
			if ((getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "transportSoldier")) > 0 && {isNull _airVeh}) then {
				_airVeh = _x;
			};
		} else {
			_grndVehs = _grndVehs + [_x];
		};
	};
} forEach _vehicles;

//--- ===================================================================
//--- cmdcon41-w3b (Ray wish): EASA-on-AI + richer AI squad gear, both HARD-BOUND to REAL researched upgrades.
//--- Runs ONCE here on the founding machine (the HC for delegate teams; server for the W6/W19 fallbacks), right
//--- after the _vehicles list is split into _airVeh/_grndVehs and BEFORE the air-insert block, so the hulls are
//--- freshly created + LOCAL and their weapon state replicates with the vehicle (JIP-safe). Self-contained: the
//--- kit table is an inline local (design says do NOT hoist into Init_CommonConstants this pass). A2-OA-safe:
//--- typeName guards (no isEqualType), no A3 commands, bounded single-pass forEach, no sleeps.
//--- ===================================================================

//--- (1) EASA-ON-AI (gate WFBE_C_AICOM_EASA_AI default 1): apply an EASA kit to each local alive AICOM air hull whose
//--- typeOf matches a row, but ONLY once the side has actually RESEARCHED EASA ((GetSideUpgrades select WFBE_UP_EASA) >= 1).
//--- Classnames copied VERBATIM from Client\Module\EASA\EASA_Init.sqf rows; the remove-stock/add-kit idiom mirrors the
//--- proven Server_GuerAirDef.sqf:295-311 swap. Rows: [class, stockW, stockM, kitW, kitM, turretBool]. Turret rows use the
//--- [-1] turret add/remove; hull rows use plain add/removeWeapon+Magazine. We do NOT set WFBE_EASA_Setup on AI hulls
//--- (a non-index value breaks Common_RearmVehicle player loadout indexing - design R3). Log one EASA_AI_KIT line per hull.
if ((missionNamespace getVariable ["WFBE_C_AICOM_EASA_AI", 1]) > 0) then {
	private ["_easaUpg","_easaHas"];
	_easaUpg = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
	//--- HARD research gate (Ray): kit ONLY when EASA is actually unlocked. count-guard the select so a short/empty
	//--- upgrade array (GUER zero-array / CIV []) degrades to "not unlocked" instead of erroring.
	_easaHas = (count _easaUpg > WFBE_UP_EASA) && {(_easaUpg select WFBE_UP_EASA) >= 1};
	if (_easaHas) then {
		private ["_easaKits"];
		//--- INLINE default-kit table. Jets verified present in EASA_Init rows: Su34 (L11), Su25_TK_EP1 (L133),
		//--- A10 (L377), AV8B2 (L481). Helis: AH64D_EP1 (L592), AH1Z (L610), Ka52 (L651), Ka52Black (L660),
		//--- Mi24_P (L640), Mi24_V (L631), AW159_Lynx_BAF (L620 TURRET). Each kitW/kitM copied EXACTLY from one
		//--- balanced AG/AA loadout row for that airframe; stockW/stockM copied EXACTLY from its _easaDefault row.
		_easaKits = [
			//--- HELIS ---
			//--- AH-64D (Hellfire): stock HellfireLauncher/8Rnd_Hellfire -> +Stinger AA pair (row L596).
			["AH64D_EP1", ["HellfireLauncher"], ["8Rnd_Hellfire"], ["HellfireLauncher","StingerLauncher_twice"], ["8Rnd_Hellfire","2Rnd_Stinger"], false],
			//--- AH-1Z: stock HellfireLauncher/8Rnd_Hellfire x2 -> AGM-114(8)+AIM-9L(2) (row L614).
			["AH1Z", ["HellfireLauncher"], ["8Rnd_Hellfire","8Rnd_Hellfire"], ["HellfireLauncher","SidewinderLaucher_AH1Z"], ["8Rnd_Hellfire","2Rnd_Sidewinder_AH1Z"], false],
			//--- Ka-52: stock AT9/AT-9 x3 -> Ataka-V(12)+Igla-V(2) (row L655).
			["Ka52", ["AT9Launcher"], ["4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P"], ["AT9Launcher","Igla_twice"], ["4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P","2Rnd_Igla"], false],
			//--- Ka-52 (Black): stock Vikhr/12Rnd -> R-73(2)+Vikhr(12) (row L664).
			["Ka52Black", ["VikhrLauncher"], ["12Rnd_Vikhr_KA50"], ["R73Launcher_2","VikhrLauncher"], ["2Rnd_R73","12Rnd_Vikhr_KA50"], false],
			//--- Mi-24P: stock AT9+HeliBomb -> Ataka-V(4)+Igla-V(2) (row L645).
			["Mi24_P", ["AT9Launcher","HeliBombLauncher"], ["4Rnd_AT9_Mi24P","2Rnd_FAB_250"], ["AT9Launcher","Igla_twice"], ["4Rnd_AT9_Mi24P","2Rnd_Igla"], false],
			//--- Mi-24V: stock AT9/4Rnd -> Ataka-V(4)+Igla-V(2) (row L635).
			["Mi24_V", ["AT9Launcher"], ["4Rnd_AT9_Mi24P"], ["AT9Launcher","Igla_twice"], ["4Rnd_AT9_Mi24P","2Rnd_Igla"], false],
			//--- Wildcat AH11 (TURRET path - manned turret, mirrors AW159 in EASA_Equip): stock -> Spike(2)+Stinger(2) (row L624).
			["AW159_Lynx_BAF", ["CRV7_HEPD","CTWS","SpikeLauncher_ACR"], ["6Rnd_CRV7_HEPD","200Rnd_40mmHE_FV510","200Rnd_40mmSABOT_FV510","2Rnd_Spike_ACR","2Rnd_Spike_ACR"], ["CRV7_HEPD","CTWS","SpikeLauncher_ACR","StingerLauncher_twice"], ["6Rnd_CRV7_HEPD","200Rnd_40mmHE_FV510","200Rnd_40mmSABOT_FV510","2Rnd_Spike_ACR","2Rnd_Stinger"], true],
			//--- JETS (one balanced AG/AA kit per side) ---
			//--- Su-34 [EAST]: stock Ch29+R73 -> FAB-250(6)+Kh-29(4)+R-73(2)+GBU-12(2) (row L15).
			["Su34", ["Ch29Launcher_Su34","R73Launcher_2"], ["6Rnd_Ch29","2Rnd_R73","2Rnd_R73"], ["AirBombLauncher","BombLauncherF35","Ch29Launcher_Su34","R73Launcher_2"], ["4Rnd_FAB_250","2Rnd_FAB_250","2Rnd_GBU12","4Rnd_Ch29","2Rnd_R73"], false],
			//--- Su-25T [EAST/TK]: stock AT9+R73+S8 -> Ataka-V(4)+FAB-250(6)+R-73(2)+S-8(40) (row L140).
			["Su25_TK_EP1", ["AT9Launcher","R73Launcher_2","S8Launcher"], ["4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P","2Rnd_R73","40Rnd_S8T"], ["AT9Launcher","AirBombLauncher","R73Launcher_2","S8Launcher"], ["4Rnd_AT9_Mi24P","4Rnd_FAB_250","2Rnd_FAB_250","2Rnd_R73","40Rnd_S8T"], false],
			//--- A-10 [WEST]: stock FFAR+Mk82 -> AGM-65(2)+Hydra(38)+Stinger... use AGM-65(2)+Stinger(2) balanced (row L383).
			["A10", ["FFARLauncher","Mk82BombLauncher_6"], ["38Rnd_FFAR","6Rnd_Mk82"], ["MaverickLauncher","StingerLauncher_twice"], ["2Rnd_Maverick_A10","2Rnd_Stinger"], false],
			//--- AV-8B II [WEST]: stock Maverick+Sidewinder -> AGM-114(8)+AGM-65(2)+AIM-9L(2) (row L485).
			["AV8B2", ["MaverickLauncher","SidewinderLaucher_AH1Z"], ["2Rnd_Maverick_A10","2Rnd_Maverick_A10","2Rnd_Maverick_A10","2Rnd_Sidewinder_AH1Z"], ["HellfireLauncher","MaverickLauncher","SidewinderLaucher_AH1Z"], ["8Rnd_Hellfire","2Rnd_Maverick_A10","2Rnd_Sidewinder_AH1Z"], false]
		];
		{
			private ["_kh"];
			_kh = _x;
			if (!isNull _kh && {alive _kh} && {local _kh} && {_kh isKindOf "Air"}) then {
				private ["_khType","_khRow","_khHit"];
				_khType = typeOf _kh;
				_khHit = false;
				{
					if (!_khHit && {(_x select 0) == _khType}) then {
						_khHit = true;
						_khRow = _x;
						private ["_stW","_stM","_kW","_kM","_kTur"];
						_stW  = _khRow select 1; _stM = _khRow select 2;
						_kW   = _khRow select 3; _kM  = _khRow select 4;
						_kTur = _khRow select 5;
						if (_kTur) then {
							//--- TURRET path (manned turret; [-1] = the vehicle's primary/main turret, exactly as Server_GuerAirDef).
							{_kh removeMagazineTurret [_x, [-1]]} forEach _stM;
							{_kh removeWeaponTurret  [_x, [-1]]} forEach _stW;
							{_kh addMagazineTurret [_x, [-1]]} forEach _kM;
							{_kh addWeaponTurret  [_x, [-1]]} forEach _kW;
						} else {
							//--- HULL path (jets + non-turret gunships fire from the hull).
							{_kh removeMagazine _x} forEach _stM;
							{_kh removeWeapon   _x} forEach _stW;
							{_kh addMagazine _x} forEach _kM;
							{_kh addWeapon   _x} forEach _kW;
						};
						diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|EASA_AI_KIT|type=" + _khType + "|turret=" + str _kTur);
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] EASA_AI_KIT applied to %2 (turret=%3, EASA researched).", _side, _khType, _kTur]] Call WFBE_CO_FNC_AICOMLog;
					};
				} forEach _easaKits;
			};
		} forEach _vehicles;
	};
};

//--- (2) RICH-GEAR (gate WFBE_C_AICOM_RICH_GEAR default 1): a TINY, ammo-safe post-create gear bump for the team's Man units,
//--- HARD-BOUND to the ACTUAL researched WFBE_UP_GEAR level. tier = (GetSideUpgrades select WFBE_UP_GEAR), +1 while the side
//--- logic's wfbe_aicom_econ_surge is true (still hard-capped at 5). Below WFBE_C_AICOM_RICH_GEAR_MIN_TIER (2) do nothing.
//--- Delta is intentionally minimal (design R5 - ammo compat is the main hazard, NO weapon swaps this pass): each Man gets +1
//--- magazine of its OWN current primary weapon's first config magazine type; tier>=4 gives +2 mags each PLUS the leader one
//--- extra AT round copied from an AT soldier's launcher magazine IF the team has one. A2-OA-safe: getArray on CfgWeapons
//--- magazines (same idiom this file uses at ~L186), typeName guards, bounded single-pass loops, no sleeps.
if ((missionNamespace getVariable ["WFBE_C_AICOM_RICH_GEAR", 1]) > 0) then {
	private ["_rgUpg","_rgTier","_rgMin"];
	_rgUpg = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
	//--- HARD research gate (Ray): tier is the ACTUAL researched gear level. count-guard the select so a short array degrades to 0.
	_rgTier = if (count _rgUpg > WFBE_UP_GEAR) then {_rgUpg select WFBE_UP_GEAR} else {0};
	//--- Econ-surge +1 (still capped at 5). The surge flag lives on the side logic OBJECT; read it via GetSideLogic + plain
	//--- object getVariable [name,default] (objects support the 2-arg form; only GROUPS do not). Degrades to false if unset.
	if (_rgTier > 0) then {
		private ["_rgLogik"];
		_rgLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _rgLogik && {_rgLogik getVariable ["wfbe_aicom_econ_surge", false]}) then {_rgTier = _rgTier + 1};
	};
	if (_rgTier > 5) then {_rgTier = 5};
	_rgMin = missionNamespace getVariable ["WFBE_C_AICOM_RICH_GEAR_MIN_TIER", 2];
	if (_rgTier >= _rgMin) then {
		private ["_rgExtra","_rgAtMag"];
		//--- tier>=4 -> +2 mags each; tier 2-3 -> +1 mag each.
		_rgExtra = if (_rgTier >= 4) then {2} else {1};
		_rgAtMag = ""; //--- resolved below (an AT soldier's launcher magazine), only used at tier>=4 for the leader.
		{
			private ["_ru"];
			_ru = _x;
			if (!isNull _ru && {alive _ru} && {local _ru}) then {
				private ["_rw","_rmags","_rmag"];
				//--- +N mags of the unit's OWN current primary weapon's FIRST config magazine type (safest possible compat).
				_rw = primaryWeapon _ru;
				if (!(_rw == "")) then {
					_rmags = getArray (configFile >> "CfgWeapons" >> _rw >> "magazines");
					if (count _rmags > 0) then {
						_rmag = _rmags select 0;
						for "_ri" from 1 to _rgExtra do {_ru addMagazine _rmag};
					};
				};
				//--- While scanning, note an AT soldier's launcher magazine (secondaryWeapon = launcher) for the tier>=4 leader bonus.
				if (_rgAtMag == "" && {_rgTier >= 4}) then {
					private ["_rsw","_rsmags"];
					_rsw = secondaryWeapon _ru;
					if (!(_rsw == "")) then {
						_rsmags = getArray (configFile >> "CfgWeapons" >> _rsw >> "magazines");
						if (count _rsmags > 0) then {_rgAtMag = _rsmags select 0};
					};
				};
			};
		} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
		//--- tier>=4: the LEADER gets ONE extra AT round of the team's own AT class (copied above), IF the team fields an AT soldier.
		if (_rgTier >= 4 && {!(_rgAtMag == "")}) then {
			private ["_rgLdr"];
			_rgLdr = leader _team;
			if (!isNull _rgLdr && {alive _rgLdr} && {local _rgLdr}) then {_rgLdr addMagazine _rgAtMag};
		};
		diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|RICH_GEAR|tier=" + str _rgTier + "|extraMags=" + str _rgExtra + "|atMag=" + _rgAtMag);
		["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] RICH_GEAR applied (tier %2, +%3 mag/unit, atMag=%4).", _side, _rgTier, _rgExtra, _rgAtMag]] Call WFBE_CO_FNC_AICOMLog;
	};
};
//--- ===================================================================

if (!isNull _airVeh && {alive _airVeh} && {!isNull (driver _airVeh)} && {alive (driver _airVeh)}) then {
	//--- Concurrent ground roll-out: never leave crewed hulls idle during the lift.
	{
		if (!isNull _x && {alive _x} && {!isNull (driver _x)}) then {(driver _x) doMove _pos};
	} forEach _grndVehs;

	//--- Load the team's FOOT infantry into the team's own heli (cargo seats only).
	_footPax = [];
	{
		if (alive _x && {vehicle _x == _x} && {_x != (driver _airVeh)}) then {_footPax = _footPax + [_x]};
	} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);

	_cargoSeats = _airVeh emptyPositions "cargo";
	_lifted  = [];
	_walkers = [];
	{
		if (count _lifted < _cargoSeats) then {
			_x assignAsCargo _airVeh;
			[_x] orderGetIn true;
			_lifted = _lifted + [_x];
		} else {
			_walkers = _walkers + [_x];
		};
	} forEach _footPax;

	//--- Overflow that did not fit walks by ground NOW (never idle).
	{if (alive _x) then {_x doMove _pos}} forEach _walkers;

	if (count _lifted > 0) then {
		//--- Pick an LZ: prefer a flat spot at the objective; else para-drop fallback.
		_lzPos = _pos;
		_flat  = _pos isFlatEmpty [12, 0, 2, 12, 0, false, objNull];
		if (count _flat > 0) then {_lzPos = _flat} else {_lzPos = _pos};

		//--- ===================================================================
		//--- cmdcon42 HOT-LZ PARADROP DECISION (Ray 2026-07-02, gate WFBE_C_AICOM_AIR_PARADROP default-ON):
		//--- if the transport would insert onto a CONTESTED or ENEMY-HELD LZ, the infantry PARADROPS (reuses the
		//--- proven no-flat-LZ EJECT fallback below) instead of the heli descending to land in the depot guns. ONE
		//--- bounded, decision-time evaluation - NO per-tick scans. Hot when EITHER:
		//---   (a) the LZ's nearest town is not our side (town logic getVariable "sideID" - broadcast, readable on the
		//---       HC where this runs; neutral/GUER/enemy all treated as jump-worthy), OR
		//---   (b) any HOSTILE unit (the ((side _team) getFriend (side _x)) < 0.6 idiom used elsewhere in this file) is
		//---       inside WFBE_C_AICOM_AIR_PARADROP_SCAN_R of the LZ (one nearEntities scan).
		//--- On a hot LZ we hand the Spawn a DROP POINT that is WFBE_C_AICOM_AIR_PARADROP_OFFSET m SHORT of the town
		//--- centre, back along the heli->town approach vector, and an EMPTY flat-list so the existing branch takes the
		//--- para path (the transport holds altitude, ejects there, then flies home/despawns exactly as today). A2-OA-safe:
		//--- getVariable "sideID" on a TOWN OBJECT (objects accept the [name,default] form; only GROUPS reject it),
		//--- getFriend/nearEntities, plain atan2 position-delta bearing (binary getDir is A3-only). NEVER-FROZEN: this only
		//--- chooses jump-vs-land; either way the pax get their unconditional post-insert doMove _obj into the order loop.
		private ["_forceDrop","_dropLz","_hotTown","_hotReason"];
		_forceDrop = false;
		_dropLz    = _lzPos;
		_hotReason = "";
		if ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_PARADROP", 1]) > 0) then {
			//--- (a) LZ town ownership: nearest town to the LZ, its broadcast sideID vs our sideID.
			_hotTown = objNull;
			if (count towns > 0) then {_hotTown = [_lzPos, towns] Call WFBE_CO_FNC_GetClosestEntity};
			if (!isNull _hotTown && {(_hotTown getVariable ["sideID", -1]) != _sideID}) then {
				_forceDrop = true;
				_hotReason = "enemy-town";
			};
			//--- (b) enemies near the LZ: ONE decision-time hostile scan (skip if (a) already tripped).
			if (!_forceDrop) then {
				private ["_scanR","_hostiles","_minHostiles"];
				_scanR = missionNamespace getVariable ["WFBE_C_AICOM_AIR_PARADROP_SCAN_R", 400];
				_minHostiles = (missionNamespace getVariable ["WFBE_C_AICOM_AIR_PARADROP_MIN_HOSTILE", 2]) max 1;
				_hostiles = {!isNull _x && {alive _x} && {((side _team) getFriend (side _x)) < 0.6} && {!(_x isKindOf "Man") || {(vehicle _x) == _x}}} count (_lzPos nearEntities [["Man","LandVehicle","Tank"], _scanR]);
				if (_hostiles >= _minHostiles) then {
					_forceDrop = true;
					_hotReason = "contested";
				};
			};
			//--- On a hot LZ, resolve a drop point OFFSET m short of the town centre, back along the heli->town vector, so
			//--- the jumpers do not eject directly over the depot guns. Fall back to the raw LZ if geometry is degenerate.
			if (_forceDrop) then {
				private ["_offset","_tc","_hp","_brg","_seg","_tcName"];
				_offset = missionNamespace getVariable ["WFBE_C_AICOM_AIR_PARADROP_OFFSET", 250];
				_tc = if (!isNull _hotTown) then {getPos _hotTown} else {_lzPos};
				_hp = getPos _airVeh;                                     //--- heli origin = approach source.
				_seg = _hp distance _tc;
				if (_seg > 5) then {
					//--- bearing heli -> town (A2-safe atan2 position-delta; binary getDir is A3-only).
					_brg = ((_tc select 0) - (_hp select 0)) atan2 ((_tc select 1) - (_hp select 1));
					//--- eject point = town centre pulled back _offset m toward the heli (clamped so we never overshoot past the heli).
					if (_offset > (_seg - 20)) then {_offset = (_seg - 20) max 0};
					_dropLz = [ (_tc select 0) - (_offset * sin _brg), (_tc select 1) - (_offset * cos _brg), 0 ];
				} else {
					_dropLz = _lzPos;
				};
				_tcName = if (!isNull _hotTown) then {_hotTown getVariable ["name","?"]} else {"pos"};
				diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|AIR_PARADROP|team=" + (str _team) + "|town=" + _tcName + "|reason=" + _hotReason);
				["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] HOT-LZ paradrop into [%3] (reason %4) - ejecting %5m short.", _side, _team, _tcName, _hotReason, _offset]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
		//--- ===================================================================

		//--- Pre-compute the heli's build cost NOW (clean scope) so the disembark
		//--- Spawn can REFUND it to the AI-commander treasury after a successful
		//--- fly-off to the map edge. Mirrors the canonical price lookup used by
		//--- AI_Commander_Teams.sqf L165 / AI_Commander_Wildcard.sqf L716:
		//--- (missionNamespace getVariable (typeOf _veh)) select QUERYUNITPRICE.
		_heliCost = 0;
		_ud = missionNamespace getVariable (typeOf _airVeh);
		if (!isNil "_ud") then {_heliCost = _ud select QUERYUNITPRICE};
		//--- Mark this hull as an AI-commander transport so the refund path can
		//--- never refund a player-owned or non-aicom heli.
		_airVeh setVariable ["wfbe_aicom_transport", true, true];

		//--- Fly the heli to the objective and unload. doMove + flyInHeight, then
		//--- land+disembark when close (heli-land) OR para-eject if no flat LZ.
		//--- cmdcon42 HOT-LZ: force the para branch by handing the Spawn the OFFSET drop point as the LZ and an EMPTY
		//--- flat-list, so the run-in halts short of the town and the existing (count _fl > 0) land-gate is false -> eject.
		if (_forceDrop) then {_lzPos = _dropLz; _flat = []};
		[_airVeh, _lzPos, _flat, _lifted, _team, _pos, _side, _sideID, _heliCost] Spawn {
			private ["_h","_lz","_fl","_pax","_tm","_obj","_t0","_sd","_sID","_cost","_edge","_wsz","_ex","_ey","_offPos","_hcrew","_approachLimited"];
			_h    = _this select 0;
			_lz   = _this select 1;
			_fl   = _this select 2;
			_pax  = _this select 3;
			_tm   = _this select 4;
			_obj  = _this select 5;
			_sd   = _this select 6;
			_sID  = _this select 7;
			_cost = _this select 8;
			//--- Let everyone board first.
			_t0 = time + 30;
			waitUntil {sleep 1; time > _t0 || {({alive _x && vehicle _x == _h} count _pax) >= ({alive _x} count _pax)}};
			if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
				//--- Heli lost mid-lift: any survivors still aboard/around get an unconditional move.
				{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;
			};
			_approachLimited = (missionNamespace getVariable ["WFBE_C_AICOM_HELI_APPROACH_LIMITED", 0]) > 0;
			if (_approachLimited) then {(group (driver _h)) setSpeedMode "LIMITED"};
			(driver _h) doMove _lz;
			_h flyInHeight (60 max (missionNamespace getVariable ["WFBE_C_AICOM_HELI_RUNINFLOOR", 0]));
			//--- Run in until near the LZ (or timeout / loss).
			_t0 = time + 240;
			waitUntil {sleep 2; time > _t0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {(_h distance _lz) < 120}};
			if (_approachLimited) then {(group (driver _h)) setSpeedMode "FULL"};
			if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
				{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;
			};
			if (count _fl > 0) then {
				//--- Flat LZ: command a real landing and disembark.
				_h land "GET OUT";
				_h flyInHeight 0;
				_t0 = time + 40;
				waitUntil {sleep 1; time > _t0 || {(getPosATL _h) select 2 < 1.5}};
				{if (alive _x && {vehicle _x == _h}) then {unassignVehicle _x; [_x] orderGetIn false}} forEach _pax;
			} else {
				//--- No flat LZ: para-drop over the objective (eject pattern, Support_Paratroopers).
				_h flyInHeight (120 + random 20);
				{
					if (alive _x && {vehicle _x == _h}) then {
						unassignVehicle _x;
						_x action ["EJECT", _h];
						sleep 0.85;
					};
				} forEach _pax;
			};
			//--- GUARD: dropped pax always get an unconditional ground move to the objective
			//--- (the order loop will then fold them into the team MOVE/SAD).
			{if (alive _x) then {_x doMove _obj}} forEach _pax;

			//--- HELI FLY-OFF + REFUND (user request): the empty team transport now flies
			//--- to the NEAREST MAP EDGE and, on reaching off-map ALIVE, is deleted and its
			//--- build cost is REFUNDED to the side's AI-commander treasury (server-routed).
			//--- If it is destroyed before reaching the edge, NO refund. Player/non-aicom
			//--- helis are guarded out via the wfbe_aicom_transport flag set at lift time.
			if (!isNull _h && {alive _h} && {!isNull (driver _h)} && {alive (driver _h)} && {_h getVariable ["wfbe_aicom_transport", false]}) then {
				//--- ===================================================================
				//--- cmdcon42-f RETAINED TRANSPORT (Ray: HQ air squads should BE air squads; gate
				//--- WFBE_C_AICOM_AIR_RETAIN default-ON): instead of the legacy off-map fly-off + delete +
				//--- REFUND below, KEEP the team's transport - route it through the SAME shared
				//--- return-to-base-and-hold path the air-mobile legs use (WFBE_CO_FNC_AICOMAirReturn, one
				//--- implementation, no duplication), so the hull parks at the side base and the order
				//--- loop's AIR-MOBILE branch can fly the team's NEXT orders with it. ECONOMICS (by design):
				//--- retaining FORGOES the legacy refund (_cost = the hull's QUERYUNITPRICE credited back to
				//--- the AI treasury on edge-exit) - the side keeps a REAL transport asset instead of the
				//--- credit. Flag 0 = fall through to the UNTOUCHED legacy body below (byte-identical
				//--- fly-off + delete + refund). LEADER-IS-CREW edge guard: if the group LEADER is part of
				//--- the transport CREW (aboard the hull but NOT one of the lifted pax), retaining would
				//--- park the team leader at base and the HC arrival latch (leader-distance) could never
				//--- latch for the dropped pax - fall back to the legacy fly-off for that founding (it
				//--- deletes the crew; the engine promotes a ground leader, exactly as today). Retained-hull
				//--- coverage (verified): B74.2 base-reap only reaps transportSoldier==0 attack helis;
				//--- AIR_REAP_UNCREWED skips it while the pilot lives; AUTOFUEL tops it off (it is in
				//--- _vehicles); the stuck-watcher airborne exemption covers its later legs. A2-OA-safe:
				//--- vehicle/in/leader tests + exitWith out of this then-scope only.
				private ["_retain"];
				_retain = (missionNamespace getVariable ["WFBE_C_AICOM_AIR_RETAIN", 1]) > 0;
				if (_retain && {!isNull _tm} && {!isNull (leader _tm)} && {(vehicle (leader _tm)) == _h} && {!((leader _tm) in _pax)}) then {
					_retain = false;
					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] AIR_RETAIN skipped - leader is transport crew; legacy fly-off/refund keeps the arrival latch on a ground leader.", _sd, _tm]] Call WFBE_CO_FNC_AICOMLog;
				};
				if (_retain) exitWith {
					diag_log ("AICOMSTAT|v2|EVENT|" + str _sID + "|" + str (round (time / 60)) + "|AIR_RETAIN|team=" + (str _tm) + "|heli=" + (typeOf _h));
					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] transport %3 RETAINED (no refund) - returning to base to hold for the next order.", _sd, _tm, typeOf _h]] Call WFBE_CO_FNC_AICOMLog;
					[_h, _tm, _sd] Call WFBE_CO_FNC_AICOMAirReturn;
				};
				//--- ===================================================================
				//--- Clamp the heli's exit toward the CLOSEST of the four map edges (worldSize box).
				//--- N-FEATUREBUG-43 fix 2026-06-27: was hardcoded 15360 (Chernarus only) -> the off-map edge math + the
				//--- waitUntil off-map exit test below were 2560m wrong on Takistan/Zargabad (both 12800), so the heli
				//--- either never registered as off-map or refunded early. worldSize is A3-ONLY (A2 OA latent bug), so
				//--- branch the box size off worldName, matching Init_Boundaries.sqf (chernarus=15360, takistan=12800, zargabad=8192).
				_wsz = switch (toLower worldName) do {
					case "chernarus": {15360};
					case "takistan":  {12800};
					case "zargabad":  {8192};
					default {15360};
				};
				_ex  = (getPos _h) select 0;
				_ey  = (getPos _h) select 1;
				//--- distance to each edge: x=0, x=worldSize, y=0, y=worldSize.
				_offPos = [_ex, _ey, 0];
				//--- Pick the nearest edge explicitly (A2-safe, no isEqualTo dependency).
				if (_ex <= (_wsz - _ex) && {_ex <= _ey} && {_ex <= (_wsz - _ey)}) then {
					_offPos = [-200, _ey, 0];               //--- nearest = west edge (x=0)
				} else {
					if ((_wsz - _ex) <= _ey && {(_wsz - _ex) <= (_wsz - _ey)}) then {
						_offPos = [_wsz + 200, _ey, 0];     //--- nearest = east edge (x=worldSize)
					} else {
						if (_ey <= (_wsz - _ey)) then {
							_offPos = [_ex, -200, 0];       //--- nearest = south edge (y=0)
						} else {
							_offPos = [_ex, _wsz + 200, 0]; //--- nearest = north edge (y=worldSize)
						};
					};
				};
				_h flyInHeight (90 + random 30);
				(driver _h) doMove _offPos;
				//--- Wait until it reaches/crosses the edge (off-map) OR is lost. Cap ~6 min.
				_t0 = time + 360;
				waitUntil {sleep 3; time > _t0 || isNull _h || {!alive _h} || {((getPos _h) select 0) < 0} || {((getPos _h) select 0) > _wsz} || {((getPos _h) select 1) < 0} || {((getPos _h) select 1) > _wsz}};
				//--- REFUND ONLY if it reached the edge ALIVE. Destroyed-en-route = no refund.
				if (!isNull _h && {alive _h} && {(((getPos _h) select 0) < 0) || (((getPos _h) select 0) > _wsz) || (((getPos _h) select 1) < 0) || (((getPos _h) select 1) > _wsz)} && {_h getVariable ["wfbe_aicom_transport", false]}) then {
						private ["_htype"];
						_htype = typeOf _h;          //--- capture BEFORE delete (typeOf of a deleted obj is "").
					_hcrew = crew _h;
					{deleteVehicle _x} forEach _hcrew;
					deleteVehicle _h;
					if (_cost > 0) then {
						if (isServer) then {
							["aicom-heli-refunded", _sID, _cost] Call HandleSpecial;
						} else {
							["RequestSpecial", ["aicom-heli-refunded", _sID, _cost]] Call WFBE_CO_FNC_SendToServer;
						};
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team transport %2 flew off-map, deleted + refunded $%3.", _sd, _htype, _cost]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			};
		};
		["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] AIR-INSERT via own %3 (lifted %4, walked %5).", _side, _team, typeOf _airVeh, count _lifted, count _walkers]] Call WFBE_CO_FNC_AICOMLog;
	};
};
//--- ===================================================================

//--- ===================================================================
//--- GROUND MOUNT-UP (Feature A: mechanized/motorized mounted infantry). Fires ONCE
//--- before the order loop, and ONLY when the team has NO air transport (isNull _airVeh)
//--- so air-insert teams are untouched. Fills the CARGO seats of the team's own ground
//--- IFV/truck/light vehicles with the on-foot template infantry, so a mech/motor team
//--- RIDES to the objective instead of spawning next to an empty hull and walking. The
//--- existing capture force-dismount (~L545-568) puts them back on foot at the town, and
//--- the B37 mid-march re-mount (~L369) keeps stragglers aboard. Idiom mirrors the proven
//--- side-patrol remount (Common_RunSidePatrol.sqf:202-203) and the air-lift load above
//--- (L163-171): assignAsCargo + orderGetIn true.
//--- NO-FROZEN-AI GUARD (hard): assignAsCargo + orderGetIn are NON-BLOCKING and there is
//--- NO waitUntil/sleep here - the seat fill is a single-frame bounded loop. Any rider
//--- that fails to board simply keeps its existing march order and walks; overflow infantry
//--- (more bodies than seats) stay on foot and road-march exactly as today. No sim/distance
//--- gating, no static AI touched. Riders are consumed by a monotonic index so no rider is
//--- double-assigned (bounced) across multiple ground vehicles.
if (isNull _airVeh) then {
	private ["_ridePool","_riders","_rIdx","_nRiders","_seatLeft","_rider","_assigned"];
	//--- B66 TRANSPORT MOUNT-UP / GUER-AVOID (Ray constraint): a mounted road-march must NOT drive the
	//--- unarmored troop-truck into a hostile (enemy/GUER-held) town`s STATIC GUNS. Before mounting,
	//--- scan the straight-line drive path (team leader -> objective _pos) for any town NOT held by us
	//--- (sideID != _sideID, i.e. enemy/GUER/neutral garrison) whose centre lies within a danger band of
	//--- that path. If one blocks the route, KEEP the infantry ON FOOT for this leg (skip the seat-fill):
	//--- they advance dismounted and fight, and the truck is never driven into the guns. The crewed hulls
	//--- still get their normal road-march order from the order loop; overflow/foot infantry road-march as
	//--- today. A2-OA-safe: point-to-segment distance via plain arithmetic (no worldSize/findIf), getVariable
	//--- "sideID" on a TOWN object (objects support the 2-arg form; only GROUPS do not). NEVER-FROZEN: this
	//--- only chooses ride-vs-walk; the infantry always hold their march order either way.
	private ["_mountBlocked","_dangerR","_mLdr","_ax","_ay","_bx","_by","_segDX","_segDY","_segLen2","_tcx","_tcy","_proj","_clx","_cly","_pathD"];
	_mountBlocked = false;
	_dangerR = missionNamespace getVariable ["WFBE_C_AICOM_TRANSPORT_AVOID_RANGE", 350];
	_mLdr = leader _team;
	if (!isNull _mLdr && {alive _mLdr}) then {
		_ax = (getPosATL _mLdr) select 0; _ay = (getPosATL _mLdr) select 1;
		_bx = _pos select 0; _by = _pos select 1;
		_segDX = _bx - _ax; _segDY = _by - _ay;
		_segLen2 = (_segDX * _segDX) + (_segDY * _segDY);
		{
			if (!_mountBlocked && {!isNull _x} && {(_x getVariable ["sideID", -1]) != _sideID}) then {
				_tcx = (getPos _x) select 0; _tcy = (getPos _x) select 1;
				//--- closest point on segment A->B to the town centre (clamped t in [0,1]); guard zero-length leg.
				_proj = if (_segLen2 <= 1) then {0} else {(((_tcx - _ax) * _segDX) + ((_tcy - _ay) * _segDY)) / _segLen2};
				if (_proj < 0) then {_proj = 0}; if (_proj > 1) then {_proj = 1};
				_clx = _ax + (_segDX * _proj); _cly = _ay + (_segDY * _proj);
				_pathD = sqrt (((_tcx - _clx) * (_tcx - _clx)) + ((_tcy - _cly) * (_tcy - _cly)));
				if (_pathD < _dangerR) then {_mountBlocked = true};
			};
		} forEach towns;
	};
	if (_mountBlocked) then {
		//--- Hostile garrison astride the route: stay on foot (never ride the truck into static guns).
		{if (alive _x && {vehicle _x == _x}) then {_x doMove _pos}} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
		["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] MOUNT-UP SKIPPED - hostile town within %3m of the drive path; infantry advance on foot (GUER-avoid).", _side, _team, _dangerR]] Call WFBE_CO_FNC_AICOMLog;
	};
	//--- Drivable ground hulls with at least one free cargo seat (no Air, must be mobile).
	_ridePool = [];
	{
		if (!isNull _x && {alive _x} && {!(_x isKindOf "Air")} && {canMove _x}
			&& {(_x emptyPositions "cargo") > 0}
			&& {((missionNamespace getVariable ["WFBE_C_AICOM_ARMED_TRANSPORT_ONLY", 1]) <= 0) || {(count (weapons _x)) > 0}}) then {_ridePool = _ridePool + [_x]}; //--- B69 (Ray 2026-06-22): ONLY armed hulls (count weapons > 0 -> APC/IFV/armed technical) carry troops; skip unarmed troop-trucks that drove infantry into the town centre and evaporated. Unmounted infantry advance ON FOOT via the group road-march order (never frozen). Air transport (helis) is a separate path, untouched. Tunable/reversible via WFBE_C_AICOM_ARMED_TRANSPORT_ONLY (0 = old behaviour).
	} forEach _grndVehs;
	if (count _ridePool > 0 && {!_mountBlocked}) then { //--- B66: skip the seat-fill when a hostile town blocks the route
		//--- On-foot, non-crew infantry only (crew already man their hulls; air-lift idiom L155-158).
		_riders = [];
		{
			if (alive _x && {vehicle _x == _x}) then {_riders = _riders + [_x]};
		} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
		_nRiders  = count _riders;
		_rIdx     = 0;
		_assigned = 0; private ["_totalSeats","_seatOK"]; _totalSeats = 0; { _totalSeats = _totalSeats + (_x emptyPositions "cargo") } forEach _ridePool; _seatOK = (_totalSeats >= (_nRiders * (missionNamespace getVariable ["WFBE_C_AICOM_MOUNT_MIN_SEAT_FRAC", 0.8]))); //--- B756 (Ray 2026-06-26) seat-capacity gate: only mount if the ride pool seats most of the squad; a PARTIAL mount splits the team (the hull drives off, the foot element strands -> ASSAULT_STRANDED). Below the fraction the squad stays foot-cohesive (the hull paces the group road-march).
		{
			_veh = _x;
			_seatLeft = _veh emptyPositions "cargo";
			//--- Single-frame seat fill: pull riders by index so none is assigned twice across hulls.
			while {_seatLeft > 0 && {_rIdx < _nRiders}} do {
				_rider = _riders select _rIdx;
				_rIdx  = _rIdx + 1;
				if (_seatOK && {alive _rider} && {vehicle _rider == _rider}) then { //--- B756: only board if the squad mostly fits (else stay foot-cohesive).
					_rider assignAsCargo _veh;
					[_rider] orderGetIn true;
					_seatLeft = _seatLeft - 1;
					_assigned = _assigned + 1;
				};
			};
		} forEach _ridePool;
		//--- Overflow infantry (beyond seat capacity) stay on foot and road-march as today - never idle.
		["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] GROUND MOUNT-UP (%3 ride vehicles, %4 infantry mounted of %5 on foot).", _side, _team, count _ridePool, _assigned, _nRiders]] Call WFBE_CO_FNC_AICOMLog;
	};
};
//--- ===================================================================

while {!WFBE_GameOver && _alive} do {
	//--- AICOM v2 (Ray): reap UNCREWED/bugged aircraft. An airframe (heli OR plane) alive with NO alive crew is
	//--- orphaned (crew killed/bailed/bugged) - it crashes, sits, or piles up over a long round. Delete it after a
	//--- short grace so it can't accumulate. Stamp-on-first-seen avoids deleting a transient bail/reseat. HC-local.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_REAP_UNCREWED", 1]) > 0) then {
		{
			if (!isNull _x && {alive _x} && {local _x} && {_x isKindOf "Air"}) then {
				if (({alive _x} count (crew _x)) == 0) then {
					private ["_us"]; _us = _x getVariable "wfbe_air_uncrewed_at";
					if (isNil "_us") then {_x setVariable ["wfbe_air_uncrewed_at", time]} else {
						if ((time - _us) >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_REAP_GRACE", 45])) then {deleteVehicle _x};
					};
				} else {
					_x setVariable ["wfbe_air_uncrewed_at", nil];
				};
			};
		} forEach _vehicles;
	};

	//--- AICOM v2 (cmdcon29, Ray): crew SELF-REPAIR of an immobilized ground vehicle. A team whose vehicle
	//--- has a shot-out wheel/track or a blown engine (!canMove) strands the whole team (moved=0). When the
	//--- vehicle still has a live crew, is NOT in a firefight, and no enemy is near, the crew effects a field
	//--- repair after a short delay -> mobility restored, the team rolls again instead of lingering forever.
	//--- HC-local (vehicles are local here). The !canMove gate is checked first, so the nearEntities threat
	//--- scan only runs for the rare actually-immobilized vehicle.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_VEHICLE_SELFREPAIR", 1]) > 0) then {
		private ["_srVeh","_srSafe","_srDelay"];
		_srSafe  = missionNamespace getVariable ["WFBE_C_AICOM_SELFREPAIR_SAFE_DIST", 250];
		_srDelay = missionNamespace getVariable ["WFBE_C_AICOM_SELFREPAIR_DELAY", 30];
		{
			_srVeh = _x;
			if (!isNull _srVeh && {alive _srVeh} && {local _srVeh} && {_srVeh isKindOf "LandVehicle"} && {!(canMove _srVeh)} && {({alive _x} count (crew _srVeh)) > 0}) then {
				//--- threat present (enemy/neutral-hostile within the safe radius) or the team is fighting? stand down.
				private ["_srThreat","_srStamp"];
				_srThreat = {!isNull _x && {alive _x} && {((side _team) getFriend (side _x)) < 0.6}} count (_srVeh nearEntities [["Man","LandVehicle"], _srSafe]);
				if (_srThreat == 0 && {behaviour (leader _team) != "COMBAT"}) then {
					_srStamp = _srVeh getVariable "wfbe_aicom_repair_at";
					if (isNil "_srStamp") then {
						_srVeh setVariable ["wfbe_aicom_repair_at", time];
					} else {
						if ((time - _srStamp) >= _srDelay) then {
							_srVeh setDamage 0;
							_srVeh setVariable ["wfbe_aicom_repair_at", nil];
							diag_log ("AICOMSTAT|v1|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|VEHICLE_SELFREPAIR|veh=" + (typeOf _srVeh));
						};
					};
				} else {
					//--- enemy appeared or the team engaged: cancel any in-progress repair so it must re-earn the safe window.
					_srVeh setVariable ["wfbe_aicom_repair_at", nil];
				};
			} else {
				if (!isNull _srVeh) then {_srVeh setVariable ["wfbe_aicom_repair_at", nil]};
			};
		} forEach _vehicles;
	};

	//--- cmdcon41-w3h (Ray 2026-07-02): AICOM vehicles never run out of fuel. A dry tank strands the whole
	//--- team exactly like a blown engine, but no recovery tier can fix "out of gas" - so top the hull off
	//--- silently whenever it drops low. HC-local (setFuel needs vehicle locality - guaranteed here). No
	//--- threat gate on purpose: a dry vehicle under fire still has to be able to move (never-frozen mandate).
	if ((missionNamespace getVariable ["WFBE_C_AICOM_AUTOFUEL", 1]) > 0) then {
		{
			if (!isNull _x && {alive _x} && {local _x} && {(fuel _x) < (missionNamespace getVariable ["WFBE_C_AICOM_AUTOFUEL_BELOW", 0.25])}) then {
				_x setFuel 1;
				diag_log ("AICOMSTAT|v1|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|AUTOFUEL|veh=" + (typeOf _x));
			};
		} forEach _vehicles;
	};

	_alive = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

	//--- B36.1 (Ray 2026-06-15): PC-scale retirement. The server flags a REAR team (wfbe_aicom_disband)
	//--- when the human player count rises - fewer HQ squads = server relief. Units are HC-LOCAL here, so
	//--- the delete must happen on the HC. GUARDRAIL (hard): re-check on THIS machine that no player is
	//--- within the safe radius and the team is not in combat before deleting - never a player-visible
	//--- vanish. If a player has come close since the server flagged it, STAND DOWN (clear the flag, keep
	//--- fighting) and let the next server cycle re-evaluate. A2 getVariable: 1-arg + isNil (see _order below).
	if (_alive && {!isNull _team}) then {
		private ["_dis"];
		_dis = _team getVariable "wfbe_aicom_disband";
		if (!isNil "_dis" && {_dis}) then {
			private ["_dLdr","_dSafe","_dNear","_dCombat","_dCmd"];
			_dLdr  = leader _team;
			_dSafe = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_SAFE_DIST", 900];
			_dCmd = _team getVariable "wfbe_aicom_disband_cmd"; _dCmd = (!isNil "_dCmd" && {_dCmd}); _dNear = if (_dCmd || {isNull _dLdr}) then {0} else {{isPlayer _x && {alive _x} && {(_x distance _dLdr) < _dSafe}} count allUnits}; //--- Build84: explicit console order bypasses player-proximity veto
			_dCombat = if (isNull _dLdr) then {false} else {behaviour _dLdr == "COMBAT"};
			if (_dNear == 0 && {!_dCombat}) then {
				{ if (local _x) then {deleteVehicle _x} } forEach (units _team);
				//--- cmdcon44s (correctness): retirement must delete the team HULLS too, not just the crew (units _team above).
				//--- A retired REAR team otherwise leaves crewless tanks/helis parked at base forever - no reaper catches an
				//--- HC-local, group-less hull. HC-local delete only; skip any hull a player is aboard (belt-and-braces; the
				//--- _dNear guard already cleared nearby players). Capture the outer _x before the inner count (A2 rebind trap).
				{ private ["_rv"]; _rv = _x; if (!isNull _rv && {local _rv} && {({isPlayer _x} count (crew _rv)) == 0}) then {deleteVehicle _rv} } forEach _vehicles;
				_alive = false;
				diag_log ("AICOMSTAT|v1|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|TEAM_RETIRE_HC|deleted-local-units|cmd=" + str _dCmd);
			} else {
				if (!_dCmd) then {_team setVariable ["wfbe_aicom_disband", false, true]}; //--- Build84: latch explicit console orders (fire when combat ends); only the automatic sweep clears on player-proximity
			};
		};
	};

	if (_alive) then {
		//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
		_order = _team getVariable "wfbe_aicom_order";
		if (isNil "_order") then {_order = []};
		if (count _order >= 3) then {
			_seq = _order select 0;
			_mode = _order select 1;
			_dest = _order select 2;

			//--- DECAP PRESS HOOK (consumes the #724 organic-closer stamp; the first and only reader).
			//--- Per-pass plain get + isNil (group vars have no 2-arg default form). While stamped, override
			//--- THIS pass's dest/mode with the stamped HQ pos + the existing "goto" press idiom (Strategy
			//--- L903 doctrine: "goto" = press through the arrival SAD into the BASE-ASSAULT fire phase below;
			//--- NOT "defense" hold, NOT "towns-target" capture). Stamp appear/clear each force ONE synthetic
			//--- fresh-order pass (sentinel _lastSeq) so movement re-issues immediately and the team falls
			//--- back to its REAL order the pass after the closer clears the stamp (drift/ABORT/WON) - the
			//--- override is recomputed every pass, never latched. Fixed-wing teams excluded (ground press
			//--- only this increment; heli-LIFT infantry teams are ordinary ground carriers here). At flag 0
			//--- no stamp ever exists (#724 clears them) -> _pressPos isNil -> provably byte-inert no-op.
			_pressSyn = false;
			_pressPos = _team getVariable "wfbe_aicom_decap";
			_pressAct = (!isNil "_pressPos") && {typeName _pressPos == "ARRAY"} && {count _pressPos >= 2};   //--- stack-pass: [] = broadcast-clear sentinel (nil cannot network on A2 OA)
			if (_pressAct && {!_isPlaneTeam}) then {
				_pressOn = _team getVariable "wfbe_aicom_press_on";
				if (isNil "_pressOn") then {
					_team setVariable ["wfbe_aicom_press_on", true];
					_team setVariable ["wfbe_aicom_press_pos", _pressPos];
					_team setVariable ["wfbe_aicom_rallying", false, true];   //--- stack-pass MAJOR: an ex-rally team must not take the RALLY-ARRIVED branch at the HQ (it would clear strike/caplock + flip teammode instead of assaulting)
					_team setVariable ["wfbe_aicom_route", []];               //--- stack-pass MAJOR: drop the STALE town road chain (HC-local; the server re-snaps on its next real issue) - otherwise the synthetic accept re-lays node-1-first and the convoy BACKTRACKS the old route away from the HQ
					_pressSyn = true;
					_lastSeq = -999999;   //--- synthetic fresh order: re-route onto the HQ pos THIS pass
					diag_log ("AICOM2|v1|DECAP|" + str _side + "|" + str (round (time / 60)) + "|PRESS|team=" + (str _team) + "|dist=" + str (round ((leader _team) distance _pressPos)));
				} else {
					//--- stack-pass: moving HQ mid-press (MHQ redeploys) -> re-lay movement once the stamp drifts >150m
					_pressPrev = _team getVariable "wfbe_aicom_press_pos";
					if (isNil "_pressPrev") then {_pressPrev = _pressPos};
					if ((_pressPrev distance _pressPos) > 150) then {
						_team setVariable ["wfbe_aicom_press_pos", _pressPos];
						_team setVariable ["wfbe_aicom_route", []];
						_pressSyn = true;
						_lastSeq = -999999;
					};
				};
				_mode = "goto";
				_dest = _pressPos;
			} else {
				if (!isNil {_team getVariable "wfbe_aicom_press_on"}) then {
					_team setVariable ["wfbe_aicom_press_on", nil];
					_team setVariable ["wfbe_aicom_press_pos", nil];
					_team setVariable ["wfbe_aicom_route", []];               //--- stack-pass: the stale chain is equally wrong for the re-accepted REAL order from out here - go direct; the server re-snaps on its next issue
					_pressSyn = true;
					_lastSeq = -999999;   //--- press ended -> re-accept the real order in the fresh-order block
				};
			};

			if (_seq != _lastSeq) then {
				//--- Fresh order: head out.
				_lastSeq = _seq;
				_arrived = false;
				_captureDone = false;
				_team setVariable ["wfbe_aicom_arrival_trace_at", time + 60];
				diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|CAPTURE_TRACE|ORDER_ACCEPT|team=" + (str _team) + "|seq=" + str _seq + "|mode=" + str _mode + "|dist=" + str (round ((leader _team) distance _dest)));

				//--- REAL UNSTUCK (task #14/#16): if this fresh order is a STUCK re-issue
				//--- (server bumped wfbe_aicom_unstuck > 0 because the team sat parked far
				//--- from target, not in contact), the bare re-route below is not enough for
				//--- a hull physically wedged at base (distStart=0). Escalate by strike tier
				//--- BEFORE laying the new route, HC-side where the units are local:
				//---   Tier 1: zero the lead hull's velocity + short reverse to break the wedge.
				//---   Tier 2: rely on the fresh ROAD route below (re-snapped from current pos).
				//---   Tier 3 (>=3): last-resort tiny teleport of the lead hull onto the nearest
				//---           clear non-water road node - ONLY when no player is within 300 m
				//---           (MEMORY guardrail: never a player-visible teleport / frozen AI).
				//--- Every tier still ends in the road route below = the unit always holds a move.
				_usTier = if (count _order > 3) then {_order select 3} else {0}; //--- UNSTUCK FIX (Ray 2026-06-16): read the strike tier from the order seq (atomic), NOT the out-of-band wfbe_aicom_unstuck flag, which a later commander cycle reset to 0 before this fresh-seq block ran -> UNSTUCK_FIRED was ~never hit. Governor at ~459 still reads the flag for gear-slow (unaffected).
				if (_pressSyn) then {_usTier = 0};   //--- stack-pass: synthetic press accepts are NOT stuck re-issues - never re-fire the strike ladder (reverse pulse / lane flip / tier-3 teleport) off the real order's stale tier
				if (isNil "_usTier") then {_usTier = 0};
				if (_pressAct) then {_usTier = 0};	//--- press guard: a stamped pressing team (valid press pos) is not a stuck re-issue - never fire the UNSTUCK strike ladder (teleport/reverse/lane-flip) on a live press
				if (_usTier > 0) then {
					[_team, _usTier, _side] Spawn {
						private ["_uTeam","_uTier","_uSide","_uLdr","_uVeh","_uNode","_uRds","_uPlayerNear","_uOnFoot","_uHullDead","_uFootPlayerNear","_uFootRds","_uFootNode","_recV2","_uOnWater","_uForceRoad","_uFlush","_uFlushOrder","_uFlushSeq","_uFlushMode","_uFlushDest"]; //--- cmdcon41-w3e +_recV2/_uOnWater/_uForceRoad; lane377 +_uFlush*
						_uTeam = _this select 0;
						_uTier = _this select 1;
						_uSide = _this select 2;
						_uLdr  = leader _uTeam;
						if (isNull _uLdr || {!alive _uLdr}) exitWith {};
						//--- cmdcon41-w3e RECOVERY V2 (gate WFBE_C_AICOM_RECOVERY_V2 default 1): three verified-safe upgrades
						//--- layered onto the EXISTING strike-ladder recovery Spawn (no new per-tick scan - this Spawn only fires on a
						//--- stuck re-issue). (c) DEAD-DRIVER SWAP: a live drivable hull whose driver is dead/empty but that still has a
						//--- live crewman gets that crewman moved into the driver seat (locality-safe: this Spawn runs where the group +
						//--- its hulls are local). (b) LANE-FLIP re-path: on a tier-1 wedge add a real reverse-velocity pulse along
						//--- -vectorDir AND flip the sign of the team persistent wfbe_aicom_lanejit so the NEXT server-side
						//--- BuildRoadRoute lays a DIFFERENT lane instead of re-snapping the same stuck path. (e) WATER GUARD: a
						//--- hull/leader on water is exactly the case Common_AICOM_AutoFlip refuses (it exits on surfaceIsWater) -
						//--- force the tier-3 road-snap recovery immediately regardless of tier. Candidate (a) vehicle UNFLIP is NOT
						//--- added here: it already ships as Common_AICOM_AutoFlip.sqf (Build84, server+HC 5s loop). A2-OA-safe:
						//--- surfaceIsWater / vectorDir / crew / moveInDriver / setVelocity only (no A3 ops, no isEqualType).
						_recV2 = (missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_V2", 1]) > 0;
						_uOnWater = false;
						_uForceRoad = false;
						_uFlush = (missionNamespace getVariable ["WFBE_C_AICOM_TELEPORT_ORDER_FLUSH", 1]) > 0;
						//--- B37 (Ray 2026-06-16): log that the unstuck ACTION fired at this tier, so the
						//--- strike -> fire -> recover lifecycle is visible (UNSTUCK_STRIKE -> UNSTUCK_FIRED ->
						//--- next ASSAULT_STRANDED moved=).
						//--- cmdcon43-j (telemetry, minimal): tag the UNSTUCK_FIRED line with map= (worldName) + dist= (leader->order-dest
						//--- metres = the stall severity at fire-time) so future ladder tuning can attribute recoveries per-map + see how far
						//--- out the wedge is (a near-target uncap-park wedge vs a far cross-country strand escalate very differently on the
						//--- steep maps). worldName is a global command; the dest is read HC-locally from the team's own order (A2-safe: groups
						//--- reject the [name,default] getVariable form -> plain get + isNil + count guard, no A3 ops).
						private ["_uDbgDest","_uDbgDist","_uDbgOrder"];
						_uDbgDist = -1;
						_uDbgOrder = _uTeam getVariable "wfbe_aicom_order";
						if (!isNil "_uDbgOrder" && {count _uDbgOrder >= 3}) then {
							_uDbgDest = _uDbgOrder select 2;
							if (!isNil "_uDbgDest") then {_uDbgDist = round (_uLdr distance _uDbgDest)};
						};
						diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|UNSTUCK_FIRED|team=" + (str _uTeam) + "|tier=" + str _uTier + "|map=" + worldName + "|dist=" + str _uDbgDist);
							//--- WASPSCALE recov counter (cmdcon42): shared cumulative recovery-action counter the WASPSCALE emit reads (recov=). Bumped in the missionNamespace of WHICHEVER machine this team is local to; the server emit therefore reports its own SERVER-LOCAL recoveries (HC-delegated team recoveries show as UNSTUCK_FIRED on the HC RPT, which analyze_soak reads). Monotonic.
							missionNamespace setVariable ["wfbe_waspscale_recov", (missionNamespace getVariable ["wfbe_waspscale_recov", 0]) + 1];
						//--- B37 RE-MOUNT (Ray's mechanized-infantry ask): any team member on foot but with a live,
						//--- drivable assigned vehicle is ordered back in, so infantry that fell out during the stall
						//--- actually rides to the objective instead of walking/idling.
						{ if (alive _x && {vehicle _x == _x} && {!isNull (assignedVehicle _x)} && {alive (assignedVehicle _x)} && {canMove (assignedVehicle _x)}) then {[_x] orderGetIn true} } forEach (units _uTeam);
						_uVeh = vehicle _uLdr;
						//--- cmdcon41-w3e (e) WATER GUARD precompute: is the stuck hull (or on-foot leader) sitting on water?
						//--- A beached/water hull never self-frees and AutoFlip skips it, so flag it to force the road-snap below.
						if (_recV2) then {
							if (!isNull _uVeh && {alive _uVeh} && {surfaceIsWater (getPos _uVeh)}) then {_uOnWater = true};
							if (((vehicle _uLdr) == _uLdr) && {surfaceIsWater (getPos _uLdr)}) then {_uOnWater = true};
							if (_uOnWater) then {_uForceRoad = true};
						};
						//--- cmdcon41-w3e (c) DEAD-DRIVER SWAP: the lead hull is alive + drivable but has no live driver, yet a
						//--- live crewman remains aboard - move the first alive non-player crewman into the driver seat so the
						//--- reverse nudge + road route below actually have a driver (else the hull sits crewed-but-driverless).
						//--- Locality-safe: the group + its hulls are local on this machine. A2-OA-safe: crew / moveInDriver.
						if (_recV2 && {!isNull _uVeh} && {_uVeh != _uLdr} && {alive _uVeh} && {canMove _uVeh} && {(isNull (driver _uVeh)) || {!alive (driver _uVeh)}}) then {
							private ["_swapCrew","_swapPick"];
							_swapCrew = crew _uVeh;
							_swapPick = objNull;
							{ if (isNull _swapPick && {alive _x} && {!isPlayer _x} && {_x != (driver _uVeh)}) then {_swapPick = _x} } forEach _swapCrew;
							if (!isNull _swapPick) then {
								_swapPick moveInDriver _uVeh;
								["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] RECOVERY_V2 dead-driver swap - moved live crewman into %3 driver seat.", _uSide, _uTeam, typeOf _uVeh]] Call WFBE_CO_FNC_AICOMLog;
							};
						};
						//--- TP-15 STUCK-DRIVEN IN-PLACE REPAIR (WFBE_C_AICOM_STUCK_REPAIR default 0). A tier-2/3 unstuck means
						//--- the hull sat wedged/parked far from target and NOT in contact (the tier is only set when the
						//--- server flagged a non-combat stall). Rather than DETOUR the team to a town/service point, restore
						//--- the lead hull IN PLACE so the reverse-nudge + re-route below act on a healthy, armed hull. Mirrors
						//--- the SELFREPAIR idiom (local + alive + LandVehicle + no-threat gate); adds setVehicleAmmo 1 (a long
						//--- stall can burn the leg ammo). One-shot at the event (this Spawn fires once per stuck re-issue), not
						//--- a per-tick loop. A2-OA-safe: setDamage / setVehicleAmmo / nearEntities / getFriend (no A3 commands).
						if (_uTier >= 2 && {(missionNamespace getVariable ["WFBE_C_AICOM_STUCK_REPAIR", 0]) > 0} && {!isNull _uVeh} && {_uVeh != _uLdr} && {alive _uVeh} && {local _uVeh} && {_uVeh isKindOf "LandVehicle"}) then {
							private ["_srSafe2","_srThreat2"];
							_srSafe2   = missionNamespace getVariable ["WFBE_C_AICOM_SELFREPAIR_SAFE_DIST", 250];
							_srThreat2 = {!isNull _x && {alive _x} && {((side _uTeam) getFriend (side _x)) < 0.6}} count (_uVeh nearEntities [["Man","LandVehicle"], _srSafe2]);
							if (_srThreat2 == 0) then {
								_uVeh setDamage 0;
								_uVeh setVehicleAmmo 1;
								diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|STUCK_REPAIR|team=" + (str _uTeam) + "|tier=" + str _uTier + "|veh=" + (typeOf _uVeh));
								//--- STUCK_REPAIR_RESETS_TIER (2026-07-06, flag WFBE_C_AICOM_STUCK_REPAIR_RESETS_TIER default 0):
								//--- A successful in-place repair (setDamage 0 + canMove) leaves the tier counter at the high
								//--- pre-repair value; AssignTowns then re-issues at that same tier even though the hull is
								//--- now healthy. Reset wfbe_aicom_stuckstrikes to 0 (broadcast so the server's next
								//--- AssignTowns cycle reads the cleared counter). Inert when flag = 0.
								//--- A2-OA-safe: group setVariable with broadcast=true, canMove (no A3 commands).
								if ((missionNamespace getVariable ["WFBE_C_AICOM_STUCK_REPAIR_RESETS_TIER", 0]) > 0 && {canMove _uVeh}) then {
									_uTeam setVariable ["wfbe_aicom_stuckstrikes", 0, true];
									diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|UNSTUCK_TIER_RESET|team=" + (str _uTeam) + "|seq=" + str _seq + "|tier=" + str _uTier + "|map=" + worldName);
								};
							};
						};

						//--- SML-5 surgical unstuck: nudge only individually-wedged foot units before tier escalation. Flag-gated (WFBE_C_SML_SURGICAL_UNSTUCK default 0).
						//--- NOTE: this is a synchronous Call inside an already-Spawned block. It returns and tier 1/2/3 escalation fires normally regardless.
						//--- At flag 0 this block is never entered - tier logic is byte-identical to HEAD.
						if ((missionNamespace getVariable ["WFBE_C_SML_SURGICAL_UNSTUCK", 0]) > 0) then {
							[_uTeam, _uSide] Call WFBE_CO_FNC_SMLUnstuck;
						};
						//--- Tier 1: break a physical wedge on the lead hull.
						if (!isNull _uVeh && {_uVeh != _uLdr} && {alive _uVeh} && {canMove _uVeh}) then {
							_uVeh setVelocity [0,0,0];
							//--- cmdcon41-w3e (b) REVERSE-THEN-REPATH: a couple of real reverse-velocity pulses along -vectorDir
							//--- physically back the wedged hull out of the obstacle it climbed, THEN flip the team persistent
							//--- wfbe_aicom_lanejit sign so the NEXT server-side BuildRoadRoute (AssignTowns reads wfbe_aicom_lanejit
							//--- for the lateral lane) re-lays the leg on a DIFFERENT lane instead of the same stuck path. Legacy path
							//--- (flag off) keeps only the doMove reverse-nudge. A2-OA-safe: vectorDir / setVelocity / setVariable.
							if (_recV2) then {
								private ["_uDir","_uRevSpd","_uJit"];
								_uDir = vectorDir _uVeh; //--- unit forward vector; reverse = negate + scale.
								_uRevSpd = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_REVERSE_SPEED", 6];
								_uVeh setVelocity [(- (_uDir select 0)) * _uRevSpd, (- (_uDir select 1)) * _uRevSpd, (velocity _uVeh) select 2];
								sleep 1.5;
								if (!isNull _uVeh && {alive _uVeh}) then {_uVeh setVelocity [(- (_uDir select 0)) * _uRevSpd, (- (_uDir select 1)) * _uRevSpd, (velocity _uVeh) select 2]};
								//--- LANE-FLIP: flip the persistent per-team lane sign so the re-lay picks a different lane offset.
								_uJit = _uTeam getVariable "wfbe_aicom_lanejit";
								if (isNil "_uJit") then {_uJit = (random 2) - 1};
								if ((abs _uJit) < 0.05) then {_uJit = 1}; //--- a zero lane cannot flip; seed it so the re-path actually diverges.
								_uTeam setVariable ["wfbe_aicom_lanejit", (- _uJit), true];
								["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] RECOVERY_V2 reverse-pulse + lane-flip (newLane=%3, map=%4).", _uSide, _uTeam, (- _uJit), worldName]] Call WFBE_CO_FNC_AICOMLog; //--- cmdcon43-j: +map= for per-map ladder attribution (this tier-1 wedge recovery fires FAR more on steep Takistan).
							};
							_uLdr doMove (_uVeh modelToWorld [0,-14,0]); //--- short reverse-ish nudge.
							sleep 4;
						};
						//--- Tier 3: last-resort teleport-nudge to the nearest clear road node,
						//--- only if no player is close enough to witness it.
						//--- cmdcon41-w3e (e) WATER GUARD: fire the road-snap at ANY tier when the hull is water-stuck (_uForceRoad).
						//--- TELEPORT-GUARD FIX (2026-07-06): hoist the player-guard radius once per Spawn invocation so both snap
						//--- branches (vehicle + foot) read the SAME parameterised constant (WFBE_C_AICOM_RECOVERY_PLAYER_GUARD_R,
						//--- default 300). Guard matrix: player >= _uPGR -> snap allowed; player < _uPGR -> snap suppressed,
						//--- vehicle-branch uses hop fallback (velocity-Z bump, no teleport) to cover the full exclusion zone.
						//--- Foot-branch defers to doMove fallback (re-issues move order, no teleport). No dead zone. A2-OA-safe: missionNamespace getVariable.
						private "_uPGR";
						_uPGR = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_PLAYER_GUARD_R", 300];
						if ((_uTier >= 3 || {_recV2 && _uForceRoad}) && {!isNull _uVeh} && {alive _uVeh}) then {
							_uPlayerNear = false;
							{ if (isPlayer _x && {(_x distance _uVeh) < _uPGR}) then {_uPlayerNear = true} } forEach playableUnits;
							if (!_uPlayerNear) then {
								_uRds = (getPos _uVeh) nearRoads 150;
								if (count _uRds > 0) then {
									_uNode = [getPos _uVeh, _uRds] Call WFBE_CO_FNC_GetClosestEntity;
									if (!isNull _uNode && {!surfaceIsWater (getPos _uNode)}) then {
										_uVeh setVelocity [0,0,0];
										_uVeh setPos (getPos _uNode);
										if (_uFlush) then {
											_uFlushOrder = _uTeam getVariable "wfbe_aicom_order";
											if (!isNil "_uFlushOrder" && {count _uFlushOrder >= 3}) then {
												_uFlushSeq = _uFlushOrder select 0;
												_uFlushMode = _uFlushOrder select 1;
												_uFlushDest = _uFlushOrder select 2;
												_uTeam setVariable ["wfbe_aicom_order", [_uFlushSeq + 1, _uFlushMode, _uFlushDest], true];
												diag_log ("AICOMSTAT|v2|EVENT|" + str _uSide + "|" + str (round (time / 60)) + "|TELEPORT_ORDER_FLUSH|team=" + (str _uTeam) + "|seq=" + str (_uFlushSeq + 1) + "|mode=" + str _uFlushMode + "|kind=vehicle");
											};
										};
										["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] TIER3 unstuck teleport-nudge to road node (map=%3).", _uSide, _uTeam, worldName]] Call WFBE_CO_FNC_AICOMLog; //--- cmdcon43-j: +map= for per-map ladder attribution.
									};
								} else {
									//--- NO-ROAD SHELF FALLBACK (cmdcon44i, gate WFBE_C_AICOM_RECOVERY_NOROAD_STEP default 1, same wedge-escape as the foot branch below): a
									//--- MOUNTED hull wedged on a roadless shelf gets NO road snap either (nearRoads empty). Step the HULL toward the order dest onto the
									//--- nearest isFlatEmpty non-water spot - the flat-empty gate rejects steep/occupied ground so a hull is only moved to a drivable pad
									//--- (never dropped onto a slope to flip); if no flat pad exists it does nothing (no worse than today). A2-OA-safe: atan2 delta bearing,
									//--- isFlatEmpty/surfaceIsWater/setPos, group order read via getVariable+isNil (groups reject [name,default]). Flag 0 = inert.
									if ((missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOROAD_STEP", 1]) > 0) then {
										private ["_nvOrder","_nvDest","_nvBrg","_nvStep","_nvGuess","_nvFlat","_nvPos","_nvVp"];
										_nvOrder = _uTeam getVariable "wfbe_aicom_order";
										_nvDest  = objNull;
										if (!isNil "_nvOrder" && {count _nvOrder >= 3}) then {_nvDest = _nvOrder select 2};
										if (!isNil "_nvDest" && {typeName _nvDest == "ARRAY"} && {count _nvDest >= 2}) then {
											_nvVp   = getPosATL _uVeh;
											_nvBrg  = ((_nvDest select 0) - (_nvVp select 0)) atan2 ((_nvDest select 1) - (_nvVp select 1));
											_nvStep = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST", 90];
											if (_nvStep > ((_uVeh distance _nvDest) - 15)) then {_nvStep = ((_uVeh distance _nvDest) - 15) max 0};
											if (_nvStep > 5) then {
												_nvGuess = [(_nvVp select 0) + _nvStep * (sin _nvBrg), (_nvVp select 1) + _nvStep * (cos _nvBrg), 0];
												//--- Wider flat-empty footprint for a hull (12m) so we only relocate onto genuinely drivable ground.
												_nvFlat = _nvGuess isFlatEmpty [12, 0, 2, 14, 0, false, objNull];
												if (count _nvFlat > 0 && {!surfaceIsWater _nvFlat}) then {
													_nvPos = _nvFlat;
													_uVeh setVelocity [0,0,0];
													_uVeh setPos _nvPos;
													missionNamespace setVariable ["wfbe_waspscale_recov", (missionNamespace getVariable ["wfbe_waspscale_recov", 0]) + 1];
													diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|STUCK_NOROAD_STEP|team=" + (str _uTeam) + "|tier=" + str _uTier + "|map=" + worldName + "|step=" + str (round _nvStep) + "|veh=1");
													["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] TIER3 NO-ROAD hull step %3m toward objective (map=%4).", _uSide, _uTeam, round _nvStep, worldName]] Call WFBE_CO_FNC_AICOMLog;
												};
											};
										};
									};
								};
							};
						};
						//--- B (Ray 2026-06-29 A/B, guard widened 2026-07-06): a player within _uPGR (same snap-exclusion zone) blocks the teleport-snap; un-wedge the lead hull with a small upward velocity hop instead - it breaks terrain friction and visibly bumps the hull free (never-frozen guardrail). Result matrix: player < _uPGR -> hop; player >= _uPGR -> snap; no gap. The fresh MOVE route below re-applies the order.
						if (_uTier >= 3 && {!isNull _uVeh} && {alive _uVeh}) then { private "_bNear"; _bNear = false; { if (isPlayer _x && {(_x distance _uVeh) < _uPGR}) then {_bNear = true} } forEach playableUnits; if (_bNear) then { _uVeh setVelocity [(velocity _uVeh) select 0, (velocity _uVeh) select 1, 4] } };
						//--- WAVE-1 CAUSE-1 FOOT/DEAD-HULL UNSTUCK (2026-06-19): the vehicle Tier-3 above gates on
						//--- !isNull _uVeh && alive _uVeh, so a wedged FOOT team (leader on foot) or a team whose hull
						//--- is null/dead/immobile NEVER recovers (live: distStart=0, strikes climbed to ~43). Add a
						//--- foot/dead-hull last-resort: if the leader is on foot (vehicle == leader) OR the hull is
						//--- null / cannot move, teleport the LEADER to the nearest clear non-water road node within ~150m
						//--- and re-form the squad on him. SAME guardrail as the vehicle branch: only when NO player is
						//--- within 300m (MEMORY: never a player-visible teleport / frozen AI). The fresh road route below
						//--- (laid after this Spawn) still hands the team a live MOVE order, so it is never left idle.
						_uHullDead = isNull _uVeh || {!alive _uVeh} || {!(canMove _uVeh)};
						_uOnFoot   = (vehicle _uLdr) == _uLdr;
						//--- cmdcon41-w3e (e) WATER GUARD: fire the foot road-snap at ANY tier when water-stuck (_uForceRoad).
						if ((_uTier >= 3 || {_recV2 && _uForceRoad}) && {_uOnFoot || _uHullDead || {_recV2 && _uForceRoad}}) then {
							_uFootPlayerNear = false;
							{ if (isPlayer _x && {(_x distance _uLdr) < _uPGR}) then {_uFootPlayerNear = true} } forEach playableUnits;
							if (!_uFootPlayerNear) then {
								//--- cmdcon41-w3e (d) SLOPE-AWARE FOOT SNAP: a foot team grinding a steep Takistan slope (surfaceNormal
								//--- z below WFBE_C_AICOM_RECOVERY_SLOPE_Z, default 0.85) is exactly the hill-grind case - widen the road
								//--- search radius to WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R (default 200m) so it snaps onto the nearest road
								//--- and stops grinding, instead of the default 150m ring that often misses a mountain track. Flat foot
								//--- teams (and flag off) keep the proven 150m radius. A2-OA-safe: surfaceNormal / nearRoads.
								private ["_uFootR","_uSlopeZ"];
								_uFootR = 150;
								if (_recV2) then {
									_uSlopeZ = (surfaceNormal (getPos _uLdr)) select 2;
									if ((_uSlopeZ < (missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_SLOPE_Z", 0.85])) || _uForceRoad) then {_uFootR = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R", 200]};
								};
								_uFootRds = (getPos _uLdr) nearRoads _uFootR;
								if (count _uFootRds > 0) then {
									_uFootNode = [getPos _uLdr, _uFootRds] Call WFBE_CO_FNC_GetClosestEntity;
									if (!isNull _uFootNode && {!surfaceIsWater (getPos _uFootNode)}) then {
										_uLdr setVelocity [0,0,0];
										_uLdr setPos (getPos _uFootNode);
										if (_uFlush) then {
											_uFlushOrder = _uTeam getVariable "wfbe_aicom_order";
											if (!isNil "_uFlushOrder" && {count _uFlushOrder >= 3}) then {
												_uFlushSeq = _uFlushOrder select 0;
												_uFlushMode = _uFlushOrder select 1;
												_uFlushDest = _uFlushOrder select 2;
												_uTeam setVariable ["wfbe_aicom_order", [_uFlushSeq + 1, _uFlushMode, _uFlushDest], true];
												diag_log ("AICOMSTAT|v2|EVENT|" + str _uSide + "|" + str (round (time / 60)) + "|TELEPORT_ORDER_FLUSH|team=" + (str _uTeam) + "|seq=" + str (_uFlushSeq + 1) + "|mode=" + str _uFlushMode + "|kind=foot");
											};
										};
										//--- Re-form the squad on the relocated leader so dismounts/stragglers regroup (never idle).
										{ if (alive _x && {_x != _uLdr} && {vehicle _x == _x}) then {_x doFollow _uLdr} } forEach (units _uTeam);
										["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] TIER3 FOOT/dead-hull unstuck teleport-nudge to road node (re-formed on leader) (map=%3).", _uSide, _uTeam, worldName]] Call WFBE_CO_FNC_AICOMLog; //--- cmdcon43-j: +map= for per-map ladder attribution.
									};
								} else {
									//--- NO-ROAD SHELF FALLBACK (cmdcon44i, claude-gaming 2026-07-04, gate WFBE_C_AICOM_RECOVERY_NOROAD_STEP default 1): the road-snap above does
									//--- NOTHING when nearRoads finds no road inside the ring - exactly the roadless mountain-shelf founding case (live cmdcon44i Zargabad:
									//--- EAST foot teams O 1-1-E/O 1-1-G founded on the SE spawn shelf, frozen at dist=1771m for ~24min, tiers 1-4 cycled with ZERO effect
									//--- because NO TIER3 teleport line ever emitted - _uFootRds was empty). When no road exists, STEP the leader a fixed
									//--- WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST (default 90m) toward the ORDER DESTINATION (bearing leader->dest) onto the nearest flat-empty
									//--- non-water ground there, so the shelf team is bumped OFF the shelf toward its objective instead of pinned forever. This is the wedge
									//--- escape the capture-lock TTL was meant to be, for a FOOT team that never even reaches the arrival gate. Same player-guard (checked
									//--- above at _uFootPlayerNear), same squad re-form. A2-OA-safe: getVariable+isNil order read (groups reject [name,default]), atan2
									//--- position-delta bearing (binary getDir is A3-only), isFlatEmpty / surfaceIsWater / setPos. Flag 0 = inert (byte-identical to HEAD).
									if ((missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOROAD_STEP", 1]) > 0) then {
										private ["_nrOrder","_nrDest","_nrBrg","_nrStep","_nrGuess","_nrFlat","_nrPos","_nrLp"];
										_nrOrder = _uTeam getVariable "wfbe_aicom_order";
										_nrDest  = objNull;
										if (!isNil "_nrOrder" && {count _nrOrder >= 3}) then {_nrDest = _nrOrder select 2};
										if (!isNil "_nrDest" && {typeName _nrDest == "ARRAY"} && {count _nrDest >= 2}) then {
											_nrLp   = getPosATL _uLdr;
											_nrBrg  = ((_nrDest select 0) - (_nrLp select 0)) atan2 ((_nrDest select 1) - (_nrLp select 1)); //--- A2-safe bearing leader->dest.
											_nrStep = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST", 90];
											//--- Clamp so a near-target step never overshoots past the dest.
											if (_nrStep > ((_uLdr distance _nrDest) - 10)) then {_nrStep = ((_uLdr distance _nrDest) - 10) max 0};
											if (_nrStep > 5) then {
												_nrGuess = [(_nrLp select 0) + _nrStep * (sin _nrBrg), (_nrLp select 1) + _nrStep * (cos _nrBrg), 0];
												//--- Snap to a nearby flat-empty spot so the squad is not dropped inside a rock/wall; fall back to the raw guess.
												_nrFlat = _nrGuess isFlatEmpty [8, 0, 3, 10, 0, false, objNull];
												_nrPos  = if (count _nrFlat > 0) then {_nrFlat} else {_nrGuess};
												if (!surfaceIsWater _nrPos) then {
													_uLdr setVelocity [0,0,0];
													_uLdr setPos _nrPos;
													{ if (alive _x && {_x != _uLdr} && {vehicle _x == _x}) then {_x doFollow _uLdr} } forEach (units _uTeam);
													missionNamespace setVariable ["wfbe_waspscale_recov", (missionNamespace getVariable ["wfbe_waspscale_recov", 0]) + 1];
													diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|STUCK_NOROAD_STEP|team=" + (str _uTeam) + "|tier=" + str _uTier + "|map=" + worldName + "|step=" + str (round _nrStep));
													["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] TIER3 NO-ROAD shelf step %3m toward objective (re-formed on leader) (map=%4).", _uSide, _uTeam, round _nrStep, worldName]] Call WFBE_CO_FNC_AICOMLog;
												};
											};
										};
									};
								};
							};
						} else {
							//--- Foot snap deferred: player within _uPGR guard radius; re-issue move order (non-teleport fallback, retried next unstuck cycle).
							_uLdr doMove _dest;
						};
					};
				};

				//--- cmdcon41-w3j FIXED-WING TRANSIT (Ray aircraft lane, gate WFBE_C_AICOM_PLANE_FLYHEIGHT via the ALT const below):
				//--- a pure fixed-wing team (_isPlaneTeam, flagged at founding) is skipped by BOTH the air-insert block (planes
				//--- carry no troops so never become _airVeh) and the ground road-march below (`_rmHasVeh` excludes isKindOf "Air"),
				//--- so today a jet team falls straight through to the foot `else` (a ground MOVE) and then to the arrival GROUND SAD
				//--- - it never gets a cruise altitude and tries to prosecute the town at engine-default height, weaving/porpoising
				//--- into terrain. Give it real air discipline instead: set a cruise flyInHeight on every live plane hull, then lay a
				//--- SINGLE large-completion-radius MOVE over _dest (NOT a ground SAD) so the jet flies TO the objective at altitude;
				//--- the arrival latch (plane guard, below) then keeps it orbit-attacking rather than diving to land on the town.
				//--- Mirrors the working W22 Top-Gun loiter pattern (AI_Commander_Wildcard.sqf) which flies a plane cleanly at height.
				//--- HONEST A2-1.64 caveat: flyInHeight reliably STEERS helicopters; for PLANES the height command is weak on 1.64
				//--- (full plane support is 1.80) - so the big win here is "fly a wide MOVE at altitude + never a ground SAD/foot MOVE",
				//--- with flyInHeight as a best-effort floor. A2-OA-safe: flyInHeight/doMove + a plain WaypointsAdd MOVE, no A3 commands.
				if (_isPlaneTeam) then {
					private ["_plAlt","_plLoiterCR","_plHulls"];
					//--- MAP-AWARE cruise floor (doc rec #3): planes are NOT in the heli terrain-guard's Helicopter filter, so unlike
					//--- helis they get no reactive climb - give them a higher static floor on the STEEP maps (Takistan/Zargabad
					//--- ridgelines) than on gentle Chernarus. WFBE_C_AICOM_PLANE_FLYHEIGHT, if EXPLICITLY set (>0), overrides the map
					//--- floor; the default (0/absent) resolves per worldName (same worldName-branch idiom the fly-off box-size uses).
					//--- Jets orbit-ATTACK at height (not skim), so a generous 400 gentle / 500 steep. A2-OA-safe: switch toLower worldName.
					_plAlt = missionNamespace getVariable ["WFBE_C_AICOM_PLANE_FLYHEIGHT", 0];
					if (_plAlt <= 0) then {
						_plAlt = switch (toLower worldName) do {
							case "takistan": {500};
							case "zargabad": {500};
							case "chernarus": {400};
							default {400};
						};
					};
					_plLoiterCR = missionNamespace getVariable ["WFBE_C_AICOM_PLANE_LOITER_RADIUS", 600]; //--- large MOVE completion radius: keep bank shallow over the target (tight loiter over terrain = bank-into-hill crash, Part B/§3-iii).
					_plHulls = 0;
					{
						if (!isNull _x && {alive _x} && {_x isKindOf "Plane"}) then {
							_x flyInHeight _plAlt;                 //--- best-effort cruise floor (weak for planes on 1.64, but correct direction).
							if (!isNull (driver _x) && {!isPlayer (driver _x)}) then {(driver _x) doMove _dest}; //--- concurrent per-hull doMove so a multi-plane team all head for the objective now.
							_plHulls = _plHulls + 1;
						};
					} forEach _vehicles;
					//--- Team-level MOVE over the objective with a GENEROUS completion radius (not a tight SAD): the jet approaches
					//--- at altitude and the wide radius lets it wheel over the target instead of braking/circling a tight point.
					_team setBehaviour "AWARE"; _team setCombatMode "RED"; _team setSpeedMode "FULL"; //--- fast, will-engage air posture (COLUMN/formation irrelevant for a lone/paired jet).
					[_team, true, [[_dest, 'MOVE', 40, _plLoiterCR, [], [], ["AWARE","RED","","FULL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 %4 FIXED-WING transit (alt %5m, loiter r %6m, %7 plane hull(s)).", _side, _team, _seq, _mode, _plAlt, _plLoiterCR, _plHulls]] Call WFBE_CO_FNC_AICOMLog;
				} else {

				//--- ===================================================================
				//--- cmdcon42-f AIR-MOBILE ORDERS (Ray 2026-07-02, gate WFBE_C_AICOM_AIRMOBILE default-ON):
				//--- if this team STILL HAS its own live transport helicopter (alive, driver alive, has fuel -
				//--- AUTOFUEL keeps it fed) and the ordered destination is beyond WFBE_C_AICOM_AIRMOBILE_MIN_DIST,
				//--- FLY the leg (WFBE_CO_FNC_AICOMAirLeg) instead of road-marching. The helper mounts the pax,
				//--- flies at altitude, and at the destination runs the SAME hot-LZ decision the founding insert
				//--- uses (cold -> land+GET OUT; contested/enemy town -> paradrop OFFSET m short), then RETURNS the
				//--- transport to base + HOLDS it for the next order (persists - it IS the team's vehicle; no
				//--- fly-off/refund here). The dropped pax get an unconditional ground doMove to _dest, so the
				//--- arrival latch + MOVE/SAD capture chain fold them in exactly like a road-marched team (Hook-B
				//--- sees a normal arrival). GUARDS: transport-LESS remnants (no heli / dead heli) fall through to
				//--- the unchanged road-march below; the helper stamps wfbe_aicom_airborne_until so the AssignTowns
				//--- stuck-watcher never teleports a flying leader; a mid-flight order change continues to the drop
				//--- then re-evaluates next seq (no mid-air re-vector). NEVER-FROZEN: on any early-out (no heli /
				//--- nobody to lift) the helper returns false and we road-march as today. A2-OA-safe: transportSoldier
				//--- config read + isKindOf "Air" + fuel, all mirrored from the founding air-insert split.
				private ["_amDone","_amHeli"];
				_amDone = false;
				if ((missionNamespace getVariable ["WFBE_C_AICOM_AIRMOBILE", 1]) > 0 && {(leader _team) distance _dest > (missionNamespace getVariable ["WFBE_C_AICOM_AIRMOBILE_MIN_DIST", 1200])}) then {
					_amHeli = objNull;
					{
						if (!isNull _x && {alive _x} && {_x isKindOf "Air"} && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "transportSoldier")) > 0} && {isNull _amHeli} && {!isNull (driver _x)} && {alive (driver _x)} && {canMove _x} && {(fuel _x) > 0}) then {_amHeli = _x};
					} forEach _vehicles;
					if (!isNull _amHeli) then {
						//--- Fly this leg. The helper Spawns its own non-blocking flight + return-to-base; it returns
						//--- true when it committed the leg (pax lifted). Only then do we SKIP the road-march.
						//--- cmdcon42-l: pass the team's authoritative _vehicles list so the helper can pick a LIGHT
						//--- ground vehicle to SLING + deep-drop behind the lines (WFBE_C_AICOM_VEHLIFT).
						if ([_amHeli, _team, _dest, _side, _sideID, _vehicles] Call WFBE_CO_FNC_AICOMAirLeg) then {_amDone = true};
					};
				};
				if (!_amDone) then {

				//--- ROAD-MARCH (task #14/#16): the old single bare 'MOVE' to the raw town
				//--- center used EMPTY squad-props, so the engine defaulted armour/trucks to
				//--- AWARE->COMBAT/WEDGE cross-country - A2 PFM's worst case (distStart=0 at
				//--- base). Now: if this team has any ground VEHICLE, lay a ROAD-NODE chain
				//--- (broadcast in wfbe_aicom_route by AssignTowns) with COLUMN/NORMAL props
				//--- and forceFollowRoad on each vehicle, so the convoy takes lanes the engine
				//--- can drive; a final MOVE near the objective hands off to the arrival branch
				//--- which flips to COMBAT/WEDGE SAD. Pure-infantry teams keep the simple MOVE.
				_rmHasVeh = false;
				{ if (!isNull _x && {alive _x} && {!(_x isKindOf "Air")} && {canMove _x}) then {_rmHasVeh = true} } forEach _vehicles;

				if (_rmHasVeh && {(leader _team) distance _dest > 700}) then {
					//--- B755 (Ray 2026-06-25) RE-MOUNT FOR THE LONG LEG: a team re-tasked to a far town after a prior capture has its
					//--- infantry ON FOOT (the keystone capture dismount at the towns-target arrival unassigned them) - without this they
					//--- FOOT-MARCH a leg the hulls should DRIVE, splitting the team. Re-seat on-foot non-crew infantry into drivable (armed,
					//--- if ARMED_TRANSPORT_ONLY) hulls with free cargo, mirroring the once-only ground mount-up below. No-op on the first
					//--- march (already mounted). A2-OA-safe + NON-FROZEN: assignAsCargo/orderGetIn are instant; overflow/foot still road-march.
					private "_rmAssigned"; _rmAssigned = 0; if ((missionNamespace getVariable ["WFBE_C_AICOM_REMOUNT_LONG_LEG", 1]) > 0) then {
						private ["_rmRiders","_rmIdx","_rmN","_rmSeat","_rmRider"];
						_rmRiders = [];
						{ if (alive _x && {vehicle _x == _x}) then {_rmRiders = _rmRiders + [_x]} } forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
						_rmN = count _rmRiders; _rmIdx = 0; private ["_rmTot","_rmSeatOK"]; _rmTot = 0; { if (!isNull _x && {alive _x} && {!(_x isKindOf "Air")} && {canMove _x} && {((missionNamespace getVariable ["WFBE_C_AICOM_ARMED_TRANSPORT_ONLY", 1]) <= 0) || {(count (weapons _x)) > 0}}) then {_rmTot = _rmTot + (_x emptyPositions "cargo")} } forEach _vehicles; _rmSeatOK = (_rmTot >= (_rmN * (missionNamespace getVariable ["WFBE_C_AICOM_MOUNT_MIN_SEAT_FRAC", 0.8]))); //--- B756 (Ray 2026-06-26): re-mount seat-capacity gate (don't re-seat into a partial mount that re-splits the team).
						{
							if (!isNull _x && {alive _x} && {!(_x isKindOf "Air")} && {canMove _x} && {(_x emptyPositions "cargo") > 0} && {((missionNamespace getVariable ["WFBE_C_AICOM_ARMED_TRANSPORT_ONLY", 1]) <= 0) || {(count (weapons _x)) > 0}}) then {
								_rmSeat = _x emptyPositions "cargo";
								while {_rmSeat > 0 && {_rmIdx < _rmN}} do {
									_rmRider = _rmRiders select _rmIdx; _rmIdx = _rmIdx + 1;
									if (_rmSeatOK && {alive _rmRider} && {vehicle _rmRider == _rmRider}) then {_rmRider assignAsCargo _x; [_rmRider] orderGetIn true; _rmSeat = _rmSeat - 1; _rmAssigned = _rmAssigned + 1};
								};
							};
						} forEach _vehicles;
					};
					if (_rmAssigned > 0) then {diag_log ("AICOMSTAT|v1|EVENT|" + str (side _team) + "|" + str (round (time / 60)) + "|REMOUNT|seated=" + str _rmAssigned + "|leg=" + str (round ((leader _team) distance _dest)))}; //--- B756 (Ray 2026-06-26): REMOUNT telemetry - prove the long-leg re-seat fires + how many dismounted infantry it re-mounts before the far road-march.
					//--- Road convoy: AWARE+COLUMN road-march posture for the long leg. A2-fix (2026-06-14):
					//--- the A3-only forceFollowRoad was removed (it throws "Unknown operation" on OA); the
					//--- road-bias comes from the road-SNAPPED MOVE nodes below + COLUMN formation (the same
					//--- A2 idiom Server_AI_SetTownAttackPath uses).
					//--- cmdcon41-w2 F1 YELLOW MARCH (Ray-approved, gate WFBE_C_AICOM_MARCH_YELLOW default 1): in transit,
					//--- use YELLOW (return fire, don't pursue) so a column rolls past insurgent pot-shots instead of
					//--- dissolving into a firefight. The FINAL MOVE node on _dest, the arrival SAD, capture, and base-
					//--- assault fire ALL stay COMBAT/RED (re-asserted at the arrival latch). Flag off (0) = RED everywhere
					//--- (legacy). A2-OA-safe: inline missionNamespace getVariable + if/else on a scalar (>0), no A3 cmds.
					private "_marchCM"; _marchCM = if ((missionNamespace getVariable ["WFBE_C_AICOM_MARCH_YELLOW", 1]) > 0) then {"YELLOW"} else {"RED"};
					_team setBehaviour "AWARE";
					_team setCombatMode _marchCM;      //--- cmdcon41-w2 F1: YELLOW transit when flagged (was hard RED); RED-on-objective re-asserted at arrival.
					_team setFormation "COLUMN";
					_team setSpeedMode "FULL";         //--- STANCE (task #1): full road-march speed (was NORMAL).

					//--- Pull the road-node chain the server snapped for this seq (may be empty).
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_rmRoute = _team getVariable "wfbe_aicom_route";
					if (isNil "_rmRoute") then {_rmRoute = []};

					//--- Build the waypoint list: each road node as a COLUMN/NORMAL MOVE, then a
					//--- final MOVE on the destination so the arrival branch (leader<200m) trips.
					_rmWPs = [];
					private "_rmInterCR"; _rmInterCR = missionNamespace getVariable ["WFBE_C_AICOM_ROUTE_COMPLETION", 70]; //--- SMOOTHNESS (B): intermediate road-node completionRadius widened 30 -> WFBE_C_AICOM_ROUTE_COMPLETION (70) so the convoy latches each node from further out and stops braking/backtracking to hit a tight 30m ring; the FINAL _dest node below stays tight (30) so the arrival branch still trips.
					{
						_rmWPs = _rmWPs + [[_x, 'MOVE', 40, _rmInterCR, [], [], ["AWARE",_marchCM,"","FULL"]]];  //--- cmdcon41-w2 F1: intermediate road-node transit uses _marchCM (YELLOW when flagged, else RED). STANCE (task #1): FULL advance (was YELLOW/NORMAL). A2-fix 2026-06-14: inherit-formation (was COLUMN-locked). SMOOTHNESS (B): completion 30 -> _rmInterCR (WFBE_C_AICOM_ROUTE_COMPLETION 70) so columns open through chokepoints instead of bunching + braking to hit each node.
					} forEach _rmRoute;
					_rmWPs = _rmWPs + [[_dest, 'MOVE', 50, 30, [], [], ["AWARE","RED","COLUMN","FULL"]]];  //--- cmdcon41-w2 F1: FINAL MOVE node on _dest STAYS RED (advance-and-engage on the objective, unaffected by the march flag). STANCE (task #1): RED/FULL final-approach (was YELLOW/NORMAL). FINAL node kept tight (30) so the arrival branch (leader<capRange) still latches.
					[_team, true, _rmWPs] Spawn WFBE_CO_FNC_WaypointsAdd;
					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 %4 ROAD-MARCH (%5 road nodes).", _side, _team, _seq, _mode, count _rmRoute]] Call WFBE_CO_FNC_AICOMLog;
				} else {
					//--- Short leg or pure infantry: direct cross-country MOVE (A2 PFM handles
					//--- short overland fine, and foot squads should not be road-locked).
					//--- (A2-fix: removed the A3-only forceFollowRoad clear; short legs were never road-locked.)
					//--- B66 FAST-TRANSIT FOOT LEG: the old bare WaypointSimple shipped an EMPTY 7th props
					//--- element, so the engine left a pure-infantry squad at its founding posture and it
					//--- dawdled (AWARE/NORMAL, sometimes LIMITED) across the leg. Mirror the vehicle road-march
					//--- final waypoint (~L549) with explicit [AWARE,RED,COLUMN,FULL] so foot squads transit FAST
					//--- in column. The arrival branch (~L595-611) already re-lays a COMBAT/WEDGE SAD, so they
					//--- still fight on arrival (never-frozen-AI safe - the squad always holds a live MOVE order).
					//--- SMOOTHNESS (A) FOOT ROAD-ROUTE: for a LONG pure-infantry leg (> WFBE_C_AICOM_FOOT_ROUTE_DIST,
					//--- default 700m) with a server-snapped road chain, walk the SAME road-node chain the vehicle
					//--- road-march uses (wfbe_aicom_route) instead of a single cross-country beeline. Foot squads then
					//--- follow lanes/valleys the engine can path smoothly rather than grinding straight over ridges,
					//--- and each intermediate node latches from WFBE_C_AICOM_ROUTE_COMPLETION (70m) out so the column
					//--- flows instead of braking to hit a tight ring. A FINAL tight (30m) MOVE on _dest still trips the
					//--- arrival branch. Short legs (< dist) OR an empty route keep the proven single fast-transit MOVE.
					//--- A2-OA-safe: getVariable + isNil guard on the GROUP route var (no [name,default] on groups),
					//--- plain forEach node build, exact vehicle-branch WaypointsAdd signature ([_team,true,_rmWPs] Spawn).
					//--- NEVER-FROZEN: either path hands the team a live MOVE chain; the arrival branch re-lays COMBAT/WEDGE SAD.
					//--- cmdcon41-w2 F1 YELLOW MARCH (foot branch): recompute _marchCM here (the vehicle-branch _marchCM
					//--- is out of scope). Intermediate foot road nodes + the short fast-transit MOVE use _marchCM (YELLOW
					//--- when flagged, else RED); the FINAL tight MOVE on _dest STAYS RED. Flag off = RED everywhere (legacy).
					private "_marchCM"; _marchCM = if ((missionNamespace getVariable ["WFBE_C_AICOM_MARCH_YELLOW", 1]) > 0) then {"YELLOW"} else {"RED"};
					_rmRoute = _team getVariable "wfbe_aicom_route";
					if (isNil "_rmRoute") then {_rmRoute = []};
					if (((leader _team) distance _dest > (missionNamespace getVariable ["WFBE_C_AICOM_FOOT_ROUTE_DIST", 700])) && {count _rmRoute > 0}) then {
						//--- Long foot leg WITH a road chain: build node-by-node MOVE waypoints (fast column), wide
						//--- intermediate completion so the squad flows, then a tight final MOVE on the destination.
						private "_rmFootCR"; _rmFootCR = missionNamespace getVariable ["WFBE_C_AICOM_ROUTE_COMPLETION", 70];
						_rmWPs = [];
						{
							_rmWPs = _rmWPs + [[_x, 'MOVE', 50, _rmFootCR, [], [], ["AWARE",_marchCM,"COLUMN","FULL"]]]; //--- cmdcon41-w2 F1: foot road node uses _marchCM (YELLOW when flagged, else RED). FULL column transit, wide latch (WFBE_C_AICOM_ROUTE_COMPLETION 70).
						} forEach _rmRoute;
						_rmWPs = _rmWPs + [[_dest, 'MOVE', 50, 30, [], [], ["AWARE","RED","COLUMN","FULL"]]]; //--- cmdcon41-w2 F1: FINAL node on _dest STAYS RED. Kept tight (30) so the arrival branch latches.
						[_team, true, _rmWPs] Spawn WFBE_CO_FNC_WaypointsAdd; //--- exact vehicle-branch signature.
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 %4 FOOT ROAD-ROUTE (%5 road nodes, long leg).", _side, _team, _seq, _mode, count _rmRoute]] Call WFBE_CO_FNC_AICOMLog;
					} else {
						//--- Short leg OR no road chain: proven single fast-transit MOVE. cmdcon41-w2 F1: the single transit
						//--- node uses _marchCM (YELLOW when flagged, else RED) - it IS the whole transit for this short leg,
						//--- and the arrival latch re-asserts RED on the objective. Flag off = RED (legacy behaviour).
						[_team, true, [[_dest, 'MOVE', 50, 30, [], [], ["AWARE",_marchCM,"COLUMN","FULL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd; //--- B66 (was [_team,_dest,'MOVE',50] Spawn WFBE_CO_FNC_WaypointSimple - empty props)
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 %4 FOOT FAST-TRANSIT (column).", _side, _team, _seq, _mode]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
				}; //--- cmdcon42-f: close the `if (!_amDone) {ground road-march/foot}` guard - when the air-mobile leg committed (_amDone), the road-march is SKIPPED (the helper handed the team its live flight + drop + pax moves).
				}; //--- cmdcon41-w3j: close the `if (_isPlaneTeam) {air transit} else {ground road-march/foot}` split opened just above the road-march block.
				//--- cmdcon41-w2 RALLY MODE EXECUTOR (sketch rally-mode-bounding-withdrawal-executor): the transit lay
				//--- above already drove a FAST bounding-withdrawal MOVE to _dest for EVERY mode (it fires regardless of
				//--- the mode string) = exactly the fall-back leg we want (returns fire + uses cover en route, never a
				//--- stand-and-die SAD). For a fresh order whose mode is the exact-case lowercase "rally", stamp a rally
				//--- flag so the arrival latch (below) re-tasks to "towns" instead of laying the assault SAD. A2-OA-safe:
				//--- exact-case == on a string literal, plain broadcast setVariable, no A3 commands.
				if (_mode == "rally") then {
					_team setVariable ["wfbe_aicom_rallying", true, true];
					diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|RALLY_FALLBACK|team=" + (str _team) + "|seq=" + str _seq + "|dist=" + str (round ((leader _team) distance _dest)));
					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 RALLY bounding-withdrawal to rally pos.", _side, _team, _seq]] Call WFBE_CO_FNC_AICOMLog;
				};

			} else {
				//--- CAREFUL-GEAR GOVERNOR (owner refinement, layered on the 20s loop):
				//--- the road-march already drives transit FAST (AWARE/NORMAL, never LIMITED/
				//--- COMBAT), so the DEFAULT stays NORMAL. We only DOWNSHIFT to LIMITED while
				//--- EITHER (a) the lead hull sits on a steep slope (engine grade-crawl zone, a
				//--- careful gear keeps it from sliding/grinding) OR (b) a stuck-strike is active
				//--- (wfbe_aicom_unstuck > 0). Snap back to NORMAL the instant both clear. The
				//--- strike side auto-reverts because AssignTowns resets the strike to 0 on
				//--- progress; the slope side reverts next tick once the hull is back on flat.
				//--- A2-safe: surfaceNormal + setSpeedMode "LIMITED"/"NORMAL" (same primitive
				//--- AI_TownPatrol.sqf uses). Orthogonal to waypoints - never re-lays the route,
				//--- formation, behaviour props, or the 3-tier unstuck. Hysteresis flag fires
				//--- setSpeedMode exactly once per state transition, not every tick.
				//--- MEMORY guardrail: LIMITED still MOVES - never a freeze / standing-still AI.
				_govLdr = leader _team;
				if (!isNull _govLdr && {alive _govLdr}) then {
					//--- Sample the VEHICLE pos (the hull is what climbs); leader rides the hull.
					_govNz   = (surfaceNormal (getPos (vehicle _govLdr))) select 2; //--- 1.0=flat, lower=steeper.
					_govSteep = _govNz < (missionNamespace getVariable ["WFBE_C_AICOM_SLOPE_Z", 0.93]);
					//--- SMOOTHNESS (C) GRADE DWELL/HYSTERESIS: the raw per-tick "steep" sample flickers as a
					//--- convoy crests small bumps, so one steep hull used to pulse the WHOLE team down to LIMITED
					//--- (jerky speed oscillation). Debounce the SLOPE side: the steep condition must PERSIST
					//--- continuously for > WFBE_C_AICOM_GRADE_DWELL (default 6s) before it downshifts to LIMITED,
					//--- and the hull must be FLAT for the same dwell before FULL is restored. The stuck STRIKE side
					//--- stays IMMEDIATE (recovery must not be delayed). setSpeedMode still fires once per state
					//--- transition (via _govIsSlow), never per-tick. Time stamped in a team var on the first-steep /
					//--- first-flat tick. A2-safe: plain time + getVariable+isNil on the GROUP (no [name,default]).
					private ["_govDwell","_govGradeStamp","_govGradeRaw","_govSteepDwelled"];
					_govDwell = missionNamespace getVariable ["WFBE_C_AICOM_GRADE_DWELL", 6];
					_govGradeStamp = _team getVariable "wfbe_aicom_grade_stamp"; //--- [rawSteepBool, timeStamped]
					if (isNil "_govGradeStamp" || {(typeName _govGradeStamp) != "ARRAY"} || {count _govGradeStamp < 2}) then {
						_govGradeStamp = [_govSteep, time];
						_team setVariable ["wfbe_aicom_grade_stamp", _govGradeStamp];
					};
					_govGradeRaw = _govGradeStamp select 0;
					if (if (_govGradeRaw) then {!_govSteep} else {_govSteep}) then {
						//--- raw slope state changed this tick: restart the dwell clock.
						_govGradeStamp = [_govSteep, time];
						_team setVariable ["wfbe_aicom_grade_stamp", _govGradeStamp];
					};
					//--- debounced steep = raw steep held past the dwell; else keep the last debounced state until
					//--- the opposite condition earns its own dwell (so we never flap mid-transition).
					_govSteepDwelled = _team getVariable "wfbe_aicom_grade_steep";
					if (isNil "_govSteepDwelled") then {_govSteepDwelled = false};
					if ((time - (_govGradeStamp select 1)) >= _govDwell) then {
						_govSteepDwelled = _govSteep; //--- current raw state has persisted long enough -> adopt it.
						_team setVariable ["wfbe_aicom_grade_steep", _govSteepDwelled];
					};
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_govStrk = _team getVariable "wfbe_aicom_unstuck";
					if (isNil "_govStrk") then {_govStrk = 0};
					//--- STRIKE stays immediate; SLOPE uses the debounced (dwelled) state.
					_govWantSlow = _govSteepDwelled || {_govStrk > 0};
					_govIsSlow = _team getVariable "wfbe_aicom_gearslow";
					if (isNil "_govIsSlow") then {_govIsSlow = false};
					if (_govWantSlow && {!_govIsSlow}) then {
						_team setSpeedMode "LIMITED";          //--- careful gear (A2-safe, still moving).
						_team setVariable ["wfbe_aicom_gearslow", true];
					};
					if (!_govWantSlow && {_govIsSlow}) then {
						_team setSpeedMode "FULL";             //--- STANCE (task #1): back to the fast default (was NORMAL).
						_team setVariable ["wfbe_aicom_gearslow", false];
					};
				};

				//--- On arrival, switch to the mode's local behaviour once.
				if (!_arrived) then {
					_arrivalGate = (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS", 250]) max (((missionNamespace getVariable ["WFBE_C_TOWNS_CAPTURE_RANGE", 40]) max (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_SAD", 80])) + 20); //--- WAVE-3 250m arrival-gate (fleet wln6wj9cn) kept through the #138 CAPTURE_TRACE locals restructure (the #138 hunk carried the stale 100m math).
					_arrivalDist = (leader _team) distance _dest;
					if (_arrivalDist < _arrivalGate) then {
						_arrived = true;
						diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|CAPTURE_TRACE|ARRIVAL_GATE|team=" + (str _team) + "|seq=" + str _seq + "|mode=" + str _mode + "|dist=" + str (round _arrivalDist) + "|gate=" + str (round _arrivalGate));
						//--- Cosmetic: faction smoke at assault onset (fires once per team via the _arrived latch). Server-only, gated + capped + cooldown.
						[getPosATL (leader _team), side _team] call WFBE_CO_FNC_SpawnFactionSmoke;
						//--- cmdcon41-w2 F1: RE-ASSERT team-level RED at the arrival latch. Transit may have run YELLOW
						//--- (WFBE_C_AICOM_MARCH_YELLOW), so on reaching the objective we flip the whole team back to advance-
						//--- and-engage before the arrival SAD / capture / base-assault fire (those all stay COMBAT/RED).
						//--- Harmless when the flag was off (team was already RED). A2-OA-safe: plain setCombatMode.
						_team setCombatMode "RED";
						//--- cmdcon41-w2 RALLY MODE EXECUTOR (arrival): read the rally flag stamped on the fresh order.
						//--- A2: groups do not support the [name,default] getVariable form; plain get + isNil.
						private "_rallying"; _rallying = _team getVariable "wfbe_aicom_rallying"; if (isNil "_rallying") then {_rallying = false};
						//--- ROAD-MARCH hand-off: at the objective we WANT overland combat, so
						//--- release the road bias and assault with COMBAT/WEDGE (was empty props,
						//--- which left the SAD at engine defaults). Feed real squad-props through
						//--- WaypointsAdd so behaviour/formation actually apply.
						//--- (A2-fix: removed the A3-only forceFollowRoad clear; COMBAT/WEDGE props set the assault posture.)
						_team setSpeedMode "NORMAL";
						//--- REMNANT STANCE DOWNSHIFT (cmdcon41): a badly-attrited squad should not
						//--- bull-rush COMBAT/RED into a dug-in objective and get finished off - it should
						//--- advance CAUTIOUSLY (AWARE/YELLOW: still MOVING, still returns fire, never
						//--- frozen). Gate on WFBE_C_AICOM_REMNANT_CAUTION and a remnant test: no founding-
						//--- size var exists on the team, so use the spec fallback of < 3 live units.
						//--- A2-OA-safe (== on numbers, if/else - no bool ==, no A3 commands). Props are the
						//--- ONLY thing tuned; the SAD radius/completion + never-idle order are unchanged.
						private ["_stB","_stC"];
						_stB = "COMBAT"; _stC = "RED";
						if ((missionNamespace getVariable ["WFBE_C_AICOM_REMNANT_CAUTION", 1]) > 0) then {
							if ((count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) < 3) then {
								_stB = "AWARE"; _stC = "YELLOW"; //--- remnant: cautious advance, still moving + returns fire (never frozen).
							};
						};
						if (_rallying) then {
							//--- cmdcon41-w2 RALLY MODE EXECUTOR (arrival): a rallying team reached the rally pos. Do NOT lay the
							//--- assault SAD - clear the rally flag and re-task to "towns" (broadcast, SAME idiom as the capture-
							//--- success release) so AssignTowns re-tasks it next cycle and it re-engages on proximity (never idles
							//--- at the rally point). Also clear the goto + stale strike/relief so AssignTowns owns it. A2-OA-safe:
							//--- broadcast setVariable (same locality as the capture-success writes below).
							_team setVariable ["wfbe_aicom_rallying", false, true];
							_team setVariable ["wfbe_teamgoto", objNull, true];        //--- drop the rally goto -> AssignTowns retargets next tick (isNull _goto => _needs=true)
							_team setVariable ["wfbe_aicom_townorder", [], false];     //--- 2-arg (NOT broadcast) to match existing townorder writes
							_team setVariable ["wfbe_teammode", "towns", true];        //--- re-enter the towns retarget gate (same idiom as the capture-success release)
							_team setVariable ["wfbe_aicom_strike", false, true];      //--- clear stale strike so Strategy.sqf does not re-grab
							_team setVariable ["wfbe_aicom_relief", objNull, true];
							_team setVariable ["wfbe_aicom_caplock", [], true];   //--- CAPTURE LOCK CLEAR (GR-2026-07-03a): no longer draining -> re-taskable now.
							diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|RALLY_ARRIVED|team=" + (str _team) + "|seq=" + str _seq + "|dist=" + str (round _arrivalDist));
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] RALLY_ARRIVED - re-tasking to towns (no assault SAD).", _side, _team]] Call WFBE_CO_FNC_AICOMLog;
						} else {
						//--- cmdcon41-w3 ASSAULT APPROACH SMOKE (gate WFBE_C_AICOM_SMOKE default 1): the moment the team latches
						//--- arrival on a towns-target (NON-rally) objective, before the assault SAD is laid, pop ONE covering
						//--- volley of 2 smoke shells ~45-60m AHEAD of the leader toward _dest so the final approach is screened.
						//--- HC-local, bounded (2 createVehicle, no loop/sleep), rate-limited to one smoke event per team per
						//--- WFBE_C_AICOM_SMOKE_COOLDOWN (120s) via the SAME group-var stamp the break-off smoke uses (get + isNil,
						//--- A2-safe - groups reject the [name,default] form). Bearing leader->_dest via the atan2 position-delta
						//--- idiom already used in this file. createVehicle [class,pos,[],0,'NONE'] is A2-OA-safe. Never-frozen:
						//--- purely cosmetic; the assault SAD below (unchanged) still hands the team a live order this same tick.
						if ((missionNamespace getVariable ["WFBE_C_AICOM_SMOKE", 1]) > 0) then {
							private ["_asLdr","_asLast","_asCool","_asOK"];
							_asLdr  = leader _team;
							_asCool = missionNamespace getVariable ["WFBE_C_AICOM_SMOKE_COOLDOWN", 120];
							_asLast = _team getVariable "wfbe_aicom_smoke_last";
							_asOK   = if (isNil "_asLast") then {true} else {(time - _asLast) >= _asCool};
							if (!isNull _asLdr && {alive _asLdr} && {_asOK}) then {
								private ["_asCls","_asBase","_asBrg","_asFwd","_asP0","_asP1"];
								//--- Faction-appropriate smoke (WEST white, EAST red, resistance green; A2-OA base classes).
								_asCls = switch (_side) do {
									case west: {"SmokeShell"};
									case east: {"SmokeShellRed"};
									default {"SmokeShellGreen"};
								};
								_asBase = getPosATL _asLdr;
								//--- Bearing leader -> _dest (A2-safe atan2 position-delta; binary getDir is A3-only). Guard a zero-length delta.
								_asBrg = getDir _asLdr;
								if ((_asLdr distance _dest) > 5) then {
									_asBrg = ((_dest select 0) - (_asBase select 0)) atan2 ((_dest select 1) - (_asBase select 1));
								};
								//--- One volley: two shells 45m and 60m ahead toward _dest (a screening pair on the approach line).
								_asFwd = 45;
								_asP0 = [(_asBase select 0) + _asFwd * (sin _asBrg), (_asBase select 1) + _asFwd * (cos _asBrg), 0];
								_asP1 = [(_asBase select 0) + (_asFwd + 15) * (sin _asBrg), (_asBase select 1) + (_asFwd + 15) * (cos _asBrg), 0];
								createVehicle [_asCls, _asP0, [], 0, "NONE"];
								createVehicle [_asCls, _asP1, [], 0, "NONE"];
								_team setVariable ["wfbe_aicom_smoke_last", time];
								diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|SMOKE|ASSAULT|team=" + (str _team) + "|cls=" + _asCls);
							};
						};
						//--- cmdcon41-w3j FIXED-WING ARRIVAL: a jet must NEVER get the ground WEDGE SAD here - a plane handed a
						//--- tight ground-attack SAD tries to fly an unflyable low pattern (weaves, stalls, or noses into the town).
						//--- Instead re-assert the altitude orbit-attack: a large-completion MOVE over _dest at the cruise floor, so
						//--- the jet keeps wheeling over the objective and strafing revealed targets (engine gun/rocket runs) rather
						//--- than trying to land on it. Re-issued whenever the arrival latch fires. HELIS are unaffected (they are
						//--- "Helicopter", never "Plane", and keep the proven WEDGE SAD + the gun-run nudge loop above).
						if (_isPlaneTeam) then {
							private ["_plAlt2","_plLoiterCR2"];
							_plAlt2 = missionNamespace getVariable ["WFBE_C_AICOM_PLANE_FLYHEIGHT", 0]; //--- cmdcon41-w3j: same map-aware floor as the transit block.
							if (_plAlt2 <= 0) then { _plAlt2 = switch (toLower worldName) do { case "takistan": {500}; case "zargabad": {500}; case "chernarus": {400}; default {400} } };
							_plLoiterCR2 = missionNamespace getVariable ["WFBE_C_AICOM_PLANE_LOITER_RADIUS", 600];
							{ if (!isNull _x && {alive _x} && {_x isKindOf "Plane"}) then {_x flyInHeight _plAlt2} } forEach _vehicles;
							[_team, true, [[_dest, 'MOVE', 40, _plLoiterCR2, [], [], ["AWARE","RED","","FULL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd; //--- orbit-attack loiter (NOT a ground SAD).
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] FIXED-WING arrival - orbit-attack loiter over objective (alt %3m, r %4m).", _side, _team, _plAlt2, _plLoiterCR2]] Call WFBE_CO_FNC_AICOMLog;
						} else {
						if (_mode == "defense") then {
							[_team, true, [[_dest, 'SAD', 100, 30, [], [], [_stB,_stC,"WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						} else {
							[_team, true, [[_dest, 'SAD', (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_SAD", 80]), 30, [], [], [_stB,_stC,"WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd; //--- punchy-AICOM (Ray 2026-06-17): 250 -> WFBE_C_AICOM_ASSAULT_SAD (80m). Tighter approach SAD = the squad closes onto the objective instead of roving a 250m ring. cmdcon41: props via _stB/_stC (remnant downshift above).
							//--- armor-screen: tanks screen OUTWARD while infantry/APCs hold the SAD.
							//--- Gate: WFBE_C_AICOM_ARMOR_SCREEN > 0. At flag 0 this block is inert;
							//--- the SAD above already covered ALL units and we do nothing extra.
							//--- A2-OA-safe: isKindOf "Tank" (confirmed codebase idiom); atan2 delta
							//--- bearing (same idiom as L1429 smoke block); vehicle driver doMove;
							//--- group vars via single-arg getVariable + isNil (groups reject 2-arg form);
							//--- missionNamespace 2-arg getVariable is fine. No pushBack/findIf/params/A3.
							if ((missionNamespace getVariable ["WFBE_C_AICOM_ARMOR_SCREEN", 0]) > 0) then {
								private ["_ascrR","_ascrBase","_ascrBrg","_ascrIdx"];
								_ascrR    = missionNamespace getVariable ["WFBE_C_AICOM_ARMOR_SCREEN_R", 80];
								//--- Bearing: team leader -> _dest (atan2 delta, same idiom as L1429).
								//--- Guard a zero-length delta so atan2 does not divide by zero.
								_ascrBase = getPos (leader _team);
								_ascrBrg  = getDir (leader _team);
								if (((leader _team) distance _dest) > 5) then {
									_ascrBrg = ((_dest select 0) - (_ascrBase select 0)) atan2 ((_dest select 1) - (_ascrBase select 1));
								};
								//--- Walk _vehicles; for each Tank hull issue a doMove to a staggered outward
								//--- screen pos. Infantry and light vehicles already have the SAD above.
								//--- "Outward" = heading away from _dest (opposite of the approach bearing), so
								//--- tanks fan out as a hull-down watch arc facing the enemy.
								//--- Stagger: index * 30 deg offset so two tanks do not converge on the same point.
								_ascrIdx = 0;
								{
									if (!isNull _x && {alive _x} && {_x isKindOf "Tank"}) then {
										//--- Screen heading: OPPOSITE of approach (face outward from objective).
										//--- Add +/-30 deg stagger per hull so a 2-tank section fans left/right.
										//--- A2: no selectRandom/apply; plain numeric index arithmetic is A2-safe.
										private ["_ascrOffset","_ascrHdg","_ascrP"];
										_ascrOffset = (_ascrIdx mod 2) * 60 - 30; //--- hull 0 -> -30 deg, hull 1 -> +30 deg, repeats.
										_ascrHdg    = (_ascrBrg + 180 + _ascrOffset) mod 360;
										_ascrP      = [(_dest select 0) + _ascrR * (sin _ascrHdg), (_dest select 1) + _ascrR * (cos _ascrHdg), 0];
										//--- Order the DRIVER (not the hull) to the screen pos.
										//--- _x IS already a vehicle; vehicle _x == _x always, so the old
										//--- "_ascrVeh != _x" guard was dead code and the driver branch
										//--- never ran. Fix (review defect): guard driver directly, skip
										//--- driverless/dead-driver tanks entirely (no doMove, no counter).
										//--- Idiom matches L475 and L1120 (driver _x for vehicle objects).
										if (!isNull (driver _x) && {alive (driver _x)}) then {
											(driver _x) doMove _ascrP;
											//--- Hull-down watch posture: COMBAT/RED so it returns fire; LIMITED
											//--- so it settles and watches rather than advancing. A2-safe setters.
											_x setCombatMode "RED";
											_x setBehaviour "COMBAT";
											_x setSpeedMode "LIMITED";
											_ascrIdx = _ascrIdx + 1;
										}; //--- else: no live driver -> tank is driverless or crew is dead; skip entirely.
									};
								} forEach _vehicles;
								if (_ascrIdx > 0) then {
									["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] ARMOR_SCREEN - %3 tank(s) screened outward r=%4m hdg=%5.", _side, _team, _ascrIdx, _ascrR, round _ascrBrg]] Call WFBE_CO_FNC_AICOMLog;
								};
							};
						};
						}; //--- cmdcon41-w3j: close the fixed-wing-vs-ground arrival split.
						}; //--- cmdcon41-w2: close rally-vs-assault guard
					};
				};

				//--- ===================================================================
				//--- REAL-COMBAT BASE-ASSAULT FIRE PHASE (cmdcon41, REAL-BASE-ASSAULT.md sec 2).
				//--- A "goto" strike order presses onto the enemy HQ (Strategy L660 lays getPos
				//--- _enemyHQ as a plain goto). Today "goto" falls into the arrival SAD only -> units
				//--- fight nearby MEN, never the HQ/factory structures, so the base is never destroyed
				//--- by weapons. This phase - parallel to the towns-target capture block below and
				//--- built on the SAME proven, A2-OA-safe idioms (2-operand reveal, doTarget/doFire,
				//--- WFBE_CO_FNC_GetClosestEntity, a live SAD WaypointsAdd underneath so units are
				//--- never idle, the _holdEnd time-box + _capAbort seq-interrupt from the capture
				//--- hold) - orders EVERY live unit to reveal+doTarget+doFire the nearest alive enemy
				//--- structure (factories FIRST, the HQ LAST). It only engages once the leader is
				//--- within ~400m of the enemy HQ, so ordinary long "goto" moves are untouched. It
				//--- exits when the HQ is dead AND no alive enemy structures remain, on _capAbort
				//--- (re-tasked mid-assault), or on the hard timeout - the team then flows on normally.
				if (_arrived && {!_captureDone} && {_mode == "goto"} && {(missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_STRUCTURES", 1]) > 0}) then {

					//--- Early-exit if the team is gone / has no live units (mirrors the capture-phase guard).
					if (isNull _team || {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) == 0}) exitWith {};

					//--- Resolve the enemy side (opposite of _side; A2-OA: switch on Side, no A3 commands).
					private ["_enemySide"];
					_enemySide = switch (_side) do {
						case west: {east};
						case east: {west};
						default {sideEnemy}; //--- resistance/other: fall back to A2's global OPFOR alias.
					};

					//--- Alive-filtered enemy HQ + structures (both helpers alive-filter; _eHQ may be objNull mid-mobilize).
					private ["_eHQ","_eStructs"];
					_eHQ     = _enemySide Call WFBE_CO_FNC_GetSideHQ;
					_eStructs = _enemySide Call WFBE_CO_FNC_GetSideStructures;
					if (isNil "_eStructs" || {typeName _eStructs != "ARRAY"}) then {_eStructs = []};

					//--- ENGAGE-GATE: only prosecute structures once the leader is within ~400m of the
					//--- enemy HQ pos - so a team still road-marching a long "goto" leg is NOT pulled into
					//--- the fire loop (ordinary goto moves untouched). If the HQ is null/mobilizing we
					//--- cannot range-gate, so skip (the arrival SAD keeps the team fighting meanwhile).
					private ["_engageRange","_hqPos","_inRange"];
					_engageRange = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_ENGAGE_RANGE", 400];
					_inRange = false;
					if (!isNull _eHQ && {alive _eHQ}) then {
						_hqPos = getPos _eHQ;
						if (!isNull leader _team && {alive leader _team} && {((leader _team) distance _hqPos) < _engageRange}) then {_inRange = true};
					};

					if (_inRange) then {
						//--- Seq-interrupt snapshot (identical idiom to the capture hold): if a fresh order
						//--- (bumped seq) arrives mid-assault the outer ~8s loop must re-read within one tick
						//--- instead of finishing a multi-minute press. A2-OA: plain single-arg getVariable on
						//--- the GROUP + isNil (the [name,default] form is unreliable on groups).
						private ["_asInt","_asOrd0","_asSeq","_asAbort","_asOrdN","_asEnd","_asDone"];
						_asInt  = (missionNamespace getVariable ["WFBE_C_AICOM_CAPTURE_INTERRUPT", 1]) > 0;
						_asOrd0 = _team getVariable "wfbe_aicom_order"; if (isNil "_asOrd0") then {_asOrd0 = []};
						_asSeq  = if (count _asOrd0 >= 1) then {_asOrd0 select 0} else {-1};
						_asAbort = false;
						_asDone  = false;

						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] BASE-ASSAULT fire phase begin vs %3 HQ (%4 structure(s)).", _side, _team, _enemySide, count _eStructs]] Call WFBE_CO_FNC_AICOMLog;

						//--- Time-boxed fire loop (bounded by _asEnd + _asAbort exactly like the capture hold).
						//--- Each ~10s tick: (a) re-resolve the live structure list, (b) pick the nearest ALIVE
						//--- FACTORY first (HQ only once no factories remain) via WFBE_CO_FNC_GetClosestEntity,
						//--- (c) lay a live SAD waypoint at the target so the squad is NEVER idle (manoeuvres even
						//--- with no LOS), (d) order every live unit to reveal+doTarget+doFire the target. Exit
						//--- when the HQ is dead AND no alive enemy structures remain, on _asAbort, or on timeout.
						_asEnd = time + (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_HOLD", 360]);
						while {time < _asEnd && {!_asDone} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
							//--- Seq-interrupt check (same as the capture hold).
							_asOrdN = _team getVariable "wfbe_aicom_order"; if (isNil "_asOrdN") then {_asOrdN = []};
							if (_asInt && {count _asOrdN >= 1} && {(_asOrdN select 0) != _asSeq}) then {_asAbort = true};
							if (_asAbort) exitWith {}; //--- re-tasked mid-assault -> bail; outer loop re-reads the new order.

							//--- Re-resolve live targets this tick (structures die out from under us).
							_eHQ     = _enemySide Call WFBE_CO_FNC_GetSideHQ;
							_eStructs = _enemySide Call WFBE_CO_FNC_GetSideStructures;
							if (isNil "_eStructs" || {typeName _eStructs != "ARRAY"}) then {_eStructs = []};

							//--- Build the alive FACTORY-FIRST list (exclude the HQ; append it LAST so
							//--- factories fall before the HQ per the design's kill order).
							private ["_liveStructs","_tgt","_ldrRef"];
							_liveStructs = [];
							{
								if (!isNil "_x") then {
									if (!isNull _x && {alive _x} && {_x != _eHQ}) then {_liveStructs = _liveStructs + [_x]};
								};
							} forEach _eStructs;

							//--- Pick the nearest alive factory to the leader; if none remain, target the HQ last.
							_ldrRef = if (!isNull leader _team && {alive leader _team}) then {leader _team} else {_team};
							_tgt = objNull;
							if (count _liveStructs > 0) then {
								_tgt = [_ldrRef, _liveStructs] Call WFBE_CO_FNC_GetClosestEntity;
							} else {
								if (!isNull _eHQ && {alive _eHQ}) then {_tgt = _eHQ};
							};

							//--- Victory-of-this-phase test: HQ dead AND no alive enemy structures -> done.
							if (isNull _tgt) then {
								_asDone = true;
							} else {
								//--- Lay a live SAD at the target so the squad closes + manoeuvres even without LOS
								//--- (never idle - MEMORY guardrail), then order the fire. SAD radius mirrors the
								//--- assault-SAD ring used on arrival; completion 30 like the other WaypointsAdd calls.
								[_team, true, [[getPos _tgt, 'SAD', (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_SAD", 80]), 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
								{
									if (alive _x) then {
										_x reveal _tgt;   //--- A2: 2-operand reveal only (array form is A3-only).
										_x doTarget _tgt;
										_x doFire _tgt;
									};
								} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
							};
							sleep 10; //--- re-issue each ~10s tick.
						};
						if (_asAbort) exitWith {}; //--- assault interrupted -> bail the phase; outer loop re-tasks.
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] BASE-ASSAULT fire phase end (HQ alive=%3, structures left=%4).", _side, _team, (!isNull _eHQ && {alive _eHQ}), count _eStructs]] Call WFBE_CO_FNC_AICOMLog;
					} else {
						_arrivalTraceAt = _team getVariable "wfbe_aicom_arrival_trace_at";
						if (isNil "_arrivalTraceAt") then {_arrivalTraceAt = time};
						if (time >= _arrivalTraceAt) then {
							diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|CAPTURE_TRACE|ARRIVAL_WAIT|team=" + (str _team) + "|seq=" + str _seq + "|mode=" + str _mode + "|dist=" + str (round _arrivalDist) + "|gate=" + str (round _arrivalGate));
							_team setVariable ["wfbe_aicom_arrival_trace_at", time + 60];
						};
					};
				};

				//--- ===================================================================
				//--- DISMOUNT-CAPTURE PHASE (towns-target). The keystone movement works:
				//--- the team REACHES the town (road-march / air-insert / truck-abandon all
				//--- proven). It then "hung around" and never flipped the town. Root causes,
				//--- all fixed below WITHOUT touching server_town.sqf or the camp scripts:
				//---  (1) BRANCH BUG: the old code chose camp-sweep vs pure-armour on the
				//---      LIVE-MOUNTED _hasCargo flag. By arrival the infantry are already ON
				//---      FOOT (air-insert L210/L224, spawn-on-foot, truck-abandon), so
				//---      _hasCargo was false -> pure-armour else -> only (leader)doMove _dest
				//---      -> nobody ever went to a camp or held the depot. Now we drive on the
				//---      actual ON-FOOT infantry whenever the team has any.
				//---  (2) DEPOT PRESENCE: mode-0 (Classic) flips a town ONLY via server_town.sqf,
				//---      which scans nearEntities within WFBE_C_TOWNS_CAPTURE_RANGE (40m) of the
				//---      TOWN-CENTER DEPOT LOGIC. The old sweep parked infantry AT bunkers
				//---      (outside 40m) and never held the depot, so _west stayed 0 -> no drain.
				//---      PRIMARY FIX: after the camp sweep we HOLD all on-foot infantry at the
				//---      depot center (getPos _townObj) and FIGHT there.
				//---  (3) DEFENDER CLEAR: a bare doMove makes units stand, not seek-and-destroy.
				//---      One live resistance defender within 40m keeps server_town.sqf _skip=true
				//---      (contested) and regenerates supply. So at the depot we lay a real SAD
				//---      waypoint and reveal the garrison, then hold until resistance-near-center
				//---      hits zero (or a hard timeout). Units always hold a live SAD/move order -
				//---      never frozen/idle (MEMORY guardrail).
				//--- RE-ARM: _captureDone is latched ONLY once the town is ours; otherwise the
				//--- 20s loop re-runs this phase next tick (units keep fighting at the center) so
				//--- a single failed pass is never a dead end.
				if (_arrived && !_captureDone && _mode == "towns-target") then {
					diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|CAPTURE_TRACE|BEGIN_CAPTURE|team=" + (str _team) + "|seq=" + str _seq + "|dist=" + str (round ((leader _team) distance _dest)));

					//--- WAVE-1 CAUSE-3 EARLY-EXIT: bail the whole capture phase if the team is gone or has
					//--- no live units (a wipe mid-phase would otherwise run scans/waypoints on a dead group).
					if (isNull _team || {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) == 0}) exitWith {};

					//--- B69 (capture-phase-seq-interrupt): snapshot the order seq we entered the capture phase on. If a fresh order (bumped seq) arrives mid-capture (e.g. the team is pulled into the HQ strike), abort this phase so the outer ~8s order loop re-reads within one tick instead of finishing a multi-minute hold. A2-OA: plain single-arg getVariable on the GROUP + isNil (the [name,default] form is unreliable on groups). _capAbort is set inside the hold loops (child scopes write the parent private) and bails the phase via exitWith after each loop.
					private ["_capInt","_capSeq","_capAbort","_capOrd0","_capOrdN"];
					_capInt = (missionNamespace getVariable ["WFBE_C_AICOM_CAPTURE_INTERRUPT", 1]) > 0;
					_capOrd0 = _team getVariable "wfbe_aicom_order"; if (isNil "_capOrd0") then {_capOrd0 = []};
					_capSeq = if (count _capOrd0 >= 1) then {_capOrd0 select 0} else {-1};
					_capAbort = false;

					//--- Resolve the town object ROBUSTLY. wfbe_aicom_townorder is set server-side
					//--- WITHOUT broadcast (AI_Commander_AssignTowns.sqf L117/L240 use the 2-arg
					//--- setVariable), so on a Headless Client it reads nil. The order dest _dest IS
					//--- the town-logic position (getPos _target), and the global "towns" array is
					//--- populated on every machine (Init_Town.sqf L165) with broadcast "camps"
					//--- (L63). So fall back to the nearest town to _dest for a valid depot+camps.
					_townObj   = objNull;
					_townCamps = [];
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_townOrderArr = _team getVariable "wfbe_aicom_townorder";
					if (isNil "_townOrderArr") then {_townOrderArr = []};
					if (count _townOrderArr > 0) then {_townObj = _townOrderArr select 0};
					if (isNull _townObj && {count towns > 0}) then {
						_townObj = [_dest, towns] Call WFBE_CO_FNC_GetClosestEntity;
					};
					if (!isNull _townObj) then {_townCamps = _townObj getVariable ["camps", []]};

					//--- Depot-center scan point (server_town.sqf scans nearEntities around the
					//--- town LOGIC). Fall back to the order dest if the town object is unknown.
					_townCenter = if (!isNull _townObj) then {getPos _townObj} else {_dest};
					_capRange   = missionNamespace getVariable ["WFBE_C_TOWNS_CAPTURE_RANGE", 40];
					_campRange  = missionNamespace getVariable ["WFBE_C_CAMPS_RANGE", 10];

					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] begin capture at [%3] (%4 camps, depot scan %5m).", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}, count _townCamps, _capRange]] Call WFBE_CO_FNC_AICOMLog;

					//--- CAPTURE LOCK STAMP (GR-2026-07-03a, capture-churn fix): this team has fired BEGIN_CAPTURE and is about to drain the depot.
					//--- Stamp a BROADCAST group var wfbe_aicom_caplock = [townObj, t0] (3-arg GROUP setVariable IS valid on A2 OA; only the
					//--- 3-arg NAMESPACE form is the trap). The driver runs on the HC; the order ISSUERS run on the server + read this via
					//--- WFBE_CO_FNC_CapLock, so the public flag is mandatory for cross-machine visibility (mirrors wfbe_aicom_strike broadcasts).
					//--- The lock makes the team immune to re-targeting until captured / dead / TTL / town-flips-to-us (see the helper).
					//--- DEADLOCK FIX (2026-07-04): re-stamps PRESERVE the original t0 for the same town - refreshing t0 every pass
					//--- made the 600s TTL unreachable, permanently pinning a team wedged inside the capture radius. TTL now
					//--- measures total time-in-capture; a genuinely slow drain re-locks after one issuer re-evaluation.
					if ((missionNamespace getVariable ["WFBE_C_AICOM_CAPTURE_LOCK", 1]) > 0) then {
						private ["_capPrev","_capT0"];
						_capPrev = _team getVariable "wfbe_aicom_caplock";
						_capT0 = time;
						if (!isNil "_capPrev" && {typeName _capPrev == "ARRAY"} && {count _capPrev >= 2} && {(_capPrev select 0) == _townObj}) then {_capT0 = _capPrev select 1};
						_team setVariable ["wfbe_aicom_caplock", [_townObj, _capT0], true];
					};

					//--- ALWAYS dismount: build the on-foot infantry list from EVERY alive non-crew
					//--- unit, dismounting any that happen to still be in cargo. Crew (driver/gunner)
					//--- stay in their hull (keeps armour ready + parked near center). This replaces
					//--- the broken _hasCargo branch selection entirely.
					_liveUnits = (units _team) Call WFBE_CO_FNC_GetLiveUnits;
					_footInf   = [];
					{
						_u = _x;
						if (alive _u) then {
							if (vehicle _u != _u) then {
								_veh = vehicle _u;
								if (_u == driver _veh || _u == gunner _veh) then {
									//--- Crew stays mounted: hull stays driveable + parked.
								} else {
									unassignVehicle _u;
									[_u] orderGetIn false;
									_footInf = _footInf + [_u];
								};
							} else {
								//--- Already on foot (air-insert / spawn-on-foot / truck-abandon).
								_footInf = _footInf + [_u];
							};
						};
					} forEach _liveUnits;

					if (count _footInf > 0) then {
						//--- ===== PER-CAMP SWEEP (drain-speed bonus + defender soften) =====
						//--- Mode 0: holding camps is NOT a gate, but server_town.sqf L183 multiplies
						//--- the drain rate by (campsOnSide/totalCamps), so taking bunkers ACCELERATES
						//--- the flip. Camp flip needs on-foot Man within WFBE_C_CAMPS_RANGE (10m)
						//--- (server_town_camp.sqf L26), so we close to <=10m and reveal nearby enemy so
						//--- the AI fights instead of standing. NO remount between camps - they stay on
						//--- foot for the depot hold that follows (the real capture step).
						{
							_campObj = _x;
							if (!isNull _campObj) then {
								{if (alive _x) then {_x doMove (getPos _campObj)}} forEach _footInf;
								if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove (getPos _campObj)};

								//--- Settle: up to 30s or leader within camp range (10m). exitWith-in-then
								//--- scope trap avoided: proximity test lives in the while header (lazy &&).
								_settleTimeout = time + 30;
								while {time < _settleTimeout && {!(!isNull leader _team && {alive leader _team} && {(leader _team) distance _campObj < _campRange})}} do {
									//--- Reveal the camp's live enemy so the squad prosecutes them.
									{
										if (alive _x && {side _x != _side} && {side _x != civilian}) then {_team reveal _x}; //--- A2: 2-operand reveal only (array form is A3-only).
									} forEach ((getPos _campObj) nearEntities [["Man"], 60]);
									sleep 3;
								};
								//--- Dwell so the 10m camp scan ticks (presence-based capture).
								//--- cmdcon41-w3f: randomize the fixed 45s dwell to 35-55s so concurrent teams don't
								//--- lock-step on the same tick. Randomized dwell ONLY - deliberately NO exit-when-camp-flips
								//--- polling here (recorded gotcha: that poll caused the frozen-team regression).
								sleep (35 + random 20);
							};
						} forEach _townCamps;

						//--- ===== CAMP-FIRST GATE (BUG A): BOTH CAMPS BEFORE THE CENTER =====
						//--- Owner decision: KEEP Classic capture mode (WFBE_C_TOWNS_CAPTURE_MODE=0
						//--- unchanged) and make the AI take both camps FIRST *behaviourally*. We do
						//--- NOT enter the depot/town-center hold below until every camp this town owns
						//--- is held by our side (sideID == _sideID). Direct the foot infantry to the
						//--- NEAREST un-held camp, lay a live SAD/MOVE order there at WFBE_C_CAMPS_RANGE,
						//--- reveal its garrison (same pattern as the sweep above), and re-evaluate each
						//--- pass. TIME-BOX with the existing _holdEnd-style idiom so a dead/uncapturable
						//--- bunker (server_town_camp.sqf:24 gates on alive _base) can NEVER trap the team:
						//--- after a bounded window we fall through to the center hold anyway. Units always
						//--- hold a live SAD/move order here - never frozen/idle (MEMORY guardrail).
						_unheldCamps = [];
						{ if (!isNull _x && {(_x getVariable ["sideID",-1]) != _sideID}) then {_unheldCamps = _unheldCamps + [_x]} } forEach _townCamps;
						_campFirstEnd = time + (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_HOLD", 360]); //--- punchy-AICOM (Ray 2026-06-17): hard-coded 150 -> WFBE_C_AICOM_ASSAULT_HOLD (360). Longer camp-first window = the team actually finishes taking both camps.
						//--- B74.2 (Ray 2026-06-23) NO-PROGRESS tracker for the camp-first loop (don't get stuck on camps).
						private ["_campStallPasses","_campLastUnheld","_campStallMax","_capMode","_campGateMode2"];
						_campStallPasses = 0;
						_campLastUnheld  = count _unheldCamps;
						_campStallMax    = missionNamespace getVariable ["WFBE_C_AICOM_CAMP_STALL_PASSES", 3];
						//--- FIX A (afraid-of-camps): in the LIVE AllCamps capture mode (WFBE_C_TOWNS_CAPTURE_MODE==2,
						//--- read the same way server_town.sqf:15 does) the depot CANNOT drain until this side holds
						//--- EVERY camp, so the B74.2 no-progress bail is HARMFUL here: after bailing the team falls
						//--- through to a depot hold that still can't flip, and grinds the town forever ("stands at a
						//--- town it cannot finish"). When mode==2 AND WFBE_C_AICOM_CAMP_GATE_MODE2 (default 1) is on we
						//--- DISABLE the stall bail and stay on the camps, clearing them harder, bounded by the SAME
						//--- _campFirstEnd (WFBE_C_AICOM_ASSAULT_HOLD, 360s) so the team is never trapped indefinitely.
						//--- Mode 0/1, or the flag off, behave EXACTLY as before.
						_capMode       = missionNamespace getVariable ["WFBE_C_TOWNS_CAPTURE_MODE", 0];
						_campGateMode2 = missionNamespace getVariable ["WFBE_C_AICOM_CAMP_GATE_MODE2", 1];
						//--- SML-1 camp-split: when 2+ camps are unheld, spawn per-unit doStop/doMove orders with a TTL watchdog. Flag-gated (WFBE_C_SML_CAMP_SPLIT, default 0).
						if ((missionNamespace getVariable ["WFBE_C_SML_CAMP_SPLIT", 0]) > 0) then {
							[_team, _footInf, _unheldCamps, _sideID, _side, _townCenter, _capSeq, _campFirstEnd] Spawn WFBE_CO_FNC_SMLCampSplit;
						};
						//--- SML-2 real dismounts: force cargo infantry off hulls; crew (driver/gunner) stay mounted for fire support. Flag-gated (WFBE_C_SML_DISMOUNTS, default 0).
						if ((missionNamespace getVariable ["WFBE_C_SML_DISMOUNTS", 0]) > 0) then {
							[_team, _footInf, _sideID, _side, _capSeq, _campFirstEnd] Spawn WFBE_CO_FNC_SMLDismounts;
						};

						while {count _unheldCamps > 0 && {time < _campFirstEnd} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
							_capOrdN = _team getVariable "wfbe_aicom_order"; if (isNil "_capOrdN") then {_capOrdN = []};
							if (_capInt && {count _capOrdN >= 1} && {(_capOrdN select 0) != _capSeq}) then {_capAbort = true};
							if (_capAbort) exitWith {}; //--- B69: re-tasked mid camp-first -> bail; outer loop re-reads the new order
							_nearCamp   = [leader _team, _unheldCamps] Call WFBE_CO_FNC_GetClosestEntity;
							if (isNull _nearCamp) exitWith {};
							_campTgtPos = getPos _nearCamp;
							//--- CAPTURE MECHANIC (server_town_camp.sqf L26): the camp scan is
							//--- nearEntities["Man", WFBE_C_CAMPS_RANGE(10m)] - it counts ONLY on-foot
							//--- "Man" entities within 10m. Crew sitting in a hull do NOT register, and
							//--- a 30m-radius SAD lets the group "complete" the order out on the 30m
							//--- ring and rove there (the observed "drive circles, never cap"). So:
							//---  (a) lay a TIGHT MOVE waypoint on the camp CENTRE with a small radius
							//---      INSIDE the 10m capture range (mirrors the depot-centre hold, sized
							//---      to the camp scan) - NOT a 30m SAD ring,
							//---  (b) defensively dismount any _footInf still in cargo and walk them in,
							//---  (c) settle until the leader is inside _campRange, then PLANT the foot
							//---      units (doStop + setUnitPos "UP") so they hold IN the 10m zone and
							//---      the presence scan ticks, instead of orbiting.
							_campHoldR = (_campRange - 2) max 6; //--- ~8m: comfortably inside the 10m "Man" scan
							[_team, true, [[_campTgtPos, 'MOVE', _campHoldR, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
							//--- Defensive dismount: any foot soldier still in cargo walks in on foot
							//--- (crew never count for the camp "Man" scan, so foot presence is required).
							{
								if (alive _x && {vehicle _x != _x}) then {
									_veh = vehicle _x;
									if !(_x == driver _veh || _x == gunner _veh) then {unassignVehicle _x; [_x] orderGetIn false};
								};
							} forEach _footInf;
							{if (alive _x) then {_x doMove _campTgtPos}} forEach _footInf;
							if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove _campTgtPos};
							//--- Reveal the camp's live enemy so the squad prosecutes them (sweep pattern).
							{
								if (alive _x && {side _x != _side} && {side _x != civilian}) then {_team reveal _x}; //--- A2: 2-operand reveal only (array form is A3-only).
							} forEach (_campTgtPos nearEntities [["Man"], 60]);
							//--- FIX A: in the mode-2 gated path the depot can't flip until the garrison is
							//--- cleared, so prosecute the camp HARDER: lay a live SAD ring over the camp and
							//--- doTarget/doFire every live garrison unit so the squad ATTACKS instead of just
							//--- planting. Still bounded by _campFirstEnd; units keep a live order (never idle).
							if (_capMode == 2 && {_campGateMode2 != 0}) then {
								[_team, true, [[_campTgtPos, 'SAD', (_campRange max 30), 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
								_campEnemy = [];
								{
									if (alive _x && {side _x != _side} && {side _x != civilian}) then {
										_team reveal _x; //--- A2: 2-operand reveal only.
										_campEnemy = _campEnemy + [_x];
									};
								} forEach (_campTgtPos nearEntities [["Man"], 60]);
								if (count _campEnemy > 0) then {
									_campFoe = _campEnemy select 0;
									{if (alive _x) then {_x doTarget _campFoe; _x doFire _campFoe}} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
								};
							};
							//--- Settle: up to ~20s or leader inside the 10m camp range (mirrors the
							//--- per-camp sweep settle at L543). Re-press stragglers toward the centre.
							_campSettleEnd = time + 20;
							while {time < _campSettleEnd && {!(!isNull leader _team && {alive leader _team} && {(leader _team) distance _nearCamp < _campRange})} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
								{if (alive _x && {(_x distance _nearCamp) > _campHoldR}) then {_x doMove _campTgtPos}} forEach _footInf;
								sleep 3;
							};
							//--- ANTI-ORBIT HOLD: any foot unit now inside the zone STOPS and stands so
							//--- it stays put within 10m (presence-based capture) instead of roving. Units
							//--- still outside keep a live move order in - never frozen far out (guardrail).
							{
								if (alive _x) then {
									if ((_x distance _nearCamp) < _campRange) then {_x setUnitPos "UP"; doStop _x}
									else {_x doMove _campTgtPos};
								};
							} forEach _footInf;
							//--- Dwell so the 10m camp scan ticks the supplyValue down to a flip.
							sleep 8;
							//--- Re-evaluate: drop any camp that is now ours (or went null).
							_unheldCamps = [];
							{ if (!isNull _x && {(_x getVariable ["sideID",-1]) != _sideID}) then {_unheldCamps = _unheldCamps + [_x]} } forEach _townCamps;
							//--- B74.2 NO-PROGRESS BAIL (Ray 2026-06-23): if the un-held camp count did NOT drop this
							//--- pass, count a stall; after WFBE_C_AICOM_CAMP_STALL_PASSES consecutive no-progress passes
							//--- stop grinding the camps and fall through to the depot/town-centre hold (never STUCK on an
							//--- uncapturable/heavily-defended camp). A pass that DID flip a camp resets the counter. The
							//--- exitWith leaves the camp-first while (same idiom as the _capAbort bail above) -> the plant
							//--- is released below and, with _capAbort still false, the team proceeds to the centre hold.
							if (count _unheldCamps < _campLastUnheld) then {
								_campStallPasses = 0; _campLastUnheld = count _unheldCamps;
							} else {
								_campStallPasses = _campStallPasses + 1;
							};
							//--- FIX A: SKIP the no-progress bail in the mode-2 gated path. In AllCamps mode the
							//--- depot cannot drain until every camp is held, so bailing to the (still-gated) depot
							//--- hold would only grind the town forever. We stay on the camps and let _campFirstEnd
							//--- (WFBE_C_AICOM_ASSAULT_HOLD) be the sole, bounded release. Classic/threshold (mode 0/1)
							//--- or the flag off keep the original stall bail unchanged.
							if !(_capMode == 2 && {_campGateMode2 != 0}) then {
								if (_campStallMax > 0 && {_campStallPasses >= _campStallMax}) exitWith {
									["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] camp-first NO-PROGRESS after %3 passes (%4 camp(s) still un-held) - proceeding to town centre.", _side, _team, _campStallPasses, count _unheldCamps]] Call WFBE_CO_FNC_AICOMLog;
								};
							};
						};
						//--- Release the plant so the depot-centre hold below can march these units on
						//--- (setUnitPos "UP" pins stance; "AUTO" hands movement back to the AI).
						{if (alive _x) then {_x setUnitPos "AUTO"; _x doFollow (leader _team)}} forEach _footInf; //--- B69: doFollow clears the sticky doStop from the camp plant (setUnitPos alone does NOT), so an interrupted team is never left frozen; the next order's waypoints take over.
							if (_capAbort) exitWith {}; //--- B69: camp-first interrupted (plant released above so no frozen units) -> bail capture phase; outer loop re-tasks.
						if (count _unheldCamps > 0) then {
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] camp-first window expired with %3 camp(s) un-held at [%4] - proceeding to center.", _side, _team, count _unheldCamps, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}]] Call WFBE_CO_FNC_AICOMLog;
						};

						//--- SML-4 overwatch: pre-position launcher soldier on armor approach vector before the depot assault. Flag-gated (WFBE_C_SML_AT_OVERWATCH default 0).
						if ((missionNamespace getVariable ["WFBE_C_SML_AT_OVERWATCH", 0]) > 0) then {
							[_team, _footInf, _sideID, _side, _townCenter, _dest, _capSeq] Spawn WFBE_CO_FNC_SMLOverwatch;
						};
						//--- ===== PRIMARY: DEPOT-CENTER HOLD + CLEAR (the actual town flip) =====
						//--- Push every on-foot soldier ONTO the depot center and FIGHT there. This is
						//--- the only thing that satisfies server_town.sqf mode-0: a WEST unit within
						//--- 40m of the depot AND no live resistance within that same 40m. Lay a real
						//--- group SAD waypoint over the center (COMBAT/RED), move the foot units in, and
						//--- reveal the garrison so they clear it. Then HOLD until resistance-near-center
						//--- is zero (town drains + flips) OR a hard timeout, re-revealing each tick.
						//--- WAVE-1 A4 CAPTURE-HOLD: hold SAD radius = _capRange (was _capRange max 60). The town only
						//--- drains within _capRange (40m), so a 60m hold ring left units orbiting the 40-60m band
						//--- and never satisfying the depot-center presence scan. Tightening to _capRange pulls them in.
						//--- cmdcon41-w3f: PRIMARY depot-center hold formation WEDGE -> LINE. A bunched WEDGE at the
						//--- depot center let one enemy grenade wipe the whole hold; LINE spreads the squad so a single
						//--- frag can't clear them. FORMATION only - COMBAT/RED behaviour + _capRange radius unchanged.
						//--- (Road-march arrival handoff lines and the secondary depot SADs ~L1250/1252 are left as-is.)
						[_team, true, [[_townCenter, 'SAD', _capRange, 30, [], [], ["COMBAT","RED","LINE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						{if (alive _x) then {_x doMove _townCenter}} forEach _footInf;
						if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove _townCenter};
						//--- SML-3 retreat: mauled individual soldiers pull back toward rear while healthy units keep fighting. Flag-gated (WFBE_C_SML_RETREAT default 0).
						if ((missionNamespace getVariable ["WFBE_C_SML_RETREAT", 0]) > 0) then {
							[_team, _footInf, _sideID, _side, _townCenter, _capSeq] Spawn WFBE_CO_FNC_SMLRetreat;
						};

						//--- Hold/fight loop: up to ~150s. Exit early once no live resistance remains
						//--- within the capture radius of the depot (the contested _skip clears -> the
						//--- town drains and flips). Re-reveal enemy each tick. Every iteration leaves
						//--- units on a live SAD order (never idle).
						_holdEnd = time + (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_HOLD", 360]); //--- punchy-AICOM (Ray 2026-06-17): hard-coded 150 -> WFBE_C_AICOM_ASSAULT_HOLD (360). Longer depot-center hold = the team holds long enough to drain + flip the town.
						_resNear = 1; _holdFlipped = false;
						//--- WAVE-2 DRAIN-WAIT (claude-gaming 2026-07-01): the OLD loop exited the instant enemies
						//--- cleared (_resNear==0), but server_town.sqf drains the depot over MANY 5s ticks while OUR
						//--- bodies sit in the 40m ring - so a peaceful, capturable town exited the hold in ~10s,
						//--- never flipped, and got RELEASED as "uncapturable" after 2 empty passes (the live
						//--- "res-near=0 never flips / standing around / afraid of camps" bug). Now we HOLD until the
						//--- town actually flips to us OR the hard timeout/abort - keying the loop on the flip flag,
						//--- not the enemy count. Still bounded by _holdEnd (360s), _capAbort, and the stall-advance
						//--- floor, so units are never frozen and always on a live SAD order.
						while {time < _holdEnd && {!_holdFlipped} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
							_capOrdN = _team getVariable "wfbe_aicom_order"; if (isNil "_capOrdN") then {_capOrdN = []};
							if (_capInt && {count _capOrdN >= 1} && {(_capOrdN select 0) != _capSeq}) then {_capAbort = true};
							if (_capAbort) exitWith {}; //--- B69: re-tasked mid depot-hold -> bail; outer loop re-reads the new order
							_enemyNear = (_townCenter nearEntities [["Man"], _capRange]) unitsBelowHeight 10;
							_resNear = 0;
							{
								if (alive _x && {side _x != _side} && {side _x != civilian}) then {
									_resNear = _resNear + 1;
									_team reveal _x; //--- A2: 2-operand reveal only (array form is A3-only).
								};
							} forEach _enemyNear;
							//--- cmdcon41-w2 DEPOT-HOLD BREAK-OFF (sketch rally-break-off-depot-hold-attrition-trigger): a depleted
							//--- team still being out-fought at the depot (live resistance in the ring, _resNear>0) should break off
							//--- into a fighting withdrawal instead of grinding to extinction. When live units drop below
							//--- WFBE_C_AICOM_BREAKOFF_MIN (default 3) AND _resNear>0, raise wfbe_aicom_wantrally (broadcast) so
							//--- Strategy converts it to a rally order, then bail the phase via the SAME _capAbort idiom (the outer
							//--- loop re-reads the new order; _captureDone is NOT latched). A2-OA-safe: < on numbers, && in if(),
							//--- plain broadcast setVariable, no A3 commands. Never-frozen: the team already holds a live SAD order,
							//--- and the outer loop hands it the rally MOVE next tick.
							if ((count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) < (missionNamespace getVariable ["WFBE_C_AICOM_BREAKOFF_MIN", 3]) && {_resNear > 0}) then {
								_team setVariable ["wfbe_aicom_wantrally", true, true];
								//--- cmdcon41-w3 BREAK-OFF SMOKE (gate WFBE_C_AICOM_SMOKE default 1): as the out-fought remnant breaks off
								//--- it pops covering smoke so the fighting withdrawal is screened instead of running exposed. HC-local,
								//--- bounded (2 createVehicle, no loop/sleep), rate-limited to one smoke event per team per
								//--- WFBE_C_AICOM_SMOKE_COOLDOWN (120s) via a plain group-var stamp (get + isNil, A2-safe - groups reject the
								//--- [name,default] form). Two shells in a ~15m ring around the leader offset by the enemy bearing (the
								//--- _resNear ring gave us the enemy already this tick) so the screen sits between us and them. createVehicle
								//--- [class,pos,[],0,'NONE'] is A2-OA-safe. Never-frozen: purely cosmetic; the outer loop hands the rally MOVE next tick.
								if ((missionNamespace getVariable ["WFBE_C_AICOM_SMOKE", 1]) > 0) then {
									private ["_smkLdr","_smkLast","_smkCool","_smkOK"];
									_smkLdr  = leader _team;
									_smkCool = missionNamespace getVariable ["WFBE_C_AICOM_SMOKE_COOLDOWN", 120];
									_smkLast = _team getVariable "wfbe_aicom_smoke_last";
									_smkOK   = if (isNil "_smkLast") then {true} else {(time - _smkLast) >= _smkCool};
									if (!isNull _smkLdr && {alive _smkLdr} && {_smkOK}) then {
										private ["_smkCls","_smkBase","_smkBrg","_smkP0","_smkP1"];
										//--- Faction-appropriate covering smoke (WEST white, EAST red, resistance green; A2-OA base classes).
										_smkCls = switch (_side) do {
											case west: {"SmokeShell"};
											case east: {"SmokeShellRed"};
											default {"SmokeShellGreen"};
										};
										_smkBase = getPosATL _smkLdr;
										//--- Bearing toward the nearest live enemy in the capture ring so the screen sits between us and them
										//--- (atan2 position-delta idiom; binary getDir is A3-only). Fall back to the leader heading if none resolves.
										_smkBrg = getDir _smkLdr;
										{
											if (alive _x && {side _x != _side} && {side _x != civilian}) exitWith {
												_smkBrg = (((getPosATL _x) select 0) - (_smkBase select 0)) atan2 (((getPosATL _x) select 1) - (_smkBase select 1));
											};
										} forEach (_smkBase nearEntities [["Man"], _capRange]);
										//--- Two shells ~15m out on either side of the enemy bearing (a covering arc, not a stack).
										_smkP0 = [(_smkBase select 0) + 15 * (sin (_smkBrg - 30)), (_smkBase select 1) + 15 * (cos (_smkBrg - 30)), 0];
										_smkP1 = [(_smkBase select 0) + 15 * (sin (_smkBrg + 30)), (_smkBase select 1) + 15 * (cos (_smkBrg + 30)), 0];
										createVehicle [_smkCls, _smkP0, [], 0, "NONE"];
										createVehicle [_smkCls, _smkP1, [], 0, "NONE"];
										_team setVariable ["wfbe_aicom_smoke_last", time];
										diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|SMOKE|BREAKOFF|team=" + (str _team) + "|cls=" + _smkCls);
									};
								};
								_capAbort = true; //--- bail the depot-hold phase without latching _captureDone (same idiom as the seq-interrupt _capAbort).
								_team setVariable ["wfbe_aicom_caplock", [], true];   //--- CAPTURE LOCK CLEAR (GR-2026-07-03a): stopped draining -> re-taskable now (issuer stops skipping it).
								diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|BREAKOFF|team=" + (str _team) + "|live=" + str (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) + "|resNear=" + str _resNear);
								["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] BREAKOFF (out-fought remnant, res-near=%3) - requesting rally.", _side, _team, _resNear]] Call WFBE_CO_FNC_AICOMLog;
							};
							if (_capAbort) exitWith {}; //--- cmdcon41-w2: break-off (or seq-interrupt) -> bail the depot-hold loop; the post-loop _capAbort guard bails the phase.
							//--- Keep stragglers pressing the center (cheap re-issue, prevents drift).
							//--- WAVE-1 A4: re-press units beyond ~60% of _capRange (was max 25). Units inside the 40m ring
							//--- but past ~24m get pulled to the exact center so the depot-center presence scan ticks.
							{if (alive _x && {(_x distance _townCenter) > (_capRange * 0.6)}) then {_x doMove _townCenter}} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
							//--- Early-out if the town already flipped to us.
							if (!isNull _townObj && {(_townObj getVariable ["sideID", -1]) == _sideID}) then {_holdFlipped = true};
							sleep 10;
						};

						//--- Latch only if the town is now OURS; otherwise leave _captureDone false so
						//--- the 20s order loop re-runs this whole phase next tick and keeps fighting.
						if (_capAbort) exitWith {}; //--- B69: depot-hold interrupted -> bail BEFORE latching captureDone; outer loop re-reads the new order
						_townFlipped = (!isNull _townObj) && {(_townObj getVariable ["sideID", -1]) == _sideID};
						if (_townFlipped) then {
							_captureDone = true;
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] CAPTURED [%3] - holding center.", _side, _team, _townObj getVariable ["name","?"]]] Call WFBE_CO_FNC_AICOMLog;
							//--- SPREAD+HOLD (cmdcon41, SPREAD-AND-HOLD.md sec 2a): the FIRST team to flip a
							//--- fresh town claims a short DEFEND hold via a self-expiring latch STAMPED ON THE
							//--- TOWN OBJECT (broadcast, so AssignTowns can honour it) - so the captor keeps a
							//--- body in the drain ring while the garrison re-arms, instead of every captor
							//--- immediately retargeting and leaving the centre empty (the see-saw). Later
							//--- captors (or the same team past expiry) fall through to the verbatim release.
							//--- A2-OA-safe: object getVariable [name,default] is fine (object, not a group);
							//--- SetTeamMoveMode/SetTeamMovePos are the codebase-standard broadcast setters.
							private ["_holdMode","_holdUntil","_holdClaimed"];
							_holdMode  = missionNamespace getVariable ["WFBE_C_AICOM_HOLD_MODE", 1];
							_holdUntil = _townObj getVariable ["wfbe_aicom_hold_until", 0];
							_holdClaimed = false;
							if (_holdMode > 0 && {time > _holdUntil}) then {
								//--- Claim the hold: stamp the town's expiry, put THIS team on DEFEND at the
								//--- town centre, flag which town it is holding, clear stale strike/relief, and
								//--- do NOT null the goto (so AssignTowns' holder-skip keeps it here).
								_townObj setVariable ["wfbe_aicom_hold_until", time + (missionNamespace getVariable ["WFBE_C_AICOM_HOLD_SECS", 180]), true];
								[_team, "defense"] Call SetTeamMoveMode;               //--- broadcast wfbe_teammode "defense"
								[_team, getPos _townObj] Call SetTeamMovePos;          //--- broadcast wfbe_teamgoto = town centre (goto NOT nulled)
								_team setVariable ["wfbe_aicom_holding_town", _townObj, true]; //--- which town this team is holding (AssignTowns holder-skip reads it)
								_team setVariable ["wfbe_aicom_strike", false, true];  //--- clear stale strike state so Strategy.sqf doesn't re-grab
								_team setVariable ["wfbe_aicom_relief", objNull, true];
								_team setVariable ["wfbe_aicom_caplock", [], true];   //--- CAPTURE LOCK CLEAR (GR-2026-07-03a): no longer draining -> re-taskable now.
								_holdClaimed = true;
								["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] HOLD-CLAIM [%3] on defense for %4s.", _side, _team, _townObj getVariable ["name","?"], (missionNamespace getVariable ["WFBE_C_AICOM_HOLD_SECS", 180])]] Call WFBE_CO_FNC_AICOMLog;
							};
							if (!_holdClaimed) then {
							//--- ON-CAPTURE RE-TASK (BUG B): drop the captured-town order so AssignTowns
							//--- retargets THIS team next tick instead of letting it idle ~2 min at the
							//--- center. AssignTowns L168-169 retargets when isNull _goto (=> _needs=true),
							//--- and L164 only enters that gate for mode "towns"/"". So null the goto,
							//--- clear the order bookkeeping, and force the team back into the towns gate.
							//--- Also clear stale strike/relief state so Strategy.sqf doesn't re-grab it.
							//--- Locality matches existing writes: teamgoto/teammode broadcast true (like
							//--- SetTeamMovePos/SetTeamMoveMode); townorder stays 2-arg (like all its writers).
							_team setVariable ["wfbe_teamgoto", objNull, true];        //--- drop captured-town goto -> AssignTowns retargets next tick (isNull _goto => _needs=true)
							_team setVariable ["wfbe_aicom_townorder", [], false];     //--- 2-arg (NOT broadcast) to match existing townorder writes
							_team setVariable ["wfbe_teammode", "towns", true];        //--- ensure strike/relief teams re-enter the towns retarget gate
							_team setVariable ["wfbe_aicom_strike", false, true];      //--- clear stale strike state so Strategy.sqf doesn't re-grab
							_team setVariable ["wfbe_aicom_relief", objNull, true];
							_team setVariable ["wfbe_aicom_caplock", [], true];   //--- CAPTURE LOCK CLEAR (GR-2026-07-03a): no longer draining -> re-taskable now.
							};
						} else {
							//--- WAVE-1 CAUSE-3 BOUND-CAPTURE-LOOP: on a contested/uncapturable depot the old code held
							//--- the center FOREVER ("did not flip res-near=0"). Track consecutive non-flip passes on a
							//--- team var; after WFBE_C_AICOM_CAPTURE_MAXPASSES passes with res-near==0 AND the town still
							//--- not ours, RELEASE via the SAME on-capture re-task idiom (success block above) so
							//--- AssignTowns retargets this team next tick instead of grinding. A pass with res-near>0 is
							//--- a live firefight (legit) -> reset the counter so we keep fighting a defended town.
							_capMaxPasses = missionNamespace getVariable ["WFBE_C_AICOM_CAPTURE_MAXPASSES", 2];
							if (_resNear > 0) then {
								_team setVariable ["wfbe_aicom_cappasses", 0];
							} else {
								_capPasses = _team getVariable "wfbe_aicom_cappasses";
								if (isNil "_capPasses") then {_capPasses = 0};
								_capPasses = _capPasses + 1;
								_team setVariable ["wfbe_aicom_cappasses", _capPasses];
							};
							_capReleased = false;
							_capPasses = _team getVariable "wfbe_aicom_cappasses";
							if (isNil "_capPasses") then {_capPasses = 0};
							if (_capPasses >= _capMaxPasses) then {
								//--- Bail this depot: same release idiom as the capture-success block above so AssignTowns
								//--- retargets (isNull _goto => _needs=true), and clear strike/relief so Strategy will not re-grab.
								_captureDone = true;     //--- stop re-running this phase for the dropped order
								_capReleased = true;
								_team setVariable ["wfbe_aicom_cappasses", 0];
								_team setVariable ["wfbe_teamgoto", objNull, true];
								_team setVariable ["wfbe_aicom_townorder", [], false];
								_team setVariable ["wfbe_teammode", "towns", true];
								_team setVariable ["wfbe_aicom_strike", false, true];
								_team setVariable ["wfbe_aicom_relief", objNull, true];
								_team setVariable ["wfbe_aicom_caplock", [], true];   //--- CAPTURE LOCK CLEAR (GR-2026-07-03a): stopped draining -> re-taskable now (issuer stops skipping it).
								["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] RELEASED uncapturable depot at [%3] after %4 empty passes - retargeting.", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}, _capMaxPasses]] Call WFBE_CO_FNC_AICOMLog;
							};
							if (!_capReleased) then {
								//--- Not flipped, still worth retrying: keep the SAD-at-center order live (units stay
								//--- fighting, never idle) and retry on the next loop tick. No remount, no dead end.
								["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] capture pass at [%3] did not flip (res-near=%4) - holding + retrying.", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}, _resNear]] Call WFBE_CO_FNC_AICOMLog;
							};
						};
					} else {
						//--- ===== PURE-ARMOUR DEPOT HOLD (no infantry at all) =====
						//--- This team is tank(s)+crew with NO on-foot soldiers (_footInf is empty: the
						//--- crew stay in their hulls above). The camp "Man" scan (server_town_camp.sqf
						//--- L26) ignores crewed hulls, so a mounted team can never take camps - but it
						//--- does NOT need to: the TOWN depot scan (server_town.sqf L51) is
						//---   nearEntities[["Man","Car","Motorcycle","Tank","Air","Ship"], _capRange]
						//--- and countSide on that set counts a CREWED hull as its crew's side. So a tank
						//--- parked within _capRange (40m) of the depot centre contributes our presence to
						//--- the flip DIRECTLY (drains the town) AND its main gun clears the depot
						//--- defenders. We therefore drive the WHOLE mounted team onto _townCenter, lay a
						//--- live group SAD there at _capRange (mirrors the infantry depot-hold at L1008),
						//--- reveal the garrison, and HOLD in a fight loop until resistance-near-centre is
						//--- zero (town drains + flips) OR a hard timeout - re-pressing stragglers and
						//--- re-issuing the move each tick so the hulls NEVER freeze/idle (MEMORY guardrail).
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] PURE-ARMOUR depot hold at [%3] (no foot infantry; %4 hull(s)).", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}, count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)]] Call WFBE_CO_FNC_AICOMLog;

						//--- WAVE-1 A5 ARMOUR-LATCH: SAD radius = _capRange so the hull parks IN the drain
						//--- ring, not on its 40-60m edge. COMBAT/RED so it actively prosecutes the depot.
						[_team, true, [[_townCenter, 'SAD', _capRange, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						{if (alive _x) then {_x doMove _townCenter}} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
						if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove _townCenter};

						//--- Hold/fight loop (mirror of the infantry depot-hold at L1018): up to the same
						//--- WFBE_C_AICOM_ASSAULT_HOLD window. Exit early once no live resistance remains
						//--- within _capRange of the centre (depot drains + flips). Re-reveal enemy + re-press
						//--- stragglers each tick. Honour the same _capAbort re-task interrupt as the foot path.
						_armHoldEnd = time + (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_HOLD", 360]);
						_armResNear = 1; _armHoldFlipped = false;
						//--- WAVE-2 DRAIN-WAIT (mirror of the infantry depot-hold): hold until the depot actually
						//--- flips to us, not merely until enemies clear - a crewed hull in the 40m ring drains the
						//--- town over many server ticks, so exiting on _armResNear==0 abandoned it before the flip.
						while {time < _armHoldEnd && {!_armHoldFlipped} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
							_capOrdN = _team getVariable "wfbe_aicom_order"; if (isNil "_capOrdN") then {_capOrdN = []};
							if (_capInt && {count _capOrdN >= 1} && {(_capOrdN select 0) != _capSeq}) then {_capAbort = true};
							if (_capAbort) exitWith {}; //--- re-tasked mid armour-hold -> bail; outer loop re-reads the new order
							_armEnemyNear = (_townCenter nearEntities [["Man","Car","Motorcycle","Tank","Air"], _capRange]) unitsBelowHeight 10;
							_armResNear = 0;
							{
								if (alive _x && {side _x != _side} && {side _x != civilian}) then {
									_armResNear = _armResNear + 1;
									_team reveal _x; //--- A2: 2-operand reveal only (array form is A3-only).
								};
							} forEach _armEnemyNear;
							//--- Keep hulls beyond ~60% of _capRange pressing the centre (cheap re-issue, no freeze).
							{if (alive _x && {(_x distance _townCenter) > (_capRange * 0.6)}) then {_x doMove _townCenter}} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
							//--- Early-out if the town already flipped to us.
							if (!isNull _townObj && {(_townObj getVariable ["sideID", -1]) == _sideID}) then {_armHoldFlipped = true};
							sleep 10;
						};
						if (_capAbort) exitWith {}; //--- armour-hold interrupted -> bail BEFORE latching captureDone; outer loop re-reads the new order

						//--- WAVE-1 A5 ARMOUR-LATCH: only latch _captureDone if the town ACTUALLY flipped
						//--- (mirror the infantry _townFlipped check). Otherwise leave it false so the 20s
						//--- order loop re-runs this whole armour-hold next tick and keeps the hull fighting.
						if ((!isNull _townObj) && {(_townObj getVariable ["sideID", -1]) == _sideID}) then {
							_captureDone = true;
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] (armour) CAPTURED [%3] - holding center.", _side, _team, _townObj getVariable ["name","?"]]] Call WFBE_CO_FNC_AICOMLog;
							_team setVariable ["wfbe_teamgoto", objNull, true];
							_team setVariable ["wfbe_aicom_townorder", [], false];
							_team setVariable ["wfbe_teammode", "towns", true];
							_team setVariable ["wfbe_aicom_strike", false, true];
							_team setVariable ["wfbe_aicom_relief", objNull, true];
							_team setVariable ["wfbe_aicom_caplock", [], true];   //--- CAPTURE LOCK CLEAR (GR-2026-07-03a): no longer draining -> re-taskable now.
						} else {
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] (armour) depot pass at [%3] did not flip (res-near=%4) - holding + retrying.", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}, _armResNear]] Call WFBE_CO_FNC_AICOMLog;
						};
					};
				};

				//--- TRUCK-ABANDON (task #16): at the rally, abandon true ground troop-trucks
				//--- (transportSoldier>0, NOT Air/Tank/APC). HOISTED OUT of the _hasCargo gate
				//--- (commander infantry spawn ON FOOT, so _hasCargo is false at the order tick
				//--- and the old placement never fired). Runs in the arrived/same-seq branch,
				//--- once per order via a seq-stamped guard. Dismount driver+crew (+leftover pax)
				//--- and re-task them on foot so no crewed hull and no stranded pax sits idle.
				if (_arrived) then {
					_truckSeq = _team getVariable "wfbe_aicom_trucksabandoned";
					if (isNil "_truckSeq") then {_truckSeq = -1};
					if (_truckSeq != _seq) then {
						_team setVariable ["wfbe_aicom_trucksabandoned", _seq];
						_dismountDest = _dest;
						{
							_abVeh = _x;
							if (!isNull _abVeh && {alive _abVeh}
							    && {!(_abVeh isKindOf "Air")} && {!(_abVeh isKindOf "Tank")} && {!(_abVeh isKindOf "APC")}
							    && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _abVeh) >> "transportSoldier")) > 0}) then {
								_left = [];
								{
									if (alive _x) then {
										unassignVehicle _x;
										[_x] orderGetIn false;
										_left = _left + [_x];
									};
								} forEach (crew _abVeh);
								//--- Re-task every dismounted occupant (driver+crew+any leftover pax).
								{if (alive _x) then {_x doMove _dismountDest}} forEach _left;
								//--- Enroll the abandoned hull with the server husk-collector ONCE per hull.
								if !(_abVeh getVariable ["wfbe_aicom_abandoned", false]) then {
									_abVeh setVariable ["wfbe_aicom_abandoned", true];
									if (isServer) then {
										["aicom-vehicle-abandoned", _abVeh] Call HandleSpecial;
									} else {
										["RequestSpecial", ["aicom-vehicle-abandoned", _abVeh]] Call WFBE_CO_FNC_SendToServer;
									};
								};
							};
						} forEach _vehicles;
					};
				};

				//--- IMMOBILE-ABANDON (task #2): a crewed hull that can no longer move must
				//--- not strand its crew. Dismount and give them an UNCONDITIONAL ground move.
				//--- DEAD-LEADER FIX: destination is the order slot-2 dest (_dest, always in
				//--- scope here); we never unassign/moveOut with no destination. PER-HULL FLAG:
				//--- the husk-enroll RequestSpecial is sent ONCE per hull, not every poll.
				{
					_cv = _x;
					if (!isNull _cv && {alive _cv} && {!(_cv isKindOf "Air")} && {!(canMove _cv)} && {({alive _x} count (crew _cv)) > 0}) then {
						_dropPos = _dest;
						if (!isNull (leader _team) && {alive (leader _team)}) then {
							if (!isNil "_order" && {count _order >= 3}) then {_dropPos = _order select 2};
						};
						{
							if (alive _x) then {
								unassignVehicle _x;
								[_x] orderGetIn false;
								_x doMove _dropPos;
							};
						} forEach (crew _cv);
						//--- Also fall back to a group MOVE waypoint so the team re-forms on the dest.
						if (isNull (leader _team) || {!alive (leader _team)}) then {
							[_team, _dropPos, "MOVE", 50] Spawn WFBE_CO_FNC_WaypointSimple;
						};
						//--- PER-HULL FLAG: enroll the husk ONCE; skip already-flagged hulls so
						//--- RequestSpecial is not re-sent on every 20s poll for the team's lifetime.
						if !(_cv getVariable ["wfbe_aicom_abandoned", false]) then {
							_cv setVariable ["wfbe_aicom_abandoned", true];
							if (isServer) then {
								["aicom-vehicle-abandoned", _cv] Call HandleSpecial;
							} else {
								["RequestSpecial", ["aicom-vehicle-abandoned", _cv]] Call WFBE_CO_FNC_SendToServer;
							};
						};
					};
				} forEach _vehicles;
			};
		};
	};

	//--- B48 SELF-SERVICE (default OFF: WFBE_C_AICOM_SERVICE_ENABLED). A damaged/low-ammo team
	//--- detours to the nearest SAFE friendly town-centre, repairs+rearms+heals, then clears its
	//--- goto so AssignTowns retargets it. The helper enforces every guardrail (never out of
	//--- contact, never frozen, hard en-route timeout). HC-local: the team's units are local here.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_SERVICE_ENABLED", 0]) > 0) then {
		[_team, _side, _sideID, _vehicles] Call WFBE_CO_FNC_AICOMServiceTick;
	};

	//--- AICOM ARTY FIRE (Ray 2026-06-27): if this team owns a self-propelled artillery hull, run tier-scaled fire
	//--- missions on the nearest ENEMY-held town in range. Reuses WFBE_CO_FNC_FireArtillery + the exact ARTYTIMEOUT /
	//--- RANGES_MAX idioms from AI_Commander_Strategy's base-gun path. COOLDOWN scales with the side's ARTYTIMEOUT
	//--- upgrade (must research it); the gun runs dry and auto-rearms at a Service Point (tier-capped fill, above).
	//--- Friendly-fire-guarded. Runs in this same sequential sleep-8 loop (no order fight); only the fire burst Spawns.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_ARTY_ENABLED", 0]) > 0) then {
		private ["_artyHull","_aLogik","_upLvl","_cd","_last","_artyText","_idx2","_maxR","_minR","_tgtT","_tgtP","_ffClear"];
		_artyHull = objNull;
		//--- Ray 2026-06-29 SELF-PROPELLED-ONLY: only fire from a TRACKED/WHEELED self-propelled arty hull (GRAD/MLRS),
		//--- never a static towed gun or mortar emplacement. IsMobileArtillery = IsArtillery!=-1 AND a vehicle chassis
		//--- (Tank/Car/Wheeled_APC/Tracked_APC) AND NOT StaticWeapon. _vehicles only ever holds the team's mounted hulls,
		//--- so in practice this is the GRAD/MLRS; the guard just makes "self-propelled only" explicit + future-proof.
		{ if (alive _x && {[_x, _side] Call IsMobileArtillery} && {!isNull (gunner _x)} && {alive (gunner _x)} && {someAmmo _x}) exitWith {_artyHull = _x} } forEach _vehicles;
		if (!isNull _artyHull && {((missionNamespace getVariable ["WFBE_C_AICOM_ARTY_REQUIRE_TOWN", 0]) <= 0) || {({((_x getVariable ["sideID", -1]) == _sideID) && {(_artyHull distance _x) <= (missionNamespace getVariable ["WFBE_C_AICOM_ARTY_TOWN_RANGE", 300])}} count towns) > 0}}) then { //--- Ray 2026-06-29: SPG fires only when SUPPORTED from a captured town (within ARTY_TOWN_RANGE of a friendly town centre); flag-gated WFBE_C_AICOM_ARTY_REQUIRE_TOWN (default 0=off).
			_aLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;
			_upLvl = if (isNull _aLogik) then {0} else {(_aLogik getVariable ["wfbe_upgrades", [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]]) select WFBE_UP_ARTYTIMEOUT};
			if (typeName _upLvl != "SCALAR") then {_upLvl = 0};
			_cd = (missionNamespace getVariable ["WFBE_C_ARTILLERY_INTERVALS", [550,500,450,400,350,300,250]]) select (_upLvl min 6);
			_last = _artyHull getVariable ["wfbe_aicom_arty_last", -1e9];
			if ((time - _last) >= _cd) then {
				_artyText = str _side;
				_idx2 = [typeOf _artyHull, _side] Call IsArtillery;
				_maxR = ((missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MAX", _artyText]) select _idx2) / ((missionNamespace getVariable ["WFBE_C_ARTILLERY", 1]) max 1);
				//--- MIN-RANGE GATE (Ray): a town inside the gun min range made FireArtillery a no-op but the cooldown was
				//--- still stamped (burned the whole interval). Read the per-side RANGES_MIN (parallel to RANGES_MAX, same
				//--- _idx2) and require the town be at least _minR away, so we never lock onto an un-shootable close target.
				_minR = ((missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MIN", _artyText]) select _idx2);
				if (typeName _minR != "SCALAR") then {_minR = 0};
				_tgtT = objNull; _tgtP = [0,0,0];
				{
					if (((_x getVariable ["sideID", -1]) != _sideID) && {(_x getVariable ["sideID", -1]) >= 0} && {isNull _tgtT} && {(_artyHull distance _x) >= _minR} && {(_artyHull distance _x) <= _maxR}) then {_tgtT = _x; _tgtP = getPos _x};
				} forEach towns;
				if (!isNull _tgtT) then {
					_ffClear = true;
					//--- FF SCAN SHRINK (Ray): the old 400m ring around the TOWN CENTER vetoed every town the AI own infantry was
					//--- assaulting (the normal case) so the gun almost never fired. Shrink to ~80m around the actual aim point.
					{ if (alive _x && {side _x == _side} && {(_x distance _tgtP) < 80}) exitWith {_ffClear = false} } forEach (nearestObjects [_tgtP, ["Man","Car","Tank","Air"], 80]);
					if (_ffClear) then {
						//--- AMMO-TYPE SELECT (claude-gaming 2026-06-29, flag WFBE_C_AICOM_ARTY_AMMOTYPES_ENABLE default OFF):
						//--- pick + load a situational round (illum at night, cluster vs armour) from ONLY the types the side has
						//--- researched (the helper gates on WFBE_UP_ARTYAMMO via GetArtilleryAmmoOptions). Off / HE-only -> default HE.
						[_artyHull, _side, _idx2, _tgtP] Call WFBE_CO_FNC_AICOMArtyPickAmmo;
						[_artyHull, _tgtP, _side, 60] Spawn WFBE_CO_FNC_FireArtillery;
						_artyHull setVariable ["wfbe_aicom_arty_last", time];
						diag_log ("AICOMSTAT|v1|EVENT|" + _artyText + "|" + str (round (time / 60)) + "|FIRE_MISSION_MOBILE|" + (typeOf _artyHull) + "|tier=" + str _upLvl);
					};
				};
			};
		};
	};

	//--- cmdcon41-w2 TOP-UP CONSUMER (Ray: reinforce at friendly towns). Strategy publishes wfbe_aicom_topup_req
	//--- on THIS team as [count, posArray, classArray, issuedTime]; the units are LOCAL here (HC/server that owns the team),
	//--- so we create them straight into _team via the mission helper WFBE_CO_FNC_CreateUnit (same signature as
	//--- Common_RunSidePatrol.sqf:113 - it sets skill, backfills weapons, adds the Killed EH, and honours HC
	//--- locality). Cap creations at 4 per tick; DEFER (keep the request) when a player is within 300m of pos so
	//--- no unit ever pops in a player`s face. A2-OA: GROUP getVariable = plain get + isNil (no [name,default] on
	//--- groups); typeName guards (no A3 isEqualType); clear the var by setting [] and testing count>0 (A2 setVariable
	//--- nil on groups is unreliable). Never create if _team is null. Never-frozen: additions inherit the team order.
	if (_alive && {!isNull _team}) then {
		private ["_topReq","_topN","_topPos","_topCls","_topIssued","_topTtl","_topMade","_topDefer","_topClass","_topUnit"];
		_topReq = _team getVariable "wfbe_aicom_topup_req";
		if (!isNil "_topReq" && {(typeName _topReq) == "ARRAY"} && {count _topReq >= 3}) then {
			_topN   = _topReq select 0;
			_topPos = _topReq select 1;
			_topCls = _topReq select 2;
			_topIssued = time;
			if ((count _topReq) > 3) then {_topIssued = _topReq select 3};
			_topTtl = missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_REQ_TTL", 300];
			if ((typeName _topTtl) != "SCALAR") then {_topTtl = 300};
			if ((typeName _topN) == "SCALAR" && {_topN > 0} && {(typeName _topPos) == "ARRAY"} && {count _topPos >= 2} && {(typeName _topCls) == "ARRAY"} && {count _topCls > 0}) then {
				if ((typeName _topIssued) != "SCALAR") then {_topIssued = time};
				if ((count _topReq) < 4) then {_team setVariable ["wfbe_aicom_topup_req", [_topN, _topPos, _topCls, _topIssued], true]}; //--- legacy 3-slot request: stamp once so it can age out.
				if ((_topTtl > 0) && {(time - _topIssued) > _topTtl}) then {
					_team setVariable ["wfbe_aicom_topup_req", [], true];
					diag_log ("AICOMSTAT|v1|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|TOPUP_REQ_STALE|team=" + (str _team) + "|age=" + str (round (time - _topIssued)) + "|ttl=" + str _topTtl);
				} else {
					//--- DEFER if any player is within 300m of the spawn pos (keep the request untouched for a later tick).
					_topDefer = false;
					{ if (isPlayer _x && {alive _x} && {(_x distance _topPos) < 300}) exitWith {_topDefer = true} } forEach playableUnits;
					if (!_topDefer) then {
						_topMade = 0;
						//--- create up to _topN classes, hard-capped at 4 this tick (cycle the class list by index).
						while {_topMade < _topN && {_topMade < 4}} do {
							_topClass = _topCls select (_topMade mod (count _topCls));
							_topUnit = [_topClass, _team, _topPos, _sideID] Call WFBE_CO_FNC_CreateUnit; //--- canonical mission createUnit-in-group idiom (Common_RunSidePatrol.sqf:113).
							_topMade = _topMade + 1;
						};
						//--- clear the request (A2: set [] and test count>0 next tick, NOT nil).
						_team setVariable ["wfbe_aicom_topup_req", [], true];
						diag_log ("AICOMSTAT|v1|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|TOPUP_DONE|team=" + (str _team) + "|count=" + str _topMade);
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] TOP-UP created %3 reinforcement(s).", _side, _team, _topMade]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			} else {
				//--- Malformed request (bad counts/types): clear it so it cannot loop forever.
				_team setVariable ["wfbe_aicom_topup_req", [], true];
			};
		};
	};

	sleep 8;
};

//--- Team wiped: release the brain's slot.
if (isServer) then {
	["aicom-team-ended", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-ended", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};

if (!isNull _team) then {deleteGroup _team};
