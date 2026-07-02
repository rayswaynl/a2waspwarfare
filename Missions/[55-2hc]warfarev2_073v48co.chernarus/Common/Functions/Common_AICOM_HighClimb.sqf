/*
	Common_AICOM_HighClimb.sqf

	Author: claude-gaming (2026-07-01)

	Description:
		AI-COMMANDER high-climb / low-gear terrain assist manager.

		The player's Valhalla low-gear assist (Client\Module\Valhalla\Common_AI_LowGear.sqf
		driven by Func_Client_AI_LowGear_Manager.sqf) runs CLIENT-SIDE and only iterates
		`units group player` - so it only ever assists AI-driven tanks in the local player's
		OWN group. AI-COMMANDER founded/delegated tanks are NEVER in a player's group and are
		local to the SERVER (server-local founded teams) or to a HEADLESS CLIENT (delegated
		teams), where that client manager never runs. Result: AICOM tanks get zero climbing
		assist and bog on steep terrain (Takistan ridges especially).

		This manager runs on the machine where AICOM vehicles are LOCAL:
		  - the server (started from Init_Server.sqf, for server-local founded teams), and
		  - each headless client (started from Init_HC.sqf, for HC-delegated teams).

		Enumeration is BOUNDED (no allUnits / allLocal / vehicles world-scan - the perf trap):
		it reads each side's already-tracked commander teams from the side logic's globally
		broadcast `wfbe_teams` group array (populated by the aicom-team-created HandleSpecial
		path), walks each team GROUP's units, and only touches a vehicle that is LOCAL to this
		machine. That is exactly the founded/delegated set - ~4-8 teams per side, a handful of
		hulls each - never the whole world.

		For each qualifying vehicle (local, alive, canMove, isKindOf "Tank", AI-driven, not
		already flagged) it spawns a per-vehicle boost loop that mirrors the player assist's
		curve + guards but uses ONLY server/HC-safe commands (setVelocity, speed, velocity,
		driver, currentCommand, stopped, isEngineOn - all A2-OA-1.64 and locality-safe where
		the vehicle is local).

		Flag: WFBE_C_AICOM_HIGHCLIMB (default 0 = OFF). Ships inert; flip to 1 for A/B.
*/

//--- OFF by default. Read inline (Init_CommonConstants owner registers the constant later).
if ((missionNamespace getVariable ["WFBE_C_AICOM_HIGHCLIMB", 0]) == 0) exitWith {};

//--- Which machine am I? Only the server and headless clients host AICOM-local vehicles.
if (!isServer && {!isHeadLessClient}) exitWith {};

private ["_machineTag"];
_machineTag = if (isServer) then {"SERVER"} else {"HC"};

["INFORMATION", Format ["Common_AICOM_HighClimb.sqf: AICOM high-climb manager started (%1).", _machineTag]] Call WFBE_CO_FNC_AICOMLog;

//--- ============================================================================
//--- Per-vehicle boost loop (server/HC-safe re-implementation of Common_AI_LowGear.sqf).
//--- Curve + guards mirror the player client assist; commands are all locality-safe for a
//--- vehicle that is LOCAL to this machine (setVelocity applies where the object is local).
//--- _this = tank object.
//--- ============================================================================
WFBE_CO_FNC_AICOM_HighClimb_Boost = {
	private ["_vehicle","_direction","_min","_minBoostSpeed","_baseBoostCoef","_maxBoostCoef",
	         "_sleepDelay","_driver","_speed","_vel","_currentCommand","_canAssist","_isMovingForward","_boostCoef"];

	_vehicle = _this;

	if (isNull _vehicle) exitWith {};
	if !(_vehicle isKindOf "Tank") exitWith {};
	//--- The velocity correction must only be applied where the vehicle is local.
	if !(local _vehicle) exitWith {};

	//--- Avoid duplicate loops on the same machine for the same vehicle.
	if (_vehicle getVariable ["AICOM_HighClimb_Running", false]) exitWith {};
	_vehicle setVariable ["AICOM_HighClimb_Running", true, false];

	//--- Heading-vs-velocity test: is the hull actually moving FORWARD (within +/-15 deg)?
	_direction = {
		private ["_vel","_veh","_vdir","_dir"];
		_vel = _this select 0;
		_veh = _this select 1;
		_vdir = (_vel select 0) atan2 (_vel select 1);
		if (_vdir < 0) then {_vdir = _vdir + 360};
		_dir = getDir _veh;
		if (_dir < 0) then {_dir = _dir + 360};
		_vdir = _vdir - _dir;
		if (abs(_vdir) < 15) then {true} else {false};
	};

	//--- Target assist speed: help only while below this. Mirror the player assist values.
	_min = 30;
	//--- Minimum speed before boosting: never push a stopped/parked tank.
	_minBoostSpeed = 3;
	//--- Progressive multiplier: gentle at low speed, stronger on steep climbs.
	_baseBoostCoef = 1.05;
	_maxBoostCoef  = 1.30;

	while {
		!isNull _vehicle &&
		{alive _vehicle} &&
		{canMove _vehicle} &&
		{local _vehicle}
	} do {

		_sleepDelay = 0.5;
		_driver = driver _vehicle;

		if (!isNull _driver) then {

			//--- AI drivers only, engine running.
			if (!isPlayer _driver && {isEngineOn _vehicle}) then {

				_sleepDelay = 0.1;
				_speed = speed _vehicle;
				_vel = velocity _vehicle;
				_currentCommand = currentCommand _driver;

				//--- Do not fight an explicit STOP/WAIT order or a stopped driver (the tank
				//--- may still roll downhill, but the assist must not boost that roll).
				_canAssist = (!(stopped _driver)) && {!(_currentCommand in ["WAIT", "STOP"])};

				_isMovingForward = [_vel, _vehicle] call _direction;

				if (_canAssist && {_isMovingForward}) then {
					//--- Climbing assist only: boost when already moving forward but too slow.
					//--- No braking above the target speed.
					if (_speed > _minBoostSpeed && {_speed < _min}) then {
						_boostCoef = _baseBoostCoef + (((_min - _speed) / _min) * (_maxBoostCoef - _baseBoostCoef));
						if (_boostCoef > _maxBoostCoef) then {_boostCoef = _maxBoostCoef};

						_vel = [
							(_vel select 0) * _boostCoef,
							(_vel select 1) * _boostCoef,
							(_vel select 2)
						];

						_vehicle setVelocity _vel;
					};
				};
			};
		};

		sleep _sleepDelay;
	};

	_vehicle setVariable ["AICOM_HighClimb_Running", false, false];
};

//--- ============================================================================
//--- Manager loop. Bounded enumeration over the side-logic wfbe_teams group arrays.
//--- Adaptive sleep: short while we are actively assisting hulls, long when idle.
//--- ============================================================================
private ["_sides","_perfStart","_perfTeams","_perfLocalVeh","_perfStarted","_side","_logik","_teams","_team","_seen","_veh","_driver","_sleep"];

_sides = [west, east, resistance];

while {!gameOver} do {

	//--- Performance Audit timing (mirrors the client low-gear manager). Guarded by isNil.
	_perfStart    = diag_tickTime;
	_perfTeams    = 0;   //--- commander teams walked this pass (across all sides)
	_perfLocalVeh = 0;   //--- distinct machine-local tanks inspected this pass
	_perfStarted  = 0;   //--- boost loops newly spawned this pass

	//--- track vehicles already inspected this pass so a hull shared across list quirks is counted once.
	_seen = [];

	{
		_side  = _x;
		_logik = _side Call WFBE_CO_FNC_GetSideLogic;

		if (!isNil "_logik" && {!isNull _logik}) then {

			//--- wfbe_teams is broadcast globally (setVariable [...,true] in aicom-team-created),
			//--- so it is readable here on the server AND on every HC. Object getVariable [k,d]
			//--- is A2-OA-safe (never the A3-only group getVariable [k,d]).
			_teams = _logik getVariable ["wfbe_teams", []];

			{
				_team = _x;
				if (!isNull _team) then {
					_perfTeams = _perfTeams + 1;

					//--- BOUNDED: walk only this team's own units, resolve their vehicle, and act
					//--- ONLY on a hull local to THIS machine. No allUnits / allLocal / vehicles scan.
					{
						_veh = vehicle _x;
						if (
							!isNull _veh &&
							{_veh != _x} &&
							{local _veh} &&
							{!(_veh in _seen)} &&
							{alive _veh} &&
							{canMove _veh} &&
							{_veh isKindOf "Tank"}
						) then {
							_seen set [count _seen, _veh];
							_perfLocalVeh = _perfLocalVeh + 1;

							_driver = driver _veh;
							if (
								!isNull _driver &&
								{!isPlayer _driver} &&
								{!(_veh getVariable ["AICOM_HighClimb_Running", false])}
							) then {
								_perfStarted = _perfStarted + 1;
								_veh spawn WFBE_CO_FNC_AICOM_HighClimb_Boost;
							};
						};
					} forEach (units _team);
				};
			} forEach _teams;
		};
	} forEach _sides;

	//--- Adaptive sleep: fast cadence while any hull is being assisted (so new tanks are picked
	//--- up promptly during an assault), slow idle cadence when there is nothing local to help.
	_sleep = if (_perfLocalVeh > 0) then {5} else {15};

	//--- Performance Audit record (tag "aicom_highclimb"), same guard idiom as the client manager.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["aicom_highclimb", diag_tickTime - _perfStart, Format["teams:%1;localVeh:%2;started:%3", _perfTeams, _perfLocalVeh, _perfStarted], _machineTag] Call PerformanceAudit_Record;
		};
	};

	sleep _sleep;
};
