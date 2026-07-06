/*
	AI Commander - deploy the HQ and build the base, following the side's doctrine.
	feat/ai-commander V0.2. Server-side worker, full-command mode only.
	Parameter: _this = side.

	Doctrine (wfbe_aicom_doctrine, picked by the supervisor): "LF" or "HF" decides
	which production factory is built first; everything is built eventually.
	One construction per call (gentle supply drain, no build spam). Costs are paid
	from side supply exactly like a human commander's COIN build (the client normally
	deducts before RequestStructure; here the server deducts itself).
*/

private ["_side","_sideText","_logik","_hq","_supply","_names","_classes","_costs","_scripts","_structures","_doctrine","_order","_idx","_have","_cost","_class","_script","_pos","_ang","_hqPos","_defMax","_defCount","_defClass","_defData","_defPrice","_funds","_deployCost","_dual","_findBuildPos","_buildPosClear","_isUsableRoad","_nearUsableRoad","_factoryRally","_upgrades","_coreDone","_placed","_roads","_cand","_artyBuilt","_artyClasses","_fam","_i","_bankIdx","_bankCost","_cbrIdx","_scaffoldActivated","_dPos","_dTry","_dAng","_artyThreat","_enemySide","_enemySideText","_enemyArtyCount","_artyScanRadius","_cbrCost","_cbrReserve","_cbrMinTime","_myID","_ownTowns","_defDir","_resIdx","_resCost","_artradIdx","_artradCost","_artradReqArty","_econGateTowns","_econMyID","_econOpen","_roadClearOK","_slopeOK","_treeClearOK","_tp19RoadClearOK"];  //--- cmdcon41-w3k: +_roadClearOK (road-clear placement gate helper).

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (isNull _hq || {!alive _hq}) exitWith {};

_dual = (missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0;
_supply = if (_dual) then {(_side) Call WFBE_CO_FNC_GetSideSupply} else {9000000};

_names   = missionNamespace getVariable Format ["WFBE_%1STRUCTURES", _sideText];
_classes = missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText];
_costs   = missionNamespace getVariable Format ["WFBE_%1STRUCTURECOSTS", _sideText];
_scripts = missionNamespace getVariable Format ["WFBE_%1STRUCTURESCRIPTS", _sideText];
if (isNil "_names" || isNil "_classes" || isNil "_costs" || isNil "_scripts") exitWith {};

//--- 1) Deploy the HQ where it stands (the MHQ starts at the side's start location).
if (!((_side) Call WFBE_CO_FNC_GetSideHQDeployStatus)) exitWith {
	if (_logik getVariable ["wfbe_hqinuse", false]) exitWith {};
	//--- B62 (Ray 2026-06-21): MHQ/Base double-deploy lock. If an MHQ relocation is mid-drive
	//--- (AI_Commander_MHQReloc set wfbe_mhqreloc_active), do NOT re-deploy a fresh HQ at the old
	//--- spot - that races the relocation and double-deploys. The reloc worker clears the flag on
	//--- finish/abort; until then the Base worker stands down on the deploy path.
	if (_logik getVariable ["wfbe_mhqreloc_active", false]) exitWith {};
	_deployCost = _costs select 0;
	if (_supply >= _deployCost) then {
		//--- V0.6.5 owner report: HQ deployed ON a road (MHQ start spot). Nudge the deploy
		//--- position off-road/out-of-water. AICOM v2 (Ray 2026-07-01, road fix): the old code
		//--- used a FIXED 22-50m annulus and, on give-up, RESET to the raw on-road spot - so a
		//--- start location boxed in by roads kept planting the HQ ON the road. Replace with an
		//--- EXPANDING-RING off-road search (mirrors the ring idiom in Common_GetSafePlace.sqf:
		//--- sweep angles, then GROW the radius when a ring is exhausted) and KEEP the best
		//--- off-road candidate ever found - NEVER reset to the raw on-road spot. The radius
		//--- grows in WFBE_C_AICOM_HQ_NUDGE_STEP (default 25m) increments up to
		//--- WFBE_C_AICOM_HQ_NUDGE_MAX_R (default 200m). Pure scalar math + nearRoads/surfaceIsWater
		//--- (A2-OA-safe, same gate as the factory finder and the ServicePoint road-snap).
		_dPos = getPos _hq;
			//--- cmdcon41-w3k: the HQ deploy (the CC/HQ site itself) is a base-structure placement too, so honour the
			//--- SAME road-clear flag+buffer as _findBuildPos. _roadClearOK is compiled LATER in this script (after the
			//--- HQ block), so read the flag/buffer INLINE here with the identical nearRoads idiom. Flag off (=0) -> only
			//--- the water nudge remains (old road behaviour disabled); buffer default 14 == the prior hardcoded value.
			private ["_hqRoadClear","_hqRoadBuf"];
			_hqRoadClear = (missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROADCLEAR", 1]) > 0;
			_hqRoadBuf = missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_BUFFER", 14];
			if (_hqRoadBuf <= 0) then {_hqRoadClear = false};
			if ((_hqRoadClear && {count (_dPos nearRoads _hqRoadBuf) > 0}) || {surfaceIsWater _dPos}) then {
			private ["_hqRaw","_nudgeMaxR","_nudgeStep","_nudgeRad","_nudgeAng","_cand","_haveCand","_bestCand","_bestRoadD","_candRoadD","_candOK"];
			_hqRaw = getPos _hq;
			_nudgeMaxR = missionNamespace getVariable ["WFBE_C_AICOM_HQ_NUDGE_MAX_R", 200];
			_nudgeStep = missionNamespace getVariable ["WFBE_C_AICOM_HQ_NUDGE_STEP", 25];
			if (_nudgeStep <= 0) then {_nudgeStep = 25};
			_dTry = 0;
			_haveCand = false;      //--- a fully off-road+dry candidate found -> accept immediately.
			_bestCand = _hqRaw;     //--- best-so-far (farthest from any road, always dry) - the fallback.
			_bestRoadD = -1;        //--- distance to nearest road at _bestCand (higher = better); -1 = unset.
			//--- expanding ring: start just outside the road-reject radius, grow outward.
			_nudgeRad = 22;
			while {!_haveCand && {_nudgeRad <= _nudgeMaxR}} do {
				//--- sweep the ring in fixed angular steps (36 deg == the Common_GetSafePlace sweep),
				//--- with a small random phase so successive deploys do not all probe identical spots.
				_nudgeAng = random 360;
				for [{private "_k"; _k = 0}, {_k < 10 && {!_haveCand}}, {_k = _k + 1}] do {
					_cand = [(_hqRaw select 0) + _nudgeRad * sin _nudgeAng, (_hqRaw select 1) + _nudgeRad * cos _nudgeAng, 0];
					_dTry = _dTry + 1;
					if (!(surfaceIsWater _cand)) then {
						//--- distance to the nearest road (60 == none within 60m -> treat as fully clear).
						_candRoadD = 60;
						{ private "_rd"; _rd = (getPos _x) distance _cand; if (_rd < _candRoadD) then {_candRoadD = _rd} } forEach (_cand nearRoads 60);
						_candOK = ((!_hqRoadClear) || {count (_cand nearRoads _hqRoadBuf) == 0}); //--- cmdcon41-w3k: flag-gated + tunable buffer (was hardcoded 14).
						//--- track the best DRY candidate by road-clearance so give-up never returns on-road.
						if (_candRoadD > _bestRoadD) then {_bestRoadD = _candRoadD; _bestCand = _cand};
						if (_candOK) then {_haveCand = true; _bestCand = _cand};
					};
					_nudgeAng = _nudgeAng + 36;
				};
				_nudgeRad = _nudgeRad + _nudgeStep;
			};
			//--- NEVER reset to the raw on-road spot: take the fully-clear hit, else the best off-road
			//--- candidate seen (farthest from any road, guaranteed dry). Only if NOTHING dry was ever
			//--- found (all-water ring, degenerate map) does _bestCand remain the raw spot.
			_dPos = _bestCand;
			["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] HQ deploy spot nudged off-road to %2 (%3 tries, clear=%4, roadDist=%5, maxR=%6).", _sideText, _dPos, _dTry, _haveCand, round _bestRoadD, _nudgeMaxR]] Call WFBE_CO_FNC_AICOMLog;
		};
		if (_dual) then {[_side, -_deployCost, "AI commander HQ deployment.", false] Call ChangeSideSupply};
		[_classes select 0, _side, _dPos, getDir _hq, 0] ExecVM "Server\Construction\Construction_HQSite.sqf";
		["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] deploying HQ (cost %2 supply).", _sideText, _deployCost]] Call WFBE_CO_FNC_AICOMLog;
	};
};

//--- 2) HQ deployed: walk the doctrine build order; build the first missing structure.
_doctrine = _logik getVariable ["wfbe_aicom_doctrine", "LF"];
_hqPos = getPos ((_side) Call WFBE_CO_FNC_GetSideHQ);
//--- Marty 2026-06-13: _hqPos feeds _findBuildPos (ring placement) and, through it, the
//--- createVehicle/setPos path in ConstructDefense. A malformed HQ position (GetSideHQ
//--- briefly returning a non-object around HQ (re)deploy) makes the finder's surfaceIsWater
//--- / select throw and hands back garbage, which then throws again at createVehicle - the
//--- ~8x/round RPT spam. Fall back to the alive HQ object validated above; if that is somehow
//--- unusable too, skip this construction tick entirely (next tick retries).
if (typeName _hqPos != "ARRAY" || {count _hqPos < 2} || {typeName (_hqPos select 0) != "SCALAR"} || {typeName (_hqPos select 1) != "SCALAR"}) then {_hqPos = getPos _hq};
if (typeName _hqPos != "ARRAY" || {count _hqPos < 2} || {typeName (_hqPos select 0) != "SCALAR"} || {typeName (_hqPos select 1) != "SCALAR"}) exitWith {};

//--- V0.4: valid-position helper. Ring placement around the HQ, clearance-checked,
//--- never in water. _this = [rmin, rmax] or [rmin, rmax, _nearRoad].
//--- task #25 (road-aware): optional 3rd param _nearRoad biases the footprint vs roads.
//---   absent/0 = OFF-road: flat-empty dry ground, reject only on a USABLE (paved) road
//---              within 16m - dirt tracks no longer over-reject and shrink the ring.
//---   1        = NEAR a road (Light/Heavy/Aircraft factories): sit BESIDE a USABLE road
//---              on flat dry ground with a real perpendicular standoff (>=12m off the
//---              carriageway, not the old 5m node check that let footprints straddle the
//---              lane), so commander teams/trucks have a drivable egress apron. The road
//---              point is NOT pre-snapped with GetEmptyPosition (that drifted the candidate
//---              onto the flattest terrain = the track).
//--- In BOTH modes the FIRST fully-valid candidate is kept; on try-budget failure fall back
//--- to the best DRY-LAND candidate seen (never water). See _isUsableRoad below for the
//--- paved-vs-dirt classification (junction connectivity, build-safe across A2/OA).
//--- task #25b (road-type filter): A2 `nearRoads` returns EVERY segment - paved
//--- highways AND unpaved dirt/forest tracks (Chernarus is full of dirt tracks), so a
//--- bare `nearRoads` gate is "near a dirt path" = satisfied almost everywhere, and the
//--- factory lands ON a track. There is no surface-type field we can rely on across all
//--- three builds (Vanilla A2 / CombinedOps / Arrowhead), so we classify a road object as
//--- USABLE (drivable carriageway, not a dead-end track stub or field path) by its junction
//--- connectivity: a real road threads through (>=2 connected segments); dirt stubs and
//--- pedestrian paths typically dead-end. `roadsConnectedTo` is OA-only, so it is guarded
//--- with isNil-safe compile and degrades to "accept" on Vanilla A2 (where the old behaviour
//--- stands rather than throwing). _this = road object -> bool.
_isUsableRoad = {
	private ["_road","_ok","_conn"];
	_road = _this;
	if (isNull _road) exitWith {false};
	_ok = true;
	//--- roadsConnectedTo exists only on OA-class builds; never let it throw on Vanilla.
	if (!isNil {missionNamespace getVariable "WF_A2_Vanilla"} && {!WF_A2_Vanilla}) then {
		_conn = [];
		_conn = _road call {private "_c"; _c = []; if (!isNil {roadsConnectedTo _this}) then {_c = roadsConnectedTo _this}; _c};
		//--- a usable carriageway connects onward to >=2 other road segments; a lone dirt
		//--- stub / field-path end typically connects to <=1.
		if (count _conn < 2) then {_ok = false};
	};
	_ok
};

//--- task #25b: nearest USABLE road object within _radius of a position (or objNull).
//--- _this = [pos, radius] -> road object | objNull.
_nearUsableRoad = {
	private ["_pos","_rad","_rds","_best","_bestD","_d"];
	_pos = _this select 0; _rad = _this select 1;
	_rds = _pos nearRoads _rad;
	_best = objNull; _bestD = 1e9;
	{
		if (_x call _isUsableRoad) then {
			_d = (getPos _x) distance _pos;
			if (_d < _bestD) then {_bestD = _d; _best = _x};
		};
	} forEach _rds;
	_best
};

//--- BUILDING-CLEARANCE helper (bug fix, ACTIVE). Ray report: AI factories land hard against
//--- a house/wall, so factory output spawns INTO the geometry and breaks. _findBuildPos already
//--- rejects roads, water and crowded friendly structures, but NOT nearby WORLD buildings. This
//--- helper returns true when a candidate has clear ground (no House/wall within _radius). Uses
//--- nearestObjects with the "Building"/"House" kinds (A2-OA-safe; same idiom as the cond-c
//--- counter-battery scan above). The clearance radius is read inline-default so it ships with a
//--- sane value and Ray can tune it later without editing Init_CommonConstants. Guarded so it never
//--- blocks a build: callers keep a road-clear fallback that ignores this gate on try-budget failure.
_buildPosClear = {
	private ["_cpos","_clr","_blk"];
	_cpos = _this;
	_clr = missionNamespace getVariable ["WFBE_C_AICOM_BUILD_CLEARANCE", 14];
	if (_clr <= 0) exitWith {true};   //--- 0 disables the gate -> old behaviour.
	_blk = false;
	{ if (!isNull _x && {(_x distance _cpos) < _clr}) exitWith {_blk = true} } forEach (nearestObjects [_cpos, ["House","Building","Wall","Fence"], _clr + 4]);
	!_blk
};
//--- NO-OVERLAP FLOOR helper (Ray 2026-06-29, req #1). The soft STRUCT_SPACING (default 45m) is a
//--- PREFERENCE the primary _ok path enforces; but the try-budget fallback tiers (_bestBC/_best/_p)
//--- previously had NO spacing floor, so a failed search could hand back a spot ON TOP of an existing
//--- structure (overlapping footprints). This helper returns true only when _cand is >= the HARD floor
//--- (WFBE_C_AICOM_STRUCT_SPACING_FLOOR, default 30m == the "big hangars reach ~30m" footprint note)
//--- from EVERY existing friendly structure, so no fallback tier can ever overlap. Local _blk flag +
//--- exitWith INSIDE its own forEach (same idiom as _buildPosClear) so it cannot abort an outer loop.
_farFromStructs = {
	private ["_cpos","_floor","_blk"];
	_cpos = _this;
	_floor = missionNamespace getVariable ["WFBE_C_AICOM_STRUCT_SPACING_FLOOR", 30];
	if (_floor <= 0) exitWith {true};   //--- 0 disables the floor.
	_blk = false;
	{ if ((_cpos distance _x) < _floor) exitWith {_blk = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
	!_blk
};
//--- ROAD-CLEAR helper (cmdcon41-w3k, Ray backlog: AICOM builds base structures ON ROADS - observed live on
//--- Takistan, whose dense road net near the start locations kept planting factories/CC on the carriageway).
//--- Returns true when _cand is far enough from EVERY road segment (paved AND dirt) that a footprint cannot
//--- straddle the lane. Gate behind WFBE_C_AICOM_BUILD_ROADCLEAR (default 1 = ON); the reject radius is
//--- WFBE_C_AICOM_BUILD_ROAD_BUFFER (default 14 m). Idiom: `_pos nearRoads _buffer, count > 0 = reject`, the
//--- exact proven A2-OA pattern already live in the HQ-deploy block (L53), BuildRoadRoute and recovery v2
//--- (no isOnRoad/getRoadInfo - those are A3-only). This is the SAME kind of per-candidate gate as the
//--- STRUCT_SPACING check, wired into every accept path in _findBuildPos below so no fallback tier can
//--- reintroduce an on-road placement. _this = candidate pos -> bool.
_roadClearOK = {
	private ["_cpos","_rb"];
	_cpos = _this;
	if ((missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROADCLEAR", 1]) <= 0) exitWith {true}; //--- 0 disables the gate -> old behaviour.
	_rb = missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_BUFFER", 14];
	if (_rb <= 0) exitWith {true};
	(count (_cpos nearRoads _rb) == 0)
};
//--- SLOPE gate (TP-19, owner wish "don't build on slopes/trees"). Reject a candidate whose ground is too
//--- steep for a factory footprint (it floats/clips on a hillside). surfaceNormal z = 1.0 flat, lower = steeper;
//--- gate on WFBE_C_AICOM_BUILD_MIN_FLAT_Z (default 0 = OFF -> byte-identical). Same proven surfaceNormal idiom
//--- as WFBE_C_AICOM_RECOVERY_SLOPE_Z. Wired into the SAME accept chain as _buildPosClear so no primary/best-clear
//--- tier keeps a steep spot; the raw-DRY last-resort fallback is left ungated (finder must always return a spot).
_slopeOK = {
	private ["_cpos","_mz"];
	_cpos = _this;
	_mz = missionNamespace getVariable ["WFBE_C_AICOM_BUILD_MIN_FLAT_Z", 0];
	if (_mz <= 0) exitWith {true};   //--- 0 disables the gate -> old behaviour.
	((surfaceNormal _cpos) select 2) >= _mz
};
//--- TREE-CLEAR gate (TP-19). Reject a candidate with a map tree/small-tree within WFBE_C_AICOM_BUILD_TREE_CLEAR m
//--- (default 0 = OFF). Trees are TERRAIN objects (not caught by the _buildPosClear nearestObjects House/Wall scan),
//--- the A3 answer is nearestTerrainObjects, but that command does NOT exist on A2 OA 1.64 (parse error on any boot with TREE_CLEAR>0); nearestObjects is A2-safe (catches placed objects, not map vegetation). Same flag-gated per-
//--- candidate shape as _roadClearOK. On forest-dense maps the try budget + DRY fallback still guarantee a build.
_treeClearOK = {
	private ["_cpos","_tr"];
	_cpos = _this;
	_tr = missionNamespace getVariable ["WFBE_C_AICOM_BUILD_TREE_CLEAR", 0];
	if (_tr <= 0) exitWith {true};   //--- 0 disables the gate -> old behaviour.
	(count (nearestObjects [_cpos, ["Tree","SmallTree"], _tr])) == 0  //--- hotfix(live): nearestTerrainObjects is A3-only (RPT: Error Missing ) on every boot with TREE_CLEAR>0); swapped to nearestObjects (A2-safe). NOTE: A2 OA has no terrain-vegetation query so this gate is a documented no-op for map trees.
};
//--- ROAD-CLEAR gate (TP-19, owner report 2026-07-06: AI commander builds base structures on dirt roads).
//--- Reject a build candidate if a road segment (paved OR dirt) exists within WFBE_C_AICOM_BUILD_ROAD_CLEAR m.
//--- Gate idiom: `_pos nearRoads _radius, count > 0 = reject` - proven A2-OA-safe pattern, identical to the
//--- nearRoads usage already live in the HQ-deploy nudge block, BuildRoadRoute, and the primary _roadClearOK
//--- helper above (all use nearRoads; no isOnRoad/getRoadInfo - those are A3-only). This TP-19 gate
//--- mirrors the flag-gated per-candidate shape of _slopeOK and _treeClearOK: 0 = OFF (byte-identical to
//--- pre-PR behaviour), > 0 = reject radius in metres. Suggested live value: 6-8 m (covers the immediate
//--- carriageway footprint without over-rejecting near-road factory slots). Default 0 keeps the gate inert
//--- until a server operator tunes it. _this = candidate pos -> bool.
_tp19RoadClearOK = {
	private ["_cpos","_rc"];
	_cpos = _this;
	_rc = missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_CLEAR", 0];
	if (_rc <= 0) exitWith {true};   //--- 0 disables the gate -> old behaviour (byte-identical).
	(count (_cpos nearRoads _rc)) == 0
};
//--- NEAREST-FACTORY-DISTANCE helper (Ray 2026-06-29, req #2). Distance (m) from _cand to the closest
//--- existing SPAWN-POINT factory (Barracks/Light/Heavy/Aircraft - the player respawn structures per
//--- Client_GetRespawnAvailable). Used by the road-spaced mode (_nearRoad==2) to STRING factories ALONG
//--- a road one step apart instead of clustering at one HQ angle. Returns 1e9 when the side has none yet
//--- (so the first spawn-point factory is placed freely). Local-flag forEach idiom, no exitWith leak.
_nearestFactoryDist = {
	private ["_cpos","_best","_d"];
	_cpos = _this;
	_best = 1e9;
	{ if (((_x getVariable ["wfbe_structure_type", ""]) in ["Barracks","Light","Heavy","Aircraft"]) && {alive _x}) then {_d = _cpos distance _x; if (_d < _best) then {_best = _d}} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
	_best
};
_findBuildPos = {
	private ["_rmin","_rmax","_nearRoad","_p","_ok","_try","_ang","_best","_haveDry","_rd","_rp","_hd","_ox","_oy","_cand","_blocked","_sx","_sy","_tries","_bestClear","_haveClear","_bestBC","_haveBC","_isRoadMode","_stepBest","_haveStep","_stepTarget","_nf","_stepErr","_bestStepErr","_floor","_roadRejLogged"];  //--- cmdcon41-w3k: +_roadRejLogged (rate-limit the road-reject log to first per placement attempt).
	_roadRejLogged = false; //--- cmdcon41-w3k: one always-on INFORMATION line per rejected-for-road cluster (first reject only, not per nudge/try).
	_rmin = _this select 0; _rmax = _this select 1;
	_nearRoad = if (count _this > 2) then {_this select 2} else {0};
	//--- ROAD modes: 1 = beside a road (legacy near-road); 2 = beside a road AND spaced ALONG it
	//--- (Ray 2026-06-29 req #2, spawn-point factories). Both share the perpendicular-offset/off-lane
	//--- validation; mode 2 additionally PREFERS the all-gates-clear throw whose distance to the nearest
	//--- existing factory is closest to WFBE_C_AICOM_FACTORY_ROAD_STEP, so factory N+1 steps one slot
	//--- further along the road frontage instead of landing at a random ring angle next to factory N.
	_isRoadMode = (_nearRoad == 1) || (_nearRoad == 2);
	//--- the USABLE-road filter rejects more candidates than the old bare nearRoads gate, so give the
	//--- near-road modes a bigger try budget to find a paved lane to sit beside AND clear the FULL
	//--- spacing gate (Ray req #1: widen the search so an all-gates-clear spot is normally found, and
	//--- the no-overlap floor is only ever a last resort). Build-tick only (~1/5min/side) so cost is moot.
	_tries = if (_isRoadMode) then {(missionNamespace getVariable ["WFBE_C_AICOM_BUILDPOS_TRIES_ROAD", 64])} else {(missionNamespace getVariable ["WFBE_C_AICOM_BUILDPOS_TRIES_OFFROAD", 40])};
	_stepTarget = missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_ROAD_STEP", 50];
	_floor = missionNamespace getVariable ["WFBE_C_AICOM_STRUCT_SPACING_FLOOR", 30];
	_stepBest = [0,0,0]; _haveStep = false; _bestStepErr = 1e9;
	_ok = false; _try = 0; _haveDry = false; _haveClear = false; _haveBC = false; _best = [_hqPos, 35] Call WFBE_CO_FNC_GetEmptyPosition;
	_p = _best;
	while {!_ok && _try < _tries} do {
		_ang = random 360;
		_p = [(_hqPos select 0) + (_rmin + random (_rmax - _rmin)) * sin _ang, (_hqPos select 1) + (_rmin + random (_rmax - _rmin)) * cos _ang, 0];
		if (_isRoadMode) then {
			//--- NEAR-road (Barracks/Light/Heavy/Aircraft factories): BESIDE a USABLE road on flat,
			//--- dry ground with a real standoff, never on/over the lane. Do NOT pre-snap with
			//--- GetEmptyPosition here - roads are the flattest/emptiest terrain, so snapping
			//--- first drifts the candidate ONTO the track (the old order-of-operations bug).
			_rd = [_p, 36] Call _nearUsableRoad;
			if (!isNull _rd) then {
				//--- offset PERPENDICULAR to the road heading by a fixed standoff (>= a factory
				//--- footprint, not the old 5m node check) so the building sits off the
				//--- carriageway and the lane stays clear for egress.
				_rp = getPos _rd;
				_hd = ((_p select 0) - (_rp select 0)) atan2 ((_p select 1) - (_rp select 1)); //--- bearing road->candidate = the side we push out to
				_ox = (_rp select 0) + (missionNamespace getVariable ["WFBE_C_AICOM_ROAD_STANDOFF", 16]) * sin _hd;  //--- Build84: map-aware road standoff (TK 40 / CH 24; was hardcoded 16)
				_oy = (_rp select 1) + (missionNamespace getVariable ["WFBE_C_AICOM_ROAD_STANDOFF", 16]) * cos _hd;
				_cand = [_ox, _oy, 0];
				//--- settle onto flat-empty ground with a SMALL radius so it cannot drift back
				//--- onto the lane, then validate: dry, and a clear drivable strip between the
				//--- build pos and the carriageway (sample the midpoint - not water/road-snapped).
				_cand = [_cand, 8] Call WFBE_CO_FNC_GetEmptyPosition;
				if (!(surfaceIsWater _cand)) then {
					if (!_haveDry) then {_best = _cand; _haveDry = true};
					_blocked = false;
					_sx = (((_cand select 0) + (_rp select 0)) / 2);
					_sy = (((_cand select 1) + (_rp select 1)) / 2);
					if (surfaceIsWater [_sx, _sy, 0]) then {_blocked = true};
					//--- standoff must survive the empty-pos settle (>= 12m off the carriageway).
					if (((_cand distance _rp) < ((missionNamespace getVariable ["WFBE_C_AICOM_ROAD_STANDOFF", 16]) * 0.6))) then {_blocked = true};  //--- Build84: scale min-standoff with the tunable (was bare 12)
						//--- B752 (Ray 2026-06-25): also reject a candidate that SETTLED ONTO a road (paved OR DIRT).
						//--- The 16m offset is from the CHOSEN usable road (kept >12m off above), but GetEmptyPosition can
						//--- drift _cand onto an ADJACENT dirt track (flat+empty = preferred) = the "factory on a dirt road"
						//--- Ray reported. nearRoads 9 catches any carriageway node under the footprint; the chosen road is
						//--- >12m off so it is not caught; the 40-try near-road budget refinds a clean spot.
						if (!_blocked && {count (_cand nearRoads 9) > 0}) then {_blocked = true};
						//--- cmdcon41-w3k ROAD-BUFFER GATE: reject any candidate within WFBE_C_AICOM_BUILD_ROAD_BUFFER (14m)
						//--- of ANY road segment (paved OR dirt). Wired into the SAME _blocked chain as the STRUCT_SPACING
						//--- reject below so no accept path OR fallback tier (_bestBC/_bestClear/_p) can keep an on-road spot.
						//--- The near-road modes deliberately sit BESIDE a chosen road; the standoff (16m) normally clears
						//--- the 14m buffer, but GetEmptyPosition can drift the settle back toward an adjacent lane - this
						//--- gate is the backstop. Rate-limited log: first road reject per placement attempt only.
						if (!_blocked && {!(_cand call _roadClearOK)}) then {
							_blocked = true;
							if (!_roadRejLogged) then {
								_roadRejLogged = true;
								["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] BUILD_ROAD_REJECT near=%2 - candidate %3 within %4m of a road (WFBE_C_AICOM_BUILD_ROADCLEAR); searching off-road.", _sideText, _nearRoad, _cand, (missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_BUFFER", 14])]] Call WFBE_CO_FNC_AICOMLog;
							};
						};
					//--- MIDDLE FALLBACK TIER (_bestBC): candidate passed water/standoff/on-road AND is
					//--- BUILDING-CLEAR (_buildPosClear) but may be spacing-crowded. Recorded BEFORE the
					//--- STRUCT_SPACING gate so the try-budget fallback prefers a building+road-clear (off-lane,
					//--- not-in-geometry) spot over raw 'dry' _best (which GetEmptyPosition drifts onto roads).
					//--- Ray 2026-06-29 req #1: ALSO gate on the HARD no-overlap floor (_farFromStructs) so the
						//--- relaxed fallback may use the cushion between FLOOR (30m) and SPACING (45m) but can NEVER
						//--- return a spot that overlaps an existing structure. Only the 30..45m band is ever relaxed.
						if (!_blocked && {!_haveBC} && {_cand call _buildPosClear} && {_cand call _farFromStructs}) then {_bestBC = _cand; _haveBC = true};
					//--- B67: reject a candidate that crowds an existing friendly structure
					//--- (< WFBE_C_AICOM_STRUCT_SPACING). GetSideStructures fresh - _findBuildPos
					//--- runs before the outer _structures local is assigned (line ~314).
					if (!_blocked) then {
						{ if ((_cand distance _x) < (missionNamespace getVariable ["WFBE_C_AICOM_STRUCT_SPACING", 45])) exitWith {_blocked = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
					};
					//--- FIX6 (Ray): record the ROAD-CLEAR fallback only once the candidate is BOTH road-clear AND spacing-OK
					//--- (moved BELOW the STRUCT_SPACING check). Otherwise the try-budget fallback could hand back a
					//--- road-clear-but-CROWDED spot (<45m from another structure -> overlapping footprints).
					//--- CLEARANCE FIX (bug fix, ACTIVE): reject a candidate hard against a world building/wall so the
					//--- factory spawn pads do not sit inside geometry (units spawning into a house/wall break).
					if (!_blocked && {!(_cand call _buildPosClear)}) then {_blocked = true};
					if (!_blocked && {!(_cand call _slopeOK)}) then {_blocked = true};           //--- TP-19 slope gate (flag-off = no-op)
					if (!_blocked && {!(_cand call _treeClearOK)}) then {_blocked = true};       //--- TP-19 tree gate (flag-off = no-op)
					if (!_blocked && {!(_cand call _tp19RoadClearOK)}) then {_blocked = true};  //--- TP-19 road-clear gate (flag-off = no-op)
					if (!_blocked && {!_haveClear}) then {_bestClear = _cand; _haveClear = true};
					//--- Ray 2026-06-29 req #2 (SPACED-along-road, mode 2): a fully-clear candidate is a valid
					//--- step. Instead of accepting the FIRST one (which clusters factory N+1 right next to factory
					//--- N at a random ring angle), keep the one whose distance to the nearest existing factory is
					//--- closest to WFBE_C_AICOM_FACTORY_ROAD_STEP, so consecutive spawn points step evenly ALONG
					//--- the road frontage. Spend the whole try budget hunting the best step; the first spawn-point
					//--- factory (no factories yet -> _nf=1e9) takes the first hit immediately.
					if (!_blocked && {_nearRoad == 2}) then {
						_nf = _cand call _nearestFactoryDist;
						if (_nf >= 1e8) then {
							_p = _cand; _ok = true;   //--- first spawn point on this side: nothing to space from.
						} else {
							_stepErr = abs (_nf - _stepTarget);
							if (!_haveStep || {_stepErr < _bestStepErr}) then {_stepBest = _cand; _bestStepErr = _stepErr; _haveStep = true};
						};
					};
					//--- mode 1 (legacy near-road) keeps the FIRST all-gates-clear hit.
					if (!_blocked && {_nearRoad != 2}) then {_p = _cand; _ok = true};
				};
			};
		} else {
			//--- OFF-road (CC/Barracks/Bank/CBR): flat-empty dry ground clear of ANY road
			//--- (paved AND dirt). task #25b regressed by switching to a USABLE-only 16m gate:
			//--- Chernarus dirt tracks are continuous multi-segment roads (roadsConnectedTo>=2),
			//--- so _nearUsableRoad did NOT exclude them, and GetEmptyPosition (line 171) drifts
			//--- the candidate onto the flat dirt carriageway before the gate runs. Reject on a
			//--- bare nearRoads hit at 22m (vs old 16m) so dirt-track nodes ~10-25m apart cannot
			//--- be skipped by a footprint straddling the lane between two nodes. roadsConnectedTo
			//--- is NOT consulted here on purpose - paved or dirt, we want it clear. The same
			//--- count(_p nearRoads N) idiom is already live in the HQ-deploy block, so the gate
			//--- is a proven A2-OA pattern (no isOnRoad/getRoadInfo - those are A3-only).
			_p = [_p, 30] Call WFBE_CO_FNC_GetEmptyPosition;
			if (!(surfaceIsWater _p)) then {
				if (!_haveDry) then {_best = _p; _haveDry = true};
				//--- cmdcon41-w3k ROAD-BUFFER GATE (off-road path): the existing nearRoads 22 gate below already
				//--- rejects any road within 22m (>= the 14m default buffer), so this is normally satisfied; it is
				//--- kept explicit so the flag WFBE_C_AICOM_BUILD_ROADCLEAR is the single authoritative road gate and
				//--- a tuned WFBE_C_AICOM_BUILD_ROAD_BUFFER > 22 is honoured here too. Rate-limited log (first only).
				if (!(_p call _roadClearOK) && {!_roadRejLogged}) then {
					_roadRejLogged = true;
					["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] BUILD_ROAD_REJECT near=%2 - candidate %3 within %4m of a road (WFBE_C_AICOM_BUILD_ROADCLEAR); searching off-road.", _sideText, _nearRoad, _p, (missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_BUFFER", 14])]] Call WFBE_CO_FNC_AICOMLog;
				};
				if ((count (_p nearRoads 22) == 0) && {_p call _roadClearOK}) then {
					//--- MIDDLE FALLBACK TIER (_bestBC): road-clear here; record if ALSO building-clear,
					//--- relaxing the soft STRUCT_SPACING. Preferred over raw 'dry' _best in the fallback chain.
					//--- Ray 2026-06-29 req #1: ALSO gate on the HARD no-overlap floor (_farFromStructs) so the
					//--- relaxed fallback can never return a spot that overlaps an existing structure.
					if (!_haveBC && {_p call _buildPosClear} && {_p call _farFromStructs}) then {_bestBC = _p; _haveBC = true};
					//--- B67: reject a candidate that crowds an existing friendly structure
					//--- (< WFBE_C_AICOM_STRUCT_SPACING). GetSideStructures fresh - _findBuildPos
					//--- runs before the outer _structures local is assigned (line ~314).
					_ok = true;
					{ if ((_p distance _x) < (missionNamespace getVariable ["WFBE_C_AICOM_STRUCT_SPACING", 45])) exitWith {_ok = false} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
					//--- CLEARANCE FIX (bug fix, ACTIVE): reject a candidate hard against a world building/wall so the
					//--- factory spawn pads do not sit inside geometry (units spawning into a house/wall break).
					if (_ok && {!(_p call _buildPosClear)}) then {_ok = false};
					if (_ok && {!(_p call _slopeOK)}) then {_ok = false};           //--- TP-19 slope gate (flag-off = no-op)
					if (_ok && {!(_p call _treeClearOK)}) then {_ok = false};       //--- TP-19 tree gate (flag-off = no-op)
					if (_ok && {!(_p call _tp19RoadClearOK)}) then {_ok = false};  //--- TP-19 road-clear gate (flag-off = no-op)
					//--- FIX6 (Ray): record the ROAD-CLEAR fallback only once the candidate is BOTH road-clear AND
					//--- spacing-OK (_ok survives the STRUCT_SPACING forEach above) - prevents a crowded fallback.
					if (_ok && {!_haveClear}) then {_bestClear = _p; _haveClear = true};
				};
			};
		};
		_try = _try + 1;
	};
	//--- Ray 2026-06-29 req #2: in SPACED mode (2), if no candidate was accepted immediately (i.e. this is
	//--- NOT the first factory) but the budget found at least one fully-clear step, take the best-spaced one
	//--- now. _stepBest is all-gates-clear (building+road+FULL spacing), so it is a clean accept.
	if (!_ok && {_nearRoad == 2} && {_haveStep}) then {_p = _stepBest; _ok = true};
	private "_via";
	//--- try-budget failure: hand back the best dry-land candidate (never water).
	if (!_ok) then {_p = if (_haveClear) then {_bestClear} else {if (_haveBC) then {_bestBC} else {if (_haveDry) then {_best} else {_p}}}}; //--- AICOM v2 (Ray): prefer the best ROAD-CLEAR fallback over an on-road _best, so structures stop landing on roads in road-dense base spots.
	_via = "raw"; if (_haveDry) then {_via = "DRY"}; if (_haveBC) then {_via = "bestBC"}; if (_haveClear) then {_via = "bestClear"}; if (_haveStep) then {_via = "bestStep"}; if (_ok) then {_via = if (_nearRoad == 2) then {"okStep"} else {"ok"}};
	//--- AICOM v2 (Ray 2026-07-01, road fix): the fallback chain above prefers the road-CLEAR tiers
	//--- (_bestClear/_bestBC) but can still resolve _p onto the raw DRY _best - which is recorded
	//--- BEFORE the road gate and may sit ON a road (paved OR dirt). REJECT an on-road fallback _p:
	//--- rather than returning it, STEP it off-road radially OUTWARD along the HQ->_p bearing in 8m
	//--- increments (up to +150m) until nearRoads is clear and the spot is dry. Same nudge idiom as
	//--- the no-overlap hard guard below (which then still runs on the stepped-off spot, so spacing
	//--- is preserved). Pure scalar math + nearRoads/surfaceIsWater = A2-OA-safe; only fires when the
	//--- try-budget genuinely failed AND the chosen fallback landed on a road (rare, road-dense base).
	//--- cmdcon41-w3k: gate the terminal step-out on the SAME flag+buffer as the per-candidate reject, so
	//--- WFBE_C_AICOM_BUILD_ROADCLEAR=0 disables the whole road behaviour and WFBE_C_AICOM_BUILD_ROAD_BUFFER
	//--- tunes the reject/clear radius consistently. The step-out clear test also uses the tunable buffer.
	if (!(_p call _roadClearOK)) then {
		private ["_rbx","_rby","_rbh","_rstep","_rnx","_rny","_rnpos","_rdone","_rbuf"];
		_rbuf = missionNamespace getVariable ["WFBE_C_AICOM_BUILD_ROAD_BUFFER", 14];
		//--- cmdcon41-w3k: rate-limited road-reject log (fires here iff the per-candidate gates above never
		//--- logged for this attempt, e.g. a purely-DRY fallback _best recorded before any road test).
		if (!_roadRejLogged) then {
			_roadRejLogged = true;
			["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] BUILD_ROAD_REJECT near=%2 - fallback %3 within %4m of a road (WFBE_C_AICOM_BUILD_ROADCLEAR); stepping off-road.", _sideText, _nearRoad, _p, _rbuf]] Call WFBE_CO_FNC_AICOMLog;
		};
		_rbx = (_p select 0) - (_hqPos select 0); _rby = (_p select 1) - (_hqPos select 1);
		_rbh = if (_rbx == 0 && {_rby == 0}) then {random 360} else {_rbx atan2 _rby}; //--- HQ->_p bearing (random if _p == HQ).
		_rdone = false; _rstep = 8;
		while {!_rdone && {_rstep <= 150}} do {
			_rnx = (_p select 0) + _rstep * sin _rbh;
			_rny = (_p select 1) + _rstep * cos _rbh;
			_rnpos = [_rnx, _rny, 0];
			if (!(surfaceIsWater _rnpos) && {_rnpos call _roadClearOK}) then {_p = _rnpos; _rdone = true; _via = _via + "+offroad"};
			_rstep = _rstep + 8;
		};
		//--- cmdcon41-w3k LAST RESORT: could not step clear of roads within +150m (base boxed in by roads, dense
		//--- Takistan net). Allow the placement here rather than deadlocking the whole base, but emit an always-on
		//--- INFORMATION line so BUILD_ROAD_LASTRESORT is visible in the RPT and we can tune/relocate.
		if (!_rdone) then {
			_via = _via + "+ONROAD!"; //--- could not step clear of roads within +150m; RPT-flagged.
			["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] BUILD_ROAD_LASTRESORT near=%2 - could not clear roads within +150m of %3; placing anyway (road-dense base spot).", _sideText, _nearRoad, _p]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	//--- Ray 2026-06-29 req #1 FINAL HARD GUARD: the raw _best/_p fallback tiers have NO spacing floor, so a
	//--- fully-failed search could still resolve _p ON TOP of an existing structure (overlap). Enforce the
	//--- no-overlap floor unconditionally: if _p still violates the floor, NUDGE it radially OUTWARD along the
	//--- HQ->_p bearing in 8m steps (up to +150m) until it clears every structure. Pure scalar math + distance
	//--- loop = A2-OA-safe; runs only when the fallback actually produced an overlapping spot (rare).
	if (!(_p call _farFromStructs) && {_floor > 0}) then {
		private ["_bx","_by","_bh","_step","_nx","_ny","_npos","_done"];
		_bx = (_p select 0) - (_hqPos select 0); _by = (_p select 1) - (_hqPos select 1);
		_bh = if (_bx == 0 && {_by == 0}) then {random 360} else {_bx atan2 _by}; //--- HQ->_p bearing (random if _p == HQ).
		_done = false; _step = 8;
		while {!_done && {_step <= 150}} do {
			_nx = (_p select 0) + _step * sin _bh;
			_ny = (_p select 1) + _step * cos _bh;
			_npos = [_nx, _ny, 0];
			if (!(surfaceIsWater _npos) && {_npos call _farFromStructs}) then {_p = _npos; _done = true; _via = _via + "+nudge"};
			_step = _step + 8;
		};
		if (!_done) then {_via = _via + "+OVERLAP!"}; //--- could not clear the floor in a crowded base; RPT-flagged.
	};
	diag_log (format ["AICOMPLACE|near=%1|via=%2|pos=%3|onRoad=%4|clr=%5|nf=%6|floorOK=%7", _nearRoad, _via, _p, (count (_p nearRoads 12) > 0), (_p call _buildPosClear), (round (_p call _nearestFactoryDist)), (_p call _farFromStructs)]);
	_p
};

//--- V0.4: strategy-shaped construction. At start ONLY the core: CC -> Barracks ->
//--- doctrine factory (keeps supply free for the research program). The rest of the
//--- base is built once the research core (Gear 3 + Barracks 2) is reached = branch out.
_upgrades = _logik getVariable "wfbe_upgrades";
_coreDone = false;
if (!isNil "_upgrades") then {
	_coreDone = ((_upgrades select WFBE_UP_GEAR) >= 3) && {(_upgrades select WFBE_UP_BARRACKS) >= 2};
};
_order = if (_doctrine == "HF") then {["CommandCenter","Barracks","Heavy"]} else {["CommandCenter","Barracks","Light"]};
if (_coreDone) then {
	_order = _order + (if (_doctrine == "HF") then {["Light","ServicePoint"]} else {["Heavy","ServicePoint"]});
	//--- AIRCRAFT GATE: the AI flies poorly, so the air factory is deferred until the side
	//--- is well established (holds >= WFBE_C_AICOM_AIR_MIN_TOWNS towns). Until then it never
	//--- enters the build order, so no air upgrades/units/teams can follow from it.
	_myID = (_side) Call WFBE_CO_FNC_GetSideID;
	_ownTowns = 0;
	{ if ((_x getVariable "sideID") == _myID) then {_ownTowns = _ownTowns + 1} } forEach towns;
	if (_ownTowns >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 4])) then {
		_order = _order + ["Aircraft"];
	};
};

//--- V0.6 task 49b: experital-awareness build extension (nil-guarded, no-op on this mission).
//--- CBRadar and Bank only enter _order when the side's STRUCTURES array lists them.
//--- The EXACT type-name strings come from Structures_CO_RU/W.sqf in the experital branch:
//---   CBR  -> "CBRadar"   (WFBE_C_STRUCTURES_COUNTERBATTERY guard in experital)
//---   Bank -> "Bank"      (WFBE_C_ECONOMY_BANK guard in experital)
//---
//--- CBR REACTIVE gate (AI scaffold only — human commanders are unaffected):
//--- CBRadar only enters the build order when an artillery THREAT is confirmed.
//--- Threat state is armed by Server_CounterBattery.sqf (fired-EH blip path, condition b),
//--- RequestOnUnitKilled.sqf (killed-by-arty check, condition a), and the enemy-arty-exists
//--- scan below (condition c).  All three write wfbe_aicom_arty_threat = true on the
//--- side logic.  Additional gates: round time > 45 min AND supply >= CBR cost + reserve.
_scaffoldActivated = false;
_cbrIdx = _names find "CBRadar";
if (_cbrIdx >= 0) then {
	//--- Read or compute the threat flag.
	_artyThreat = _logik getVariable ["wfbe_aicom_arty_threat", false];

	//--- Condition (c): enemy has built an artillery piece AND round > 60 min.
	//--- Cheap scan: WFBE_CommanderArtillery is set globally (true,true) on construction.
	//--- Only evaluate if threat not yet confirmed (skip scan when already armed).
	if (!_artyThreat && {time > 3600}) then {
		_enemySide = if (_side == west) then {east} else {west};
		_enemySideText = str _enemySide;
		//--- N-FEATUREBUG-48 fix 2026-06-27: the counter-battery scan must look at the ENEMY base, not our own.
		//--- Anchoring nearestObjects at OUR HQ (10km) only ever scanned our own structures and never reached
		//--- the enemy arty 12.8-15km away, so cond-c could never arm. Anchor the scan at the ENEMY HQ instead.
		private ["_eHQ","_scanPos"];
		_eHQ = _enemySide Call WFBE_CO_FNC_GetSideHQ;
		if (!isNull _eHQ) then {
			_scanPos = getPos _eHQ;
			_artyScanRadius = 10000;
			if ((missionNamespace getVariable ["WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE", 0]) > 0) then {
				_artyScanRadius = missionNamespace getVariable ["WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS", 10000];
				if (_artyScanRadius < 0) then {_artyScanRadius = 0};
			};
			{
				if (!_artyThreat) then {
					if ((_x getVariable ["WFBE_CommanderArtillery", false]) &&
					    {(_x getVariable ["WFBE_CommanderArtillerySide", ""]) == _enemySideText} &&
					    {alive _x}) then {
						_artyThreat = true;
						_logik setVariable ["wfbe_aicom_arty_threat", true];
						["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] wfbe_aicom_arty_threat ARMED (cond-c: enemy arty piece exists at %2 min).", _sideText, round (time / 60)]] Call WFBE_CO_FNC_AICOMLog;
						diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|ARTY_THREAT_ARMED|cond-c");
					};
				};
			} forEach (nearestObjects [_scanPos, ["StaticWeapon","Tank","Car"], _artyScanRadius]);
		};
	};

	//--- CBR enters the build order only when: threat confirmed + round > min time + supply OK.
	//--- V0.6.7 P5: both threat AND time gate are required; use tunable min-time and supply reserve.
	//--- Default min time: 2700 s (45 min). Override via WFBE_C_AICOM_CBR_MIN_TIME in missionNamespace.
	_cbrMinTime = missionNamespace getVariable ["WFBE_C_AICOM_CBR_MIN_TIME", 2700];
	_cbrReserve = missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_RESERVE", 500];
	if (_artyThreat && {time >= _cbrMinTime}) then {
		_cbrCost = _costs select _cbrIdx;
		if (_supply >= _cbrCost + _cbrReserve) then {
			_order = _order + ["CBRadar"];
			_scaffoldActivated = true;
		};
	};
};
//--- ECON/ARTY GATE (owner 2026-06-14): AI commander defers Bank + ArtilleryRadar until it holds MORE than N towns. AI-commander build logic ONLY — human players are unaffected.
_econGateTowns = missionNamespace getVariable ["WFBE_C_AICOM_ECON_GATE_TOWNS", 6];
_econMyID = (_side) Call WFBE_CO_FNC_GetSideID;
_econOpen = ({(_x getVariable "sideID") == _econMyID} count towns) > _econGateTowns;
_bankIdx = _names find "Bank";
if (_bankIdx >= 0) then {
	//--- Supply gate: only attempt Bank when supply > 1.5x its construction cost.
	_bankCost = _costs select _bankIdx;
	if (_econOpen && {_supply > _bankCost * 1.5}) then {
		_order = _order + ["Bank"];
		_scaffoldActivated = true;
	};
};
//--- RESERVE (owner request): humans can build it; let the AI build it too. Same plain
//--- supply-multiple gate as Bank. `_names find "Reserve" == -1` (guard WFBE_C_STRUCTURES_RESERVE
//--- off) is the natural no-op; the L274 builder loop then dedups/pays from _costs.
_resIdx = _names find "Reserve";
if (_resIdx >= 0) then {
	_resCost = _costs select _resIdx;
	if (_econOpen && {_supply > _resCost * 1.5}) then {
		_order = _order + ["Reserve"];
		_scaffoldActivated = true;
	};
};
//--- ARTILLERYRADAR: humans can always build it; the AI now defers it until the ENEMY actually
//--- fields/fires artillery, re-using the SAME wfbe_aicom_arty_threat flag the CBRadar block above
//--- armed (cond-a killed-by-arty, cond-b >=3 fire missions, cond-c enemy-arty-piece scan). The flag
//--- is never auto-cleared, so once the enemy fields arty this gate opens on the next tick (it CAN
//--- build later). Default-ON; set WFBE_C_AICOM_ARTRAD_REQUIRE_ENEMY_ARTY = 0 for the old always-build.
_artradIdx = _names find "ArtilleryRadar";
if (_artradIdx >= 0) then {
	_artradCost = _costs select _artradIdx;
	_artradReqArty = (missionNamespace getVariable ["WFBE_C_AICOM_ARTRAD_REQUIRE_ENEMY_ARTY", 1]) > 0;
	_artyThreat = _logik getVariable ["wfbe_aicom_arty_threat", false];
	if (_econOpen && {_supply > _artradCost * 1.5} && {(!_artradReqArty) || _artyThreat}) then {
		_order = _order + ["ArtilleryRadar"];
		_scaffoldActivated = true;
	};
};
if (_scaffoldActivated) then {
	_artyThreat = _logik getVariable ["wfbe_aicom_arty_threat", false];
	//--- B74.1 (2026-06-23) DE-SPAM: _scaffoldActivated is true whenever a structure is merely IN _order, even one
	//--- that already exists (the actual build is dedup-gated downstream), so on a high-supply side this logged
	//--- ~1/min for hours (935x in the b74 soak) with zero real builds, masking real signal. Only emit when the
	//--- scaffold set CHANGES vs the last logged state. A2-OA-safe (str/in/getVariable on the side-logic object).
	private ["_scaffoldSig","_scaffoldPrev"];
	_scaffoldSig = str [("CBRadar" in _order), ("Bank" in _order), ("Reserve" in _order), ("ArtilleryRadar" in _order), _artyThreat];
	_scaffoldPrev = _logik getVariable ["wfbe_aicom_scaffold_sig", ""];
	if (_scaffoldSig != _scaffoldPrev) then {
		_logik setVariable ["wfbe_aicom_scaffold_sig", _scaffoldSig];
		["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] experital build scaffold ACTIVE (CBR-in-order=%2 threat=%3 Bank=%4).", _sideText, ("CBRadar" in _order), _artyThreat, ("Bank" in _order)]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|SCAFFOLD_BUILD|CBR=" + str ("CBRadar" in _order) + " threat=" + str _artyThreat + " Bank=" + str ("Bank" in _order));
	};
};

_structures = (_side) Call WFBE_CO_FNC_GetSideStructures;

{
	_idx = _names find _x;
	if (_idx >= 0) then {
		_class = _classes select _idx;
		//--- BUILD-LIMIT + BASE CAP (Ray 2026-06-24, directives #1 + #4): obey the SAME per-type structure caps as
		//--- human players. _x here is the TYPE KEY (the order list + _names = WFBE_%1STRUCTURES are type keys, not
		//--- model names), and wfbe_structure_type on each built site == that same type key (set as _rlType in
		//--- Construction_*Site.sqf). Read the player cap WFBE_C_STRUCTURES_MAX_<type> (case-insensitive getVariable,
		//--- same idiom as coin_interface.sqf:917); CommandCenter is additionally clamped to the AICOM base cap.
		//--- FLAW-FIX: exitWith inside forEach exits the ENTIRE loop (CommandCenter is the first order item, so a
		//--- capped CC would starve the whole base of all other production). Instead compute _capped and wrap the
		//--- REST of the iteration body in if(!_capped) so ONLY the current type is skipped; the loop continues.
		//--- Micro-opt: reuse the already-computed _structures local (line 336) for the type-count, no extra call.
		//--- De-spammed via per-type quota signature on _logik (mirrors scaffold-sig de-spam, lines 326-333).
		//--- Both gates run BEFORE any supply is paid below, so a capped build never spends.
		private ["_otype","_typeLimit","_typeHave","_basesMax","_capped"];
		_capped = false;
		if ((missionNamespace getVariable ["WFBE_C_AICOM_OBEY_BUILD_LIMITS", 1]) > 0) then {
			_otype = _x;
			_typeLimit = missionNamespace getVariable [Format ["WFBE_C_STRUCTURES_MAX_%1", _otype], 3];
			if (typeName _typeLimit != "SCALAR") then {_typeLimit = 3};
			//--- directive #1: a 'base' is a CommandCenter; clamp the per-type limit to the base cap.
			if (_otype == "CommandCenter") then {
				_basesMax = missionNamespace getVariable ["WFBE_C_AICOM_BASES_MAX", 2];
				if (_basesMax > 0 && {_basesMax < _typeLimit}) then {_typeLimit = _basesMax};
			};
			//--- count LIVE structures of this type; use the already-computed _structures local (micro-opt).
			_typeHave = {((_x getVariable ["wfbe_structure_type", ""]) == _otype) && {alive _x}} count _structures;
			if (_typeHave >= _typeLimit) then {
				_capped = true;
				//--- de-spam: only log when the quota-full state for this type CHANGES on the side logic.
				private ["_qSig","_qPrev"];
				_qSig = _otype + "=" + str _typeHave + "/" + str _typeLimit;
				_qPrev = _logik getVariable [Format ["wfbe_aicom_quota_%1", _otype], ""];
				if (_qSig != _qPrev) then {
					_logik setVariable [Format ["wfbe_aicom_quota_%1", _otype], _qSig];
					["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] build of %2 SKIPPED - cap reached (%3/%4).", _sideText, _otype, _typeHave, _typeLimit]] Call WFBE_CO_FNC_AICOMLog;
					diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|BUILD_CAP_SKIP|type=" + _otype + "|have=" + str _typeHave + "|max=" + str _typeLimit);
				};
			};
		};
		if (!_capped) then {
		//--- Already have an ALIVE one of this type? V0.4.2: construction is ASYNC, so a
		//--- site paid for last tick is not alive yet - the pending timestamp guards the
		//--- 5-min build window so we never pay for the same structure twice.
		_have = false;
		//--- B74 REBASE (Ray 2026-06-22): when REBASE_ON, only count a structure as 'already have' if it sits within
		//--- BASE_RADIUS of the CURRENT HQ - so after an MHQ relocation the old base's far factories no longer block a
		//--- rebuild and the new forward base re-establishes its own production (supply-gated). Structures build in the
		//--- 60-110m HQ ring (well inside BASE_RADIUS), so normal non-relocated play is unchanged (HQ-local == side-wide).
		private ["_rebaseLocal","_baseR"];
		_rebaseLocal = (missionNamespace getVariable ["WFBE_C_AICOM_REBASE_ON", 1]) > 0;
		_baseR = missionNamespace getVariable ["WFBE_C_AICOM_BASE_RADIUS", 450];
		{ if (typeOf _x == _class && {alive _x} && {(!_rebaseLocal) || {((getPos _x) distance _hqPos) <= _baseR}}) exitWith {_have = true} } forEach _structures;
		if (!_have) then {
			if (time - (_logik getVariable [Format ["wfbe_aicom_built_%1", _x], -1e6]) < 300) then {_have = true};
		};
		if (!_have) exitWith {
			_cost = _costs select _idx;
			if (_supply >= _cost) then {
				//--- ServicePoint wants to sit ON a road (repair/refuel access); fall back to ring.
				_pos = [0,0,0];
				_placed = false;
				if (_x == "ServicePoint") then {
					//--- AICOM v2 (Ray 2026-06-27): place the Service Point BESIDE a road (near-road mode: offset off
					//--- the carriageway + road-rejected), NOT ON a road node. The old code set _pos = getPos roadNode,
					//--- so the SP sat ON the road (Ray report). Vehicles still reach it; it no longer blocks the lane.
					_pos = [(missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MIN", 60]), (missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MAX", 110]), 1] Call _findBuildPos;
					if (!(surfaceIsWater _pos)) then {_placed = true};
				};
				//--- task #25 + Ray 2026-06-29 req #2: the SPAWN-POINT factories (Barracks/Light/Heavy/Aircraft -
				//--- the player respawn structures per Client_GetRespawnAvailable) are placed road-ADJACENT and
				//--- SPACED ALONG the road (mode 2) so respawning players come out near a road and the four spawn
				//--- points don't stack at one HQ angle. Everything else (CC/Bank/CBR) keeps OFF-road placement.
				//--- Barracks was previously OFF-road; it is now road-spaced too (it IS a respawn point).
				if (!_placed) then {
					if (_x in ["Barracks","Light","Heavy","Aircraft"]) then {
						//--- B67 + req #2: widen the outer ring as the side accumulates spawn-point factories so each
						//--- successive one has fresh road frontage to step onto (the FULL 45m spacing gate clears
						//--- far more often -> the no-overlap floor stays a rare last resort). +35m per existing
						//--- spawn-point factory, capped at +120m over the base outer ring.
						private ["_fc","_rmaxF"];
						_fc = {((_x getVariable ["wfbe_structure_type", ""]) in ["Barracks","Light","Heavy","Aircraft"]) && {alive _x}} count _structures;
						_rmaxF = (missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MAX", 110]) + ((_fc * 35) min 120);
						_pos = [(missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MIN", 60]), _rmaxF, 2] Call _findBuildPos;
					} else {
						_pos = [(missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MIN", 60]), (missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MAX", 110])] Call _findBuildPos;
					};
				};
				if (_dual) then {[_side, -_cost, Format ["AI commander base construction (%1).", _x], false] Call ChangeSideSupply};
				_logik setVariable [Format ["wfbe_aicom_built_%1", _x], time];
				_script = _scripts select _idx;
				//--- AICOM v2 (Ray, deliberate layout): face structures toward the FRONT (HQ->spearhead bearing) so
				//--- spawn pads / doors point at the egress instead of a random spin. Falls back to random if no front.
				private ["_facDir","_facTgt","_facP"];
				_facTgt = (_logik getVariable ["wfbe_aicom_targets", []]);
				_facDir = if (count _facTgt > 0 && {!isNull (_facTgt select 0)}) then {_facP = getPos (_facTgt select 0); ((_facP select 0) - (_hqPos select 0)) atan2 ((_facP select 1) - (_hqPos select 1))} else {random 360};
				[_class, _side, _pos, _facDir, _idx] ExecVM (Format ["Server\Construction\Construction_%1.sqf", _script]);
				//--- FACTORY RALLY (task #25 / bug a). Warfare has no rally MARKER: "rally" = the
				//--- destination spawned units inherit. Players set it (shift-click); the AI never
				//--- did, so AI factory output (troop trucks, combat teams) spawned at the in-base
				//--- factory with NO destination and sat forever. Here the commander SETS a
				//--- strategic rally for each production factory it builds: a forward point toward
				//--- the side's primary spearhead (wfbe_aicom_targets[0], published by
				//--- AI_Commander_Strategy.sqf), snapped onto a USABLE road so the egress lane is
				//--- one A2 PFM can actually drive. The construction is async, so we cannot stamp
				//--- the not-yet-alive factory object now; a short watcher waits for the built
				//--- _site to register at _pos, then writes wfbe_aicom_factory_rally onto it for
				//--- the server buy path (Server_BuyUnit) to commandMove new units toward.
				if (_x in ["Light","Heavy","Aircraft"]) then {
					_factoryRally = [_side, _logik, _pos] Spawn {
						private ["_side","_logik","_pos","_targets","_target","_tgtPos","_rally","_dx","_dy","_dist","_egX","_egY","_egN","_site","_wait"];
						_side = _this select 0; _logik = _this select 1; _pos = _this select 2;
						//--- 1) resolve the strategic target = primary spearhead town the
						//--- commander already publishes (top of wfbe_aicom_targets), with a graceful
						//--- fallback to the nearest enemy/neutral town, then the enemy HQ.
						_targets = _logik getVariable ["wfbe_aicom_targets", []];
						_target = objNull;
						if (typeName _targets == "ARRAY" && {count _targets > 0}) then {_target = _targets select 0};
						_tgtPos = if (!isNull _target) then {getPos _target} else {[]};
						if (count _tgtPos < 2) then {
							//--- fallback: nearest town not ours; else the enemy HQ position.
							private ["_myID","_bestT","_bestD","_d"];
							_myID = (_side) Call WFBE_CO_FNC_GetSideID;
							_bestT = objNull; _bestD = 1e9;
							{ if ((_x getVariable ["sideID", -1]) != _myID) then {_d = _x distance _pos; if (_d < _bestD) then {_bestD = _d; _bestT = _x}} } forEach towns;
							if (!isNull _bestT) then {_tgtPos = getPos _bestT} else {
								private ["_eHQ"];
								_eHQ = (if (_side == west) then {east} else {west}) Call WFBE_CO_FNC_GetSideHQ;
								if (!isNull _eHQ) then {_tgtPos = getPos _eHQ};
							};
						};
						if (count _tgtPos < 2) exitWith {}; //--- no front to point at this tick; leave unset, retried next build/strategy cycle.
						//--- 2) egress point = a step (~180m) from the factory toward the front, then
						//--- snapped onto the nearest USABLE road within 220m so the first leg is a
						//--- drivable lane. Falls back to the toward-front point if no usable road near.
						_dx = (_tgtPos select 0) - (_pos select 0);
						_dy = (_tgtPos select 1) - (_pos select 1);
						_dist = sqrt (_dx*_dx + _dy*_dy);
						if (_dist < 1) then {_dist = 1};
						_egN = 180 min _dist;
						_egX = (_pos select 0) + (_dx / _dist) * _egN;
						_egY = (_pos select 1) + (_dy / _dist) * _egN;
						_rally = [_egX, _egY, 0];
						//--- snap to the nearest USABLE road (same connectivity filter as placement),
						//--- mirroring the ServicePoint road-snap pattern.
						{
							private ["_conn","_okr"];
							_okr = true;
							if (!isNil {missionNamespace getVariable "WF_A2_Vanilla"} && {!WF_A2_Vanilla}) then {
								_conn = _x call {private "_c"; _c = []; if (!isNil {roadsConnectedTo _this}) then {_c = roadsConnectedTo _this}; _c};
								if (count _conn < 2) then {_okr = false};
							};
							if (_okr && {!(surfaceIsWater (getPos _x))}) exitWith {_rally = getPos _x};
						} forEach ([_rally, 220] call {private ["_p","_r","_rds","_out","_best","_bestD","_d"]; _p = _this select 0; _r = _this select 1; _rds = _p nearRoads _r; _out = []; _best = objNull; _bestD = 1e9; { _d = (getPos _x) distance _p; if (_d < _bestD) then {_bestD = _d; _best = _x} } forEach _rds; if (!isNull _best) then {_out = [_best]}; _out + (_rds - [_best])});
						//--- 3) wait for the async factory to finish, then stamp the rally on the
						//--- nearest matching structure registered at _pos. Bounded so a failed build
						//--- never leaves a hung watcher.
						_wait = 0;
						_site = objNull;
						while {isNull _site && _wait < 360} do {
							sleep 5; _wait = _wait + 5;
							{
								if (((_x getVariable ["wfbe_structure_type", ""]) in ["Light","Heavy","Aircraft"]) && {alive _x} && {(_x distance _pos) < 25}) exitWith {_site = _x};
							} forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
						};
						if (!isNull _site) then {
							_site setVariable ["wfbe_aicom_factory_rally", _rally, true];
							["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] factory rally SET on %2 -> %3 (toward front).", str _side, typeOf _site, _rally]] Call WFBE_CO_FNC_AICOMLog;
							diag_log ("AICOMSTAT|v1|EVENT|" + str _side + "|" + str (round (time / 60)) + "|FACTORY_RALLY_SET|" + (typeOf _site) + "|" + str _rally);
						};
					};
				};
				["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] building %2 at %3 (cost %4 supply, doctrine %5, branch-out %6).", _sideText, _x, _pos, _cost, _doctrine, _coreDone]] Call WFBE_CO_FNC_AICOMLog;
				//--- STRUCTURE cost/currency telemetry (claude-gaming 2026-06-15): Steff saw "the AI
				//--- comms upgraded buildings and such" - surface the base-building SPEND. Structures
				//--- are paid from supply when the dual-currency economy is on (_dual); otherwise the
				//--- supply deduction is skipped (free). Rides the existing per-structure build event.
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|STRUCTURE_BUILT|struct=" + _x + "|cost=" + str _cost + "|paidBy=" + (if (_dual) then {"supply"} else {"free"}) + "|branchOut=" + str _coreDone);
			};
		};
		}; //--- end if (!_capped)
	};
} forEach _order;

//--- 3) Base defenses: a few manned statics once the Barracks stands (crewed from it).
_defMax = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_DEFENSES_MAX", 4];
//--- AICOM v2 (Ray, SELF-HEALING within the 4-cap): count LIVE base defenses (StaticWeapon tagged wfbe_defense
//--- near the HQ), NOT a monotonic counter, so a destroyed gun is REBUILT next pass and the base never erodes to
//--- nothing over a long round. Mirror onto wfbe_aicom_defenses so the arty gate (~L558) reads the live value.
_defCount = 0;
{ if (!isNull _x && {alive _x} && {(_x getVariable ["wfbe_defense", false])}) then {_defCount = _defCount + 1} } forEach (_hqPos nearEntities [["StaticWeapon"], (missionNamespace getVariable ["WFBE_C_BASEGC_RANGE", 800])]);
_logik setVariable ["wfbe_aicom_defenses", _defCount];
if (_defCount < _defMax) then {
	_have = false;
	{ if ((_x getVariable ["wfbe_structure_type", ""]) == "Barracks" && {alive _x}) exitWith {_have = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
	if (_have) then {
		//--- AICOM v2 (Ray): BALANCED light defense within the 4-cap - rotate MG / AT / GL / AA so enemy armor (AT),
		//--- massed infantry (GL) and air (AA) all meet resistance, not just MG/AA. AT/GL guarded (some factions
		//--- lack the class -> fall back to MG). Classnames from the faction defense config.
		_defClass = switch (_defCount % 4) do {
			case 1: { private "_atC"; _atC = missionNamespace getVariable Format ["WFBE_%1DEFENSES_ATPOD", _sideText]; if (isNil "_atC") then {missionNamespace getVariable Format ["WFBE_%1DEFENSES_MG", _sideText]} else {_atC} };
			case 2: { private "_glC"; _glC = missionNamespace getVariable Format ["WFBE_%1DEFENSES_GL", _sideText]; if (isNil "_glC") then {missionNamespace getVariable Format ["WFBE_%1DEFENSES_MG", _sideText]} else {_glC} };
			case 3: { missionNamespace getVariable Format ["WFBE_%1DEFENSES_AAPOD", _sideText] };
			default { missionNamespace getVariable Format ["WFBE_%1DEFENSES_MG", _sideText] };
		};
		if (!isNil "_defClass") then {
			if (typeName _defClass == "ARRAY") then {_defClass = _defClass select 0};
			_defData = missionNamespace getVariable _defClass;
			_defPrice = if (!isNil "_defData") then {_defData select QUERYUNITPRICE} else {0};
			_funds = (_side) Call GetAICommanderFunds;
			if (_funds >= _defPrice) then {
				[_side, -_defPrice] Call ChangeAICommanderFunds;
				_pos = [28, 42] Call _findBuildPos;
				//--- Steff 2026-06-13: face the defense OUTWARD (bearing HQ->pos) not a random heading,
				//--- so manned statics engage outward threats and never fire across the base into friendly
				//--- defenses/structures.
				private ["_defDx","_defDy"]; _defDx = (_pos select 0) - (_hqPos select 0); _defDy = (_pos select 1) - (_hqPos select 1); _defDir = if (abs _defDx < 0.01 && {abs _defDy < 0.01}) then {random 360} else {_defDx atan2 _defDy}; //--- BUG-FIX 2026-06-14: guard atan2(0,0) zero-divisor when build pos == HQ (left _defDir unset -> garbage heading).
				[_defClass, _side, _pos, _defDir, true, true] Call ConstructDefense;
				_logik setVariable ["wfbe_aicom_defenses", _defCount + 1];
				["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] placed base defense %2/%3 [%4].", _sideText, _defCount + 1, _defMax, _defClass]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
	};
};

//--- 4) V0.5: two base artillery pieces once the defenses stand. Construction tags
//--- them WFBE_CommanderArtillery; the strategy worker fires them at spearhead
//--- towns / the enemy HQ (fire is free in WFBE - the real cooldown gates it).
//--- V0.6.3: OFF by default (owner call) - opt back in via WFBE_C_AI_COMMANDER_ARTILLERY = 1.
if (((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0) && {(missionNamespace getVariable "WFBE_C_ARTILLERY") > 0}) then {
	_artyBuilt = _logik getVariable ["wfbe_aicom_arty_built", 0];
	if (_artyBuilt < 2 && {(_logik getVariable ["wfbe_aicom_defenses", 0]) >= _defMax}) then {
		_have = false;
		{ if ((_x getVariable ["wfbe_structure_type", ""]) == "Barracks" && {alive _x}) exitWith {_have = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
		if (_have) then {
			_defClass = "";
			_artyClasses = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_CLASSNAMES", _sideText];
			if (!isNil "_artyClasses" && {count _artyClasses > 0}) then {
				//--- Entries are FAMILY arrays ([['M119_US_EP1'],['M252_US_EP1'],...]): pass a
				//--- CLASSNAME on, or ConstructDefense's createVehicle throws a type error that
				//--- kills the whole supervisor script.
				//--- Ray 2026-06-29 SELF-PROPELLED-ONLY: the AI may field only TRACKED/WHEELED self-propelled
				//--- artillery - NO static towed howitzers (D30/M119) or mortar emplacements (2b14/M252). Those
				//--- occupy ARTILLERY_CLASSNAMES indices 0/1 (StaticWeapon); the SPG (GRAD/MLRS) is a later index.
				//--- Scan ALL families and accept the FIRST class that is a self-propelled hull (Tank/Car/Wheeled_APC/
				//--- Tracked_APC and NOT StaticWeapon). If the side has no SPG class, build nothing - a static gun is
				//--- never created for the AI. A2-OA-safe: string-form isKindOf on the classname (idiom: AwardBounty.sqf:34).
				_i = 0;
				while {_i < count _artyClasses && {_defClass == ""}} do {
					private ["_cand","_isSP"];
					_fam = _artyClasses select _i;
					_cand = "";
					if (typeName _fam == "ARRAY") then {
						if (count _fam > 0) then {_cand = _fam select 0};
					} else {
						_cand = _fam;
					};
					if (_cand != "" && {isClass (configFile >> "CfgVehicles" >> _cand)}) then {
						_isSP = ((_cand isKindOf "Tank") || (_cand isKindOf "Car") || (_cand isKindOf "Wheeled_APC") || (_cand isKindOf "Tracked_APC")) && {!(_cand isKindOf "StaticWeapon")};
						if (_isSP) then {_defClass = _cand};
					};
					_i = _i + 1;
				};
				if (_defClass == "") then {
					["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] base-artillery build skipped - no SELF-PROPELLED (tracked/wheeled) arty class for this side (static towed/mortar excluded by design).", _sideText]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
			if (_defClass != "") then {
				_defData = missionNamespace getVariable _defClass;
				_defPrice = if (!isNil "_defData") then {_defData select QUERYUNITPRICE} else {0};
				_funds = (_side) Call GetAICommanderFunds;
				if (_funds >= _defPrice) then {
					[_side, -_defPrice] Call ChangeAICommanderFunds;
					_pos = [25, 38] Call _findBuildPos;
					[_defClass, _side, _pos, random 360, true, true] Call ConstructDefense;
					_logik setVariable ["wfbe_aicom_arty_built", _artyBuilt + 1];
					["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] placed base artillery %2/2 [%3] (cost %4 funds).", _sideText, _artyBuilt + 1, _defClass, _defPrice]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
		};
	};
};

//--- ============================================================================================
//--- 5) FORWARD OUTPOST (2nd base, AICOM v2 / Ray). When supply is ABUNDANT, stand up a SECOND
//---    CommandCenter + its own doctrine factory + light defense at a DISTANT forward owned town, so
//---    spare supply projects production toward the front. Self-contained, supply-guarded, idempotent.
//---    REUSES _findBuildPos by repointing the _hqPos CLOSURE var to the forward center (the helper reads
//---    _hqPos as a free var, L137/141). Runs LAST so _hqPos is free to repoint. FWDBASE_ENABLE=0 = inert.
//--- ============================================================================================
private ["_fwdEnable","_relocActive","_rearHQpos","_fwdMyID","_fwdCap","_fwdSupplyGate","_fwdReserve","_fwdMinDist","_ccCount","_basesMax","_frontF","_haveFront","_frontPosF","_bestFwdT","_bestFwdD","_dxF","_dyF","_dF","_standoffF","_fwdPos","_fwdOrder","_fwdHave","_ord","_fwdIdx","_fwdClass","_baseRF","_presentF","_fwdCost","_fwdFacP","_fwdScript","_fwdDir","_fwdCCpresent","_fwdDefMax","_fwdDefCount","_fwdDefClass","_fwdDefData","_fwdDefPrice","_fwdFunds","_fwdDefPos","_fwdDefDir","_fwdDx2","_fwdDy2"];
_fwdEnable = (missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_ENABLE", 1]) > 0;
if (_fwdEnable && {_dual}) then {
	_relocActive = _logik getVariable ["wfbe_mhqreloc_active", false];
	if (!_relocActive && {(_side) Call WFBE_CO_FNC_GetSideHQDeployStatus} && {!(_logik getVariable ["wfbe_hqinuse", false])}) then {
		_rearHQpos = +_hqPos;                               //--- capture the REAR HQ pos BEFORE any repoint.
		_fwdMyID   = (_side) Call WFBE_CO_FNC_GetSideID;
		_supply    = (_side) Call WFBE_CO_FNC_GetSideSupply; //--- re-read LIVE supply (the primary loop above already spent this tick).
		_fwdCap    = missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", 40000];
		_fwdSupplyGate = (_fwdCap min 50000) * (missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_SUPPLY_FRAC", 0.80]); //--- clamp the cap at the realistic prod limit so DEBUG's inflated 900k supply-cap doesn't push the gate to 720k (unreachable); prod (40k cap) is unchanged at 32k.
		if (_fwdSupplyGate < (missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_SUPPLY_FLOOR", 24000])) then {_fwdSupplyGate = missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_SUPPLY_FLOOR", 24000]};
		_fwdReserve = missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_SUPPLY_RESERVE", 6000];
		_fwdMinDist = missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_MIN_DIST", 3500];
		if (_supply >= _fwdSupplyGate) then {
			_ccCount = {((_x getVariable ["wfbe_structure_type", ""]) == "CommandCenter") && {alive _x}} count _structures;
			_basesMax = missionNamespace getVariable ["WFBE_C_AICOM_BASES_MAX", 2];
			if (_ccCount >= 1 && {_ccCount < _basesMax}) then {
				//--- FIND a forward owned town: own-held, >= MIN_DIST from the rear HQ, nearest the published front.
				_frontF = objNull; _haveFront = false;
				private "_tgF"; _tgF = _logik getVariable ["wfbe_aicom_targets", []];
				if (typeName _tgF == "ARRAY" && {count _tgF > 0}) then {_frontF = _tgF select 0; if (!isNull _frontF) then {_haveFront = true}};
				_frontPosF = if (_haveFront) then {getPos _frontF} else {[]};
				_bestFwdT = objNull; _bestFwdD = 1e9;
				{
					if ((_x getVariable ["sideID", -1]) == _fwdMyID) then {
						private ["_dHQ","_score"];
						_dHQ = _x distance _rearHQpos;
						if (_dHQ >= _fwdMinDist) then {
							_score = if (_haveFront) then {_x distance _frontPosF} else {0 - _dHQ};
							if (_score < _bestFwdD) then {_bestFwdD = _score; _bestFwdT = _x};
						};
					};
				} forEach towns;
					//--- FALLBACK: prod town-start owns only a rear cluster; no owned town qualifies far out.
					//--- Build the outpost toward the published FRONT town instead (standoff math already places it rearward of the town).
					if (isNull _bestFwdT && {_haveFront} && {!isNull _frontF}) then {
						if ((_frontF distance _rearHQpos) >= _fwdMinDist) then {_bestFwdT = _frontF};
					};
					if (isNull _bestFwdT) then {
						["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] FWDBASE: no eligible forward town (owned/front) >= %2m - skipping.", _sideText, _fwdMinDist]] Call WFBE_CO_FNC_AICOMLog;
					};
				if (!isNull _bestFwdT) then {
					//--- forward CENTER = standoff BEHIND the town toward the rear HQ (out of the town core).
					_dxF = (_rearHQpos select 0) - (getPos _bestFwdT select 0);
					_dyF = (_rearHQpos select 1) - (getPos _bestFwdT select 1);
					_dF  = sqrt (_dxF*_dxF + _dyF*_dyF); if (_dF < 1) then {_dF = 1};
					_standoffF = (missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_TOWN_STANDOFF", 350]) min _dF;
					_fwdPos = [(getPos _bestFwdT select 0) + (_dxF / _dF) * _standoffF, (getPos _bestFwdT select 1) + (_dyF / _dF) * _standoffF, 0];
					if (((_fwdPos distance _rearHQpos) >= _fwdMinDist) && {!surfaceIsWater _fwdPos}) then {
						_hqPos = _fwdPos;   //--- THE CRUX: _findBuildPos now rings the FORWARD center.
						_fwdOrder = if (_doctrine == "HF") then {["CommandCenter","Heavy"]} else {["CommandCenter","Light"]};
						_fwdHave = false;
						{
							_ord = _x;   //--- capture the order TYPE-KEY before the inner forEach clobbers _x.
							if (!_fwdHave) then {
								_fwdIdx = _names find _ord;
								if (_fwdIdx >= 0) then {
									_fwdClass = _classes select _fwdIdx;
									_baseRF = missionNamespace getVariable ["WFBE_C_AICOM_BASE_RADIUS", 450];
									_presentF = false;
									{ if (typeOf _x == _fwdClass && {alive _x} && {((getPos _x) distance _fwdPos) <= _baseRF}) exitWith {_presentF = true} } forEach _structures;
									if (!_presentF && {(time - (_logik getVariable [Format ["wfbe_aicom_fwdbuilt_%1", _ord], -1e6])) < 300}) then {_presentF = true};
									if (!_presentF) then {
										_fwdHave = true;   //--- one-per-pass latch (consume the slot whether or not affordable).
										_fwdCost = _costs select _fwdIdx;
										if (_supply >= (_fwdCost + _fwdReserve)) then {
											_fwdFacP = if (_ord in ["Light","Heavy","Aircraft"]) then {
												[(missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_RING_MIN", 60]), (missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_RING_MAX", 110]), 1] Call _findBuildPos
											} else {
												[(missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_RING_MIN", 60]), (missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_RING_MAX", 110])] Call _findBuildPos
											};
											if (_dual) then {[_side, -_fwdCost, Format ["AI commander forward outpost (%1).", _ord], false] Call ChangeSideSupply};
											_logik setVariable [Format ["wfbe_aicom_fwdbuilt_%1", _ord], time];
											_fwdScript = _scripts select _fwdIdx;
											_fwdDir = if (_haveFront) then {((_frontPosF select 0) - (_fwdPos select 0)) atan2 ((_frontPosF select 1) - (_fwdPos select 1))} else {random 360};
											[_fwdClass, _side, _fwdFacP, _fwdDir, _fwdIdx] ExecVM (Format ["Server\Construction\Construction_%1.sqf", _fwdScript]);
											["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] FORWARD OUTPOST building %2 at %3 (town %4, cost %5, distRear %6).", _sideText, _ord, _fwdFacP, (_bestFwdT getVariable ["name","?"]), _fwdCost, round (_fwdPos distance _rearHQpos)]] Call WFBE_CO_FNC_AICOMLog;
											diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FWDBASE_BUILD|struct=" + _ord + "|cost=" + str _fwdCost + "|town=" + (_bestFwdT getVariable ["name","?"]) + "|distRear=" + str (round (_fwdPos distance _rearHQpos)));
										};
									};
								};
							};
						} forEach _fwdOrder;
						//--- LIGHT forward defense: self-healing manned statics once the forward CC stands.
						_fwdCCpresent = false;
						{ if ((_x getVariable ["wfbe_structure_type", ""]) == "CommandCenter" && {alive _x} && {((getPos _x) distance _fwdPos) <= (missionNamespace getVariable ["WFBE_C_AICOM_BASE_RADIUS", 450])}) exitWith {_fwdCCpresent = true} } forEach _structures;
						if (_fwdCCpresent) then {
							_fwdDefMax = missionNamespace getVariable ["WFBE_C_AICOM_FWDBASE_DEF_MAX", 2];
							_fwdDefCount = 0;
							{ if (!isNull _x && {alive _x} && {(_x getVariable ["wfbe_defense", false])}) then {_fwdDefCount = _fwdDefCount + 1} } forEach (_fwdPos nearEntities [["StaticWeapon"], (missionNamespace getVariable ["WFBE_C_BASEGC_RANGE", 800])]);
							if (_fwdDefCount < _fwdDefMax) then {
								_fwdDefClass = missionNamespace getVariable Format ["WFBE_%1DEFENSES_MG", _sideText];
								if (!isNil "_fwdDefClass") then {
									if (typeName _fwdDefClass == "ARRAY") then {_fwdDefClass = _fwdDefClass select 0};
									_fwdDefData = missionNamespace getVariable _fwdDefClass;
									_fwdDefPrice = if (!isNil "_fwdDefData") then {_fwdDefData select QUERYUNITPRICE} else {0};
									_fwdFunds = (_side) Call GetAICommanderFunds;
									if (_fwdFunds >= _fwdDefPrice) then {
										[_side, -_fwdDefPrice] Call ChangeAICommanderFunds;
										_fwdDefPos = [22, 40] Call _findBuildPos;
										_fwdDx2 = (_fwdDefPos select 0) - (_fwdPos select 0); _fwdDy2 = (_fwdDefPos select 1) - (_fwdPos select 1);
										_fwdDefDir = if (abs _fwdDx2 < 0.01 && {abs _fwdDy2 < 0.01}) then {random 360} else {_fwdDx2 atan2 _fwdDy2};
										[_fwdDefClass, _side, _fwdDefPos, _fwdDefDir, true, true] Call ConstructDefense;
										["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] FORWARD OUTPOST defense %2/%3 [%4].", _sideText, _fwdDefCount + 1, _fwdDefMax, _fwdDefClass]] Call WFBE_CO_FNC_AICOMLog;
										diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|FWDBASE_DEFENSE|n=" + str (_fwdDefCount + 1) + "|max=" + str _fwdDefMax);
									};
								};
							};
						};
					};
				};
			};
		};
	};
};
