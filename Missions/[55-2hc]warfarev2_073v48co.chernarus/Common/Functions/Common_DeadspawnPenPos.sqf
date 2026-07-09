/* Common_DeadspawnPenPos.sqf  (fable/deadspawn-redesign 2026-07-09)
   --------------------------------------------------------------------------
   Resolve a single, shared, IN-BOUNDS underwater holding-pen position for the
   WFBE_C_DEADSPAWN_REDESIGN feature (Client\Init\Init_Client.sqf join placement).
   Server-agnostic / deterministic - every client independently computes the
   identical point (surfaceIsWater + a fixed seed are not random), so no
   cross-client sync is needed.

   Reuses the exact ring-search idiom already live in Headless\Init\Init_HC.sqf's
   WFBE_HC_FNC_ParkSeaHC (SW sea seed [1000,1000,0], outward ring search for
   surfaceIsWater) rather than inventing new positioning, per the design brief.
   ParkSeaHC itself is HC-only (guarded on side group player == civilian) so it
   cannot be called directly on a human player; this duplicates its positioning
   technique instead of its (HC-scoped) function.

   HARD CONSTRAINT (Client\Functions\Client_HandleOnMap.sqf): anything outside
   the mission boundary for more than WFBE_C_PLAYERS_OFFMAP_TIMEOUT seconds
   (default 50) is force-killed via `setDamage 1`, which bypasses allowDamage -
   immunity means nothing if the pen itself is off-map. So the resolved XY is
   verified in-bounds using the SAME formula Client_IsOnMap.sqf uses
   (WFBE_BOUNDARIESXY square boundary, centred on the map) before being
   returned. If the ring search ever produced an out-of-bounds candidate
   (never observed on Chernarus - the seed itself resolves within the first
   couple of rings - but not analytically guaranteed for an arbitrary ring
   count), this falls back to the literal seed [1000,1000], which IS
   analytically in-bounds on Chernarus (verified by hand: ~9447m from map
   centre vs a ~10861m corner border distance at that bearing) and remains
   in-bounds on any map via the same dynamic WFBE_BOUNDARIESXY check.

   Landlocked maps (no water found within the ring search) also fall back to
   the seed, so the pen still resolves to a real, in-bounds, on-map point
   instead of failing outright - the UNDERWATER property is a Chernarus
   (water-map) bonus, not a hard requirement; immunity comes entirely from the
   existing allowDamage window in Init_Client.sqf, not from this function.
   -------------------------------------------------------------------------- */

private ["_boundary","_half","_seed","_seaPos","_ring","_step","_cand","_posXY","_difx","_dify","_dir","_adis","_bdis","_borderdis","_posdis","_z"];

_seed = [1000, 1000, 0];
_seaPos = [];

if (surfaceIsWater _seed) then { _seaPos = _seed };
_ring = 0;
while {count _seaPos == 0 && {_ring < 40}} do {
	_ring = _ring + 1;
	_step = _ring * 250;
	{
		if (count _seaPos == 0) then {
			_cand = [(1000 + ((_x select 0) * _step)), (1000 + ((_x select 1) * _step)), 0];
			if (surfaceIsWater _cand) then { _seaPos = _cand };
		};
	} forEach [[-1,-1],[-1,0],[0,-1],[-1,1],[1,-1],[0,1],[1,0],[1,1]];
};
if (count _seaPos == 0) then { _seaPos = _seed }; //--- no water found (or landlocked map): fall back to the verified seed.

//--- BOUNDARY GUARD: re-derive the same true/false test Client_IsOnMap.sqf runs on `player`,
//--- against this CANDIDATE point instead, before committing to it. Falls back to the
//--- analytically-verified seed if the candidate somehow fails (belt+suspenders - see header).
_boundary = missionNamespace getVariable ["WFBE_BOUNDARIESXY", 15360];
_half = _boundary / 2;
_posXY = [_seaPos select 0, _seaPos select 1];
_difx = (_posXY select 0) - _half;
_dify = (_posXY select 1) - _half;
_dir = atan (_difx / _dify);
if (_dify < 0) then {_dir = _dir + 180};
_adis = abs (_half / cos (90 - _dir));
_bdis = abs (_half / cos _dir);
_borderdis = _adis min _bdis;
_posdis = _posXY distance [_half,_half];
if !(_posdis < _borderdis) then { _seaPos = _seed; _posXY = [_seed select 0, _seed select 1] };

//--- BUGFIX (fable/deadspawn-redesign, landlocked follow-up): the original version of this
//--- function set Z=-8 unconditionally, including on the DRY fallback branch (no water found
//--- anywhere in the ring search - the realistic case on Takistan/Zargabad). That would have
//--- setPos'd a live player 8m INTO SOLID GROUND at exactly the hazard Init_HC.sqf's own
//--- comment warns about ("NEVER setPos underground - that kills the unit"). Fixed: one
//--- authoritative surfaceIsWater check on the FINAL resolved XY (after every fallback/
//--- boundary-guard branch above has already settled) decides the offset - never inferred
//--- from which branch produced the point.
//--- Submerge only if this point is CONFIRMED water; dry fallback stays at ground level
//--- (Z=0, ATL) - the landlocked enclosure (Init_DeadspawnPenEnclosure.sqf) contains the
//--- player physically instead of relying on depth for a point that isn't water at all.
if (surfaceIsWater [(_posXY select 0), (_posXY select 1), 0]) then { _z = -8 } else { _z = 0 };

[(_posXY select 0), (_posXY select 1), _z]
