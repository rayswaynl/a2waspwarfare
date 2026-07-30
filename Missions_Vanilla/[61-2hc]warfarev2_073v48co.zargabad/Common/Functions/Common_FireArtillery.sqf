Private["_ammo","_angle","_artillery","_artillery_classes","_artillery_type","_burst","_CBREH","_destination","_dispersion","_direction","_distance","_FEH","_ffAbort","_ffNear","_ffRad","_gunner","_i","_index","_minRange","_maxRange","_position","_radius","_reloadTime","_side","_type","_velocity","_watchPosition","_weapon","_xcoord","_ycoord"];

_artillery = _this select 0;
_destination = _this select 1;
_side = _this select 2;
_radius = _this select 3;
_index = [typeOf _artillery, _side] Call IsArtillery;

_gunner = gunner _artillery;
if (_index == -1) exitWith {["WARNING", Format ["Common_FireArtillery.sqf: No artillery types were found for [%1].", _artillery]] Call WFBE_CO_FNC_LogContent};
if (isNull _gunner) exitWith {["WARNING", Format ["Common_FireArtillery.sqf: Artillery [%1] gunner is null.", _artillery]] Call WFBE_CO_FNC_LogContent};
if (isPlayer _gunner) exitWith {["WARNING", Format ["Common_FireArtillery.sqf: Artillery [%1] gunner is a player", _artillery]] Call WFBE_CO_FNC_LogContent};

//--- NUMERIC: WFBE_C_ARTILLERY 0 = Disabled (Init_CommonConstants). Divisor must never be 0
//--- (range max / 0 -> scalar NaN). Exit clean before ARTY_Prep locks the piece.
if ((missionNamespace getVariable ["WFBE_C_ARTILLERY", 1]) <= 0) exitWith {
	["WARNING", Format ["Common_FireArtillery.sqf: Artillery fire missions disabled (WFBE_C_ARTILLERY=%1).", missionNamespace getVariable ["WFBE_C_ARTILLERY", 0]]] Call WFBE_CO_FNC_LogContent;
};

//--- WFBE_C_ARTILLERY_DISABLED_GUARD
_artillery setVariable ["restricted",true];
{if(isPlayer _x) then {_x action  ["getOut", _artillery]};} forEach (crew _artillery);

_minRange 	= (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MIN",_side]) select _index;
_maxRange 	= round(((missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MAX",_side]) select _index) / ((missionNamespace getVariable ["WFBE_C_ARTILLERY", 1]) max 1));
_weapon 	= (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_WEAPONS",_side]) select _index;
_ammo 		= (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_AMMOS",_side]) select _index;
_velocity 	= (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_VELOCITIES",_side]) select _index;
_dispersion = (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_DISPERSIONS",_side]) select _index;
_reloadTime = (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_TIME_RELOAD",_side]) select _index;
_burst 		= (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_BURST",_side]) select _index;

//--- Prepare the artillery unit to the fire mission submission.
[_artillery] Call ARTY_Prep; 

//--- Artillery Calculations.
_position = getPos _artillery;
_xcoord = (_destination select 0) - (_position select 0);
_ycoord = (_destination select 1) - (_position select 1);
_direction =  -(((_ycoord atan2 _xcoord) + 270) % 360);
if (_direction < 0) then {_direction = _direction + 360};
_distance = sqrt ((_xcoord ^ 2) + (_ycoord ^ 2)) - _minRange;
_angle = _distance / (((_maxRange - _minRange) max 1)) * 100 + 15;
if (_angle > 70) then {_angle = 70};
//--- N-FEATUREBUG-39: out-of-range early exit. ARTY_Prep (above) already stopped the vehicle and
//--- disabled the driver's AI, and line 7 set restricted=true. Returning here without undoing that
//--- left the piece PERMANENTLY locked (engine off, driver AI dead, restricted flag stuck) and
//--- unusable for the next fire mission. Run the SAME teardown the normal completion path uses:
//--- ARTY_Finish (re-enable driver AI, lower the gun) + clear restricted, so the piece is reusable.
if (_distance < 0 || _distance + _minRange > _maxRange) exitWith {
	[_artillery] Call ARTY_Finish;
	_artillery setVariable ["restricted",false];
};

_FEH = Call Compile Format ["_artillery addEventHandler ['Fired',{[_this select 4,_this select 6,%1,%2,%3,%4,%5,%6,%7,%8,%9] Spawn WFBE_CO_FNC_HandleArtillery}];",_ammo,_destination,_velocity,_dispersion,getPos _artillery,_distance,_radius,_maxRange,_side];

//--- CBR detection hook: runs where the arty is local (server for AI; client for player-crewed).
//--- Route to server in both cases via SendToServer when not already on server.
//--- Capture return index so we can remove this EH after the fire mission (prevents accumulation).
_CBREH = -1;
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) > 0) then {
	_CBREH = _artillery addEventHandler ['Fired', {
		private ["_firer","_fpos","_pkt"];
		_firer = _this select 0;
		_fpos  = getPos _firer;
		if (isServer) then {
			[_firer, _fpos] Call WFBE_SE_FNC_CounterBatteryCheck;
		} else {
			["CounterBatteryFired", [_firer, _fpos]] Call WFBE_CO_FNC_SendToServer;
		};
	}];
};

{_gunner disableAI _x} forEach ['MOVE','TARGET','AUTOTARGET'];
_watchPosition = [_destination select 0, _destination select 1, (_artillery distance _destination)/(tan(90-_angle))];

(_gunner) doWatch _watchPosition;

sleep (10 + random 4);

if !(alive _gunner) exitWith {
	if !(isNull _artillery) then {
		//--- Remove the higher-index CBR EH FIRST: A2 removeEventHandler re-indexes later EHs
		//--- down, so pulling _FEH first shifts _CBREH's stored index and leaks the CBR handler.
		if (_CBREH >= 0) then {_artillery removeEventHandler ['Fired',_CBREH]};
		_artillery removeEventHandler ['Fired',_FEH];
		if (alive _artillery) then {
			if (alive (driver _artillery)) then {{(driver _artillery) enableAI _x} forEach ['MOVE','TARGET','AUTOTARGET']};
			_artillery setVariable ["restricted",false];
		};
	};
};
if !(alive _artillery) exitWith {
	if (alive _gunner) then {{_gunner enableAI _x} forEach ['MOVE','TARGET','AUTOTARGET']};
};

//--- r30 fire-deconflict: re-check FRIENDLIES AT IMPACT after the aim sleep (and each round).
//--- Strategy/PlayerArty gate friendlies at decision time (~400m) then Spawn this script, which
//--- sleeps 10+s before the first shot - advancing own squads can enter the impact zone meanwhile.
//--- Measure from _destination (impact), not the battery. Abort with full teardown (restricted clear).
_ffRad = 400;
_ffNear = 0;
{ if (alive _x && {side _x == _side}) then {_ffNear = _ffNear + 1} } forEach (_destination nearEntities [["Man","Car","Tank","Air"], _ffRad]);
if (_ffNear > 0) exitWith {
	if !(isNull _artillery) then {
		if (_CBREH >= 0) then {_artillery removeEventHandler ['Fired',_CBREH]};
		_artillery removeEventHandler ['Fired',_FEH];
		if (alive _artillery) then {
			[_artillery] Call ARTY_Finish;
			if (alive (driver _artillery)) then {{(driver _artillery) enableAI _x} forEach ['MOVE','TARGET','AUTOTARGET']};
			_artillery setVariable ["restricted",false];
		};
	};
	if (alive _gunner) then {{_gunner enableAI _x} forEach ['MOVE','TARGET','AUTOTARGET']};
	diag_log ("ARTILLERY|v1|ABORT_FRIENDLY|side=" + str _side + "|near=" + str _ffNear + "|rad=" + str _ffRad);
};

for '_i' from 1 to _burst do {
	sleep (_reloadTime+random 3);
	if (!alive _gunner || !alive _artillery) exitWith {};
	//--- Per-round FF recheck (multi-round missions must not walk onto friendlies).
	_ffNear = 0;
	{ if (alive _x && {side _x == _side}) then {_ffNear = _ffNear + 1} } forEach (_destination nearEntities [["Man","Car","Tank","Air"], _ffRad]);
	if (_ffNear > 0) exitWith {
		diag_log ("ARTILLERY|v1|ABORT_FRIENDLY_ROUND|side=" + str _side + "|near=" + str _ffNear + "|round=" + str _i);
	};
	_artillery fire _weapon;
};

sleep 1;

if !(isNull _artillery) then {
	//--- Remove _CBREH (higher index) before _FEH; A2 re-indexes EHs on removal (see teardown note above).
	if (_CBREH >= 0) then {_artillery removeEventHandler ['Fired',_CBREH]};
	_artillery removeEventHandler ['Fired',_FEH];
};

sleep (_reloadTime + 20);

if (alive (_gunner)) then {{_gunner enableAI _x} forEach ['MOVE','TARGET','AUTOTARGET']};

//--- fix(arty-lifecycle): the gun can be DELETED during the tail sleeps above - the server_groupsGC
//--- commander-artillery wreck reaper, a base GC pass, or a player selling the hull. ARTY_Finish
//--- dereferences the vehicle unconditionally (getPos / getDir / gunner lookAt) and setVariable on a
//--- null object throws, so both tail statements errored whenever a fire mission outlived its gun.
//--- Every other artillery touch in this file is already isNull/alive guarded (L73-85, L89, L96-99);
//--- these two were the only unguarded ones. Re-checked after the 5s sleep - it can die in that window.
if (!isNull _artillery) then {
	[_artillery] Call ARTY_Finish; //--- Free the artillery unit from the fire mission submission.
	sleep 5;
	if (!isNull _artillery) then {_artillery setVariable ["restricted",false]};
};

