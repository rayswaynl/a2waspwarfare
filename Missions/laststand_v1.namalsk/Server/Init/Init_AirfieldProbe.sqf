/*
	Init_AirfieldProbe.sqf  (claude-gaming 2026-06-14)

	DIAGNOSTIC ONLY -- changes NO coordinates and spawns NO objects.

	The airfield capture camps (mission.sqm LocationLogicCamp id=308 NWAF /
	id=310 Balota) sit ~300m south of the real airfields. Blind coordinate
	guesses were refuted, so instead of guessing we PROBE.

	At mission start this logs the on-land validity of a 5x5 grid of candidate
	camp positions around each airfield's LocationLogicAirport logic:
		Balota id=7  ~[4550, 2280]
		NWAF  id=8  ~[4479, 10618]

	Grid = a 5x5 set of (x,y) offsets around each airport logic, using the
	requested +/-0,40,80,120m magnitudes collapsed to 5 sample points per axis:
	OFFSETS = [-120,-40,0,40,120]. 5 x 5 = 25 candidates per field.

	For every candidate it emits ONE pipe line that can be grepped from the RPT:
		AIRFIELD_PROBE|v1|field:<NWAF|Balota>|x:..|y:..|water:<bool>|roads:<count>

	A2-OA ONLY: surfaceIsWater, nearRoads, getPosASL/ATL. NO isOnRoad / A3 cmds.
*/

if (!isServer) exitWith {};

[] spawn {
	//--- One-shot, run once after a short settle delay so the world/roads are loaded.
	if (!isNil "wfbe_airfield_probe_done") exitWith {};
	wfbe_airfield_probe_done = true;

	uiSleep 20;

	//--- 5x5 grid: +/-0,40,80,120m magnitudes -> 5 offsets per axis.
	private ["_offsets","_fields","_x0","_y0","_px","_py","_pos","_water","_roads"];
	_offsets = [-120, -40, 0, 40, 120];

	//--- Known airport-logic anchors (x,y) from mission.sqm: Balota id=7, NWAF id=8.
	_fields = [
		["Balota", 4550,    2280],
		["NWAF",   4479.3252, 10618.404]
	];

	diag_log "AIRFIELD_PROBE|v1|begin|grid:5x5|offsets:-120,-40,0,40,120";

	{
		private ["_name","_ax","_ay"];
		_name = _x select 0;
		_ax   = _x select 1;
		_ay   = _x select 2;

		{
			_px = _x;
			{
				_py = _x;
				//--- Candidate [x,y] on the airport-logic plane.
				_pos = [_ax + _px, _ay + _py, 0];
				//--- surfaceIsWater takes a 2D/3D pos; true => in the sea, reject.
				_water = surfaceIsWater _pos;
				//--- nearRoads within 8m; a non-empty list means on/at a road, reject for an apron.
				_roads = count (_pos nearRoads 8);

				diag_log Format [
					"AIRFIELD_PROBE|v1|field:%1|x:%2|y:%3|water:%4|roads:%5",
					_name,
					(_ax + _px),
					(_ay + _py),
					_water,
					_roads
				];
			} forEach _offsets;
		} forEach _offsets;
	} forEach _fields;

	diag_log "AIRFIELD_PROBE|v1|end";
};
