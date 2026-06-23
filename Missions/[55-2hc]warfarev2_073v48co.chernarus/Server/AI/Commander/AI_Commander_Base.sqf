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

private ["_side","_sideText","_logik","_hq","_supply","_names","_classes","_costs","_scripts","_structures","_doctrine","_order","_idx","_have","_cost","_class","_script","_pos","_ang","_hqPos","_defMax","_defCount","_defClass","_defData","_defPrice","_funds","_deployCost","_dual","_findBuildPos","_isUsableRoad","_nearUsableRoad","_factoryRally","_upgrades","_coreDone","_placed","_roads","_cand","_artyBuilt","_artyClasses","_fam","_i","_bankIdx","_bankCost","_cbrIdx","_scaffoldActivated","_dPos","_dTry","_dAng","_artyThreat","_enemySide","_enemySideText","_enemyArtyCount","_cbrCost","_cbrReserve","_cbrMinTime","_myID","_ownTowns","_defDir","_resIdx","_resCost","_artradIdx","_artradCost","_artradReqArty","_econGateTowns","_econMyID","_econOpen"];

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
		//--- V0.6.5 owner report: HQ deployed ON a road (MHQ start spot). Nudge the
		//--- deploy position off-road/out-of-water; fall back to the raw spot if no
		//--- candidate is found within 20 tries.
		_dPos = getPos _hq;
		if ((count (_dPos nearRoads 14) > 0) || {surfaceIsWater _dPos}) then {
			_dTry = 0;
			while {_dTry < 20 && {(count (_dPos nearRoads 14) > 0) || {surfaceIsWater _dPos}}} do {
				_dAng = random 360;
				_dPos = [((getPos _hq) select 0) + (22 + random 28) * sin _dAng, ((getPos _hq) select 1) + (22 + random 28) * cos _dAng, 0];
				_dTry = _dTry + 1;
			};
			if ((count (_dPos nearRoads 14) > 0) || {surfaceIsWater _dPos}) then {_dPos = getPos _hq};
			["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] HQ deploy spot nudged off-road to %2 (%3 tries).", _sideText, _dPos, _dTry]] Call WFBE_CO_FNC_AICOMLog;
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

_findBuildPos = {
	private ["_rmin","_rmax","_nearRoad","_p","_ok","_try","_ang","_best","_haveDry","_rd","_rp","_hd","_ox","_oy","_cand","_blocked","_sx","_sy","_tries"];
	_rmin = _this select 0; _rmax = _this select 1;
	_nearRoad = if (count _this > 2) then {_this select 2} else {0};
	//--- the USABLE-road filter rejects more candidates than the old bare nearRoads gate,
	//--- so give the near-road mode more tries to find a paved lane to sit beside.
	_tries = if (_nearRoad == 1) then {40} else {24};
	_ok = false; _try = 0; _haveDry = false; _best = [_hqPos, 35] Call WFBE_CO_FNC_GetEmptyPosition;
	_p = _best;
	while {!_ok && _try < _tries} do {
		_ang = random 360;
		_p = [(_hqPos select 0) + (_rmin + random (_rmax - _rmin)) * sin _ang, (_hqPos select 1) + (_rmin + random (_rmax - _rmin)) * cos _ang, 0];
		if (_nearRoad == 1) then {
			//--- NEAR-road (Light/Heavy/Aircraft factories): BESIDE a USABLE road on flat,
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
				_ox = (_rp select 0) + 16 * sin _hd;
				_oy = (_rp select 1) + 16 * cos _hd;
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
					if (((_cand distance _rp) < 12)) then {_blocked = true};
					//--- B67: reject a candidate that crowds an existing friendly structure
					//--- (< WFBE_C_AICOM_STRUCT_SPACING). GetSideStructures fresh - _findBuildPos
					//--- runs before the outer _structures local is assigned (line ~314).
					if (!_blocked) then {
						{ if ((_cand distance _x) < (missionNamespace getVariable ["WFBE_C_AICOM_STRUCT_SPACING", 45])) exitWith {_blocked = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
					};
					if (!_blocked) then {_p = _cand; _ok = true};
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
				if (count (_p nearRoads 22) == 0) then {
					//--- B67: reject a candidate that crowds an existing friendly structure
					//--- (< WFBE_C_AICOM_STRUCT_SPACING). GetSideStructures fresh - _findBuildPos
					//--- runs before the outer _structures local is assigned (line ~314).
					_ok = true;
					{ if ((_p distance _x) < (missionNamespace getVariable ["WFBE_C_AICOM_STRUCT_SPACING", 45])) exitWith {_ok = false} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
				};
			};
		};
		_try = _try + 1;
	};
	//--- try-budget failure: hand back the best dry-land candidate (never water).
	if (!_ok && _haveDry) then {_p = _best};
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
		} forEach (nearestObjects [getPos (_side Call WFBE_CO_FNC_GetSideHQ), ["StaticWeapon","Tank","Car"], 10000]);
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
					_roads = _hqPos nearRoads 200;
					_cand = [];
					{ if (((getPos _x) distance _hqPos) > 25) then {_cand = _cand + [_x]} } forEach _roads;
					if (count _cand > 0) then {
						_pos = getPos (_cand select (floor (random (count _cand))));
						if (!(surfaceIsWater _pos)) then {_placed = true};
					};
				};
				//--- task #25: production factories (Light/Heavy/Aircraft) are where commander
				//--- teams spawn, so bias them NEAR a road for unit egress; everything else
				//--- (CC/Barracks/Bank/CBR) keeps the default OFF-road placement.
				if (!_placed) then {
					if (_x in ["Light","Heavy","Aircraft"]) then {
						//--- B67: widen the factory placement ring (was 45..75) so production
						//--- factories spread out from the HQ core and clear the spacing gate.
						_pos = [(missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MIN", 60]), (missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MAX", 110]), 1] Call _findBuildPos;
					} else {
						_pos = [(missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MIN", 60]), (missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_RING_MAX", 110])] Call _findBuildPos;
					};
				};
				if (_dual) then {[_side, -_cost, Format ["AI commander base construction (%1).", _x], false] Call ChangeSideSupply};
				_logik setVariable [Format ["wfbe_aicom_built_%1", _x], time];
				_script = _scripts select _idx;
				[_class, _side, _pos, random 360, _idx] ExecVM (Format ["Server\Construction\Construction_%1.sqf", _script]);
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
	};
} forEach _order;

//--- 3) Base defenses: a few manned statics once the Barracks stands (crewed from it).
_defMax = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_DEFENSES_MAX", 4];
_defCount = _logik getVariable ["wfbe_aicom_defenses", 0];
if (_defCount < _defMax) then {
	_have = false;
	{ if ((_x getVariable ["wfbe_structure_type", ""]) == "Barracks" && {alive _x}) exitWith {_have = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
	if (_have) then {
		//--- Alternate MG / AA pods; classnames from the faction defense config (guarded).
		_defClass = if (_defCount % 2 == 0) then {
			missionNamespace getVariable Format ["WFBE_%1DEFENSES_MG", _sideText]
		} else {
			missionNamespace getVariable Format ["WFBE_%1DEFENSES_AAPOD", _sideText]
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
				//--- kills the whole supervisor script. Family _artyBuilt, scanning past empties.
				_i = _artyBuilt;
				while {_i < count _artyClasses && {_defClass == ""}} do {
					_fam = _artyClasses select _i;
					if (typeName _fam == "ARRAY") then {
						if (count _fam > 0) then {_defClass = _fam select 0};
					} else {
						_defClass = _fam;
					};
					_i = _i + 1;
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
