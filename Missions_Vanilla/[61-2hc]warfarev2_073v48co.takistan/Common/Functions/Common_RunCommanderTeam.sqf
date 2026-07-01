/*
	Run one AI-commander combat team: create it and execute the brain's orders locally.
	feat/ai-commander V0.3. Runs on a HEADLESS CLIENT (delegate-aicom-team) or on the
	server as fallback - the whole team lifecycle stays on the creating machine so
	waypoints keep locality (the proven side-patrol pattern).

	 Parameters: [ sideID, template (unit class array), spawnPos ]

	The server brain communicates through ONE public group variable:
	  wfbe_aicom_order = [seq, mode, pos]   (mode: "towns-target" | "defense")
	The driver applies an order once per seq bump: MOVE to pos, SAD on arrival
	(towns-target) or a tight defensive SAD at pos (defense). Team wipe releases
	the slot via aicom-team-ended.
*/

Private ["_townOrderArr","_chkVeh","_sideID","_template","_pos","_side","_team","_retVal","_units","_vehicles","_ldr","_alive","_order","_seq","_lastSeq","_mode","_dest","_arrived",
         "_captureDone","_townObj","_townCamps","_campObj","_campRange",
         "_liveUnits","_dismounted","_veh","_u","_settleTimeout","_hasCargo",
         "_townCenter","_capRange","_footInf","_holdEnd","_resNear","_enemyNear","_townFlipped",
         "_unheldCamps","_campFirstEnd","_nearCamp","_campTgtPos",
         "_airVeh","_grndVehs","_footPax","_cargoSeats","_lifted","_walkers","_lzPos","_flat","_pilot","_crewVeh","_pax","_abVeh","_left","_dropPos","_cv","_dismountDest","_cn","_ud","_heliCost","_truckSeq",
         "_rmHasVeh","_rmRoute","_rmWPs","_usTier",
         "_govLdr","_govNz","_govSteep","_govStrk","_govWantSlow","_govIsSlow","_skillSend","_foundType",
         "_capPasses","_capMaxPasses","_capReleased"];

_sideID = _this select 0;
_template = _this select 1;
_pos = _this select 2;
_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

_pos = [_pos, 30, 120] Call WFBE_CO_FNC_GetRandomPosition;
_pos = [_pos, 40] Call WFBE_CO_FNC_GetEmptyPosition;

_team = [_side, "aicom"] Call WFBE_CO_FNC_CreateGroup;
_retVal = [_template, _pos, _side, true, _team, true, 90] call WFBE_CO_FNC_CreateTeam;
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
	Private ["_hTeam","_hSide","_hOrder","_hDest","_hLdr","_hDir"];
	_hTeam = _this select 0;
	_hSide = _this select 1;
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
			if (isServer) then {
				["aicom-team-heading", [_hTeam, _hDir]] Call HandleSpecial;
			} else {
				["RequestSpecial", ["aicom-team-heading", [_hTeam, _hDir]]] Call WFBE_CO_FNC_SendToServer;
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
		private ["_tm","_sd","_vehs","_h","_tgt","_cannon","_cannonMuzzle","_muzzles","_isGuided","_ammo","_band","_enSide"]; //--- B66 +_cannonMuzzle/_muzzles
		_tm = _this select 0; _sd = _this select 1; _vehs = _this select 2;
		_enSide = if (_sd == west) then {east} else {west};
		while {!WFBE_GameOver && !isNull _tm && {(count ((units _tm) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
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
						{ if (alive _x && {side _x == _enSide} && {(_h distance _x) < _band}) exitWith {_tgt = _x} } forEach ((getPos _h) nearEntities [["Man","Car","Tank","Air"], _band]);
						if (!isNull _tgt) then {
							_h flyInHeight (missionNamespace getVariable ["WFBE_C_AICOM_HELI_GUN_ALT", 35]);
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
		[_airVeh, _lzPos, _flat, _lifted, _team, _pos, _side, _sideID, _heliCost] Spawn {
			private ["_h","_lz","_fl","_pax","_tm","_obj","_t0","_sd","_sID","_cost","_edge","_wsz","_ex","_ey","_offPos","_hcrew"];
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
			(driver _h) doMove _lz;
			_h flyInHeight 60;
			//--- Run in until near the LZ (or timeout / loss).
			_t0 = time + 240;
			waitUntil {sleep 2; time > _t0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {(_h distance _lz) < 120}};
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
				//--- Clamp the heli's exit toward the CLOSEST of the four map edges (worldSize box).
				//--- N-FEATUREBUG-43 fix 2026-06-27: was hardcoded 15360 (Chernarus only) -> the off-map edge math + the
				//--- waitUntil off-map exit test below were 2560m wrong on Takistan/Zargabad (both 12800), so the heli
				//--- either never registered as off-map or refunded early. worldSize is A3-ONLY (A2 OA latent bug), so
				//--- branch the box size off worldName, matching Init_Boundaries.sqf (chernarus=15360, takistan/zargabad=12800).
				_wsz = switch (toLower worldName) do {
					case "chernarus": {15360};
					case "takistan":  {12800};
					case "zargabad":  {12800};
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
			private ["_dLdr","_dSafe","_dNear","_dCombat"];
			_dLdr  = leader _team;
			_dSafe = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_SAFE_DIST", 900];
			_dNear = if (isNull _dLdr) then {0} else {{isPlayer _x && {alive _x} && {(_x distance _dLdr) < _dSafe}} count allUnits};
			_dCombat = if (isNull _dLdr) then {false} else {behaviour _dLdr == "COMBAT"};
			if (_dNear == 0 && {!_dCombat}) then {
				{ if (local _x) then {deleteVehicle _x} } forEach (units _team);
				_alive = false;
				diag_log ("AICOMSTAT|v1|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|TEAM_RETIRE_HC|deleted-local-units");
			} else {
				_team setVariable ["wfbe_aicom_disband", false, true];
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

			if (_seq != _lastSeq) then {
				//--- Fresh order: head out.
				_lastSeq = _seq;
				_arrived = false;
				_captureDone = false;

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
				if (isNil "_usTier") then {_usTier = 0};
				if (_usTier > 0) then {
					[_team, _usTier, _side] Spawn {
						private ["_uTeam","_uTier","_uSide","_uLdr","_uVeh","_uNode","_uRds","_uPlayerNear","_uOnFoot","_uHullDead","_uFootPlayerNear","_uFootRds","_uFootNode"];
						_uTeam = _this select 0;
						_uTier = _this select 1;
						_uSide = _this select 2;
						_uLdr  = leader _uTeam;
						if (isNull _uLdr || {!alive _uLdr}) exitWith {};
						//--- B37 (Ray 2026-06-16): log that the unstuck ACTION fired at this tier, so the
						//--- strike -> fire -> recover lifecycle is visible (UNSTUCK_STRIKE -> UNSTUCK_FIRED ->
						//--- next ASSAULT_STRANDED moved=).
						diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|UNSTUCK_FIRED|team=" + (str _uTeam) + "|tier=" + str _uTier);
						//--- B37 RE-MOUNT (Ray's mechanized-infantry ask): any team member on foot but with a live,
						//--- drivable assigned vehicle is ordered back in, so infantry that fell out during the stall
						//--- actually rides to the objective instead of walking/idling.
						{ if (alive _x && {vehicle _x == _x} && {!isNull (assignedVehicle _x)} && {alive (assignedVehicle _x)} && {canMove (assignedVehicle _x)}) then {[_x] orderGetIn true} } forEach (units _uTeam);
						_uVeh = vehicle _uLdr;
						//--- Tier 1: break a physical wedge on the lead hull.
						if (!isNull _uVeh && {_uVeh != _uLdr} && {alive _uVeh} && {canMove _uVeh}) then {
							_uVeh setVelocity [0,0,0];
							_uLdr doMove (_uVeh modelToWorld [0,-14,0]); //--- short reverse-ish nudge.
							sleep 4;
						};
						//--- Tier 3: last-resort teleport-nudge to the nearest clear road node,
						//--- only if no player is close enough to witness it.
						if (_uTier >= 3 && {!isNull _uVeh} && {alive _uVeh}) then {
							_uPlayerNear = false;
							{ if (isPlayer _x && {(_x distance _uVeh) < 100}) then {_uPlayerNear = true} } forEach playableUnits;
							if (!_uPlayerNear) then {
								_uRds = (getPos _uVeh) nearRoads 150;
								if (count _uRds > 0) then {
									_uNode = [getPos _uVeh, _uRds] Call WFBE_CO_FNC_GetClosestEntity;
									if (!isNull _uNode && {!surfaceIsWater (getPos _uNode)}) then {
										_uVeh setVelocity [0,0,0];
										_uVeh setPos (getPos _uNode);
										["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] TIER3 unstuck teleport-nudge to road node.", _uSide, _uTeam]] Call WFBE_CO_FNC_AICOMLog;
									};
								};
							};
						};
						//--- B (Ray 2026-06-29 A/B): a player within 100m blocks the teleport, so un-wedge the lead hull with a small upward velocity hop - it breaks terrain friction and visibly bumps the hull free instead of leaving it frozen in the player's view (never-frozen guardrail). The fresh MOVE route below re-applies the order.
						if (_uTier >= 3 && {!isNull _uVeh} && {alive _uVeh}) then { private "_bNear"; _bNear = false; { if (isPlayer _x && {(_x distance _uVeh) < 100}) then {_bNear = true} } forEach playableUnits; if (_bNear) then { _uVeh setVelocity [(velocity _uVeh) select 0, (velocity _uVeh) select 1, 4] } };
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
						if (_uTier >= 3 && {_uOnFoot || _uHullDead}) then {
							_uFootPlayerNear = false;
							{ if (isPlayer _x && {(_x distance _uLdr) < 100}) then {_uFootPlayerNear = true} } forEach playableUnits;
							if (!_uFootPlayerNear) then {
								_uFootRds = (getPos _uLdr) nearRoads 150;
								if (count _uFootRds > 0) then {
									_uFootNode = [getPos _uLdr, _uFootRds] Call WFBE_CO_FNC_GetClosestEntity;
									if (!isNull _uFootNode && {!surfaceIsWater (getPos _uFootNode)}) then {
										_uLdr setVelocity [0,0,0];
										_uLdr setPos (getPos _uFootNode);
										//--- Re-form the squad on the relocated leader so dismounts/stragglers regroup (never idle).
										{ if (alive _x && {_x != _uLdr} && {vehicle _x == _x}) then {_x doFollow _uLdr} } forEach (units _uTeam);
										["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] TIER3 FOOT/dead-hull unstuck teleport-nudge to road node (re-formed on leader).", _uSide, _uTeam]] Call WFBE_CO_FNC_AICOMLog;
									};
								};
							};
						};
					};
				};

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
					_team setBehaviour "AWARE";
					_team setCombatMode "RED";        //--- STANCE (task #1): advance-and-engage on the march (was YELLOW).
					_team setFormation "COLUMN";
					_team setSpeedMode "FULL";         //--- STANCE (task #1): full road-march speed (was NORMAL).

					//--- Pull the road-node chain the server snapped for this seq (may be empty).
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_rmRoute = _team getVariable "wfbe_aicom_route";
					if (isNil "_rmRoute") then {_rmRoute = []};

					//--- Build the waypoint list: each road node as a COLUMN/NORMAL MOVE, then a
					//--- final MOVE on the destination so the arrival branch (leader<200m) trips.
					_rmWPs = [];
					{
						_rmWPs = _rmWPs + [[_x, 'MOVE', 40, 30, [], [], ["AWARE","RED","","FULL"]]];  //--- STANCE (task #1): RED/FULL advance-and-engage (was YELLOW/NORMAL). A2-fix 2026-06-14: inherit-formation (was COLUMN-locked) + wider completion 30 so columns open through chokepoints instead of bunching
					} forEach _rmRoute;
					_rmWPs = _rmWPs + [[_dest, 'MOVE', 50, 30, [], [], ["AWARE","RED","COLUMN","FULL"]]];  //--- STANCE (task #1): RED/FULL final-approach (was YELLOW/NORMAL).
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
					[_team, true, [[_dest, 'MOVE', 50, 30, [], [], ["AWARE","RED","COLUMN","FULL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd; //--- B66 (was [_team,_dest,'MOVE',50] Spawn WFBE_CO_FNC_WaypointSimple - empty props)
					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 %4 FOOT FAST-TRANSIT (column).", _side, _team, _seq, _mode]] Call WFBE_CO_FNC_AICOMLog;
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
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_govStrk = _team getVariable "wfbe_aicom_unstuck";
					if (isNil "_govStrk") then {_govStrk = 0};
					_govWantSlow = _govSteep || {_govStrk > 0};
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
					if ((leader _team) distance _dest < ((missionNamespace getVariable ["WFBE_C_TOWNS_CAPTURE_RANGE", 40]) + 20)) then {
						_arrived = true;
						//--- Cosmetic: faction smoke at assault onset (fires once per team via the _arrived latch). Server-only, gated + capped + cooldown.
						[getPosATL (leader _team), side _team] call WFBE_CO_FNC_SpawnFactionSmoke;
						//--- ROAD-MARCH hand-off: at the objective we WANT overland combat, so
						//--- release the road bias and assault with COMBAT/WEDGE (was empty props,
						//--- which left the SAD at engine defaults). Feed real squad-props through
						//--- WaypointsAdd so behaviour/formation actually apply.
						//--- (A2-fix: removed the A3-only forceFollowRoad clear; COMBAT/WEDGE props set the assault posture.)
						_team setSpeedMode "NORMAL";
						if (_mode == "defense") then {
							[_team, true, [[_dest, 'SAD', 100, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						} else {
							[_team, true, [[_dest, 'SAD', (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_SAD", 80]), 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd; //--- punchy-AICOM (Ray 2026-06-17): 250 -> WFBE_C_AICOM_ASSAULT_SAD (80m). Tighter approach SAD = the squad closes onto the objective instead of roving a 250m ring.
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
								sleep 45;
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
						private ["_campStallPasses","_campLastUnheld","_campStallMax"];
						_campStallPasses = 0;
						_campLastUnheld  = count _unheldCamps;
						_campStallMax    = missionNamespace getVariable ["WFBE_C_AICOM_CAMP_STALL_PASSES", 3];
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
							if (_campStallMax > 0 && {_campStallPasses >= _campStallMax}) exitWith {
								["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] camp-first NO-PROGRESS after %3 passes (%4 camp(s) still un-held) - proceeding to town centre.", _side, _team, _campStallPasses, count _unheldCamps]] Call WFBE_CO_FNC_AICOMLog;
							};
						};
						//--- Release the plant so the depot-centre hold below can march these units on
						//--- (setUnitPos "UP" pins stance; "AUTO" hands movement back to the AI).
						{if (alive _x) then {_x setUnitPos "AUTO"; _x doFollow (leader _team)}} forEach _footInf; //--- B69: doFollow clears the sticky doStop from the camp plant (setUnitPos alone does NOT), so an interrupted team is never left frozen; the next order's waypoints take over.
							if (_capAbort) exitWith {}; //--- B69: camp-first interrupted (plant released above so no frozen units) -> bail capture phase; outer loop re-tasks.
						if (count _unheldCamps > 0) then {
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] camp-first window expired with %3 camp(s) un-held at [%4] - proceeding to center.", _side, _team, count _unheldCamps, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}]] Call WFBE_CO_FNC_AICOMLog;
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
						[_team, true, [[_townCenter, 'SAD', _capRange, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						{if (alive _x) then {_x doMove _townCenter}} forEach _footInf;
						if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove _townCenter};

						//--- Hold/fight loop: up to ~150s. Exit early once no live resistance remains
						//--- within the capture radius of the depot (the contested _skip clears -> the
						//--- town drains and flips). Re-reveal enemy each tick. Every iteration leaves
						//--- units on a live SAD order (never idle).
						_holdEnd = time + (missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_HOLD", 360]); //--- punchy-AICOM (Ray 2026-06-17): hard-coded 150 -> WFBE_C_AICOM_ASSAULT_HOLD (360). Longer depot-center hold = the team holds long enough to drain + flip the town.
						_resNear = 1;
						while {time < _holdEnd && {_resNear > 0} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
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
							//--- Keep stragglers pressing the center (cheap re-issue, prevents drift).
							//--- WAVE-1 A4: re-press units beyond ~60% of _capRange (was max 25). Units inside the 40m ring
							//--- but past ~24m get pulled to the exact center so the depot-center presence scan ticks.
							{if (alive _x && {(_x distance _townCenter) > (_capRange * 0.6)}) then {_x doMove _townCenter}} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
							//--- Early-out if the town already flipped to us.
							if (!isNull _townObj && {(_townObj getVariable ["sideID", -1]) == _sideID}) then {_resNear = 0};
							sleep 10;
						};

						//--- Latch only if the town is now OURS; otherwise leave _captureDone false so
						//--- the 20s order loop re-runs this whole phase next tick and keeps fighting.
						if (_capAbort) exitWith {}; //--- B69: depot-hold interrupted -> bail BEFORE latching captureDone; outer loop re-reads the new order
						_townFlipped = (!isNull _townObj) && {(_townObj getVariable ["sideID", -1]) == _sideID};
						if (_townFlipped) then {
							_captureDone = true;
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] CAPTURED [%3] - holding center.", _side, _team, _townObj getVariable ["name","?"]]] Call WFBE_CO_FNC_AICOMLog;
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
								_capPasses = ([_team, "wfbe_aicom_cappasses", 0] Call WFBE_CO_FNC_GroupGetBool) + 1;
								_team setVariable ["wfbe_aicom_cappasses", _capPasses];
							};
							_capReleased = false;
							if (([_team, "wfbe_aicom_cappasses", 0] Call WFBE_CO_FNC_GroupGetBool) >= _capMaxPasses) then {
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
						_armResNear = 1;
						while {time < _armHoldEnd && {_armResNear > 0} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
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
							if (!isNull _townObj && {(_townObj getVariable ["sideID", -1]) == _sideID}) then {_armResNear = 0};
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

	sleep 8;
};

//--- Team wiped: release the brain's slot.
if (isServer) then {
	["aicom-team-ended", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-ended", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};

if (!isNull _team) then {deleteGroup _team};
