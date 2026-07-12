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
   returned. Any point with 0<=x<=15360 and 0<=y<=15360 trivially satisfies
   this square-boundary test, so the seed below only needs to be real, deep
   water - it does not need a separate in-bounds proof.

   Landlocked maps (no water found within the ring search) also fall back to
   the seed, so the pen still resolves to a real, in-bounds, on-map point
   instead of failing outright - the UNDERWATER property is a Chernarus
   (water-map) bonus, not a hard requirement; immunity comes entirely from the
   existing allowDamage window in Init_Client.sqf, not from this function.
   -------------------------------------------------------------------------- */

private ["_boundary","_half","_seed","_seaPos","_ring","_step","_cand","_posXY","_difx","_dify","_dir","_adis","_bdis","_borderdis","_posdis","_z"];

//--- fable/deadspawn-chernarus-sea (owner 2026-07-09): the previous seed [1000,1000,0] (this file's
//--- header above still described the SW-corner idiom it was copy-pasted from, per Init_HC.sqf's
//--- WFBE_HC_FNC_ParkSeaHC) was NEVER actually verified as water on THIS terrain - only as in-bounds.
//--- Owner report: the deadspawn pen does not land in the sea on Chernarus. [1000,1000] sits in the
//--- SW interior landmass (Chernarus's coastline runs along the east/south, not the west), and the
//--- ring search below only probes 8 fixed rays outward from the seed - it can easily miss real water
//--- that isn't on one of those rays, falling through to the dry-land seed itself.
//--- REPLACEMENT SEED: [10000, 400, 0] - 300m due south of the pre-placed, RPT-self-verified "Khe Sanh
//--- Bravo" naval-HVT carrier logic at world [10000,700] (mission.sqm Item135/Item0, id=9003; anchor
//--- consumed by Server\Init\Init_NavalHVT.sqf:252-254 as _aBravo, labelled "[B] Khe Sanh Bravo (LHD) —
//--- SE sea" at Init_NavalHVT.sqf:326-327). That carrier spawn is guarded by its own runtime check
//--- (Init_NavalHVT.sqf:241-247: diag_log WARN if `!(surfaceIsWater (getPos _lhdBravoLogic))`), so its
//--- anchor is a live, production-verified deep-water point far from any coastline. 400 is chosen
//--- 300m SOUTH of that anchor (further from the mainland, i.e. more conservatively offshore, not
//--- less) so the pen point is comfortably clear of the LHD hull footprint (max ~42m lateral twin-hull
//--- offset per Init_NavalHVT.sqf's TWIN-HULL geometry notes) while staying in the same open "SE sea"
//--- water body. FLAG FOR OWNER: this was derived from mission.sqm/script cross-reference, NOT an
//--- in-engine surfaceIsWater check (no running engine available here) - please sanity-check
//--- [10000,400] on the Chernarus map (or watch the RPT for a "no water found" fallback) before this
//--- ships.
_seed = [10000, 400, 0];
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
