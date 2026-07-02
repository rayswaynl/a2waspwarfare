/* Init_DeadspawnWall.sqf  (claude-gaming 2026-06-14)
   --------------------------------------------------------------------------
   PHYSICAL deadspawn protection. Server-only, one-shot at init.

   PROBLEM: the three per-side holding markers (WestTempRespawnMarker /
   EastTempRespawnMarker / GuerTempRespawnMarker) sit only 64-128m apart on a
   bare NE-Chernarus mountaintop. AI-slot bots respawn EXACTLY onto their own
   side's marker (Server\AI\AI_AdvancedRespawn.sqf:29, AI_SquadRespawn.sqf), so
   an enemy-side bot has clear line-of-fire onto a HUMAN parked on an adjacent
   side's marker during join. That is the "AI killed <player> in the deadspawn"
   kill (Smarty incident). The worst sightlines are GUER<->EAST (~44.5m) and
   GUER<->WEST (~52m).

   FIX: ring each side's marker with a closed square of tall H-barriers that
   block line-of-fire/LoS between the three holding points. This is PURELY
   ADDITIVE and touches no protected file:
     - It does NOT trap players: Task-35 (Client\Init\Init_Client.sqf:502-539)
       TELEPORTS the joiner to base; they never walk out, so a fully sealed
       ring is fine. A 120s watchdog (Init_Client.sqf:20-26) re-enables damage
       even if the move stalls. The allowDamage-false transit protection in
       Init_Client.sqf is left untouched - this wall is a second, physical layer.
     - It does NOT leave any human captive / AI-disabled (we never call
       setCaptive/disableAI - the standing hard guardrail).

   IMPLEMENTATION NOTES:
     - Reuses Land_HBarrier_large, already proven on this CO+EP1 box (used
       throughout Server\Init\Init_Defenses.sqf wall templates).
     - Spawns with createVehicle (GLOBAL - must be server-authoritative on a
       dedicated server so AI LoS/collision sees the wall), per the standing
       rule against createVehicleLocal here.
     - Each barrier gets enableSimulation false (no physics cost) and
       allowDamage false (bots can't shoot the wall down) so the protection is
       permanent and cheap.
     - Reads getMarkerPos per side so it follows the marker's own elevation
       (the three differ by up to ~12m); no hardcoded height.
     - Logs any class that fails to load (isNull) like
       Server\Functions\Server_SpawnStructureDressing.sqf:48-51 does, then keeps
       going, so a missing class degrades gracefully instead of erroring.
   -------------------------------------------------------------------------- */

if (!isServer) exitWith {};

private ["_wallCls","_radius","_segLen","_markers","_allProps","_mk","_c","_perim","_step","_count","_i","_ang","_px","_py","_pos","_prop","_built"];

//--- Tall LoS/line-of-fire blocker. Confirmed-present class on this CO server
//--- (Server\Init\Init_Defenses.sqf wall templates). ~5m long per segment.
_wallCls = "Land_HBarrier_large";

//--- Half-width of the square ring around each marker. 12m gives a ~24m box:
//--- comfortably larger than the ~15-20m per-side footprint, and the nearest
//--- neighbouring marker is 64.5m away so rings never overlap.
_radius  = 12;

//--- Approx footprint length of one H-barrier section. Drives how many
//--- segments are laid per side so the ring is solid (no shoot-through gaps).
_segLen  = 5;

_markers = ["WestTempRespawnMarker","EastTempRespawnMarker","GuerTempRespawnMarker"];

_allProps = [];

{
	_mk = _x;
	_c  = getMarkerPos _mk;   //--- [x,y,z] at marker's own world pos.

	//--- Skip ONLY this marker if it doesn't resolve (getMarkerPos returns [0,0,0]
	//--- for an unknown name). Use a guarded block, NOT exitWith - exitWith would
	//--- abort the whole forEach and skip the remaining sides. All three markers are
	//--- static in mission.sqm so this is just defensive.
	if ((_c select 0) == 0 && (_c select 1) == 0) then {
		["WARNING", Format ["Init_DeadspawnWall.sqf: marker [%1] did not resolve (got [0,0,0]); skipped.", _mk]] Call WFBE_CO_FNC_LogContent;
	} else {

	//--- Lay a closed CIRCULAR ring of barriers around the marker. A ring has no
	//--- corner gaps and fully encloses the holding point (player teleports out via
	//--- Task-35, so no doorway is needed). Walk the circle at ~_segLen spacing so
	//--- adjacent tangent-oriented barriers overlap into a continuous wall.
	_perim = 2 * 3.14159 * _radius;             //--- circumference of the ring
	_count = ceil (_perim / _segLen);           //--- number of barrier segments
	if (_count < 8) then {_count = 8};          //--- floor so even a tiny ring is sealed
	_step  = 360 / _count;

	_built = 0;
	for "_i" from 0 to (_count - 1) do {
		_ang = _i * _step;

		//--- Point on the ring at this bearing from the marker centre.
		_px = (_c select 0) + _radius * (sin _ang);
		_py = (_c select 1) + _radius * (cos _ang);

		_pos = [_px, _py, 0];

		_prop = createVehicle [_wallCls, _pos, [], 0, "NONE"];
		if (isNull _prop) then {
			//--- Class failed to load on this CO server: log once and keep going.
			["WARNING", Format ["Init_DeadspawnWall.sqf: class [%1] failed createVehicle for marker [%2].", _wallCls, _mk]] Call WFBE_CO_FNC_LogContent;
		} else {
			//--- Orient the long face TANGENT to the ring (perpendicular to the radius)
			//--- so consecutive barriers form a continuous wall, not radial spokes.
			_prop setDir (_ang + 90);
			//--- Pin to this marker's own terrain elevation (markers differ by up to ~12m).
			_prop setPosATL [_px, _py, 0];
			_prop setVectorUp [0,0,1];
			//--- Cheap + indestructible: no physics, bots can't shoot it down.
			_prop enableSimulation false;
			_prop allowDamage false;
			_allProps = _allProps + [_prop];
			_built = _built + 1;
		};
	};

	["INITIALIZATION", Format ["Init_DeadspawnWall.sqf: ringed [%1] at %2 with %3 barriers (r=%4m).", _mk, _c, _built, _radius]] Call WFBE_CO_FNC_LogContent;

	}; //--- end else (marker resolved)

} forEach _markers;

//--- Keep a handle on the props (debugging / potential teardown) without broadcasting.
missionNamespace setVariable ["WFBE_DEADSPAWN_WALL_PROPS", _allProps];

["INITIALIZATION", Format ["Init_DeadspawnWall.sqf: deadspawn enclosure complete - %1 barriers spawned across %2 side markers.", count _allProps, count _markers]] Call WFBE_CO_FNC_LogContent;
