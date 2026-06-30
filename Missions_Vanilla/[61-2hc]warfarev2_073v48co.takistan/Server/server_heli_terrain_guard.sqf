/*
	server_heli_terrain_guard.sqf — qol-polish-pack (ON by default; set WFBE_C_AIHELI_TERRAIN_GUARD = 0 to disable).

	AI helicopters in A2 hold a fixed flyInHeight (AGL) maintained against the terrain *directly below* them, so on a steep
	up-slope they clip the rising ground ahead before the engine reacts. This loop looks AHEAD along each AI heli's heading and
	raises its flyInHeight when terrain is rising into the flight path — a cheap reactive climb, no pathfinding change.

	A2 OA has NO getTerrainHeightASL (that is an Arma 3 command). We sample terrain height at an arbitrary point the A2 way:
	a single reusable invisible probe object — setPos [x,y,0] grounds it (z is ATL), then getPosASL reads the ground height there.

	Scope: SERVER-LOCAL AI helis only (paradrop/supply, GUER air-defence, W13 gunship, and AICOM helis when no Headless Client).
	HC-local AICOM helis would need an HC-side copy of this loop — left as a follow-up. Reactive only: it raises height, never
	lowers it, so it cannot force a heli into the ground; worst case it briefly delays a low pass. Gated by WFBE_C_AIHELI_TERRAIN_GUARD.
*/
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_AIHELI_TERRAIN_GUARD", 0]) < 1) exitWith {};

private ["_probe","_lookAhead","_clearance"];
_lookAhead = missionNamespace getVariable ["WFBE_C_AIHELI_GUARD_LOOKAHEAD", 250];
_clearance = missionNamespace getVariable ["WFBE_C_AIHELI_GUARD_CLEARANCE", 60];

//--- one reusable terrain-sampling probe (server-local, invisible).
_probe = "Sign_sphere10cm_EP1" createVehicleLocal [0, 0, 0];
_probe hideObject true;

["INITIALIZATION", Format ["server_heli_terrain_guard.sqf: AI-heli terrain guard ON (look-ahead %1m, min clearance %2m).", _lookAhead, _clearance]] Call WFBE_CO_FNC_LogContent;

while {!WFBE_gameover} do {
	{
		private ["_h","_drv","_spd","_dir","_pos","_terrAhead","_heliASL"];
		_h = _x;
		if (_h isKindOf "Helicopter" && {alive _h} && {local _h} && {(getPos _h) select 2 > 8}) then {
			_drv = driver _h;
			if (!isNull _drv && {!isPlayer _drv}) then {
				_spd = speed _h;
				if (_spd > 25) then {
					_dir = direction _h;
					_pos = getPosASL _h;
					//--- look-ahead point along the heli's heading; z=0 (ATL) grounds the probe so getPosASL reads the terrain there.
					_probe setPos [(_pos select 0) + (sin _dir) * _lookAhead, (_pos select 1) + (cos _dir) * _lookAhead, 0];
					_terrAhead = (getPosASL _probe) select 2;
					_heliASL = _pos select 2;
					if ((_heliASL - _terrAhead) < _clearance) then {
						//--- terrain rising into the path: command a climb to restore clearance (engine maintains AGL afterwards).
						_h flyInHeight (_clearance + 25);
					};
				};
			};
		};
	} forEach vehicles;
	sleep 4;
};
