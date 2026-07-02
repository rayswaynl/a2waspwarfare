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

		Flag: WFBE_C_AICOM_AUTOFLIP (default 1 = ON).
*/

//--- Read inline (Init_CommonConstants owner registers the constant later). Default ON.
if ((missionNamespace getVariable ["WFBE_C_AICOM_AUTOFLIP", 1]) == 0) exitWith {};

//--- Only the server and headless clients host AICOM-local vehicles.
if (!isServer && {!isHeadLessClient}) exitWith {};

private ["_machineTag"];
_machineTag = if (isServer) then {"SERVER"} else {"HC"};
["INFORMATION", Format ["Common_AICOM_AutoFlip.sqf: AICOM auto-unflip manager started (%1).", _machineTag]] Call WFBE_CO_FNC_AICOMLog;

//--- Per-vehicle righting check (mirrors Marty AutoFlip _processVehicle; server/HC-safe, no systemChat).
//--- _this = [vehicle, now].
WFBE_CO_FNC_AICOM_AutoFlip_Check = {
	private ["_vehicle","_now","_tilt","_maxSpeed","_stuckDelay","_cooldown","_upZ","_vel","_speed","_lastFlip","_since","_pos"];
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
	diag_log (Format ["AICOMSTAT|v1|EVENT|%1|%2|AUTOFLIP|righted=%3", str isServer, round (time / 60), typeOf _vehicle]);
};

//--- Manager loop: bounded enumeration over the side-logic wfbe_teams group arrays.
private ["_sides","_seen","_side","_logik","_teams","_team","_veh","_now"];
_sides = [west, east, resistance];

while {!gameOver} do {
	_now  = time;
	_seen = [];   //--- dedupe hulls inspected this pass.
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
							[_veh, _now] Call WFBE_CO_FNC_AICOM_AutoFlip_Check;
						};
					} forEach (units _team);
				};
			} forEach _teams;
		};
	} forEach _sides;
	sleep 5;
};
