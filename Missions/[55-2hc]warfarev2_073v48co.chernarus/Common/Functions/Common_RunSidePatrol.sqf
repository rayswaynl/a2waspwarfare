/*
	Run one side patrol (Patrols upgrade): create the team and drive it until it dies.
	 Parameters: [ sideID, template (unit class array, resolved server-side from the
	               WFBE_<side>_PATROL_* pools), homeTown ]
	Runs on the SERVER or on a HEADLESS CLIENT (delegate-sidepatrol) - the whole
	lifecycle stays on the machine that created the group so waypoints keep locality.
	Slot bookkeeping (wfbe_side_patrols counter + WFBE_ACTIVE_PATROLS marker list)
	always lives on the server: direct Call when local, RequestSpecial from the HC.

	Task 40: when the patrol arrives at a target town, sweep through the town's camps
	         sequentially (dwell ~75 s at each so the presence-based capture ticks),
	         then push to the town center once all camps are ours or the dwell timeout
	         expires (8 min total). Normal frontline gravitation resumes after the sweep.

	Task 41: at Patrols level 4 a side-appropriate supply truck (WFBE_%1SUPPLYTRUCKS
	         first entry) is spawned and joined to the patrol group (no new group).
	         Each time the patrol arrives at a town and the convoy truck is alive within
	         150 m of the leader, the server pays the team WFBE_C_PATROL_CONVOY_PAY
	         cash via the BankPayout channel (at most once per town visit).
*/

Private ["_sideID","_template","_homeTown","_side","_position","_retVal","_units","_vehicles",
         "_team","_ldr","_target","_alive","_candidates",
         "_upgLvl","_truckCls","_truckVeh","_truckDriver","_truckList",
         "_paidThisVisit","_convoyPay","_sweepDone",
         "_townCamps","_campObj","_sweepStart","_allOurs","_ups",
         "_campRange","_liveUnits","_inVehicle","_dismounted","_veh",
         "_driver","_cargo","_u","_settleTimeout","_lastLdrPos","_stuckTicks","_pLdr","_pPos","_pVeh","_pNear","_pRds","_pNode",
         "_pUnstuckStreak","_pUnstuckMax","_pAvoid","_pAvoidKeep","_pAvoidCd","_cIsAvoided",
         "_cIsNaval","_navSkipLogged"];  //--- cmdcon41-w3m: +_cIsNaval (naval-HVT skip test), _navSkipLogged (one-time-per-group INFO latch).

_sideID   = _this select 0;
_template = _this select 1;
_homeTown = _this select 2;
_side     = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

_position = ([getPos _homeTown, 100, 400] Call WFBE_CO_FNC_GetRandomPosition);
_position = [_position, 50] Call WFBE_CO_FNC_GetEmptyPosition;

_team   = [_side, "patrol"] Call WFBE_CO_FNC_CreateGroup;
_retVal = [_template, _position, _side, true, _team, true, 90] call WFBE_CO_FNC_CreateTeam;
_units    = _retVal select 0;
_vehicles = _retVal select 1;
_team     = _retVal select 2;

if (isNull _team || {count _units == 0}) exitWith {
	//--- Fix 2026-06-11: a CREWLESS spawn (0 units, N vehicles) passed the old total-only
	//--- guard, instantly failed the alive-check and LEAKED its empty vehicles at the
	//--- spawn town forever (observed piling up at Mogilevka), then re-dispatched in a
	//--- loop. No infantry = no patrol: delete whatever spawned and release the slot.
	{if (!isNull _x) then {deleteVehicle _x}} forEach _vehicles;
	{if (!isNull _x) then {deleteVehicle _x}} forEach _units;
	if (!isNull _team) then {deleteGroup _team};
	["WARNING", Format["Common_RunSidePatrol.sqf: [%1] patrol creation failed/crewless at [%2] (units %3, vehicles %4, template %5) - cleaned up, releasing the slot.", _side, _homeTown getVariable "name", count _units, count _vehicles, _template]] Call WFBE_CO_FNC_LogContent;
	if (isServer) then {
		["sidepatrol-ended", _sideID, objNull] Call HandleSpecial;
	} else {
		["RequestSpecial", ["sidepatrol-ended", _sideID, objNull]] Call WFBE_CO_FNC_SendToServer;
	};
};

_team allowFleeing 0;
//--- B66: broadcast=true so the server/GC can SEE the patrol flag and skip these groups
//--- (was false=client/HC-local only -> server-invisible -> BASE-GC could mis-adopt/delete).
_team setVariable ["WFBE_SidePatrol", true, true];

//--- B36 (Ray 2026-06-15): fewer GUER patrols, but the ones that DO move are MORE DANGEROUS.
//--- Max the combat skill of GUER (resistance) patrol units - sharper aim, spots farther, never
//--- flees - so a lone GUER patrol is a real threat. Gated to the resistance side so WEST/EAST
//--- patrols are unchanged. Tunable via WFBE_C_SIDE_PATROL_GUER_SKILL (default 0.92).
if (_side == resistance) then {
	private ["_pskill","_gt"]; _gt = {!isNull _x && {(_x getVariable ["sideID",-1]) == 2}} count towns; _pskill = ((missionNamespace getVariable ["WFBE_C_SIDE_PATROL_GUER_SKILL", 0.85]) + (0.03 * (6 - (_gt min 6)))) min 1;
	{
		if (!isNull _x && {alive _x}) then {
			_x setSkill _pskill;
			_x setSkill ["aimingAccuracy", ((0.78 + (0.03 * (6 - (_gt min 6)))) min 0.95)];
			_x setSkill ["spotDistance", 1];
			_x setSkill ["spotTime", 1];
			_x setSkill ["courage", 1];
		};
	} forEach _units;
};

_ldr = leader _team;
if (isServer) then {
	["sidepatrol-started", _sideID, _ldr] Call HandleSpecial;
} else {
	["RequestSpecial", ["sidepatrol-started", _sideID, _ldr]] Call WFBE_CO_FNC_SendToServer;
};

["INFORMATION", Format["Common_RunSidePatrol.sqf: [%1] patrol spawned at [%2] (%3 units, %4 vehicles).", _side, _homeTown getVariable "name", count _units, count _vehicles]] Call WFBE_CO_FNC_LogContent;

//--- Task 41: check upgrade level; at level 4 spawn a convoy supply truck joined to the group.
_truckVeh  = objNull;
_convoyPay = if (isNil "WFBE_C_PATROL_CONVOY_PAY") then {750} else {WFBE_C_PATROL_CONVOY_PAY};
_ups       = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
_upgLvl    = if (count _ups > WFBE_UP_PATROLS) then {_ups select WFBE_UP_PATROLS} else {0};

if (_upgLvl >= 4) then {
	_truckList = missionNamespace getVariable Format["WFBE_%1SUPPLYTRUCKS", str _side];
	if (!isNil "_truckList" && {count _truckList > 0}) then {
		//--- Prefer the T810 as the convoy truck when ACR is present; fall back to the
		//--- side's first supply truck so it still works without the ACR DLC.
		_truckCls = if (isClass (configFile >> "CfgVehicles" >> "T810_CZ_EP1")) then {"T810_CZ_EP1"} else {_truckList select 0};
		_truckVeh    = _truckCls createVehicle _position;
		_truckVeh    setPos _position;
		//--- Fix 2026-06-11: the driver was created with the TRUCK classname (a vehicle
		//--- class as a soldier = no driver, truck never moves, convoy pay never fires).
		//--- Use the side's crew soldier class instead (same source HandleDefense uses).
		//--- Fix 2026-06-19: the OFP/A1 string-form `_class createUnit [..]` RETURNS Nothing,
		//--- so _truckDriver was undefined and moveInDriver did nothing (truck spawned
		//--- driverless, never moved). Use the returning CreateUnit helper (same source
		//--- Server_HandleDefense uses) and guard moveInDriver on a non-null result.
		_truckDriver = [(missionNamespace getVariable Format["WFBE_%1SOLDIER", _side]), _team, _position, _sideID] Call WFBE_CO_FNC_CreateUnit;
		if (!isNull _truckDriver) then {_truckDriver moveInDriver _truckVeh};
		["INFORMATION", Format["Common_RunSidePatrol.sqf: [%1] convoy truck [%2] spawned for L4 patrol.", _side, _truckCls]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Frontline gravitation: always head for the nearest town we do NOT own; when it
//--- flips to us (we helped cap it or a teammate did), pick the next one. If we own
//--- the whole map the patrol roams between our own towns.
_target        = objNull;
_alive         = true;
_paidThisVisit = false;
//--- CIRCLING FIX B (Build84, claude-gaming 2026-07-01): consecutive PATROL_UNSTUCK wedge count.
//--- The wedge handler used to re-march the SAME unreachable target forever (RPT: 72 PATROL_UNSTUCK
//--- fires on one team over 100 min). After WFBE_C_AICOM_PATROL_UNSTUCK_MAX consecutive wedges we drop
//--- the target + avoid that town for a cooldown so the nearest-town pick below chooses a DIFFERENT
//--- frontline town. _pAvoid holds [town, expiry] pairs (A2-safe plain array on a local).
_pUnstuckStreak = 0;
_pAvoid         = [];
//--- cmdcon41-w3m (ground-patrol-skip-naval-hvt, HIGH behavioral): a GROUND patrol can NEVER path to an
//--- OFFSHORE carrier town (Khe Sanh Alpha/Bravo/Charlie, stamped wfbe_is_naval_hvt in Init_NavalHVT.sqf).
//--- Live EAST patrol O 1-1-G thrashed ALL MATCH cycling PATROL_UNSTUCK (80x) / PATROL_RETARGET because the
//--- target pick below re-selected a carrier forever (unstuck -> retarget -> re-pick same offshore town). The
//--- candidate build + BOTH fallbacks now EXCLUDE any town flagged wfbe_is_naval_hvt OR sitting over water
//--- (surfaceIsWater belt-and-braces). One INFORMATION log the FIRST time this group skips a naval town (latched,
//--- not per tick). Gated by WFBE_C_PATROLS_SKIP_NAVAL (default 1); at 0 the old unfiltered pick returns.
_navSkipLogged = false;

while {!WFBE_GameOver && _alive} do {
	_alive = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

	if (_alive) then {
		if (isNull _target) then {
			_paidThisVisit = false; //--- new objective: reset convoy-pay guard
			//--- CIRCLING FIX B: prune expired avoid entries, then exclude still-avoided (recently
			//--- wedged) towns so a fresh pick lands on a DIFFERENT frontline town. If everything is
			//--- avoided, fall through to the unfiltered list so the patrol always gets a target.
			_pAvoidKeep = [];
			{if ((typeName (_x select 0) == "OBJECT") && {!isNull (_x select 0)} && {(_x select 1) > time}) then {_pAvoidKeep set [count _pAvoidKeep, _x]}} forEach _pAvoid;
			_pAvoid = _pAvoidKeep;
			private "_skipNaval"; _skipNaval = (missionNamespace getVariable ["WFBE_C_PATROLS_SKIP_NAVAL", 1]) > 0;
			_candidates = [];
			{
				private ["_cTown"];
				_cTown = _x;
				if ((_cTown getVariable "sideID") != _sideID) then {
					//--- cmdcon41-w3m: never target an offshore naval-HVT carrier (ground units can't path to it).
					_cIsNaval = _skipNaval && {(_cTown getVariable ["wfbe_is_naval_hvt", false]) || {surfaceIsWater (getPos _cTown)}};
					if (_cIsNaval && {!_navSkipLogged}) then {
						_navSkipLogged = true;
						["INFORMATION", Format ["Common_RunSidePatrol.sqf: [%1] ground patrol SKIPPING naval-HVT town [%2] (offshore/over-water - unreachable by ground).", _side, _cTown getVariable ["name","?"]]] Call WFBE_CO_FNC_LogContent;
					};
					if (!_cIsNaval) then {
						_cIsAvoided = false;
						{if ((_x select 0) == _cTown) then {_cIsAvoided = true}} forEach _pAvoid;
						if (!_cIsAvoided) then {_candidates = _candidates + [_cTown]};
					};
				};
			} forEach towns;
			if (count _candidates == 0) then {
				//--- Everything owned or everything avoided: fall back to any non-owned NON-NAVAL town. cmdcon41-w3m:
				//--- the fallback MUST keep excluding naval towns (else a compressed side falls back onto a carrier).
				{if (((_x getVariable "sideID") != _sideID) && {!(_skipNaval && {(_x getVariable ["wfbe_is_naval_hvt", false]) || {surfaceIsWater (getPos _x)}})}) then {_candidates = _candidates + [_x]}} forEach towns;
				//--- Last-ditch (never-idle guarantee): any NON-NAVAL town at all; only if THAT is empty use raw towns.
				if (count _candidates == 0) then {
					{if (!(_skipNaval && {(_x getVariable ["wfbe_is_naval_hvt", false]) || {surfaceIsWater (getPos _x)}})) then {_candidates = _candidates + [_x]}} forEach towns;
					if (count _candidates == 0) then {_candidates = + towns};
				};
			};
			_target = [leader _team, _candidates] Call WFBE_CO_FNC_GetClosestEntity;
			if (!isNull _target) then {
				[_team, getPos _target, 'MOVE', 25] Spawn WFBE_CO_FNC_WaypointSimple;
			};
		} else {
			if ((leader _team) distance _target < 200) then {

				//--- Task 40: camp sweep on arrival at the current target town.
				//--- Guard with a group variable so we only sweep once per visit.
				//--- A2 OA: 2-arg group getVariable returns nil (NOT the default) when UNSET, so on the FIRST
				//--- sweep `nil != _target` threw ("Type Nothing"). 1-arg + isNil guard (G1 twin; batch-1/#36 missed it).
				_sweepDone = _team getVariable "wfbe_patrol_sweep_town";
				if (isNil "_sweepDone" || {_sweepDone != _target}) then {
					_team setVariable ["wfbe_patrol_sweep_town", _target, false];

					_townCamps  = _target getVariable ["camps", []];
					_sweepStart = time;
					_campRange  = missionNamespace getVariable ["WFBE_C_CAMPS_RANGE", 30];

					if (count _townCamps > 0) then {
						["INFORMATION", Format["Common_RunSidePatrol.sqf: [%1] sweeping %2 camps at [%3].", _side, count _townCamps, _target getVariable "name"]] Call WFBE_CO_FNC_LogContent;

						//--- Per-camp: move leader → settle → DISMOUNT non-drivers → dwell → REMOUNT.
						for "_ci" from 0 to ((count _townCamps) - 1) do {
							_campObj = _townCamps select _ci;

							//--- Skip dead camps to avoid nil-access on getPos of a null object.
							if (isNull _campObj) exitWith {};

							//--- Order move to camp.
							if (!isNull leader _team && alive leader _team) then {
								(leader _team) doMove (getPos _campObj);
							};

							//--- Settle wait: up to 20 s or leader within _campRange m.
							//--- Fix: exitWith inside a then-block exits only that then-block, not the
							//--- while; proximity condition moved into the while test with lazy && {}.
							_settleTimeout = time + 20;
							while {time < _settleTimeout && {!(!isNull leader _team && {alive leader _team} && {(leader _team) distance _campObj < _campRange})}} do { sleep 2; };

							//--- DISMOUNT: unassign everyone alive who is currently inside a vehicle,
							//---   EXCEPT one driver per vehicle (keep each vehicle driveable for remount).
							_liveUnits  = (units _team) Call WFBE_CO_FNC_GetLiveUnits;
							_dismounted = [];
							{
								_u = _x;
								if (alive _u && vehicle _u != _u) then {
									_veh = vehicle _u;
									//--- Preserve exactly one driver per vehicle (already seated as driver).
									if (_u == driver _veh) then {
										//--- This unit IS the driver — leave them in.
									} else {
										unassignVehicle _u;
										[_u] orderGetIn false;
										_dismounted = _dismounted + [_u];
									};
								};
							} forEach _liveUnits;

							//--- Send dismounted infantry to the camp object.
							if (count _dismounted > 0) then {
								{
									if (alive _x) then {_x doMove (getPos _campObj)};
								} forEach _dismounted;
							};

							//--- Dwell at camp (~75 s total including settle phase).
							sleep 75;

							//--- REMOUNT: re-assign cargo and order back in (25 s grace, then proceed regardless).
							if (count _vehicles > 0 && count _dismounted > 0) then {
								_veh = _vehicles select 0;
								{
									if (alive _x && alive _veh) then {
										_x assignAsCargo _veh;
										[_x] orderGetIn true;
									};
								} forEach _dismounted;
								sleep 25;
							};
						};

						//--- After the camp sweep, if all camps belong to us OR the 8-min
						//--- total timeout fired, push to the town center.
						_allOurs = true;
						for "_ci" from 0 to ((count _townCamps) - 1) do {
							if (isNull (_townCamps select _ci)) then {_allOurs = false};
							if (!isNull (_townCamps select _ci) && ((_townCamps select _ci) getVariable ["sideID", -1]) != _sideID) then {_allOurs = false};
						};

						if (_allOurs || {time - _sweepStart > 480}) then {
							//--- Town-center push: dismount ALL non-drivers, send to center, NO remount — hold/fight.
							_liveUnits = (units _team) Call WFBE_CO_FNC_GetLiveUnits;
							{
								_u = _x;
								if (alive _u && vehicle _u != _u) then {
									_veh = vehicle _u;
									if (_u != driver _veh) then {
										unassignVehicle _u;
										[_u] orderGetIn false;
									};
								};
							} forEach _liveUnits;

							if (!isNull leader _team && alive leader _team) then {
								{if (alive _x) then {_x doMove (getPos _target)}} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
								sleep 30;
							};
						};
					};
				};

				//--- Task 41: convoy payout on arrival (at most once per town visit).
				if (!_paidThisVisit && {!isNull _truckVeh} && {alive _truckVeh}
				    && {(leader _team) distance _truckVeh < 150}) then {
					_paidThisVisit = true;
					if (isServer) then {
						["sidepatrol-convoy-stop", _sideID, _target] Call HandleSpecial;
					} else {
						["RequestSpecial", ["sidepatrol-convoy-stop", _sideID, _target]] Call WFBE_CO_FNC_SendToServer;
					};
				};

				if ((_target getVariable "sideID") == _sideID) then {
					_target = objNull; //--- Town is ours now: gravitate to the next frontline town.
				};
				//--- Still hostile/neutral: stay engaged; the town capture logic does the rest.
			} else { //--- EN-ROUTE never-frozen guard (Ray 2026-06-29): a patrol with no progress for ~90s is wedged - re-march + un-wedge (player-safe velocity hop within 100m, teleport-to-road otherwise). A patrol must never sit frozen in a player view.
			_pLdr = leader _team; if (!isNull _pLdr && {alive _pLdr}) then { _pPos = getPos _pLdr; if (isNil "_stuckTicks") then {_stuckTicks = 0}; if (isNil "_lastLdrPos") then {_lastLdrPos = _pPos}; if ((_pPos distance _lastLdrPos) < 25) then {_stuckTicks = _stuckTicks + 1} else {_stuckTicks = 0; _pUnstuckStreak = 0}; _lastLdrPos = _pPos; if (_stuckTicks >= 3) then { _stuckTicks = 0; { if (alive _x && {vehicle _x == _x} && {!isNull (assignedVehicle _x)} && {alive (assignedVehicle _x)} && {canMove (assignedVehicle _x)}) then {[_x] orderGetIn true} } forEach (units _team); [_team, getPos _target, 'MOVE', 25] Spawn WFBE_CO_FNC_WaypointSimple; _pVeh = vehicle _pLdr; if (!isNull _pVeh && {_pVeh != _pLdr} && {alive _pVeh} && {canMove _pVeh}) then { _pNear = false; { if (isPlayer _x && {(_x distance _pVeh) < 100}) then {_pNear = true} } forEach playableUnits; if (_pNear) then { _pVeh setVelocity [(velocity _pVeh) select 0, (velocity _pVeh) select 1, 4] } else { _pRds = (getPos _pVeh) nearRoads 150; if (count _pRds > 0) then { _pNode = [getPos _pVeh, _pRds] Call WFBE_CO_FNC_GetClosestEntity; if (!isNull _pNode && {!surfaceIsWater (getPos _pNode)}) then { _pVeh setVelocity [0,0,0]; _pVeh setPos (getPos _pNode) } } }; diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time/60)) + "|PATROL_UNSTUCK|" + (str _team)); _pUnstuckStreak = _pUnstuckStreak + 1; _pUnstuckMax = missionNamespace getVariable ["WFBE_C_AICOM_PATROL_UNSTUCK_MAX", 5]; if (_pUnstuckStreak >= _pUnstuckMax) then { _pUnstuckStreak = 0; if (!isNull _target) then { _pAvoidCd = missionNamespace getVariable ["WFBE_C_AICOM_BLACKLIST_COOLDOWN", 600]; _pAvoid set [count _pAvoid, [_target, time + _pAvoidCd]]; diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time/60)) + "|PATROL_RETARGET|" + (str _team) + "|town=" + (_target getVariable ["name","town"]) + "|wedges=" + str _pUnstuckMax) }; _target = objNull } } } }
			};
		};
	};

	sleep 30;
};

//--- Patrol wiped: release the slot (the server also re-arms the spawn cooldown).
if (isServer) then {
	["sidepatrol-ended", _sideID, _ldr] Call HandleSpecial;
} else {
	["RequestSpecial", ["sidepatrol-ended", _sideID, _ldr]] Call WFBE_CO_FNC_SendToServer;
};

if (!isNull _team) then {deleteGroup _team};
