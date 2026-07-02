//--- ===================================================================
//--- Common_AICOMAirLeg.sqf  (WFBE_CO_FNC_AICOMAirLeg)
//--- cmdcon42-f AIR-MOBILE ORDERS (Ray 2026-07-02, gate WFBE_C_AICOM_AIRMOBILE default-ON).
//---
//--- An AICOM team that STILL HAS its own live transport helicopter FLIES an ORDERED leg
//--- instead of road-marching, and at the destination runs the SAME hot-LZ decision the
//--- FOUNDING air-insert uses (c2ee728b2, Common_RunCommanderTeam.sqf ~L506-630):
//---   cold LZ      -> heli lands + GETS OUT (isFlatEmpty insert),
//---   contested/enemy town -> heli holds altitude + PARADROPS the pax ~OFFSET m short.
//--- After the drop the transport RETURNS toward the side HQ/base and HOLDS/lands there for
//--- the NEXT order (it IS the team's vehicle - it PERSISTS, never fly-off-refunded here) via
//--- the SHARED WFBE_CO_FNC_AICOMAirReturn - the founding retained-transport path
//--- (WFBE_C_AICOM_AIR_RETAIN, default-ON) routes through the SAME code. The dropped pax always get an
//--- unconditional ground doMove to the objective so the order loop's arrival latch + MOVE/SAD
//--- capture chain folds them in EXACTLY like a road-marched or landed insert (Hook-B sees a
//--- normal arrival). NEVER-FROZEN: every branch ends in a live pax move; the team is flagged
//--- airborne so the AssignTowns stuck-watcher does not teleport a flying leader mid-flight.
//---
//--- ARGS: [_h, _team, _dest, _side, _sideID, _teamVehs]
//---   _h        : the team's own live transport helicopter (alive, driver alive, has fuel).
//---   _team     : the AICOM group.
//---   _dest     : destination position (the ordered town, slot 2 of wfbe_aicom_order).
//---   _side     : side of the team.
//---   _sideID   : side id (for telemetry).
//---   _teamVehs : (cmdcon42-l, optional) the team's authoritative hull list (_vehicles in the caller). Used to
//---               pick a LIGHT ground vehicle to SLING + deep-drop behind the lines. Omitted = no vehicle lift.
//--- Runs the leg in ONE self-contained Spawn (non-blocking). No new per-tick loop.
//---
//--- A2-OA-1.64 SAFE: getVariable "sideID" on a TOWN OBJECT ([name,default] form is object-legal;
//--- only GROUPS reject it), getFriend / nearEntities / isFlatEmpty / land "GET OUT" / action
//--- ["EJECT"], atan2 position-delta bearing (binary getDir is A3-only), setFuel/flyInHeight/doMove.
//--- No isEqualType, no ==/!= on Booleans, no worldSize.
//--- ===================================================================

private ["_h","_team","_dest","_side","_sideID","_teamVehs"];
_h      = _this select 0;
_team   = _this select 1;
_dest   = _this select 2;
_side   = _this select 3;
_sideID = _this select 4;
_teamVehs = if (count _this > 5) then {_this select 5} else {[]}; //--- cmdcon42-l: team hull list (may be omitted by older callers).
if (isNil "_teamVehs" || {typeName _teamVehs != "ARRAY"}) then {_teamVehs = []};

if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {isNull _team}) exitWith {false};

//--- FUEL GUARD: AUTOFUEL (Common_RunCommanderTeam order loop) keeps AICOM hulls fed, but be
//--- belt-and-braces - top the transport off before a long leg so it never strands mid-flight.
if ((fuel _h) < 0.35) then {_h setFuel 1};

//--- Load the team's on-FOOT infantry into the transport (cargo seats only; crew/driver excluded).
private ["_footPax","_cargoSeats","_lifted","_walkers"];
_footPax = [];
{
	if (alive _x && {vehicle _x == _x} && {_x != (driver _h)}) then {_footPax = _footPax + [_x]};
} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);

_cargoSeats = _h emptyPositions "cargo";
_lifted  = [];
_walkers = [];
{
	if (count _lifted < _cargoSeats) then {
		_x assignAsCargo _h;
		[_x] orderGetIn true;
		_lifted = _lifted + [_x];
	} else {
		_walkers = _walkers + [_x];
	};
} forEach _footPax;

//--- Nobody to lift (all crew, or heli full-of-crew): no air leg - the caller road-marches instead.
if (count _lifted == 0) exitWith {false};

//--- Overflow that did not fit walks by ground NOW toward the objective (never idle).
{if (alive _x) then {_x doMove _dest}} forEach _walkers;

//--- ===================================================================
//--- HOT-LZ PARADROP DECISION (mirror of the founding block c2ee728b2). Pick an LZ: prefer a flat
//--- spot at the objective; else the raw dest. Then decide land-vs-paradrop:
//---   (a) the LZ's nearest town is not our side (town getVariable "sideID"; neutral/GUER/enemy all
//---       jump-worthy), OR (b) any hostile ((side _team) getFriend (side _x) < 0.6) inside *_SCAN_R.
//--- On a hot LZ resolve a drop point *_OFFSET m SHORT of the town centre, back along the heli->town
//--- approach vector, and force the para branch (empty flat-list) so the transport ejects short.
//--- ===================================================================
private ["_lzPos","_flat","_forceDrop","_dropLz","_hotTown","_hotReason"];
_lzPos = _dest;
_flat  = _dest isFlatEmpty [12, 0, 2, 12, 0, false, objNull];
if (count _flat > 0) then {_lzPos = _flat} else {_lzPos = _dest};

_forceDrop = false;
_dropLz    = _lzPos;
_hotReason = "";
if ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_PARADROP", 1]) > 0) then {
	_hotTown = objNull;
	if (count towns > 0) then {_hotTown = [_lzPos, towns] Call WFBE_CO_FNC_GetClosestEntity};
	if (!isNull _hotTown && {(_hotTown getVariable ["sideID", -1]) != _sideID}) then {
		_forceDrop = true;
		_hotReason = "enemy-town";
	};
	if (!_forceDrop) then {
		private ["_scanR","_hostiles"];
		_scanR = missionNamespace getVariable ["WFBE_C_AICOM_AIR_PARADROP_SCAN_R", 400];
		_hostiles = {!isNull _x && {alive _x} && {((side _team) getFriend (side _x)) < 0.6}} count (_lzPos nearEntities [["Man","LandVehicle","Tank"], _scanR]);
		if (_hostiles > 0) then {
			_forceDrop = true;
			_hotReason = "contested";
		};
	};
	if (_forceDrop) then {
		private ["_offset","_tc","_hp","_brg","_seg","_tcName"];
		_offset = missionNamespace getVariable ["WFBE_C_AICOM_AIR_PARADROP_OFFSET", 250];
		_tc = if (!isNull _hotTown) then {getPos _hotTown} else {_lzPos};
		_hp = getPos _h;                                          //--- heli origin = approach source.
		_seg = _hp distance _tc;
		if (_seg > 5) then {
			//--- bearing heli -> town (A2-safe atan2 position-delta; binary getDir is A3-only).
			_brg = ((_tc select 0) - (_hp select 0)) atan2 ((_tc select 1) - (_hp select 1));
			if (_offset > (_seg - 20)) then {_offset = (_seg - 20) max 0};
			_dropLz = [ (_tc select 0) - (_offset * sin _brg), (_tc select 1) - (_offset * cos _brg), 0 ];
		} else {
			_dropLz = _lzPos;
		};
		_tcName = if (!isNull _hotTown) then {_hotTown getVariable ["name","?"]} else {"pos"};
		diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|AIRMOBILE_PARADROP|team=" + (str _team) + "|town=" + _tcName + "|reason=" + _hotReason);
		["INFORMATION", Format ["Common_AICOMAirLeg.sqf: [%1] team [%2] AIR-MOBILE hot-LZ paradrop into [%3] (reason %4) - ejecting %5m short.", _side, _team, _tcName, _hotReason, _offset]] Call WFBE_CO_FNC_AICOMLog;
	};
};
//--- Hot LZ: hand the fly-in the OFFSET drop point + an EMPTY flat-list so the land-gate is false -> eject.
if (_forceDrop) then {_lzPos = _dropLz; _flat = []};

//--- AIRBORNE EXEMPTION: stamp a generous "team is flying this leg" window so the AssignTowns
//--- position-stuck watcher does NOT flag a flying leader as stuck / teleport the team mid-flight.
//--- Broadcast so the SERVER (where AssignTowns runs) reads it; the leg-runner refreshes it in flight.
_team setVariable ["wfbe_aicom_airborne_until", time + 600, true];

//--- ===================================================================
//--- cmdcon42-l VEHICLE AIRLIFT (Ray 2026-07-02: "can AI also lift vehicles? and drop them like 1-2k behind
//--- the lines?"; gate WFBE_C_AICOM_VEHLIFT default-ON). If this team owns a LIGHT ground vehicle, the transport
//--- SLINGS it below the hull (attachTo) and, after the pax insert, deep-drops it *_DEPTH m BEYOND the ordered
//--- town along the town->enemy-HQ (enemy-rear) axis, so the vehicle + crew land 1-2km BEHIND the lines and
//--- attack the objective from the REAR (Ray's flanking intent). Decisions made HERE (driver context = _h is
//--- LOCAL, so the attachTo/detach later run where the heli is local, as required):
//---   ELIGIBILITY - TIERED BY THE SIDE'S AIR-FACTORY RESEARCH (Ray expansion: "BTR/LAV/Stryker should be
//---     included, at higher AF tiers heavier vehicles as well"). One tier-resolve per leg via the same
//---     GetSideUpgrades/WFBE_UP_AIR read the roster rows use (AIR research has 5 levels; ICBM deps prove L5):
//---       TIER 1 (AIR < *_T2_AIR [2]): "Car" AND NOT "Wheeled_APC" AND armor <= *_MAXARMOR (150) - armed
//---         HMMWVs incl. M2 (120)/CROWS (100)/Avenger (150), UAZs, Vodniks (85-100), technicals, light trucks.
//---       TIER 2 (AIR >= 2): ALSO Wheeled_APC-family with armor <= *_T2_MAXARMOR (200) - BTR-60 (120),
//---         LAV-25/BTR-90 (150), Strykers (160) become liftable (the NOT-Wheeled_APC clause drops here).
//---       TIER 3 (AIR >= *_T3_AIR [4]): ANY LandVehicle with armor <= *_T3_MAXARMOR (400) - tracked IFVs
//---         (BMP-2 250, Bradley 300/400) join; MBTs stay excluded NATURALLY by armor (T-72 690, M1A1 850).
//---     Never Air/Ship (LandVehicle-only at every tier; candidates are pre-filtered NOT-Air). The *_ALLOW
//---     base-class fallback (armour-misread, still gated NOT-Wheeled_APC/NOT-Tank) stays as the tier-1 net.
//---     It must be alive, canMove, NOT the transport. ONE lift per leg (first match wins). LIFTER: any
//---     transport lifts anything (arcade-lore by design - no heavy-lifter preference; teams own ONE transport
//---     and the -7 sling hangs the same for every hull, it's a game).
//---   SURVIVAL GUARD: skip the lift if this vehicle is the team's ONLY drivable ground transport (never lift
//---     what the team needs to survive - only lift a SPARE light vehicle).
//---   DROP POINT: *_DEPTH (+-300 jitter) BEYOND _dest along the _dest->enemy-HQ bearing (A2-safe atan2 delta;
//---     enemy HQ = opposite side's HQ; if null, fall back to the _dest->_h approach-reverse so we still drop
//---     on the far side). Must clear surfaceIsWater=false + a cheap isFlatEmpty check; if it fails, shorten
//---     depth in 300m steps toward _dest, floor at _dest itself.
//--- The heavy lifting (sling below, fly the pax leg, then continue to the deep drop, detach + ground-snap,
//--- then AICOMAirReturn) happens in the flight Spawn below. A2-OA-safe: getNumber config read, isKindOf,
//--- atan2 position-delta bearing, surfaceIsWater, isFlatEmpty, attachTo/detach, setVelocity/setPos. No A3
//--- commands, no isEqualType, no ==/!= on Booleans.
//--- ===================================================================
private ["_liftVeh","_vehDrop"];
_liftVeh = objNull;
_vehDrop = [];
if ((missionNamespace getVariable ["WFBE_C_AICOM_VEHLIFT", 1]) > 0) then {
	private ["_maxArmor","_allow","_grndCount","_liftTier","_t2Max","_t3Max"];
	_maxArmor = missionNamespace getVariable ["WFBE_C_AICOM_VEHLIFT_MAXARMOR", 150];
	_t2Max    = missionNamespace getVariable ["WFBE_C_AICOM_VEHLIFT_T2_MAXARMOR", 200];
	_t3Max    = missionNamespace getVariable ["WFBE_C_AICOM_VEHLIFT_T3_MAXARMOR", 400];
	_allow    = missionNamespace getVariable ["WFBE_C_AICOM_VEHLIFT_ALLOW", ["Car"]];
	//--- TIER RESOLVE (once per leg): the side's AIR-FACTORY research level gates how heavy a hull the
	//--- transport may sling. Same GetSideUpgrades/WFBE_UP_AIR read the roster rows + supplyMission use;
	//--- count-guarded so a short/empty upgrade array (GUER zero-array) degrades to tier 1, never errors.
	private ["_upgV","_airLvl"];
	_liftTier = 1;
	_airLvl = 0;
	_upgV = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
	if (!isNil "_upgV" && {typeName _upgV == "ARRAY"} && {count _upgV > WFBE_UP_AIR}) then {_airLvl = _upgV select WFBE_UP_AIR};
	if (_airLvl >= (missionNamespace getVariable ["WFBE_C_AICOM_VEHLIFT_T2_AIR", 2])) then {_liftTier = 2};
	if (_airLvl >= (missionNamespace getVariable ["WFBE_C_AICOM_VEHLIFT_T3_AIR", 4])) then {_liftTier = 3};
	//--- Count the team's own drivable GROUND transports (non-air, canMove) so we never lift the team's ONLY
	//--- one (never lift what the team needs to survive). _teamVehs = the caller's authoritative hull list.
	_grndCount = { !isNull _x && {alive _x} && {!(_x isKindOf "Air")} && {canMove _x} } count _teamVehs;
	//--- Pick the FIRST eligible ground vehicle owned by the team (first match wins = ONE lift per leg).
	{
		if (isNull _liftVeh && {!isNull _x} && {alive _x} && {canMove _x} && {!(_x isKindOf "Air")} && {_x != _h}) then {
			private ["_type","_armor","_isLight","_isAllow"];
			_type  = typeOf _x;
			_armor = getNumber (configFile >> "CfgVehicles" >> _type >> "armor");
			//--- TIER 1 (always on): a "Car" that is NOT a "Wheeled_APC" at/below the light ceiling
			//--- (Wheeled_APC derives FROM Car in A2, so the NOT-clause is load-bearing at this tier).
			_isLight = (_armor > 0) && {_armor <= _maxArmor} && {_x isKindOf "Car"} && {!(_x isKindOf "Wheeled_APC")};
			//--- TIER 2 (AIR >= T2_AIR): Wheeled_APC-family joins - BTR-60/90, LAV-25, Strykers.
			if (!_isLight && {_liftTier >= 2}) then {
				_isLight = (_armor > 0) && {_armor <= _t2Max} && {_x isKindOf "Wheeled_APC"};
			};
			//--- TIER 3 (AIR >= T3_AIR): ANY LandVehicle at/below the heavy ceiling - tracked IFVs (BMP-2 250,
			//--- Bradley 300/400) join; MBTs (T-72 690, M1A1 850) stay excluded naturally by armor. LandVehicle
			//--- keeps Air/Ship out at every tier.
			if (!_isLight && {_liftTier >= 3}) then {
				_isLight = (_armor > 0) && {_armor <= _t3Max} && {_x isKindOf "LandVehicle"};
			};
			//--- Allowlist fallback (armour read 0/unreliable): a base-class match, still gated NOT-Wheeled_APC/NOT-Tank.
			_isAllow = false;
			if (!_isLight && {!(_x isKindOf "Wheeled_APC")} && {!(_x isKindOf "Tank")}) then {
				private "_ax"; _ax = _x;
				{ if (!_isAllow && {_ax isKindOf _x}) then {_isAllow = true} } forEach _allow;
			};
			if (_isLight || _isAllow) then {
				//--- SURVIVAL GUARD: never lift the team's ONLY drivable ground transport.
				if (_grndCount > 1) then {_liftVeh = _x};
			};
		};
	} forEach _teamVehs;

	if (!isNull _liftVeh) then {
		//--- Compute the DEEP drop point: *_DEPTH (+-300 jitter) BEYOND _dest along the _dest->enemy-rear bearing.
		private ["_depth","_enemySide","_eHQ","_refPos","_brg","_dx","_dy","_tryDepth","_ok","_candPos"];
		_depth = (missionNamespace getVariable ["WFBE_C_AICOM_VEHLIFT_DEPTH", 1500]) + (round (random 600) - 300);
		//--- enemy rear = the enemy HQ direction FROM _dest. Resolve the enemy side (A2-OA: switch on Side).
		_enemySide = switch (_side) do { case west: {east}; case east: {west}; default {sideEnemy} };
		_eHQ = _enemySide Call WFBE_CO_FNC_GetSideHQ;
		if (!isNull _eHQ && {alive _eHQ}) then {_refPos = getPos _eHQ} else {_refPos = []};
		//--- bearing _dest -> enemy rear (atan2 position-delta; binary getDir is A3-only). If no HQ, reverse the
		//--- heli->dest approach so we still push to the FAR side of the town.
		if (count _refPos > 0) then {
			_brg = ((_refPos select 0) - (_dest select 0)) atan2 ((_refPos select 1) - (_dest select 1));
		} else {
			private "_hp0"; _hp0 = getPos _h;
			_brg = ((_dest select 0) - (_hp0 select 0)) atan2 ((_dest select 1) - (_hp0 select 1));
		};
		//--- Project along the bearing, then water+flatness-guard the candidate, shortening depth in 300m steps
		//--- toward _dest (floor at _dest itself = depth 0) until it is on dry, roughly-flat ground. The floor
		//--- IS the dest (depth 0), which is guaranteed on-land (a team is being ordered there), so the loop
		//--- always terminates with a usable point. A2-OA-safe: surfaceIsWater + isFlatEmpty (both used above).
		_tryDepth = _depth;
		_ok = false;
		_vehDrop = _dest; //--- floor default; overwritten by the first dry/flat candidate.
		while {!_ok} do {
			if (_tryDepth < 0) then {_tryDepth = 0}; //--- clamp: the last try is dest itself (depth 0).
			_dx = (_dest select 0) + (_tryDepth * sin _brg);
			_dy = (_dest select 1) + (_tryDepth * cos _brg);
			_candPos = [_dx, _dy, 0];
			if (!(surfaceIsWater _candPos)) then {
				private "_fe";
				_fe = _candPos isFlatEmpty [15, 0, 3, 15, 0, false, objNull];
				if (count _fe > 0) then {_vehDrop = _fe} else {_vehDrop = _candPos};
				_ok = true;
			};
			if (!_ok) then {
				if (_tryDepth <= 0) exitWith {_vehDrop = _dest; _ok = true}; //--- even dest is water (rare): use it anyway, loop ends.
				_tryDepth = _tryDepth - 300;
			};
		};

		//--- SLING the vehicle below the transport. Zeta_Init proves the A2 heli sling idiom (Zeta_DefaultPos
		//--- [0,0,-10] for helis); the founding vehicle-paradrop (Support_ParaVehicles) uses [0,0,-3]. The MH60/
		//--- UH60/CH47/Mi17 hulls differ in belly clearance, so use a conservative fixed -7 (clears every hull's
		//--- rotor/skid geometry, well under the terrain guard's 60m climb clearance - the sling can never
		//--- ground-clip while the guard holds the heli >= 60m up). Crew of the lifted vehicle STAYS ABOARD IT:
		//--- A2 attachTo carries the occupants with the hull (verified vs Support_ParaVehicles, which slings a
		//--- crewed cargo vehicle the same way), so no dismount/remount dance is needed - on detach the crew
		//--- ride it down and drive off the drop.
		_liftVeh attachTo [_h, [0, 0, -7]];
		_liftVeh setVariable ["wfbe_aicom_slung", true, true]; //--- mark so nothing else reaps/re-tasks a slung hull mid-flight.
		diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|VEHLIFT|team=" + (str _team) + "|veh=" + (typeOf _liftVeh) + "|depth=" + str (round (_liftVeh distance _vehDrop)) + "|tier=" + str _liftTier);
		["INFORMATION", Format ["Common_AICOMAirLeg.sqf: [%1] team [%2] SLINGS %3 (lift tier %4) for a deep drop %5m behind %6 (enemy-rear flank).", _side, _team, typeOf _liftVeh, _liftTier, round _depth, _dest]] Call WFBE_CO_FNC_AICOMLog;
	};
};

diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|AIRMOBILE_LEG|team=" + (str _team) + "|lifted=" + str (count _lifted) + "|walked=" + str (count _walkers) + "|dist=" + str (round ((leader _team) distance _dest)));
["INFORMATION", Format ["Common_AICOMAirLeg.sqf: [%1] team [%2] AIR-MOBILE leg via %3 (lifted %4, walked %5).", _side, _team, typeOf _h, count _lifted, count _walkers]] Call WFBE_CO_FNC_AICOMLog;

//--- ===================================================================
//--- FLY THE LEG in ONE self-contained Spawn (non-blocking; mirrors the founding disembark Spawn
//--- L584-689, minus the fly-off/refund - the transport RETURNS to base + HOLDS to persist).
//--- ===================================================================
[_h, _lzPos, _flat, _lifted, _team, _dest, _side, _sideID, _liftVeh, _vehDrop] Spawn {
	private ["_h","_lz","_fl","_pax","_tm","_obj","_sd","_sID","_t0","_lveh","_vdrop"];
	_h    = _this select 0;
	_lz   = _this select 1;
	_fl   = _this select 2;
	_pax  = _this select 3;
	_tm   = _this select 4;
	_obj  = _this select 5;
	_sd   = _this select 6;
	_sID  = _this select 7;
	_lveh = _this select 8;   //--- slung LIGHT ground vehicle (objNull if no lift this leg).
	_vdrop= _this select 9;   //--- its DEEP drop point behind the lines (empty if no lift).

	//--- Let everyone board first (bounded).
	_t0 = time + 30;
	waitUntil {sleep 1; time > _t0 || {({alive _x && vehicle _x == _h} count _pax) >= ({alive _x} count _pax)}};
	if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
		//--- Heli lost mid-lift: any survivors still aboard/around get an unconditional move.
		{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;
		//--- Slung vehicle: detach + ground-snap where it hangs so it is not lost with the heli; crew drive to the objective.
		if (!isNull _lveh && {alive _lveh}) then {
			detach _lveh; _lveh setVelocity [0,0,0];
			_lveh setPos [(getPos _lveh) select 0, (getPos _lveh) select 1, 0.5];
			_lveh setVariable ["wfbe_aicom_slung", false, true];
			{if (alive _x) then {_x doMove _obj}} forEach (crew _lveh);
		};
		_tm setVariable ["wfbe_aicom_airborne_until", 0, true];
	};

	//--- Run in to the LZ at altitude. Refresh the airborne exemption every leg-tick so a long
	//--- flight never lets the server stuck-watcher window lapse mid-air.
	_approachLimited = (missionNamespace getVariable ["WFBE_C_AICOM_HELI_APPROACH_LIMITED", 0]) > 0;
	if (_approachLimited) then {(group (driver _h)) setSpeedMode "LIMITED"};
	(driver _h) doMove _lz;
	_h flyInHeight (60 max (missionNamespace getVariable ["WFBE_C_AICOM_HELI_RUNINFLOOR", 0]));
	_t0 = time + 240;
	waitUntil {
		sleep 2;
		_tm setVariable ["wfbe_aicom_airborne_until", time + 120, true];
		time > _t0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {(_h distance _lz) < 120}
	};
	if (_approachLimited) then {(group (driver _h)) setSpeedMode "FULL"};
	if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
		{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;
		if (!isNull _lveh && {alive _lveh}) then {
			detach _lveh; _lveh setVelocity [0,0,0];
			_lveh setPos [(getPos _lveh) select 0, (getPos _lveh) select 1, 0.5];
			_lveh setVariable ["wfbe_aicom_slung", false, true];
			{if (alive _x) then {_x doMove _obj}} forEach (crew _lveh);
		};
		_tm setVariable ["wfbe_aicom_airborne_until", 0, true];
	};

	if (count _fl > 0) then {
		//--- COLD LZ: land + disembark (GET OUT).
		_h land "GET OUT";
		_h flyInHeight 0;
		_t0 = time + 40;
		waitUntil {sleep 1; time > _t0 || {(getPosATL _h) select 2 < 1.5}};
		{if (alive _x && {vehicle _x == _h}) then {unassignVehicle _x; [_x] orderGetIn false}} forEach _pax;
	} else {
		//--- HOT LZ: hold altitude + para-drop (eject pattern, mirrors the founding para branch).
		_h flyInHeight (120 + random 20);
		{
			if (alive _x && {vehicle _x == _h}) then {
				unassignVehicle _x;
				_x action ["EJECT", _h];
				sleep 0.85;
			};
		} forEach _pax;
	};
	//--- GUARD: dropped pax ALWAYS get an unconditional ground move to the objective so the order
	//--- loop's arrival latch + MOVE/SAD capture chain folds them in exactly like a walked insert.
	{if (alive _x) then {_x doMove _obj}} forEach _pax;

	//--- ===================================================================
	//--- cmdcon42-l VEHICLE DEEP-DROP (Ray: drop the vehicle 1-2k BEHIND the lines). SEQUENCING DECISION:
	//--- pax insert FIRST (above) THEN the vehicle deep-drop (here) - the two drop points are on the SAME
	//--- outbound flight path (dest-insert is nearer the base, _vdrop is FARTHER along the enemy-rear axis),
	//--- so dropping pax on the way in and the vehicle at the deep turn-around point is the natural, robust
	//--- order (one continuous run, no doubling back; the alternative - vehicle-first then return for the pax
	//--- insert - would fly PAST the insert to the deep point then back, a longer, more fragile path). The
	//--- sling stays attached through the whole pax insert (the -7m offset clears the terrain guard's 60m
	//--- climb, and every hot-LZ para/land altitude is well above the sling), then we descend at the deep
	//--- point + release. A2-OA-safe: doMove / flyInHeight / getPosATL / detach / setVelocity / setPos / crew.
	if (!isNull _lveh && {alive _lveh} && {!isNull _h} && {alive _h} && {!isNull (driver _h)} && {alive (driver _h)} && {typeName _vdrop == "ARRAY"} && {count _vdrop > 1}) then {
		//--- Continue on the SAME flight to the deep drop point behind the lines.
		(driver _h) doMove _vdrop;
		_h flyInHeight (90 + random 20);
		_t0 = time + 200;
		waitUntil {
			sleep 2;
			_tm setVariable ["wfbe_aicom_airborne_until", time + 120, true];
			time > _t0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {(_h distance _vdrop) < 90}
		};
		//--- Descend to ~15m so the released vehicle drops onto the deck, not from altitude.
		if (!isNull _h && {alive _h} && {!isNull (driver _h)} && {alive (driver _h)}) then {
			_h flyInHeight 15;
			_t0 = time + 25;
			waitUntil {sleep 1; time > _t0 || isNull _h || {!alive _h} || {((getPosATL _h) select 2) < 20}};
		};
		//--- DETACH + ground-snap (Zeta_Unhook idiom): kill inherited velocity, snap onto the surface at
		//--- z=0.5 so it settles on wheels (not buried/launched). detach runs HERE where the heli is LOCAL
		//--- (driver context), as required. Crew rode the hull down (attachTo carried the occupants).
		if (!isNull _lveh && {alive _lveh}) then {
			detach _lveh;
			_lveh setVelocity [0,0,0];
			_lveh setPos [(_vdrop select 0), (_vdrop select 1), 0.5];
			_lveh setVariable ["wfbe_aicom_slung", false, true];
			//--- FLANK FROM THE REAR (Ray's tactical intent): the dropped vehicle + crew are the team's
			//--- flanking element - drive toward the ordered town FROM BEHIND. Each live crew member gets an
			//--- unconditional doMove to _obj so they attack the objective from the rear.
			{if (alive _x) then {_x doMove _obj}} forEach (crew _lveh);
			diag_log ("AICOMSTAT|v2|EVENT|" + str _sID + "|" + str (round (time / 60)) + "|VEHDROP|team=" + (str _tm) + "|veh=" + (typeOf _lveh) + "|depth=" + str (round (_lveh distance _obj)));
			["INFORMATION", Format ["Common_AICOMAirLeg.sqf: [%1] team [%2] DEEP-DROP %3 behind %4 - crew flanking the town from the rear.", _sd, _tm, typeOf _lveh, _obj]] Call WFBE_CO_FNC_AICOMLog;
		};
	} else {
		//--- SAFETY: no deep drop ran (no lift, or the heli/sling was lost) but the vehicle is still attached
		//--- aloft to a LIVE heli - release it safely under the heli so it is never carried off / lost.
		if (!isNull _lveh && {alive _lveh} && {((getPos _lveh) select 2) > 3}) then {
			detach _lveh;
			_lveh setVelocity [0,0,0];
			_lveh setPos [(getPos _lveh) select 0, (getPos _lveh) select 1, 0.5];
			_lveh setVariable ["wfbe_aicom_slung", false, true];
			{if (alive _x) then {_x doMove _obj}} forEach (crew _lveh);
		};
	};
	//--- ===================================================================

	//--- TRANSPORT PERSISTS: the empty transport now RETURNS toward the side HQ/base and HOLDS there
	//--- (lands) so it is available for the team's NEXT order. NO fly-off / NO refund / NO despawn -
	//--- this IS the team's vehicle. cmdcon42-f: ONE shared implementation (WFBE_CO_FNC_AICOMAirReturn) -
	//--- the founding retained-transport path (WFBE_C_AICOM_AIR_RETAIN) calls the SAME code, no duplication.
	//--- The helper refreshes the airborne window on the way home and CLEARS it on every exit path.
	//--- The B74.2 HELI BASE-REAP in the order loop only reaps NON-transport (attack) helis
	//--- (transportSoldier==0), so a parked transport is never auto-reaped here.
	[_h, _tm, _sd] Call WFBE_CO_FNC_AICOMAirReturn;
};

true
