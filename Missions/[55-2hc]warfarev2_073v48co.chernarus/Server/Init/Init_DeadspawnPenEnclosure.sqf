/* Init_DeadspawnPenEnclosure.sqf  (fable/deadspawn-redesign 2026-07-09)
   --------------------------------------------------------------------------
   LANDLOCKED-MAP holding cell for the WFBE_C_DEADSPAWN_REDESIGN pen. Server-only,
   one-shot at init, flag-gated (only runs when the redesign is armed).

   Common_DeadspawnPenPos.sqf resolves EVERY client (and this script) to the SAME
   deterministic point (no randomness). On a water map (Chernarus) that's an
   underwater point (Z=-8) and nothing needs building here. On a landlocked map
   (no surfaceIsWater hit anywhere in the ring search - Takistan; Zargabad's
   coastline, if any, doesn't reach the shared seed either) the resolver falls
   back to the verified-in-bounds seed at GROUND level (Z=0) - a bare, open point
   with nothing around it. This script builds a small sealed cell there so the
   landlocked pen reads as a "dead, waiting" holding area rather than an exposed
   open point: reuses the EXACT ring-building idiom already live in
   Init_DeadspawnWall.sqf (same Land_HBarrier_large class, same createVehicle /
   enableSimulation / allowDamage pattern) at a tighter, single-occupant radius.

   Calls the SAME resolver function every client calls (WFBE_CO_FNC_DeadspawnPenPos)
   rather than re-deriving the seed/search independently, so the enclosure is
   guaranteed to land exactly where clients actually end up - no risk of the two
   drifting apart if the search/fallback logic in that function ever changes.

   Distinguishes water vs landlocked by the returned Z: the resolver only ever
   returns Z=-8 (confirmed underwater) or Z=0 (dry fallback) - see
   Common_DeadspawnPenPos.sqf's own final surfaceIsWater check.
   -------------------------------------------------------------------------- */

if (!isServer) exitWith {};

private ["_pos","_radius","_segLen","_perim","_step","_count","_i","_ang","_px","_py","_prop","_built","_allProps","_wallCls"];

_pos = [] call WFBE_CO_FNC_DeadspawnPenPos;

if ((_pos select 2) == 0) then {
	//--- Landlocked resolution (dry fallback) - build the sealed cell.
	_wallCls = "Land_HBarrier_large"; //--- same proven LoS/line-of-fire blocker as Init_DeadspawnWall.sqf.
	_radius  = 8; //--- tighter than the 12m per-side wall-pen ring - a single-occupant holding cell, not a shared pen.
	_segLen  = 5;

	_perim = 2 * 3.14159 * _radius;
	_count = ceil (_perim / _segLen);
	if (_count < 8) then {_count = 8};
	_step  = 360 / _count;

	_allProps = [];
	_built = 0;
	for "_i" from 0 to (_count - 1) do {
		_ang = _i * _step;
		_px = (_pos select 0) + _radius * (sin _ang);
		_py = (_pos select 1) + _radius * (cos _ang);

		_prop = createVehicle [_wallCls, [_px, _py, 0], [], 0, "NONE"];
		if (isNull _prop) then {
			["WARNING", Format ["Init_DeadspawnPenEnclosure.sqf: class [%1] failed createVehicle at ring point %2.", _wallCls, [_px,_py]]] Call WFBE_CO_FNC_LogContent;
		} else {
			_prop setDir (_ang + 90);
			_prop setPosATL [_px, _py, 0];
			_prop setVectorUp [0,0,1];
			_prop enableSimulation false;
			_prop allowDamage false;
			_allProps = _allProps + [_prop];
			_built = _built + 1;
		};
	};

	missionNamespace setVariable ["WFBE_DEADSPAWN_PEN_ENCLOSURE_PROPS", _allProps];
	["INITIALIZATION", Format ["Init_DeadspawnPenEnclosure.sqf: landlocked pen enclosed at %1 with %2 barriers (r=%3m).", _pos, _built, _radius]] Call WFBE_CO_FNC_LogContent;
} else {
	["INITIALIZATION", Format ["Init_DeadspawnPenEnclosure.sqf: pen resolved underwater at %1 - no enclosure needed on this map.", _pos]] Call WFBE_CO_FNC_LogContent;
};
