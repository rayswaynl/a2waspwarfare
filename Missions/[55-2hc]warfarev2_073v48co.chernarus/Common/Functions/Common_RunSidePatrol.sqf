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
         "_driver","_cargo","_u","_settleTimer","_settleTimeout"];

_sideID   = _this select 0;
_template = _this select 1;
_homeTown = _this select 2;
_side     = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

_position = ([getPos _homeTown, 100, 400] Call WFBE_CO_FNC_GetRandomPosition);
_position = [_position, 50] Call WFBE_CO_FNC_GetEmptyPosition;

_team   = createGroup _side;
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
_team setVariable ["WFBE_SidePatrol", true, false];

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
		_truckDriver = (missionNamespace getVariable Format["WFBE_%1SOLDIER", _side]) createUnit [_position, _team, "", 0.6, "CORPORAL"];
		_truckDriver moveInDriver _truckVeh;
		["INFORMATION", Format["Common_RunSidePatrol.sqf: [%1] convoy truck [%2] spawned for L4 patrol.", _side, _truckCls]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Frontline gravitation: always head for the nearest town we do NOT own; when it
//--- flips to us (we helped cap it or a teammate did), pick the next one. If we own
//--- the whole map the patrol roams between our own towns.
_target        = objNull;
_alive         = true;
_paidThisVisit = false;

while {!WFBE_GameOver && _alive} do {
	_alive = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

	if (_alive) then {
		if (isNull _target) then {
			_paidThisVisit = false; //--- new objective: reset convoy-pay guard
			_candidates = [];
			{if ((_x getVariable "sideID") != _sideID) then {_candidates = _candidates + [_x]}} forEach towns;
			if (count _candidates == 0) then {_candidates = + towns};
			_target = [leader _team, _candidates] Call WFBE_CO_FNC_GetClosestEntity;
			if (!isNull _target) then {
				[_team, getPos _target, 'MOVE', 25] Spawn WFBE_CO_FNC_WaypointSimple;
			};
		} else {
			if ((leader _team) distance _target < 200) then {

				//--- Task 40: camp sweep on arrival at the current target town.
				//--- Guard with a group variable so we only sweep once per visit.
				_sweepDone = _team getVariable ["wfbe_patrol_sweep_town", objNull];
				if (_sweepDone != _target) then {
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
							_settleTimer   = time;
							_settleTimeout = time + 20;
							while {time < _settleTimeout} do {
								if (!isNull leader _team && alive leader _team) then {
									if ((leader _team) distance _campObj < _campRange) exitWith {};
								};
								sleep 2;
							};

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
