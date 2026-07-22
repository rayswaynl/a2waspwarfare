/*
	Common_AICOM_AutoFlip.sqf

	Author: claude-gaming (2026-07-01)

	Description:
		AI-COMMANDER auto-unflip. Marty's AutoFlip (Client\Module\AutoFlip\AutoFlip.sqf) rights
		flipped ground vehicles, but it runs CLIENT-SIDE and only watches the player's own vehicle
		and the player's group - so AI-COMMANDER vehicles (local to the SERVER for founded teams,
		or a HEADLESS CLIENT for delegated teams) are never righted and sit stuck on their roof.

		This manager runs where AICOM hulls are LOCAL (server + each HC), enumerates the BOUNDED
		side-logic wfbe_teams group arrays (NO allUnits/allLocal world scan), and rights any local
		AICOM ground vehicle that has sat tilted + stationary + grounded + dry beyond a short delay -
		reusing Marty's exact tilt/slow/grounded/dry/cooldown/stuck-timer thresholds and righting.
		It only ever acts when a vehicle is genuinely flipped AND stuck (never a moving/upright one).

		Flag: WFBE_C_AICOM_AUTOFLIP (default 1 = ON - see Init_CommonConstants.sqf:794).

		DIAGNOSIS NOTE (cmdcon43-k, 2026-07-02): a four-RPT review saw the manager 'started (HC)' line
		but ZERO 'righted=' events on both maps. VERDICT: WORKING-BUT-IDLE, detection is SOUND (it is a
		faithful copy of Marty's proven client AutoFlip). Unlike HighClimb, the righting site already
		carries an ALWAYS-ON diag_log (AICOMSTAT|...|AUTOFLIP|righted=) that flushes to the RPT directly
		(no PerformanceAudit dependency), so zero rightings is real telemetry: no crewed AICOM ground
		hull sat flipped+stuck+grounded+dry+off-cooldown for the 10s window today. That is expected -
		AICOM road-marches (BuildRoadRoute) and the heli terrain-guard / TIER-3 recovery nudge keep
		hulls off the terrain that rolls them. To let a FUTURE soak tell IDLE from a wiring fault, a
		rate-limited manager heartbeat is added below (localVeh + how many were tilted this pass).

		VERIFIED TRIGGER MATH (all conditions must hold, re-checked each 5s pass; any one unmet clears
		the stuck timer): tilt  = (vectorUp _veh) select 2 < 0.35 (hull rolled >~69 deg off level);
		slow  = |velocity| < 2 m/s; grounded = (getPos _veh select 2) < 3 (ASL-Z gate keeps it from
		firing mid-fall/lift); dry = NOT surfaceIsWater (never right a hull in the sea - it belongs to
		the unstuck ladder, cf. Common_RunCommanderTeam:961); off-cooldown = (now - lastFlip) > 45.
		A hull that satisfies all five for >= 10 continuous seconds is righted (setVectorUp [0,0,1] +
		setPos z=0.5 + a small downward settle velocity). KNOWN LIMIT (shared with HighClimb, by
		design): a hull whose crew ejected/died is an EMPTY hull, absent from `units _team`, so it is
		not reached - this manager only rights hulls that flipped WITH crew still aboard (the common
		steep-terrain roll). To PROVOKE one for verification see the PR boot-smoke checklist.
*/

//--- Read inline (Init_CommonConstants owner registers the constant later). Default ON.
if ((missionNamespace getVariable ["WFBE_C_AICOM_AUTOFLIP", 1]) == 0) exitWith {};

//--- Only the server and headless clients host AICOM-local vehicles.
if (!isServer && {!isHeadLessClient}) exitWith {};

private "_aicomInitDeadline"; _aicomInitDeadline = diag_tickTime + 20;
waitUntil { uiSleep 0.25; ((!isNil "WFBE_CO_FNC_AICOMLog") && {!isNil "WFBE_CO_FNC_GetSideLogic"}) || (diag_tickTime > _aicomInitDeadline) };
if (isNil "WFBE_CO_FNC_AICOMLog" || {isNil "WFBE_CO_FNC_GetSideLogic"}) exitWith { diag_log "[WFBE][AICOM-INIT-RACE] Common_AICOM_AutoFlip.sqf: required Init_Common functions still nil after 20s - auto-unflip manager not started."; };
if (isNil "WFBE_CO_FNC_AICOMLog") exitWith { diag_log "[WFBE][AICOM-LOG-INIT-RACE] Common_AICOM_AutoFlip.sqf: WFBE_CO_FNC_AICOMLog still nil after 20s - Init_Common not finished; auto-unflip manager not started."; };

private ["_machineTag"];
_machineTag = if (isServer) then {"SERVER"} else {"HC"};
["INFORMATION", Format ["Common_AICOM_AutoFlip.sqf: AICOM auto-unflip manager started (%1).", _machineTag]] Call WFBE_CO_FNC_AICOMLog;

//--- Per-vehicle righting check (mirrors Marty AutoFlip _processVehicle; server/HC-safe, no systemChat).
//--- _this = [vehicle, now].
WFBE_CO_FNC_AICOM_AutoFlip_Check = {
	private ["_vehicle","_now","_tilt","_maxSpeed","_stuckDelay","_cooldown","_upZ","_vel","_speed","_lastFlip","_since","_pos","_playerNear"];
	_vehicle = _this select 0;
	_now     = _this select 1;

	if (isNull _vehicle) exitWith {};
	if (!alive _vehicle) exitWith {};
	//--- Ground vehicles only (cars + tanks); never Air/Ship/Motorcycle.
	if ((_vehicle isKindOf "Motorcycle") || {_vehicle isKindOf "Air"} || {_vehicle isKindOf "Ship"}) exitWith {};
	//--- setVectorUp/setPos apply only where the object is local.
	if (!local _vehicle) exitWith {};

	_tilt      = 0.35;   //--- upZ below this = tilted/rolled (Marty value).
	_maxSpeed  = 2;      //--- must be effectively stationary.
	_stuckDelay = 10;    //--- seconds tilted+stuck before we right it.
	_cooldown  = 45;     //--- seconds before the same vehicle may be righted again.

	_upZ   = (vectorUp _vehicle) select 2;
	_vel   = velocity _vehicle;
	_speed = sqrt (((_vel select 0) * (_vel select 0)) + ((_vel select 1) * (_vel select 1)) + ((_vel select 2) * (_vel select 2)));
	_lastFlip = _vehicle getVariable ["WFBE_AICOM_AutoFlip_LastFlip", -999];

	//--- Any condition unmet -> not a stuck flip; clear the timer and wait.
	if (_upZ >= _tilt) exitWith {_vehicle setVariable ["WFBE_AICOM_AutoFlip_StuckSince", -1, false]};
	if (_speed >= _maxSpeed) exitWith {_vehicle setVariable ["WFBE_AICOM_AutoFlip_StuckSince", -1, false]};
	if ((getPos _vehicle select 2) >= 3) exitWith {_vehicle setVariable ["WFBE_AICOM_AutoFlip_StuckSince", -1, false]};
	if (surfaceIsWater (getPos _vehicle)) exitWith {_vehicle setVariable ["WFBE_AICOM_AutoFlip_StuckSince", -1, false]};
	if ((_now - _lastFlip) <= _cooldown) exitWith {_vehicle setVariable ["WFBE_AICOM_AutoFlip_StuckSince", -1, false]};

	_since = _vehicle getVariable ["WFBE_AICOM_AutoFlip_StuckSince", -1];
	if (_since < 0) exitWith { _vehicle setVariable ["WFBE_AICOM_AutoFlip_StuckSince", _now, false] };
	if ((_now - _since) < _stuckDelay) exitWith {};

	//--- Right it (Marty's righting: level, lift slightly, settle down).
	_pos = getPos _vehicle;
	_vehicle setVectorUp [0,0,1];
	_vehicle setPos [_pos select 0, _pos select 1, 0.5];
	_vehicle setVelocity [0,0,-0.5];
	_vehicle setVariable ["WFBE_AICOM_AutoFlip_LastFlip", _now, true];
	_vehicle setVariable ["WFBE_AICOM_AutoFlip_StuckSince", -1, false];
	//--- WASPSCALE recov counter (cmdcon42): same shared cumulative recovery-action counter as the unstuck site (recov= on the WASPSCALE line). Auto-flip righting is a recovery action; bumped in this machine's missionNamespace (server or HC, wherever the hull is local). Server emit reports its server-local share. Monotonic.
	missionNamespace setVariable ["wfbe_waspscale_recov", (missionNamespace getVariable ["wfbe_waspscale_recov", 0]) + 1];
	//--- Owner directive: recover even in player view, but expose nearby-player context for RPT tuning.
	_playerNear = 0;
	{if (isPlayer _x && {alive _x} && {(_x distance _vehicle) < 200}) then {_playerNear = _playerNear + 1}} forEach playableUnits;
	diag_log (Format ["AICOMSTAT|v1|EVENT|%1|%2|AUTOFLIP|righted=%3|playersNear=%4", str isServer, round (time / 60), typeOf _vehicle, _playerNear]);
};

//--- Manager loop: bounded enumeration over the side-logic wfbe_teams group arrays.
private ["_sides","_seen","_side","_logik","_teams","_team","_veh","_now","_localVeh","_tilted","_lastHeartbeat"];
_sides = [west, east, resistance];
//--- cmdcon43-k: always-on heartbeat clock (rate-limited 120s below). Lets a soak reading the HC RPT
//--- tell IDLE (localVeh>0 but never tilted -> nothing to right) from a wiring fault (localVeh=0).
_lastHeartbeat = -999;

while {!gameOver} do {
	_now  = time;
	_seen = [];   //--- dedupe hulls inspected this pass.
	_localVeh = 0; //--- distinct machine-local team hulls inspected this pass.
	_tilted   = 0; //--- of those, how many are currently rolled past the tilt threshold (0.35).
	{
		_side  = _x;
		_logik = _side Call WFBE_CO_FNC_GetSideLogic;
		if (!isNil "_logik" && {!isNull _logik}) then {
			//--- wfbe_teams is broadcast (setVariable [...,true]) so readable on server AND every HC.
			_teams = _logik getVariable ["wfbe_teams", []];
			{
				_team = _x;
				if (!isNull _team) then {
					{
						_veh = vehicle _x;
						if (!isNull _veh && {_veh != _x} && {local _veh} && {!(_veh in _seen)}) then {
							_seen set [count _seen, _veh];
							_localVeh = _localVeh + 1;
							//--- cheap tilt read for the heartbeat only (the Check fn re-reads + owns the act decision).
							if (alive _veh && {((vectorUp _veh) select 2) < 0.35}) then {_tilted = _tilted + 1};
							[_veh, _now] Call WFBE_CO_FNC_AICOM_AutoFlip_Check;
						};
					} forEach (units _team);
				};
			} forEach _teams;

			//--- A mobilized side HQ is stored separately from wfbe_teams, yet remains server-local.
			//--- The deployed HQ is a static structure and must never enter vehicle recovery.
			if (!(_logik getVariable ["wfbe_hq_deployed", true])) then {
				_veh = _logik getVariable ["wfbe_hq", objNull];
				if (!isNull _veh && {local _veh} && {!(_veh in _seen)}) then {
					_seen set [count _seen, _veh];
					_localVeh = _localVeh + 1;
					if (alive _veh && {((vectorUp _veh) select 2) < 0.35}) then {_tilted = _tilted + 1};
					[_veh, _now] Call WFBE_CO_FNC_AICOM_AutoFlip_Check;
				};
			};
		};
	} forEach _sides;

	//--- cmdcon43-k ALWAYS-ON heartbeat (rate-limited 120s). A2-OA-safe: diag_log + round + arithmetic,
	//--- no A3 commands, no ==/!= on booleans.
	if ((diag_tickTime - _lastHeartbeat) > 120) then {
		_lastHeartbeat = diag_tickTime;
		diag_log (Format ["AICOMSTAT|v1|EVENT|%1|%2|AUTOFLIP_HB|machine=%3|localVeh=%4|tilted=%5", str isServer, round (time / 60), _machineTag, _localVeh, _tilted]);
	};

	sleep 5;
};
