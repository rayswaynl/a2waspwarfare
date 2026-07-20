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

		DIAGNOSIS NOTE (cmdcon43-k, 2026-07-02): under the LIVE 2-HC config every AICOM team is
		HC-DELEGATED (AI_Commander_Teams.sqf: count-of-live-HCs>0 -> delegate-aicom-team), so the
		SERVER's copy of this manager legitimately inspects ZERO local AICOM hulls (localVeh:0 every
		pass in the server PerformanceAudit) - the hulls are local to the HC, and it is the HC's copy
		that must boost them. But PerformanceAudit_Run is NOT started on the HC (only server + real
		clients), so the HC's `started:` audit field NEVER flushes to any RPT. The previous build's
		ONLY telemetry for this system was that audit field => on the machine where it actually runs it
		is INVISIBLE. That, not a logic fault, is why zero boosts were "seen". Fix: an ALWAYS-ON
		diag_log (AICOMSTAT|...|HIGHCLIMB) each time a hull is first picked up AND a rate-limited one
		when a boost is actually applied, so a future soak can tell IDLE (no bogged hulls) from BROKEN
		(hulls present, never boosted) from the HC RPT directly.

		ELIGIBILITY (cmdcon43-k): the old filter was isKindOf "Tank" ONLY. In A2-OA that DOES catch the
		tracked armour AICOM fields (T-72/T-90 are Tank; BMP-2/BMP-3/2S6/GRAD are Tracked_APC which
		derives FROM Tank), but it MISSES the WHEELED hulls the commander also fields heavily: BTR-90
		(Wheeled_APC, which derives from Car - NOT Tank; appears in ~5 RU templates), plus GAZ_Vodnik /
		UAZ / Kamaz transports (Car). Those bog on the same ridges. Eligibility is widened to the
		"drivable heavy/medium ground hull" set the rest of the AICOM code already uses:
		isKindOf "Tank" OR "Wheeled_APC" OR "Car" (NOT StaticWeapon/Air/Ship). Classname literals are
		A2-OA-safe. See WFBE_CO_FNC_AICOM_HighClimb_Eligible below.

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

		Flag: WFBE_C_AICOM_HIGHCLIMB. LIVE DEFAULT = 1 (ON) - see Init_CommonConstants.sqf:793.
		(The old header said "default 0 = OFF, ships inert"; that was stale - the constant has shipped
		at 1 since Build 84. Set the constant to 0 to disable / retire this system - see the PR body's
		RETIRE alternative.)
*/

//--- Gate on the flag. The LIVE constant is 1 (ON) - see Init_CommonConstants.sqf:793. The default-0
//--- here is only a DEFENSIVE fallback for the race where this file runs before the constant registers
//--- (it never should - both are inited pre-mission - but a 0-fallback fails safe: no boost, no error).
//--- == is on a SCALAR (never a boolean); A2-OA-safe.
if ((missionNamespace getVariable ["WFBE_C_AICOM_HIGHCLIMB", 0]) == 0) exitWith {};

//--- Which machine am I? Only the server and headless clients host AICOM-local vehicles.
if (!isServer && {!isHeadLessClient}) exitWith {};

private ["_machineTag"];
_machineTag = if (isServer) then {"SERVER"} else {"HC"};

["INFORMATION", Format ["Common_AICOM_HighClimb.sqf: AICOM high-climb manager started (%1).", _machineTag]] Call WFBE_CO_FNC_AICOMLog;

//--- ============================================================================
//--- Shared eligibility test (cmdcon43-k). A hull qualifies for climb-assist when it is a drivable
//--- GROUND combat/transport hull the commander actually fields. isKindOf "Tank" catches the tracked
//--- armour (T-72/T-90 = Tank; BMP-2/BMP-3/2S6/GRAD = Tracked_APC derives FROM Tank); the added
//--- "Wheeled_APC"/"Car" clauses catch BTR-90 (Wheeled_APC->Car) and the wheeled transports
//--- (GAZ_Vodnik/UAZ/Kamaz = Car). StaticWeapon is excluded (a mounted MG has no drive to assist).
//--- Air/Ship never reach here (Tank/Car families are LandVehicle). A2-OA-safe: isKindOf classname
//--- literals + boolean ops, no A3 commands. _this = vehicle object.
//--- ============================================================================
WFBE_CO_FNC_AICOM_HighClimb_Eligible = {
	private ["_v"];
	_v = _this;
	if (isNull _v) exitWith {false};
	if (_v isKindOf "StaticWeapon") exitWith {false};
	((_v isKindOf "Tank") || {_v isKindOf "Wheeled_APC"} || {_v isKindOf "Car"})
};

//--- ============================================================================
//--- Per-vehicle boost loop (server/HC-safe re-implementation of Common_AI_LowGear.sqf).
//--- Curve + guards mirror the player client assist; commands are all locality-safe for a
//--- vehicle that is LOCAL to this machine (setVelocity applies where the object is local).
//--- _this = tank object.
//--- ============================================================================
WFBE_CO_FNC_AICOM_HighClimb_Boost = {
	private ["_vehicle","_direction","_min","_minBoostSpeed","_baseBoostCoef","_maxBoostCoef",
	         "_sleepDelay","_driver","_speed","_vel","_currentCommand","_canAssist","_isMovingForward","_boostCoef",
	         "_lastLog"];

	_vehicle = _this;

	if (isNull _vehicle) exitWith {};
	if !(_vehicle Call WFBE_CO_FNC_AICOM_HighClimb_Eligible) exitWith {};
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
		//--- T1.5 FIX (R3-SYNTHESIS 2026-07-20): the raw difference above ranges -360..360 with no
		//--- wrap-around normalisation, so a hull driving essentially straight ahead near due-north
		//--- (e.g. _vdir=5, _dir=355 - a true 10 degree turn) computed diff=-350, abs()=350, silently
		//--- failing the <15 test and zeroing climb-assist for ~8% of all headings. Normalise the
		//--- difference into (-180,180] before the magnitude test.
		if (_vdir > 180) then {_vdir = _vdir - 360};
		if (_vdir < -180) then {_vdir = _vdir + 360};
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

						//--- cmdcon43-k ALWAYS-ON boost telemetry (rate-limited to 1 line / 30s / hull so a
						//--- climb burst is one line, not a flood). This is the ONLY observable proof a boost
						//--- fired on the HC (PerformanceAudit never flushes there); a future soak reading the
						//--- HC RPT can now tell IDLE (no BOOST lines) from BROKEN. diag_log + typeOf + round
						//--- are A2-OA-safe. == is on numbers/strings only (never a boolean). No A3 commands.
						_lastLog = _vehicle getVariable ["AICOM_HighClimb_LastLog", -999];
						if ((diag_tickTime - _lastLog) > 30) then {
							_vehicle setVariable ["AICOM_HighClimb_LastLog", diag_tickTime, false];
							diag_log (Format ["AICOMSTAT|v1|EVENT|%1|%2|HIGHCLIMB|boosted=%3|spd=%4|coef=%5", str isServer, round (time / 60), typeOf _vehicle, round _speed, round (_boostCoef * 100)]);
						};
					};
				};

				//--- T1.5 ADD (R3-SYNTHESIS 2026-07-20): the boost above only assists a hull ALREADY rolling
				//--- (_speed > _minBoostSpeed) - a fully STOPPED/bogged hull gets ZERO help today, which is
				//--- the one real gap in this manager (the seed claim "climb-assist is dead" was withdrawn -
				//--- 2500+ boosts fire in the live evidence; its only gap is unsticking a STOPPED hull). Nudges
				//--- along the HULL's own heading (getDir, NOT the velocity-derived heading above, which is
				//--- unreliable at near-zero speed) so static friction breaks. Escalates a per-vehicle strike
				//--- counter and STOPS pulsing after PULSE_MAX_STRIKES consecutive still-stuck attempts, so a
				//--- genuinely wedged/flipped hull is handed back to the normal AssignTowns stuck/strand/abandon
				//--- ladder instead of nudged forever. Gate WFBE_C_AICOM_HIGHCLIMB_PULSE (default 1).
				if ((missionNamespace getVariable ["WFBE_C_AICOM_HIGHCLIMB_PULSE", 1]) > 0) then {
					if (_canAssist && {_speed <= _minBoostSpeed}) then {
						private ["_pulseMax","_pulseCd","_pulseLast","_pulseStrikes","_pulseHead","_pulseSpd","_pulseVel"];
						//--- Codex review HIGH: still genuinely stuck this tick, so any recovery timer that may have
						//--- started (see the else branch below) was a false start - clear it.
						_vehicle setVariable ["AICOM_HighClimb_PulseRecoverSince", -1, false];
						_pulseMax  = missionNamespace getVariable ["WFBE_C_AICOM_HIGHCLIMB_PULSE_MAX_STRIKES", 6];
						_pulseCd   = missionNamespace getVariable ["WFBE_C_AICOM_HIGHCLIMB_PULSE_COOLDOWN", 2];
						_pulseLast = _vehicle getVariable ["AICOM_HighClimb_PulseLast", -999];
						if ((diag_tickTime - _pulseLast) > _pulseCd) then {
							_pulseStrikes = _vehicle getVariable ["AICOM_HighClimb_PulseStrikes", 0];
							if (_pulseStrikes < _pulseMax) then {
								_pulseHead = getDir _vehicle;
								_pulseSpd  = missionNamespace getVariable ["WFBE_C_AICOM_HIGHCLIMB_PULSE_SPEED", 2.5];
								_pulseVel  = [(sin _pulseHead) * _pulseSpd, (cos _pulseHead) * _pulseSpd, (_vel select 2)];
								_vehicle setVelocity _pulseVel;
								_vehicle setVariable ["AICOM_HighClimb_PulseLast", diag_tickTime, false];
								_vehicle setVariable ["AICOM_HighClimb_PulseStrikes", _pulseStrikes + 1, false];
								diag_log (Format ["AICOMSTAT|v1|EVENT|%1|%2|HIGHCLIMB_PULSE|veh=%3|spd=%4|strike=%5", str isServer, round (time / 60), typeOf _vehicle, round _speed, _pulseStrikes + 1]);
							};
						};
					} else {
						//--- Codex review HIGH: a single elevated-speed SAMPLE is not proof of real recovery - our own
						//--- pulse sets ~2.5 m/s (~9 km/h), well above the 3 km/h reset threshold, so the very next tick
						//--- after a pulse fires used to read as "rolling again" and wipe the strike counter every single
						//--- pulse - the escalation ceiling could never bite and a wedged hull got pulsed forever. Now
						//--- require SUSTAINED motion above the threshold for WFBE_C_AICOM_HIGHCLIMB_PULSE_RECOVER_SECS
						//--- (default 3s) before resetting - a transient pulse-induced bounce cannot sustain that long
						//--- against genuine static friction, but real recovered motion (freed from the obstruction) can.
						if (_speed > _minBoostSpeed) then {
							private ["_pulseRecoverSince","_pulseRecoverSecs"];
							_pulseRecoverSince = _vehicle getVariable ["AICOM_HighClimb_PulseRecoverSince", -1];
							if (_pulseRecoverSince < 0) then {
								_vehicle setVariable ["AICOM_HighClimb_PulseRecoverSince", diag_tickTime, false];
							} else {
								_pulseRecoverSecs = missionNamespace getVariable ["WFBE_C_AICOM_HIGHCLIMB_PULSE_RECOVER_SECS", 3];
								if ((diag_tickTime - _pulseRecoverSince) >= _pulseRecoverSecs) then {
									_vehicle setVariable ["AICOM_HighClimb_PulseStrikes", 0, false];
									_vehicle setVariable ["AICOM_HighClimb_PulseRecoverSince", -1, false];
								};
							};
						} else {
							//--- Dropped back under threshold before sustaining - not real recovery, clear the timer.
							_vehicle setVariable ["AICOM_HighClimb_PulseRecoverSince", -1, false];
						};
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
private ["_sides","_perfStart","_perfTeams","_perfLocalVeh","_perfStarted","_side","_logik","_teams","_team","_seen","_veh","_driver","_sleep","_lastHeartbeat"];

_sides = [west, east, resistance];
//--- cmdcon43-k: always-on manager heartbeat clock (independent of PerformanceAudit, which never
//--- flushes on the HC). Emits at most one line / 120s so a soak reading the HC RPT can confirm the
//--- manager IS walking teams and WHETHER it finds local eligible hulls - distinguishing IDLE
//--- (localVeh:0, nothing to help) from a wiring fault.
_lastHeartbeat = -999;

while {!gameOver} do {

	//--- Performance Audit timing (mirrors the client low-gear manager). Guarded by isNil.
	_perfStart    = diag_tickTime;
	_perfTeams    = 0;   //--- commander teams walked this pass (across all sides)
	_perfLocalVeh = 0;   //--- distinct machine-local eligible hulls (tank/wheeled) inspected this pass
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
							{_veh Call WFBE_CO_FNC_AICOM_HighClimb_Eligible}
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

	//--- Adaptive sleep: fast cadence while any hull is being assisted (so new hulls are picked
	//--- up promptly during an assault), slow idle cadence when there is nothing local to help.
	_sleep = if (_perfLocalVeh > 0) then {5} else {15};

	//--- Performance Audit record (tag "aicom_highclimb"), same guard idiom as the client manager.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["aicom_highclimb", diag_tickTime - _perfStart, Format["teams:%1;localVeh:%2;started:%3", _perfTeams, _perfLocalVeh, _perfStarted], _machineTag] Call PerformanceAudit_Record;
		};
	};

	//--- cmdcon43-k ALWAYS-ON manager heartbeat (rate-limited 120s). PerformanceAudit never flushes on
	//--- the HC, so this is the only RPT-visible proof the manager runs there + how many local eligible
	//--- hulls it sees. A2-OA-safe: diag_log + round + arithmetic; no A3 commands, no ==/!= on booleans.
	if ((diag_tickTime - _lastHeartbeat) > 120) then {
		_lastHeartbeat = diag_tickTime;
		diag_log (Format ["AICOMSTAT|v1|EVENT|%1|%2|HIGHCLIMB_HB|machine=%3|teams=%4|localVeh=%5|started=%6", str isServer, round (time / 60), _machineTag, _perfTeams, _perfLocalVeh, _perfStarted]);
	};

	sleep _sleep;
};
