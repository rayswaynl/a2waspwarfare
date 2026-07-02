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
//--- ARGS: [_h, _team, _dest, _side, _sideID]
//---   _h     : the team's own live transport helicopter (alive, driver alive, has fuel).
//---   _team  : the AICOM group.
//---   _dest  : destination position (the ordered town, slot 2 of wfbe_aicom_order).
//---   _side  : side of the team.
//---   _sideID: side id (for telemetry).
//--- Runs the leg in ONE self-contained Spawn (non-blocking). No new per-tick loop.
//---
//--- A2-OA-1.64 SAFE: getVariable "sideID" on a TOWN OBJECT ([name,default] form is object-legal;
//--- only GROUPS reject it), getFriend / nearEntities / isFlatEmpty / land "GET OUT" / action
//--- ["EJECT"], atan2 position-delta bearing (binary getDir is A3-only), setFuel/flyInHeight/doMove.
//--- No isEqualType, no ==/!= on Booleans, no worldSize.
//--- ===================================================================

private ["_h","_team","_dest","_side","_sideID"];
_h      = _this select 0;
_team   = _this select 1;
_dest   = _this select 2;
_side   = _this select 3;
_sideID = _this select 4;

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

diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|AIRMOBILE_LEG|team=" + (str _team) + "|lifted=" + str (count _lifted) + "|walked=" + str (count _walkers) + "|dist=" + str (round ((leader _team) distance _dest)));
["INFORMATION", Format ["Common_AICOMAirLeg.sqf: [%1] team [%2] AIR-MOBILE leg via %3 (lifted %4, walked %5).", _side, _team, typeOf _h, count _lifted, count _walkers]] Call WFBE_CO_FNC_AICOMLog;

//--- ===================================================================
//--- FLY THE LEG in ONE self-contained Spawn (non-blocking; mirrors the founding disembark Spawn
//--- L584-689, minus the fly-off/refund - the transport RETURNS to base + HOLDS to persist).
//--- ===================================================================
[_h, _lzPos, _flat, _lifted, _team, _dest, _side, _sideID] Spawn {
	private ["_h","_lz","_fl","_pax","_tm","_obj","_sd","_sID","_t0"];
	_h    = _this select 0;
	_lz   = _this select 1;
	_fl   = _this select 2;
	_pax  = _this select 3;
	_tm   = _this select 4;
	_obj  = _this select 5;
	_sd   = _this select 6;
	_sID  = _this select 7;

	//--- Let everyone board first (bounded).
	_t0 = time + 30;
	waitUntil {sleep 1; time > _t0 || {({alive _x && vehicle _x == _h} count _pax) >= ({alive _x} count _pax)}};
	if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
		//--- Heli lost mid-lift: any survivors still aboard/around get an unconditional move.
		{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;
		_tm setVariable ["wfbe_aicom_airborne_until", 0, true];
	};

	//--- Run in to the LZ at altitude. Refresh the airborne exemption every leg-tick so a long
	//--- flight never lets the server stuck-watcher window lapse mid-air.
	(driver _h) doMove _lz;
	_h flyInHeight 60;
	_t0 = time + 240;
	waitUntil {
		sleep 2;
		_tm setVariable ["wfbe_aicom_airborne_until", time + 120, true];
		time > _t0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {(_h distance _lz) < 120}
	};
	if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
		{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;
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
