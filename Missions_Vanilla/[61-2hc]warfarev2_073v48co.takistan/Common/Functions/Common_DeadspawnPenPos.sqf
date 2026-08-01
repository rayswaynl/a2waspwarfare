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
   CLAMPED into the SAME square Client_IsOnMap.sqf tests (WFBE_BOUNDARIESXY,
   the PER-MAP side length - 8192 on Zargabad, not always 15360) before being
   returned. The seed below only needs to be real, deep water on the source
   terrain; the clamp - not any property of the seed - is what guarantees the
   returned point is in-bounds on every terrain.

   Landlocked maps (no water found within the ring search) also fall back to
   the seed, which the boundary clamp below then forces on-map, so the pen
   still resolves to a real, in-bounds point
   instead of failing outright - the UNDERWATER property is a Chernarus
   (water-map) bonus, not a hard requirement; immunity comes entirely from the
   existing allowDamage window in Init_Client.sqf, not from this function.
   -------------------------------------------------------------------------- */

private ["_boundary","_half","_margin","_seed","_seaPos","_ring","_step","_cand","_posXY","_difx","_dify","_dir","_adis","_bdis","_borderdis","_posdis","_z"];

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
			//--- r54: ring must radiate from the resolved _seed, not a stale hardcoded SW [1000,1000].
			//--- After the SE-sea seed move to [10000,400], probing from 1000,1000 missed nearby water
			//--- and fell through to a dry/wrong fallback on maps where the seed itself is land.
			_cand = [((_seed select 0) + ((_x select 0) * _step)), ((_seed select 1) + ((_x select 1) * _step)), 0];
			if (surfaceIsWater _cand) then { _seaPos = _cand };
		};
	} forEach [[-1,-1],[-1,0],[0,-1],[-1,1],[1,-1],[0,1],[1,0],[1,1]];
};
if (count _seaPos == 0) then { _seaPos = _seed }; //--- no water found (or landlocked map): fall back to the verified seed.

//--- BOUNDARY GUARD: same square AABB Client_IsOnMap.sqf uses (no atan/cos axis div0).
//--- fix(2026-08-01): the previous guard FELL BACK to _seed when the candidate was outside
//--- [0..B]^2 - but on a no-water map the candidate it just rejected IS _seed (fallback
//--- above), so the guard re-selected the same off-map point. On Zargabad
//--- (WFBE_BOUNDARIESXY = 8192 < seed x = 10000, Common\Init\Init_Boundaries.sqf) the join
//--- pen therefore resolved off-map and Client_HandleOnMap.sqf force-killed joining players
//--- once the Init_Client.sqf invulnerability window lapsed. CLAMP each axis into
//--- [margin .. B-margin] instead: deterministic (every client and
//--- Init_DeadspawnPenEnclosure.sqf compute the same clamp), a no-op wherever the point was
//--- already in-bounds (Chernarus/Takistan resolve exactly as before), and the final
//--- surfaceIsWater check below re-decides wet/dry for any moved point.
//--- RACE HARDENING: Init_Client.sqf calls this resolver inline at join placement, BEFORE
//--- Init_Common.sqf (which runs Init_Boundaries.sqf at line 416) is guaranteed to have run -
//--- the two are independent execVM threads with no ordering (documented at
//--- Init_Client.sqf:78-87). If WFBE_BOUNDARIESXY is still nil here, a bare 15360 default
//--- would un-clamp Zargabad (8192) right back off the map on the racing client while the
//--- server-side enclosure (post-Init_Common) clamps against the real value - divergence.
//--- Derive the boundary from worldName instead when the variable is not yet set: same
//--- idiom + table as Common_RunCommanderTeam.sqf ~904 / Init_Boundaries.sqf (worldSize is
//--- A3-only), identical on every machine at every init phase.
_boundary = missionNamespace getVariable ["WFBE_BOUNDARIESXY", -1];
if (_boundary < 0) then {
	_boundary = switch (toLower worldName) do {
		case "chernarus": {15360};
		case "takistan":  {12800};
		case "zargabad":  {8192};
		default {15360};
	};
};
_margin = 100; //--- keeps the 8m Init_DeadspawnPenEnclosure.sqf ring plus its occupant clear of the kill boundary.
_posXY = [_seaPos select 0, _seaPos select 1];
if ((_posXY select 0) < _margin) then { _posXY set [0, _margin] };
if ((_posXY select 0) > (_boundary - _margin)) then { _posXY set [0, (_boundary - _margin)] };
if ((_posXY select 1) < _margin) then { _posXY set [1, _margin] };
if ((_posXY select 1) > (_boundary - _margin)) then { _posXY set [1, (_boundary - _margin)] };

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
