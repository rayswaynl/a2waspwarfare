/*
	Common_GetRunwaySpawn.sqf - fable/air-cluster (owner 2026-07-27 "planes dont even spawn on the runway").

	Resolve a fixed-wing spawn slot on the nearest LAND runway OWNED by the given side.
	Runway identity = the editor-placed LocationLogicAirport logics (Init_Airports.sqf seats a hangar
	on each; the logic direction is the strip heading). Ownership via WFBE_CO_FNC_GetAirfieldOwnerSideID
	(nearest town logic within WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS).

	Parameters:  0: sideID (numeric)   1: fallback position (array or object)
	Returns:     [[x,y,0], runwayDir]  or  [] when the side owns no land airfield (caller keeps its
	             own position - byte-identical fallback).

	Carrier "airfields" are town logics, not LocationLogicAirport entities, so they never enter the
	scan; the surfaceIsWater guard is belt-and-braces on top.
*/

private ["_sid","_fb","_afs","_best","_bestD","_d","_own","_dir","_pos","_try","_blocked"];

_sid = _this select 0;
_fb  = _this select 1;
if (typeName _fb == "OBJECT") then {_fb = getPos _fb};

_afs = [0,0,0] nearEntities [["LocationLogicAirport"], 100000];
_best = objNull;
_bestD = 1000000;
{
	if (!(surfaceIsWater (getPos _x))) then {
		_own = [_x] Call WFBE_CO_FNC_GetAirfieldOwnerSideID;
		if (_own == _sid) then {
			_d = _x distance _fb;
			if (_d < _bestD) then {_bestD = _d; _best = _x};
		};
	};
} forEach _afs;

if (isNull _best) exitWith { [] };

//--- fable/walls-and-runway (owner live report 2026-07-28, player 777 "plane not spawning when
//--- buying"): the scan radius above is 100km - effectively the whole map - so the "nearest owned
//--- runway" could be kilometres from the factory the player actually bought at. The plane DID
//--- spawn; it just materialised at a distant airfield with no indication, which reads exactly like
//--- a failed purchase. Cap the relocation: beyond WFBE_C_AIR_RUNWAY_MAX_DIST the caller keeps its
//--- own apron position (the same byte-identical fallback as owning no airfield at all). The
//--- owner intent - "planes spawn on the runway" - is preserved wherever a runway is actually
//--- part of that base. 0 disables the cap (legacy whole-map behaviour).
private "_maxD";
_maxD = missionNamespace getVariable ["WFBE_C_AIR_RUNWAY_MAX_DIST", 2500];
if (_maxD > 0 && {_bestD > _maxD}) exitWith {
	diag_log Format ["AIRSPAWN|v3|runway-skip|reason=too-far|dist=%1|cap=%2|sideID=%3", round _bestD, _maxD, _sid];
	[]
};

_dir = getDir _best;
_pos = [getPos _best, missionNamespace getVariable ["WFBE_C_AIR_RUNWAY_OFFSET", 60], _dir] Call GetPositionFrom;

//--- Occupied-slot slide: step further along the strip past parked fixed-wing (bounded, no exitWith).
_try = 0;
_blocked = true;
while {_blocked && {_try < 4}} do {
	_blocked = ({(_x isKindOf "Plane") && {alive _x}} count (_pos nearEntities [["Air"], 18])) > 0;
	if (_blocked) then {
		_pos = [_pos, 30, _dir] Call GetPositionFrom;
		_try = _try + 1;
	};
};

[[_pos select 0, _pos select 1, 0], _dir]
