//--- DO NOT CHANGE.
WESTID = 0;
EASTID = 1;
RESISTANCEID = 2;
//--- DO NOT CHANGE.
QUERYUNITLABEL = 0;
QUERYUNITPICTURE = 1;
QUERYUNITPRICE = 2;
QUERYUNITTIME = 3;
QUERYUNITCREW = 4;
QUERYUNITUPGRADE = 5;
QUERYUNITFACTORY = 6;
QUERYUNITSKILL = 7;
QUERYUNITFACTION = 8;
QUERYUNITTURRETS = 9;
//--- DO NOT CHANGE.
QUERYGEARLABEL = 0;
QUERYGEARPICTURE = 1;
QUERYGEARCLASS = 2;
QUERYGEARTYPE = 3;
QUERYGEARCOST = 4;
QUERYGEARUPGRADE = 5;
QUERYGEARALLOWED = 6;
QUERYGEARHANDGUNPOOL = 7;
QUERYGEARMAGAZINES = 8;
QUERYGEARSPACE = 9;
QUERYGEARALLOWTWO = 10;

//--- Side Statics.
WFBE_C_WEST_ID = 0;
WFBE_C_EAST_ID = 1;
WFBE_C_GUER_ID = 2;
WFBE_C_CIV_ID = 3;
WFBE_C_UNKNOWN_ID = 4;

//--- Common Upgrades, each number match the upgrades arrays.
WFBE_UP_BARRACKS = 0;
WFBE_UP_LIGHT = 1;
WFBE_UP_HEAVY = 2;
WFBE_UP_AIR = 3;
WFBE_UP_PARATROOPERS = 4;
WFBE_UP_UAV = 5;
WFBE_UP_SUPPLYRATE = 6;
WFBE_UP_RESPAWNRANGE = 7;
WFBE_UP_AIRLIFT = 8;
WFBE_UP_FLARESCM = 9;
WFBE_UP_ARTYTIMEOUT = 10;
WFBE_UP_ICBM = 11;
WFBE_UP_FASTTRAVEL = 12;
WFBE_UP_GEAR = 13;
WFBE_UP_AMMOCOIN = 14;
WFBE_UP_EASA = 15;
WFBE_UP_SUPPLYPARADROP = 16;
WFBE_UP_ARTYAMMO = 17;
WFBE_UP_IRSMOKE = 18;
WFBE_UP_AIRAAM = 19;
WFBE_UP_AAR = 20;
WFBE_UP_UNITCOST = 21;
WFBE_UP_CBRADAR = 22;
WFBE_UP_PATROLS = 23;

//--- Side patrols (Patrols upgrade): max concurrent patrol teams per side.
if (isNil "WFBE_C_SIDE_PATROLS_MAX") then {WFBE_C_SIDE_PATROLS_MAX = 3};  //--- Build83 (Ray 2026-07-01): +1 WEST/EAST side-patrol cap 2->3 (flat fallback; the pop-tier BY_TIER array below is the live consumer). [B36.1 2026-06-15: was 3->2.] Patrols stay LOW even as the HQ-team curve scales up; the EFFECTIVE cap is level-aware (min(this, patrol level)) in server_side_patrols.sqf, so patrol-1 => 1, patrol-2+ => 3 per side, never more.

/*
	### Working with the missionNamespace ###
	 * The With command allows us to swap the Global variable Namespace.
	 * It prevents the typical long variable declaration (missionNamespace setVariable...).

	In the declaration below, the parameters are first (they are checked with the isNil command).
	The isNil check prevent us from overriding MP parameters.
*/
with missionNamespace do {

//--- ZG-FIX (cmdcon44-e, claude-gaming 2026-07-03): Zargabad-scoped constant pre-sets.
//--- These run BEFORE the isNil-guarded CH/TK defaults below, so the ZG values win and the
//--- CH/TK defaults (e.g. HQSTRIKE_MIN_TOWNS=12) are skipped on Zargabad. CH/TK: byte-identical
//--- (worldName guard skips this block). isNil guards here respect lobby-param pre-sets.
//--- Rationale: ZG is a small dense urban map (~8 towns, 8192m). The CH defaults are scaled for
//--- Chernarus (40+ towns, 15360m) and are unreachable on ZG -> AI never entered engage/strike
//--- phase, matches stalled (0 captures in the live 66-min soak). LANE_OFFSET and REACH_FOOT
//--- match TK values (same map-size class, same tight-valley routing constraint).
//--- EGRESS_MAP_BOUNDS=1: use Init_Boundaries ZG size (8192) not the legacy 15360 CH box,
//--- so random base-start candidates are not selected in out-of-bounds ghost terrain.
if (worldName == "Zargabad") then {
	if (isNil "WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS") then {WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS = 5};
	if (isNil "WFBE_C_AICOM_ENGAGE_MIN_TOWNS")   then {WFBE_C_AICOM_ENGAGE_MIN_TOWNS   = 4};
	if (isNil "WFBE_C_AICOM_LANE_OFFSET")         then {WFBE_C_AICOM_LANE_OFFSET         = 60};
	if (isNil "WFBE_C_AICOM_ASSAULT_REACH_FOOT")  then {WFBE_C_AICOM_ASSAULT_REACH_FOOT  = 1800};
	//--- NOTE: this 1800 matches TK's empirical value set at line ~1229 below, but via a different
	//--- path. Line ~1229 uses `if (worldName == "Takistan") then {1800} else {2500}` -- on ZG that
	//--- guard evaluates the else branch (worldName is "Zargabad") and would set 2500, not 1800.
	//--- This ZG pre-set runs BEFORE that line, lands 1800 first, and the isNil guard at ~1229
	//--- finds the var already set and skips. So this line is the only path to 1800 on ZG; on TK
	//--- the pre-set is never reached (worldName guard skips the entire ZG block). No double-assignment.
	if (isNil "WFBE_C_BASE_EGRESS_MAP_BOUNDS")    then {WFBE_C_BASE_EGRESS_MAP_BOUNDS    = 1};
	//--- BUG-2 (fable GR-2026-07-03a): ZG is 11 towns on an 8192m map, so the center-of-map gravity well is sharp.
	//--- Use a STRONGER repick penalty (~0.8x FAR_PENALTY) and a slightly longer memory so the fist genuinely rotates
	//--- across the small town set instead of pinning the 2 central hubs. Same isNil-guard/pre-set-respect idiom as the block above.
	if (isNil "WFBE_C_AICOM_REPICK_PENALTY")    then {WFBE_C_AICOM_REPICK_PENALTY    = 800};
	if (isNil "WFBE_C_AICOM_REPICK_MEMORY_MIN") then {WFBE_C_AICOM_REPICK_MEMORY_MIN = 7};
};
//--- End ZG-FIX Zargabad-scoped pre-sets.

//--- GUER "Insurgents" playable faction master gate (0=off, 1=on). Default OFF = byte-for-byte today's behaviour.
	if (isNil "WFBE_C_GUER_PLAYERSIDE") then {WFBE_C_GUER_PLAYERSIDE = 1}; //--- B66: 0->1 GUER playable ON (trial round).
	if (isNil "WFBE_C_GUER_VBIED_ARM_DELAY") then {WFBE_C_GUER_VBIED_ARM_DELAY = 3};
	if (isNil "WFBE_C_GUER_VBIED_BLAST_RADIUS") then {WFBE_C_GUER_VBIED_BLAST_RADIUS = 60}; //--- B74.1 (Ray 2026-06-23): 30->60. The blast is now 3x Bo_FAB_250 (far bigger than the old 3x 122mm HE), so widen the cash-for-kills snapshot radius to match the real lethal zone - otherwise kills outside 30m didn't pay (Ray: "grant money whenever something is killed").
	if (isNil "WFBE_C_GUER_VBIED_TYPE") then {WFBE_C_GUER_VBIED_TYPE = "hilux1_civil_2_covered"};
	if (isNil "WFBE_C_GUER_KILL_BOUNTY_COEF") then {WFBE_C_GUER_KILL_BOUNTY_COEF = 0.4};
	if (isNil "WFBE_C_GUER_IED_KILL_COEF") then {WFBE_C_GUER_IED_KILL_COEF = 0.30}; //--- B67 (Ray 2026-06-21) item #8: an IED kill pays only 30% of the normal vehicle/unit bounty (anti-farm) so spamming IEDs for cash is not worthwhile. Applied in RequestOnUnitKilled when the kill is tagged as an IED kill.

	//--- GUER improvised mortar strike constants REMOVED (owner de-dup decision 7a33e78892: Action_GuerMortarStrike
	//--- + the "guer-mortar-strike" server case are gone; the GDir panel mortar verb is retired in RequestGDirPanel.sqf).

	//--- GUER BARREL BOMB (fable/guer-barrelbomb): kill-gated, heli-delivered call-in triggered by a WF-scroll
	//--- action at a friendly town center (NOT the Commissar Panel, NOT a Tactical Center - see
	//--- GUER-BARRELBOMB-REVISED.md). Action_GuerHeliBombCall.sqf -> RequestSpecial -> Server_HandleSpecial
	//--- "guer-heli-bomb" -> Support_GuerHeliDrop.sqf (KAT_GuerHeliDrop).
	if (isNil "WFBE_C_GUER_HELIBOMB_ENABLE")        then {WFBE_C_GUER_HELIBOMB_ENABLE        = 1};    //--- master flag. 0 = OFF, byte-identical to HEAD.
	if (isNil "WFBE_C_GUER_HELIBOMB_COST")          then {WFBE_C_GUER_HELIBOMB_COST          = 3000}; //--- $ debited from the caller's GUER team per call-in.
	if (isNil "WFBE_C_GUER_HELIBOMB_COOLDOWN")      then {WFBE_C_GUER_HELIBOMB_COOLDOWN      = 900};  //--- seconds between calls (per player).
	if (isNil "WFBE_C_GUER_HELIBOMB_RANGE")         then {WFBE_C_GUER_HELIBOMB_RANGE         = 1600}; //--- max map-click designation range from the caller (m). Wider than mortar (1200) - a heli asset, not a foot call-in.
	if (isNil "WFBE_C_GUER_HELIBOMB_SHELLS")        then {WFBE_C_GUER_HELIBOMB_SHELLS        = 1};    //--- ordnance drops per call-in. 1 = a single barrel bomb, not a barrage.
	if (isNil "WFBE_C_GUER_HELIBOMB_SPREAD")        then {WFBE_C_GUER_HELIBOMB_SPREAD        = 15};   //--- +/- 2D impact offset from the exact click (m).
	if (isNil "WFBE_C_GUER_HELIBOMB_RADIUS")        then {WFBE_C_GUER_HELIBOMB_RADIUS        = 60};   //--- kill-credit snapshot/lethal radius (m).
	if (isNil "WFBE_C_GUER_KILLTIER_HELIBOMB")      then {WFBE_C_GUER_KILLTIER_HELIBOMB      = 60};   //--- cumulative GUER kills to unlock. Midpoint of the CURRENT M113(50)-T55(80) band - NOT the stale design doc's "30" (that now collides with KILLTIER_1=30 after the 2026-07 kill-tier retune; see build notes).
	if (isNil "WFBE_C_GUER_HELIDROP_CREDIT_KILLS")  then {WFBE_C_GUER_HELIDROP_CREDIT_KILLS  = 1};    //--- 1 = barrel-bomb kills advance WFBE_GUER_PLAYER_KILLS (owner: "Yes - count them"). Idempotent single-pass credit in Support_GuerHeliDrop.sqf; no wfbe_lasthitby stamp is used (would double-count via RequestOnUnitKilled's delayed-hit path).

	//--- GUER improvised armour (#109, shipped default-OFF): graded non-AT damage reduction on resistance light vehicles (technicals); AT/HEAT/ATGM pass through. See Common_GuerArmor.sqf. Un-shelve by raising the base above 0.

	//--- GUER improvised armour (#109, shipped default-OFF): graded non-AT damage reduction on resistance light vehicles (technicals); AT/HEAT/ATGM pass through. See Common_GuerArmor.sqf. Un-shelve by raising the base above 0.
	if (isNil "WFBE_C_GUER_IMPROVISED_ARMOR") then {WFBE_C_GUER_IMPROVISED_ARMOR = 0};	//--- base % damage reduction vs non-AT fire (0 = whole feature OFF).
	if (isNil "WFBE_C_GUER_IMPROVISED_ARMOR_TIERSTEP") then {WFBE_C_GUER_IMPROVISED_ARMOR_TIERSTEP = 4};	//--- extra % per WFBE_GUER_VEHICLE_TIER.
	if (isNil "WFBE_C_GUER_IMPROVISED_ARMOR_MAX") then {WFBE_C_GUER_IMPROVISED_ARMOR_MAX = 45};	//--- hard cap on effective % reduction.
	if (isNil "WFBE_C_GUER_IMPROVISED_ARMOR_MOBILITY_BONUS") then {WFBE_C_GUER_IMPROVISED_ARMOR_MOBILITY_BONUS = 15};	//--- extra % on drivetrain hits, keeps technicals mobile.

	//--- B75 (guer-tech): KILL-BASED TECH PROGRESSION. The GUER faction earns better gear by KILLS instead of
	//--- by elapsed match time (the old time-tier in Server_GuerStipend.sqf is removed). WFBE_GUER_PLAYER_KILLS is
	//--- the cumulative count of enemy (WEST/EAST) units killed BY resistance PLAYERS (incremented server-side in
	//--- RequestOnUnitKilled.sqf, publicVariable'd, JIP-seeded). It drives: the vehicle tier (BRDM/T-34/T-55/T-72),
	//--- the M113 VBIED unlock, the Ka-137 flare amount and the barracks AI cap. publicVariable is NOT JIP-replayed
	//--- in A2-OA, so this isNil-guarded 0 seed gives joiners a safe default until the per-kill broadcast / connect
	//--- catch-up (Server_OnPlayerConnected.sqf) lands.
		if (isNil "WFBE_GUER_PLAYER_KILLS") then {WFBE_GUER_PLAYER_KILLS = 0};
		//--- Vehicle-tier kill thresholds. tier1 (>= KILLTIER_1 kills) = BRDM + T-34, tier2 = T-55, tier3 = T-72 + BMP2.
		//--- These replace the old elapsed-time ladder (30m/90m/180m) that gated the GUER heavy vehicles.
		if (isNil "WFBE_C_GUER_KILLTIER_1") then {WFBE_C_GUER_KILLTIER_1 = 30};  //--- 2x-ed (was 15) - slow GUER kill-tech progression.
		if (isNil "WFBE_C_GUER_KILLTIER_2") then {WFBE_C_GUER_KILLTIER_2 = 80};  //--- 2x-ed (was 40).
		if (isNil "WFBE_C_GUER_KILLTIER_3") then {WFBE_C_GUER_KILLTIER_3 = 160}; //--- 2x-ed (was 80).
		//--- Truck VBIED speed target. 1.0 is the no-boost/off-equivalent value; owner requested 1.25x stock speed.
		if (isNil "WFBE_C_GUER_VBIED_SPEEDCOEF") then {WFBE_C_GUER_VBIED_SPEEDCOEF = 1.25};
		//--- Second VBIED: an UNARMED M113 with ~1.5x speed (driver-detonated, same blast + cash-for-kills as the hilux),
		//--- kill-gated into the GUER depot. M113_UN_EP1 exists on both maps so the type is map-independent (no TK repoint).
		if (isNil "WFBE_C_GUER_VBIED_M113_TYPE") then {WFBE_C_GUER_VBIED_M113_TYPE = "M113_UN_EP1"};
		if (isNil "WFBE_C_GUER_VBIED_M113_KILLS") then {WFBE_C_GUER_VBIED_M113_KILLS = 50}; //--- 2x-ed (was 25): GUER kills required before the M113 VBIED appears in the depot.
		if (isNil "WFBE_C_GUER_VBIED_M113_SPEEDCOEF") then {WFBE_C_GUER_VBIED_M113_SPEEDCOEF = 1.5}; //--- owner-requested target top-speed multiplier of the driver-local boost loop (~1.5x stock M113).
		//--- Third VBIED variant: a fast, small SUICIDE MOTORCYCLE (fable/guer-suicide-bike). Reuses the truck
		//--- VBIED's blast/attribution/payout machinery UNCHANGED (Server_HandleSpecial.sqf "guer-vbied-detonate"
		//--- case) -- only a third accepted vehicle type is added there. Always available when the flag is on
		//--- (tier-0, like the truck VBIED), not kill-gated like the M113. TYPE is repointed CH->TK/ZG the same
		//--- way VBIED_TYPE is (Root_GUE.sqf / Root_TKGUE.sqf / Root_GUE_PlayerOverlay.sqf).
		if (isNil "WFBE_C_GUER_SUICIDE_BIKE") then {WFBE_C_GUER_SUICIDE_BIKE = 1};
		if (isNil "WFBE_C_GUER_SUICIDE_BIKE_TYPE") then {WFBE_C_GUER_SUICIDE_BIKE_TYPE = "TT650_Ins"};
		//--- Ka-137 (Ka137_MG_PMC) flares: the recon heli ships with NO countermeasures. The GUER player's bought Ka-137
		//--- gets a CMFlareLauncher + a flare magazine sized by the kill tier (more kills => more flares). NB: A2-OA stock
		//--- has no 30Rnd flare mag, so the floor is 60Rnd (closest available); the count still increases 60->120->240
		//--- by kills as requested. Mags are indexed by WFBE_GUER_VEHICLE_TIER (clamped to the array bounds).
		if (isNil "WFBE_C_GUER_KA137_TYPE") then {WFBE_C_GUER_KA137_TYPE = "Ka137_MG_PMC"};
		if (isNil "WFBE_C_GUER_KA137_FLARE_LAUNCHER") then {WFBE_C_GUER_KA137_FLARE_LAUNCHER = "CMFlareLauncher"};
		if (isNil "WFBE_C_GUER_KA137_FLARE_MAGS") then {WFBE_C_GUER_KA137_FLARE_MAGS = ["60Rnd_CMFlareMagazine","120Rnd_CMFlareMagazine","240Rnd_CMFlareMagazine"]};

	//--- B75 (guer-tech): FOB (forward operating base) system. Each WEST/EAST factory the GUER side destroys grants one
	//--- FOB build token of the matching type. WFBE_GUER_FOB_AVAIL = [barracks, lightFactory, heavyFactory] is the count
	//--- of still-buildable FOBs per type (earned by factory kills, spent when a FOB is built). It gates the depot FOB
	//--- trucks and feeds the RHUD "B n | LF n | HF n" row. Server-authoritative; publicVariable'd (NOT JIP-replayed in
	//--- A2-OA, so isNil-seeded here, re-broadcast by Server_GuerStipend.sqf + pushed to joiners by OnPlayerConnected).
		if (isNil "WFBE_GUER_FOB_AVAIL") then {WFBE_GUER_FOB_AVAIL = [0,0,0]};
		//--- Unlock-notification feed: [seq, text]. The server sets it (seq = the kill count at unlock) + publicVariable's
		//--- it when a kill threshold grants the next reward; the GUER overlay watcher shows it once. Seeded [0,""] so a
		//--- joiner's watcher seeds its seen-seq to 0 and never re-pops an old unlock (publicVariable is not JIP-replayed).
		if (isNil "WFBE_GUER_UNLOCK_MSG") then {WFBE_GUER_UNLOCK_MSG = [0, ""]};
		//--- FOB delivery trucks: [Barracks, Light, Heavy] truck classnames (index-aligned with WFBE_GUER_FOB_AVAIL).
		//--- Map-branched on worldName (the macro is unreliable in standalone-loaded files). These are trucks NOT in the
		//--- GUER player roster; registered with "FOB (...)" labels in Core_GUE.sqf and shown ONLY in the depot when the
		//--- matching FOB token is available. A GUER player buys one, drives it to a valid spot, then "Build FOB ...".
		if (isNil "WFBE_C_GUER_FOB_TRUCKS") then {
			WFBE_C_GUER_FOB_TRUCKS = if (worldName == "Takistan" || worldName == "Zargabad") then {
				["Ural_TK_CIV_EP1","V3S_Open_TK_CIV_EP1","V3S_TK_EP1"]
			} else {
				["Ural_INS","UralOpen_INS","GAZ_Vodnik"]
			};
		};
		if (isNil "WFBE_C_GUER_FOB_STRUCTS") then {WFBE_C_GUER_FOB_STRUCTS = ["Barracks","Light","Heavy"]}; //--- logical structure names per FOB index.
		if (isNil "WFBE_C_GUER_FOB_BUILD_DIST") then {WFBE_C_GUER_FOB_BUILD_DIST = 22};   //--- metres in front of the truck where the FOB factory is placed.
		if (isNil "WFBE_C_GUER_FOB_BUILD_RANGE") then {WFBE_C_GUER_FOB_BUILD_RANGE = 30}; //--- max player->truck distance to use the Build-FOB action.
		if (isNil "WFBE_C_GUER_FOB_TOWN_BLOCK") then {WFBE_C_GUER_FOB_TOWN_BLOCK = 600};  //--- no FOB within this many metres of a WEST/EAST-held town.
		//--- cmdcon43-n2 (2026-07-03) GUER TOWN-CENTER BUY FIX: base-less GUER buys every vehicle from the town-center
		//--- DEPOT (their only vehicle economy). This flag makes Client_GetClosestDepot.sqf resolve the depot for a GUER
		//--- buyer at ANY friendly town center - GUER-held OR neutral (not WEST-held, not EAST-held) - the same idiom
		//--- Client_CanUseTownCenterEASA + the GUER spawn/respawn town pick use, and reads sideID with a -1 default so a
		//--- transiently-unset/contested friendly town is not silently dropped. 1 = widened (fixed, matches the documented
		//--- friendly-town design); 0 = restore the stock strict own-side (sideID == sideID) gate. WEST/EAST are unaffected.
		if (isNil "WFBE_C_GUER_DEPOT_NEUTRAL_BUY") then {WFBE_C_GUER_DEPOT_NEUTRAL_BUY = 1};
		//--- Ray 3B (GR-2026-07-03a) GUER GEAR PROXIMITY: base-less GUER may buy GEAR only near a friendly gear source -
		//--- a friendly town-center DEPOT (GUER-held or neutral; WFBE_CL_FNC_GetClosestDepot), a GUER-held town CAMP/bunker
		//--- (WFBE_CL_FNC_GetClosestCamp), or a deployed GUER FOB BARRACKS (a real resistance BARRACKSTYPE structure, already
		//--- caught by the barracks gearInRange check). Radius = WFBE_C_UNITS_PURCHASE_GEAR_RANGE (150m). Consumed in
		//--- Client\FSM\updateavailableactions.fsm. 1 = gated (the fix, removes the old buy-anywhere GUER behaviour);
		//--- 0 = restore buy-anywhere for GUER (pre-fix). WEST/EAST unaffected (they never hit this GUER-only branch).
		if (isNil "WFBE_C_GUER_GEAR_PROXIMITY") then {WFBE_C_GUER_GEAR_PROXIMITY = 1};
		//--- Shared placement gate (client preview + server authoritative): true if _pos (the world position passed as
		//--- _this, or [_pos, flatRadius] for a factory-specific footprint) is inside an enemy (WEST/EAST) build-restricted
		//--- area - within WFBE_C_GUER_FOB_TOWN_BLOCK of an enemy-HELD town, or inside a WEST/EAST base area. Neutral / GUER-
		//--- held towns are allowed (you can "extend" near a friendly GUE factory). No early-exit inside then{} (A2-OA gotcha)
		//--- - plain flag accumulation.
		WFBE_FNC_GuerFobBlocked = {
			private ["_pos","_flatRadius","_blocked","_tSideID","_eLogik","_eArea","_blockDist","_townList"];
			_pos = _this;
			_flatRadius = missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_RADIUS", 10];
			if ((count _this) > 1 && {(typeName (_this select 0)) == "ARRAY"} && {(typeName (_this select 1)) == "SCALAR"}) then {
				_pos = _this select 0;
				_flatRadius = _this select 1;
			};
			_blocked = false;
			_blockDist = missionNamespace getVariable ["WFBE_C_GUER_FOB_TOWN_BLOCK", 600];
			//--- never on water.
			if (surfaceIsWater _pos) then {_blocked = true};
			//--- qol-polish-pack: reject too-steep ground (FOB factory floats/tilts on slopes; mirrors the AI commander's isFlatEmpty gate).
			if (!_blocked && {(missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_CHECK", 1]) > 0} && {count (_pos isFlatEmpty [_flatRadius, 0, (missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_GRAD", 0.5]), 10, 0, false, objNull]) == 0}) then {_blocked = true};
			//--- enemy-HELD (WEST/EAST) town within the block radius?
			_townList = if (isNil "towns") then {[]} else {towns};
			{
				_tSideID = _x getVariable ["sideID", -1];
				if (((_tSideID == (missionNamespace getVariable ["WFBE_C_WEST_ID", 0])) || (_tSideID == (missionNamespace getVariable ["WFBE_C_EAST_ID", 1]))) && {(_pos distance _x) < _blockDist}) then {_blocked = true};
			} forEach _townList;
			//--- inside a WEST or EAST base area?
			if (!_blocked) then {
				{
					_eLogik = _x Call WFBE_CO_FNC_GetSideLogic;
					if (!isNull _eLogik) then {
						_eArea = [_pos, _eLogik getVariable ["wfbe_basearea", []]] Call WFBE_CO_FNC_GetClosestEntity3;
						if (!isNull _eArea) then {_blocked = true};
					};
				} forEach [west, east];
			};
			_blocked
		};
		//--- Barracks AI cap (per GUER player group): base + one extra slot per N kills, clamped to the A2 12-per-group engine ceiling.
		if (isNil "WFBE_C_GUER_BARRACKS_AI_BASE") then {WFBE_C_GUER_BARRACKS_AI_BASE = 4};
		if (isNil "WFBE_C_GUER_BARRACKS_AI_MAX") then {WFBE_C_GUER_BARRACKS_AI_MAX = 12};
		if (isNil "WFBE_C_GUER_BARRACKS_AI_PER_KILLS") then {WFBE_C_GUER_BARRACKS_AI_PER_KILLS = 20}; //--- 2x-ed (was 10): FOB barracks squad cap grows half as fast (still capped by WFBE_C_GUER_BARRACKS_AI_MAX).

//--- B61 (Ray 2026-06-21): GUER AIR DEFENSE — standalone server loop (Server\Server_GuerAirDef.sqf) keeps a
//--- Ka-137 (or, over a large town under attack, a Mi-24) over ACTIVE GUER-held towns. Default-ON but capped +
//--- self-cleaning so it can't blow up FPS. Only relevant when the GUER playable faction is enabled.
	if (isNil "WFBE_C_GUER_AIRDEF_ENABLE") then {WFBE_C_GUER_AIRDEF_ENABLE = 1};        //--- master switch (set 0 to disable the loop entirely).
	if (isNil "WFBE_C_GUER_AIRDEF_INTERVAL") then {WFBE_C_GUER_AIRDEF_INTERVAL = 120};  //--- seconds between maintain sweeps.
	if (isNil "WFBE_C_GUER_AIRDEF_THREAT_ONLY") then {WFBE_C_GUER_AIRDEF_THREAT_ONLY = 1}; //--- ARMED 2026-07-28 (owner: "make the Ka-137 appear less ... every town activation gets a bunch in the air"): defenders spawn only for towns with a live W/E foe in range - idle activation no longer summons air. 0 = legacy always-spawn.
	if (isNil "WFBE_C_GUER_AIRDEF_MAX") then {WFBE_C_GUER_AIRDEF_MAX = 2};              //--- owner design 2026-07-23 06:03: 4->3 (fewer drones, better payloads; drops to 2 when the GUER ground-raider ships - see wasp-guer-harassment-unit card). Rollback: 4. [Ray-dir 2026-07-24: 3->2 - the drop the 4->3 note anticipated once the GUER ground-raider is in; fewer air-def drones = less spawn churn + fewer AI; rollback 3.]
	if (isNil "WFBE_C_GUER_AIRDEF_AT_CHANCE") then {WFBE_C_GUER_AIRDEF_AT_CHANCE = 0.45}; //--- owner design 2026-07-23 06:03: 0.20->0.45 - fewer drones, each likelier to carry the EASA AT (Konkurs/AT-5) punch. Rollback: 0.20.
	if (isNil "WFBE_C_GUER_AIRDEF_MI24_CHANCE") then {WFBE_C_GUER_AIRDEF_MI24_CHANCE = 0.40}; //--- chance a LARGE GUER town under attack fields a Mi-24 gunship instead. [Ray-dir 2026-07-28: 0.25->0.40 - threat-only spawning cut total air volume, so the events that DO fire bias toward the interesting gunship response; rollback 0.25.]
	if (isNil "WFBE_C_GUER_AIRDEF_AA_CHANCE") then {WFBE_C_GUER_AIRDEF_AA_CHANCE = 0.75}; //--- chance a Ka-137 fields the EASA Igla AA loadout when ENEMY AIR is near the town (counter-air; takes priority over Mi-24/AT roll).
	if (isNil "WFBE_C_GUER_AIRDEF_CLASS_KA") then {WFBE_C_GUER_AIRDEF_CLASS_KA = "Ka137_MG_PMC"}; //--- default light air defender (recon/strike).
	if (isNil "WFBE_C_GUER_AIRDEF_CLASS_MI24") then {WFBE_C_GUER_AIRDEF_CLASS_MI24 = "Mi24_P"};   //--- heavy gunship for large contested towns.
	if (isNil "WFBE_C_GUER_AIRDEF_LIFETIME") then {WFBE_C_GUER_AIRDEF_LIFETIME = 900};  //--- max seconds a defender lives before forced recycle (anti-accumulation).
	if (isNil "WFBE_C_GUER_AIRDEF_QUIET_DESPAWN") then {WFBE_C_GUER_AIRDEF_QUIET_DESPAWN = 300}; //--- despawn after this many seconds with no enemies near the town.
	if (isNil "WFBE_C_GUER_AIRDEF_DESTROYED_COOLDOWN") then {WFBE_C_GUER_AIRDEF_DESTROYED_COOLDOWN = 240}; //--- fix0807b (churn, 2026-08-07): per-town no-spawn window armed after a COMBAT loss (destroyed/crew_dead). Live-measured (61-min wave0807a3 window): 23 destroyed + 28 spawned in one hour, mean survival ~1 maintain sweep (~145s, well under the 300s quiet-despawn grace period), most refilled the SAME sweep the death was noticed - the town-side half of the fix in Server_GuerAirDef.sqf. Default ~2x interval so a killed town forgoes one extra sweep before refilling. Rollback: 0 (legacy immediate-refill).
	if (isNil "WFBE_C_GUER_AIRDEF_LARGE_SV") then {WFBE_C_GUER_AIRDEF_LARGE_SV = 2500}; //--- maxSupplyValue at/above which a town counts as LARGE (Mi-24 eligible); town_type Large/Huge also qualifies.
	if (isNil "WFBE_C_GUER_AIRDEF_HEIGHT") then {WFBE_C_GUER_AIRDEF_HEIGHT = 120};      //--- flyInHeight for spawned GUER air.
	if (isNil "WFBE_C_GUER_AIRDEF_FLYAWAY") then {WFBE_C_GUER_AIRDEF_FLYAWAY = 1};      //--- NEW (Grok idea #12, default 0): on a "quiet" recall, fly the defender ~2km away from the town + climb, THEN despawn, instead of an instant mid-skyline delete. Bounded by FLYAWAY_TIMEOUT.
	if (isNil "WFBE_C_GUER_AIRDEF_FLYAWAY_TIMEOUT") then {WFBE_C_GUER_AIRDEF_FLYAWAY_TIMEOUT = 60}; //--- max seconds to wait for the fly-away (or >1500m clear) before despawning anyway; hard-clamped to <=60 in-code so the wait can never be unbounded.
	if (isNil "WFBE_C_GUER_GROUND_QRF") then {WFBE_C_GUER_GROUND_QRF = 1};              //--- ARMED (owner ruling 2026-07-21: everything flags on). E3 roster-phase-2: GUER ground QRF.
	if (isNil "WFBE_C_GUER_HUEY_QRF") then {WFBE_C_GUER_HUEY_QRF = 1};              //--- ARMED (owner ruling 2026-07-21: everything flags on). E5 roster-phase-2: late-game GUER Huey QRF delivery bird.
	if (isNil "WFBE_C_TOWN_TYPE_OVERLAYS") then {WFBE_C_TOWN_TYPE_OVERLAYS = 1};          //--- ARMED (owner ruling 2026-07-21: everything flags on). roster-phase-2: airfield/high-SV garrison flavor overlays.

//--- KA-137 SWARM ROLL (cmdcon42, Ray 2026-07-02): when the AIRDEF loop fields a COMBAT Ka-137 (recon-MG / AT / AA,
//--- NOT the paradrop bird or the Mi-24), roll for it to be MORE THAN ONE — extras created INTO THE SAME group so
//--- they formation-fly as a drone flock. Extras COUNT toward WFBE_C_GUER_AIRDEF_MAX; the roll is skipped once the
//--- cap is reached, so a swarm never exceeds the air budget. Only relevant when the GUER AIRDEF loop is enabled.
	if (isNil "WFBE_C_GUER_KA137_SWARM") then {WFBE_C_GUER_KA137_SWARM = 1};                //--- master switch (1 = swarm rolls enabled, 0 = single drone only).
	if (isNil "WFBE_C_GUER_KA137_SWARM_CHANCE") then {WFBE_C_GUER_KA137_SWARM_CHANCE = 0.25}; //--- chance a combat Ka-137 spawn also fields a 2nd drone in the same group. [Ray-dir 2026-07-28: 0.15->0.25 - the threat-only spawn gate removed the idle-town churn behind the 07-24 cut AND finally leaves the cap headroom the roll needs; a pair is the visible "swarm". Rollback 0.15. Prior: 2026-07-24 CHURN 0.25->0.15.]
	if (isNil "WFBE_C_GUER_KA137_SWARM_CHANCE3") then {WFBE_C_GUER_KA137_SWARM_CHANCE3 = 0.10}; //--- chance (only if the 2nd rolled) for a 3rd drone in the same group. [Ray-dir 2026-07-24 CHURN: 0.15->0.10 (fewer 3-drone flocks); rollback 0.15.]

//--- KA-137 FLARE STOCK (cmdcon42 item2, Ray 2026-07-02; retuned 5-20 same day): AI-spawned Ka-137s (leader +
//--- swarm extras) get a chance-based MIN-MAX countermeasure budget (variance-nerf vs the flat CM_Set default 32).
//--- Build86 flipped WFBE_C_MODULE_AUTO_CM_OA ON; that auto-CM module (Client\Module\CM\CM_AutoCM_OA.sqf) consumes
//--- an INTEGER "FlareCount" vehicle variable (one FlareCountermeasure decoy per point), so the rolled stock is
//--- expressed EXACTLY as that integer — no magazine rounding. Roll = MIN + floor(random (MAX - MIN + 1)); MAX is
//--- clamped up to MIN at the consumer so a bad config can never make the roll negative. The hull also gets the
//--- manual CMFlareLauncher + a 60Rnd flare mag (player-Ka-137 idiom). Default-ON; set FLARES 0 to disable.
	if (isNil "WFBE_C_GUER_KA137_FLARES") then {WFBE_C_GUER_KA137_FLARES = 1};              //--- master switch (1 = roll a MIN-MAX auto-CM flare stock on AI Ka-137s, 0 = none).
	if (isNil "WFBE_C_GUER_KA137_FLARES_MIN") then {WFBE_C_GUER_KA137_FLARES_MIN = 5};      //--- lower bound of the rolled flare stock (inclusive).
	if (isNil "WFBE_C_GUER_KA137_FLARES_MAX") then {WFBE_C_GUER_KA137_FLARES_MAX = 20};     //--- upper bound of the rolled flare stock (inclusive; clamped up to MIN if misconfigured below it).
	if (isNil "WFBE_C_GUER_KA137_FLARE_TIER_SCALE") then {WFBE_C_GUER_KA137_FLARE_TIER_SCALE = 0}; //--- Feature gate: 0 = flat MIN-MAX (byte-identical to HEAD); >0 = scale the AI Ka-137 flare stock by GUER kill-tier (delivers the RequestOnUnitKilled "flares up to 120/240" milestone copy).
	if (isNil "WFBE_C_GUER_KA137_FLARE_TIERMIN") then {WFBE_C_GUER_KA137_FLARE_TIERMIN = [5,30,60,60]};    //--- Per-tier (0..3) flare-stock lower bound; consulted ONLY when TIER_SCALE>0. Tier 0 = base MIN (5) so tier-0 hulls never change.
	if (isNil "WFBE_C_GUER_KA137_FLARE_TIERMAX") then {WFBE_C_GUER_KA137_FLARE_TIERMAX = [20,120,240,240]}; //--- Per-tier (0..3) flare-stock upper bound; consulted ONLY when TIER_SCALE>0. t1=120/t2=240 match the milestone copy.
	if (isNil "WFBE_C_KA137_HP_MULT") then {WFBE_C_KA137_HP_MULT = 3}; //--- cmdcon45 (owner): Ka-137 incoming-damage divisor = effective HP multiplier on all parts (1 = vanilla).

//--- Day/night cycles.
	// Marty: Defaults used when mission parameters do not provide the accelerated day/night settings.
	WFBE_DAYNIGHT_ENABLED = 0; //--- Night mode removed (Ray 2026-06-18): hard-force the accelerated day/night cycle OFF (permanent daylight). SET (not isNil-guarded) so a stale lobby param / saved profile can't re-enable it; every cycle site gates on ==1.
	// Marty: Match the mission parameter's 180-minute daytime default.
	if (isNil "WFBE_DAY_DURATION") then {WFBE_DAY_DURATION = 180};    //--- Real-life duration of daytime in minutes
	if (isNil "WFBE_NIGHT_DURATION") then {WFBE_NIGHT_DURATION = 30}; //--- Real-life duration of nighttime in minutes
	// Marty: Hybrid day/night sync tuning. Clients animate with small local skipTime steps; setDate is reserved for JIP and exceptional hard corrections.
	if (isNil "WFBE_DAYNIGHT_CLIENT_TICK") then {WFBE_DAYNIGHT_CLIENT_TICK = 0.1}; //--- Seconds between each small client-side time step.
	if (isNil "WFBE_DAYNIGHT_SERVER_SYNC_INTERVAL") then {WFBE_DAYNIGHT_SERVER_SYNC_INTERVAL = 30}; //--- Seconds between authoritative server date broadcasts.
	if (isNil "WFBE_DAYNIGHT_CLIENT_MAX_CORRECTION") then {WFBE_DAYNIGHT_CLIENT_MAX_CORRECTION = 0.0005}; //--- Max drift correction in game hours per client tick.
	if (isNil "WFBE_DAYNIGHT_CLIENT_HARD_SYNC_DRIFT") then {WFBE_DAYNIGHT_CLIENT_HARD_SYNC_DRIFT = 6}; //--- Drift in game hours before one exceptional setDate correction.
	// Marty: Visual phase boundaries are estimated for Chernarus on 28 June, the effective mission date after month override.
	WFBE_DAYNIGHT_FORCED_MONTH = 6; //--- Force June when the accelerated cycle is enabled.
	WFBE_DAYNIGHT_FORCED_DAY = 28; //--- Force the 28th day when the accelerated cycle is enabled.
	WFBE_DAYNIGHT_DAWN_START = 4; //--- Dawn starts around 04:00.
	WFBE_DAYNIGHT_DAWN_END = 5; //--- Full daylight starts around 05:00.
	WFBE_DAYNIGHT_DUSK_START = 20.5; //--- Dusk starts around 20:30.
	WFBE_DAYNIGHT_DUSK_END = 21.5; //--- Night starts around 21:30.
	WFBE_DAYNIGHT_TWILIGHT_WEIGHT = 3; //--- Dawn/dusk game hours take x times longer than full daylight game hours.
//--- Permanent Daytime feature flag (fable/permanent-daytime, Build84).
//--- 0 (default) = inert; flag-off leaves the mission byte-identical to HEAD.
//--- >0 = force-enable the WFBE_C_ENVIRONMENT_DAYLIGHT_CLAMP loop regardless of its own value,
//---     keeping the clock inside the daylight band (DAYLIGHT_START -> DAYLIGHT_END).
//--- When WFBE_DAYNIGHT_ENABLED==1 (accelerated cycle ON), PERMANENT_DAY is silently ignored.
	if (isNil "WFBE_C_PERMANENT_DAY") then {WFBE_C_PERMANENT_DAY = 0}; //--- Permanent daytime; default 0 (off).

//--- AI.
	if (isNil "WFBE_C_AI_COMMANDER_ENABLED") then {WFBE_C_AI_COMMANDER_ENABLED = 1}; //--- Enable or disable the AI Commanders.
	//--- AI COMMANDER LOCK: when 1, AI retains full command regardless of who occupies the slot.
	//--- Protects eval/night sessions from accidental human takeover. Default 0 = normal play.
	if (isNil "WFBE_C_AI_COMMANDER_LOCK") then {WFBE_C_AI_COMMANDER_LOCK = 0}; //--- B67 (Ray 2026-06-21): 1->0 to ENABLE the hybrid commander feature (#5). Players can now vote out the AI commander; the AI then keeps founding/refilling its teams (assist mode) while the player builds + can re-task all teams. Set back to 1 to relock (AI always commands - the eval/night-soak posture).
	if (isNil "WFBE_C_AI_COMMANDER_GARRISON") then {WFBE_C_AI_COMMANDER_GARRISON = 0}; //--- AssignTowns base-garrison opt-in. 0 keeps all AI teams on the front.
	if (isNil "WFBE_C_AICOM_ALWAYS_OFFENSE") then {WFBE_C_AICOM_ALWAYS_OFFENSE = 1}; //--- Owner ruling 2026-07-21: AICOM stays on offense; 0 restores legacy garrison/last-stand conversions, while active-attack relief remains available.
	if (isNil "WFBE_C_AICOM_PUBLIC_STATE_SYNC") then {WFBE_C_AICOM_PUBLIC_STATE_SYNC = 1}; //--- armed 2026-07-27 owner go. Broadcasts side-logic AICOM state writes (wfbe_aicom_funds/running) for HC readers.
	if (isNil "WFBE_C_AICOM_TELEPORT_ORDER_FLUSH") then {WFBE_C_AICOM_TELEPORT_ORDER_FLUSH = 1}; //--- Lane 377: after teleport-equivalent relocation, publish a fresh HC order from the new position.
	//--- C3 consensus telemetry: periodic FIELDSPLIT/CAPTURE_TRACE diagnostics are opt-in and behavior-neutral.
	if (isNil "WFBE_C_AICOM_C3_TELEMETRY") then {WFBE_C_AICOM_C3_TELEMETRY = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on).
	//--- ACTIVE-TOWN BUDGET: max concurrently active towns. FPS lever; 12 for the legacy-vs-next A/B (Steff 2026-06-13).
	if (isNil "WFBE_C_TOWNS_ACTIVE_MAX") then {WFBE_C_TOWNS_ACTIVE_MAX = 12}; //--- punchy-AICOM (Ray 2026-06-18): KEEP 12 for the next test - concentration comes from SPEARHEAD_TOWNS_MAX=1 + CONCENTRATION=4 (mass on one town of the full 12-town front), NOT from shrinking the active set.
	if (isNil "WFBE_C_TOWNS_STARTUP_SLEEP") then {WFBE_C_TOWNS_STARTUP_SLEEP = 0}; //--- Fleet lane 115: optional startup pacing for server_town_ai's two town init passes. 0 = legacy 0.01s; try 0.05-0.10 to soften large-map startup spikes.
	//--- GUER GROUP CAP: hard ceiling on total resistance groups. Bounds runaway GUER growth toward the engine's ~144-groups/side
	//--- limit over long stalled AI-vs-AI runs (garrisons + W9 uprising + side-patrols, none of which had a global cap).
	//--- 90 is far above any single-front GUER force, well under the 144 ceiling; raise to 999 for an instant rollback.
	if (isNil "WFBE_C_GUER_GROUPS_MAX") then {WFBE_C_GUER_GROUPS_MAX = 40}; //--- 80->40 (owner doctrine ruling 2026-07-23: standing GUER baseline halved; GUER Director V2 dynamic layer now carries reinforcement above baseline). Was 60->80 (Ray 2026-06-15); raise to 999 for instant rollback.
	if (isNil "WFBE_C_AI_MAX") then {WFBE_C_AI_MAX = 12}; //--- Max AI allowed on each AI groups.
	if (isNil "WFBE_C_AI_DELEGATION") then {WFBE_C_AI_DELEGATION = 0}; //--- Enable AI delegation (0: Disabled, 1: creation of ai on the client, 2: Headless Client).
	if (isNil "WFBE_C_STATIC_DEF_COMBAT") then {WFBE_C_STATIC_DEF_COMBAT = 1}; //--- D10#4: 1 = manned static town-defence gunners get an explicit combat posture (setBehaviour AWARE + setCombatMode RED) so they engage; 0 = legacy passive. AWARE (not COMBAT) keeps them on the gun. Balance change (defended towns harder); ships inert.
	if (isNil "WFBE_C_AI_TEAMS_ENABLED") then {WFBE_C_AI_TEAMS_ENABLED = 1}; //--- Enable or disable the AI Teams.
	if (isNil "WFBE_C_AI_TEAMS_JIP_PRESERVE") then {WFBE_C_AI_TEAMS_JIP_PRESERVE = 1}; //--- Keep the AI Teams units on JIP.
	WFBE_C_AI_COMMANDER_MOVE_INTERVALS = 3600;
	WFBE_C_AI_COMMANDER_SUPPLY_TRUCKS_MAX = 5;
	//--- AI Commander revival (feat/ai-commander).
	WFBE_C_AI_COMMANDER_TOTAL_AI_MAX = 140;    //--- Symmetric per-side AI ceiling; tiered cap array below is authoritative for commander founding/produce.
	WFBE_C_AI_COMMANDER_USE_ARC_APPROACH = 1;  //--- 1: SetTownAttackPath arc approach; 0: simple AIMoveTo fallback.
	WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL = 300; //--- B67 (Ray 2026-06-21): 120->300s. Tech pacing: ~37-entry AI research order x 300s ~= 185 min to walk the full tree (was ~20-30 min). Dominant lever for the "full tech over ~180 min" decision; early/cheap tiers still start in the first ~10-15 min off the untouched bootstrap supply. Rollback: 120.
	WFBE_C_AI_COMMANDER_TOWN_INTERVAL = 120;
	WFBE_C_AI_COMMANDER_PRODUCE_INTERVAL = 45;
	WFBE_C_AI_COMMANDER_TYPES_INTERVAL = 30;
	WFBE_C_AI_COMMANDER_TICK = 15;             //--- Supervisor base tick (s); how often the order-executor runs (hybrid responsiveness).
	WFBE_C_AI_COMMANDER_BASE_INTERVAL = 60;    //--- V0.2: base worker cadence (HQ deploy -> doctrine build order -> defenses).
	WFBE_C_AI_COMMANDER_TEAMS_INTERVAL = 90;   //--- V0.2: team-founding cadence.
	WFBE_C_AI_COMMANDER_TEAMS_TARGET = 2;      //--- B36 (Ray 2026-06-15): HALVED 4->2 to cut HC saturation + group count. With MAX_EXTRA 1 the founding cap is 3 teams/side (was 6); teams stay big via AI_MAX 12. Rollback: 4.
	//--- B36 (Ray 2026-06-15): seconds with NO human commander (from start, re-armed when a human leaves) before the AI builds/spends.
	WFBE_C_AI_COMMANDER_BUILD_GRACE = 300;
	WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA = 0;   //--- punchy-AICOM (Ray 2026-06-17): 1->0 to pin exactly 10 teams at low pop (base PC_LOW=10, no funds-extra). Rollback: 1.
	WFBE_C_AI_COMMANDER_DEFENSES_MAX = 4;      //--- V0.2: manned base statics the AI places around its HQ.
	//--- B36.1 (Ray 2026-06-15): DYNAMIC TEAM SCALING by live HUMAN player count (HCs excluded). The team
	//--- count is the dominant server-FPS lever, so the AI commander's founding target scales INVERSELY
	//--- with population: more players = more server pressure = FEWER HQ squads; low pop is efficient +
	//--- boring, so flood it with many more AI teams. Buckets 0-2 / 3-5 / 6-9 / 10+. The 10+ value matches
	//--- the old static target (2) = no high-pop regression. Consumed by AI_Commander_Teams.sqf.
	WFBE_C_AICOM_TEAMS_PC_LOW  = 17;           //--- Ray 2026-07-26: 10 -> 17 so effective = 17 + DELTA(-1) = 16 teams/side at low pop (owner: 16 each side). Low-population target before funds/engine caps; shared by WEST/EAST.
	WFBE_C_AICOM_TEAMS_PC_MID  = 17;           //--- Ray 2026-07-26: 7 -> 17 -> effective 16 at 3-5 players (owner: 16 each side). HIGH/FULL deliberately NOT raised - 16 teams/side on a populated server would sink FPS. Prior Build83: ~20% trim, 8->7.
	WFBE_C_AICOM_TEAMS_PC_HIGH = 4;            //--- Build83: ~20% trim, 5->4.
	WFBE_C_AICOM_TEAMS_PC_FULL = 3;            //--- rollback the whole curve: set all four to 2.
	WFBE_C_AICOM_TEAMS_HARD_CAP = 12;          //--- Ray 2026-07-28: 16 -> 12 max teams/side ALL MAPS (owner; 6h m0727h session showed the 16-team envelope grinding server+HC memory into the 32-bit wall by hour 4 - fps 47->14 at constant AI). Prior Ray 2026-07-26: 10 -> 16 max teams/side ALL MAPS (owner). NOTE the PC curve still gates the real target (PC_LOW 9 - delta 1 = 8 effective); this only lifts the ceiling above it. Prior Ray 2026-06-29: 8 -> 10 max teams/side (Ray: low-pop fielding; reverts the 2026-06-28 10->8). [prior B752 2026-06-25: back to 8 max teams (13 over-throttled the per-side TOTAL_AI cap + fed the hoard in the 12h TK soak). Shared CH+TK via LoadoutManager. HARD ceiling on the AI-commander founding target regardless of the PC curve + banking valve (was fielding ~15 at low pop = base 12 + valve 3). Clamped in AI_Commander_Teams.sqf. Rollback: 99 (effectively off).
	//--- cmdcon42-k (Ray 2026-07-02): DROP N teams off EACH AI commander's BASE founding target on BOTH maps (the new
	//--- dynamic transport/patrol/swarm systems in Build 87 add per-team AI; HQ teams now hand the server too much AI to
	//--- handle). DELTA is applied to the PC-scaled base team target (WFBE_C_AICOM_TEAMS_PC_* after the curve overwrites
	//--- WFBE_C_AI_COMMANDER_TEAMS_TARGET) in AI_Commander_Teams.sqf, so the funds-extra + surge (+2) ride ON TOP of the
	//--- REDUCED base, and the hard cap (above) still clamps the ceiling. FLOOR guards a config accident from zeroing the
	//--- army (a side that founds 0 teams loses this fork by walkover). DELTA 0 => EXACT current behaviour (easy revert).
	WFBE_C_AICOM_TEAMS_DELTA = -1;             //--- cmdcon42-k: teams dropped from the base founding target per AI commander (both maps). 0 = no change (rollback).
	WFBE_C_AICOM_TEAMS_FLOOR = 3;              //--- cmdcon42-k: minimum effective base target after the delta - never let a config accident starve the army below this.
	WFBE_C_AICOM_DISBAND_SAFE_DIST = 1200;     //--- REPURPOSED (owner ruling 2026-07-22): disband paths no longer read this (vetoes removed, destructive retire); still gates the AI_Commander_MHQReloc teleport-step stealth check.
	WFBE_C_AICOM_INCOME_PC_BONUS = 0.06;       //--- B36.1 income: +6% AI-commander CASH income per human player UNDER the REF pop (INVERTED - highest at LOW pop to fund the team-curve flood; 0 disables -> flat INCOME_MULT).
	WFBE_C_AICOM_INCOME_PC_REF = 10;           //--- B36.1: player count at/above which the inverted income boost is ZERO (base income). Below it, AI-commander cash income rises +BONUS per player under REF. Mirrors the team curve's high-pop end (10+ = 2 teams).
	//--- B37 BANKING VALVE (Ray 2026-06-16): convert low-pop banked funds into squads + a gentle income trim. Toggle to A/B.
	WFBE_C_AICOM_BANKING_VALVE = 1;            //--- B37: 1=on (low-pop funds->squads valve + income trim); 0=B36.1 behaviour.
	WFBE_C_AICOM_TEAMS_LOWPOP_EXTRA = 4;       //--- B74 (Ray 2026-06-22): 0->4 re-open the banking valve so the hoarded ~1.3M funds convert into a FEW more teams (kept small on purpose - 'fewer-but-stronger' dominates via the B74 cost-weighted picker). Rollback: 0. (B74.2: superseded by WFBE_C_AICOM_LOWPOP_EXTRA_BY_TIER below; this stays as the non-tiered fallback.)
	//--- B74.2 UNIFIED POP-TIER (Ray 2026-06-23, "Lively"). ONE tier 0=LOW(0-2)/1=MID(3-5)/2=HIGH(6-9)/3=FULL(10+) is
	//--- published ~every 90s from AI_Commander_Teams.sqf (where the human count is already computed) into WFBE_PopTier
	//--- (publicVariable so clients read it live). Every AI population indexes a 4-element BY_TIER array so total AI FALLS
	//--- as humans rise: low pop = more action, high pop = fewer-but-stronger (b74 cost-weighted picker). Base/HQ defenses
	//--- are deliberately NOT tiered (Ray 2026-06-23). Numbers sized to the MEASURED test-box FPS curve (playable knee ~450-470 units).
	if (isNil "WFBE_PopTier") then {WFBE_PopTier = 0};        //--- 0=LOW; default until the first server publish
	//--- ===== TEST HARNESS (all default-off; never affects live play) =====
	if (isNil "WFBE_C_TEST_POPTIER_PIN") then {WFBE_C_TEST_POPTIER_PIN = -1}; //--- Test-only scale pin: forces the effective human count (drives WFBE_PopTier + the AI-team curve) so an EMPTY box spawns full-scale load for stress tests. -1 = off; e.g. 12 = force FULL tier. Additive real spawns (NOT sim-gating/antistack).
	if (isNil "WFBE_C_TEST_TEAM_CAP") then {WFBE_C_TEST_TEAM_CAP = -1}; //--- Test-only fast-bench team cap: hard-clamps each AI commander's founding target to at most N teams/side, for "2 teams + 1 town" minutes-fast dev loops (pairs with WFBE_C_TEST_POPTIER_PIN + WF_Debug). Read next to the poptier pin; applied as the FINAL ceiling in AI_Commander_Teams.sqf (after the PC curve/delta/banking-valve/hard-cap/econ-surge/veteran-slot, right before the founding gate) so it composes with every existing clamp instead of racing them. -1 = off (no effect on live play).
	if (isNil "WFBE_C_TEST_TOWN_CAP") then {WFBE_C_TEST_TOWN_CAP = -1}; //--- Test-only fast-bench town cap: when >0, keeps only the N towns nearest EACH side's start position ACTIVE (Server\Init\Init_Towns.sqf) and marks every other town wfbe_inactive - the SAME "town doesn't exist for gameplay" mechanism Common\Init\Init_Town.sqf already uses for TownTemplate-disabled towns, so town-AI garrison/supply/patrol loops only run against a tiny map slice without deleting any town object/camp/depot model. -1/0 = off (no effect on live play).
	if (isNil "WFBE_C_BOMB_PROBE") then {WFBE_C_BOMB_PROBE = 0}; //--- TEST HARNESS - never arm on the live box. Stage-A bomb-release/turret-vs-hull verification harness (Server\Functions\Server_BombProbe.sqf, docs\plans\2026-07-28-bomb-stage-a-runbook.md). Armed only, spawns 5 throwaway AI-crewed hulls offshore, applies the EASA-AI kit table, orders reveal/doTarget/doFire at a spawned ground cluster, logs BOMBPROBE|v1|* RPT evidence, then deletes everything it created. 0 = off (no effect on live play, byte-identical).
	if (isNil "WFBE_C_BOMB_PROBE_ORIGIN") then {WFBE_C_BOMB_PROBE_ORIGIN = [500,500,300]}; //--- TEST HARNESS - never arm on the live box. Fixed offshore/corner spawn position for Server_BombProbe.sqf (best-effort SW-corner guess on Chernarus - VERIFY clear terrain/water on your test box before arming WFBE_C_BOMB_PROBE and override this constant if it is not.
	WFBE_C_TOTAL_AI_MAX_BY_TIER       = [180,170,150,120];     //--- Ray 2026-07-26: 250 max AI/side ALL MAPS (owner) - was [140,130,100,80]. 4-HC box soak: the 16-team target needs ~128 units/side, the old ceiling refused founding at sideAI>cap (FOUND_SKIP reason=side_ai_cap). Rollback: [140,130,100,80]. per-side commander-AI ceiling (founding gate + AI_Commander_Produce)
	WFBE_C_AICOM_LOWPOP_EXTRA_BY_TIER = [3,2,0,0];            //--- funds-valve extra teams (valve only fires pop<=5 = LOW/MID)
	WFBE_C_TOWNS_DEFENDER_BY_TIER     = [2,2,2,1];            //--- town garrison difficulty -> COEF (Medium/Medium/Medium/Light)
	WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER   = [12,12,10,8];         //--- concurrently-active-towns cap (the single largest AI slice)
	WFBE_C_SIDE_PATROLS_MAX_BY_TIER   = [3,3,3,2];            //--- Build83 (Ray 2026-07-01): +1 WEST/EAST side-patrol cap per tier ([2,2,2,1]->[3,3,3,2]). Effective = min(this, patrol level).
	WFBE_C_PLAYERS_AI_MAX_BY_TIER     = [16,14,12,10];        //--- per-player AI buy-cap (recruit cap; never deletes an existing squad)
	WFBE_C_AICOM_INCOME_PC_BONUS_VALVE = 0.045; //--- B37: gentler low-pop income boost when the valve is on (vs 0.06), so more-squads does not over-bank.
	WFBE_C_AICOM_INCOME_MULT_MAX = 4.0;        //--- B67 (Ray 2026-06-21): 3.0->4.0 - lift the town-cash multiplier ceiling so the low-pop inverted bonus is not clipped (keeps near-empty-server PvE well-funded). CASH only. hard ceiling on the scaled commander income multiplier (packed-server runaway guard).
	if (isNil "WFBE_C_AICOM_AIR_MIN_TOWNS") then {WFBE_C_AICOM_AIR_MIN_TOWNS = 3}; //--- B66: 4->3 - bring air online a town sooner. Aircraft are deferred until the AI holds this many towns (it flies poorly; air is a late, established-only asset). 0 = no gate.
	if (isNil "WFBE_C_AIR_ATTACK_GUNNER") then {WFBE_C_AIR_ATTACK_GUNNER = 1}; //--- ARMED (owner pick, 2026-07-17; was default-0/soak-gated). Mounts a GUNNER on AICOM attack helicopters (AI_Commander_AirResp/Wildcard W13) so AH64/AH1Z/Mi24 actually fire their gunner-seat armament (Hellfire/TOW/Vikhr) instead of flying pilot-only + never engaging. Mirrors the shipped B62 gunner-mount (Server_GuerAirDef.sqf:378-387). Gunner mounted only if the airframe has an empty gunner seat. Set 0 to revert to the pre-arm, pilot-only, byte-identical behavior.
	if (isNil "WFBE_C_AICOM_AIR_COUNCIL_PACK") then {WFBE_C_AICOM_AIR_COUNCIL_PACK = 0}; //--- B757 roster council air templates: 0 = registered but dark; owner can arm the additive air pack explicitly.
	if (isNil "WFBE_C_AICOM_WEST_JETS") then {WFBE_C_AICOM_WEST_JETS = 0}; //--- OWNER-GATED default 0. Chernarus WEST (US_Camo -> Squad_USMC.sqf) has zero fixed-wing team templates -> AICOM cannot found a jet team for WEST (research finding 2026-07-28, "WEST cannot found a fixed-wing bomber on Chernarus"). Arms two Plane templates in Squad_USMC.sqf (A-10 CAS, AV-8B Strike) modelled on Squad_OA_US.sqf; flag off = roster byte-identical to HEAD. Admission still flows through the existing AI_Commander_Teams.sqf / AI_Commander_AssignTypes.sqf isKindOf-Plane + airfield + jet time-ramp gates, unchanged.
	//--- === Build 83 / cmdcon35 constants (claude-gaming 2026-07-01) ===
	if (isNil "WFBE_C_AICOM_HQ_NUDGE_MAX_R") then {WFBE_C_AICOM_HQ_NUDGE_MAX_R = 200};  //--- AI HQ off-road nudge: max expanding-ring radius (m) before using best off-road candidate.
	if (isNil "WFBE_C_AICOM_HQ_NUDGE_STEP") then {WFBE_C_AICOM_HQ_NUDGE_STEP = 25};     //--- AI HQ off-road nudge: ring radius growth per step (m).
	if (isNil "WFBE_C_GUER_AIRDEF_DROP_CHANCE") then {WFBE_C_GUER_AIRDEF_DROP_CHANCE = 0.25}; //--- Ka-137 cargo/paradrop roll when a GUER town is under GROUND attack. [Ray-dir 2026-07-28: 0.18->0.25 - same "fewer but more interesting" retune as the Mi-24 chance; rollback 0.18.]
	if (isNil "WFBE_C_GUER_AIRDEF_DROP_COUNT") then {WFBE_C_GUER_AIRDEF_DROP_COUNT = 5};      //--- troopers per Ka-137 paradrop stick.
	if (isNil "WFBE_C_GUER_AIRDEF_DROP_MAX") then {WFBE_C_GUER_AIRDEF_DROP_MAX = 2};          //--- global alive cap on paradropped GUER squads (anti-spam).
	if (isNil "WFBE_C_KA137_REWARD_COEF") then {WFBE_C_KA137_REWARD_COEF = 0.4};              //--- Build83 (Ray 2026-07-01): Ka-137 kill/salvage reward -60%. Applied gated on Ka137_MG_PMC in bounty + salvage paths.
	if (isNil "WFBE_C_AICOM_GROUP_CAP") then {WFBE_C_AICOM_GROUP_CAP = 110};               //--- Build83: tunable AICOM founding group-cap (engine ~144/side safety headroom); 110 = prior hardcoded value.
	if (isNil "WFBE_C_AICOM_FOOT_ROUTE_DIST") then {WFBE_C_AICOM_FOOT_ROUTE_DIST = 700};   //--- Build83 movement: min leg (m) for a pure-infantry team to road-march the wfbe_aicom_route chain vs a single cross-country MOVE.
	if (isNil "WFBE_C_AICOM_ROUTE_COMPLETION") then {WFBE_C_AICOM_ROUTE_COMPLETION = 70};  //--- Build83 movement: intermediate road-node MOVE completionRadius (m); wider = no stop-start. Final dest node stays tight (30).
	//--- === Build 84 / cmdcon36 constants (claude-gaming 2026-07-01) ===
	if (isNil "WFBE_C_AICOM_ROAD_STANDOFF") then {WFBE_C_AICOM_ROAD_STANDOFF = if (worldName == "Takistan") then {40} else {24}};  //--- Build84 (backlog#1): perpendicular metres AI spawn-factories/ServicePoint sit off a road (was hardcoded 16). Wider on open Takistan so bases stop hugging the highway; tighter on hedged Chernarus. Set 16 to restore old behaviour.
	if (isNil "WFBE_C_AICOM_ROUTE_HOP_SPACING") then {WFBE_C_AICOM_ROUTE_HOP_SPACING = 600};  //--- Build84: target spacing (m) between road-march nodes (~1 node per this distance) so long legs stay on roads. Lower = denser chain.
	if (isNil "WFBE_C_AICOM_ROUTE_HOP_MAX") then {WFBE_C_AICOM_ROUTE_HOP_MAX = 24};           //--- Build84: hard cap on road-march node count per leg (bounds the builder loop on very long legs).
	if (isNil "WFBE_C_AICOM_ROUTE_SNAP_RADIUS") then {WFBE_C_AICOM_ROUTE_SNAP_RADIUS = 250};  //--- Build84: nearRoads snap radius (m) for an intermediate road-march node (was 120); wider so long-leg hops find a road instead of being dropped into a beeline gap.
	if (isNil "WFBE_C_AICOM_LANE_OFFSET") then {WFBE_C_AICOM_LANE_OFFSET = if (worldName == "Takistan") then {60} else {120}};  //--- cmdcon42-h: max perpendicular lane-jitter amplitude (m) multiplied by the team's persistent wfbe_aicom_lanejit (-1..1) in WFBE_CO_FNC_BuildRoadRoute, so concentrated teams diverge into their own lane mid-route. TK-branch: on Takistan's narrow switchback valley roads a 120m sideways guess leaves the road entirely (the snap then misses -> cross-country beeline over a ridge), so TK halves it to 60m. isNil guard keeps any pre-set global as the override.
	if (isNil "WFBE_C_AICOM_WAVE_STAGGER") then {WFBE_C_AICOM_WAVE_STAGGER = 1};           //--- feat/aicom-wave-stagger (Grok idea #3, 2026-07-25): 0=off (byte-identical - orders re-issue immediately as before). 1=on: when a 2nd+ team converges on the SAME spearhead/assault town in one AssignTowns pass, delay that team's order re-issue (HC order broadcast / direct AIMoveTo) by a deterministic per-team offset so convoys stagger their arrival instead of piling up on one road. Reuses the existing persistent wfbe_aicom_lanejit var (same seed idiom as WFBE_C_AICOM_LANE_OFFSET above) for the offset - no new per-team state. Same value on all 3 maps (not map-tuned like LANE_OFFSET).
	if (isNil "WFBE_C_AICOM_WAVE_STAGGER_MIN") then {WFBE_C_AICOM_WAVE_STAGGER_MIN = 30}; //--- feat/aicom-wave-stagger: min seconds a converging team's re-issue is delayed (only used when WFBE_C_AICOM_WAVE_STAGGER=1).
	if (isNil "WFBE_C_AICOM_WAVE_STAGGER_MAX") then {WFBE_C_AICOM_WAVE_STAGGER_MAX = 90}; //--- feat/aicom-wave-stagger: max seconds a converging team's re-issue is delayed; both bounds sit comfortably inside the WFBE_C_AICOM_ASSAULT_SLACK (120s) budget so the assault timeout clock (which starts synchronously, unaffected by this delay) never false-positives from the stagger alone.
	if (isNil "WFBE_C_AICOM_GRADE_DWELL") then {WFBE_C_AICOM_GRADE_DWELL = 6};             //--- Build83 movement: seconds a steep grade must persist before the careful-gear governor downshifts a convoy to LIMITED (anti-pulse). Stuck-strike LIMITED stays immediate.
	if (isNil "WFBE_C_AICOM_ORDER_DELTA") then {WFBE_C_AICOM_ORDER_DELTA = 80};            //--- Build83 movement: console/HC order re-issue distance gate (m) - nearby re-clicks don't tear the march.
	if (isNil "WFBE_C_AICOM_ORDER_MININT") then {WFBE_C_AICOM_ORDER_MININT = 6};           //--- Build83 movement: per-team min seconds between order re-lays (debounce).
	if (isNil "WFBE_C_AICOM_DIRECT_COOLDOWN") then {WFBE_C_AICOM_DIRECT_COOLDOWN = 1.5};   //--- Build83 console: short cooldown for DIRECT map-click Move/Defend/Patrol (local setVariable) - separate from the 8s RequestSpecial brain-send gate so re-targeting feels responsive.
	//--- === Build 83 OILFIELDS (Takistan-only neutral resource node, Ray 2026-07-01) ===
	if (isNil "WFBE_C_OILFIELD_ENABLE") then {WFBE_C_OILFIELD_ENABLE = 1};                 //--- master on/off (Takistan only; inert on Chernarus).
	if (isNil "WFBE_C_OILFIELD_UNLOCK_TIME") then {WFBE_C_OILFIELD_UNLOCK_TIME = 3600};    //--- ingame seconds before the node unlocks (marker+capture+income live, announced). 1 hour.
	if (isNil "WFBE_C_OILFIELD_POS") then {WFBE_C_OILFIELD_POS = [4600, 6200, 0]};         //--- LEGACY-FALLBACK TK anchor (only used when WFBE_C_OILFIELD_DYNAMIC=0 or the dynamic search fails); the fallback auto-snaps to a real oil/fuel object near here, else uses this.
	if (isNil "WFBE_C_OILFIELD_ANCHOR_SEARCH") then {WFBE_C_OILFIELD_ANCHOR_SEARCH = 1200}; //--- search radius (m) for a real oil/fuel installation to anchor on.
	if (isNil "WFBE_C_OILFIELD_RADIUS") then {WFBE_C_OILFIELD_RADIUS = 120};               //--- capture/hold radius (m).
	if (isNil "WFBE_C_OILFIELD_SCAN_INTERVAL") then {WFBE_C_OILFIELD_SCAN_INTERVAL = 15};   //--- seconds between presence scans (floored 5s in code).
	if (isNil "WFBE_C_OILFIELD_INCOME_INTERVAL") then {WFBE_C_OILFIELD_INCOME_INTERVAL = 60}; //--- seconds between income ticks while held.
	if (isNil "WFBE_C_OILFIELD_INCOME_SUPPLY") then {WFBE_C_OILFIELD_INCOME_SUPPLY = 200};  //--- supply credited to the owner per income tick. [Ray 2026-08-02 17:08: 25 -> 200/min - make the node a real strategic prize; rollback 25. NOTE: INCOME_CAP 15000 now exhausts in 75 min held.]
	if (isNil "WFBE_C_OILFIELD_INCOME_CAP") then {WFBE_C_OILFIELD_INCOME_CAP = 15000};      //--- per-round lifetime supply cap the node pays out (anti-runaway).
	if (isNil "WFBE_C_OILFIELD_MARKER_TYPE") then {WFBE_C_OILFIELD_MARKER_TYPE = "mil_circle"}; //--- map marker type.
	if (isNil "WFBE_C_OILFIELD_MARKER_TEXT") then {WFBE_C_OILFIELD_MARKER_TEXT = "OILFIELD"};   //--- map marker label.
	if (isNil "WFBE_C_OILFIELD_OPEN_MSG") then {WFBE_C_OILFIELD_OPEN_MSG = "The OILFIELD is now active! Hold it with your units to earn passive supply income. Check your map."}; //--- 1h-unlock broadcast line.
	//--- === cmdcon43-m OILFIELD pre-unlock visibility (marker + countdown from match start; Takistan-only) ===
	if (isNil "WFBE_C_OILFIELD_PREMARK") then {WFBE_C_OILFIELD_PREMARK = 1};                //--- 1 = create the map marker EARLY (as soon as the derrick position resolves) with a "OILFIELD - opens in mm:ss" countdown label, so players see the field + timer from match start; 0 = classic marker-only-at-unlock.
	if (isNil "WFBE_C_OILFIELD_PREMARK_UPDATE") then {WFBE_C_OILFIELD_PREMARK_UPDATE = 30}; //--- countdown label refresh cadence (s); 30s is negligible marker-churn while per-second would be render spam (floored 10s in code).
	if (isNil "WFBE_C_OILFIELD_PREMARK_COLOR") then {WFBE_C_OILFIELD_PREMARK_COLOR = "ColorYellow"}; //--- pre-unlock (neutral/locked) marker colour; handed off to the side-absolute owner colour at unlock.
	if (isNil "WFBE_C_OILFIELD_PREMARK_LABEL") then {WFBE_C_OILFIELD_PREMARK_LABEL = "OILFIELD - opens in %1"};  //--- pre-unlock countdown label; %1 = mm:ss remaining. At T=0-countdown it reads "OILFIELD - opens in 60:00" etc.
	if (isNil "WFBE_C_OILFIELD_PREMARK_T5_MSG") then {WFBE_C_OILFIELD_PREMARK_T5_MSG = "The OILFIELD opens in 5 minutes - it lies between the two armies. Rally your units."}; //--- one-shot T-5min DashboardAnnounce garnish (same PREMARK flag gate); "" to disable just the announce.
	//--- === cmdcon42 OILFIELD upgrade (stakes visibility + sabotage/repair loop + AICOM pull + GUER raids; Takistan-only) ===
	if (isNil "WFBE_C_OILFIELD_MARKER_LIVE") then {WFBE_C_OILFIELD_MARKER_LIVE = 1};       //--- (stakes visibility) 1 = marker LABEL shows live owner + supply/tick (e.g. "OILFIELD [BLUFOR] +25/60s"); 0 = static label.
	if (isNil "WFBE_C_OILFIELD_SABOTAGE") then {WFBE_C_OILFIELD_SABOTAGE = 1};             //--- master on/off for the sabotage+repair loop (fire/smoke spectacle, income halt). 0 = classic capture-only node.
	if (isNil "WFBE_C_OILFIELD_SABOTAGE_SECS") then {WFBE_C_OILFIELD_SABOTAGE_SECS = 45};  //--- seconds an ENEMY of the holder must dwell in radius (holder cleared) to sabotage the field.
	if (isNil "WFBE_C_OILFIELD_REPAIR_SECS") then {WFBE_C_OILFIELD_REPAIR_SECS = 40};      //--- seconds the OWNING side must dwell (any unit) to repair a sabotaged field; halved if an engineer/repair-truck is present.
	if (isNil "WFBE_C_OILFIELD_SMOKE_INTERVAL") then {WFBE_C_OILFIELD_SMOKE_INTERVAL = 18};//--- seconds between re-spawned black smoke shells while the field burns (persistent column; each shell self-expires).
	if (isNil "WFBE_C_OILFIELD_SABOTAGE_MSG") then {WFBE_C_OILFIELD_SABOTAGE_MSG = "The OILFIELD has been SABOTAGED! It stops paying until the owner repairs it - watch for the smoke."}; //--- sabotage broadcast line.
	if (isNil "WFBE_C_OILFIELD_REPAIR_MSG") then {WFBE_C_OILFIELD_REPAIR_MSG = "The OILFIELD has been repaired and is paying out again."}; //--- repair broadcast line.
	if (isNil "WFBE_C_OILFIELD_AICOM_PULL") then {WFBE_C_OILFIELD_AICOM_PULL = 1};         //--- (AI contests) 1 = stamp a spearhead weight bonus on the nearest real town while the field is NOT held by that AI side (pulls AICOM teams past the field to capture it organically). 0 = off.
	if (isNil "WFBE_C_OILFIELD_AICOM_WEIGHT") then {WFBE_C_OILFIELD_AICOM_WEIGHT = 600};   //--- magnitude of the AICOM spearhead-weight bonus applied to the field's nearest town (added to wfbe_aicom_town_weight; town score divisor context ~50/m).
	if (isNil "WFBE_C_OILFIELD_GUER_RAID") then {WFBE_C_OILFIELD_GUER_RAID = if (worldName == "Takistan") then {1} else {0}}; //--- (GUER raids) DEFAULT ON on Takistan, OFF elsewhere (adds AI units): 1 = occasional GUER foot party raids the field while it is PAYING. Group-budget-aware.
	if (isNil "WFBE_C_OILFIELD_GUER_RAID_INTERVAL") then {WFBE_C_OILFIELD_GUER_RAID_INTERVAL = 1500}; //--- min seconds between GUER raid spawns on the field.
	if (isNil "WFBE_C_OILFIELD_GUER_RAID_SIZE") then {WFBE_C_OILFIELD_GUER_RAID_SIZE = 4}; //--- GUER foot raiders per raid party.
	if (isNil "WFBE_C_OILFIELD_GUER_RAID_GRPCAP") then {WFBE_C_OILFIELD_GUER_RAID_GRPCAP = 120}; //--- do NOT spawn a raid if resistance group count is at/above this (leaves headroom below the 144 hard cap).
	if (isNil "WFBE_C_OILFIELD_GUER_RAID_PLAYER_RADIUS") then {WFBE_C_OILFIELD_GUER_RAID_PLAYER_RADIUS = 400}; //--- defer materialisation when a real player is within this radius of the actual raid ring position; HCs are excluded.
	if (isNil "WFBE_C_OILFIELD_GUER_RAID_DENY_LOG_INTERVAL") then {WFBE_C_OILFIELD_GUER_RAID_DENY_LOG_INTERVAL = 300}; //--- minimum seconds between repeated player-near defer receipts; the gate still re-evaluates every scan.
	//--- === cmdcon42-oilrig DYNAMIC placement (Ray placement spec 2026-07-02: derrick on open ground BETWEEN the teams) ===
	if (isNil "WFBE_C_OILFIELD_DYNAMIC") then {WFBE_C_OILFIELD_DYNAMIC = 1};               //--- 1 = per-match dynamic placement: HQ-midpoint + open-ground ring search + spawned derrick composition. 0 = legacy fixed-anchor auto-snap (no composition).
	if (isNil "WFBE_C_OILFIELD_HQ_WAIT") then {WFBE_C_OILFIELD_HQ_WAIT = 600};             //--- max seconds to wait for BOTH start HQs to exist before falling back to the legacy anchor.
	if (isNil "WFBE_C_OILFIELD_RING_STEP") then {WFBE_C_OILFIELD_RING_STEP = 100};         //--- ring-search radius step (m) out from the HQ midpoint (floored 25m in code).
	if (isNil "WFBE_C_OILFIELD_RING_MAX") then {WFBE_C_OILFIELD_RING_MAX = 2000};          //--- max ring-search radius (m); beyond this the dynamic path gives up (WARNING + legacy fallback).
	if (isNil "WFBE_C_OILFIELD_FLAT_Z") then {WFBE_C_OILFIELD_FLAT_Z = 0.90};              //--- min (surfaceNormal) z for a candidate spot (1.0=flat; foot-snap uses 0.85, structures want flatter).
	if (isNil "WFBE_C_OILFIELD_ROAD_CLEAR") then {WFBE_C_OILFIELD_ROAD_CLEAR = 60};        //--- candidate rejected if any road within this (m) (nearRoads).
	if (isNil "WFBE_C_OILFIELD_TOWN_CLEAR") then {WFBE_C_OILFIELD_TOWN_CLEAR = 500};       //--- candidate rejected if any town center (towns list) within this (m).
	if (isNil "WFBE_C_OILFIELD_HOUSE_CLEAR") then {WFBE_C_OILFIELD_HOUSE_CLEAR = 80};      //--- candidate rejected if any building ("House") within this (m).
	if (isNil "WFBE_C_PATROL_T3_CASH") then {WFBE_C_PATROL_T3_CASH = 8000};                //--- [ORPHANED 2026-07-28 fable/patrol-reimagine: reward code removed from Server_ProcessUpgrade.sqf per owner order; constant retained per repo policy, value unused.] Was: one-time CASH on completing Patrol L3.
	if (isNil "WFBE_C_PATROL_T4_SUPPLY") then {WFBE_C_PATROL_T4_SUPPLY = 1500};             //--- [ORPHANED 2026-07-28 fable/patrol-reimagine: reward code removed from Server_ProcessUpgrade.sqf per owner order; constant retained per repo policy, value unused.] Was: one-time SUPPLY on completing Patrol L4.
	if (isNil "WFBE_C_AICOM_PLANE_AIRSTART") then {WFBE_C_AICOM_PLANE_AIRSTART = 1};        //--- Build83 (Ray): founded PLANES air-start (FLY) at the captured airfield, aligned to the runway logic, de-conflicted (helis/ground unchanged). 0 = old grounded/scattered FORM behavior.
	if (isNil "WFBE_C_AICOM_PLANE_STACK_DEG") then {WFBE_C_AICOM_PLANE_STACK_DEG = 25};     //--- Build83: per-plane heading fan (deg) so a multi-plane team's air-started hulls don't spawn stacked.
	if (isNil "WFBE_C_AICOM_AIR_TEAM_MAX_HULLS") then {WFBE_C_AICOM_AIR_TEAM_MAX_HULLS = 0}; //--- Lane 179: 0 = off. >0 caps retained Air hulls created by one CreateTeam pass; intended for AICOM air founding templates.
	if (isNil "WFBE_C_AICOM_AIR_TEAM_STAGGER") then {WFBE_C_AICOM_AIR_TEAM_STAGGER = 0};    //--- Lane 179: seconds to wait between retained Air hull spawns for this side. 0 = no delay.
	if (isNil "WFBE_C_AIRLIFT_OWN_HQ") then {WFBE_C_AIRLIFT_OWN_HQ = 1};                    //--- Build83 (Ray 2026-07-01): re-enable airlifting your OWN HQ (Zeta_Hook; was disabled by Trello #87). 0 = restore the old exclusion.
	if (isNil "WFBE_C_AICOM_AIR_MAX_TOTAL") then {WFBE_C_AICOM_AIR_MAX_TOTAL = 5};          //--- Build83 (Ray): flat per-side cap on TOTAL alive AICOM air (planes + attack + transport helis together). Replaces the retired per-type attack-heli cap. 0 = no cap.
	if (isNil "WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI") then {WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI = 1}; //--- Build83 (Ray): a held Aircraft-Factory structure lets the AI build HELIS without the (never-rushed) air-research tier; planes still need a held airfield. 0 = old (helis need researched air tier).
	if (isNil "WFBE_C_AICOM_MANUALPIN_TTL") then {WFBE_C_AICOM_MANUALPIN_TTL = 600};        //--- Build83 (Ray): seconds a human console order "pins" a team so the AI (AssignTowns) won't re-grab it; TTL-bounded so a stale pin from a disconnected commander expires. 0 = off.
	//--- B74.2 HELI BASE-REAP: let the HC team-runner self-delete an attack heli that has idled crewed at its OWN
	//--- base continuously for this many seconds (0 = off). This is the HC-LOCAL cleanup the server-side BASE-GC
	//--- cannot do (HC-founded heli hulls are not server-local + are ownership-exempt at server_groupsGC.sqf:209).
	if (isNil "WFBE_C_AICOM_HELI_BASE_REAP_TIMEOUT") then {WFBE_C_AICOM_HELI_BASE_REAP_TIMEOUT = 600};
	//--- B66 airfield-air rule: choppers are allowed from an Aircraft-Factory at tier 2; fixed-wing PLANES are only buildable at an OWNED airfield with the Aircraft-Factory at tier 4 (NOT the base air factory). 1 = enforce; 0 = old behaviour (planes from base air factory).
	if (isNil "WFBE_C_AICOM_AIR_REQUIRE_AIRFIELD") then {WFBE_C_AICOM_AIR_REQUIRE_AIRFIELD = 1};
	if (isNil "WFBE_C_AICOM_AIRFIELD_FREE_AIR") then {WFBE_C_AICOM_AIRFIELD_FREE_AIR = 1}; //--- B74 (Ray 2026-06-22): when a side HOLDS a captured airfield it may buy JETS+HELIS there even WITHOUT the Aircraft Factory (free-buy at the field). An Aircraft Factory alone (no airfield) still yields HELICOPTERS ONLY (jets need a field to operate/rearm). 1=on, 0=old (factory-gated, planes need both).
	//--- cmdcon42 (Ray 2026-07-02) AICOM AIR PARADROP INTO HOT LZ: when a team's own transport heli would insert onto a CONTESTED or ENEMY-HELD LZ, the
	//--- infantry PARADROPS (reuses the existing no-flat-LZ EJECT fallback) instead of the transport descending to land in the guns. Hot-LZ = the LZ's
	//--- nearest town is not our side (getVariable "sideID"; neutral/GUER/enemy all jump-worthy) OR a decision-time nearEntities scan finds any hostile
	//--- (getFriend < 0.6) within *_SCAN_R. Jumpers eject SHORT of the town (*_OFFSET m back along the approach vector) so they don't drop onto the depot guns.
	if (isNil "WFBE_C_AICOM_AIR_PARADROP") then {WFBE_C_AICOM_AIR_PARADROP = 1};                 //--- 1 = paradrop into contested/enemy LZs (default). 0 = always attempt land-and-disembark (legacy).
	if (isNil "WFBE_C_AICOM_AIR_PARADROP_SCAN_R") then {WFBE_C_AICOM_AIR_PARADROP_SCAN_R = 400}; //--- m: ONE decision-time hostile scan radius around the LZ. Any hostile (getFriend < 0.6) inside -> paradrop.
	if (isNil "WFBE_C_AICOM_AIR_PARADROP_MIN_HOSTILE") then {WFBE_C_AICOM_AIR_PARADROP_MIN_HOSTILE = 2}; //--- Lane-344: hostile count required in the LZ scan before forcing paradrop; filters single-frame crew/body blips.
	if (isNil "WFBE_C_AICOM_AIR_PARADROP_OFFSET") then {WFBE_C_AICOM_AIR_PARADROP_OFFSET = 250}; //--- m short of the town, back along the approach vector, to eject so jumpers don't land ON the depot guns.
	//--- cmdcon42-f (Ray 2026-07-02) AICOM AIR-MOBILE ORDERS: a team that STILL HAS its own live transport helicopter FLIES an ordered leg (mount pax -> fly at
	//--- altitude -> at the destination run the SAME hot-LZ decision above: cold LZ = land+GET OUT, contested/enemy town = paradrop OFFSET m short) instead of
	//--- road-marching, then the transport RETURNS to the side base + HOLDS for the next order (it persists - it IS the team's vehicle; no fly-off/refund). Only
	//--- acts when the destination is beyond *_MIN_DIST; transport-less remnants road-march unchanged. Airlifted teams register arrivals normally (pax get an
	//--- unconditional ground move to the objective so the arrival latch + MOVE/SAD capture chain fold them in like a walked/landed insert).
	if (isNil "WFBE_C_AICOM_AIRMOBILE") then {WFBE_C_AICOM_AIRMOBILE = 1};                        //--- 1 = fly ordered legs with the team's own retained transport heli (default). 0 = always road-march (legacy).
	if (isNil "WFBE_C_AICOM_AIRMOBILE_MIN_DIST") then {WFBE_C_AICOM_AIRMOBILE_MIN_DIST = 1200};  //--- m: only air-mobile when the ordered destination is farther than this (short legs road-march - not worth a fly-out).
	if (isNil "WFBE_C_AICOM_AIR_RETAIN") then {WFBE_C_AICOM_AIR_RETAIN = 1};                     //--- cmdcon42-f (Ray): 1 = the FOUNDING air-insert KEEPS the team's transport heli (returns to base + holds via the shared AICOMAirReturn path) so the AIR-MOBILE branch above can fly the team's next orders. ECONOMICS BY DESIGN: retaining FORGOES the legacy off-map refund (the hull's QUERYUNITPRICE credited back to the AI treasury) - the side keeps a REAL transport asset instead of the credit (HQ air squads should BE air squads). 0 = legacy fly-off + delete + refund (byte-identical).
	//--- fable/heli-quickstart (owner 2026-07-28: helicopters linger way too long in base before flying off
	//--- after spawning): tunable boarding-wait cap for a founded team's OWN air transport
	//--- (Common_RunCommanderTeam.sqf, the "Let everyone board first" wait before the run-in), replacing the
	//--- previous hardcoded 30s. Air-only - gates only the transport-insert Spawn enclosed by !isNull _airVeh
	//--- (an Air hull with transportSoldier>0); ground transports are never affected.
	if (isNil "WFBE_C_AICOM_BOARD_WAIT") then {WFBE_C_AICOM_BOARD_WAIT = 12};              //--- s: max wait for pax to mount the team's own air transport before the run-in begins. 30 = legacy value.
	//--- fable/air-quickstart-v2 (owner 2026-07-28: helicopters linger way too long in base; HC-safe
	//--- quickstart v2): a founded team's own air transport otherwise sits idle at the pad until the
	//--- NEXT WFBE_C_AI_COMMANDER_TOWN_INTERVAL (120s) AssignTowns pass ever issues it an order - up
	//--- to ~75-120s of dead time the owner reported. Server_HandleSpecial.sqf's "aicom-team-created"
	//--- handler (already the SINGLE point every founded team - HC or server-fallback - reports back
	//--- through) writes ONE narrow first wfbe_aicom_order for THAT team only, using the exact [seq,
	//--- mode, pos] contract Common_RunCommanderTeam.sqf already polls - never calls the HC-unsafe,
	//--- side-wide WFBE_SE_FNC_AI_Com_AssignTowns (see PR #1586 rejection writeup). Default 0: the
	//--- handler still runs its existing registration code unchanged; this adds one extra
	//--- missionNamespace getVariable read and nothing else.
	if (isNil "WFBE_C_AICOM_AIR_QUICKSTART") then {WFBE_C_AICOM_AIR_QUICKSTART = 0};              //--- 1 = issue a same-tick first order to a freshly founded air-transport team (see Server_HandleSpecial.sqf "aicom-team-created"). 0 = legacy (team waits for the next AssignTowns tick, up to WFBE_C_AI_COMMANDER_TOWN_INTERVAL).
	//--- Grok U6 idle-air retirement: all three defaults are 0 so the existing air lifecycle is unchanged until explicitly configured.
	if (isNil "WFBE_C_AICOM_AIR_IDLE_RTB") then {WFBE_C_AICOM_AIR_IDLE_RTB = 0};
	if (isNil "WFBE_C_AICOM_AIR_IDLE_MINUTES") then {WFBE_C_AICOM_AIR_IDLE_MINUTES = 0};
	if (isNil "WFBE_C_AICOM_AIR_IDLE_SENSE_R") then {WFBE_C_AICOM_AIR_IDLE_SENSE_R = 0};
	//--- cmdcon42-l (Ray 2026-07-02) AICOM VEHICLE AIRLIFT: when an air-mobile leg launches (Common_AICOMAirLeg) and the team owns an eligible ground vehicle, the transport SLINGS it below the heli (attachTo) and flies it to a DEEP drop point *_DEPTH m BEYOND the ordered town along the town->enemy-HQ (enemy-rear) axis, so the vehicle + crew land 1-2km BEHIND the lines and attack the objective from the rear (Ray's flanking intent). ELIGIBILITY IS TIERED BY THE SIDE'S AIR-FACTORY RESEARCH (Ray expansion: "BTR/LAV/Stryker should be included, at higher AF tiers heavier vehicles as well"; one WFBE_UP_AIR read via GetSideUpgrades per leg - AIR research has 5 levels): TIER 1 = light Car-family only (armed HMMWVs/UAZs/Vodniks/technicals/light trucks, armor <= *_MAXARMOR); TIER 2 (AIR >= *_T2_AIR) ALSO Wheeled_APC-family (BTR-60/90, LAV-25, Strykers, armor <= *_T2_MAXARMOR); TIER 3 (AIR >= *_T3_AIR) ANY LandVehicle (tracked IFVs BMP-2/Bradley join, armor <= *_T3_MAXARMOR; MBTs stay excluded NATURALLY by armor: T-72 690 / M1A1 850). Never Air/Ship at any tier. ONE lift per leg; NEVER lifts the team's only transport; the drop point must clear water + a flatness check (shortens depth toward the dest if not, floor at the dest). The pax insert still uses the normal hot-LZ point on the same flight path. Telemetry: VEHLIFT line carries |tier=N.
	if (isNil "WFBE_C_AICOM_VEHLIFT") then {WFBE_C_AICOM_VEHLIFT = 1};                            //--- 1 = an air-mobile leg SLINGS one owned eligible (AIR-tier-gated) ground vehicle + deep-drops it behind the lines (default). 0 = pax-only air legs (legacy).
	if (isNil "WFBE_C_AICOM_VEHLIFT_DEPTH") then {WFBE_C_AICOM_VEHLIFT_DEPTH = 1500};             //--- m BEYOND the ordered town, along the town->enemy-HQ (enemy-rear) axis, to drop the slung vehicle (jitter +-300). The dropped crew then attack the town from behind. Shortened in 300m steps toward the dest if water/non-flat, floored at the dest itself.
	if (isNil "WFBE_C_AICOM_VEHLIFT_MAXARMOR") then {WFBE_C_AICOM_VEHLIFT_MAXARMOR = 150};        //--- TIER-1 config-armor ceiling (name kept for compat), CALIBRATED 150 against vanilla A2/OA values: SUV 25, offroad 30, Ural/MTVR 32, HMMWV/UAZ/V3S 40, Land Rover ~60, Vodnik 85-100, HMMWV CROWS 100, HMMWV M2 120, HMMWV Avenger 150 - ALL liftable at <=150 (earlier 80/120 drafts excluded exactly the ARMED HMMWVs/Vodniks most worth dropping behind the lines). At tier 1 the APC family (BTR60 120, LAV25/BTR90 150, Stryker 160) overlaps this armor range but is excluded by the CLASS test, NOT the armor test: tier-1 liftable also requires isKindOf "Car" AND NOT isKindOf "Wheeled_APC" (Wheeled_APC derives FROM Car in A2, so the NOT-clause is load-bearing); BMP2 (250)/Bradley are Tank-family = not "Car" at all. getNumber (configFile>>CfgVehicles>>type>>"armor") <= this = tier-1 liftable. A per-class allowlist (WFBE_C_AICOM_VEHLIFT_ALLOW) is a fallback for hulls whose armor reads 0/unreliable (still gated NOT-Wheeled_APC/NOT-Tank).
	if (isNil "WFBE_C_AICOM_VEHLIFT_T2_AIR") then {WFBE_C_AICOM_VEHLIFT_T2_AIR = 2};              //--- AIR-FACTORY research level (WFBE_UP_AIR) that unlocks TIER 2 lifts: Wheeled_APC-family joins the liftable set (BTR-60/90, LAV-25, Strykers).
	if (isNil "WFBE_C_AICOM_VEHLIFT_T2_MAXARMOR") then {WFBE_C_AICOM_VEHLIFT_T2_MAXARMOR = 200};  //--- TIER-2 armor ceiling for the Wheeled_APC family: BTR60 120, LAV25/BTR90 150, Stryker 160 all fit under 200; anything heavier-wheeled stays grounded.
	if (isNil "WFBE_C_AICOM_VEHLIFT_T3_AIR") then {WFBE_C_AICOM_VEHLIFT_T3_AIR = 4};              //--- AIR-FACTORY research level that unlocks TIER 3 lifts: ANY LandVehicle up to *_T3_MAXARMOR (AIR has 5 levels - the ICBM dep proves L5 - so 4 = late-game).
	if (isNil "WFBE_C_AICOM_VEHLIFT_T3_MAXARMOR") then {WFBE_C_AICOM_VEHLIFT_T3_MAXARMOR = 400};  //--- TIER-3 armor ceiling: tracked IFVs join (BMP-2 250, Bradley 300/400); MBTs stay excluded NATURALLY by armor (T-72 690, M1A1 850) - no class exclusion needed at this tier (LandVehicle-only keeps Air/Ship out).
	//--- ALLOWLIST FALLBACK: hulls whose base class (isKindOf) makes them liftable even if the armor read is 0/unreliable. A "Car"-kind that is NOT a "Wheeled_APC" is the primary allow; this list is a belt-and-braces base-class set (all A2/OA light 4x4 base classes). Both the armor gate AND (Car AND NOT Wheeled_APC) must hold OR the hull isKindOf one of these to lift - so an armour misread never lifts a LAV/BTR (they are Wheeled_APC) and never lifts a tank.
	if (isNil "WFBE_C_AICOM_VEHLIFT_ALLOW") then {WFBE_C_AICOM_VEHLIFT_ALLOW = ["Car","Offroad","HMMWV_Base","UAZ","LandRover_Base","Pickup","Datsun1_base"]};
	if (isNil "WFBE_C_AICOM_ARTRAD_REQUIRE_ENEMY_ARTY") then {WFBE_C_AICOM_ARTRAD_REQUIRE_ENEMY_ARTY = 1}; //--- CB-GATE (Ray B48): 1 = AI commander defers the (cosmetic) ArtilleryRadar build until the ENEMY actually fields/fires artillery (re-uses wfbe_aicom_arty_threat). 0 = old human-like always-build. AI-commander build logic ONLY; humans unaffected.
	if (isNil "WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE") then {WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE = 0}; //--- Lane 114: 0 keeps the legacy 10km cond-c enemy-artillery scan; 1 lets the radius below tune it.
	if (isNil "WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS") then {WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS = 10000}; //--- metres for the opt-in cond-c enemy-artillery existence scan around enemy HQ.
	//--- P1 combined-arms ratio (claude-gaming 2026-06-15): target CLASS mix for newly-typed AI teams,
	//--- [infantry, light, heavy, air]. The type picker buckets the eligible templates by class and
	//--- rolls a class against these weights; if the rolled class has NO buildable (factory+tech-unlocked)
	//--- template it falls back to a lower vehicle class and finally to infantry, so it never forces an
	//--- un-buildable type. Infantry stays the largest single share (foot are required to capture camps),
	//--- but armour/mech rise to a meaningful ~25-35% once the heavy/light factory + tier exist. Weights
	//--- need not sum to 1 (they are normalised at pick time). Was effectively ~70% infantry from the old
	//--- doctrine-only weighting; this defaults to ~65/20/12/3 of the achievable mix.
	//--- HF-MAIN DOCTRINE (owner ruling 2026-07-22): default ON; flag-off restores the legacy doctrine/temperament pick and founding mix.
	if (isNil "WFBE_C_AICOM_DOCTRINE_HF_MAIN") then {WFBE_C_AICOM_DOCTRINE_HF_MAIN = 1};
	if (isNil "WFBE_C_AICOM_TYPE_MIX") then {WFBE_C_AICOM_TYPE_MIX = [0.65, 0.20, 0.12, 0.03]};
	//--- B66 combined-arms RAMP: the static TYPE_MIX above stays the fallback. The type picker selects an
	//--- [inf,light,heavy,air] weight tier by the AI commander's OWN-TOWN count: EARLY (mostly foot, the
	//--- opening land-grab), MID (armour/mech rising once factories exist), LATE (heavy+air heavy, an
	//--- established war machine). MATURE_MID / MATURE_LATE are the own-town thresholds at/above which the
	//--- MID / LATE tiers apply. Weights need not sum to 1 (normalised at pick time).
	if (isNil "WFBE_C_AICOM_TYPE_MIX_EARLY") then {WFBE_C_AICOM_TYPE_MIX_EARLY = [0.26,0.34,0.34,0.06]}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: mix-first inf reduction (45->32 early) instead of bias push (B756 overshoot guard). Owner 2026-08-01 ("focus a little less on infantry and more on vehicles"): 32->26 inf, redistributed to light+heavy, air untouched.
	if (isNil "WFBE_C_AICOM_TYPE_MIX_MID") then {WFBE_C_AICOM_TYPE_MIX_MID = [0.24,0.28,0.31,0.17]}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: balanced mid roster; shift infantry reduction into the mix rather than multiplying biases. Owner 2026-08-01: 30->24 inf, redistributed to light+heavy, air untouched (LATE already vehicle-heavy, not changed).
	if (isNil "WFBE_C_AICOM_TYPE_MIX_LATE") then {WFBE_C_AICOM_TYPE_MIX_LATE = [0.12,0.12,0.28,0.48]}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: late game leans air 0.48 per owner pick - capture rail: air bucket must stay lift-majority.
	if (isNil "WFBE_C_AICOM_TYPE_MIX_MATURE_MID")  then {WFBE_C_AICOM_TYPE_MIX_MATURE_MID  = 2}; //--- Ray 2026-06-27: 4->2 own-towns so the armour-heavier MID mix (43/25/20/12) kicks in sooner (debug-off captures are slow, so the AI was stuck in the foot-heavy EARLY mix too long). own-town count at/above which the MID tier applies.
	if (isNil "WFBE_C_AICOM_TYPE_MIX_MATURE_LATE") then {WFBE_C_AICOM_TYPE_MIX_MATURE_LATE = 8}; //--- own-town count at/above which the LATE tier applies.
	//--- B74 COST/TIER BIAS (Ray 2026-06-22) -> SUPERSEDED by the B750 effectiveness draw below. The B74 picker weighted
	//--- each template by (mission ECONOMY price)^1.5, so the commander spammed its single most EXPENSIVE platoon and the
	//--- army looked repetitive. Kept defined at 0 (no-op) for any external reference; the live draw now reads EFF_BIAS_EXP.
	if (isNil "WFBE_C_AICOM_TIER_BIAS_EXP") then {WFBE_C_AICOM_TIER_BIAS_EXP = 0};
	//--- B750 EFFECTIVENESS DRAW (Ray 2026-06-24, "don't bias highest VALUE, bias most EFFECTIVE units + more variety"):
	//--- within a class bucket, weight each candidate template by (summed BI CfgVehicles "cost" = combat-threat rating)^EXP
	//--- instead of by the mission ECONOMY price. Combat value is decoupled from what the economy charges (tier/balance
	//--- inflation), and a LOW exponent flattens the draw so the commander fields a VARIED, capable mix rather than one
	//--- premium template. 0 = pure uniform (max variety); 0.5 (default) = mild effectiveness lean; ~1.0+ = stronger.
	//--- Tune live. The combat value is read from config once per template per founding (cheap; foundings are infrequent).
	if (isNil "WFBE_C_AICOM_EFF_BIAS_EXP") then {WFBE_C_AICOM_EFF_BIAS_EXP = 0.3};  //--- AICOM v2 (Ray "much more varied"): 0.5->0.3 - flatten the cost-effectiveness bias so the founding draw spreads across far more templates (less repetition).
		//--- B754 (Ray 2026-06-25) HELI TIME-BIAS: field MORE helicopters (transport + attack) the longer the match runs. Scales the AIR class-bucket weight by a wall-clock factor ramping 1.0 -> MAXMULT over RAMP_MIN minutes, then holds (orthogonal to the own-town TYPE_MIX ramp). MAXMULT=1.0 => no-op.
		if (isNil "WFBE_C_AICOM_AIR_TIME_BIAS_MAXMULT")    then {WFBE_C_AICOM_AIR_TIME_BIAS_MAXMULT    = 4.5};  //--- AICOM v2 (Ray 2026-06-27 "lots of choppers late"): 2.5->4.5, the air bucket weight balloons late-game.
		if (isNil "WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN")   then {WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN   = 35};  //--- AICOM v2: 45->35 min so the air ramp peaks sooner.
		//--- AICOM v2 JET TIME-GATE (Ray 2026-06-27): manned CAS jets (fixed-wing) only start founding after
		//--- JET_START_SECS of match time, then ramp in (probability 0->1) to JET_FULL_SECS. Stacks ON TOP of the
		//--- airfield-ownership gate (a side must hold an airfield to field planes AT ALL). 2h start -> 5h full.
		if (isNil "WFBE_C_AICOM_JET_START_SECS") then {WFBE_C_AICOM_JET_START_SECS = 7200};  //--- 2h: no AI jets before this.
		if (isNil "WFBE_C_AICOM_JET_FULL_SECS")  then {WFBE_C_AICOM_JET_FULL_SECS  = 18000}; //--- 5h: jets at full availability (ramped 2h->5h).
		//--- AICOM v2 (Ray): reap UNCREWED/bugged aircraft (heli OR plane) so a long round can't pile up orphaned airframes.
		if (isNil "WFBE_C_AICOM_AIR_REAP_UNCREWED") then {WFBE_C_AICOM_AIR_REAP_UNCREWED = 1};  //--- 1 = delete an alive air vehicle with no alive crew. 0 = off.
		if (isNil "WFBE_C_AICOM_AIR_REAP_GRACE")    then {WFBE_C_AICOM_AIR_REAP_GRACE    = 45}; //--- s an aircraft must stay uncrewed before it's reaped (avoids deleting a transient bail/reseat).
		//--- AICOM v2 (cmdcon29, Ray): crew SELF-REPAIR of an immobilized ground vehicle (shot-out wheel/track/engine -> !canMove strands the whole team, moved=0). Crew field-repairs (setDamage 0) after a safe-window delay; gated on no enemy near + not in combat. 0 = off.
		if (isNil "WFBE_C_AICOM_VEHICLE_SELFREPAIR")   then {WFBE_C_AICOM_VEHICLE_SELFREPAIR   = 1};
		if (isNil "WFBE_C_AICOM_SELFREPAIR_SAFE_DIST") then {WFBE_C_AICOM_SELFREPAIR_SAFE_DIST = 250}; //--- m: no non-friendly Man/LandVehicle within this radius before a repair starts or completes.
		if (isNil "WFBE_C_AICOM_SELFREPAIR_DELAY")     then {WFBE_C_AICOM_SELFREPAIR_DELAY     = 30};  //--- s the crew must hold a safe window before the field repair completes.
		if (isNil "WFBE_C_AICOM_SELFREPAIR_AIRSHIP")   then {WFBE_C_AICOM_SELFREPAIR_AIRSHIP   = 1};   //--- 0 = OFF, byte-identical to HEAD (field repair stays LandVehicle-only). >0 = immobilised AIR and SHIP hulls also get the crew field repair, and the threat scan additionally looks for enemy Air. Closes two observed gaps: a damaged helicopter that force-lands is excluded from in-place repair AND cannot travel to an airfield for AICOMServiceTick AND is never reaped by Server_HandleEmptyVehicle.sqf (its fuse resets while crew are aboard), so it sits crewed and immobile until an enemy destroys it; and Ship is likewise excluded, matching the repeatedly-stuck GUER flotilla (USVFLOTILLA|UNSTUCK streak=5, SKIPLEG). Rollback: 0.
		if (isNil "WFBE_C_AICOM_STUCK_REPAIR")         then {WFBE_C_AICOM_STUCK_REPAIR         = 1};  //--- TP-15: 1 = at a tier-2/3 UNSTUCK event, restore+rearm the stuck lead hull IN PLACE (no town detour), reusing the SELFREPAIR safe-dist gate. 0 = off (byte-identical).
		//--- B754 (Ray 2026-06-25) RELATIVE ROUND-CLOSER GATE: the absolute 12-town HQ-strike gate is unreachable in a lopsided game (b753 soak: WEST held 11 vs EAST's dug-in 2, myEff 70 vs 53, never hit 12 -> 8.4h with no winner). Let a runaway leader close BELOW the absolute gate when dominant on EFFECTIVE strength AND (enemy collapsed to <= ENEMY_MAX towns OR own >= TOWN_RATIO town lead), plus a STALL_OVERRIDE after N dominant-but-passive stall ticks. Never fires while behind on towns/strength.
		if (isNil "WFBE_C_AICOM_HQSTRIKE_ENEMY_MAX")      then {WFBE_C_AICOM_HQSTRIKE_ENEMY_MAX      = 2};
		if (isNil "WFBE_C_AICOM_HQSTRIKE_TOWN_RATIO")     then {WFBE_C_AICOM_HQSTRIKE_TOWN_RATIO     = 3};
		if (isNil "WFBE_C_AICOM_HQSTRIKE_STALL_OVERRIDE") then {WFBE_C_AICOM_HQSTRIKE_STALL_OVERRIDE = 5};
		//--- D2 (cmdcon28, Ray 2026-06-30): the STALL_OVERRIDE above was structurally DEAD (its counter only built while
		//--- town-dominant-but-strength-deficit, but the override gate required strength-dominance - mutually exclusive;
		//--- live: a side stalled 17x, 0 round-enders). Fixed in AI_Commander_Strategy.sqf. STALL_TOWN_RATIO = how many x
		//--- the enemy's towns a side must hold to accrue the override streak (was a hard-coded 2). OVERRIDE_ENABLE = master
		//--- on/off for a clean revert. NOTE: at 2x, an 11-6 board (1.83x) does NOT trigger - drop to ~1.7 to close tighter games.
		if (isNil "WFBE_C_AICOM_STALL_TOWN_RATIO")        then {WFBE_C_AICOM_STALL_TOWN_RATIO        = 2};
		if (isNil "WFBE_C_AICOM_STALL_OVERRIDE_ENABLE")   then {WFBE_C_AICOM_STALL_OVERRIDE_ENABLE   = 1};
		//--- B755 (Ray 2026-06-25) MECHANIZED-INFANTRY BIAS: seat infantry in ARMED vehicles rather than founding pure-foot teams. Multiplies the class-bucket roll toward mechanized/armor (bucket 2 = IFV/APC that carry their own dismounts) + motorized (bucket 1). 1.0 = no-op. Self-gating (empty buckets zero out, so foot is never starved when no factory exists).
		if (isNil "WFBE_C_AICOM_MECH_BIAS") then {WFBE_C_AICOM_MECH_BIAS = 1.55}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: mix-first inf reduction (45->32 early) instead of bias push (B756 overshoot guard).
		if (isNil "WFBE_C_AICOM_MOTOR_BIAS") then {WFBE_C_AICOM_MOTOR_BIAS = 1.5}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: mix-first inf reduction instead of bias push (B756 overshoot guard).
		//--- B755 RE-MOUNT FOR THE LONG LEG: a team re-tasked to a far town after a prior capture has its infantry ON FOOT (the capture dismount unassigned them). 1 = re-seat them into the team's drivable hulls before the road-march so they RIDE the long leg instead of foot-marching (no-op on the first march). 0 = old behaviour.
		if (isNil "WFBE_C_AICOM_REMOUNT_LONG_LEG") then {WFBE_C_AICOM_REMOUNT_LONG_LEG = 1};
		//--- r108 B66 REAL-LEG GUER-AVOID: re-run the hostile-town route scan on the ACTUAL leg (leader -> live order dest) at the long-leg road-march; when a hostile garrison sits astride the drive path the re-mount is skipped and seated cargo riders dismount (the founding mount-block scans leader->spawn - no objective exists at founding - so it never protected a real route). 0 = legacy (no live scan).
		if (isNil "WFBE_C_AICOM_GUER_AVOID_REALLEG") then {WFBE_C_AICOM_GUER_AVOID_REALLEG = 0};
		//--- B756 (Ray 2026-06-26) DISMOUNT-CARRIER bias: within the team-template draw, multiply a template's weight if it carries INFANTRY dismounts (so IFV/APC + squad beat bare MBTs in the heavy bucket = "infantry seated in armed vehicles" rather than gun-tanks). 1.0 = no-op.
		if (isNil "WFBE_C_AICOM_DISMOUNT_BIAS") then {WFBE_C_AICOM_DISMOUNT_BIAS = 1.7}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: mix-first inf reduction instead of bias push (B756 overshoot guard).
	//--- Codex review MEDIUM fix: crew-only dismount (Common_RunCommanderTeam.sqf) threat-gate radius - see the dismount-decision block there.
	if (isNil "WFBE_C_AICOM_CREW_DISMOUNT_THREAT_RADIUS") then {WFBE_C_AICOM_CREW_DISMOUNT_THREAT_RADIUS = 100};
		//--- B756 MOUNT seat-capacity gate: only GROUND MOUNT-UP / re-mount a team if its ride pool can seat at least this FRACTION of the squad. A partial mount splits the team (the APC drives off, the foot element strands -> ASSAULT_STRANDED). Below this the team stays foot-cohesive (the hull paces the group road-march). 0 = old behaviour (always partial-mount).
		if (isNil "WFBE_C_AICOM_MOUNT_MIN_SEAT_FRAC") then {WFBE_C_AICOM_MOUNT_MIN_SEAT_FRAC = 0.8};
		//--- B756 NAVAL-RAID gate: naval-HVT (carrier) spearhead targets are only assigned to teams with a TRANSPORT HELI (they're offshore, only reachable by air-insertion). Ground teams never get tasked to the sea (no stranding). This makes the carriers a real - but air-only - assault objective. Gate lives in AI_Commander_AssignTowns.sqf.
		if (isNil "WFBE_C_AICOM_NAVAL_AIR_ONLY") then {WFBE_C_AICOM_NAVAL_AIR_ONLY = 1};
		//--- Moving-platform audit: Ship AICOM templates stay out of the generic ground founder until a water-aware naval founder/route exists. 0 = fail-closed default; 1 = reserved for that future path.
		if (isNil "WFBE_C_AICOM_NAVAL_TEMPLATES") then {WFBE_C_AICOM_NAVAL_TEMPLATES = 0};
	//--- A/B EXPERIMENT (legacy-vs-next): arm label + sim-gating switch. LEGACY arm = control (gating off).
	if (isNil "WFBE_C_AB_ARM") then {WFBE_C_AB_ARM = "NEXT-T1c"};
	//--- AI COMMANDER ARTILLERY: locked off 2026-06-13 (Steff), RE-ENABLED 2026-07-09 by owner - an INFORMED
	//--- decision, not an oversight: Ray showed the owner the exact 2026-06-13 lock language below plus the
	//--- two-systems ambiguity (this flag vs the separate always-on "AICOM TRACKED ARTILLERY" battery, see
	//--- note further down) before he confirmed. Reverses the prior lock; ships with the new dwell-tempo
	//--- softening + self-healing 2-piece cap (PR #960, fable/alife-arty-dwell). The flag is now isNil-guarded
	//--- (like every other AICOM tunable) instead of force-assigned, so it defaults ON but a param/debug
	//--- override can still dial it back to 0. Unlocks the fire-mission worker (AI_Commander_Strategy.sqf) AND
	//--- base-gun building (AI_Commander_Base.sqf), both already flag-gated there; see WFBE_C_AICOM_ARTY_DWELL /
	//--- WFBE_C_AI_COMMANDER_ARTILLERY_MAX below for the new dwell-tempo + cap knobs (distinct from the
	//--- PRE-EXISTING WFBE_C_AICOM_ARTY_MAX=1 below, which caps a SEPARATE always-on "AICOM TRACKED ARTILLERY"
	//--- mechanism - one battery founded via the normal team pipeline, AI_Commander_Teams.sqf ~L505/
	//--- Common_RunCommanderTeam.sqf ~L2510. That system is untouched by this change; see
	//--- ARTILLERY-DWELL-NOTES.md for the full two-systems writeup).
	//--- Original lock (kept for history): "Steff 2026-06-13: the AI must NOT be able to use artillery. Forced
	//--- off (not a default) so no param/override can enable it - blocks both the fire-mission worker AND
	//--- building base guns."
	if (isNil "WFBE_C_AI_COMMANDER_ARTILLERY") then {WFBE_C_AI_COMMANDER_ARTILLERY = 1};
	if (isNil "WFBE_C_SIM_GATING") then {WFBE_C_SIM_GATING = 0}; //--- 1 only on the NEXT arm: enableSimulation off for AI far from any active town.
	WFBE_C_AI_COMMANDER_LOG = 1;               //--- V0.4: always-on [AICOM] diag_log (independent of WF_LOG_CONTENT; 0 to silence).
	//--- V0.5: PvE difficulty (lobby param WFBE_C_AI_COMMANDER_LEVEL: 0 Easy / 1 Normal / 2 Hard).
	//--- Tunes the SYNTHETIC MONEY only - supply stays real on every level.
	if (isNil "WFBE_C_AI_COMMANDER_LEVEL") then {WFBE_C_AI_COMMANDER_LEVEL = 1};
	switch (WFBE_C_AI_COMMANDER_LEVEL) do {
		case 0:  {WFBE_C_AI_COMMANDER_FUNDS_MULT = 1.0; WFBE_C_AI_COMMANDER_INCOME_MULT = 1.0; WFBE_C_AI_COMMANDER_INCOME_STIPEND = 0};
		case 2:  {WFBE_C_AI_COMMANDER_FUNDS_MULT = 2.0; WFBE_C_AI_COMMANDER_INCOME_MULT = 2.0; WFBE_C_AI_COMMANDER_INCOME_STIPEND = 9000}; //--- B67: Hard stipend 3000->9000 (symmetry with the boosted Normal tier).
		default  {WFBE_C_AI_COMMANDER_FUNDS_MULT = 1.5; WFBE_C_AI_COMMANDER_INCOME_MULT = 1.5; WFBE_C_AI_COMMANDER_INCOME_STIPEND = 6000}  //--- B67 (Ray 2026-06-21): 2000->6000/min flat CASH (bloated income so the AI fields high-tier units all the time; cash only, never supply, cannot speed interval-gated tech). B36.1 base was $2000/min CASH (60s income tick so per-tick == per-min; Hard tier 3000, Easy 0). Unconditional per-tick AI-commander funds drip; keeps it fielding armies on a near-empty server.;
	};
	WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL = 60;   //--- V0.5: war-strategy worker cadence (spearheads/relief/strike/arty).
	//--- V0.6: Wildcard events - one free random event per AI-commanded side per interval.
	if (isNil "WFBE_C_AI_COMMANDER_WILDCARD") then {WFBE_C_AI_COMMANDER_WILDCARD = 1};           //--- 0 disables wildcard events entirely.
	if (isNil "WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL") then {WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL = 900}; //--- Seconds between wildcard events per side (15 min - faster testing cadence, claude-gaming 2026-06-14; was 1800/30min).
	if (isNil "WFBE_C_AI_COMMANDER_WILDCARD_COST") then {WFBE_C_AI_COMMANDER_WILDCARD_COST = 8000};       //--- funds the AI commander pays per wildcard draw. 0 = free/legacy (feature inert); >0 = purchase-gated (per-side afford check + cooldown). Intended live value 8000 (Ray 2026-07-07). claude-gaming.
	if (isNil "WFBE_C_AI_COMMANDER_WILDCARD_COOLDOWN") then {WFBE_C_AI_COMMANDER_WILDCARD_COOLDOWN = 1800}; //--- s min gap between purchased wildcard draws per side (30 min). Active only when WFBE_C_AI_COMMANDER_WILDCARD_COST > 0.
	if (isNil "WFBE_C_AI_COMMANDER_WILDCARD_HUMAN_BUY") then {WFBE_C_AI_COMMANDER_WILDCARD_HUMAN_BUY = 0}; //--- 0 preserves the legacy human-commanded skip; >0 lets the server charge the separate AICOM treasury.
	WFBE_C_AI_COMMANDER_SPEARHEAD_PER_TOWN = 3;   //--- V0.5: teams concentrated per spearhead town (legacy/fallback quota; per-tier quota below overrides).
	//--- V0.8 COHERENT FRONT (claude-gaming 2026-06-14): the old spearhead scorer was
	//--- supplyValue - dNear/150, which let a fat enemy city 8km away outscore the nearest
	//--- contestable town (STUCKSTAT distTgt=8122 = one squad sent piecemeal across the map).
	//--- The fix ranks enemy/neutral towns by NEAREST-TO-OUR-FRONT first (frontier prefilter +
	//--- distance-dominant score) with a small pull toward the enemy HQ, so the army advances as
	//--- a wave onto achievable nearby objectives instead of cherry-picking the enemy's rear.
	_wfbeAICOMMapSize = getNumber (configFile >> "CfgWorlds" >> worldName >> "mapSize");
	if (_wfbeAICOMMapSize <= 0) then {
		_wfbeAICOMMapSize = switch (worldName) do {
			case "Takistan": {12800};
			case "Zargabad": {4096};
			default {15360};
		};
	};
	_wfbeAICOMMapRadius = _wfbeAICOMMapSize / 2;
	if (isNil "WFBE_C_AICOM_FRONTIER_RADIUS") then {WFBE_C_AICOM_FRONTIER_RADIUS = ((_wfbeAICOMMapRadius * 0.20) max 1500)};   //--- m: a candidate town is "on the front" if it is within this distance of one of OUR owned towns (fallback: our HQ). Towns past this are deprioritised, not banned (guardrail: still targetable if the front is empty). Scales to small maps via CfgWorlds mapSize while preserving pre-set overrides.
	if (isNil "WFBE_C_AICOM_DISTANCE_DIVISOR") then {WFBE_C_AICOM_DISTANCE_DIVISOR = 30};   //--- C6 pick 1 (owner GO 2026-07-22 19:08): 50->30, stronger near-front preference so hauls shorten. Rollback: 50.   //--- score divisor on distance-to-front: one supply point is worth this many metres of march. Was effectively 150 (too weak); 50 makes distance dominate so the nearest contestable town wins.
	if (isNil "WFBE_C_AICOM_HQ_PULL_DIVISOR") then {WFBE_C_AICOM_HQ_PULL_DIVISOR = 250};    //--- score divisor on distance-to-ENEMY-HQ: adds a small spearhead bias toward the enemy capital so the front advances in one direction instead of wandering. Larger = weaker pull. 0 disables the pull.
	if (isNil "WFBE_C_AICOM_FAR_PENALTY") then {WFBE_C_AICOM_FAR_PENALTY = 1000};           //--- flat score penalty applied to any candidate OUTSIDE the frontier radius, so a rich deep city can no longer buy its way over a near contestable town. Large enough to swamp supply spread.
	if (isNil "WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND") then {WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND = 0}; //--- 1 = after N stall blacklists, widen frontier so repick can leave a compressed 5-town front loop (RPT-DEEPDIVE-20260730 WEST spearhead). 0 = dark (default).
	if (isNil "WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND_AFTER") then {WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND_AFTER = 3}; //--- cumulative stall blacklists this war before expand arms (per side logic).
	if (isNil "WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND_RADIUS") then {WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND_RADIUS = 6000}; //--- m: FRONTIER_RADIUS override while expanded (deeper candidates score without full FAR_PENALTY wall).
	if (isNil "WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND_FAR_PENALTY") then {WFBE_C_AICOM_SPEARHEAD_POOL_EXPAND_FAR_PENALTY = 200}; //--- softer off-front penalty while expanded (legacy FAR_PENALTY=1000 kept sides cycling near towns only).
	if (isNil "WFBE_C_AICOM_SOFT_WEIGHT")  then {WFBE_C_AICOM_SOFT_WEIGHT  = 12};            //--- A8: score points SUBTRACTED per garrison hardness tier (wfbe_town_type Tiny=0..Huge=4) so at comparable distance the AI prefers SOFTER towns. Full swing ~48pts (~2.4 town-spacings at DISTANCE_DIVISOR=50); under FAR_PENALTY so front-contiguity is unaffected. 0 = rollback to distance-only.
	if (isNil "WFBE_C_AICOM_GARRISON_PENALTY") then {WFBE_C_AICOM_GARRISON_PENALTY = 0};      //--- Lane-329: Allocate fist scorer penalty per garrison hardness tier; 0 = inert/default-off.
	if (isNil "WFBE_C_AICOM_VALUE_DIVISOR") then {WFBE_C_AICOM_VALUE_DIVISOR = 50};           //--- A8: divisor on the (previously dead) per-town wfbe_town_value (100..1000) -> 2..20 pts; rewards rich towns at comparable distance. Larger = weaker. Clamped to 1 if <=0.
	//--- F5 NEAR-BAND BONUS: if the candidate town is within WFBE_C_AICOM_NEAR_BAND_DIST metres of our nearest
	//--- owned town, add a flat score bonus to boost near-front objectives relative to equally-close but
	//--- higher-supply-value towns further back. Gate flag 0 = inert (default; owner flips to 1 to enable).
	if (isNil "WFBE_C_AICOM_NEAR_BAND") then {WFBE_C_AICOM_NEAR_BAND = 1};                    //--- cmdcon43 Ray-approved flip-ON (near-band bonus): 1 = near-band bonus active, 0 = inert.
	if (isNil "WFBE_C_AICOM_NEAR_BAND_DIST") then {WFBE_C_AICOM_NEAR_BAND_DIST = ((_wfbeAICOMMapRadius * 0.14) max 1000)};       //--- m: candidate must be within this distance of our nearest owned town to earn the bonus. Scales to small maps via CfgWorlds mapSize while preserving pre-set overrides.
	if (isNil "WFBE_C_AICOM_NEAR_BAND_BONUS") then {WFBE_C_AICOM_NEAR_BAND_BONUS = 300};      //--- score points added when the near-band gate passes (additive, after all penalties).
	//--- V0.8 FORCE CONCENTRATION: how many teams pile onto the SAME top-priority town so the
	//--- attack overwhelms the garrison, then roll forward once it flips. Replaces "one team per
	//--- distant town". The per-tier table scales the quota by garrison size (TinyTown needs ~2,
	//--- a HugeTown needs ~5). CONCENTRATION is the global base; the tier table refines per target.
	if (isNil "WFBE_C_AICOM_CONCENTRATION") then {WFBE_C_AICOM_CONCENTRATION = 6};           //--- B57 (Ray 2026-06-20): 4->6 teams massed on the primary spearhead. Towns stay HARD - the AI overwhelms via mass (bigger+more teams), not softer garrisons. Rollback: 4.
	if (isNil "WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX") then {WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX = 2};//--- B61 (Ray 2026-06-21): 1->2 - dispatch fix. 15 teams/side on ONE spearhead overflowed the per-town concentration cap and the surplus idled at base; a 2nd objective gives them somewhere to go (re-task instead of idle). Rollback: 1. [punchy-AICOM 2026-06-17 had set 2->1 for max concentration.]
	//--- B69 (Ray 2026-06-22) HQ-strike finisher + capture interrupt (Patch A).
	if (isNil "WFBE_C_AICOM_HQSTRIKE_TOWN_FRAC")  then {WFBE_C_AICOM_HQSTRIKE_TOWN_FRAC  = 0.5}; //--- own >= this fraction of ALL towns (count towns) to launch/hold the HQ strike = "cap ~half the map first". Replaces the dead literal _myTowns > 8 which never scaled (live map is 40+ towns; WFBE_C_TOWNS_AMOUNT is a town-MODE index, not a count). The 1.5x/1.2x town-ratio + strength gates still apply on top. Rollback: raise FLOOR to 99 or revert the two Strategy.sqf gate lines.
	if (isNil "WFBE_C_AICOM_HQSTRIKE_TOWN_FLOOR") then {WFBE_C_AICOM_HQSTRIKE_TOWN_FLOOR = 3};   //--- absolute min owned towns regardless of fraction (anti-trigger-happy on tiny maps/modes).
	if (isNil "WFBE_C_AICOM_STRIKE_VEH_BONUS")    then {WFBE_C_AICOM_STRIKE_VEH_BONUS    = 100}; //--- punch-score bonus for a strike candidate owning a crewed Tank/APC/Air, so armour/attack-heli (the floor-exempt PUNCH) outrank a full infantry squad in the HQ-strike picker. 0 = raw-bodycount selection.
	if (isNil "WFBE_C_AICOM_CAPTURE_INTERRUPT")   then {WFBE_C_AICOM_CAPTURE_INTERRUPT   = 1};   //--- 1 = a capturing team re-reads a fresh AICOM order within ~8s (breaks out of the camp/depot hold loops) instead of going deaf for up to ~12 min. 0 = old blocking behaviour.
	//--- CAPTURE LOCK (GR-2026-07-03a, capture-churn fix): a team that has fired BEGIN_CAPTURE and is draining a town becomes IMMUNE to
	//--- re-targeting/new orders (the AICOM order ISSUERS skip it via WFBE_CO_FNC_CapLock) until: the town is CAPTURED, the team dies/loses
	//--- viability, the TTL expires (anti-wedge), or the town flips to our side by other means. Root cause of last night's 62-starts/5-finishes
	//--- churn: the ~10-min spearhead repick re-ordered teams that were mid-drain, resetting progress before a town-drain could ever complete.
	//--- CORRECTNESS FIX (repo policy) so default 1 - but keep the kill-switch. 0 = pre-fix behaviour (issuers re-task capturing teams).
	if (isNil "WFBE_C_AICOM_CAPTURE_LOCK")     then {WFBE_C_AICOM_CAPTURE_LOCK     = 1};   //--- 1 = in-drain teams immune to re-orders (default); 0 = kill-switch (old churn behaviour).
	if (isNil "WFBE_C_AICOM_CAPTURE_LOCK_TTL") then {WFBE_C_AICOM_CAPTURE_LOCK_TTL = if (worldName == "Takistan") then {900} else {600}}; //--- s a lock survives before it auto-releases, so a permanently-wedged capturer is never locked forever (re-taskable after this). T1.3a (R3-SYNTHESIS 2026-07-20): TK raised to 900 alongside STALL_ADVANCE_SECS above (>= the TK attempt budget) so the lock does not expire mid-capture on the larger map; CH/ZG stay at the proven 600.
		//--- B61 (Ray 2026-06-21) BASE-GC / RE-ADOPT pass (server_groupsGC.sqf). The base fills with units the
		//--- commander neither counts, re-tasks, nor reaps: untracked live groups + crewed-idle helis/armor whose
		//--- empty-vehicle delete timer is reset while crew is alive (immortal). The base-GC pass RE-ADOPTS untracked
		//--- infantry into the commander (re-task + register + count) and DELETES only idle crewed AIR + abandoned
		//--- hulls, after a continuous idle-at-base timeout. The combat guard + idle-timer ALWAYS apply.
		if (isNil "WFBE_C_BASEGC_ENABLE")       then {WFBE_C_BASEGC_ENABLE       = 1};   //--- 1 = base pass on (default), 0 = inert (only the legacy empty-group GC runs).
		if (isNil "WFBE_C_BASEGC_IDLE_TIMEOUT") then {WFBE_C_BASEGC_IDLE_TIMEOUT = 300}; //--- s a candidate must sit continuously idle-at-base before the pass ACTS; the first-seen stamp resets if it leaves/wakes.
		if (isNil "WFBE_C_BASEGC_RANGE")        then {WFBE_C_BASEGC_RANGE        = 800}; //--- m from a side's own HQ within which untracked groups / idle crewed vehicles are candidates.
		if (isNil "WFBE_C_BASEGC_PLAYER_GUARD") then {WFBE_C_BASEGC_PLAYER_GUARD = 0};   //--- m player-proximity guard (Ray's call: 0 = proximity does NOT block cleanup; if >0, skip a candidate with a player within this many metres).
		if (isNil "WFBE_C_BASEGC_IDLE_SPEED")   then {WFBE_C_BASEGC_IDLE_SPEED   = 5};   //--- a crewed heli/armor moving slower than this (km/h, the 'speed' command) counts as idle-at-base.
		//--- perf-basegc-clamp (2026-07-25, docs/design/SERVER-GROUPSGC-SCAN-COST-AUDIT-2026-07-03.md):
		//--- the BASE-GC combat guard above fires one nearEntities call PER CANDIDATE; default 0 = old
		//--- per-candidate behaviour (fully inert). Armed: one nearEntities snapshot per side per pass,
		//--- taken from the side's own HQ, reused via distance-math for every candidate at/under the
		//--- clamped radius; a candidate beyond the clamp still falls back to a fresh per-candidate scan
		//--- (never a missed enemy, only a smaller cost reduction for that one candidate).
		if (isNil "WFBE_C_BASEGC_SCAN_TIGHTEN")     then {WFBE_C_BASEGC_SCAN_TIGHTEN     = 1};    //--- 1 = armed (snapshot+distance path), 0 = inert (default; original per-candidate nearEntities).
		if (isNil "WFBE_C_BASEGC_SCAN_RADIUS_CEIL") then {WFBE_C_BASEGC_SCAN_RADIUS_CEIL = 1100}; //--- m: hard ceiling on the per-side snapshot's candidate-range component (min'd against WFBE_C_BASEGC_RANGE, then +300 detection buffer). >= the shipped BASEGC_RANGE(800)+300 so armed results match the per-candidate scan exactly at defaults; only a WFBE_C_BASEGC_RANGE raised above this ceiling trades exact coverage for bounded scan cost on the out-of-envelope candidates (see server_groupsGC.sqf fallback).
	//--- B60 MHQ RELOCATION (Ray 2026-06-21, DEFAULT-ON): the commander mobilizes its static HQ into the MHQ,
	//--- an AI driver DRIVES it forward to a standoff behind the front town, then it re-deploys. Safety rails:
	//--- stuck-timer, deadline (player-safe teleport-step fallback), enemy-standoff, always re-deploys (never idle/frozen).
	//--- Set WFBE_C_AICOM_MHQ_RELOCATE = 0 to make it fully inert.
	if (isNil "WFBE_C_AICOM_MHQ_RELOCATE")          then {WFBE_C_AICOM_MHQ_RELOCATE          = 1};    //--- 1 = ON (Ray default), 0 = off (no-op).
	if (isNil "WFBE_C_AICOM_MHQ_RELOCATE_INTERVAL") then {WFBE_C_AICOM_MHQ_RELOCATE_INTERVAL = 180};  //--- s between relocation evaluations per side.
	if (isNil "WFBE_C_AICOM_MHQ_FRONT_DIST")        then {WFBE_C_AICOM_MHQ_FRONT_DIST        = 2500}; //--- m: relocate only once the front (spearhead town) is farther than this from the HQ.
	if (isNil "WFBE_C_AICOM_MHQ_STANDOFF")          then {WFBE_C_AICOM_MHQ_STANDOFF          = 1500}; //--- B74 (Ray 2026-06-22): 800->1500. m: new base sits this far BEHIND the front town (toward the old HQ), capped so it never overshoots.
	if (isNil "WFBE_C_AICOM_MHQ_MIN_ADVANCE")       then {WFBE_C_AICOM_MHQ_MIN_ADVANCE       = 1500}; //--- B74.1 (2026-06-23): 3000->1500. The b74 soak proved 3000 unreachable on Chernarus - the DEEPEST standoff candidate all night was 2790m, so the gate rejected ALL 376 relocations + zeroed _destPos before the new teleport-on-stuck path could help, leaving #9 forward-factory dormant. 1500 admits the real candidates (still far enough to not stack on the old base, which the original 800m moves did).
	if (isNil "WFBE_C_AICOM_MHQ_MINADV_RELAX_SKIP") then {WFBE_C_AICOM_MHQ_MINADV_RELAX_SKIP = 1};    //--- cmdcon-base-unstick: relaxed-ring candidates may be closer than MIN_ADVANCE; 1 = allow them, 0 = preserve the strict gate.
	if (isNil "WFBE_C_AICOM_REBASE_ON")             then {WFBE_C_AICOM_REBASE_ON             = 1};    //--- B74 (Ray 2026-06-22): after an MHQ relocation, (re)build the production factories at the NEW HQ (supply-gated, HQ-local check) so a moved base is not a dead base. 1=on.
	if (isNil "WFBE_C_AICOM_BASE_RADIUS")           then {WFBE_C_AICOM_BASE_RADIUS           = 450};  //--- B74: m radius around the CURRENT HQ within which 'do we already have this factory' is judged, so a forward HQ rebuilds locally instead of counting the OLD base's factories side-wide.
	if (isNil "WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS")    then {WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS    = 12};   //--- B74.1 (Ray 2026-06-23): a side launches the HQ-STRIKE round-ender once it holds this many towns. Replaces the DEAD ceil(count-towns*0.5)=~20 gate (unreachable on Chernarus' 40+ towns; sides peaked at 13), so a dominant side now actually goes for the kill instead of grinding forever. Absolute town count.
	if (isNil "WFBE_C_AICOM_HQSTRIKE_CAP_FRAC")     then {WFBE_C_AICOM_HQSTRIKE_CAP_FRAC     = 0.5};  //--- B74.1 (Ray 2026-06-23): once striking, commit this FRACTION of the side's live field teams to the enemy-HQ assault (was a flat 3). 0.5 = half the army razes the enemy base (HQ+factories => the supremacy/HQ-loss win fires).
	//--- U3 SENSE-MAP-PROFILE (Grok idea #25, perf-sense-map-profile 2026-07-25): extends the AI_Commander_AirResp/DECAP
	//--- per-map sense-radius idiom (worldName-branched CH/TK vs ZG - see WFBE_C_AICOM2_DECAP_SENSE_RADIUS/COMMIT_RADIUS
	//--- above and WFBE_C_AICOM2_AIRRESP_SENSE_RADIUS below, both already per-map) to the one OTHER multi-town
	//--- player-sensing scan in Server/AI/Commander/ that still used a single flat radius on every map:
	//--- WFBE_C_AICOM_RELIEF_ENEMY_DIST (read in AI_Commander_Strategy.sqf x2 + AI_Commander_AssignTowns.sqf x1, each a
	//--- `forEach towns`/per-team nearEntities check for "is this town under attack"). A tighter radius makes the AI
	//--- notice players near a town LATER (fewer relief/hold-defense triggers) - that IS a balance change, not just a
	//--- perf win, so unlike AirResp/DECAP (which shipped unconditionally per-map) this is flag-gated OFF by default
	//--- pending an owner soak.
	if (isNil "WFBE_C_AICOM_SENSE_MAP_PROFILE") then {WFBE_C_AICOM_SENSE_MAP_PROFILE = 0}; //--- master switch. 0 = OFF (default): every gated scan below stays byte-identical to its pre-patch flat value on every map. 1 = per-map profile armed.
	if (isNil "WFBE_C_AICOM_RELIEF_ENEMY_DIST")     then {WFBE_C_AICOM_RELIEF_ENEMY_DIST     = if (WFBE_C_AICOM_SENSE_MAP_PROFILE > 0) then {if (worldName == "Zargabad") then {300} else {if (worldName == "Takistan") then {450} else {500}}} else {500}};  //--- B74.1 (Ray 2026-06-23): a team is only diverted to DEFEND an own town when a live hostile is within this many m of it (REACTIVE defense). Stops the old "too defensive" behaviour of pinning teams to quiet but 'active' (near-front) towns. m. Per-map profile (flag=1): CH 500 (baseline, unchanged) / TK 450 (0.90 ratio, matches the existing 3-tier WFBE_C_AMBIENT_SKIRMISH_RADIUS TK:CH ratio elsewhere in this file) / ZG 300 (0.6 ratio, matches WFBE_C_AICOM2_DECAP_SENSE_RADIUS's ZG:CH ratio above). Flag off (0) = flat 500 everywhere, pre-patch behavior.
	//--- B74.2 (Ray 2026-06-24, directive #3): AI commander gets a CASH boost only, never a SUPPLY boost. Every cash boost
	//--- (updateresources.sqf INCOME_MULT x time-curve + INCOME_STIPEND 6000/9000) already routes through the SEPARATE AICOM
	//--- treasury via ChangeAICommanderFunds. The ONLY synthetic SUPPLY the AI is ever handed (not earned from towns) is the
	//--- V0.7 bootstrap-stipend supply grant in AI_Commander.sqf. This flag drops that supply portion while leaving the bootstrap
	//--- FUNDS grant intact. 0 = no synthetic supply (Ray default), 1 = legacy bootstrap supply trickle. Town supply income
	//--- (the side-wide shared credit at updateresources.sqf SUPPLY_INCOME_MULT) is UNTOUCHED - it funds human commanders + GUER
	//--- too and is already throttled. Note: WFBE_C_AI_COMMANDER_FUNDS_MULT/INCOME_MULT at line 219-223 are CASH multipliers and stay.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_SUPPLY_ENABLE") then {WFBE_C_AICOM_BOOTSTRAP_SUPPLY_ENABLE = 0};
	//--- B74.2 (Ray 2026-06-24, directive #5): AI-commander STRUCTURE-SELL / recycle. When the side is over its redundant-
	//--- structure threshold (or, once item 1/4 lands, over the base/building cap) the commander dismantles its LOWEST-COST
	//--- non-HQ / non-CommandCenter structure, refunding a fraction of the build cost to side SUPPLY (mirrors a human recycle).
	//--- Ships ARMED (1) since 4d16fad70 (2026-06-24, same commit) - Ray armed it immediately rather than shipping dark; see the trailing comment on the flag line below. AI-commander build logic ONLY; humans unaffected.
	if (isNil "WFBE_C_AICOM_BASE_SELL_ENABLE")      then {WFBE_C_AICOM_BASE_SELL_ENABLE      = 1};    //--- 1 = arm the sell worker (Ray armed it), 0 = inert (worker early-exits).
		if (isNil "WFBE_C_AICOM_SELL_STRANDED") then {WFBE_C_AICOM_SELL_STRANDED = 1};  //--- B758 (Ray 2026-06-26): 1 = the sell worker prefers recouping the STRANDED OLD-BASE (structures far from the rebuilt HQ that still have a near copy) after an MHQ relocate, not only >MAX duplicates. 0 = original duplicate-only behaviour.
	if (isNil "WFBE_C_AICOM_BASE_SELL_INTERVAL")    then {WFBE_C_AICOM_BASE_SELL_INTERVAL    = 120};  //--- s between sell evaluations per side (slow; selling is rare).
	if (isNil "WFBE_C_AICOM_SELL_REFUND_FRAC")      then {WFBE_C_AICOM_SELL_REFUND_FRAC      = 0.5};  //--- fraction of the structure's build cost refunded to side SUPPLY on sell (0..1). Never over-refunds (clamped).
	if (isNil "WFBE_C_AICOM_SELL_REDUNDANT_MAX")    then {WFBE_C_AICOM_SELL_REDUNDANT_MAX    = 2};    //--- self-contained trigger (pre-cap): sell only when the side holds MORE than this many DUPLICATE structures of any one sellable type (a 2nd+ Barracks/Light/Heavy/etc). Once item 1/4's base/building cap lands, the cap becomes the primary trigger and this is the floor.
	if (isNil "WFBE_C_AICOM_ARTY_SELL_STRANDED") then {WFBE_C_AICOM_ARTY_SELL_STRANDED = 0}; //--- 1 = BaseSell Pass-3 recycles stranded commander base-artillery (WFBE_CommanderArtillery SPGs not in wfbe_structures) after MHQ relocate so the 2/2 cap can rebuild near the new HQ (RPT-DEEPDIVE-20260730 sec 2.5). 0 = dark (default). AI-commander only.
	if (isNil "WFBE_C_AICOM_ARTY_SELL_STRANDED_DIST") then {WFBE_C_AICOM_ARTY_SELL_STRANDED_DIST = 1500}; //--- m: commander SPG must be farther than this from current HQ to count as stranded (floor = BASE_RADIUS). Wider than factory Pass-1 so echelon-forward guns near the front are less likely to look stranded.
	if (isNil "WFBE_C_AICOM_INCOME_TAPER_TOWNS")    then {WFBE_C_AICOM_INCOME_TAPER_TOWNS    = 8};    //--- B74.1 (Ray 2026-06-23): AICOM income TAPER kicks in above this town count - diminishing per-town funds so a territorial LEADER's treasury can't compound unbounded (soak leader ran to +281k/tick). At/below = full income.
	if (isNil "WFBE_C_AICOM_INCOME_TAPER_RATE")     then {WFBE_C_AICOM_INCOME_TAPER_RATE     = 0.4};  //--- B74.1: each town held ABOVE the taper threshold contributes only this fraction of a normal town's funds. 0.4 = strong damping; 1.0 = no taper. AICOM-ONLY (never touches player income or supply).
	if (isNil "WFBE_C_AICOM_OVERRUN_DIST")          then {WFBE_C_AICOM_OVERRUN_DIST          = 250};  //--- B74.1 (Ray 2026-06-23): a striking side has OVERRUN the enemy base when a strike-team unit is within this many m of the enemy HQ...
	if (isNil "WFBE_C_AICOM_OVERRUN_CLEAR")         then {WFBE_C_AICOM_OVERRUN_CLEAR         = 200};  //--- B74.1: ...AND zero live enemy units remain within this many m of their own HQ. Both => base overrun => raze HQ+factories => supremacy win.
	if (isNil "WFBE_C_AICOM_OVERRUN_RAZE")          then {WFBE_C_AICOM_OVERRUN_RAZE          = 400};  //--- B74.1: on overrun, every enemy production structure within this many m of the enemy HQ is razed (setDamage 1) so factories==0 for the win check.
	//--- B752 (Ray 2026-06-25) AICOM round-closure + spender pass. The 12h soak stalled: HQ-strike flapped off via raw maneuver strength, the "0 enemies left" overrun gate was unsatisfiable vs a 56-body garrison, the veteran override fired ~54% of foundings, and funds ran away to 18M. These tune the fixes in AI_Commander*.sqf + updateresources.sqf.
	if (isNil "WFBE_C_AICOM_OVERRUN_RATIO")         then {WFBE_C_AICOM_OVERRUN_RATIO         = 2};       //--- overrun also fires when strikers outnumber the defenders at the enemy HQ by this ratio (not only at literal 0 enemies).
	if (isNil "WFBE_C_AICOM_OVERRUN_SIEGE_TICKS")   then {WFBE_C_AICOM_OVERRUN_SIEGE_TICKS   = 5};       //--- ...or after this many consecutive ticks with strikers present at the HQ (a grinding siege eventually razes a stubborn garrison so the round can actually close).
	if (isNil "WFBE_C_AICOM_HQSTRIKE_MIN_HOLD")     then {WFBE_C_AICOM_HQSTRIKE_MIN_HOLD     = 600};     //--- s: once HQ_STRIKE posture is entered, hold it at least this long before raw strength is allowed to flap it back off (anti-thrash; the sticky recall in AI_Commander_Strategy.sqf).
	if (isNil "WFBE_C_AICOM_VETERAN_COOLDOWN")      then {WFBE_C_AICOM_VETERAN_COOLDOWN      = 900};     //--- s between veteran/premium-template founds per side (was unconditional => ~54% of teams). Throttles the spend spam + keeps team variety up.
	if (isNil "WFBE_C_AICOM_WEALTH_CAP")            then {WFBE_C_AICOM_WEALTH_CAP            = 1500000}; //--- funds: above this, town income + stipend stop crediting the commander (anti-hoard; the side still has millions to spend, the number just stops ballooning to 18M).

	//--- SERVER-AUTHORITY HARDENING (claude-gaming 2026-06-29): master switch for the flag-gated anti-forgery guards
	//--- (PVF sender/membership validation, ICBM/attack-wave authority, economy ledger). 0 = INERT (every guard short-
	//--- circuits = byte-equivalent legacy behaviour); 1 = ENFORCE (reject forged/abusive requests). Ships DEFAULT-OFF so
	//--- it lands inert with the patch; flip to 1 to soak on the test box + confirm honest play before the public switch.
	//--- Guards live under this flag in Server/PVFunctions/* + Server/Functions/* (DR-55/DR-27/DR-41/economy ledger).
	if (isNil "WFBE_C_SEC_HARDENING")               then {WFBE_C_SEC_HARDENING               = 0};       //--- 1 = enforce anti-forgery guards; 0 = inert (dark). Default 0.

	//--- AICOM FORWARD-ARTY + PARATROOPS + TIERED-AMMO (Ray 2026-06-29: ENABLED). Three AICOM capabilities flipped ON.
	if (isNil "WFBE_C_AICOM_ARTY_REQUIRE_TOWN")     then {WFBE_C_AICOM_ARTY_REQUIRE_TOWN     = 1};       //--- 1 = mobile SPG fires only when within ARTY_TOWN_RANGE of a friendly captured town (Ray: artillery near the front).
	if (isNil "WFBE_C_AICOM_ARTY_TOWN_RANGE")       then {WFBE_C_AICOM_ARTY_TOWN_RANGE       = 300};     //--- metres: how close a captured town centre must be for the SPG to count as supported + clear to fire.
	if (isNil "WFBE_C_AICOM_PARATROOPS_ENABLE")     then {WFBE_C_AICOM_PARATROOPS_ENABLE     = 1};       //--- 1 = AI calls Tactical Center paratroops (ONLY after building the Command Center + researching Paratroopers).
	if (isNil "WFBE_C_AICOM_ARTY_AMMOTYPES_ENABLE") then {WFBE_C_AICOM_ARTY_AMMOTYPES_ENABLE = 1};       //--- 1 = AI arty uses alternate ammo types it has unlocked via WFBE_UP_ARTYAMMO (else HE only).
	if (isNil "WFBE_C_AICOM_RESEARCH_GAP_FIX")      then {WFBE_C_AICOM_RESEARCH_GAP_FIX      = 0};       //--- 1 = add missing UnitCost/AmmoCoin commander research-order entries; 0 = legacy AI_ORDER.

	//--- FUNDS-SINK (claude-gaming 2026-06-29, SYSTEM 1): in AI-vs-AI soak both commanders pin at WFBE_C_AICOM_WEALTH_CAP
	//--- (~1.5M) with NOTHING to spend funds on - units cost funds but the 8-team hard cap blocks more teams, and tech/
	//--- structures cost SUPPLY not funds. So a rich side hoards a meaningless number and rounds never resolve. When armed,
	//--- AI_Commander_FundsSink.sqf (hooked from updateresources.sqf on the income cadence) drains a hoard over THRESHOLD
	//--- into OFFENSE: doubles the Produce batch cap (heavier/fuller existing teams = a heavy push at the spearhead) +
	//--- arms a cooldown-respected veteran/premium founding, and debits a discounted one-off chunk so money converts to
	//--- pressure. Ships DEFAULT-OFF (dark) so Ray can enable + tune in soak. Rationale: convert hoard -> meaningful pressure.
	if (isNil "WFBE_C_AICOM_FUNDS_SINK_ENABLE")     then {WFBE_C_AICOM_FUNDS_SINK_ENABLE     = 1};       //--- 1 = arm the funds-sink worker (owner 2026-07-27). Must match Rsc/Parameters.hpp lobby default — MP Init_Parameters runs first so this isNil only covers SP / missing lobby slot.
	if (isNil "WFBE_C_AICOM_FUNDS_SINK_THRESHOLD")  then {WFBE_C_AICOM_FUNDS_SINK_THRESHOLD  = 1000000}; //--- funds: only drain a commander's hoard ABOVE this (well under the 1.5M WEALTH_CAP, so the drip bites before the cap pins it). Ray 2026-07-27: reverted a proposed 150000 after live data - on the soak box both sides plateau at 180k-330k and EAST was FALLING (299k -> 184k) once the 16-team cap was reached, so 150000 would have drained funds the commander was actively spending. 1M remains correct for the long AI-vs-AI soak this worker targets.
	if (isNil "WFBE_C_AICOM_FUNDS_SINK_DRAIN_PCT")  then {WFBE_C_AICOM_FUNDS_SINK_DRAIN_PCT  = 0.25};    //--- per-tick discounted drain = this fraction of the OVER-THRESHOLD surplus (0.25 = bleed a quarter of the excess each ~60s income tick).
	//--- GUER GUIDED-AT TECHNICAL (fable 2026-07-27, owner request). The SPG-9 technical fires a DUMB
	//--- recoilless round and is AI-patrol-only - it has never been in the GUER player depot. Armed, this
	//--- adds it as a tier-gated depot row AND gives its existing gunner turret a GUIDED AT-5/Konkurs
	//--- launcher alongside the stock tube, so a guerrilla pickup becomes a real tank-killer.
	//--- WHY an ADD and not a swap: the SPG-9 turret WEAPON classname does not appear anywhere in the
	//--- mission tree (only the static/vehicle classes SPG9_Gue etc. do), so a removeWeaponTurret call
	//--- could not be proven and would silently no-op. Both classnames below ARE in-tree (EASA_Init.sqf
	//--- and Server_GuerAirDef.sqf), satisfying the config-proof rule.
	//--- The missile launches from the recoilless tube's existing muzzle memory point - script cannot
	//--- reposition a muzzle, and that origin reads correctly as an improvised launcher.
	if (isNil "WFBE_C_GUER_ATGM_TECHNICAL")        then {WFBE_C_GUER_ATGM_TECHNICAL        = 1};              //--- armed 2026-07-27 owner go. Guided-AT technical (depot row + ATGM) live.
	if (isNil "WFBE_C_GUER_ATGM_TECH_TYPES")       then {WFBE_C_GUER_ATGM_TECH_TYPES       = ["Offroad_SPG9_Gue","Offroad_SPG9_TK_GUE_EP1"]}; //--- both terrains' hulls in one list; each map only ever spawns its own, so no worldName branch is needed.
	if (isNil "WFBE_C_GUER_ATGM_TECH_WEAPON")      then {WFBE_C_GUER_ATGM_TECH_WEAPON      = "AT5Launcher"};  //--- proven pairing with the magazine below (EASA_Init.sqf AT-Strike row).
	if (isNil "WFBE_C_GUER_ATGM_TECH_MAG")         then {WFBE_C_GUER_ATGM_TECH_MAG         = "5Rnd_AT5_BRDM2"};
	if (isNil "WFBE_C_GUER_ATGM_TECH_MAGS")        then {WFBE_C_GUER_ATGM_TECH_MAGS        = 2};              //--- 2 x 5 = 10 missiles. Finite by design: reammo at a service point.
	if (isNil "WFBE_C_GUER_ATGM_TECH_TIER")        then {WFBE_C_GUER_ATGM_TECH_TIER        = 1};              //--- depot tier gate (tier 1 = alongside BRDM-2/T-34, below the T-55).

	if (isNil "WFBE_C_AICOM_FUNDS_SINK_DRAIN_MAX")  then {WFBE_C_AICOM_FUNDS_SINK_DRAIN_MAX  = 120000};  //--- hard ceiling on a single tick's drain so a huge hoard bleeds steadily into push waves, never a one-shot dump.

	//--- ENDGAME SOFT-FORCING (claude-gaming 2026-06-29, SYSTEM 2): after WFBE_C_ENDGAME_FORCE_TIMER minutes of an
	//--- unresolved round, apply an ESCALATING global economic taper (gradual income shrink) so turtling becomes
	//--- unsustainable and a side must commit to a confrontation - WITHOUT sim/distance-gating, freezing, teleporting,
	//--- or touching antistack (Ray hard constraints). The timer is checked in server_victory_threeway.sqf (already on a
	//--- cadence); the taper multiplier it publishes is applied to AICOM town income in updateresources.sqf. Ships
	//--- DEFAULT-OFF. Rationale: a 5-6h marathon had breakthroughs but no round-end because each side refills faster than
	//--- the other can close; a shrinking economic base forces the issue. Mechanism is Ray's morning pick (see openQuestions).
	if (isNil "WFBE_C_ENDGAME_FORCE_ENABLE")        then {WFBE_C_ENDGAME_FORCE_ENABLE        = 0};       //--- 1 = arm the soft-forcing taper; 0 = inert. Default 0 (dark).
	if (isNil "WFBE_C_ENDGAME_FORCE_TIMER")         then {WFBE_C_ENDGAME_FORCE_TIMER         = 90};      //--- minutes of UNRESOLVED round before the taper begins escalating (mission 'time' based).
	if (isNil "WFBE_C_ENDGAME_FORCE_TAPER_STEP")    then {WFBE_C_ENDGAME_FORCE_TAPER_STEP    = 0.04};    //--- per-MINUTE income reduction once the timer passes (0.04 = lose 4%/min of the global income multiplier, escalating).
	if (isNil "WFBE_C_ENDGAME_FORCE_TAPER_FLOOR")   then {WFBE_C_ENDGAME_FORCE_TAPER_FLOOR   = 0.10};    //--- the income multiplier never tapers below this fraction (0.10 = a starved 10% trickle so the war never freezes outright).

	//=== AI COMMANDER v2 (REBUILD, branch claude/aicom-v2-rebuild) =====================================
	//--- Layout constants for the world-model SNAPSHOT array (AI_Commander_Snapshot.sqf -> side-logic
	//--- var wfbe_aicom2_snap), read by the v2 stance machine + objective allocator + closer. Fixed
	//--- layout, defined once at boot, global. Direct assignment (enum-style, like WFBE_UP_*).
	WFBE_SNAP_TIME=0; WFBE_SNAP_SIDE=1; WFBE_SNAP_SIDEID=2; WFBE_SNAP_ENSIDE=3; WFBE_SNAP_ENID=4;
	WFBE_SNAP_MYTOWNS=5; WFBE_SNAP_ENTOWNS=6; WFBE_SNAP_NEUTOWNS=7; WFBE_SNAP_TOTTOWNS=8;
	WFBE_SNAP_MYSTR=9; WFBE_SNAP_ENSTR=10; WFBE_SNAP_MYEFF=11; WFBE_SNAP_ENEFF=12;
	WFBE_SNAP_MYHQ=13; WFBE_SNAP_MYHQPOS=14; WFBE_SNAP_MYHQALIVE=15;
	WFBE_SNAP_ENHQ=16; WFBE_SNAP_ENHQPOS=17; WFBE_SNAP_ENHQALIVE=18;
	WFBE_SNAP_FUNDS=19; WFBE_SNAP_SUPPLY=20; WFBE_SNAP_PLAYERS=21; WFBE_SNAP_MYPLAYERS=22;
	WFBE_SNAP_TEAMS=23; WFBE_SNAP_OWNTOWNOBJS=24; WFBE_SNAP_TGTTOWNOBJS=25;
	//--- per-team digest layout (each element of WFBE_SNAP_TEAMS). WFBE_SNT_REPORT = HC-driver-reported
	//--- execution facts, filled by the upward team-status channel (M1); [] until then.
	WFBE_SNT_GROUP=0; WFBE_SNT_ALIVE=1; WFBE_SNT_LDRPOS=2; WFBE_SNT_ISHC=3; WFBE_SNT_ISFOUND=4;
	WFBE_SNT_ISGAR=5; WFBE_SNT_MODE=6; WFBE_SNT_STRIKE=7; WFBE_SNT_RELIEF=8;
	WFBE_SNT_HASGNDVEH=9; WFBE_SNT_MOUNTEDNOW=10; WFBE_SNT_HASHEAVY=11; WFBE_SNT_REPORT=12;
	//--- M1 single-authority Allocator (AI_Commander_Allocate.sqf). 0 = inert (legacy Strategy/AssignTowns
	//--- targeting runs unchanged = instant rollback); 1 = the Allocator concentrates force on a front fist.
	if (isNil "WFBE_C_AICOM2_ALLOCATE_ENABLE") then {WFBE_C_AICOM2_ALLOCATE_ENABLE = 1};  //--- v2try (Ray 2026-06-27): brain ON for the live try-out. Rollback = set back to 0 (legacy targeting, instant).
	if (isNil "WFBE_C_AICOM2_FIST_TOWNS")      then {WFBE_C_AICOM2_FIST_TOWNS      = 2};  //--- front towns the side concentrates on at once. cmdcon41 SPREAD: 1 -> 2 (1 = STEAMROLLER caused the live 7-teams-on-one-town dogpile; 2-3 = spread front, pairs with WFBE_C_AICOM2_FIST_PERTOWN).
	if (isNil "WFBE_C_AICOM2_HARASS_TEAMS")    then {WFBE_C_AICOM2_HARASS_TEAMS    = 0};  //--- M2: how many (mounted) teams peel off the fist to raid the enemy's deepest REAR town (supply hub). 0 = pure concentration. [Ray-dir 2026-07-24 FOCUS-FRONTS: 1->0 (no lone rear-raid team that gets ground down); rollback 1.]
	//--- FIX C: DOMINANT-SIDE PRESS FLOOR, V2 (fable, GR-2026-07-08a; design ASSAULT-DYNTIMEOUT-DESIGN.md + ADDENDUM 1).
	//--- Re-pointed from the original V1 Strategy.sqf DOMINANT_PRESS draft: V2's Allocator overwrites V1's
	//--- wfbe_aicom_targets almost every tick, so a Strategy-side floor never reaches live target selection - this
	//--- lives inside AI_Commander_Allocate.sqf's fist/target-scoring block instead. Own-metrics only
	//--- (WFBE_SNAP_MYEFF/ENEFF - same maneuver+held-town formula Strategy.sqf/Snapshot.sqf already compute).
	//--- AMPLIFIES pressing only - never caps/dampens the weaker side (owner: FULL AGGRESSION, do not balance).
	//--- 0 = fully inert (byte-identical).
	if (isNil "WFBE_C_AICOM_PRESS_FLOOR_V2")     then {WFBE_C_AICOM_PRESS_FLOOR_V2     = 1};
	if (isNil "WFBE_C_AICOM2_PRESS_DOM_RATIO")   then {WFBE_C_AICOM2_PRESS_DOM_RATIO   = 1.15}; //--- myEff >= enEff * this (AND myTowns >= enTowns) required to arm. Below WFBE_C_AICOM2_DECAP_DOM_RATIO(1.5) - this is a scoring nudge, not a full commit. ENGINEERING DEFAULT, soak-tune.
	if (isNil "WFBE_C_AICOM2_PRESS_ENEMY_BONUS") then {WFBE_C_AICOM2_PRESS_ENEMY_BONUS = 400};  //--- score bonus added to ENEMY-held candidate towns in the AUTO scorer while dominant (same magnitude scale as the existing _nearBandBonus=300 / _repickPen=500). 0 = bonus off.
	if (isNil "WFBE_C_AICOM2_PRESS_ENGAGE_BYPASS") then {WFBE_C_AICOM2_PRESS_ENGAGE_BYPASS = 1}; //--- while dominant, skip the expansion-first neutral-only gate even below WFBE_C_AICOM_ENGAGE_MIN_TOWNS. 0 = keep the gate (dominance only affects scoring, not the gate).
	//--- Tier 2 / OPTIONAL / stretch (default 0 = off): extra concentrated fist-town slots while dominant. Higher
	//--- blast radius than the scoring bonus (more teams committed = more concentration-cap/route-congestion
	//--- interaction) - recommend soaking Tier 1 (above) alone first per the design's Section 4.3 staged rollout.
	if (isNil "WFBE_C_AICOM2_PRESS_FIST_BONUS")  then {WFBE_C_AICOM2_PRESS_FIST_BONUS  = 0};
	//--- M5 DECAPITATE closer (AI_Commander_Decapitate.sqf). The missing kill-move: when a side is DECISIVELY
	//--- ahead and the enemy is collapsing, commit the fist onto the enemy HQ and PRESS until it is razed,
	//--- instead of the current rally-and-hold that froze the 2026-07-04 ZG match 2-7-2 for 90 min. DEFAULT 0
	//--- (inert; byte-identical to HEAD; the closer only reads the snapshot + emits telemetry when off). 1 = armed.
	if (isNil "WFBE_C_AICOM2_DECAP_ENABLE")      then {WFBE_C_AICOM2_DECAP_ENABLE      = 1};
	if (isNil "WFBE_C_AICOM2_DECAP_DOM_RATIO")   then {WFBE_C_AICOM2_DECAP_DOM_RATIO   = 1.5};  //--- ARM only while myEff >= enEff * this (decisive maneuver dominance, not a coin-flip edge).
	if (isNil "WFBE_C_AICOM2_DECAP_ABORT_RATIO") then {WFBE_C_AICOM2_DECAP_ABORT_RATIO = 0.9};  //--- once COMMITTED, only abort if myEff < enEff * this (wide hysteresis a momentary garrison dip cannot cross).
	if (isNil "WFBE_C_AICOM2_DECAP_MAX_ENTOWNS") then {WFBE_C_AICOM2_DECAP_MAX_ENTOWNS = 5};    //--- SECONDARY safety only (owner Q1 2026-07-06: demoted from primary trigger, was 2): even when sensed + dominant, no commit while the enemy holds more than this many towns.
	if (isNil "WFBE_C_AICOM2_DECAP_MAPRELATIVE") then {WFBE_C_AICOM2_DECAP_MAPRELATIVE = 0}; //--- default 0 retains the absolute MAX_ENTOWNS ceiling; 1 scales it to the live snapshot town count.
	if (isNil "WFBE_C_AICOM2_DECAP_MAX_ENTOWNS_FRAC") then {WFBE_C_AICOM2_DECAP_MAX_ENTOWNS_FRAC = 0.4}; //--- armed profile: ceil(total capturable towns * fraction), so a 40-town Chernarus round permits the closer at <=16 enemy towns.
	if (isNil "WFBE_C_AICOM2_DECAP_ARM_TICKS")   then {WFBE_C_AICOM2_DECAP_ARM_TICKS   = 3};    //--- consecutive dominant strategy ticks required to ARM -> COMMIT (durability latch; blocks single-tick effective-strength gaming).
	if (isNil "WFBE_C_AICOM2_DECAP_MIN_COMMIT")  then {WFBE_C_AICOM2_DECAP_MIN_COMMIT  = 300};  //--- seconds a COMMITTED decap must persist before an ABORT is even considered (stops flap; the siege counter needs time to accrue).
	//--- ORGANIC BASE SENSING (owner Q1 2026-07-06): the closer must not ACT on global HQ knowledge. A ground
	//--- team must organically come near the enemy base, then a periodic dice roll must succeed, before the
	//--- latch may even start arming. Per-map radius follows the standard worldName idiom below.
	if (isNil "WFBE_C_AICOM2_DECAP_SENSE_RADIUS")   then {WFBE_C_AICOM2_DECAP_SENSE_RADIUS   = if (worldName == "Zargabad") then {3000} else {5000}}; //--- m: an eligible offensive team leader must reach this wider approach band to establish organic sensing (5000 CH/TK, 3000 ZG); the smaller commit radius below still scopes the HQ press.
	if (isNil "WFBE_C_AICOM2_DECAP_SENSE_INTERVAL") then {WFBE_C_AICOM2_DECAP_SENSE_INTERVAL = 4};    //--- strategy ticks between dice rolls (~4 min at the 60s cadence). No roll, no ARM progress.
	if (isNil "WFBE_C_AICOM2_DECAP_SENSE_CHANCE")   then {WFBE_C_AICOM2_DECAP_SENSE_CHANCE   = 0.35}; //--- chance a due dice roll latches "sensed" while a team is in range (random 1 < this; A2-safe).
	if (isNil "WFBE_C_AICOM2_DECAP_COMMIT_RADIUS")  then {WFBE_C_AICOM2_DECAP_COMMIT_RADIUS  = if (worldName == "Zargabad") then {2000} else {3000}}; //--- m: on COMMIT only teams with a leader inside this tighter HQ band are stamped to press; distant teams keep their town orders.

	//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): "The Long Memory" A-Life feature - see docs/design/GRUDGE-DESIGN.md
	if (isNil "WFBE_C_AICOM_GRUDGE")                then {WFBE_C_AICOM_GRUDGE                = 1};     //--- master switch. 0 = inert (no stamping, no scorer bonus, no sub-options). 1 = armed.
	if (isNil "WFBE_C_AICOM_GRUDGE_BONUS")          then {WFBE_C_AICOM_GRUDGE_BONUS          = 400};   //--- flat score bonus for a live grudge site in BOTH scorers (calibration: NEAR_BAND_BONUS=300, FAR_PENALTY=1000).
	if (isNil "WFBE_C_AICOM_GRUDGE_DECAY")          then {WFBE_C_AICOM_GRUDGE_DECAY          = 2400};  //--- seconds a grudge site stays live before pruning (same prune-on-read idiom as SIDE_BLACKLIST_COOLDOWN).
	if (isNil "WFBE_C_AICOM_GRUDGE_MAX_SITES")      then {WFBE_C_AICOM_GRUDGE_MAX_SITES      = 3};     //--- cap on concurrent live grudge sites per side; oldest dropped first.
	if (isNil "WFBE_C_AICOM_GRUDGE_RELIEF_TRIGGER") then {WFBE_C_AICOM_GRUDGE_RELIEF_TRIGGER = 0};     //--- 0 = only offensive failures (SIDE_BLACKLIST, DECAP ABORT) stamp a grudge; 1 = also RELIEF_TOWN_LOST (defensive loss, opt-in).
	if (isNil "WFBE_C_AICOM_GRUDGE_BARRAGE")        then {WFBE_C_AICOM_GRUDGE_BARRAGE        = 0};     //--- SUB-OPTION, own flag. 1 = one-shot prep barrage on first return-dispatch to a grudge town via the existing AICOM arty pipeline. Still requires WFBE_C_AI_COMMANDER_ARTILLERY>0 and WFBE_C_ARTILLERY>0.

	//--- M6 AIRRESP (AI_Commander_AirResp.sqf): organic W/E air-response closer, sibling to M5 DECAPITATE. Dispatches
	//--- bounded air-response flights onto a lane already surfaced by the Allocator fist or the town-activation FSM
	//--- (never a fresh whole-map scan) - see docs/design/v2/AICOM-AIR-GROUND-RESPONSE-SPEC-2026-07-07.md. OWNER
	//--- DIRECTIVE 2026-07-08: ships ARMED (default 1), NOT the shadow/default-0 convention the design spec proposed -
	//--- this changes live AI air behaviour once merged+deployed; needs a T3 soak before the owner ships it further.
	if (isNil "WFBE_C_AICOM2_AIRRESP_ENABLE")        then {WFBE_C_AICOM2_AIRRESP_ENABLE        = 1};    //--- master switch. 1 = armed (owner override). 0 = shadow (sensing+telemetry only, no dispatch) for instant rollback.
	if (isNil "WFBE_C_AICOM2_AIRRESP_SENSE_RADIUS")   then {WFBE_C_AICOM2_AIRRESP_SENSE_RADIUS   = if (worldName == "Zargabad") then {1800} else {2500}}; //--- m: per-town nearEntities scan radius for enemy-side players (2500 CH/TK, 1800 dense-urban ZG - mirrors the DECAP per-map ratio).
	if (isNil "WFBE_C_AICOM2_AIRRESP_SENSE_INTERVAL") then {WFBE_C_AICOM2_AIRRESP_SENSE_INTERVAL = 3};    //--- strategy ticks between dice rolls (~3min at the 60s cadence - faster than the 30min Wildcard slot). No roll, no dispatch.
	if (isNil "WFBE_C_AICOM2_AIRRESP_SENSE_CHANCE")   then {WFBE_C_AICOM2_AIRRESP_SENSE_CHANCE   = 0.5};  //--- chance a due dice roll latches "sensed" while a candidate lane has in-range enemy players (random 1 < this; A2-safe).
	if (isNil "WFBE_C_AICOM2_AIRRESP_MAX_AIR")        then {WFBE_C_AICOM2_AIRRESP_MAX_AIR        = 2};    //--- global alive-cap on AICOM2-maneuver response flights per side. Separate budget from Wildcard's one-shots (W6/W13/W19/W22) and from WFBE_C_GUER_AIRDEF_MAX (a different side's economy).
	if (isNil "WFBE_C_AICOM2_AIRRESP_LOITER_TIME")    then {WFBE_C_AICOM2_AIRRESP_LOITER_TIME    = 240};  //--- s a response flight stays on its lane before self-despawn/recycle; also the watchdog's hard ceiling even while the lane stays hot.
	//--- WFBE_C_AICOM_AIR_MIN_TOWNS is already registered above (Init_CommonConstants.sqf:370, default 3) and shared with W6/W13 Wildcard eligibility - AIRRESP reuses it as-is, no re-registration.
	//--- claude/u2-airresp-poscache (Grok idea #7, PERF): AIRRESP's per-tick sense pass issues one nearEntities
	//--- spatial query per candidate lane town (Allocator fist target(s) + activated own towns), every strategy
	//--- tick, per side. 0 = off (default, byte-identical to HEAD: the nearEntities path runs verbatim). 1 =
	//--- AIRRESP snapshots the enemy side's qualifying entity positions ONCE at closer entry (AirResp already
	//--- runs exactly once per commander strategy tick) and distance-tests every candidate against that cached
	//--- array instead - same qualifying-entity definition + same SENSE_RADIUS cutoff, so target selection is
	//--- unchanged; only the scan mechanism differs. Cache staleness within one tick is acceptable by design
	//--- (players move <100m/tick at the ~60s strategy cadence). Read in AI_Commander_AirResp.sqf.
	if (isNil "WFBE_C_AICOM_AIRRESP_POS_CACHE") then {WFBE_C_AICOM_AIRRESP_POS_CACHE = 0};

	//--- M7 AICOM2 AIRSTRIKE (AI_Commander_AirStrike.sqf): owner directive 2026-07-25 ("make sure ai commander
	//--- jets / helicopters may target factories") - new, additive AICOM2 closer, NOT a flag flip of anything
	//--- dormant (both diag-air-vs-factories.md and diag-decap-idle.md confirmed no existing mechanism lets air
	//--- target a structure at all; DECAP is ground-only and hard-gated on the ENEMY HQ being alive, so it
	//--- structurally cannot raze a survivor's factories once that HQ is already dead). SHADOW-FIRST default 0
	//--- (opposite of AIRRESP's owner-armed default) - this is a new HIGH-RISK core-AICOM lane and needs a soak
	//--- before the owner arms it, same convention as DECAP.
	if (isNil "WFBE_C_AICOM2_AIRSTRIKE_ENABLE")   then {WFBE_C_AICOM2_AIRSTRIKE_ENABLE   = 1};    //--- master switch. 0 = shadow (telemetry only, no dispatch) - DEFAULT. 1 = armed.
	if (isNil "WFBE_C_AICOM2_AIRSTRIKE_COOLDOWN") then {WFBE_C_AICOM2_AIRSTRIKE_COOLDOWN = 900};  //--- s: per-side minimum gap between AI-initiated factory-strike dispatch attempts (cannot spam). Stamped only on an actual successful dispatch.
	if (isNil "WFBE_C_AICOM2_AIRSTRIKE_MAX_AIR")  then {WFBE_C_AICOM2_AIRSTRIKE_MAX_AIR  = 1};    //--- global alive-cap on AICOM2 factory-strike flights per side - deliberately smaller/separate from AIRRESP_MAX_AIR(2) so a factory hunt never crowds out AIRRESP's player-response role. Still bounded by the side-wide AIR_MAX_TOTAL/AIR_MAX_LATE headroom check on top of this.
	if (isNil "WFBE_C_AICOM2_AIRSTRIKE_HOLD")     then {WFBE_C_AICOM2_AIRSTRIKE_HOLD     = 360};  //--- s a dispatched strike flight keeps re-picking + reveal/doTarget/doFire-ing the nearest live enemy factory before self-despawn; mirrors WFBE_C_AICOM_ASSAULT_HOLD (the ground BASE-ASSAULT fire phase's own hold ceiling).
	if (isNil "WFBE_C_AICOM2_AIRSTRIKE_SAD")      then {WFBE_C_AICOM2_AIRSTRIKE_SAD      = 150};  //--- m: SAD waypoint radius laid under the current strike target each tick so the flight is never idle (mirrors WFBE_C_AICOM_ASSAULT_SAD, widened for an airborne SAD).
	//--- WFBE_C_AICOM_AIR_MAX_TOTAL / _AIR_MAX_LATE / _AIR_LATE_MINS (Init_CommonConstants.sqf:474,1061,1062) and
	//--- WFBE_C_AIR_ATTACK_GUNNER are already registered elsewhere and reused as-is by AIRSTRIKE - no re-registration.


	//--- D7 AICOM FEINT: AI commander occasionally dispatches a small feint team toward a
	//--- NON-target enemy town, then recalls it, to pressure the enemy rear and split attention.
	//--- All three constants are inert while FEINT_ENABLE=0 (default). No gameplay effect at 0.
	if (isNil "WFBE_C_AICOM_FEINT_ENABLE")   then {WFBE_C_AICOM_FEINT_ENABLE   = 0};   //--- 0 = off (dark). Set to 1 to arm feint dispatch.
	if (isNil "WFBE_C_AICOM_FEINT_INTERVAL") then {WFBE_C_AICOM_FEINT_INTERVAL = 600}; //--- s between feint dispatches per side (per-side cooldown).
	if (isNil "WFBE_C_AICOM_FEINT_DUR")      then {WFBE_C_AICOM_FEINT_DUR      = 120}; //--- s a feint team holds at the feint town before recall to the fist.
	if (isNil "WFBE_C_AICOM2_EXPAND_TEAMS")    then {WFBE_C_AICOM2_EXPAND_TEAMS    = 1};  //--- Ray 2026-06-28: up to N teams divert to capture the nearest reachable NEUTRAL town instead of all-in on the fist (issue: 42/46 towns sat neutral). 0 = off (restores fist-only). [Ray-dir 2026-07-24 FOCUS-FRONTS: 3->1 (keep ONE neutral-grab so the map does not sit empty, but stop the 3-6 team sprawl that gets ground down and floods dispatch); rollback 3.]
	if (isNil "WFBE_C_AICOM_EXPAND_DEDUP")     then {WFBE_C_AICOM_EXPAND_DEDUP     = 1};  //--- Ray 2026-07-04: ON for live testing. block-m: 0=off legacy (multiple expand teams may dogpile one neutral town); 1=each expand team claims a distinct neutral town per tick (DEDUP).
	if (isNil "WFBE_C_AICOM_HARASS_FALLBACK")  then {WFBE_C_AICOM_HARASS_FALLBACK  = 1};  //--- Ray 2026-07-04: ON for live testing. block-m: 0=off legacy (harass picks deepest town regardless of reach); 1=walk depth-sorted candidates and pick deepest reachable by >=1 mounted team (emits AICOMSTAT|v2|EVENT|HARASS_SKIP when first candidate is unreachable).
	if (isNil "WFBE_C_AICOM_ENGAGE_MIN_TOWNS") then {WFBE_C_AICOM_ENGAGE_MIN_TOWNS = 10};//--- Ray 2026-06-28 EXPANSION-FIRST: a commander captures NEUTRAL towns only (fist+harass) until it OWNS this many towns, THEN it attacks the enemy - so both sides build an empire before they clash (no early enemy-rush that ends matches premature). ANTI-STALL: if no neutral town remains reachable it engages the enemy anyway. Round-ender HQ-strike keeps its own higher gate (WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS). 0 = disable (engage from turn one).
	//--- BUG-1 CONTESTED-ENGAGE (fable GR-2026-07-03a): lift the EXPANSION-FIRST neutral-only gate when the ENEMY is at
	//--- town-parity-or-ahead AND holds >=1 town, so a side stalled below ENGAGE_MIN (the 9.6h ZG soak: WEST never
	//--- targeted EAST-held towns for 9.5h) fights the enemy instead of wandering the neutral rear. Read in
	//--- AI_Commander_Allocate.sqf. WEST=0-safe (only town COUNT compares). 0 = legacy expansion-first (instant rollback).
	if (isNil "WFBE_C_AICOM_ENGAGE_CONTESTED") then {WFBE_C_AICOM_ENGAGE_CONTESTED = 1};
	//--- BUG-2 SPEARHEAD REPICK-PENALTY (fable GR-2026-07-03a): anti-dogpile diversity lever. A town that was the published
	//--- fist primary within the last REPICK_MEMORY_MIN minutes takes this flat score penalty in the Allocator's auto-scorer,
	//--- so the commander ROTATES pressure instead of dogpiling 1-2 central towns (the soak: EAST sent 60% of orders to 2
	//--- towns, 176 repicks cycled the same short list). ~half the FAR_PENALTY (1000) scale = meaningful but not dominant.
	//--- 0 = off (no penalty; also disables the memory stamp). Read in AI_Commander_Allocate.sqf.
	if (isNil "WFBE_C_AICOM_REPICK_PENALTY")    then {WFBE_C_AICOM_REPICK_PENALTY    = 500};
	if (isNil "WFBE_C_AICOM_REPICK_MEMORY_MIN") then {WFBE_C_AICOM_REPICK_MEMORY_MIN = 5};   //--- minutes a picked primary stays penalised.
	//--- WO-6 SOFTEST-LANE PUSH (fable, GR-2026-07-07a): AICOM-V2-UNIT-MICRO-LAYER-SPEC WO-6. After a detected
	//--- town LOSS for a side, additively boost neutral/GUER-only capturable towns' scores in the Allocator's
	//--- AUTO scorer (AI_Commander_Allocate.sqf) for AICOMV2_SOFTLANE_TICKS strategy ticks, so the commander
	//--- leans toward the least-defended next target ("softest lane") rather than the obvious counter-attack on
	//--- the town it just lost. Layered onto the existing REPICK_PENALTY scorer term, not a replacement for it.
	//--- Default bonus 0 = fully inert (byte-identical decision output; the loss-detection block itself is also
	//--- gated on bonus>0, so at 0 there is no extra state read/write either). Owner can arm by raising the bonus
	//--- toward the WFBE_C_AICOM_REPICK_PENALTY/FAR_PENALTY scale (500-1000) once soaked; tune here, not in code.
	if (isNil "AICOMV2_SOFTLANE_BONUS") then {AICOMV2_SOFTLANE_BONUS = 0};
	if (isNil "AICOMV2_SOFTLANE_TICKS") then {AICOMV2_SOFTLANE_TICKS = 3};   //--- strategy ticks (WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL each) the post-loss bonus window stays active.
	if (isNil "WFBE_C_AICOM_CONCENTRATE_TOWNS") then {WFBE_C_AICOM_CONCENTRATE_TOWNS = 8};//--- Ray 2026-06-28 CONCENTRATE-FIRST: while a commander owns FEWER than this many towns it puts its FULL strength on ONE fist town (no expand/harass split) - a true opening steamroller. Once it owns this many, the normal expand(EXPAND_TEAMS)+harass spread resumes. 0 = off (spread from town one). [Ray-dir 2026-07-24 FOCUS-FRONTS: 4->8 (hold the concentrated opening far longer before spreading); rollback 4.]
	if (isNil "WFBE_C_AICOM_DISBAND_LOWTIER_ENABLE") then {WFBE_C_AICOM_DISBAND_LOWTIER_ENABLE = 1};//--- Ray 2026-06-28: retire idle rear FOOT-infantry teams once the side fields mobile (light/heavy/air) teams - keeps force modern + frees pop/group cap for armour. 0 = off.
	if (isNil "WFBE_C_AICOM_DISBAND_LOWTIER_INTERVAL") then {WFBE_C_AICOM_DISBAND_LOWTIER_INTERVAL = 600};//--- seconds between low-tier disband passes (at most ONE team retired per pass). Dedicated operator knob; DISBAND_INTERVAL remains for shared/full disband pacing.
	if (isNil "WFBE_C_AICOM_DISBAND_INTERVAL") then {WFBE_C_AICOM_DISBAND_INTERVAL = 300};//--- seconds between disband passes (at most ONE team retired per pass) - long for immersion.
	if (isNil "WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR") then {WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR = 2};//--- never disband below this many FOOT teams/side (keep a footprint). 3->2: with the 8-team cap a side rarely holds >3 foot teams so disband never fired.
	if (isNil "WFBE_C_AICOM_PHASE_ENABLE") then {WFBE_C_AICOM_PHASE_ENABLE = 1}; //--- AI-BEHAVIOR-LOOP-DESIGN.md sec1: per-team phase-state var wfbe_aicom_phase (MARCH/CAMP_SWEEP/CENTER_PUSH/CONSOLIDATE/NEXT_TARGET), stamped HC-side in Common_RunCommanderTeam.sqf at 5 existing choke points. 0 = off: var never written/read anywhere, zero behavior change.
	if (isNil "WFBE_C_AICOM_DWELL_ENABLE") then {WFBE_C_AICOM_DWELL_ENABLE = 1}; //--- AI-BEHAVIOR-LOOP-DESIGN.md sec2: cumulative per-team-per-town dwell clock (wfbe_aicom_dwell_town0), surviving a RELEASE->repick-same-town cycle, consumed as a 4th sibling abandon trigger in AI_Commander_AssignTowns.sqf. 0 = off: var never stamped, existing 3-trigger abandon ladder untouched.
	if (isNil "WFBE_C_AICOM_DWELL_MAX_SECS") then {WFBE_C_AICOM_DWELL_MAX_SECS = 900}; //--- AI-BEHAVIOR-LOOP-DESIGN.md sec2.3: OWNER-TUNABLE. Cumulative dwell ceiling (s) before DWELL_ABANDON fires - engineering default = 2x WFBE_C_AICOM_ASSAULT_HOLD (720s worst-case camp-first+depot-hold) + headroom, NOT soak-calibrated. Only consulted when WFBE_C_AICOM_DWELL_ENABLE=1.
	if (isNil "WFBE_C_AICOM_WEAKTEAM_ENABLE") then {WFBE_C_AICOM_WEAKTEAM_ENABLE = 1}; //--- AI-BEHAVIOR-LOOP-DESIGN.md sec3: widens AI_Commander_DisbandLowTier.sqf's idle-candidate test to also catch an attrited (<=WFBE_C_AICOM_BREAKOFF_MIN live units) mobile-team remnant of ANY type for disband-refund. 0 = off: candidate test stays exactly _typeIdx==0 (byte-identical foot-only culling).
	if (isNil "WFBE_C_AICOM_DISBAND_COOLDOWN") then {WFBE_C_AICOM_DISBAND_COOLDOWN = 900};//--- claude-gaming 2026-06-30 (Ray): PLAYER-COMMANDER disband-ALL failsafe (Command Console button) - min seconds between full AI-field-team disbands, per side. Reuses the wfbe_aicom_disband path; the HC destroys each team unconditionally (owner ruling 2026-07-22: destructive retire, vetoes removed).
	if (isNil "WFBE_C_AICOM2_SUPPORT_PUSH")    then {WFBE_C_AICOM2_SUPPORT_PUSH    = 1};  //--- M5: 1 = when humans are on the side, bias the fist toward where they're massed (support their push). 0 = always auto-pick the front.
	if (isNil "WFBE_C_AICOM2_SUPPORT_DIVISOR") then {WFBE_C_AICOM2_SUPPORT_DIVISOR = 50}; //--- M5: strength of the pull toward the human axis (smaller = stronger pull).
	if (isNil "WFBE_C_AICOM2_FOCUS_TTL")       then {WFBE_C_AICOM2_FOCUS_TTL       = 600};//--- M4: s a commander FOCUS town stays in force before it auto-clears (so a forgotten focus doesn't tunnel-vision the AI forever).
	if (isNil "WFBE_C_AICOM2_CONSOLIDATE_SECS") then {WFBE_C_AICOM2_CONSOLIDATE_SECS = 60}; //--- Ray: after the fist CAPTURES its town, hold ~this long (regroup at it) before advancing to the next. 0 = relentless roll-forward, no pause.
	//--- COMMAND-CENTER "AI COMMANDER" INSTRUCTION PANEL (PR1): a non-commander player can read the AI commander's
	//--- intent and hand it Focus-Attack / Defend-Town / Artillery-Here orders from the WF menu (Client\GUI\GUI_Menu_Command.sqf,
	//--- the 4th sub-tab). These ride the existing RequestSpecial channel (aicom-focus/aicom-defend/aicom-arty-here).
	if (isNil "WFBE_C_AICOM_ORDER_COOLDOWN")   then {WFBE_C_AICOM_ORDER_COOLDOWN   = 8};   //--- s client cooldown between AI-commander instructions (anti-spam; stamped client-side in the menu loop).
	if (isNil "WFBE_C_AICOM_DEFEND_TTL")       then {WFBE_C_AICOM_DEFEND_TTL       = 300}; //--- s a player-set DEFEND-town order stays fresh; the Strategy relief block biases a reliever to it while fresh, then it auto-clears.
	if (isNil "WFBE_C_AICOM_ARTY_REQUEST_TTL") then {WFBE_C_AICOM_ARTY_REQUEST_TTL = 120}; //--- s a player-set ARTILLERY-HERE request stays fresh for the brain's artillery block to consume (then ignored).
	//--- COMMAND CONSOLE (full rework): extra TTL knobs the new "Command" console orders ride. Backend (Server_HandleSpecial)
	//--- reads these for the aicom-reinforce / aicom-posture / aicom-request-unit stamps. Donate amounts are client-supplied and server-validated.
	if (isNil "WFBE_C_AICOM_REINFORCE_TTL")    then {WFBE_C_AICOM_REINFORCE_TTL    = 300}; //--- s a player-set REINFORCE-HERE order stays fresh; Strategy biases a fresh team toward that town while live, then it auto-clears.
	if (isNil "WFBE_C_AICOM_POSTURE_TTL")      then {WFBE_C_AICOM_POSTURE_TTL      = 300}; //--- s a player PUSH/HOLD posture (and a request-unit hint) stays in force before it auto-clears back to the AI's own judgement.

	//--- D4 TARGET-AWARE COMPOSITIONS: before the random bucket draw in AI_Commander_Teams.sqf, read
	//--- the target town's existing camp/garrison composition and RE-WEIGHT the draw pool within the
	//--- already-eligible tier. >=COMP_GARRISON_HEAVY camps -> boost AT/MG-containing templates;
	//--- open village (supplyValue <= COMP_OPEN_SV) -> boost mech-infantry. Factory-tier gating unchanged.
	//--- Flag 0 = inert (default OFF). A2-OA-safe (getVariable default, plain arithmetic).
	if (isNil "WFBE_C_AICOM_TARGET_AWARE_COMP")   then {WFBE_C_AICOM_TARGET_AWARE_COMP   = 0};  //--- master switch: 1 = active, 0 = inert (default OFF).
	if (isNil "WFBE_C_AICOM_COMP_GARRISON_HEAVY") then {WFBE_C_AICOM_COMP_GARRISON_HEAVY = 3};  //--- camp count (camps = town getVariable "camps") at or above which a town is "garrison-heavy" -> AT/MG boost.
	if (isNil "WFBE_C_AICOM_COMP_OPEN_SV")        then {WFBE_C_AICOM_COMP_OPEN_SV        = 50}; //--- supplyValue at or below which a target is an "open village" -> mech-infantry boost.
	if (isNil "WFBE_C_AICOM_COMP_ATMG_MULT")      then {WFBE_C_AICOM_COMP_ATMG_MULT      = 3.0};//--- weight multiplier applied to templates that contain an AT/MG hull or unit when garrison-heavy.
	if (isNil "WFBE_C_AICOM_COMP_MECH_MULT")      then {WFBE_C_AICOM_COMP_MECH_MULT      = 2.5};//--- weight multiplier applied to light/heavy (mech-infantry) templates when the target is an open village.
	if (isNil "WFBE_C_AICOM_POSTURE_ENGAGE_DELTA") then {WFBE_C_AICOM_POSTURE_ENGAGE_DELTA = 4}; //--- COMMAND CONSOLE: how many towns a PUSH posture shaves off (HOLD adds to) the expansion-first ENGAGE gate in the Allocator. SMALL bias; the stance machine is untouched.
	if (isNil "WFBE_C_AICOM_REQUEST_TYPE_MULT") then {WFBE_C_AICOM_REQUEST_TYPE_MULT = 3}; //--- COMMAND CONSOLE: weight multiplier the request-unit hook applies to the requested bucket (armor/air/infantry) in AssignTypes + Teams. SOFT nudge; the empty-bucket zero-out still guarantees a buildable pick.
		//--- cmdcon27 THREAD C: FIELD-ORDER nudge knobs (SPLIT UP / PUSH TOGETHER / HARASS / FALL BACK). One consolidated
		//--- stamp wfbe_aicom_player_fieldorder (string + t0), read once in the Allocator under WFBE_C_AICOM_POSTURE_TTL. isNil-guarded.
		if (isNil "WFBE_C_AICOM_NUDGE_SPLIT_FIST")    then {WFBE_C_AICOM_NUDGE_SPLIT_FIST    = 3};  //--- SPLIT UP: fist towns floored to this (spread the main effort across multiple fronts).
		if (isNil "WFBE_C_AICOM_NUDGE_SPLIT_EXPAND")  then {WFBE_C_AICOM_NUDGE_SPLIT_EXPAND  = 4};  //--- SPLIT UP: expand-team count floored to this (peel more teams onto neutral grabs).
		if (isNil "WFBE_C_AICOM_NUDGE_HARASS_TEAMS")  then {WFBE_C_AICOM_NUDGE_HARASS_TEAMS  = 4};  //--- HARASS: mounted rear-raid team count floored to this (pressure the enemy back-line).
		if (isNil "WFBE_C_AICOM_NUDGE_FALLBACK_DELTA") then {WFBE_C_AICOM_NUDGE_FALLBACK_DELTA = 20}; //--- FALL BACK: towns added to the engage gate (stop clashing / pull back to owned towns).
		//--- COMMAND CONSOLE PLAYER-ARTILLERY: a SEPARATE opt-in flag for the war-room ARTILLERY-HERE order, distinct from
		//--- WFBE_C_AI_COMMANDER_ARTILLERY (default flipped ON 2026-07-08, fable/alife-arty-dwell - see the flag def above;
		//--- was Steff hard-locked to 0 before that). When this is >0 the player request is accepted by the handler and
		//--- serviced by the assist-mode resolver (WFBE_SE_FNC_AI_Com_PlayerArty), which only ever fires friendly artillery
		//--- pieces that ALREADY exist on the map - it never builds guns - so it stays independent of the AI's own arty
		//--- state either way. Default 0 (off): the war-room button stays greyed out until a player opts in.
		if (isNil "WFBE_C_AICOM_PLAYER_ARTY") then {WFBE_C_AICOM_PLAYER_ARTY = 0};
	//=================================================================================================
	if (isNil "WFBE_C_AICOM_MHQ_ENEMY_CLEAR")       then {WFBE_C_AICOM_MHQ_ENEMY_CLEAR       = 700};  //--- m: do NOT mobilize/deploy if an enemy is within this of the current HQ or the destination.
	if (isNil "WFBE_C_AICOM_MHQ_ARRIVE_DIST")       then {WFBE_C_AICOM_MHQ_ARRIVE_DIST       = 400};  //--- m: MHQ within this of the destination = arrived -> deploy.
	if (isNil "WFBE_C_AICOM_MHQ_DEADLINE")          then {WFBE_C_AICOM_MHQ_DEADLINE          = 600};  //--- s of driving before the player-safe teleport-step fallback (then deploy).
	if (isNil "WFBE_C_AICOM_MHQ_STUCK_SECS")        then {WFBE_C_AICOM_MHQ_STUCK_SECS        = 210};  //--- s with no >25m progress = stuck -> deploy where it stands (never idle).
	//--- B74.2 (night-soak item 7, anti-thrash): after a relocation EVALUATION aborts (advance-below-min or
	//--- no-buffer-clear-standoff), the front/town layout almost never changes within one interval, so the
	//--- worker re-ran the full own-town scan + insertion-sort + ring-clear sweep every RELOCATE_INTERVAL and
	//--- re-logged the same ABORT (the 461 paired-abort thrash in the 11h digest). When >0, suppress re-eval
	//--- for this many seconds after an abort (per side, stamped on the side logic). 0 = OFF (old behaviour:
	//--- re-evaluate every interval). 600 = ~3 missed intervals of dead re-scan skipped. Rollback: 0.
	if (isNil "WFBE_C_AICOM_MHQ_ABORT_COOLDOWN")    then {WFBE_C_AICOM_MHQ_ABORT_COOLDOWN    = 600};   //--- s to skip re-evaluation after an abort (0 = off). B74.2: activated at 600 (Ray pick; skips ~3 dead 180s re-scans per abort). Rollback: 0.
	//--- B60 HELI CANNON-NUDGE (Ray 2026-06-21, DEFAULT-ON): A2-OA heli gunners over-prefer guided ATGMs and
	//--- ignore the cannon/rockets. When an enemy is within cannon range, drop the attack heli to a low gun-run
	//--- altitude and one-shot force the gunner onto a non-guided muzzle. Set WFBE_C_AICOM_HELI_CANNON_NUDGE = 0 to disable.
	if (isNil "WFBE_C_AICOM_HELI_CANNON_NUDGE") then {WFBE_C_AICOM_HELI_CANNON_NUDGE = 1};   //--- 1 = ON (Ray default).
	if (isNil "WFBE_C_AICOM_HELI_CANNON_RANGE") then {WFBE_C_AICOM_HELI_CANNON_RANGE = 700}; //--- m: enemy within this band -> nudge gunner to cannon.
	if (isNil "WFBE_C_AICOM_HELI_GUN_ALT")      then {WFBE_C_AICOM_HELI_GUN_ALT      = 35};  //--- m: low gun-run altitude so the engine acquires inside guided-min-range (tradeoff: more AA exposure).
	if (isNil "WFBE_C_AICOM_HELI_NUDGE_PERIOD") then {WFBE_C_AICOM_HELI_NUDGE_PERIOD = 7};   //--- s between nudges.
	if (isNil "WFBE_C_AICOM_HELI_APPROACH_LIMITED") then {WFBE_C_AICOM_HELI_APPROACH_LIMITED = 0}; //--- Fleet lane 18: 1 = slow AICOM transport helis to LIMITED only for the final LZ run-in.
	if (isNil "WFBE_C_AICOM_HELI_RUNINFLOOR") then {WFBE_C_AICOM_HELI_RUNINFLOOR = 0}; //--- m: minimum run-in altitude for AICOM transport helis (0=off/legacy 60m flat; set 60 CH or 80 TK for worldName-aware floor). Applied via max.
	if (isNil "WFBE_C_AICOM_HELI_REFUND_MAX")  then {WFBE_C_AICOM_HELI_REFUND_MAX  = 40000}; //--- D4-FIX(c): hard fallback ceiling for the aicom-heli-refunded credit when the hull type cannot be re-priced server-side (unknown/absent classname). Generous vs any real AICOM transport heli price; never overrides a successfully re-derived real price (min() always wins).
	if (isNil "WFBE_C_AICOM_HELI_GUNFLOOR")   then {WFBE_C_AICOM_HELI_GUNFLOOR   = 0}; //--- m: minimum gun-run altitude for AICOM attack helis (0=off/legacy 35m; set 35 CH or 50 TK). Applied via max on GUN_ALT.
	//--- V0.7 bootstrap: until the side owns >= 1 town, bias target selection to the
	//--- nearest-to-base, lowest-value town so the AI captures its first income source fast.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_BIAS") then {WFBE_C_AICOM_BOOTSTRAP_BIAS = 1};         //--- 1 enable, 0 disable.
	//--- V0.7 bootstrap stipend: trickle funds+supply per supervisor tick while town count == 0.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_FUNDS") then {WFBE_C_AICOM_BOOTSTRAP_FUNDS = 100};     //--- Funds per minute (scaled to tick spacing).
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_SUPPLY") then {WFBE_C_AICOM_BOOTSTRAP_SUPPLY = 120};   //--- punchy-AICOM (Ray 2026-06-17): 50->120 supply/min while zero-town, so the AI tech-unlocks + builds faster out of the gate. Rollback: 50.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_MAXTIME") then {WFBE_C_AICOM_BOOTSTRAP_MAXTIME = 7200};//--- punchy-AICOM (Ray 2026-06-17): 3600->7200 - keep the zero-town stipend alive for 2h so a stalled AI never goes broke. Rollback: 3600.
	if (isNil "WFBE_C_AICOM_SUPPLY_RESERVE") then {WFBE_C_AICOM_SUPPLY_RESERVE = 1000}; //--- supply floor: do not start a tech upgrade that would drop supply below this (keeps supply for base build/defense). Research is SUPPLY-ONLY (the funds->supply fallback was removed for production).
	WFBE_C_AI_COMMANDER_RELIEF_MAX = 1;           //--- punchy-AICOM (Ray 2026-06-17): 2->1 - at most one team diverted to defense at a time; keep the rest on offense. Rollback: 2.
	//--- B68 (Ray 2026-06-21) ATTACK-BIAS: "defense should matter MUCH LESS than attack." LAST-STAND (recall-all-
	//--- to-HQ) + the maneuver-strength compare that gates it now fire only in genuinely dire cases; teams ASSAULT
	//--- by default. Consumed in AI_Commander_Strategy.sqf. All default-ON, tunable, rollback-documented.
	if (isNil "WFBE_C_AICOM_LASTSTAND_TOWNS") then {WFBE_C_AICOM_LASTSTAND_TOWNS = 1};    //--- recall-all only at <= this many owned towns (old implicit gate <2). Rollback to old behaviour: 1 + RATIO 0.7.
	if (isNil "WFBE_C_AICOM_LASTSTAND_RATIO") then {WFBE_C_AICOM_LASTSTAND_RATIO = 0.30}; //--- AICOM v2 (Ray 2026-06-27 "almost never defensive"): 0.45->0.30, last-stand (recall-all-to-HQ) even rarer. AND maneuver strength below this fraction of the enemy's. Rollback: 0.45.
	if (isNil "WFBE_C_AICOM_INTENT_HUD") then {WFBE_C_AICOM_INTENT_HUD = 1};       //--- AICOM v2 preview: 1 = publish the AI commander's INTENT (side-keyed) + show it in the RHUD commander row + draw the OBJECTIVE town as a friendly-only map marker. 0 = off.
	if (isNil "WFBE_C_AICOM_INTENT_SPECTATOR") then {WFBE_C_AICOM_INTENT_SPECTATOR = 1}; //--- 1 = dead/spectator RHUD uses stable client side id for the AI commander name + intent row when player/group side is transient civilian.
	if (isNil "WFBE_C_AICOM_STR_LONE_ALIVE") then {WFBE_C_AICOM_STR_LONE_ALIVE = 2};      //--- a team with fewer than this many alive...
	if (isNil "WFBE_C_AICOM_STR_LONE_FARHQ") then {WFBE_C_AICOM_STR_LONE_FARHQ = 1500};   //--- ...AND farther than this (m) from HQ is a stranded remnant, EXCLUDED from the _myStr maneuver-strength count so it does not deflate strength + trip the defensive gates. 0 disables the exclusion.
	//--- B68 (Ray 2026-06-21) RETREAT-CULL hardening: the B67 progress-gated budget never culls a lone survivor
	//--- that slowly crawls home from far away (re-issues retreat forever, milling at base, never assaulting).
	//--- SMALL-MAP AICOM TUNE (card wasp-zargabad-aicom-disband-near-base-20260719; live ZG evidence).
	//--- The gate is defined before the first tuned constant; default 0 leaves legacy defaults intact.
	if (isNil "WFBE_C_AICOM_SMALLMAP_TUNE") then {WFBE_C_AICOM_SMALLMAP_TUNE = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on). Self-scoped to Zargabad via WFBE_AICOM_SMALLMAP_ARMED's worldName check below - inert on CH/TK.
	WFBE_AICOM_SMALLMAP_ARMED = (WFBE_C_AICOM_SMALLMAP_TUNE > 0) && {(toLower worldName) == "zargabad"};
	if (isNil "WFBE_C_AICOM_RETREAT_MAX_ISSUES") then {if (WFBE_AICOM_SMALLMAP_ARMED) then {WFBE_C_AICOM_RETREAT_MAX_ISSUES = 14} else {WFBE_C_AICOM_RETREAT_MAX_ISSUES = 8}}; //--- cull a lone survivor after this many retreat re-issues regardless of slow progress.
	if (isNil "WFBE_C_AICOM_RETREAT_HOME_RANGE") then {if (WFBE_AICOM_SMALLMAP_ARMED) then {WFBE_C_AICOM_RETREAT_HOME_RANGE = 1600} else {WFBE_C_AICOM_RETREAT_HOME_RANGE = 800}};
	if (isNil "WFBE_C_AICOM_RETREAT_MAX_DIST") then {WFBE_C_AICOM_RETREAT_MAX_DIST = 6000};  //--- cull a lone survivor after a retreat re-issue if farther than this (m) from HQ - not worth a multi-km walk home.
	//--- B67 (Ray 2026-06-21) BUILD PLACEMENT (item #10): minimum centre-to-centre spacing between AI-built
	//--- structures + a wider factory placement ring, so factories stop piling on top of each other.
	if (isNil "WFBE_C_AICOM_STRUCT_SPACING") then {WFBE_C_AICOM_STRUCT_SPACING = 45};       //--- m between AI structures (big hangars reach ~30m). SOFT preference enforced by the primary placement path.
	//--- Ray 2026-06-29 (req #1, NO OVERLAP): HARD no-overlap floor. STRUCT_SPACING above is a soft preference;
	//--- the try-budget FALLBACK tiers (_bestBC/_best/_p) previously had no floor and could hand back a spot ON
	//--- TOP of an existing structure. _findBuildPos now gates every fallback tier (and a final radial-nudge
	//--- guard) on this floor, so the AI can NEVER place a factory overlapping another structure. Set ~= the
	//--- largest footprint (big hangars reach ~30m) so footprints just touch but never overlap. <=0 disables.
	if (isNil "WFBE_C_AICOM_STRUCT_SPACING_FLOOR") then {WFBE_C_AICOM_STRUCT_SPACING_FLOOR = 30};
	//--- Ray 2026-06-29 (req #2, SPAWN POINTS ON ROADS, SPACED): target along-road spacing (m) between
	//--- consecutive SPAWN-POINT factories (Barracks/Light/Heavy/Aircraft). _findBuildPos mode-2 prefers the
	//--- road-adjacent candidate whose distance to the nearest existing factory is closest to this, so the four
	//--- respawn structures step evenly ALONG road frontage instead of clustering at one HQ angle.
	if (isNil "WFBE_C_AICOM_FACTORY_ROAD_STEP") then {WFBE_C_AICOM_FACTORY_ROAD_STEP = 50};
	//--- Ray 2026-06-29: _findBuildPos try budgets. Widened so an all-gates-clear (building+road+FULL spacing)
	//--- spot is normally found and the no-overlap floor stays a last resort. Build-tick only (~1/5min/side).
	if (isNil "WFBE_C_AICOM_BUILDPOS_TRIES_ROAD")    then {WFBE_C_AICOM_BUILDPOS_TRIES_ROAD    = 64}; //--- near-road / road-spaced modes (was 40).
	if (isNil "WFBE_C_AICOM_BUILDPOS_TRIES_OFFROAD") then {WFBE_C_AICOM_BUILDPOS_TRIES_OFFROAD = 40}; //--- off-road CC/Bank/CBR (was 24).
	//--- B74.2 (Ray 2026-06-24, directives #1 + #4): the AI commander obeys the SAME structure limits as human
	//--- players. AI-commander-only (human build is gated client-side in coin_interface.sqf, unaffected by these).
	//---   WFBE_C_AICOM_OBEY_BUILD_LIMITS = 1 -> AI_Commander_Base.sqf's per-type build gate reads the player cap
	//---     WFBE_C_STRUCTURES_MAX_<type> (same getVariable lookup the COIN UI uses at coin_interface.sqf:917;
	//---     getVariable is case-insensitive so the type key 'CommandCenter' resolves _MAX_COMMANDCENTER) and skips
	//---     a structure once the side already owns >= that many. 0 = old unbounded AI build.
	//---   WFBE_C_AICOM_BASES_MAX = N -> hard cap on BASES (= CommandCenter structures) the AI may stand up
	//---     (directive #1: max 2). Counted as live CommandCenters; at/over the cap the CommandCenter build is skipped.
	//---     <=0 disables the base cap.
	if (isNil "WFBE_C_AICOM_OBEY_BUILD_LIMITS") then {WFBE_C_AICOM_OBEY_BUILD_LIMITS = 1};
	if (isNil "WFBE_C_AICOM_BASES_MAX")         then {WFBE_C_AICOM_BASES_MAX         = 2};
	if (isNil "WFBE_C_AICOM_FACTORY_RING_MIN") then {WFBE_C_AICOM_FACTORY_RING_MIN = 60};   //--- factory placement ring inner (was 45).
	if (isNil "WFBE_C_AICOM_FACTORY_RING_MAX") then {WFBE_C_AICOM_FACTORY_RING_MAX = 110};  //--- factory placement ring outer (was 75).
	//--- 2ND BASE / FORWARD OUTPOST (AICOM v2, Ray): the AI stands up a SECOND CommandCenter + its own factory at a
	//--- DISTANT forward owned town ONLY when supply is genuinely ABUNDANT, projecting spare economy toward the front.
	//--- AICOM-only (humans build a 2nd base by hand, unaffected). FWDBASE_ENABLE=0 makes the sub-pass inert (rollback).
	if (isNil "WFBE_C_AICOM_FWDBASE_ENABLE")         then {WFBE_C_AICOM_FWDBASE_ENABLE         = 1};
	if (isNil "WFBE_C_AICOM_FWDBASE_SUPPLY_FRAC")    then {WFBE_C_AICOM_FWDBASE_SUPPLY_FRAC    = 0.80};  //--- gate = MAX(frac*supplyCap, floor); tracks the configured cap if it's raised.
	if (isNil "WFBE_C_AICOM_FWDBASE_SUPPLY_FLOOR")   then {WFBE_C_AICOM_FWDBASE_SUPPLY_FLOOR   = 24000}; //--- absolute supply floor for "abundant" (rear base + full tech costs well under this).
	if (isNil "WFBE_C_AICOM_FWDBASE_SUPPLY_RESERVE") then {WFBE_C_AICOM_FWDBASE_SUPPLY_RESERVE = 6000};  //--- supply that must REMAIN after each forward structure (never starves the rear economy/tech).
	if (isNil "WFBE_C_AICOM_FWDBASE_MIN_DIST")       then {WFBE_C_AICOM_FWDBASE_MIN_DIST       = 2200};  //--- m: the 2nd base must be at least this far from the rear HQ (else just wasted supply).
	if (isNil "WFBE_C_AICOM_FWDBASE_RING_MIN")       then {WFBE_C_AICOM_FWDBASE_RING_MIN       = 60};    //--- forward factory placement ring (same scale as the primary base).
	if (isNil "WFBE_C_AICOM_FWDBASE_RING_MAX")       then {WFBE_C_AICOM_FWDBASE_RING_MAX       = 110};
	if (isNil "WFBE_C_AICOM_FWDBASE_DEF_MAX")        then {WFBE_C_AICOM_FWDBASE_DEF_MAX        = 2};     //--- LIGHT defense: manned statics at the outpost (vs 4 at the primary base).
	if (isNil "WFBE_C_AICOM_FWDBASE_TOWN_STANDOFF")  then {WFBE_C_AICOM_FWDBASE_TOWN_STANDOFF  = 350};   //--- m behind the forward town (toward rear HQ) so the outpost isn't built in the town core.
	//--- AICOM FORWARD SPAWN-BEACON (Approach A, claude-gaming 2026-06-29): the commander parks a forward AMBULANCE
	//--- (already a wired mobile respawn via WFBE_%1AMBULANCES) BEHIND the spearhead town so AI + humans get a forward
	//--- spawn line that follows the front. DEFAULT-OFF / INERT (the supervisor hook only calls the worker when ENABLE>0).
	if (isNil "WFBE_C_AICOM_SPAWNBEACON_ENABLE")   then {WFBE_C_AICOM_SPAWNBEACON_ENABLE   = 0};    //--- 0 = INERT (feature fully off), 1 = arm the forward-ambulance beacon worker.
	if (isNil "WFBE_C_AICOM_SPAWNBEACON_INTERVAL") then {WFBE_C_AICOM_SPAWNBEACON_INTERVAL = 120};  //--- s: worker tick cadence (self-heal / re-stand check).
	if (isNil "WFBE_C_AICOM_SPAWNBEACON_MAX")      then {WFBE_C_AICOM_SPAWNBEACON_MAX      = 1};    //--- beacons ALIVE at once per AI commander.
	if (isNil "WFBE_C_AICOM_SPAWNBEACON_STANDOFF") then {WFBE_C_AICOM_SPAWNBEACON_STANDOFF = 300};  //--- m behind the spearhead town (toward rear HQ) so it sits in safe rear of the front.
	if (isNil "WFBE_C_AICOM_SPAWNBEACON_REFWD")    then {WFBE_C_AICOM_SPAWNBEACON_REFWD    = 600};  //--- m: re-stand the beacon forward when the front advances this far from its current spot.
	if (isNil "WFBE_C_AICOM_SPAWNBEACON_COOLDOWN") then {WFBE_C_AICOM_SPAWNBEACON_COOLDOWN = 300};  //--- s: minimum gap between BUYING new beacons (anti funds-bleed if the enemy keeps killing it). Re-standing an existing beacon is exempt.
	//--- AICOM TRACKED ARTILLERY (Ray 2026-06-27): one self-propelled artillery battery per commander, capped, with
	//--- fire cooldown + salvo size scaled by the side's ARTYTIMEOUT upgrade level (they must research it to earn the perks).
	if (isNil "WFBE_C_AICOM_ARTY_MAX")       then {WFBE_C_AICOM_ARTY_MAX       = 1};   //--- max arty batteries ALIVE per AI commander (0 = uncapped).
	if (isNil "WFBE_C_AICOM_ARTY_ENABLED")   then {WFBE_C_AICOM_ARTY_ENABLED   = 1};   //--- 1 = AI runs directed arty FIRE missions (tier-cooldown, friendly-fire-guarded). 0 = battery still founds but only fires via normal AI.
	if (isNil "WFBE_C_AICOM_ARTY_AMMO_FRAC") then {WFBE_C_AICOM_ARTY_AMMO_FRAC = [0.50,0.65,0.80,0.90,1.00,1.00,1.00]}; //--- ARTYTIMEOUT level 0..6 -> ammo fraction the battery is REARMED to at a Service Point (parallels WFBE_C_ARTILLERY_INTERVALS cooldowns); low tier = smaller reloads + faster runs-dry, so the AI must research to earn sustained fire.
	//--- B67 (Ray 2026-06-21) MHQ RELOCATION (item #12): the new base must sit a GENEROUS buffer outside any
	//--- enemy/GUER town activation ring (600m base ring + this margin). HQ routes only through own-side towns.
	if (isNil "WFBE_C_AICOM_MHQ_TOWN_BUFFER") then {WFBE_C_AICOM_MHQ_TOWN_BUFFER = 200};   //--- m beyond the 600m town ring before a relocation destination is accepted.
	//--- B67 (Ray 2026-06-21) HYBRID COMMANDER (item #5, FULL SEND): when a player votes out the AI commander,
	//--- the AI keeps founding/refilling its teams (assist mode) while the player builds + can re-task all teams.
	if (isNil "WFBE_C_AI_COMMANDER_HYBRID_REFILL") then {WFBE_C_AI_COMMANDER_HYBRID_REFILL = 1}; //--- 1=AI keeps refilling teams under a player commander; 0=legacy (AI idle under human).
	if (isNil "WFBE_C_AICOM_SUPPLY_STAGNATION_EXEMPT") then {WFBE_C_AICOM_SUPPLY_STAGNATION_EXEMPT = 1}; //--- 1=AI-commanded sides keep earned town supply while no human is seated; 0=legacy no-players stagnation.
	//--- punchy-AICOM (Ray 2026-06-17): NEW tunables.
	//--- TIME-CURVE income boost: a gentle smoothstep multiplier on the commander's recurring
	//--- funds income (updateresources.sqf _pcMult). FLAT (=FLOOR) until START, then S-curve ramp
	//--- across WINDOW seconds up to CEIL. Late + gentle by design - NOT an early snowball.
	if (isNil "WFBE_C_AICOM_TIMECURVE_FLOOR")  then {WFBE_C_AICOM_TIMECURVE_FLOOR  = 1.0};   //--- multiplier before the ramp (no early boost).
	if (isNil "WFBE_C_AICOM_TIMECURVE_CEIL")   then {WFBE_C_AICOM_TIMECURVE_CEIL   = 1.8};   //--- peak multiplier at full ramp (late-game punch).
	if (isNil "WFBE_C_AICOM_TIMECURVE_START")  then {WFBE_C_AICOM_TIMECURVE_START  = 7200};  //--- s before the ramp begins (7200 = 120 min ~ "after 2 hours").
	if (isNil "WFBE_C_AICOM_TIMECURVE_WINDOW") then {WFBE_C_AICOM_TIMECURVE_WINDOW = 3600};  //--- ramp length (s); CEIL reached at START+WINDOW (= 180 min).
	//--- FOUNDING TEAM-SIZE clamp [MIN,MAX]. MBT teams + ATTACK-HELI teams are EXEMPT from MIN
	//--- (vehicle+crew is the punch; never pad them with riflemen). Applied in AI_Commander_Produce.sqf.
	if (isNil "WFBE_C_AICOM_TEAM_SIZE_MIN") then {WFBE_C_AICOM_TEAM_SIZE_MIN = 10};   //--- founding floor for infantry/mixed teams. Owner ruling 2026-07-21: founding size is honestly 10, not 8 - raised the clamp.
	if (isNil "WFBE_C_AICOM_TEAM_SIZE_MAX") then {WFBE_C_AICOM_TEAM_SIZE_MAX = 10};  //--- Build84 (Ray): founding ceiling 12 -> 8 (lighter server load); single-vehicle MBT/attack-heli teams exempt. Owner ruling 2026-07-21: raised 8 -> 10 (founding size honestly 10).
	//--- === Build 84 / cmdcon36 wave-2/3 constants (claude-gaming 2026-07-01) ===
	if (isNil "WFBE_C_AICOM_HIGHCLIMB") then {WFBE_C_AICOM_HIGHCLIMB = 1};                 //--- Build84 (Ray, ON): AICOM tanks get demand-based Valhalla climb-assist on server/HC (boosts only a bogged tank moving forward). 0 = off.
	//--- T1.5 ADD (R3-SYNTHESIS 2026-07-20): from-zero unstick pulse - a small bounded nudge along
	//--- the hull heading when a hull has fully stopped (<=3 km/h), escalating a per-vehicle strike
	//--- counter so a genuinely wedged/flipped hull is not nudged forever. See Common_AICOM_HighClimb.sqf.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_PULSE") then {WFBE_C_AICOM_HIGHCLIMB_PULSE = 1}; //--- 0 = off (byte-identical to pre-T1.5 behaviour: only the existing rolling-hull boost applies).
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_PULSE_MAX_STRIKES") then {WFBE_C_AICOM_HIGHCLIMB_PULSE_MAX_STRIKES = 6}; //--- consecutive still-stuck pulses before this hull is handed back to the normal stuck/strand/abandon ladder.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_PULSE_COOLDOWN") then {WFBE_C_AICOM_HIGHCLIMB_PULSE_COOLDOWN = 15}; //--- s between from-zero pulses on the same hull; review minimum is 15s.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE") then {WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE = 1}; //--- armed 2026-07-27 owner go (was 0; Review fix #1194 left this as the master gate for the from-zero pulse, to be armed explicitly). Rationale: the rolling-hull assist only helps a hull that is STILL MOVING, so a fully-stopped tank got no help at all - exactly the ASSAULT_STRANDED signature seen live 2026-07-27 (teams covering 682m and 1676m in 776s before being written off). Bounded by the existing sub-constants: ZEROPULSE_DWELL 10 observations at <= ZEROPULSE_EPSILON 1m, PULSE_SPEED 2.5 m/s along hull heading, PULSE_COOLDOWN 15s, PULSE_MAX_STRIKES 6 before the hull is handed back to the normal stuck/strand/abandon ladder, ZEROPULSE_PROGRESS 25m resets strikes. Rollback: set to 0.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE_EPSILON") then {WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE_EPSILON = 1}; //--- m: goal-distance change treated as no progress during dwell qualification.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE_DWELL") then {WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE_DWELL = 10}; //--- consecutive 0.1s observations before a from-zero pulse is eligible.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE_PROGRESS") then {WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE_PROGRESS = 25}; //--- m: genuine position progress that resets pulse strikes.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_PULSE_SPEED") then {WFBE_C_AICOM_HIGHCLIMB_PULSE_SPEED = 2.5}; //--- m/s impulse magnitude along hull heading (deliberation spec: ~2-3 m/s).
	if (isNil "WFBE_C_AICOM_AUTOFLIP") then {WFBE_C_AICOM_AUTOFLIP = 1};                   //--- Build84 (Ray, ON): auto-right flipped AICOM ground vehicles on server/HC (Marty AutoFlip thresholds; only when flipped+stuck). 0 = off.
	if (isNil "WFBE_C_AICOM_SPAWN_ON_ROADS") then {WFBE_C_AICOM_SPAWN_ON_ROADS = 1};       //--- Build84: snap AICOM factory-produced unit spawn to nearest road within SPAWN_ROAD_RADIUS of the factory pad. 0 = pre-Build84 pad behaviour.
	if (isNil "WFBE_C_AICOM_SPAWN_ROAD_RADIUS") then {WFBE_C_AICOM_SPAWN_ROAD_RADIUS = 60};//--- Build84: nearRoads search radius (m) for the AICOM road-spawn snap.
	//--- === TP-9 PLAYER SPAWN-ON-ROADS (claude-gaming 2026-07-06) ===
	if (isNil "WFBE_C_PLAYER_SPAWN_ON_ROADS") then {WFBE_C_PLAYER_SPAWN_ON_ROADS = 1}; //--- TP-9: snap player-factory spawn to nearest road (reuses WFBE_C_AICOM_SPAWN_ROAD_RADIUS). 0 = off (byte-identical to pre-TP-9 player spawn).
	if (isNil "WFBE_C_AICOM_FOUND_REQUIRE_FACTORY") then {WFBE_C_AICOM_FOUND_REQUIRE_FACTORY = 1}; //--- Build84 (ARMED 2026-07-10, owner decision - see PR "Feat: AI team founding requires factory"): AI-commander founding requires the matching owned factory (no HQ 'magic' fallback) - parity with what players face. Investigation confirmed the existing STARVATION-SAFETY gate below already covers the early-game window: HQ-fallback still applies while a side owns zero factories, and the Barracks (first factory, ~2 min in) always permits infantry founding; only a same-cycle armor/air pick landing before its own factory finishes gets skipped and re-picked next 90s cycle - no dead foundings. 0 = pre-Build84 HQ-fallback allowed.
	if (isNil "WFBE_C_AICOM_PATROL_UNSTUCK_MAX") then {WFBE_C_AICOM_PATROL_UNSTUCK_MAX = 5}; //--- Build84: after N consecutive side-patrol wedges, drop target + re-pick a different frontline town (anti-orbit).
	if (isNil "WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS") then {WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS = 250}; //--- Build84: 'at target' radius (m) for assault-arrive / uncapturable-abandon logic (was getVariable-default-only).
	if (isNil "WFBE_C_AICOM_CAP_PENDING") then {WFBE_C_AICOM_CAP_PENDING = 0}; //--- fable/aicom-econ-triad F2 (2026-08-02): 1 = count the pending-spawn ledger (committed-but-unspawned production: factory FIFO orders, HC founding/top-up dispatches, airlift grants) against WFBE_C_TOTAL_AI_MAX_BY_TIER at the Produce + founding gates, closing the 226/170 overshoot race. 0 = ledger recorded + logged (pending= on PRODUCE_SKIP/FOUND_SKIP) but NOT enforced - cap behaviour byte-identical.
	if (isNil "WFBE_C_AICOM_CAP_PENDING_TTL") then {WFBE_C_AICOM_CAP_PENDING_TTL = 180}; //--- fable/aicom-econ-triad F2: seconds a pending-spawn ledger entry counts before aging out (approximates cross-machine spawn completion; longer = more conservative production).
	if (isNil "WFBE_C_AICOM_F2S_ENABLE") then {WFBE_C_AICOM_F2S_ENABLE = 0}; //--- fable/aicom-econ-triad F3 (2026-08-02): 1 = AICOM funds->supply conversion channel in the supervisor (AI_Commander.sqf, after REQDRAW). Lets a rich-but-supply-starved side (overnight 2026-08-01: EAST funds 1.44M climbing, netSupply -45k/window) convert hoarded cash into the supply its own sinks (research, base construction) are gated on, so a dominant side can convert advantage into decision. 0 = dark, byte-identical. BALANCE-SENSITIVE: owner arms.
	if (isNil "WFBE_C_AICOM_F2S_FLOOR") then {WFBE_C_AICOM_F2S_FLOOR = 400000}; //--- F3: funds the side must KEEP after a conversion - below FLOOR+AMOUNT nothing fires (non-rich sides untouched).
	if (isNil "WFBE_C_AICOM_F2S_AMOUNT") then {WFBE_C_AICOM_F2S_AMOUNT = 25000}; //--- F3: funds burned per conversion (measured income was ~29k/window - slows hoarding, never reverses it in one tick).
	if (isNil "WFBE_C_AICOM_F2S_SUPPLY_LOW") then {WFBE_C_AICOM_F2S_SUPPLY_LOW = 15000}; //--- F3: conversions fire only while side supply is under this (genuine starvation; healthy pools untouched).
	if (isNil "WFBE_C_AICOM_F2S_RATIO") then {WFBE_C_AICOM_F2S_RATIO = 1}; //--- F3: supply gained per fund burned (gain = round(AMOUNT*RATIO), still clamped by WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT).
	if (isNil "WFBE_C_AICOM_F2S_COOLDOWN") then {WFBE_C_AICOM_F2S_COOLDOWN = 300}; //--- F3: min seconds between conversions per side (default = one per supervisor stat window).
	if (isNil "WFBE_C_AICOM_AIR_LATE_MINS") then {WFBE_C_AICOM_AIR_LATE_MINS = 45};        //--- Build84 (Ray): mission minute at/after which 'late game' air scaling applies.
	if (isNil "WFBE_C_AICOM_AIR_MAX_LATE") then {WFBE_C_AICOM_AIR_MAX_LATE = 12}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: late game leans air per owner pick; capture rail: air bucket must stay lift-majority.
	if (isNil "WFBE_C_AICOM_HELI_SHARE_LATE") then {WFBE_C_AICOM_HELI_SHARE_LATE = 0.62}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: late game leans air per owner pick; capture rail: air bucket must stay lift-majority.
	//--- === cmdcon37 AI-behaviour fixes (claude-gaming overnight 2026-07-02) ===
	if (isNil "WFBE_C_AICOM_CAMP_GATE_MODE2") then {WFBE_C_AICOM_CAMP_GATE_MODE2 = 1};        //--- cmdcon37 (afraid-of-camps): in AllCamps mode (WFBE_C_TOWNS_CAPTURE_MODE=2) hold + aggressively clear a town's camps instead of bailing to a depot that can't flip. 0 = old bail behaviour.
	if (isNil "WFBE_C_AICOM_STALL_ADVANCE_SECS") then {WFBE_C_AICOM_STALL_ADVANCE_SECS = if (worldName == "Takistan") then {900} else {420}}; //--- cmdcon37 (never-stand floor): if a team is parked at a town > this many s with no flip/progress, blacklist it + retarget to the nearest OTHER enemy town same tick (bypasses the strike ladder that rarely accrues live). 0 = off. cmdcon38: 240 -> 420 so it no longer preempts a full travel(~60s)+drain-wait-hold(360s) capture attempt on Chernarus/Zargabad scale. T1.3a (R3-SYNTHESIS 2026-07-20): 420 was BELOW the executor's own ~890s TK attempt budget, so the floor preempted a still-working long-distance capture before it could finish - worldName branch raises TK to 900 (same per-map pattern as ROAD_STANDOFF/REACH_FOOT), CH/ZG stay at the proven 420.
	//--- === cmdcon41 wave-1 (claude-gaming 2026-07-02): SPREAD+HOLD, real-combat base assault (Ray: ON), siege decay, remnant caution ===
	if (isNil "WFBE_C_AICOM_SPREAD_MODE")            then {WFBE_C_AICOM_SPREAD_MODE = 1};            //--- anti-dogpile: cap teams per fist town in the Allocator (0 = legacy uncapped pile-up).
	if (isNil "WFBE_C_AICOM2_FIST_PERTOWN")          then {WFBE_C_AICOM2_FIST_PERTOWN = 4};          //--- max teams the Allocator stacks on one fist town before spilling to the next.
	if (isNil "WFBE_C_AICOM2_FIST_DWELL")            then {WFBE_C_AICOM2_FIST_DWELL = 0};             //--- AUTO fist hysteresis on the LIVE Allocate path: once the AUTO primary is chosen, pin it this many seconds before a re-score may flip it (0 = inert/legacy per-tick thrash). Port of WFBE_C_AICOM_FRONT_DWELL to Allocate.sqf. Per-side override: WFBE_C_AICOM2_FIST_DWELL_<SIDE>.
	if (isNil "WFBE_C_AICOM_SPREAD_TIERCAP")         then {WFBE_C_AICOM_SPREAD_TIERCAP = 0};         //--- Lane-334: 0=flat FIST_PERTOWN cap; 1=scale fist spread cap by wfbe_town_type like AssignTowns concentration.
	if (isNil "WFBE_C_AICOM_HOLD_MODE")              then {WFBE_C_AICOM_HOLD_MODE = 1};              //--- first captor HOLDS the just-captured town on DEFEND (0 = every captor leaves -> see-saw).
	if (isNil "WFBE_C_AICOM_HOLD_SECS")              then {WFBE_C_AICOM_HOLD_SECS = 180};            //--- hold window (garrison re-arm time) before the holder rejoins the offense.
	if (isNil "WFBE_C_AICOM_ASSAULT_STRUCTURES")     then {WFBE_C_AICOM_ASSAULT_STRUCTURES = 1};     //--- REAL-COMBAT BASE ASSAULT (Ray): strike teams doTarget/doFire the enemy HQ+factories (factories first).
	if (isNil "WFBE_C_AICOM_ASSAULT_ENGAGE_RANGE")   then {WFBE_C_AICOM_ASSAULT_ENGAGE_RANGE = 400}; //--- leader within this range of the enemy HQ -> the fire phase engages (ordinary goto moves untouched).
	if (isNil "WFBE_C_STRUCTURES_ENEMY_DESTROYABLE") then {WFBE_C_STRUCTURES_ENEMY_DESTROYABLE = 1}; //--- enemy weapons actually DAMAGE HQ/factory structures (0 = legacy invulnerable-to-enemy gate).
	if (isNil "WFBE_C_STRUCTURES_ENEMY_REDU")        then {WFBE_C_STRUCTURES_ENEMY_REDU = 2};        //--- damage-reduction divisor vs enemy fire (factories 2, HQ +1=3; legacy never-dies was 5/6).
	if (isNil "WFBE_C_AICOM_OVERRUN_SIEGE_DECAY")    then {WFBE_C_AICOM_OVERRUN_SIEGE_DECAY = 1};    //--- siege counter DECAYS (-1) on a momentary 0-striker tick instead of hard-resetting to 0.
	if (isNil "WFBE_C_AICOM_OVERRUN_SCRIPTRAZE")     then {WFBE_C_AICOM_OVERRUN_SCRIPTRAZE = 0};     //--- Ray: the scripted siege-timer raze is OFF - the win comes from REAL destruction by the assault.
	if (isNil "WFBE_C_AICOM_REMNANT_CAUTION")        then {WFBE_C_AICOM_REMNANT_CAUTION = 1};        //--- mauled remnant teams (<3 live) assault at AWARE/YELLOW instead of banzai COMBAT/RED.
	//--- === cmdcon41 wave-2 (Ray-approved 2026-07-02): YELLOW march, journey-commit, retreat+town-refit lane, econ sink, MHQ revival ===
	if (isNil "WFBE_C_AICOM_MARCH_YELLOW")            then {WFBE_C_AICOM_MARCH_YELLOW = 1};            //--- Ray F1: YELLOW on the march (return fire, keep rolling), RED at the objective. 0 = legacy RED everywhere.
	if (isNil "WFBE_C_AICOM_BREAKOFF_MIN")            then {WFBE_C_AICOM_BREAKOFF_MIN = 3};            //--- depot-hold break-off: below this many live units under fire -> withdraw to rally instead of grinding to zero.
	if (isNil "WFBE_C_AICOM_FRONT_DWELL")             then {WFBE_C_AICOM_FRONT_DWELL = 480};           //--- spearhead hysteresis: the primary front target holds this long before re-scoring may flip it.
	//--- fable/alife-arty-dwell (2026-07-08) DWELL-AGED ARTILLERY SOFTENING: the AICOM arty cooldown (AI_Commander_Strategy.sqf
	//--- ~L1084) shrinks the longer the current front primary has been dwelled on (wfbe_aicom_front_t0, stamped by the
	//--- FRONT_DWELL hysteresis above), so a town that resists longer gets shelled more often. Owner tuning knobs:
	if (isNil "WFBE_C_AICOM_ARTY_DWELL")      then {WFBE_C_AICOM_ARTY_DWELL      = 1};   //--- master switch for the dwell-tempo shrink. 1 = ON (owner default-on request); 0 = legacy flat per-upgrade-tier cooldown.
	if (isNil "WFBE_C_AICOM_ARTY_DWELL_K")    then {WFBE_C_AICOM_ARTY_DWELL_K    = 0.5}; //--- seconds shaved off the arty cooldown per second of front-dwell age (dwell age is naturally capped near WFBE_C_AICOM_FRONT_DWELL).
	if (isNil "WFBE_C_AICOM_ARTY_DWELL_FLOOR") then {WFBE_C_AICOM_ARTY_DWELL_FLOOR = 120}; //--- s: cooldown floor the dwell shrink can reach, regardless of upgrade tier or dwell age (never full-auto spam).
	//--- NOTE: named WFBE_C_AI_COMMANDER_ARTILLERY_MAX (not WFBE_C_AICOM_ARTY_MAX, which is ALREADY TAKEN a few
	//--- hundred lines up by the unrelated "AICOM TRACKED ARTILLERY" battery-founding cap, Ray 2026-06-27) to
	//--- avoid colliding with it - mirrors the WFBE_C_AI_COMMANDER_DEFENSES_MAX naming right above this system's
	//--- own master flag (AI_Commander_Base.sqf).
	if (isNil "WFBE_C_AI_COMMANDER_ARTILLERY_MAX") then {WFBE_C_AI_COMMANDER_ARTILLERY_MAX = 2}; //--- max SELF-PROPELLED base-built artillery pieces a commander may have LIVE at once (self-healing cap, AI_Commander_Base.sqf) - the owner's "max 2 tracked artillery" idea, now a named/tunable constant.
	if (isNil "WFBE_C_AICOM_LOSING_PRESS")            then {WFBE_C_AICOM_LOSING_PRESS = 1};            //--- losing-side aggression floor: behind on towns + near strength parity + base safe -> minimum PRESS (never park in DEFEND).
	if (isNil "WFBE_C_AICOM_POSTURE_HYST_ENABLE")      then {WFBE_C_AICOM_POSTURE_HYST_ENABLE = 1};      //--- cmdcon-posture-hysteresis (RPT-DEEPDIVE 2026-07-30): 1=shared DEFEND/PRESS dwell so behind-towns vs losing-press-floor cannot thrash every strategy tick (52 flips/side live). 0=byte-identical thrash.
	if (isNil "WFBE_C_AICOM_POSTURE_HYST_SEC")         then {WFBE_C_AICOM_POSTURE_HYST_SEC = 180};       //--- min seconds a DEFEND<->PRESS flip is held before the other trigger may retake stance.
	if (isNil "WFBE_C_AICOM_LOSING_PRESS_ENTER")      then {WFBE_C_AICOM_LOSING_PRESS_ENTER = 0.8};    //--- myEff/enEff ratio to ENTER losing-press floor (was hard-coded 0.8).
	if (isNil "WFBE_C_AICOM_LOSING_PRESS_EXIT")       then {WFBE_C_AICOM_LOSING_PRESS_EXIT = 0.65};    //--- ratio to EXIT losing-press once latched (hysteresis band below ENTER; stops marginal thrash).
	if (isNil "WFBE_C_AICOM_WITHDRAW_EVAL")           then {WFBE_C_AICOM_WITHDRAW_EVAL = 1};           //--- graceful-withdrawal evaluator: bleeding HC teams get a "rally" order to the nearest own HQ/town (Ray: reinforce at friendly towns).
	if (isNil "WFBE_C_AICOM_WITHDRAW_MIN_ALIVE")      then {WFBE_C_AICOM_WITHDRAW_MIN_ALIVE = 3};      //--- alive-count floor that triggers the withdrawal (MBT/attack-heli teams exempt).
	if (isNil "WFBE_C_AICOM_WITHDRAW_COOLDOWN")       then {WFBE_C_AICOM_WITHDRAW_COOLDOWN = 240};     //--- claude/aicom-west-stuck (bug M): min seconds between auto-rally re-arms for the SAME understrength team - ends the rally-arrive-rally livelock, gives a bounded assault window between withdrawal episodes. Explicit driver wantrally requests bypass this.
	if (isNil "WFBE_C_AICOM_DISBAND_MERGE_ENABLE")    then {WFBE_C_AICOM_DISBAND_MERGE_ENABLE = 0};  //--- fable/aicom-disband-merge (2026-08-02): master flag - decimated-team merge/disband diversion in the withdrawal evaluator (0 = off, byte-identical to HEAD). Arm to 1 after soak review.
	if (isNil "WFBE_C_AICOM_DISBAND_ALIVE_MAX")       then {WFBE_C_AICOM_DISBAND_ALIVE_MAX = 2};     //--- alive-count at or below which a repeat auto-withdraw (post-cooldown, prior rally already burned, no pending top-up) becomes a merge/disband instead of another barren rally march (2026-08-01 overnight: 53 RALLY_ORDER cycles at alive=1).
	if (isNil "WFBE_C_AICOM_DISBAND_MERGE_RANGE")     then {WFBE_C_AICOM_DISBAND_MERGE_RANGE = 500}; //--- max leader-to-leader metres to fold survivors into a same-side same-owner foot-infantry keeper team (B69 aicom-team-merge executor); no keeper in range -> wfbe_aicom_disband destructive retire.
	if (isNil "WFBE_C_AICOM_LOSS_RETREAT")            then {WFBE_C_AICOM_LOSS_RETREAT = 1};            //--- claude/u3-loss-retreat-20260725 (Grok #1): combat-loss retreat latch master flag - default OFF, fully inert. See AI_Commander_AssignTowns.sqf.
	if (isNil "WFBE_C_AICOM_LOSS_RETREAT_FRACTION")   then {WFBE_C_AICOM_LOSS_RETREAT_FRACTION = 0.5}; //--- fraction of a team's living strength lost within the sample window that latches the retreat (0.5 = half the team wiped).
	if (isNil "WFBE_C_AICOM_LOSS_RETREAT_WINDOW")     then {WFBE_C_AICOM_LOSS_RETREAT_WINDOW = 120};   //--- s: sliding sample window for the loss-fraction check (matches WFBE_C_AI_COMMANDER_TOWN_INTERVAL, the worker's own tick cadence).
	if (isNil "WFBE_C_AICOM_LOSS_RETREAT_COOLDOWN")   then {WFBE_C_AICOM_LOSS_RETREAT_COOLDOWN = 180}; //--- s: min time before this SAME latch can re-arm for a team (separate from WFBE_C_AICOM_WITHDRAW_COOLDOWN, the shared rally consumer's own re-arm gate).
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE")            then {WFBE_C_AICOM_STRIKE_STAGE = 1};            //--- HQ-strike staging: mass strikers at a rally short of the enemy HQ, then hit together.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_BODIES")     then {WFBE_C_AICOM_STRIKE_STAGE_BODIES = 14};    //--- staged bodies required before release.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_TIMEOUT")    then {WFBE_C_AICOM_STRIKE_STAGE_TIMEOUT = 240};  //--- s: release with whatever is staged (never deadlock).
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_DIST")       then {WFBE_C_AICOM_STRIKE_STAGE_DIST = 800};     //--- m short of the enemy HQ where the staging rally sits.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_ARRIVE")     then {WFBE_C_AICOM_STRIKE_STAGE_ARRIVE = 400};   //--- m: a striker within this of the rally counts as staged.
	if (isNil "WFBE_C_AICOM_JOURNEY_COMMIT")          then {WFBE_C_AICOM_JOURNEY_COMMIT = 1};          //--- never retarget a team that is closing on its town (progress >= 150m since dispatch).
	if (isNil "WFBE_C_AICOM_STRIKE_COMMIT") then {WFBE_C_AICOM_STRIKE_COMMIT = 0}; //--- 0=current (any towns-mode team is strike-grabbable); 1=a PROGRESSING team (open dispatch + progress>=150m + target still enemy) is skipped for the HQ strike-grab so an active journey is not killed. Exempts recycle-flagged + genuinely-stuck teams.
	if (isNil "WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE") then {WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE = 6}; //--- a team with this many failed journeys since its last arrival is recycled (combat- and player-guarded).
	//--- cmdcon43-pack2: AICOM effectiveness additions (items 2-4).
	if (isNil "WFBE_C_AICOM_RESEARCH_AIR")    then {WFBE_C_AICOM_RESEARCH_AIR    = 1}; //--- armed 2026-07-27 owner go. AI appends [AIR,1][AIR,2] to doctrine research when an Aircraft Factory is present.
	if (isNil "WFBE_C_AICOM_STRIKE_AT_BONUS") then {WFBE_C_AICOM_STRIKE_AT_BONUS = 0}; //--- 0=off; >0=score bonus for launcher-carrying teams in the HQ-strike picker (suggest 50).
	if (isNil "WFBE_C_AICOM_MHQ_RING_CLEAR")  then {WFBE_C_AICOM_MHQ_RING_CLEAR  = 600}; //--- m base ring-clear for MHQ standoff (was hard-coded 600; lower to shrink the exclusion zone).
	//--- aicom-orbiter-stuckdecay lane (cmdcon41-w3-orbiter, 2026-07-02). Build 89 (Ray dark pick 2026-07-03): default 0 = dark (flag-off = byte-identical to pre-feature behavior).
	if (isNil "WFBE_C_AICOM_ORBITER_DETECT")         then {WFBE_C_AICOM_ORBITER_DETECT = 0};         //--- ORBITER DETECT: track COMBAT en-route teams with no closing distance; N windows = stuck (enter strike ladder). 1 = on, 0 = off.
	if (isNil "WFBE_C_AICOM_ORBITER_WIN")            then {WFBE_C_AICOM_ORBITER_WIN   = 3};          //--- consecutive no-progress COMBAT windows before ORBITER_STUCK verdict (requires ORBITER_DETECT > 0).
	if (isNil "WFBE_C_AICOM_STUCK_DECAY")            then {WFBE_C_AICOM_STUCK_DECAY   = if (worldName == "Takistan") then {1} else {0}};          //--- STUCK DECAY: on real forward progress, decay strike counter by 1 instead of hard-resetting to 0. 1 = decay, 0 = reset. T1.4 (R3-SYNTHESIS 2026-07-20): enabled on TK - a 200m lurch on the larger map should not hard-reset the whole unstuck ladder; CH/ZG stay at the proven 0 (legacy reset).
	if (isNil "WFBE_C_AICOM_STUCK_GOALDELTA")        then {WFBE_C_AICOM_STUCK_GOALDELTA = if (worldName == "Takistan") then {1} else {0}};      //--- claude/aicom-west-stuck: AssignTowns position-stuck test measures distance-to-target CLOSED since the breadcrumb instead of raw leader displacement when 1 (root-cause fix for HighClimb-boosted wedged-hull false progress); 0 = legacy raw-displacement, byte-identical. T1.4 (R3-SYNTHESIS 2026-07-20): enabled on TK - pairs with the new HighClimb from-zero pulse in this same PR, so a pulse-nudged hull cannot be miscounted as real forward progress; CH/ZG stay at the proven 0.
	if (isNil "WFBE_C_AICOM_SVC_ALLTEAMS")            then {WFBE_C_AICOM_SVC_ALLTEAMS = 1};            //--- service/refit admits understrength INFANTRY teams too (was armour-only). Headcount-gated.
	if (isNil "WFBE_C_AICOM_TOPUP_UNIT_COST")         then {WFBE_C_AICOM_TOPUP_UNIT_COST = 300};       //--- funds charged per replacement infantryman at a rally top-up.
	if (isNil "WFBE_C_AICOM_TOPUP_COOLDOWN")          then {WFBE_C_AICOM_TOPUP_COOLDOWN = 240};        //--- s between top-ups per team.
	if (isNil "WFBE_C_AICOM_TOPUP_REQ_TTL")           then {WFBE_C_AICOM_TOPUP_REQ_TTL = 300};         //--- s before a deferred wfbe_aicom_topup_req is dropped so the commander can re-evaluate.
	if (isNil "WFBE_C_AICOM_TOPUP_HUMAN_MULT")        then {WFBE_C_AICOM_TOPUP_HUMAN_MULT = 0.25};     //--- cmdcon42 (Ray, TOPUP Option B): refit-cost multiplier while a HUMAN holds the commander seat (heavily discounted - the player commander gets no kill income from his squads). AI commander pays full (1). 1 = no discount.
	if (isNil "WFBE_C_AICOM_TOPUP_HUMAN_COST")        then {WFBE_C_AICOM_TOPUP_HUMAN_COST = 0};       //--- QM REFIT FREE FOR PLAYER COMMANDER (Ray owner ruling, 2026-07-21): passive Quartermaster top-up cost toggle for a SEATED HUMAN commander (AI_Commander_Produce.sqf), mirrors the WFBE_C_CMD_REFIT_COST toggle used by the explicit REFIT verb. 0 = FREE (default): the human-seated commander's auto top-up charges nothing and is never blocked by low funds. >0 = legacy discounted charge via WFBE_C_AICOM_TOPUP_HUMAN_MULT (unchanged, still 0.25 default). AI commander always pays full price (mult=1); this flag is not consulted for it.
	//--- cmdcon41-w3d COMMAND-MENU V2: new steering verbs (RALLY/REFIT/HOLD) + non-commander REQUEST-AI-SUPPORT nudge.
	if (isNil "WFBE_C_CMD_MENU_V2")                    then {WFBE_C_CMD_MENU_V2 = 1};                   //--- master flag for the cmdcon41-w3d command-menu additions (steering verbs, nudge, UnitCamera guard). 0 = off.
	if (isNil "WFBE_C_CMD_NUDGE_COOLDOWN")            then {WFBE_C_CMD_NUDGE_COOLDOWN = 180};          //--- s per-player cooldown on the non-commander "REQUEST AI SUPPORT" nudge.
	if (isNil "WFBE_C_TEAM_FOCUS_COOLDOWN")           then {WFBE_C_TEAM_FOCUS_COOLDOWN = 120};         //--- s SERVER-SIDE per-player cooldown on the commander "aicom-focus" order (TP-13; client guard alone was spammable). 0 = disable (legacy behaviour).
	if (isNil "WFBE_C_CMD_VERB_COOLDOWN")             then {WFBE_C_CMD_VERB_COOLDOWN = 60};            //--- s SERVER-SIDE per-player cooldown on the aicom-posture/fieldorder/defend/reinforce command verbs (TP-20; each verb had only a client-side cooldown). 0 = disable.
	if (isNil "WFBE_C_RESPAWNST_COOLDOWN")            then {WFBE_C_RESPAWNST_COOLDOWN = 120};          //--- s SERVER-SIDE per-side cooldown on "RespawnST" (force-kills every AI supply truck for a side). Genuine repeat-abuse mitigation under WFBE_C_SEC_HARDENING (raised from 30s - the button is a rare/deliberate action, not a fast-cadence one); the requester check alongside it is identity-narrowing, NOT authentication (client-computable value - see Server_HandleSpecial.sqf "RespawnST"). Client's own 5s ctrlEnable throttle is not authoritative. 0 = disable.
	if (isNil "WFBE_C_CMD_NUDGE_RANGE")              then {WFBE_C_CMD_NUDGE_RANGE = 1500};            //--- m max distance a nudged AI team may be from the requesting player.
	if (isNil "WFBE_C_CMD_REFIT_COST")               then {WFBE_C_CMD_REFIT_COST = 0};                //--- commander REFIT order charge toggle. 1 = legacy charging (funds debited per missing man). Ray 2026-07-04 default free (0): the player-commander REFIT verb costs nothing and is never blocked by low funds; mechanics/cooldown unchanged.
	//--- cmdcon42-o ENEMY-BASE INTEL-LEAK CLAMP (Ray 2026-07-02): the war-room roster + AI-objective marker must not reveal the hidden enemy HQ when your squads push it (HQ-strike / base-assault order destinations). Producer-side: any RENDERED order destination within HQ_RADIUS of an ENEMY side's HQ is clamped to the nearest enemy-held town ("(advancing)"), never the true base pin. The team's real movement destination is untouched (recon-by-presence still works).
	if (isNil "WFBE_C_CMD_INTEL_SANITIZE")            then {WFBE_C_CMD_INTEL_SANITIZE = 1};            //--- 1 = clamp order-destination DISPLAY surfaces near the enemy base; 0 = legacy (show true destination).
	if (isNil "WFBE_C_CMD_INTEL_HQ_RADIUS")           then {WFBE_C_CMD_INTEL_HQ_RADIUS = 800};         //--- m: a rendered order destination within this of an ENEMY HQ is clamped to the nearest enemy-held town.
	if (isNil "WFBE_C_AICOM_ECON_SINK")               then {WFBE_C_AICOM_ECON_SINK = 1};               //--- Ray: convert capped funds into pressure - dep-respecting research + team-cap surge + heavier draws.
	if (isNil "WFBE_C_AICOM_ECON_SINK_FRAC")          then {WFBE_C_AICOM_ECON_SINK_FRAC = 0.85};       //--- rich threshold as a fraction of the wealth cap.
	if (isNil "WFBE_C_AICOM_ECON_SINK_TEAMCAP")       then {WFBE_C_AICOM_ECON_SINK_TEAMCAP = 2};       //--- extra founding target while rich (still under the hard cap).
	if (isNil "WFBE_C_AICOM_ECON_SINK_HUMAN_OFF")     then {WFBE_C_AICOM_ECON_SINK_HUMAN_OFF = 1};     //--- cmdcon42 (Ray): 1 = pause the econ-sink (surge + auto-research/spend) whenever a HUMAN sits in the commander slot, even under AICOM_LOCK. 0 = legacy (sink runs regardless).
	//--- WAR-CHEST REQUISITION (cmdcon44 economy-sink, claude 2026-07-07): the V2 commander banks unbounded
	//--- funds once team founding pins at the hard cap (rc13 live: EAST 218k -> 726k+ in one round with only
	//--- TOPUP spend) - the ECON_SINK above only engages at 85% of the 1.5M wealth cap, so the 250k-1.27M band
	//--- has NO sink. When at team cap with funds over FLOOR+COST, the supervisor arms a PAID early wildcard
	//--- draw: the wildcard worker debits COST and rolls the normal curated deck (W1 War Chest excluded on
	//--- paid draws - no funds-refund card). Converts the hoard into visible battlefield events through the
	//--- existing tested deck. Owner-approved DEFAULT ON 2026-07-07 (lobby toggle in Rsc/Parameters.hpp;
	//--- the param default= overrides this constant - keep them in sync). 0 = fully inert.
	if (isNil "WFBE_C_AICOM2_REQDRAW_ENABLE")   then {WFBE_C_AICOM2_REQDRAW_ENABLE   = 1};      //--- master switch (owner default ON 2026-07-07; 0 = dark).
	if (isNil "WFBE_C_AICOM2_REQDRAW_FLOOR")    then {WFBE_C_AICOM2_REQDRAW_FLOOR    = 250000}; //--- operating reserve: the sink never drains funds below this.
	if (isNil "WFBE_C_AICOM2_REQDRAW_COST")     then {WFBE_C_AICOM2_REQDRAW_COST     = 75000};  //--- price of one requisitioned draw.
	if (isNil "WFBE_C_AICOM2_REQDRAW_COOLDOWN") then {WFBE_C_AICOM2_REQDRAW_COOLDOWN = 480};    //--- min seconds between paid draws (max ~9.4k/min drain vs ~5.5k/min observed rc13 accrual).
	if (isNil "WFBE_C_AICOM_MHQ_FINAL_STEPBACK")      then {WFBE_C_AICOM_MHQ_FINAL_STEPBACK = 120};    //--- m per step back toward own HQ when the final deploy spot fails revalidation.
	if (isNil "WFBE_C_AICOM_MHQ_FINAL_MAXTRIES")      then {WFBE_C_AICOM_MHQ_FINAL_MAXTRIES = 12};     //--- revalidation step-back attempts before the safe fallback.
	if (isNil "WFBE_C_AICOM_MHQ_ROUTE_DEESC")         then {WFBE_C_AICOM_MHQ_ROUTE_DEESC = 1};         //--- MHQ drive de-escalates (AWARE/NORMAL) near contact instead of barrelling in careless.
	if (isNil "WFBE_C_AICOM_MHQ_ROUTE_GRACE")         then {WFBE_C_AICOM_MHQ_ROUTE_GRACE = 12};        //--- s pushed onto the stuck/deadline clocks per contact tick.
	if (isNil "WFBE_C_AICOM_MHQ_HUMAN_FRONT_DIST")    then {WFBE_C_AICOM_MHQ_HUMAN_FRONT_DIST = 900};  //--- defer relocation when a friendly HUMAN fights within this of the destination (0 = off).

	//--- === cmdcon41 wave-3 (Ray picks 2026-07-02): a-life encounter layer + smoke + carriers + territorial win + EASA/gear ===
	if (isNil "WFBE_C_TOWNS_SORTIES")                 then {WFBE_C_TOWNS_SORTIES = 1};                 //--- active-town garrisons rotate a 4-man sortie on a 300-800m loop (existing teams, no new groups; instant recall on contested).
	if (isNil "WFBE_C_TOWNS_SORTIE_MINS")             then {WFBE_C_TOWNS_SORTIE_MINS = 8};             //--- minutes per sortie rotation.
	if (isNil "WFBE_C_TOWNS_SORTIES_PROXIMITY")       then {WFBE_C_TOWNS_SORTIES_PROXIMITY = 0};       //--- cmdcon41-w3p: gate NEW sortie launches on a real player being within range (see next); 0 = off/legacy (byte-identical), owner opts in.
	if (isNil "WFBE_C_TOWNS_SORTIES_PROXIMITY_RANGE") then {WFBE_C_TOWNS_SORTIES_PROXIMITY_RANGE = 1500}; //--- cmdcon41-w3p: m radius used only when the flag above is armed; ~700m past the 800m sortie-ring outer edge so an approaching player sees the patrol before reaching it.
	if (isNil "WFBE_C_TOWNS_SORTIES_RTB")             then {WFBE_C_TOWNS_SORTIES_RTB = 0};             //--- u3-sortie-despawn: rotation-end gets a bounded return-to-town-centre leg instead of an abrupt end-state clear; 0 = INERT (legacy instant clear, unchanged).
	if (isNil "WFBE_C_TOWNS_SORTIE_RTB_TIMEOUT")      then {WFBE_C_TOWNS_SORTIE_RTB_TIMEOUT = 180};    //--- s cap on the RTB leg above (never an unbounded wait even if the group gets stuck short of the town).
	if (isNil "WFBE_C_PATROLS_ROADBIAS")              then {WFBE_C_PATROLS_ROADBIAS = 1};              //--- upgrade-tier patrols route along ROADS between owned towns/HQ (players drive roads -> encounters); legacy random fallback.
	if (isNil "WFBE_C_PATROLS_ROADBIAS_MOTORIZED")    then {WFBE_C_PATROLS_ROADBIAS_MOTORIZED = 1};    //--- road patrols prefer vehicle-containing pool entries (full-pool fallback for foot-only pools e.g. TKGUE).
	if (isNil "WFBE_C_AICOM_SMOKE")                   then {WFBE_C_AICOM_SMOKE = 1};                   //--- smoke discipline: shells on the assault approach axis + covering smoke on break-off.
	if (isNil "WFBE_C_AICOM_SMOKE_COOLDOWN")          then {WFBE_C_AICOM_SMOKE_COOLDOWN = 120};        //--- s between smoke uses per team.
	if (isNil "WFBE_C_AICOM_ARMOR_SCREEN")    then {WFBE_C_AICOM_ARMOR_SCREEN = 0};    //--- armor-screen: tanks screen outward on arrival instead of SAD with infantry (0=off, default).
	if (isNil "WFBE_C_AICOM_ARMOR_SCREEN_R")  then {WFBE_C_AICOM_ARMOR_SCREEN_R = 80}; //--- m stand-off radius for the outward screen position.
	if (isNil "WFBE_C_GEAR_MAG_SLOTS")                then {WFBE_C_GEAR_MAG_SLOTS = 12};              //--- fable/gear-charge-fix: formal registration (was read with an inline 12 default at the cap sites, never registered - policy gap). Magazine slots a bought loadout is capped to; the charge is computed AFTER this cap.
	if (isNil "WFBE_C_CLIENT_CRATER_CLEANER")         then {WFBE_C_CLIENT_CRATER_CLEANER = 1};        //--- ARMED 2026-07-28 (owner: crash craters persist): per-client CraterLong/CraterLong_small sweep - craters are engine-spawned CLIENT-LOCAL, invisible to the server-side crater_cleaner. Age + combat-quiet guarded. 0 = off.
	if (isNil "WFBE_C_CLIENT_CRATER_PERIOD")          then {WFBE_C_CLIENT_CRATER_PERIOD = 120};       //--- sweep cadence seconds (floor 30).
	if (isNil "WFBE_C_CLIENT_CRATER_AGE")             then {WFBE_C_CLIENT_CRATER_AGE = 600};          //--- crater minimum age before deletion (stamped at first sight - engine craters carry no timestamp).
	if (isNil "WFBE_C_CLIENT_CRATER_QUIET_R")         then {WFBE_C_CLIENT_CRATER_QUIET_R = 150};      //--- any live soldier besides the player within this radius keeps the scar (no mid-firefight vanishing).
	if (isNil "WFBE_C_CLIENT_CRATER_RADIUS")          then {WFBE_C_CLIENT_CRATER_RADIUS = 2000};      //--- scan radius around the player.
	if (isNil "WFBE_C_TAC_T4")                        then {WFBE_C_TAC_T4 = 1};                       //--- ARMED 2026-07-28 (owner picked Tactical mockup T4 "Fire Support vs Strategic split", wave 1): STRATEGIC ORDNANCE + ROUTINE SUPPORT zone cards in the Tactical Center - pure accelerators over the existing listbox/combo flows (SCUD saturation, ICBM, Paratroopers, Fast Travel), every legacy control retained, all confirms/costs/server checks unchanged. 0 = cards hidden, dialog identical to HEAD.
	if (isNil "WFBE_C_CMD_DECK")                      then {WFBE_C_CMD_DECK = 0};                     //--- ARMED 2026-07-28 (owner picked mockup C4 "Console Deck"): the Command war room gains a live header strip (funds/posture/doctrine/focus/teams/AI), zone titles, ACTIVE-state lighting on posture + field-order buttons, and ONE order combo + GIVE ORDER applying to the roster selection (replacing the 9 separate order buttons - A2 listboxes cannot host per-row widgets). 0 = today's war room, pixel-identical (new controls carry show=0 and are never admitted).
	if (isNil "WFBE_C_GUER_TOWN_AIR_REARM")           then {WFBE_C_GUER_TOWN_AIR_REARM = 1};          //--- armed 2026-07-28 owner order ("GUER players should be able to rearm air in towns"): resistance air rearm proceeds at a GUER-HELD town depot (Client_SupportRearm.sqf exemption). 0 = old blanket refusal.
	if (isNil "WFBE_C_GUER_LOCKPICK")                  then {WFBE_C_GUER_LOCKPICK = 1};                 //--- armed 2026-07-28 owner order ("They should also be able to lockpick vehicles"): resistance-only timed lockpick action on locked stationary vehicles (Init_Unit registration + Action_GuerLockpick.sqf). 0 = action hidden.
	if (isNil "WFBE_C_GUER_LOCKPICK_TIME")             then {WFBE_C_GUER_LOCKPICK_TIME = 20};           //--- lockpick channel seconds.
	if (isNil "WFBE_C_STRUCTURES_ENEMY_TOWN_RADIUS")  then {WFBE_C_STRUCTURES_ENEMY_TOWN_RADIUS = 550};  //--- m: player structures cannot be placed within this range of a town your side does not own. Was a hardcoded 600 in Init_Client.sqf; halved 2026-07-29 after the owner reported "restricted area nearly everywhere" - with GUER holding 33 towns the 600m bubbles covered most of the map. 0 disables the town rule entirely (the enemy-base-area block still applies).
	if (isNil "WFBE_C_AICOM_NUDGE_BOMB_YIELD")        then {WFBE_C_AICOM_NUDGE_BOMB_YIELD = 1};      //--- ARMED 2026-07-28 (owner: "AI is still not using other loadouts like bombs"): the heli cannon-nudge yields when the gunner already has a bomb launcher selected, instead of yanking it back to the cannon every 7s. Its anti-standoff-ATGM purpose is unaffected. 0 = legacy (nudge always overrides).
	if (isNil "WFBE_C_AIR_RUNWAY_MAX_DIST")           then {WFBE_C_AIR_RUNWAY_MAX_DIST = 2500};      //--- m: a player-bought plane is only relocated to a runway within this range of the factory. The runway scan is map-wide (100km), so without this a buyer at a base with no airfield had their plane teleported to a distant owned airfield and reported it as "not spawning" (live, player 777, 2026-07-28). 0 = uncapped (legacy).
	if (isNil "WFBE_C_AIR_RUNWAY_SPAWN")              then {WFBE_C_AIR_RUNWAY_SPAWN = 1};              //--- armed 2026-07-27 owner go ("planes dont even spawn on the runway! That has to happen"): PLAYER-bought fixed-wing relocate from the factory apron to the nearest OWNED land runway, parked aligned to the strip (Common_GetRunwaySpawn.sqf). AI plane buys already air-start via _special="FLY" in Server_BuyUnit and are untouched. 0 = old apron behaviour.
	if (isNil "WFBE_C_AIR_RUNWAY_OFFSET")             then {WFBE_C_AIR_RUNWAY_OFFSET = 60};             //--- metres from the airport logic (hangar) along the strip heading to the first parking slot; occupied slots slide +30 m (max 3).
	if (isNil "WFBE_C_NAVAL_TWIN_GAP")                then {WFBE_C_NAVAL_TWIN_GAP = 26};               //--- iteration 2 (owner 2026-07-28: "still the gap" at 32 on m0727h) - geometry is file-documented BEST-GUESS and the model origin may not sit on the hull centreline, so step to 26 (6 m overlap if beam really is 32). Was hard-coded 42 -> 32 -> 26. Tune per restart; rollback 42.
	if (isNil "WFBE_C_NAVAL_TWIN_HULLS")              then {WFBE_C_NAVAL_TWIN_HULLS = 1};              //--- Khe Sanh: outer carriers become deck-bridged TWIN-HULL super-carriers (middle keeps the SCUD, single hull).
	if (isNil "WFBE_C_NAVAL_WEST_AAV")                then {WFBE_C_NAVAL_WEST_AAV = 0};                //--- Lane 45: default-off WEST AAV buy-row metadata hook for future naval-map beach-assault work.
	if (isNil "WFBE_C_COASTAL_UTILITY_BOATS")         then {WFBE_C_COASTAL_UTILITY_BOATS = 0};         //--- Lane 184: default-off cheap PBX/RHIB-class Light-factory utility boats on coastal/naval maps only.
	if (isNil "WFBE_C_COASTAL_UTILITY_BOAT_WATER_PROBES") then {WFBE_C_COASTAL_UTILITY_BOAT_WATER_PROBES = switch (toLower worldName) do {case "chernarus": {[[7000,150,0],[13500,1800,0],[600,6500,0]]}; default {[]};}}; //--- Lane 184: edge-water probes used to qualify coastal utility boats.
	if (isNil "WFBE_C_VICTORY_TERRITORIAL")           then {WFBE_C_VICTORY_TERRITORIAL = 1};           //--- Ray: hold >= FRAC of all towns for MINS unbroken -> win (announced start/milestones/broken; existing win path).
	if (isNil "WFBE_C_VICTORY_TERRITORIAL_FRAC")      then {WFBE_C_VICTORY_TERRITORIAL_FRAC = 0.8};    //--- town share required to run the clock.
	if (isNil "WFBE_C_VICTORY_TERRITORIAL_MINS")      then {WFBE_C_VICTORY_TERRITORIAL_MINS = 30};     //--- unbroken minutes at/above FRAC to win.
	if (isNil "WFBE_C_TERRITORIAL_HUD")              then {WFBE_C_TERRITORIAL_HUD = 1};              //--- owner-armed countdown chip; set to 0 for the documented rollback; reads the server-authored WFBE_TERRITORIAL_HUD snapshot only.
	if (isNil "WFBE_C_AICOM_EASA_AI")                 then {WFBE_C_AICOM_EASA_AI = 1};                 //--- AICOM air hulls get EASA kits at founding - ONLY when WFBE_UP_EASA is genuinely researched (>=1, no shortcuts).
	if (isNil "WFBE_C_AICOM_RICH_GEAR")               then {WFBE_C_AICOM_RICH_GEAR = 1};               //--- AI squads draw richer gear per the ACTUAL researched WFBE_UP_GEAR level (ammo-safe magazine deltas only).
	if (isNil "WFBE_C_AICOM_RICH_GEAR_MIN_TIER")      then {WFBE_C_AICOM_RICH_GEAR_MIN_TIER = 2};      //--- below this researched gear tier the pass does nothing (+1 virtual tier while econ-surge, capped 5).

	//--- === cmdcon41 wave-3e (Ray 2026-07-02): patrol escalation + AICOM recovery v2 ===
	if (isNil "WFBE_C_PATROLS_ESCALATE")              then {WFBE_C_PATROLS_ESCALATE = 1};              //--- late-game patrol threat: tier draw shifts LIGHT->MEDIUM/HEAVY with match time + Patrols upgrade level.
	if (isNil "WFBE_C_PATROLS_ESCALATE_MINS")         then {WFBE_C_PATROLS_ESCALATE_MINS = 45};        //--- minutes of match time per +1 escalation step.
	if (isNil "WFBE_C_PATROLS_ESCALATE_POPTIER_MAX")  then {WFBE_C_PATROLS_ESCALATE_POPTIER_MAX = 1};  //--- FPS guard: max pop-tier degradation at which escalation may still apply (clamps to base draw under load).
	if (isNil "WFBE_C_PERFORMANCE_AUDIT_SIDE_PATROL_PROBES") then {WFBE_C_PERFORMANCE_AUDIT_SIDE_PATROL_PROBES = 0}; //--- Lane 30: extra side-patrol PerformanceAudit records for dispatch waits, target picks and retargets. Default 0 keeps the normal audit surface unchanged.
	if (isNil "WFBE_C_SERVER_FPS_GUI_ACTIVE_PLAYERS_ONLY") then {WFBE_C_SERVER_FPS_GUI_ACTIVE_PLAYERS_ONLY = 0}; //--- Lane 112: 1 = publish SERVER_FPS_GUI only while a non-HC human player is connected. Default 0 preserves legacy every-8s broadcasts.
	if (isNil "WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY")  then {WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY = 0};  //--- Lane 111: default 0 keeps the legacy 20s marker-feed rebroadcast; 1 publishes only on feed change or keepalive.
	if (isNil "WFBE_C_SIDE_PATROL_FEED_KEEPALIVE")    then {WFBE_C_SIDE_PATROL_FEED_KEEPALIVE = 60};   //--- Seconds between change-aware marker-feed keepalive broadcasts; floored to 20s in server_side_patrols.sqf.
	if (isNil "WFBE_C_SIDE_PATROL_RTB")               then {WFBE_C_SIDE_PATROL_RTB = 1};               //--- Grok #16 A-Life polish: default 0 preserves legacy fight-to-the-death patrols. At 1, a patrol under 50% living strength cancels its frontline gravitation/camp-sweep and MOVEs to the nearest owned town, then despawns via the existing wipe/cleanup path on arrival or after a 10-min bounded timeout (Common_RunSidePatrol.sqf). Self-contained in the patrol runner script - no new PV endpoint, HC-delegation-safe (runs wherever the patrol already executes).
	//--- Grok idea #8 (2026-07-25): side patrols run their OWN waypoint loop and never receive AICOM's
	//--- global unstuck care (see Common_RunUnstuckRecovery.sqf's own header note). This arms
	//--- server_side_patrols.sqf's EXTERNAL lead-vehicle-position watchdog - independent of the patrol's
	//--- own script thread, so it keeps working even if a delegated HC hangs/freezes (unlike
	//--- Common_RunSidePatrol.sqf's existing internal ~90s en-route guard, which dies with its thread).
	//--- Default 0 = byte-identical legacy behaviour.
	if (isNil "WFBE_C_SIDE_PATROL_UNSTUCK")            then {WFBE_C_SIDE_PATROL_UNSTUCK = 1};
	if (isNil "WFBE_C_SIDE_PATROL_UNSTUCK_MINS")        then {WFBE_C_SIDE_PATROL_UNSTUCK_MINS = 3};        //--- minutes between watchdog samples per active patrol.
	if (isNil "WFBE_C_SIDE_PATROL_UNSTUCK_DIST")        then {WFBE_C_SIDE_PATROL_UNSTUCK_DIST = 20};       //--- m; lead-vehicle displacement below this since the last sample counts as "not moving".
	if (isNil "WFBE_C_SIDE_PATROL_UNSTUCK_WP_DIST")     then {WFBE_C_SIDE_PATROL_UNSTUCK_WP_DIST = 150};   //--- m; only escalate while the patrol's current waypoint is still this far away (arrived/sweeping patrols never qualify).
	if (isNil "WFBE_C_SIDE_PATROL_UNSTUCK_MAX_STRIKES") then {WFBE_C_SIDE_PATROL_UNSTUCK_MAX_STRIKES = 3}; //--- strike ladder length: re-issue waypoint (Common_RunUnstuckRecovery tier2) -> setPos nudge to nearest road (tier3) -> recycle the patrol.
	if (isNil "WFBE_C_AICOM_RECOVERY_V2")             then {WFBE_C_AICOM_RECOVERY_V2 = 1};             //--- unstuck v2: vehicle unflip, reverse+lane-flip repath, dead-driver swap, slope-aware foot nodes, water guard.
	if (isNil "WFBE_C_AICOM_RECOVERY_REVERSE_SPEED")  then {WFBE_C_AICOM_RECOVERY_REVERSE_SPEED = 6};  //--- m/s of the brief reverse pulse before re-pathing a stuck vehicle.
	if (isNil "WFBE_C_AICOM_RECOVERY_SLOPE_Z")        then {WFBE_C_AICOM_RECOVERY_SLOPE_Z = if (worldName == "Takistan") then {0.80} else {0.85}};     //--- surfaceNormal z below this = too steep for a foot waypoint node -> snap to nearest road. TK ridge grades hit 0.85 (~32deg) far more than rolling Chernarus, so a lower TK threshold (0.80, ~37deg) snaps only genuinely-too-steep foot nodes instead of constantly. isNil guard keeps any pre-set (flag/param) global as the override.
	if (isNil "WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R")    then {WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R = if (worldName == "Takistan") then {300} else {200}};  //--- m search radius for that road snap. Wider on TK's sparse mountain road net so the snap actually finds a track.
	if (isNil "WFBE_C_AICOM_RECOVERY_NOROAD_STEP")     then {WFBE_C_AICOM_RECOVERY_NOROAD_STEP = 1};      //--- cmdcon44i: when the tier-3 road-snap finds NO road (roadless mountain shelf - the ZG SE spawn shelf that pinned EAST foot teams at match start), step the leader/hull toward the objective instead of leaving it wedged forever. 0 = old behaviour (do nothing when no road).
	if (isNil "WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST") then {WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST = 90};//--- m the no-road recovery step moves toward the order destination (clamped so it never overshoots past the dest; snapped to nearest isFlatEmpty non-water ground).
	if (isNil "WFBE_C_AICOM_RECOVERY_NOTIFY")          then {WFBE_C_AICOM_RECOVERY_NOTIFY = 1};            //--- Grok idea #28: 1 = tell the seated human commander (only) when the stuck-recovery ladder fires tier 2+ on one of their AI teams. 0 = off (byte-identical - see Common_AICOMRecoveryNotify.sqf).
	if (isNil "WFBE_C_AICOM_RECOVERY_NOTIFY_MIN_TIER") then {WFBE_C_AICOM_RECOVERY_NOTIFY_MIN_TIER = 2};   //--- only tier >= this fires the notify (tier-1 wedge-breaks are common/minor; tier 2/3 are the ones worth a commander's attention).
	if (isNil "WFBE_C_AICOM_RECOVERY_NOTIFY_COOLDOWN") then {WFBE_C_AICOM_RECOVERY_NOTIFY_COOLDOWN = 300}; //--- seconds - at most one notify per TEAM in this window.

	//--- === cmdcon41 wave-3g/3h (Ray 2026-07-02): SCUD arc - carrier theatrics, TEL platform, autofuel ===
	if (isNil "WFBE_C_AICOM_AUTOFUEL")                then {WFBE_C_AICOM_AUTOFUEL = 1};                //--- Ray: AICOM vehicles + relocating MHQ never run dry (silent top-off below the threshold).
	if (isNil "WFBE_C_AICOM_AUTOFUEL_BELOW")          then {WFBE_C_AICOM_AUTOFUEL_BELOW = 0.25};      //--- fuel fraction that triggers the top-off.
	if (isNil "WFBE_C_SCUD_THEATRICS")                then {WFBE_C_SCUD_THEATRICS = 1};                //--- carrier SCUD launch show: erect (scudLaunch action), backblast smoke, owning-side klaxon.
	if (isNil "WFBE_C_SCUD_MENU")                     then {WFBE_C_SCUD_MENU = 1};                     //--- "SCUD STRIKE (carrier)" Tactical-menu entry (map-click, fires the existing carrier ScudStrike payload).
	if (isNil "WFBE_C_ICBM_TEL")                      then {WFBE_C_ICBM_TEL = 1};                      //--- land SCUD TEL: spawns at SCUD research L1, empty+locked (no red blip), destroyable counterplay.
	if (isNil "WFBE_C_ICBM_TEL_COUNTDOWN")            then {WFBE_C_ICBM_TEL_COUNTDOWN = 300};          //--- s: NUKE countdown (kill the TEL before T-0 -> strike canceled, no refund).
	if (isNil "WFBE_C_ICBM_TEL_PING_FUZZ")            then {WFBE_C_ICBM_TEL_PING_FUZZ = 400};          //--- m: fuzzy enemy intel-ping offset during a NUKE countdown.
	if (isNil "WFBE_C_ICBM_TEL_RESPAWN")              then {WFBE_C_ICBM_TEL_RESPAWN = 600};            //--- s until a destroyed TEL respawns at base.
	if (isNil "WFBE_C_ICBM_TEL_COOLDOWN")             then {WFBE_C_ICBM_TEL_COOLDOWN = 300};           //--- s SHARED cooldown across ALL TEL munitions.
	if (isNil "WFBE_C_ICBM_TEL_RANGE")                then {WFBE_C_ICBM_TEL_RANGE = if (worldName == "Takistan") then {8240} else {10350}};            //--- m range cap for non-NUKE munitions (GRAD 9000 x 1.15); NUKE unlimited. Map-fraction parity (cmdcon42-h, TK value = Ray's pick): 10350 is 0.674 of the 15360 CH width and would be 0.81 of the smaller 12800 TK map; TK uses 8240 (0.644 of TK width) so the land TEL covers a comparable relative footprint (~64%) instead of map-spanning. isNil guard keeps any pre-set/param global as the override.
	if (isNil "WFBE_C_ICBM_TEL_SAT_COST")             then {WFBE_C_ICBM_TEL_SAT_COST = 12000};         //--- SATURATION (carrier MIRV set from the TEL) funds cost.
	if (isNil "WFBE_C_ICBM_TEL_RECON_COST")           then {WFBE_C_ICBM_TEL_RECON_COST = 10000};       //--- RECON FLASH funds cost (Ray-priced).
	if (isNil "WFBE_C_ICBM_TEL_RECON_R")              then {WFBE_C_ICBM_TEL_RECON_R = 800};            //--- m reveal radius of the recon airburst.
	if (isNil "WFBE_C_ICBM_TEL_RECON_SECS")           then {WFBE_C_ICBM_TEL_RECON_SECS = 45};          //--- s the reveal + temp markers last.

	//--- cmdcon41-w3i: the three Ray-priced conventional munitions (fired from the same TEL pipeline).
	if (isNil "WFBE_C_ICBM_TEL_FASCAM_COST")          then {WFBE_C_ICBM_TEL_FASCAM_COST = 14000};       //--- FASCAM mine barrage price.
	if (isNil "WFBE_C_ICBM_TEL_FASCAM_MINES")         then {WFBE_C_ICBM_TEL_FASCAM_MINES = 24};         //--- AT mines per field.
	if (isNil "WFBE_C_ICBM_TEL_FASCAM_R")             then {WFBE_C_ICBM_TEL_FASCAM_R = 150};            //--- m scatter radius.
	if (isNil "WFBE_C_ICBM_TEL_FASCAM_MINS")          then {WFBE_C_ICBM_TEL_FASCAM_MINS = 20};          //--- minutes before the field self-clears.
	if (isNil "WFBE_C_ICBM_TEL_FASCAM_MAX")           then {WFBE_C_ICBM_TEL_FASCAM_MAX = 2};            //--- max live fields per side (refused before charging).
	if (isNil "WFBE_C_ICBM_TEL_FASCAM_MINE_W")        then {WFBE_C_ICBM_TEL_FASCAM_MINE_W = "MineMine"};  //--- placed-mine class, west (createMine idiom).
	if (isNil "WFBE_C_ICBM_TEL_FASCAM_MINE_E")        then {WFBE_C_ICBM_TEL_FASCAM_MINE_E = "MineMineE"}; //--- placed-mine class, east/GUER.
	if (isNil "WFBE_C_ICBM_TEL_RAIN_COST")            then {WFBE_C_ICBM_TEL_RAIN_COST = 7500};          //--- STEEL RAIN price.
	if (isNil "WFBE_C_ICBM_TEL_RAIN_BURSTS")          then {WFBE_C_ICBM_TEL_RAIN_BURSTS = 18};          //--- airbursts per barrage (~20s roll).
	if (isNil "WFBE_C_ICBM_TEL_RAIN_R")               then {WFBE_C_ICBM_TEL_RAIN_R = 300};              //--- m burst-spread radius.
	if (isNil "WFBE_C_ICBM_TEL_RAIN_BURST_R")         then {WFBE_C_ICBM_TEL_RAIN_BURST_R = 40};         //--- m per-burst kill radius vs EXPOSED infantry only.
	if (isNil "WFBE_C_ICBM_TEL_BUSTER_COST")          then {WFBE_C_ICBM_TEL_BUSTER_COST = 18000};       //--- BUNKER BUSTER price.
	if (isNil "WFBE_C_ICBM_TEL_BUSTER_R")             then {WFBE_C_ICBM_TEL_BUSTER_R = 30};             //--- m: nearest enemy structure within this of impact dies guaranteed.

	//--- cmdcon42-j (Ray 2026-07-02): PRODUCIBLE SCUD on Takistan. A driveable MAZ_543_SCUD_TK_EP1 buyable at the HEAVY
	//--- FACTORY (both sides) on TAKISTAN ONLY (worldName-gated where the buy row + metadata register). It becomes a mobile
	//--- side launch platform: for CONVENTIONAL TEL munitions the launch platform is the NEAREST ALIVE side platform (research
	//--- TEL or a bought SCUD) to the target, and range is measured FROM THAT PLATFORM (drive closer to reach further). NUKE
	//--- stays research-TEL-only. Per-platform cooldown for conventional shots (parallel fire for big money). No respawn (it's a
	//--- purchase). AICOM never buys it (team-template production only; the buy roster is not an AICOM source). No nuke ever.
	if (isNil "WFBE_C_TK_SCUD_HF")                    then {WFBE_C_TK_SCUD_HF = 1};                     //--- master: producible SCUD at HF (worldName-gated to "Takistan" unless WFBE_C_SCUD_DRIVABLE_ALLMAPS > 0 - see below).
	if (isNil "WFBE_C_TK_SCUD_HF_COST")               then {WFBE_C_TK_SCUD_HF_COST = 28000};            //--- buy-row price of the producible SCUD launcher (conventional).
	if (isNil "WFBE_C_TK_SCUD_HF_LEVEL")              then {WFBE_C_TK_SCUD_HF_LEVEL = 3};               //--- required HEAVY factory upgrade level for the buy row (the row's tier field).
	if (isNil "WFBE_C_TK_SCUD_HF_MAX")                then {WFBE_C_TK_SCUD_HF_MAX = 2};                 //--- max LIVE bought SCUDs per side (purchase refused at cap; destroyed ones do NOT respawn).
	if (isNil "WFBE_C_TK_SCUD_HF_TYPE")               then {WFBE_C_TK_SCUD_HF_TYPE = "MAZ_543_SCUD_TK_EP1"};  //--- hull class of the producible SCUD (proven in-tree; same as the research TEL).

	//--- cmdcon42-n (Ray 2026-07-02): AI COMMANDER SCUD USAGE (Takistan only, all worldName-gated). Ray: "allow AI commanders on
	//--- Takistan to use the SCUD, just not spam it at enemy base." A low-cadence evaluator (Server\Init\Init_IcbmTel.sqf) lets an
	//--- AI-commanded side with SCUD research >=1 + an alive launch platform fire SATURATION at the largest ENEMY cluster in range,
	//--- HARD-EXCLUDING anything within HQ_EXCLUSION of an enemy HQ (never the base). NUKE stays human/research-TEL-only.
	if (isNil "WFBE_C_TK_SCUD_AI")                    then {WFBE_C_TK_SCUD_AI = 1};                     //--- master: AI commanders may use the SCUD on Takistan (0 = off, human-only as before).
	if (isNil "WFBE_C_TK_SCUD_AI_TICK")               then {WFBE_C_TK_SCUD_AI_TICK = 120};             //--- s between AI SCUD evaluations (cheap; each side eval self-gates).
	if (isNil "WFBE_C_TK_SCUD_AI_INTERVAL")           then {WFBE_C_TK_SCUD_AI_INTERVAL = 600};         //--- s per-side minimum between AI launches (on top of the per-platform cooldown).
	if (isNil "WFBE_C_TK_SCUD_AI_MIN_CLUSTER")        then {WFBE_C_TK_SCUD_AI_MIN_CLUSTER = 8};        //--- min enemy units in a 300m cluster before the AI considers a target worth a SCUD.
	if (isNil "WFBE_C_TK_SCUD_AI_CLUSTER_R")          then {WFBE_C_TK_SCUD_AI_CLUSTER_R = 300};        //--- m cluster-scan radius around each candidate anchor.
	if (isNil "WFBE_C_TK_SCUD_AI_MAX_ANCHORS")        then {WFBE_C_TK_SCUD_AI_MAX_ANCHORS = 6};        //--- top-N nearest candidate anchors scanned per side per tick (bounds the cost).
	if (isNil "WFBE_C_TK_SCUD_AI_HQ_EXCLUSION")       then {WFBE_C_TK_SCUD_AI_HQ_EXCLUSION = 900};     //--- m HARD anti-base ring: the AI never targets within this of an enemy HQ (Ray's "not at the base" rule).
	if (isNil "WFBE_C_TK_SCUD_AI_CONFIRM_R")          then {WFBE_C_TK_SCUD_AI_CONFIRM_R = 350};        //--- m: a cluster must persist across 2 consecutive ticks within this radius (no reflex-nuking a passing patrol).
	if (isNil "WFBE_C_TK_SCUD_AI_BUY")                then {WFBE_C_TK_SCUD_AI_BUY = 1};                //--- sub-flag: rich AI sides may BUY one mobile SCUD via the player register path (0 = never buy).
	if (isNil "WFBE_C_TK_SCUD_AI_BUY_FUNDS")          then {WFBE_C_TK_SCUD_AI_BUY_FUNDS = 60000};      //--- AI treasury threshold (or econ-surge) above which the side may buy a SCUD.

	//--- === cmdcon41 wave-3j/3k (Ray 2026-07-02): aircraft fixes + no-building-on-roads ===
	if (isNil "WFBE_C_AICOM_PLANE_FLYHEIGHT")         then {WFBE_C_AICOM_PLANE_FLYHEIGHT = 0};          //--- fixed-wing altitude floor; 0 = map-aware (400 Chernarus / 500 Takistan ridges), >0 forces that value.
	if (isNil "WFBE_C_AICOM_PLANE_LOITER_RADIUS")     then {WFBE_C_AICOM_PLANE_LOITER_RADIUS = 600};    //--- completion radius of the plane orbit-attack MOVE (large = shallow bank, no terrain clipping).
	if (isNil "WFBE_C_AICOM_BUILD_ROADCLEAR")         then {WFBE_C_AICOM_BUILD_ROADCLEAR = 1};          //--- Ray backlog: AICOM never places base structures/HQ/MHQ-deploy on or beside roads.
	if (isNil "WFBE_C_AICOM_BUILD_ROAD_BUFFER")       then {WFBE_C_AICOM_BUILD_ROAD_BUFFER = 14};       //--- m minimum clearance from the nearest road segment (<=0 disables).
	if (isNil "WFBE_C_AICOM_BUILD_MIN_FLAT_Z") then {WFBE_C_AICOM_BUILD_MIN_FLAT_Z = 0.90};  //--- TP-19: min surfaceNormal z (0..1) to accept a build spot; higher = flatter required (~0.90 = reject >26deg). 0 = OFF (no slope gate).
	if (isNil "WFBE_C_AICOM_BUILD_TREE_CLEAR") then {WFBE_C_AICOM_BUILD_TREE_CLEAR = 10};  //--- TP-19: m radius that must be clear of map TREE/SMALL TREE for a build spot (~10 = no trees under the footprint). 0 = OFF (no tree gate).
	//--- AICOM BUILD LEASH (fable 2026-07-27, owner: 200m). Players are hard-limited to
	//--- WFBE_C_BASE_HQ_BUILD_RANGE (120m) from the HQ by coin_interface.sqf:18, but the AI commander's
	//--- placement routine (AI_Commander_Base.sqf) never referenced that constant at all - its gates are
	//--- purely LOCAL suitability (STRUCT_SPACING, road standoff, ground/slope/tree clearance), none of
	//--- which anchors the result to the base. So a factory could land arbitrarily far from HQ, which is
	//--- what the owner observed live. This bounds the drift.
	//--- Measured against _hqPos, the CURRENT build anchor - NOT the literal HQ object - because
	//--- AI_Commander_Base.sqf:1136 deliberately re-points _hqPos at a forward centre for forward-basing.
	//--- Leashing to the HQ object would silently disable that feature; leashing to _hqPos bounds drift
	//--- around whichever centre the AI actually intended.
	//--- SAFE BY CONSTRUCTION: the gate joins the same accept chain as _slopeOK/_treeClearOK, and the
	//--- raw-DRY last-resort fallback in _findBuildPos is deliberately ungated (see its header) - so a
	//--- tight leash can never leave the AI unable to place a structure, only push it to the fallback.
	//--- 0 = disabled (pre-2026-07-27 unleashed behaviour). Rollback: 0.
	if (isNil "WFBE_C_AICOM_BUILD_HQ_RANGE") then {WFBE_C_AICOM_BUILD_HQ_RANGE = 200}; //--- metres: max candidate distance from the current build anchor. Owner-set 200 (player limit is 120; WFBE_C_AICOM_BASE_RADIUS is 450 but only counts existing structures, it never constrained placement).

	if (isNil "WFBE_C_AICOM_BUILD_ROAD_CLEAR") then {WFBE_C_AICOM_BUILD_ROAD_CLEAR = 6};   //--- TP-19 (owner report 2026-07-06: AI built on dirt roads): metres radius around a build candidate that must be clear of any road segment (paved OR dirt, via nearRoads - A2-OA-safe). 0 = OFF (default, gate inert). Suggested live value 6-8 m; complement to WFBE_C_AICOM_BUILD_ROADCLEAR (the primary ON-by-default road gate).
	if (isNil "WFBE_C_SKINSEL")                       then {WFBE_C_SKINSEL = 1};                       //--- cmdcon41-w3l: skin selector master (WF-menu SKIN button + first-spawn dialog + respawn restore). Legacy WFBE_C_SKIN_SELECTOR still honored as an OR.
	if (isNil "WFBE_C_SKINSWAP_FUNDS_CARRY")          then {WFBE_C_SKINSWAP_FUNDS_CARRY = 1};          //--- cmdcon43-h: carry the player's wfbe_funds + wfbe_side across a skin swap so a failed rejoin (fresh/diverted/CIV group) never orphans his wallet to $0 (LIVE-confirmed cmdcon42b). 1 on, 0 off.
	if (isNil "WFBE_C_FUNDS_HEAL_ZERO_GRACE")         then {WFBE_C_FUNDS_HEAL_ZERO_GRACE = 90};         //--- Ray pick A (2026-07-03): seconds the client funds self-heal refuses to accept a 0 wfbe_funds as "healed" (a transient JIP-sync 0 was the old zero-latch); keeps re-requesting the server lock-step record restore. Belt-and-suspenders atop the record fix. Higher = longer no-zero window.
	if (isNil "WFBE_C_SKIN_PERSIST") then {WFBE_C_SKIN_PERSIST = 1}; //--- ARMED 2026-08-04 owner go           //--- skin-persist 2026-07-06: persist player skin choice via profileNamespace across session reconnects; re-applies on respawn. 0 = off (default, byte-identical).

	//--- === cmdcon41 wave-3m (live-RPT findings 2026-07-02): MHQ comeback + naval patrol guard ===
	if (isNil "WFBE_C_AICOM_MHQ_RELAX")               then {WFBE_C_AICOM_MHQ_RELAX = 1};               //--- losing-side comeback: when no standoff clears the full ring, relax 600+buffer -> 600 -> FLOOR instead of aborting forever (live WEST: 21/21 aborts while ringed).
	if (isNil "WFBE_C_AICOM_MHQ_RELAX_FLOOR")         then {WFBE_C_AICOM_MHQ_RELAX_FLOOR = 350};       //--- m hard floor - never deploy closer than this to a hostile town centre.
	if (isNil "WFBE_C_PATROLS_SKIP_NAVAL")            then {WFBE_C_PATROLS_SKIP_NAVAL = 1};            //--- ground patrols/sorties never target offshore naval-HVT towns (live: one patrol thrashed 80 unstucks all match on a carrier).

	//--- === cmdcon42-q (Ray 2026-07-02): rotating chat tips - "add 50 more hints that come by on rotation in the chat" ===
	//--- Client-only cosmetic (Client\Functions\Client_TipRotation.sqf, spawned from Init_Client.sqf next to Common_Onboarding.sqf).
	//--- Posts one short gameplay tip via systemChat every PERIOD seconds from a 50-tip pool; feature-tips self-hide via their own flag.
	if (isNil "WFBE_C_TIPS_ENABLE")                   then {WFBE_C_TIPS_ENABLE = 1};                   //--- cmdcon42-q: master on/off for the rotating chat-tip feed (0 = no tips at all).
	if (isNil "WFBE_C_TIPS_PERIOD")                   then {WFBE_C_TIPS_PERIOD = 900};                 //--- cmdcon42-q: seconds between tips (Ray: 15 min; floored to 30s in the client). 50-tip deck = a full cycle every ~12.5 h.
	if (isNil "WFBE_C_TIPS_INITIAL")                  then {WFBE_C_TIPS_INITIAL = 420};                //--- cmdcon42-q: seconds a fresh/JIP client waits before the FIRST tip, so it doesn't overlap the onboarding cards.
	if (isNil "WFBE_C_TIPS_SESSION_CAP")              then {WFBE_C_TIPS_SESSION_CAP = 8};               //--- tutorial-pacing pass 2026-08-08: stop the feed after this many VISIBLE tips instead of running unbounded for the whole match.
	//--- Lane 181: late-join catch-up card. DEFAULT ON (Ray pick 2026-07-04 "visually nice" pass):
	//--- side-coloured hint card for true late joiners only (round age >= MIN_AGE); reads only local or
	//--- join-seeded state (towns, wfbe_funds, wfbe_upgrades, WFBE_AICOM_* PVs). Self-clears after DURATION s.
	if (isNil "WFBE_C_JIP_CATCHUP_BRIEFING")          then {WFBE_C_JIP_CATCHUP_BRIEFING = 1};
	if (isNil "WFBE_C_JIP_CATCHUP_MIN_AGE")           then {WFBE_C_JIP_CATCHUP_MIN_AGE = 300};
	if (isNil "WFBE_C_JIP_CATCHUP_DELAY")             then {WFBE_C_JIP_CATCHUP_DELAY = 16};
	if (isNil "WFBE_C_JIP_CATCHUP_DURATION")          then {WFBE_C_JIP_CATCHUP_DURATION = 15}; //--- Seconds the card stays before self-clearing (0 = engine hint fade).
	//--- Lane 51: optional soundtrack plumbing. Master default 0 keeps every new hook inert until audio files are added and Ray enables it.
	if (isNil "WFBE_C_MUSIC_ENABLE")                  then {WFBE_C_MUSIC_ENABLE = 0};                  //--- 1 = client-side playMusic hooks may use the class names below.
	if (isNil "WFBE_C_MUSIC_MATCH_START_TRACK")       then {WFBE_C_MUSIC_MATCH_START_TRACK = "wf_music_match_start"};
	if (isNil "WFBE_C_INTRO_MUSIC_TRACK")             then {WFBE_C_INTRO_MUSIC_TRACK = ""};            //--- legacy alias kept for old profile/constant overrides.
	if (isNil "WFBE_C_MUSIC_TOWN_CAPTURE_TRACK")      then {WFBE_C_MUSIC_TOWN_CAPTURE_TRACK = "wf_music_town_capture"};
	if (isNil "WFBE_C_MUSIC_TOWN_CAPTURE_COOLDOWN")   then {WFBE_C_MUSIC_TOWN_CAPTURE_COOLDOWN = 180}; //--- seconds between capture music starts on one client.
	if (isNil "WFBE_C_MUSIC_VICTORY_TRACK")           then {WFBE_C_MUSIC_VICTORY_TRACK = "wf_music_victory"};

	//--- B57 SOAK DRAFT (2026-06-20, claude-gaming, propose-only): FOUND size decoupled from the live MIN
	//--- floor. HC-founded teams are NEVER refilled after founding (see AI_Commander_Teams.sqf B57 block),
	//--- so founding AT the floor (8) guarantees the LIVE average dribbles BELOW the 8-12 band the instant
	//--- attrition starts - the soak measured unitsPerTeam 4.2-5.1. Found nearer the midband so the live
	//--- average settles INSIDE the band. Clamped into [MIN,MAX]. Cheap stopgap; the real fix is a
	//--- reinforcement/top-up pass (see B57-SOAK-PROPOSALS.md, AI Commander section). Economy tradeoff:
	//--- bigger founds cost ~25% more supply under SUPPLY_INCOME_MULT=0.35 - review with Ray before deploy.
	if (isNil "WFBE_C_AICOM_TEAM_FOUND_SIZE") then {WFBE_C_AICOM_TEAM_FOUND_SIZE = 10}; //--- WARNING: MIN/MAX are both 10 by owner ruling (2026-07-21), so the founding clamp forces 10; changing FOUND_SIZE alone has no effect.
	//--- RELIEF HOLD: a team diverted to defend a town holds for this long, then - if the town is
	//--- still ours but no longer actively attacked OR the hold expires - it is released back to
	//--- OFFENSE instead of idling on a quiet town (never a standing-still AI). AI_Commander_Strategy.sqf.
	if (isNil "WFBE_C_AICOM_RELIEF_HOLD") then {WFBE_C_AICOM_RELIEF_HOLD = 90};  //--- s. AICOM v2 (Ray 2026-06-27 "almost never defensive"): 180->90 so a team diverted to defend snaps back to offense fast. Rollback: 180.
	//--- ASSAULT FINISH tunables (extracted from hard-coded literals in Common_RunCommanderTeam.sqf).
	if (isNil "WFBE_C_AICOM_ASSAULT_HOLD") then {WFBE_C_AICOM_ASSAULT_HOLD = 360}; //--- s: camp-first + depot-center capture-hold loop budget (was two hard-coded 150s).
	if (isNil "WFBE_C_AICOM_CAMP_STALL_PASSES") then {WFBE_C_AICOM_CAMP_STALL_PASSES = 3}; //--- B74.2 (Ray 2026-06-23): in the camp-first phase, if the count of UN-HELD camps does not DROP for this many consecutive passes (~30s each), the team stops grinding the camps and proceeds to the depot/town-centre hold so it never gets STUCK on an uncapturable/heavily-defended camp. The centre hold keeps its own WFBE_C_AICOM_CAPTURE_MAXPASSES release. 0 disables the early bail (camp-first then only ends on WFBE_C_AICOM_ASSAULT_HOLD).
	if (isNil "WFBE_C_AICOM_ASSAULT_SAD")  then {WFBE_C_AICOM_ASSAULT_SAD  = 80};  //--- m: approach-SAD radius on arrival (towns-target) (was hard-coded 250).
	//--- WAVE-1 (2026-06-19) target-abandon + capture-loop break tunables.
	//--- STUCK_ABANDON: after this many consecutive unstuck STRIKES on the SAME town (AssignTowns CAUSE-2),
	//--- the team BLACKLISTS that town for a cooldown and re-picks the next-best reachable target, instead of
	//--- grinding one unreachable/unflippable town forever (re-issue kept re-picking the same town). Guardrail:
	//--- if every candidate is blacklisted the list is cleared so the team always gets a target (never idles).
	if (isNil "WFBE_C_AICOM_STUCK_ABANDON") then {WFBE_C_AICOM_STUCK_ABANDON = 4};
	//--- D1 (cmdcon28, Ray 2026-06-30): PER-SIDE unreachable-town blacklist (AI_Commander_AssignTowns). STUCK_ABANDON
	//--- above is PER-TEAM; fresh teams kept being thrown at the same A2-pathfinder-unreachable town (overnight soak:
	//--- Stary Sobor = 105 dispatches). When SIDE_ABANDON different teams abandon the SAME town, it's blacklisted for
	//--- the WHOLE side for SIDE_BLACKLIST_COOLDOWN s. Flag-gated, reversible, A2-safe.
	if (isNil "WFBE_C_AICOM_SIDE_BLACKLIST")          then {WFBE_C_AICOM_SIDE_BLACKLIST = 1};            //--- 1=on; 0=off (legacy per-team only)
	if (isNil "WFBE_C_AICOM_SIDE_ABANDON")            then {WFBE_C_AICOM_SIDE_ABANDON = 3};              //--- # different-team abandons of one town -> side-wide blacklist
	if (isNil "WFBE_C_AICOM_SIDE_BLACKLIST_COOLDOWN") then {WFBE_C_AICOM_SIDE_BLACKLIST_COOLDOWN = 900}; //--- s a side-blacklisted town stays excluded before a retry
	//--- CAPTURE_MAXPASSES: max consecutive depot-hold passes (Common_RunCommanderTeam CAUSE-3) with
	//--- res-near==0 AND the town still NOT ours before the team RELEASES the contested/uncapturable depot
	//--- (same on-capture re-task idiom -> AssignTowns retargets) instead of holding the center forever.
	if (isNil "WFBE_C_AICOM_CAPTURE_MAXPASSES") then {WFBE_C_AICOM_CAPTURE_MAXPASSES = 2};
	//--- BLACKLIST_COOLDOWN: how long (s) an abandoned town stays excluded for THAT team (CAUSE-2 cooldown).
	if (isNil "WFBE_C_AICOM_BLACKLIST_COOLDOWN") then {WFBE_C_AICOM_BLACKLIST_COOLDOWN = 600};
	//--- AICOM SELF-SERVICE (B48). ARMED (1, hard-set) since 13fa61321 "soak(aicom): enable AICOM self-service on Chernarus for the 2026-06-19 all-day soak" - merged default OFF/dark for A/B, then soak-enabled; see the trailing comment on the flag line below. A damaged/low-ammo team detours to the nearest SAFE friendly town-centre, repairs+rearms+heals via the player primitives, then returns. See Common_AICOMServiceTick.sqf.
	WFBE_C_AICOM_SERVICE_ENABLED = 1;   //--- SOAK-ENABLED on Chernarus (Ray 2026-06-19 all-day day-soak of the rearm/repair/heal AICOM self-service). Hard SET to 1 for the soak; rollback = "if (isNil ...) then {... = 0}".
	if (isNil "WFBE_C_AICOM_SVC_DMG_THRESH") then {WFBE_C_AICOM_SVC_DMG_THRESH = 0.5};   //--- getDammage above this on a member/crew triggers a repair/heal detour.
	if (isNil "WFBE_C_AICOM_SVC_AMMO_THRESH") then {WFBE_C_AICOM_SVC_AMMO_THRESH = 0.35};//--- a weaponed combat vehicle below this ammo fraction triggers a rearm detour.
	if (isNil "WFBE_C_AICOM_SVC_SAFE_DIST") then {WFBE_C_AICOM_SVC_SAFE_DIST = 600};     //--- m: no enemy within this of leader OR service point, else stay + fight (never pulled out of contact).
	if (isNil "WFBE_C_AICOM_SVC_REACH") then {WFBE_C_AICOM_SVC_REACH = 4000};            //--- m: max detour distance to a service point (else keep fighting).
	if (isNil "WFBE_C_AICOM_SVC_TIMEOUT") then {WFBE_C_AICOM_SVC_TIMEOUT = 300};         //--- s: max EN-ROUTE drive time before the detour aborts + the team retargets the front.
	if (isNil "WFBE_C_AICOM_SVC_ARMOUR_ONLY") then {WFBE_C_AICOM_SVC_ARMOUR_ONLY = 0};   //--- B66: 1->0 - any team may self-service (was armour/air-only). 1 = only teams with a Tank/APC/Air detour (costly to replace); 0 = any team.
if (isNil "WFBE_C_AICOM_SVC_TRIGGER_DIST") then {WFBE_C_AICOM_SVC_TRIGGER_DIST = 300}; //--- B49: relaxed START gate (m). A disengaged team detours to service if NO enemy within this (was the full SAFE_DIST=600, which blocked every grinding team so the feature never fired). The hard en-route abort still uses SAFE_DIST; COMBAT teams are still never pulled out.
	//--- LATCH-RECLAIM WATCHDOG (w807-L7, fable, idle-latch audit): svcstate=="enroute" self-heals only from
	//--- WITHIN the same per-team spawned thread that set it (Common_AICOMServiceTick.sqf, called from
	//--- Common_RunCommanderTeam.sqf's HC-local 20s order loop); if that owner machine disconnects/dies before
	//--- its own WFBE_C_AICOM_SVC_TIMEOUT deadline re-check runs, the latch never clears and the team is skipped
	//--- by every order issuer forever. AI_Commander_Allocate.sqf's watchdog only reclaims once the latch is
	//--- independently proven stale by its OWN wfbe_aicom_svcdeadline field for this many CONSECUTIVE allocate
	//--- ticks (never touches a live/legit enroute team).
	if (isNil "WFBE_C_AICOM_SVC_RECLAIM_ENABLE") then {WFBE_C_AICOM_SVC_RECLAIM_ENABLE = 1}; //--- 1 = watchdog armed (default, correctness fix); 0 = kill-switch (legacy stuck-forever behaviour).
	if (isNil "WFBE_C_AICOM_SVC_RECLAIM_TICKS")  then {WFBE_C_AICOM_SVC_RECLAIM_TICKS  = 10};  //--- consecutive allocate ticks (~10min at the default 60s Strategy/Allocate cadence) the latch must be proven stale before reclaim.
	WFBE_C_AI_COMMANDER_REINFORCE_RANGE = 1200;   //--- V0.5: Produce only refills teams this close to base (wiped teams reform at base).
	WFBE_C_AICOM_FWD_REINFORCE_RANGE = 900;       //--- FILL-FIX 2026-06-18: 500->900 (rollback 500) - forward spearheads 500-900m out of the rear base couldn't refill and bled toward ~4 units; widen so front-line teams top up from the nearest forward factory. Still requires an OWNED town within range (never resupplies on enemy ground). --- FORWARD-REINFORCE (claude-gaming 2026-06-13): deep teams beyond REINFORCE_RANGE may still refill if their leader hugs an owned town within this radius (fixes the deep-spearhead bleed-out / EAST snowball). Refill spawns at the factory nearest the team, so a captured forward town resupplies its own front instead of a lone unit trekking from the rear base.
	if (isNil "WFBE_C_AICOM_FACTORY_TARGET_ENABLE") then {WFBE_C_AICOM_FACTORY_TARGET_ENABLE = 0}; //--- owner bug 07-24: 1 = refill from the eligible side-owned factory closest to the team's assigned AICOM objective, including player-built additional factories; 0 = legacy closest-to-leader selection.
	WFBE_C_AICOM_CRITICAL_STRENGTH = 0.55;        //--- FILL-FIX 2026-06-18: 0.30->0.55 (rollback 0.30) - a 4/10=40% team sat ABOVE the old 0.30 gate so only got the slow 3/cycle dribble and lingered at ~4; at 0.55 any team under ~55% rush-fills to full in one funds-permitting cycle. Bounded by funds/factory/AI-cap (130). --- RANK-2 health-gated refill (claude-gaming 2026-06-13): a server-local AI-commander team below this fraction of its template size is rushed to FULL strength in one Produce cycle (full-deficit batch), so just-founded teams form WHOLE and depleted teams stop lingering as 2-man remnants (cuts group count + drains the stuck war chest). Bounded by funds/factory/AI-cap. 0 disables.
	WFBE_C_AICOM_PRODUCE_BATCH = 4;               //--- FILL-FIX 2026-06-18: healthy-team refill batch (units/cycle for a team still ABOVE CRITICAL_STRENGTH); was implicit default 3 at AI_Commander_Produce.sqf:23. 4 lets a lightly-attrited team top off in ~1-2 cycles. Cash-gated + AI-cap bounded. Rollback: 3.
	WFBE_C_AI_DELEGATION_FPS_INTERVAL = 60 * 3; //--- A client send it's FPS average each x seconds to the server.
	WFBE_C_AI_DELEGATION_FPS_MIN = 25; //--- A client can handle groups if it's FPS average is above x.
	WFBE_C_AI_DELEGATION_GROUPS_MAX = 1; //--- A client max have up to x groups managed on his computer (high values may makes lag, be careful).
	WFBE_C_AI_PATROL_RANGE = 400;
	WFBE_C_AI_TOWN_ATTACK_HOPS_WP = 4; //--- AI may use up to x WP to attack a town.

	//--- B69 (Ray 2026-06-22) Patch C/D/E/F constants. New AICOM tunables for the Patch C/D/E/F sketches;
	//--- each isNil-guarded so a lobby param / saved profile cannot be overridden. Consumed by the matching
	//--- B69 server logic (see per-line sketch notes); inert until that logic ships.
	//--- Patch C: relief reliever-strength gate. Don't divert a team to relief unless it has at least this
	//--- many alive (a stranded 1-2 man remnant can't relieve anything; keep it on offense / let it be culled).
	if (isNil "WFBE_C_AICOM_RELIEF_MIN_ALIVE") then {WFBE_C_AICOM_RELIEF_MIN_ALIVE = 4};
	//--- Patch C: territory-credited press gate. POSTURE (AI_Commander_Strategy.sqf) presses the attack when
	//--- own maneuver strength >= this multiple of enemy strength (territory-credited). 0 disables the gate.
	if (isNil "WFBE_C_AICOM_TOWN_STRENGTH") then {WFBE_C_AICOM_TOWN_STRENGTH = 2};
	//--- Patch D: MHQ re-drive unstuck nudge. While driving, if no >25m progress for NUDGE_SECS the driver
	//--- gets a short steering nudge (NUDGE_TURN degrees) before the STUCK_SECS deploy-where-it-stands fires,
	//--- so a momentarily-wedged MHQ tries to free itself first (never left frozen).
	if (isNil "WFBE_C_AICOM_MHQ_NUDGE_SECS") then {WFBE_C_AICOM_MHQ_NUDGE_SECS = 45}; //--- s of no >25m progress before a steering nudge.
	if (isNil "WFBE_C_AICOM_MHQ_NUDGE_TURN") then {WFBE_C_AICOM_MHQ_NUDGE_TURN = 25}; //--- degrees to swing the heading on a nudge.
	//--- cmdcon-mhqstuck (2026-07-25, anti-livelock): a stuck-recovery redeploy that lands within
	//--- STUCK_MIN_DISP of the pre-mobilize HQ position does not count as resolved; after
	//--- STUCK_MAX_CYCLES consecutive trivial-displacement stuck cycles the worker backs off for
	//--- STUCK_BACKOFF seconds (see AI_Commander_MHQReloc.sqf). Master gate default 0 = fully inert
	//--- (identical to today: unbounded in-place stuck-redeploy cycling).
	if (isNil "WFBE_C_AICOM_MHQ_STUCK_ESCALATE")   then {WFBE_C_AICOM_MHQ_STUCK_ESCALATE   = 1};   //--- 1 = on, 0 = off (default; no behaviour change).
	if (isNil "WFBE_C_AICOM_MHQ_STUCK_MIN_DISP")   then {WFBE_C_AICOM_MHQ_STUCK_MIN_DISP   = 300}; //--- m: a stuck-redeploy under this from the pre-mobilize HQ pos is "trivial", not a resolution.
	if (isNil "WFBE_C_AICOM_MHQ_STUCK_MAX_CYCLES") then {WFBE_C_AICOM_MHQ_STUCK_MAX_CYCLES = 3};   //--- consecutive trivial-displacement stuck cycles allowed before backoff.
	if (isNil "WFBE_C_AICOM_MHQ_STUCK_BACKOFF")    then {WFBE_C_AICOM_MHQ_STUCK_BACKOFF    = 300}; //--- s the worker sits out once the cycle cap is hit (bounds the retry).
	//--- Patch E: AICOM supervisor watchdog restart loop. A standalone watchdog re-spawns a side's commander
	//--- supervisor PFM if its heartbeat goes stale, with a per-side cooldown (restart-storm guard).
	if (isNil "WFBE_C_AICOM_WATCHDOG") then {WFBE_C_AICOM_WATCHDOG = 1};                 //--- 1 = watchdog on (default); 0 = inert (instant rollback).
	if (isNil "WFBE_C_AICOM_WATCHDOG_SCAN") then {WFBE_C_AICOM_WATCHDOG_SCAN = 30};      //--- s between watchdog scans.
	if (isNil "WFBE_C_AICOM_WATCHDOG_COOLDOWN") then {WFBE_C_AICOM_WATCHDOG_COOLDOWN = 120}; //--- per-side min s between two restarts (restart-storm guard).
	//--- Patch E: supervisor spawn-phase jitter. Random 0..JITTER s stagger on supervisor (re)spawn so both
	//--- sides' heavy worker passes don't land on the same frame (smooths the server-FPS sawtooth).
	if (isNil "WFBE_C_AICOM_SUPERVISOR_JITTER") then {WFBE_C_AICOM_SUPERVISOR_JITTER = 7}; //--- s max random spawn-phase stagger.
	if (isNil "WFBE_C_LOOP_PHASE_JITTER") then {WFBE_C_LOOP_PHASE_JITTER = 1}; //--- Perf (2026-07-06): when 1, the heavy server loops (town capture + activation sweeps, groupsGC, dead collector, side patrols) each sleep a one-time random offset (up to one own period) at startup so their ticks stop landing on the same frames. Default off = V1 behaviour.
	//--- Perf (2026-07-25, Grok idea #24): when 1, the empty-vehicle collector (Server\FSM\emptyvehiclescollector.sqf)
	//--- and dead-object garbage collector (Server\FSM\server_collector_garbage.sqf) lengthen their between-pass
	//--- sleep under server load via Common_GetCollectorLoadScale.sqf (diag_fps tiers, ceiling 2.5x base delay) and
	//--- restore the base cadence once fps recovers. Both collectors fully drain their current snapshot every pass,
	//--- so a longer sleep only delays the NEXT sweep - it cannot grow an unbounded backlog. Default 0 = V1
	//--- behaviour (fixed 1s / 5s sleeps, helper never reads diag_fps when disarmed).
	if (isNil "WFBE_C_COLLECTOR_LOAD_SCALE") then {WFBE_C_COLLECTOR_LOAD_SCALE = 1};
	//--- Patch F: pending-slot timeout reaper. A reserved (pending) team-build slot that never materialises is
	//--- reaped after this many s so it can't permanently occupy the team budget (3 * TEAMS_INTERVAL[=90]).
	if (isNil "WFBE_C_AICOM_PENDING_TIMEOUT") then {WFBE_C_AICOM_PENDING_TIMEOUT = 270}; //--- s before a never-filled pending team slot is reaped.
	//--- B69 FINAL PIECES (Ray 2026-06-22). New AICOM tunables; isNil-guarded so a lobby param / saved profile
	//--- cannot override them. Inert until the matching B69 server logic ships.
	//--- #16 town-assault PUNCH: per-tier strength multipliers on the assault-team punch score (the AICOM weights
	//--- a HEAVY/armour assault team UP and a LIGHT/thin foot team DOWN when picking/sizing a town assault). INITIAL
	//--- TUNING ONLY - validate in soak before locking. Consumed by the B69 town-punch logic.
	if (isNil "WFBE_C_AICOM_TOWNPUNCH_HEAVY_MULT") then {WFBE_C_AICOM_TOWNPUNCH_HEAVY_MULT = 1.8}; //--- initial tuning, validate in soak.
	if (isNil "WFBE_C_AICOM_TOWNPUNCH_LIGHT_MULT") then {WFBE_C_AICOM_TOWNPUNCH_LIGHT_MULT = 0.7}; //--- initial tuning, validate in soak.
	//--- HC depleted-team MERGE (default-OFF). Server picks a same-side pair of depleted HC teams (A keep, B donor)
	//--- and broadcasts a HandleSpecial 'aicom-team-merge' [A,B] to every live HC; the HC consumer self-gates on
	//--- both leaders LOCAL, then (units B) joinSilent A (empty B reaped by existing GC). Group-count DOWN.
	if (isNil "WFBE_C_AICOM_HC_MERGE_ENABLE") then {WFBE_C_AICOM_HC_MERGE_ENABLE = 1};   //--- armed 2026-07-27 owner go. 1 = ON, 0 = off.
	if (isNil "WFBE_C_AICOM_HC_TOPUP_ENABLE") then {WFBE_C_AICOM_HC_TOPUP_ENABLE = 1};   //--- armed 2026-07-27 owner go. B74: refill attrited HC field teams; 1 = ON, 0 = off.
	//--- The worker has deliberate fallback values for its threshold/range tunables, so existing
	//--- server configs need no new parameter surface. #1498 implements and registers the worker
	//--- (AI_Commander_HCTopUp.sqf, wired from Init_Server.sqf); both switches armed 2026-07-27 owner go.
	//--- STRANDED-survivor merge (default-ON). A lone stranded remnant near another friendly team is folded in
	//--- rather than walking home / being culled; same merge payload contract. Group-count DOWN.
	if (isNil "WFBE_C_AICOM_STRANDED_MERGE")       then {WFBE_C_AICOM_STRANDED_MERGE       = 1};    //--- 1 = ON (default), 0 = off.
	if (isNil "WFBE_C_AICOM_STRANDED_MERGE_RANGE") then {if (WFBE_AICOM_SMALLMAP_ARMED) then {WFBE_C_AICOM_STRANDED_MERGE_RANGE = 2000} else {WFBE_C_AICOM_STRANDED_MERGE_RANGE = 1200}}; //--- m: a stranded remnant within this of a friendly team is merged into it.
	//--- ARMED-TRANSPORT-ONLY (default-ON, Ray 2026-06-22): in the road-march ride-pool only a hull WITH WEAPONS
	//--- (count weapons > 0 -> APC/IFV/armed technical) may carry troops. Unarmed troop-trucks no longer ferry
	//--- infantry into the town centre to be evaporated; unmounted infantry advance on foot. 0 = old behaviour.
	if (isNil "WFBE_C_AICOM_ARMED_TRANSPORT_ONLY") then {WFBE_C_AICOM_ARMED_TRANSPORT_ONLY = 1}; //--- 1 = ON (default), 0 = any drivable hull rides.

//--- Artillery.
	if (isNil "WFBE_C_ARTILLERY") then {WFBE_C_ARTILLERY = 1}; //--- Enable or disable Artillery fire missions (0: Disabled, 1: Short, 2: Medium, 3: Long).
	if (isNil "WFBE_C_ARTILLERY_UI") then {WFBE_C_ARTILLERY_UI = 0}; //--- Enable or disable Artillery UI for direct fire missions.
	if (isNil "WFBE_C_ARTY_SHARED_COOLDOWN") then {WFBE_C_ARTY_SHARED_COOLDOWN = 0}; //--- 1 = side-shared player artillery cooldown stamp on side logic; 0 = legacy client-local fireMissionTime only.
	WFBE_C_ARTILLERY_AMMO_RANGE_LASER = 175; //--- Artillery laser rounds detection range (Per Shell).
	WFBE_C_ARTILLERY_AMMO_RANGE_SADARM = 200; //--- Artillery SADARM rounds operative range (Per Shell).
	WFBE_C_ARTILLERY_AREA_MAX = 300; //---  Maximum spread area of artillery support.
	if WF_Debug then 
	{
		WFBE_C_ARTILLERY_INTERVALS = [15, 15, 15, 15, 15, 15, 15]; // In debug mod, arty reload is set to 15 seconds.
	} else 
	{
		WFBE_C_ARTILLERY_INTERVALS = [550, 500, 450, 400, 350, 300, 250]; //--- Delay between each fire mission for each upgrades.
	};

	//--- Base
	if (isNil "WFBE_C_BASE_AREA") then {WFBE_C_BASE_AREA = 2}; //--- Force the bases to be grouped by areas.
	if (isNil "WFBE_C_BASE_DEFENSE_MAX_AI") then {WFBE_C_BASE_DEFENSE_MAX_AI = 40}; //--- Maximum AIs that will be able to man defense within the barracks area.
	if (isNil "WFBE_C_BASE_DEFENSE_MANNING_RANGE") then {WFBE_C_BASE_DEFENSE_MANNING_RANGE = 250}; //--- Within x meters, defenses may be manned.
	//--- build/defense audit 2026-07-28: Server_HandleDefense.sqf's base-defense re-man watcher used to
	//--- re-check gunner liveness only once per sleep 420 (~7 min worst case before an empty gun refills).
	//--- Bounded-poll interval (s) between liveness checks once a gunner is seated; a Killed EH on the
	//--- seated gunner can wake the poll early. Correctness fix (not a feature gate) - lowering this only
	//--- shortens worst-case re-man latency, the total idle-wait cap (420s) is unchanged.
	if (isNil "WFBE_C_DEFENSE_REMAN_POLL") then {WFBE_C_DEFENSE_REMAN_POLL = 15};
	if (isNil "WFBE_C_BASE_START_TOWN") then {WFBE_C_BASE_START_TOWN = 1}; //--- Remove the spawn locations which are too far away from the towns.
	if (isNil "WFBE_C_BASE_STARTING_MODE") then {WFBE_C_BASE_STARTING_MODE = 2}; //--- Starting Locations Mode: 0 = WN|ES; 1 = WS|EN; 2 = Random. cmdcon41 (Ray): default 0 -> 2 (spawns "didn't seem random" - they were the fixed Build84 default).
	if (isNil "WFBE_C_BASE_RANDOM_PURE") then {WFBE_C_BASE_RANDOM_PURE = 1}; //--- cmdcon41 (Ray): random-PURE default (original unfiltered Miksuu random). //--- Build84 (backlog#2): 1 = Miksuu-original UNFILTERED pure-random when MODE=2 (skips the B62 airfield / B66 egress-edge / rotation filters in Init_Server); 0 = hardened filtered random (default).
	//--- Egress-quality gate (A2-fix 2026-06-14): random base placement (MODE=2) can box a side into a
	//--- corner with a single egress road, stalling its AI-commander teams (empty HC route -> PFM stall).
	//--- The Init_Server start-picker requires a candidate to have >= MIN_EGRESS_ROADS usable road
	//--- segments (roadsConnectedTo>=2) within nearRoads 250 AND sit >= EDGE_MARGIN m from any map edge.
	//--- Symmetric for both sides; degrades to accept on Vanilla A2 (no roadsConnectedTo). Fallback intact.
	if (isNil "WFBE_C_BASE_MIN_EGRESS_ROADS") then {WFBE_C_BASE_MIN_EGRESS_ROADS = 2}; //--- B66 (Ray 2026-06-21): 3->2, loosen the egress gate so the random-start pool isn't collapsed to ~1 viable pair (the "always same 2 spots" cause). Min usable road segments near a candidate start.
	if (isNil "WFBE_C_BASE_EDGE_MARGIN")      then {WFBE_C_BASE_EDGE_MARGIN      = 400}; //--- Min metres a candidate start must sit from any map edge.
	if (isNil "WFBE_C_BASE_EGRESS_MAP_BOUNDS") then {WFBE_C_BASE_EGRESS_MAP_BOUNDS = 0}; //--- Default OFF: keep the legacy 15360 edge box. 1 = use the Init_Boundaries worldName size (Takistan 12800) for random-start egress checks.
	if (isNil "WFBE_C_BASE_TOWN_CLEAR_MARGIN") then {WFBE_C_BASE_TOWN_CLEAR_MARGIN = 120}; //--- BUILD88 (cmdcon43-f): metres ADDED to each town's range (600m) to form the start-clearance radius. A LocationLogicStart within (townRange+margin) of a town centre is dropped from the random pool (Init_Server town-clearance filter) so the match-start HQ never deploys inside a town. Default 120 = WFBE_C_BASE_HQ_BUILD_RANGE so the HQ's close build ring clears the town zone (threshold 720m). 0 disables the extra margin (HQ centre must merely clear the raw 600m town range).
	if (isNil "WFBE_C_CLEANER_MAP_AWARE_ORIGINS") then {WFBE_C_CLEANER_MAP_AWARE_ORIGINS = 0}; //--- Default OFF: keep legacy Chernarus scan anchors. 1 = cleaners/restorers use Init_Boundaries map size for scan centre/radius.
	if (isNil "WFBE_C_DROPPEDITEMS_CLEANER_DEFER_FIRST") then {WFBE_C_DROPPEDITEMS_CLEANER_DEFER_FIRST = 1}; //--- Default OFF: keep the early ~90s first droppeditems sweep (HEAD). 1 = defer the first whole-island weaponholder sweep to the steady cadence so it runs on a settled server instead of inside the boot storm (fixes the ~6.5s first-sweep wall-time spike; the early sweep finds zero drops anyway). [Ray-dir 2026-07-24 FPS: 0->1 - defer 1st sweep out of the boot storm; kills the ~6.5-7.5s cold-start hitch (profiler MAX_MS 6915 with scanned:0); deferred sweep finds 0 drops = inert; rollback 0.]
	if (isNil "WFBE_C_DROPPEDITEMS_MIN_AGE") then {WFBE_C_DROPPEDITEMS_MIN_AGE = 120}; //--- s: weaponholder must be at least this old (first-seen by droppeditems_cleaner) before reaping. 0 = legacy immediate. Gives a guaranteed loot window independent of cleaner phase.
	if (isNil "WFBE_C_DROPPEDITEMS_PROX") then {WFBE_C_DROPPEDITEMS_PROX = 20}; //--- m: hold weaponholder deletion while a real player is this close (mirrors WFBE_C_UNITS_BODIES_PROX). 0 = off.
	if (isNil "WFBE_C_DROPPEDITEMS_PROX_HOLD") then {WFBE_C_DROPPEDITEMS_PROX_HOLD = 300}; //--- s: max extra hold past MIN_AGE while a player camps a pile (anti-pin). Total max life under prox = MIN_AGE + PROX_HOLD.
	if (isNil "WFBE_C_DROPPEDITEMS_HOLD_ENABLE") then {WFBE_C_DROPPEDITEMS_HOLD_ENABLE = 0}; //--- PR #1718 fix (owner ruling 2026-08-05): MIN_AGE/PROX/PROX_HOLD shipped ARMED by default with no opt-in, violating flag policy. Default OFF = pre-#1718 immediate-reap (byte-identical to HEAD before that PR). 1 = arm the age+proximity hold using the tuning values above. Gated in droppeditems_cleaner.sqf.
	WFBE_C_BASE_AREA_RANGE = 250; //--- A base area has a range of x meters.
	WFBE_C_BASE_HQ_BUILD_RANGE = 120; //--- HQ Build range.
	WFBE_C_BASE_AV_STRUCTURES = 260; //--- Base available structures.
	WFBE_C_BASE_PROTECTION_RANGE = 800;  //--- Base protection range.
	WFBE_C_BASE_HQ_REPAIR_PRICE_WEST = 25000; //--- HQ Repair price.
	WFBE_C_BASE_HQ_REPAIR_PRICE_EAST = 25000;
	WFBE_C_BASE_HQ_REPAIR_PRICE_GUER = 25000;
	WFBE_C_BASE_HQ_REPAIR_COUNT_WEST = 0; //--- How many times HQ has been repaired.
	WFBE_C_BASE_HQ_REPAIR_COUNT_EAST = 0;
	WFBE_C_BASE_HQ_REPAIR_COUNT_GUER = 0;
	WFBE_C_BASE_HQ_REPAIR_PRICE_1ST = 25000;
    WFBE_C_BASE_HQ_REPAIR_PRICE_2ND = 40000;
    WFBE_C_BASE_HQ_REPAIR_PRICE_3RD = 50000;
    WFBE_C_BASE_HQ_REPAIR_PRICE_CASH = 200000; //--- HQ Repair price with cash.
//--- Camps.
	if (isNil "WFBE_C_CAMPS_CREATE") then {WFBE_C_CAMPS_CREATE = 1}; //--- Create the camp models.
	WFBE_C_CAMPS_CAPTURE_BOUNTY = 500; //--- Bounty received by player whenever he capture a camp.
	WFBE_C_CAMPS_CAPTURE_RATE = 20;
	WFBE_C_CAMPS_CAPTURE_RATE_MAX = 25;
	WFBE_C_CAMPS_RANGE = 13.915;  //--- OWNER DESIGN DECISION 2026-07-20 07:40 (wasp-takistan-aicom-capture-stall-20260720): 12.65 -> 13.915 (+10%), continuing the 10 -> 11.5 -> 12.65 Ray tuning history. Part of the capture-completion fix (paired with the dismount-near-camp change in Common_RunCommanderTeam.sqf): widens the AI camp scan bubble a further notch so an arriving on-foot Man has more margin to register inside nearEntities before the presence-based flip. PLAYERS are UNCHANGED - WFBE_C_CAMPS_RANGE_PLAYERS (below) still gates them at 5m (server_town_camp.sqf filters players past that).
	WFBE_C_CAMPS_RANGE_PLAYERS = 8; //--- fable/fasttravel-campflag (c2 council item #4): 5.5 -> 8. The visible flag
	//--- mesh sits at WFBE_C_CAMP_FLAG_POS [-5,5] (~7.07m from the camp logic, Core_Models/CombinedOps.sqf) -
	//--- at 5.5 a player standing ON the flag did not count for capture or the CampCaptured.sqf bounty check.
	//--- 8m puts the flag inside the radius with margin; AI keep the separate, larger WFBE_C_CAMPS_RANGE
	//--- (13.915) untouched. History: 5 -> 5.5 (2026-07-07) -> 8 (2026-07-21).
	if (isNil "WFBE_C_TOWN_CAMP_SCAN_THROTTLE") then {WFBE_C_TOWN_CAMP_SCAN_THROTTLE = 0}; //--- Lane 107: default off; when 1, server_town_camp uses the slower scan sleeps below.
	if (isNil "WFBE_C_TOWN_CAMP_ACTIVE_GATE") then {WFBE_C_TOWN_CAMP_ACTIVE_GATE = 1}; //--- Perf (2026-07-06): when 1, a town's camp-scan loop idles while the town is dormant (not active, no air tier, no enemy seen within IDLE_GRACE). Default off = V1 behaviour.
	if (isNil "WFBE_C_TOWN_CAMP_IDLE_SLEEP") then {WFBE_C_TOWN_CAMP_IDLE_SLEEP = 3}; //--- s between dormancy re-checks while the camp gate idles.
	if (isNil "WFBE_C_TOWN_CAMP_IDLE_GRACE") then {WFBE_C_TOWN_CAMP_IDLE_GRACE = 60}; //--- s after the last enemy seen (wfbe_inactivity) before the camp loop may idle; covers activation-budget-deferred towns.
	if (isNil "WFBE_C_TOWN_CAMP_STEP_SLEEP") then {WFBE_C_TOWN_CAMP_STEP_SLEEP = 0.03}; //--- Per-camp sleep while scan throttle is enabled.
	if (isNil "WFBE_C_TOWN_CAMP_LOOP_SLEEP") then {WFBE_C_TOWN_CAMP_LOOP_SLEEP = 0.25}; //--- Full-pass sleep while scan throttle is enabled.
	//--- Commander stuck-reaction (Slot 2, task #14): the AssignTowns breadcrumb re-issues a
	//--- parked team's order. Was hardcoded 600s (10min) = stalemate-slow. Now config-driven.
	if (isNil 'WFBE_C_AICOM_STUCK_SECS')  then {WFBE_C_AICOM_STUCK_SECS  = 210};
	if (isNil 'WFBE_C_AICOM_STUCK_MOVED') then {WFBE_C_AICOM_STUCK_MOVED = 200};
	if (isNil 'WFBE_C_AICOM_WATCHDOG_LASTSTAND_SKIP') then {WFBE_C_AICOM_WATCHDOG_LASTSTAND_SKIP = 1}; //--- 1 = last-stand recall shields HQ defenders from wedge-watchdog release; 0 = legacy.
	if (isNil 'WFBE_C_AICOM_STUCK_FAR')   then {WFBE_C_AICOM_STUCK_FAR   = 300};
	//--- ASSAULT TELEMETRY (task #48, #2): dispatch->arrival watcher thresholds (AssignTowns Hook B).
	//--- ARRIVE_RADIUS 250m ~= town SAD radius (AIMoveTo uses 200) + leader margin to count "at the town".
	//--- TIMEOUT 420s = ~2x the 120s worker interval beyond STUCK_SECS(210) so a team gets ~3 watcher
	//--- passes before being declared stranded; this is the dispatch->arrival budget, not the stuck-reissue.
	if (isNil 'WFBE_C_AICOM_ASSAULT_TIMEOUT')       then {WFBE_C_AICOM_ASSAULT_TIMEOUT       = 420};
	//--- T0.2 ADD (R3-SYNTHESIS 2026-07-20): diagnostic-only, tighter than ARRIVE_RADIUS -
	//--- lets the STUCKSTAT uncap-parked line distinguish "still closing the last 150m" from
	//--- "genuinely at capture range and still not converting". Does not feed any capture,
	//--- abandon, or strike-ladder decision -- read-only in AI_Commander_AssignTowns.sqf.
	//--- Codex review MEDIUM fix: CAPGATE (server_town.sqf) throttle interval - see the diag_log call there.
	if (isNil 'WFBE_C_CAPGATE_LOG_INTERVAL') then {WFBE_C_CAPGATE_LOG_INTERVAL = 30};
	//--- W807B-L14 (owner-ordered fix, 2026-08-07): CAPGATE self-protect dominion gate (server_town.sqf)
	//--- lets a town's owner heal supply back to full every tick they hold local numeric dominance, even
	//--- under a genuinely sustained siege - predicted as a caveat in docs/design/NO-TOWN-UNCAPTURABLE.md
	//--- and confirmed live (wave0807b RPT: 97% of mode2 gate checks vetoed, GUER 0-for-38 in 69min).
	//--- Tapers the self-protect heal toward SIEGE_REGEN_FLOOR across SIEGE_DECAY_TICKS consecutive ticks
	//--- of self-protect WHILE a non-owner side is present; resets the instant the siege breaks. 0
	//--- disables it (instant rollback to pre-fix behaviour, byte-identical decision math).
	if (isNil "WFBE_C_CAPGATE_SIEGE_DECAY_TICKS") then {WFBE_C_CAPGATE_SIEGE_DECAY_TICKS = 24};
	if (isNil "WFBE_C_CAPGATE_SIEGE_REGEN_FLOOR") then {WFBE_C_CAPGATE_SIEGE_REGEN_FLOOR = 0.15};
	//--- P0 STRANDED FIX (task #48, claude-gaming 2026-06-15): foot/under-equipped ongoing teams were
	//--- dispatched at far spearhead towns 6-12km away (256 DISPATCH vs 13 ARRIVED, 63% >6km) - they
	//--- march cross-country and die. REACH_FOOT = max metres a non-mounted team is sent on the ONGOING
	//--- front: a spearhead farther than this from THIS team's leader is skipped in favour of the nearest
	//--- reachable uncaptured town (builds a contiguous front). Mounted teams (with a drivable vehicle in
	//--- the group) get REACH_MOUNTED so trucks/APCs can still cover the long leg. GUARDRAIL: never a ban -
	//--- if NOTHING is in reach (isolated), the team still gets its nearest target so it never idles.
	//--- BOOTSTRAP is exempt (0 towns owned -> the opening dogpile rush is unchanged).
	if (isNil 'WFBE_C_AICOM_ASSAULT_REACH_FOOT')    then {WFBE_C_AICOM_ASSAULT_REACH_FOOT    = if (worldName == "Takistan") then {1800} else {2500}};  //--- B66 (3000->2500m): tighten foot reach - keep thin foot teams on adjacent reachable towns (cut long death-marches; tighter contiguous front). [B57: 3500->3000.] cmdcon43-j (evidence-based, live TK RPT 2026-07-02): a foot team dispatched >~1800m to a Takistan mountain town GRINDS ridgelines and never arrives - every stranded foot team (RU_Soldier_LAT/AA, ASSAULT_STRANDED moved=2-11m over 8min) sat at distTgt 1819-2568m (median 2484), ZERO stuck below 1800m; on rolling Chernarus the same 2500m foot leg succeeds. TK-lower 1800 routes those teams to a nearer reachable town OR (INF_TRANSPORT, within REACH_MOUNTED 9km) hands them a truck for the mountain leg instead of a death-march. Same worldName idiom as ROAD_STANDOFF/LANE_OFFSET/RECOVERY_SLOPE_Z/RECOVERY_FOOT_ROAD_R just above. isNil guard keeps any pre-set param/global as the override.
	if (isNil 'WFBE_C_AICOM_ASSAULT_REACH_MOUNTED') then {WFBE_C_AICOM_ASSAULT_REACH_MOUNTED = 9000};  //--- m: teams with a drivable vehicle may take the long leg to a far spearhead.
	//--- T1.2 ADD (R3-SYNTHESIS 2026-07-20): fraction of a team's alive units that must be embarked
	//--- (in a canMove LandVehicle) before the team classifies as "mounted" for reach purposes;
	//--- the leader must have at least one additional embarked unit. 0.5 = the deliberation's spec.
	if (isNil 'WFBE_C_AICOM_MOUNTED_FRAC') then {WFBE_C_AICOM_MOUNTED_FRAC = 0.5};
	//--- FIX A: distance/mobility-aware assault timeout (fable, GR-2026-07-08a; design ASSAULT-DYNTIMEOUT-DESIGN.md
	//--- + ADDENDUM 1). Flag WFBE_C_AICOM_ASSAULT_DYNTIMEOUT: 0 = legacy flat WFBE_C_AICOM_ASSAULT_TIMEOUT for every
	//--- team (byte-identical to pre-change). 1 = per-dispatch dist/mobility-aware timeout, clamped MIN..MAX. ALL
	//--- numeric defaults below are ENGINEERING DEFAULTS, NOT live-measured - re-derive via the design's Section 1.3
	//--- calibration protocol from a confirmed-live ASSAULT_* RPT window before flipping this to 1 in production.
	if (isNil 'WFBE_C_AICOM_ASSAULT_DYNTIMEOUT')    then {WFBE_C_AICOM_ASSAULT_DYNTIMEOUT    = 1};
	if (isNil 'WFBE_C_AICOM_FOOT_STAGE') then {WFBE_C_AICOM_FOOT_STAGE = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on). TK arrivals pack M5: offensive staging for foot teams with no honest reach; MOVE to the friendly town nearest the enemy front and re-evaluate targets each pass.
if (isNil "WFBE_C_AICOM_WATER_LEG_GATE") then {WFBE_C_AICOM_WATER_LEG_GATE = 1}; //--- r37 water-crossing: land-only teams skip towns whose leader->town straight line is mostly water.
	if (isNil 'WFBE_C_AICOM_STRAND_RECOVERY') then {WFBE_C_AICOM_STRAND_RECOVERY = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on); supersedes the prior M6-soak gate. TK arrivals pack M3: one-shot recovery after a short-move ASSAULT_STRANDED verdict.
	if (isNil 'WFBE_C_AICOM_ASSAULT_SPEED_FOOT')    then {WFBE_C_AICOM_ASSAULT_SPEED_FOOT    = if (worldName == "Takistan") then {0.9} else {2.2}};  //--- m/s conservative cross-country foot pace. ENGINEERING DEFAULT.
	if (isNil 'WFBE_C_AICOM_ASSAULT_SPEED_MOUNTED') then {WFBE_C_AICOM_ASSAULT_SPEED_MOUNTED = if (worldName == "Takistan") then {3.5} else {7.5}};  //--- m/s effective AI-driven road speed incl. hop-node deceleration. ENGINEERING DEFAULT.
	if (isNil 'WFBE_C_AICOM_ASSAULT_SPEED_AIR')     then {WFBE_C_AICOM_ASSAULT_SPEED_AIR     = 35};   //--- m/s transport-heli team (_teamAir path, AI_Commander_AssignTowns.sqf only). ENGINEERING DEFAULT.
	//--- Map-aware route-overhead factor (worldName idiom already used elsewhere in this file, e.g. REACH_FOOT just
	//--- below). TERRAIN-CENSUS.md (docs/design/v2/) describes TK as ridges/long line-of-sight (worst detour) and ZG
	//--- as compact urban (moderate detour despite short raw distance); CH is the mixed-road-network baseline. Per-
	//--- map value, NOT a flat factor - confirm/correct via the design's Section 1.3 step 4, do not assume this ordering.
	if (isNil 'WFBE_C_AICOM_ASSAULT_ROUTE_FACTOR')  then {WFBE_C_AICOM_ASSAULT_ROUTE_FACTOR  = if (worldName == "Takistan") then {2.5} else {if (worldName == "Zargabad") then {1.35} else {1.25}}};
	if (isNil 'WFBE_C_AICOM_ASSAULT_SLACK')         then {WFBE_C_AICOM_ASSAULT_SLACK         = 120};  //--- s, one extra WFBE_C_AI_COMMANDER_TOWN_INTERVAL (120s) worker-pass margin.
	if (isNil 'WFBE_C_AICOM_ASSAULT_TIMEOUT_MIN')   then {WFBE_C_AICOM_ASSAULT_TIMEOUT_MIN   = 420};  //--- s, floor = today's flat value - short legs are byte-identical to current behaviour.
	if (isNil 'WFBE_C_AICOM_ASSAULT_TIMEOUT_MAX')   then {WFBE_C_AICOM_ASSAULT_TIMEOUT_MAX   = 1200};   //--- C6 pick 1 (owner GO 2026-07-22 19:08): was 2700 TK / 1500 other. Live evidence: only 1/39 arrivals ever exceeded 1200s; all strands burned the full 2700. Rollback: worldName conditional 2700/1500. //--- s, hard ceiling - beyond this a team is genuinely stuck (existing Recovery-V2 ladder applies), not just far.
	//--- B66 INF-TRANSPORT: when 1, a pure-infantry AI team on a long approach (beyond REACH_FOOT but within
	//--- REACH_MOUNTED) is given a faction troop-truck so foot teams can still cover the long leg instead of
	//--- being skipped. The consumer resolves the per-side transport classname from the Core_USMC / Core_RU /
	//--- Core_GUE transport classnames (MTVR / Kamaz / V3S_TK_Gue). 0 = old behaviour (foot teams capped at REACH_FOOT).
	if (isNil 'WFBE_C_AICOM_INF_TRANSPORT') then {WFBE_C_AICOM_INF_TRANSPORT = 1};
	//--- B66 (Ray 2026-06-21): tunables the b66 consumers read with safe inline defaults; defined here so they're tweakable.
	if (isNil 'WFBE_C_AICOM_TRANSPORT_AVOID_RANGE') then {WFBE_C_AICOM_TRANSPORT_AVOID_RANGE = 350}; //--- mounted transport dismounts/routes around a hostile town within this range (don't drive trucks into GUER garrisons).
	if (isNil 'WFBE_C_ECONOMY_BANK_PENDING_WINDOW') then {WFBE_C_ECONOMY_BANK_PENDING_WINDOW = 180}; //--- bank one-per-side reservation window (s) to close the duplicate-build race.
	//--- Careful-gear governor (owner refinement): the HC commander executor downshifts a
	//--- transit convoy from NORMAL to LIMITED only while the lead hull's surfaceNormal.z is
	//--- below this (steep slope) OR a stuck-strike is active; back to NORMAL once flat/moving.
	//--- z = cos(slope): 0.93 ~= 21.6deg, 0.90 ~= 25.8deg, 0.87 ~= 29.5deg. A2 vehicles handle
	//--- <=15deg (z>=0.966) fine; grief starts ~22-30deg. Lower = only the steepest grades slow.
	if (isNil 'WFBE_C_AICOM_SLOPE_Z')     then {WFBE_C_AICOM_SLOPE_Z     = if (worldName == "Takistan") then {0.80} else {0.86}};  //--- A2-fix 2026-06-14: was 0.93 (~21deg, too eager); 0.86 (~31deg) stops the LIMITED<->NORMAL accordion on rolling Chernarus roads. TK-branch (cmdcon42-h): ordinary Takistan inclines exceed 0.86 and over-throttle convoys to LIMITED, so TK uses 0.80 (~37deg) - only genuinely steep TK grades downshift. isNil guard keeps any pre-set global as the override.
	WFBE_C_CAMPS_REPAIR_DELAY = 15;
	WFBE_C_CAMPS_REPAIR_PRICE = 500;
	WFBE_C_CAMPS_REPAIR_RANGE = 15;
	//--- harden-repair-camp (2026-07-25): server-side proximity ceiling for the "repair-camp" PVF
	//--- gate (RequestSpecial.sqf). Deliberately generous vs WFBE_C_CAMPS_REPAIR_RANGE (15m, the
	//--- client's truck-to-camp scan range) - the gate checks the ACTUAL PLAYER's distance to the
	//--- camp logic, not the repair truck's, so it must tolerate the player standing/mounted a few
	//--- meters off the truck itself. Only rejects requests forged from elsewhere on the map.
	WFBE_C_CAMPS_REPAIR_SERVER_RADIUS = 50;
	//--- feat/deadcamp-presence-repair (owner redesign 2026-07-21, "AI soldiers repair a destroyed camp
	//--- by standing in its bubble for a couple of minutes"): presence-based dead-camp self-repair,
	//--- consumed by server_town_camp.sqf's dead-bunker branch. Flag default 0 = feature off (repo flag
	//--- policy); the tuning constant only matters once the flag is armed.
	if (isNil "WFBE_C_CAMP_REPAIR_PRESENCE") then {WFBE_C_CAMP_REPAIR_PRESENCE = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on).
	if (isNil "WFBE_C_CAMP_REPAIR_PRESENCE_TIME") then {WFBE_C_CAMP_REPAIR_PRESENCE_TIME = 150}; //--- s (2.5min) of continuous any-side presence in a dead camp's bubble before it self-repairs.

//--- Economy.
	if (isNil "WFBE_C_ECONOMY_CURRENCY_SYSTEM") then {WFBE_C_ECONOMY_CURRENCY_SYSTEM = 0}; //--- 0: Funds + Supply, 1: Funds.
	//--- cmdcon43-d (Build 88 FIX): COMMANDER-console defenses draw from side SUPPLY, not the commander's
	//--- personal player FUNDS. WHY: in the commander (MCoin) build menu, base STRUCTURES are priced+charged
	//--- against side supply ([0,cost] -> _itemcash 0 in Init_Coin), but DEFENSES/FORTIFICATIONS/STRATEGIC are
	//--- priced+charged against player funds ([_fix,cost] with _fix=1 under dual-currency -> reads wfbe_funds).
	//--- The commander's spendable wfbe_funds legitimately drains to ~0 (upgrades charge it; and on a freshly
	//--- claimed/JIP commander seat it can be 0/unreplicated), while side supply stays ample -> EVERY defense
	//--- item greys out (_cashValue(funds~0) - itemcost < 0) even though the commander is flush with supply and
	//--- can freely build structures. That is exactly the live Build 87 report ("defense/fortification/strategic
	//--- greyed out, all items"). Structures were never affected because they read supply. This flag makes the
	//--- commander's defenses use the SAME pool as his structures (supply) under the dual-currency system, so
	//--- they are buildable whenever supply covers the cost - matching the intuitive commander economy and the
	//--- structure path. Non-commander repair-truck (RCoin/REPAIR) placement is UNCHANGED (still funds). Under
	//--- the funds-only currency system (==1) there is no separate supply pool, so this is inert there.
	//--- REVERSIBILITY: set to 0 -> exact legacy behaviour (commander defenses priced+charged against funds).
	if (isNil "WFBE_C_CMD_DEF_SUPPLY") then {WFBE_C_CMD_DEF_SUPPLY = 0}; //--- cmdcon44f-era (Ray 2026-07-03): defenses cost CASH again (live report: defenses charged SV). 1 = the b88 supply-pricing experiment (kept as a host toggle).
	//--- EXPERITAL: boosted starting economy (Steff, play-test 2026-06-10; baseline 800/1200;
	//--- doubled to 1600/2400, +10k/+5k on 06-10, +20k cash/+3k supply on 06-11 - restart compensation)
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_WEST") then {WFBE_C_ECONOMY_FUNDS_START_WEST = if (WF_Debug) then {900000} else {30000}};
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_EAST") then {WFBE_C_ECONOMY_FUNDS_START_EAST = if (WF_Debug) then {900000} else {30000}};
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_GUER") then {WFBE_C_ECONOMY_FUNDS_START_GUER = if (WF_Debug) then {900000} else {20000}};
	//--- B36 hotfix (Ray 2026-06-15): AI commander starts with a flat 200k cash (was FUNDS_START x FUNDS_MULT ~=45k); it runs the whole side. Players start with 30k.
	if (isNil "WFBE_C_AI_COMMANDER_START_FUNDS") then {WFBE_C_AI_COMMANDER_START_FUNDS = 200000}; //--- B67 (Ray 2026-06-21): RESTORED to 200000 (cash-rich directive). The earlier 60k trim was counterproductive - START_FUNDS cannot prepay un-unlocked tech (tech is interval-gated at 300s, money-independent), it only fuels UNIT FIELDING, which Ray now wants maximised. CASH only; never supply.
	if (isNil "WFBE_C_ECONOMY_INCOME_INTERVAL") then {WFBE_C_ECONOMY_INCOME_INTERVAL = 60}; //--- Income Interval (Delay between each paycheck).
	if (isNil "WFBE_C_INCOME_SLEEP_FPS_SCALE") then {WFBE_C_INCOME_SLEEP_FPS_SCALE = 1}; //--- Fleet lane 279: GetSleepFPS no longer shortens sleeps under low server FPS. 1 = raw configured interval; 2 = full load-shedding extension (5 fps -> 1.5x sleep), values between scale proportionally.
	if (isNil "WFBE_C_ECONOMY_INCOME_SYSTEM") then {WFBE_C_ECONOMY_INCOME_SYSTEM = 3}; //--- Income System (1:Full, 2:Half (Half -> 120 SV Town = 60$ / 60SV), 3: Commander System, 4: Commander System: Full)
	if (isNil "WFBE_C_ECONOMY_SUPPLY_START_WEST") then {WFBE_C_ECONOMY_SUPPLY_START_WEST = if (WF_Debug) then {900000} else {12800}};
	if (isNil "WFBE_C_ECONOMY_SUPPLY_START_EAST") then {WFBE_C_ECONOMY_SUPPLY_START_EAST = if (WF_Debug) then {900000} else {12800}};
	//--- PRODUCTION SUPPLY CAP LIVES IN THE MISSION PARAMETER, NOT IN THIS LINE. On a dedicated server, Init_Parameters.sqf
	//--- sets WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT from paramsArray (Rsc\Parameters.hpp class default = 50000) BEFORE this file runs,
	//--- so this isNil fallback is DEAD in MP - the 40000 only applies to non-MP/local (editor) runs. The supply clamp in
	//--- Server\Functions\Server_ChangeSideSupply.sqf reads THIS variable, so the real live ceiling = the param (default 50000).
	//--- That (not the same-numbered WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT below) is why B74 telemetry saw both sides pin at "50k".
	//--- TO RAISE THE LIVE CAP: edit Rsc\Parameters.hpp 'WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT' default/values[]; changing this 40000 does nothing in prod.
	if (isNil "WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT") then {WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT = if (WF_Debug) then {900000} else {40000}};
	if (isNil "WFBE_C_ECONOMY_SUPPLY_SYSTEM") then {WFBE_C_ECONOMY_SUPPLY_SYSTEM = 1}; //--- Supply System (0: Trucks, 1: Automatic with time).
	//--- fix(supplyfix, 2026-07-21): Common\Functions\Common_ChangeSideSupply.sqf relays every side-supply change via
	//--- publicVariableServer, which never fires the SENDING machine's own PVEH — so on a dedicated server every
	//--- server/AI-originated call (28 call sites: town income, AICOM research/base costs, supply-mission payouts, etc.)
	//--- is a silent no-op today. Client-originated calls are unaffected (client publish -> server PVEH fires normally).
	//--- Three states, default OFF: 0 = OFF — today's exact behavior, server-side no-op preserved, clients unchanged;
	//--- 1 = SHADOW — server diag_logs the would-be pre/post delta (SUPPLYFIX|v1|SHADOW|...) without applying it;
	//--- 2 = APPLY — server calls WFBE_SE_FNC_HandleSideSupplyChange directly with the full event envelope, the same
	//--- shape already proven at Server\PVFunctions\AttackWave.sqf:73. Rollout: shadow one round, then Chernarus first,
	//--- then Takistan, Zargabad last (its 5x town-income multiplier makes it the highest-risk map to arm).
	if (isNil "WFBE_C_SUPPLY_SERVER_FIX") then {WFBE_C_SUPPLY_SERVER_FIX = 2}; //--- g1606 2026-07-30: default APPLY (was 0 = silent no-op for every server/AI-originated ChangeSideSupply via publicVariableServer self-fire trap)
	WFBE_C_FIX_INCOME_SYSTEM4_DISPLAY = 0; //--- 1 makes Client_GetIncome mirror the server's income-system 4 x1.5 payout display.
	WFBE_C_ECONOMY_INCOME_COEF = if (worldName == "Zargabad") then {42} else {14}; //--- cmdcon44r (Ray 2026-07-04): ZG CASH x3 (14*3=42) - Ray: "cash stays at 3x". NOTE cash had never been multiplied on ZG (44p only tripled the SUPPLY stream), so this SETS the ZG cash stream to the x3 Ray specified; CH/TK unchanged at 14. Consumers: updateresources.sqf:16 + Common_GetTownsIncome.sqf:7 (both read this constant, both scale together). B67 (Ray 2026-06-21): 8->14. Boost town-driven CASH income ~1.75x (CASH path only: updateresources.sqf:60->95; the SUPPLY credit at :76 uses WFBE_C_ECONOMY_SUPPLY_INCOME_MULT and is UNCHANGED). Town Multiplicator Coefficient (SV * x).
	WFBE_C_ECONOMY_SUPPLY_INCOME_MULT = if (worldName == "Zargabad") then {5.0} else {1.0}; //--- cmdcon44r (Ray 2026-07-04): ZG supply x3 -> x5 ("push ZG to 5x, cash stays at 3x"; cash stream split off to x3 via INCOME_COEF on the line above). 44p note: TRIPLE supply income on Zargabad only - the 11-town map generates too little SV for its pacing (CH/TK have 30-40 towns feeding the same economy). Side-wide credit (updateresources.sqf:96): players, human+AI commanders and GUER all x3 on ZG. CH/TK stay 1.0. Original 2026-06-29 parity note: un-throttle ongoing town SUPPLY income to stock 1.0. The credit is SIDE-WIDE (updateresources.sqf:87; funds AI + human commanders + GUER equally - see L420), so 1.0 gives AI commanders the same full supply SV income a human commander's economy gets (there was never an AI-specific handicap - the throttle hit everyone). Supersedes the B57 progression-throttle (0.35->0.5): the funds->supply bridge that made throttling safe is gone, research + factory-rebuild are now SUPPLY-ONLY, and 0.35/0.5 was starving the AI (live no-affordable-upgrade RPT: needed 9500 supply with ~1650 banked). NOTE: founding/research/structure costs were tuned against 0.35 (see L593) -> economy now runs ~2-3x faster; review costs if the AI over-builds. Cash/funds + starting-supply seed UNCHANGED (Ray: cash=units, supply=buildings+upgrades).
	WFBE_C_ECONOMY_INCOME_DIVIDED = 1.2; //--- Prevent commander from being a millionaire, and add the rest to the players pool.
	WFBE_C_ECONOMY_INCOME_PERCENT_MAX = 30; //--- Commander may set income up to x%.
	WFBE_C_ECONOMY_SUPPLY_TIME_INCREASE_DELAY = 60; //--- Increase SV delay.
	if (isNil "WFBE_C_ENDGAME_HOLD") then {WFBE_C_ENDGAME_HOLD = 45};//--- seconds the round is held open after a winner is set, so the EndGame winner-cam orbit plays out before failMission cuts the client cam (Server\FSM\server_victory_threeway.sqf).
	//--- NOT THE SUPPLY CAP, despite the name. This never clamps banked side-supply (that is WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT, the
	//--- param above, enforced in Server_ChangeSideSupply.sqf). This 50000 is used ONLY as (a) an INCOME GATE in
	//--- Server\FSM\updateresources.sqf (compared vs GetTownsSupply town-income, lines 58 & 115) and (b) the reference ceiling in the
	//--- attack-wave discount formula in Server\Functions\Server_AttackWave.sqf:15 (which ALSO hardcodes 1/50000 - keep both in sync).
	//--- It is only coincidentally equal to the current prod cap (50000). Do NOT edit this to raise the supply ceiling - see line ~521.
	WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 50000;
	WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER = 20;
	//--- Supply-mission economy knobs (tunable in one place; shared by client reward + server payouts).
	WFBE_C_SUPPLY_HELI_REWARD_MULT      = 1.25;  //--- Pilot air-delivery bonus (+25%, money and score).
	WFBE_C_SUPPLY_CASHRUN_COMMANDER_CUT = 0.20;  //--- Commander tithe on cash runs (20% of pilot reward, minted on top).
	WFBE_C_SUPPLY_INTERDICTION_CUT      = 0.25;  //--- Enemy reward for downing a loaded supply vehicle (25% of cargo).
	WFBE_C_SUPPLY_HELI_LOAD_TIME        = 15; //--- Seconds to load a helicopter at a town (channeled; stay next to it).
	WFBE_C_SUPPLY_HELI_UNLOAD_TIME      = 15; //--- Seconds the helicopter must hover/sit at the Command Center to unload.
	//--- Supply-mission vehicle types. Trucks are always eligible; the supply helicopter unlocks with the Aircraft Factory upgrade.
	WFBE_C_SUPPLY_TRUCK_TYPES = ['WarfareSupplyTruck_RU','WarfareSupplyTruck_USMC','WarfareSupplyTruck_INS','WarfareSupplyTruck_Gue','WarfareSupplyTruck_CDF','UralSupply_TK_EP1','MtvrSupply_DES_EP1'];
	//--- One supply helicopter per side. Gains LOAD SUPPLIES at Air upgrade 3; deliveries become cash runs at Air 4.
	WFBE_C_SUPPLY_HELI_TYPES = if (IS_chernarus_map_dependent) then { ['MH60S','Mi17_Ins'] } else { ['UH60M_EP1','Mi17_TK_EP1'] };  //--- Chernarus: WEST USMC / EAST Mi-17. Else Takistan: WEST US / EAST TKA (verify generated buy lists).
	if (isNil "WFBE_C_SUPPLY_HELI_ENABLED") then {WFBE_C_SUPPLY_HELI_ENABLED = 1};
	if (WFBE_C_SUPPLY_HELI_ENABLED != 1) then {WFBE_C_SUPPLY_HELI_TYPES = [];}; //--- lobby toggle: shelve the heli feature without a repack.
	WFBE_C_SUPPLY_VEHICLE_TYPES = WFBE_C_SUPPLY_TRUCK_TYPES + WFBE_C_SUPPLY_HELI_TYPES;  //--- All supply-capable (used for buy-menu highlight).

//--- Anti-stack.
	// Marty: Default to enabled when older mission parameter sets do not define the AntiStack switch.
	if (isNil "WFBE_C_ANTISTACK_ENABLED") then {WFBE_C_ANTISTACK_ENABLED = 1};
	TEAM_SKILL_TICKS_WEST = 0;
	TEAM_SKILL_TICKS_EAST = 0;
	TEAM_SKILL_TICKS_DIFF_THRESHOLD = 30;
	TEAM_SKILL_TICKS_COMPENSATION_MULTIPLIER = 0.045;
	TEAM_SKILL_TICKS_END_THRESHOLD = 10;
	SUPPLY_COMPENSATION_AMOUNT_WEST = 0;
	SUPPLY_COMPENSATION_AMOUNT_EAST = 0;
	PLAYER_NUMBER_DIFFERENCE_MODIFIER = 0.15;
	WFBE_SUPPLY_MISSION_SCORE_COEF = 1.5;
	WFBE_UPGRADE_SCORE_COEF = 0.5;

//--- Supply income stagnation when no players.
	TEAM_WEST_TICKS_NO_PLAYERS = 0;
	TEAM_EAST_TICKS_NO_PLAYERS = 0;
	SUPPLY_INCOME_TICK_MODIFIER_MULTIPLIER = 0.10;

//--- Player marker flashing in combat.
	FIRING_UNIT_BLINK_TIME = 15;
	WFBE_C_PLAYERS_MARKER_BLINKS = 16; // Keep it even number, otherwise the icon turns permanently red after blinking.
	BLINKING_UNITS_WEST = [];
	BLINKING_UNITS_EAST = [];
	BLINKING_UNITS_GUER = [];
	BLINKING_VEHICLES_WEST = [];
	BLINKING_VEHICLES_EAST = [];
	BLINKING_VEHICLES_GUER = [];
//--- fable/marker-combat-flash (owner 2026-07-09): optional seconds-based override for the
//--- combat-icon-blink duration above. WFBE_C_PLAYERS_MARKER_BLINKS is a blink-COUNT; the
//--- Client_BookkeepBlinkingIcons.sqf loop ticks ~1/s, so 1 blink =~ 1 second. 0 = inert,
//--- keeps the existing WFBE_C_PLAYERS_MARKER_BLINKS behavior byte-identical (flag-off).
//--- >0 lets an admin dial the flash window in seconds without touching the existing
//--- count-based default. Read in Client_BlinkMapIcon.sqf. Never change
//--- WFBE_C_PLAYERS_MARKER_BLINKS's own default here (flag policy).
	if (isNil "WFBE_C_MARKER_COMBAT_FLASH_SECS") then {WFBE_C_MARKER_COMBAT_FLASH_SECS = 0};

//--- cmdcon43-b (Build 88): BIG-MAP FPS - marker RENDER-pass mitigation. The consolidated marker loop
//--- (Common\Common_MarkerLoop.sqf) gates identically on any map consumer, so the script load is the same
//--- whether the player has the full-screen map (M) or a menu minimap open. The difference is the ENGINE
//--- marker render pass: the big map draws every registered own-side unit marker + its TEXT label at wide
//--- zoom (150-400 at peak), a menu minimap draws a handful. These flags cut the render + churn cost.
//--- Each is INDEPENDENTLY toggleable and default-safe; both maps read the same constants (mirrored to TK).
	if (isNil "WFBE_C_MARKER_MOVE_INPLACE") then {WFBE_C_MARKER_MOVE_INPLACE = 1};      //--- 1: refresh nudges marker pos/dir/text in place (setMarker*Local) instead of delete+recreate on the rebuild path. 0: legacy delete+recreate. Cheapest win; no visible change.
	if (isNil "WFBE_C_MARKER_LABEL_CULL") then {WFBE_C_MARKER_LABEL_CULL = 1};          //--- 1: when registered unit markers exceed the threshold, blank the TEXT on bulk unit markers (keep HQ/own-team/named); restore under threshold. Text draw is the expensive part of the A2 marker pass. 0: never cull.
	if (isNil "WFBE_C_MARKER_LABEL_CULL_THRESHOLD") then {WFBE_C_MARKER_LABEL_CULL_THRESHOLD = 120}; //--- Registered-unit-marker count at/above which label culling engages (hysteresis-guarded in the loop).
	if (isNil "WFBE_C_MARKERANIM_SLEEP") then {WFBE_C_MARKERANIM_SLEEP = 0.1};          //--- Seconds between TempAnim MarkerAnim pulse updates. 0.1 = 10 Hz; clamped to old 0.03 floor in Client_MarkerAnim.sqf.
	//--- SHELVED (item 3, not shipped): wide-zoom per-group AGGREGATION would need the map control's zoom to
	//--- know when to collapse per-unit markers to one per group. The only zoom read is ctrlMapScale, which is
	//--- Arma-3-only (unavailable in A2-OA 1.64 - verified: used nowhere in this map-heavy mission), and the
	//--- brief forbids a zoom hack. No flag is registered (an inert never-read constant is just dead code); to
	//--- revive, first find/confirm an A2-OA zoom source, then add WFBE_C_MARKER_GROUP_AGG here + a read path.
	if (isNil "WFBE_C_MARKER_MAPPERF_DIAG") then {WFBE_C_MARKER_MAPPERF_DIAG = 1};      //--- 1: emit a throttled MAPPERF|v1 RPT line (<=1/30s while the big map is open) so a live soak can verify the fix. 0: silent.
	if (isNil "WFBE_C_MARKER_SLOT_DIGIT") then {WFBE_C_MARKER_SLOT_DIGIT = 0};           //--- 0: own-squad unit-marker number = engine creation-order id (legacy, byte-identical). >0: marker number = live command-bar slot (1-based index among alive group members in `units` order) so the map number matches the F-key bar after death/buy/rejoin. See Common_GetUnitSlotDigit.sqf.

//--- Grok idea #22 (client perf): ADAPTIVE marker budget. WFBE_C_MARKER_BUDGET_PER_TICK above is a
//--- fixed per-tick ceiling shared by every client regardless of their own performance. When armed,
//--- Common_MarkerLoop.sqf derives the EFFECTIVE per-tick budget from the LOCAL client's own diag_fps
//--- instead: a client already struggling culls the bulk marker pool harder, a healthy client keeps
//--- the full fixed budget - so one player's weak PC no longer forces the same thin budget onto
//--- everyone else's smooth client (client-local, no server change, no new network traffic).
	if (isNil "WFBE_C_MARKER_BUDGET_ADAPT") then {WFBE_C_MARKER_BUDGET_ADAPT = 1};       //--- 0: legacy fixed-budget behavior (byte-identical). 1: scale the per-tick budget by this client's own diag_fps (see the 3 constants below).
	if (isNil "WFBE_C_MARKER_BUDGET_ADAPT_FLOOR") then {WFBE_C_MARKER_BUDGET_ADAPT_FLOOR = 8}; //--- Lowest the adaptive budget is ever allowed to shrink to, however low fps gets. Never exceeds WFBE_C_MARKER_BUDGET_PER_TICK (clamped in the loop).
	if (isNil "WFBE_C_MARKER_BUDGET_ADAPT_FPS_FLOOR") then {WFBE_C_MARKER_BUDGET_ADAPT_FPS_FLOOR = 15}; //--- diag_fps at/below which the adaptive budget clamps to the floor above.
	if (isNil "WFBE_C_MARKER_BUDGET_ADAPT_FPS_CEIL") then {WFBE_C_MARKER_BUDGET_ADAPT_FPS_CEIL = 40}; //--- diag_fps at/above which the adaptive budget equals the full fixed WFBE_C_MARKER_BUDGET_PER_TICK (no thinning). Linear-scaled between floor and ceil.

// Attack wave.
	ATTACK_WAVE_PRICE_MODIFIER = 1;
	ATTACK_WAVE_ACTIVE_WEST = false;
	ATTACK_WAVE_ACTIVE_EAST = false;
	ATTACK_WAVE_ACTIVE_WEST_SET_TIME = -1;
	ATTACK_WAVE_ACTIVE_EAST_SET_TIME = -1;
	//--- fix(aicom) [#1373]: the ATTACK_WAVE_ACTIVE_WEST/EAST overlap guard (Server_AttackWave.sqf) is set
	//--- true before spawning the wave worker, but a worker that dies before reaching its own reset
	//--- (exception, JIP/save-load edge, mission end) would otherwise latch the side and permanently
	//--- suppress every future attack wave. This is the staleness ceiling the guard checks alongside the
	//--- ACTIVE flag - default-on (no separate toggle), same idiom as WFBE_C_MARKER_LABEL_CULL_THRESHOLD.
	//--- 30 min gives headroom above the longest legitimate wave (<=1500s/25min at 0% discount).
	if (isNil "WFBE_C_ATTACK_WAVE_STALE_MINUTES") then {WFBE_C_ATTACK_WAVE_STALE_MINUTES = 30};

// Unit cost modifier based on the related upgrade.

	UNIT_COST_MODIFIER = 1;

//--- Environment.
	if (isNil "WFBE_C_ENVIRONMENT_MAX_VIEW") then {WFBE_C_ENVIRONMENT_MAX_VIEW = 5000}; //--- Max view distance.
	//--- ZG-FIX (cmdcon44c, Ray 2026-07-03): dense-urban Zargabad tanks client fps at high view distance.
	//--- Hard-cap AFTER param ingestion so the lobby param cannot raise it back above 3km on this map.
	if (worldName == "Zargabad") then {WFBE_C_ENVIRONMENT_MAX_VIEW = WFBE_C_ENVIRONMENT_MAX_VIEW min 3000};
	if (isNil "WFBE_C_ENVIRONMENT_MAX_CLUTTER") then {WFBE_C_ENVIRONMENT_MAX_CLUTTER = 50}; //--- Max Terrain grid.
	if (isNil "WFBE_C_ENVIRONMENT_STARTING_HOUR") then {WFBE_C_ENVIRONMENT_STARTING_HOUR = 8}; //--- Starting Hour of the day. (Ray 2026-06-24: permanent-daylight band starts 08:00; see WFBE_C_ENVIRONMENT_DAYLIGHT_* below.)
	// Ray 2026-06-24 (directive #2): permanent daylight runs 08:00->17:00 then loops back to 08:00, never night. Server clamps daytime to this band when the accelerated cycle is OFF (WFBE_DAYNIGHT_ENABLED != 1, which is the live hard-set state at line 100). Toggle WFBE_C_ENVIRONMENT_DAYLIGHT_CLAMP=0 to disable (reverts to the old one-shot setDate behaviour).
	if (isNil "WFBE_C_ENVIRONMENT_DAYLIGHT_CLAMP") then {WFBE_C_ENVIRONMENT_DAYLIGHT_CLAMP = 1};   //--- 1 = enforce the 08:00->17:00 daylight loop on the disabled-cycle path.
	if (isNil "WFBE_C_ENVIRONMENT_DAYLIGHT_START") then {WFBE_C_ENVIRONMENT_DAYLIGHT_START = 8};    //--- Reset hour when the clock passes the end of the daylight band.
	if (isNil "WFBE_C_ENVIRONMENT_DAYLIGHT_END") then {WFBE_C_ENVIRONMENT_DAYLIGHT_END = 17};       //--- Loop back to START once daytime reaches/exceeds this hour (17:00).
	if (isNil "WFBE_C_ENVIRONMENT_DAYLIGHT_CHECK") then {WFBE_C_ENVIRONMENT_DAYLIGHT_CHECK = 30};    //--- Seconds between daylight-band checks (cheap; light cadence).
	if (isNil "WFBE_C_ENVIRONMENT_STARTING_MONTH") then {WFBE_C_ENVIRONMENT_STARTING_MONTH = 6}; //--- Starting Month of the year.
	if (isNil "WFBE_C_ENVIRONMENT_WEATHER") then {WFBE_C_ENVIRONMENT_WEATHER = 0}; //--- Weather Type, 0: Clear, 1: Cloudy, 2: Rainy)
	// Marty: Volumetric clouds are disabled globally; override any stale parameter value.
	WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC = 0; //--- Disable volumetric clouds.
	WFBE_C_ENVIRONMENT_WEATHER_TRANSITION = 600; //--- Weather Transition period, change weather overcast each x seconds (longer is more realistic).

//--- Gameplay.
	if (isNil "WFBE_C_GAMEPLAY_AIR_AA_MISSILES") then {WFBE_C_GAMEPLAY_AIR_AA_MISSILES = 1}; //--- Enable Air vehicles Air-to-Air missiles (0: Disabled, 1: Enabled with Upgrade, 2: Enabled).
	if (isNil "WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED") then {WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED = 1}; //--- Enable the map boundaries if defined.
	if (isNil "WFBE_C_GAMEPLAY_FAST_TRAVEL") then {WFBE_C_GAMEPLAY_FAST_TRAVEL = 1}; //--- Fast Travel (0 Disabled, 1 Free, 2 Fee).
	if (isNil "WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE") then {WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE = 1}; //--- Handle the friendly fire.
	if (isNil "WFBE_C_GAMEPLAY_HANGARS_ENABLED") then {WFBE_C_GAMEPLAY_HANGARS_ENABLED = 1}; //--- Enable or disable hangars.
	if (isNil "WFBE_C_GAMEPLAY_MISSILES_RANGE") then {WFBE_C_GAMEPLAY_MISSILES_RANGE = 0}; //--- Incoming Guided missiles Range limit (0 = Disabled).
	if (isNil "WFBE_C_GAMEPLAY_TEAMSWAP_DISABLE") then {WFBE_C_GAMEPLAY_TEAMSWAP_DISABLE = 1}; //--- Disable teamswitch.
	if (isNil "WFBE_C_GAMEPLAY_THERMAL_IMAGING") then {WFBE_C_GAMEPLAY_THERMAL_IMAGING = 3}; //--- Thermal Imaging (0: Disabled, 1: Weapons, 2: Vehicles, 3: All).
	if (isNil "WFBE_C_GAMEPLAY_UID_SHOW") then {WFBE_C_GAMEPLAY_UID_SHOW = 1}; //--- Display the user ID (on teamswap/tk).
	if (isNil "WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE") then {WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE = 0}; //--- Upgrade clearance (on start), 0: Disabled, 1: West, 2: East, 3: Res, 4: West + East, 5: West + Res, 6: East + Res, 7: All.
	if (isNil "WFBE_C_GAMEPLAY_VICTORY_CONDITION") then {WFBE_C_GAMEPLAY_VICTORY_CONDITION = 2}; //--- Victory Condition (0: Annihilation, 1: Assassination, 2: Supremacy, 3: Towns).
	WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE = 175;
	WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE_MAX = 3500;
	WFBE_C_GAMEPLAY_FAST_TRAVEL_PRICE_KM = 215;
	WFBE_C_GAMEPLAY_FAST_TRAVEL_TIME_COEF = 0.8;
	WFBE_C_GAMEPLAY_FAST_TRAVEL_FEE = 5000;     //--- Ray 2026-06-28: flat base fee to USE fast travel (fee mode 2), added on top of the per-km price.
	WFBE_C_GAMEPLAY_FAST_TRAVEL_VEH_FEE = 2500; //--- Ray 2026-06-28: extra fee per DISTINCT VEHICLE taken along.
	if (isNil "WFBE_C_GAMEPLAY_FAST_TRAVEL_RECHECK") then {WFBE_C_GAMEPLAY_FAST_TRAVEL_RECHECK = 1}; //--- lane197: recheck destination eligibility at fire time (integrity fix). Default 1 (active).
	WFBE_C_GAMEPLAY_VOTE_TIME = if (WF_Debug) then {3} else {40};
	if (isNil "WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC") then {WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC = 0}; //--- Default-off: publish stealth-engine stopped state across locality changes; 0 keeps legacy local vehicle state.
	if (isNil "WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL") then {WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL = 0}; //--- Default-off: show the already-recorded GUER endgame stats as a third stats-panel column.
	if (isNil "WFBE_C_FIX_VOTE_LIST_PRUNE") then {WFBE_C_FIX_VOTE_LIST_PRUNE = 0}; //--- Default-off: safer vote-dialog live-team row prune (reverse pass + stale index guard). 0 = legacy forward delete behaviour.
	if (isNil "WFBE_C_FIX_VOTE_QA_EXECUTION") then {WFBE_C_FIX_VOTE_QA_EXECUTION = 0}; //--- Default-off: vote QA follow-up fixes for stored-index row color and commander primitive placeholder confirms.
	if (isNil "WFBE_C_FIX_TEAMSWITCH_CROSSGROUP_AIFREEZE") then {WFBE_C_FIX_TEAMSWITCH_CROSSGROUP_AIFREEZE = 0}; //--- Default-off: preventive infra - doFollow-pulse guard in Common_SelectPlayerCrossGroup.sqf for a future genuine cross-group selectPlayer handoff. 0 = plain selectPlayer, byte-identical.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH") then {WFBE_C_AMBIENT_SKIRMISH = 0}; //--- Ray 2026-07-06: back to default-OFF (live test done; the GUER Director program + air-contact AA tier now own ambient life). Lane 180: ambient WEST/EAST skirmish cells; server-only, one active cell cap, no AICOM/town/supply budget integration.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_INTERVAL") then {WFBE_C_AMBIENT_SKIRMISH_INTERVAL = 600}; //--- Seconds between spawn attempts while enabled.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_LIFETIME") then {WFBE_C_AMBIENT_SKIRMISH_LIFETIME = 120}; //--- Seconds before the ambient cell self-cleans.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_PLAYER_RADIUS") then {WFBE_C_AMBIENT_SKIRMISH_PLAYER_RADIUS = 1500}; //--- Never spawn inside this distance of a human player.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_TOWN_RADIUS") then {WFBE_C_AMBIENT_SKIRMISH_TOWN_RADIUS = 1500}; //--- Never spawn inside this distance of a town logic.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_GROUP_MIN") then {WFBE_C_AMBIENT_SKIRMISH_GROUP_MIN = 2}; //--- Units per side, minimum.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_GROUP_MAX") then {WFBE_C_AMBIENT_SKIRMISH_GROUP_MAX = 3}; //--- Units per side, maximum.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_SPAWN_TRIES") then {WFBE_C_AMBIENT_SKIRMISH_SPAWN_TRIES = 24}; //--- Candidate positions checked per attempt.
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_CENTER") then {WFBE_C_AMBIENT_SKIRMISH_CENTER = if (worldName == "Takistan") then {[6400,6400,0]} else {if (worldName == "Zargabad") then {[4000,4000,0]} else {[7680,7680,0]}}};
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_RADIUS") then {WFBE_C_AMBIENT_SKIRMISH_RADIUS = if (worldName == "Takistan") then {5600} else {if (worldName == "Zargabad") then {3000} else {6200}}};
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_WEST_CLASSES") then {WFBE_C_AMBIENT_SKIRMISH_WEST_CLASSES = if (IS_chernarus_map_dependent) then {["USMC_Soldier","USMC_Soldier_LAT","USMC_Soldier_AR"]} else {["US_Soldier_EP1","US_Soldier_LAT_EP1","US_Soldier_AR_EP1"]}};
	if (isNil "WFBE_C_AMBIENT_SKIRMISH_EAST_CLASSES") then {WFBE_C_AMBIENT_SKIRMISH_EAST_CLASSES = if (IS_chernarus_map_dependent) then {["RU_Soldier","RU_Soldier_LAT","RU_Soldier_AR"]} else {["TK_Soldier_EP1","TK_Soldier_LAT_EP1","TK_Soldier_AR_EP1"]}};

//--- Modules.
	if (isNil "WFBE_C_MODULE_BIS_PMC") then {WFBE_C_MODULE_BIS_PMC = 1}; //--- Enable PMC content.
	if (isNil "WFBE_C_MODULE_WFBE_EASA") then {WFBE_C_MODULE_WFBE_EASA = 1}; //--- Enable the Exchangeable Armament System for Aircraft.
		if (isNil "WFBE_C_TK_EASA_ROSTER") then {WFBE_C_TK_EASA_ROSTER = 1}; //--- cmdcon42-i: Takistan-only "EASA loadout" air variant roster (synthetic buy tokens = base hull + a proven EASA weapon kit, tiered per air-research level per side; top tiers airfield-exclusive at Rasman/Loy Manara). 0 = hide the whole roster (Chernarus always hides it regardless). Catalog: Common\Functions\Common_TKEasaRoster.sqf.
	if (isNil "WFBE_C_MODULE_WFBE_FLARES") then {WFBE_C_MODULE_WFBE_FLARES = 1}; //--- Enable the countermeasure system (0: Disabled, 1: Enabled with upgrade, 2: Enabled).
	if (isNil "WFBE_C_MODULE_AUTO_CM_OA") then {WFBE_C_MODULE_AUTO_CM_OA = 1}; //--- cmdcon41-w3f: 0 -> 1. Auto-deploy countermeasures on OA aircraft (native OA flares are manual). Requires WFBE_C_MODULE_WFBE_FLARES > 0, which is ON (SQF default 1 / param default 2), so the dependency is met; enabling this helps AI aircraft survive IR missiles (pairs with EASA-on-AI kits). Param default in Rsc\Parameters.hpp flipped to 1 to match (dedicated reads the param).
	if (isNil "WFBE_C_MODULE_WFBE_ICBM") then {WFBE_C_MODULE_WFBE_ICBM = 1}; //--- Enable the Intercontinental Ballistic Missile call for the commander.
	if (isNil "WFBE_C_FIX_IRSMOKE_PARAM_ALIAS") then {WFBE_C_FIX_IRSMOKE_PARAM_ALIAS = 0}; //--- Lane 27: default-off alias for the lobby WFBE_C_MODULE_WFBE_IRS name to the runtime WFBE_C_MODULE_WFBE_IRSMOKE name.
	if (isNil "WFBE_C_MODULE_WFBE_IRSMOKE") then {WFBE_C_MODULE_WFBE_IRSMOKE = 1}; //--- Enable the use of IR Smoke.
	if ((missionNamespace getVariable ["WFBE_C_FIX_IRSMOKE_PARAM_ALIAS", 0]) > 0) then {
		if !(isNil "WFBE_C_MODULE_WFBE_IRS") then {WFBE_C_MODULE_WFBE_IRSMOKE = WFBE_C_MODULE_WFBE_IRS};
	};
	if (isNil "WFBE_ICBM_TIME_TO_IMPACT") then {WFBE_ICBM_TIME_TO_IMPACT = 1}; //--- Time for ICBM to impact 
	if (isNil "WFBE_RADZONE_TIME") then {WFBE_RADZONE_TIME = 1}; //--- Time for radiation effect 

//--- Players.
	if (isNil "WFBE_C_PLAYERS_AI_MAX") then {WFBE_C_PLAYERS_AI_MAX = 16}; //--- Max AI allowed on each player groups.
	WFBE_C_PLAYERS_COMMANDER_BOUNTY_CAPTURE_COEF = 60;
	WFBE_C_PLAYERS_COMMANDER_SCORE_BUILD_COEF = 1;
	WFBE_C_PLAYERS_COMMANDER_SCORE_CAPTURE = 5;
	WFBE_C_PLAYERS_COMMANDER_SCORE_UPGRADE = 2;
	WFBE_C_PLAYERS_GEAR_SELL_COEF = 0.6; //--- Sell price of the gear: item price * x (800 * 0.2 = 400)
	WFBE_C_PLAYERS_GEAR_VEHICLE_RANGE = 50; //--- Possible to buy gear in vehicle if that one is within that range.
	WFBE_C_PLAYERS_HALO_HEIGHT = 200; //--- Distance above which units are able to perform an HALO jump.
	WFBE_C_PLAYERS_MARKER_DEAD_DELAY = 60; //--- Time that a marker remain on a dead unit.
	WFBE_C_PLAYERS_MARKER_TOWN_RANGE = 0.05; //--- A town marker is updated (SV) on map if a unit is within the range (town range * coef).
	WFBE_C_PLAYERS_OFFMAP_TIMEOUT = 50; //--- Player may remain x second outside of the map before being killed.
	WFBE_C_PLAYERS_PENALTY_TEAMKILL = 1000; //--- Teamkill penalty.
	WFBE_C_PLAYERS_SCORE_CAPTURE = 23;
	WFBE_C_PLAYERS_SCORE_CAPTURE_ASSIST = 17;
	WFBE_C_PLAYERS_SCORE_CAPTURE_CAMP = 5;
	WFBE_C_PLAYERS_SCORE_DELIVERY = 3;
	WFBE_C_PLAYERS_SKILL_SOLDIER_UNITS_MAX = 6; //--- Skill (Soldiers), have more units than the others.
	WFBE_C_PLAYERS_SQUADS_MAX_PLAYERS = 4; //--- One player squad may contain up to x players.
	WFBE_C_PLAYERS_SQUADS_REQUEST_TIMEOUT = 100; //--- Time delay after which an unanswered request "fades".
	WFBE_C_PLAYERS_SQUADS_REQUEST_DELAY = 120; //--- Time delay between each potential squad hops.
	WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_RANGE = 30; //--- Supply Trucks (Clients) delivery range.
	WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF = 4; //--- Funds awarded to a client for a delivery (SV * coef).
	WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY = 1200; //--- Paratroopers Call Interval.
	WFBE_C_PLAYERS_UAV_SPOTTING_DELAY = 20; //--- Interval between each uav spotting routine.
	WFBE_C_PLAYERS_UAV_SPOTTING_DETECTION = 0.21; //--- UAV will reveal each targets that it knows about this value (0-4)
	WFBE_C_PLAYERS_UAV_SPOTTING_RANGE = 1100; //--- Max Range of the UAV spotting.
	if (isNil "WFBE_C_PLAYERS_UAV_COST") then {WFBE_C_PLAYERS_UAV_COST = 12500}; //--- Server-authoritative UAV support charge.
	if (isNil "WFBE_C_PLAYERS_UAV_COOLDOWN") then {WFBE_C_PLAYERS_UAV_COOLDOWN = 1800}; //--- Per-team seconds between authorised UAV hulls.

//--- Respawn.
	if (isNil "WFBE_C_RESPAWN_CAMPS_MODE") then {WFBE_C_RESPAWN_CAMPS_MODE = 2}; //--- Respawn Camps (0: Disabled, 1: Classic [from town center], 2: Enhanced [from nearby camps]).
	if (isNil "WFBE_C_RESPAWN_CAMPS_RANGE") then {WFBE_C_RESPAWN_CAMPS_RANGE = 550}; //--- How far a player need to be from a town to spawn at camps.
	if (isNil "WFBE_C_RESPAWN_CAMPS_RULE_MODE") then {WFBE_C_RESPAWN_CAMPS_RULE_MODE = 2}; //--- Respawn Camps Rule (0: Disabled, 1: West | East, 2: West | East | Resistance).
	if (isNil "WFBE_C_RESPAWN_DELAY") then {WFBE_C_RESPAWN_DELAY = 10}; //--- Respawn Delay (Players/AI).
	if (isNil "WFBE_C_RESPAWN_LEADER") then {WFBE_C_RESPAWN_LEADER = 2}; //--- Allow leader respawn (0: Disabled, 1: Enabled, 2: Enabled but default gear).
	if (isNil "WFBE_C_RESPAWN_MOBILE") then {WFBE_C_RESPAWN_MOBILE = 2}; //--- Allow mobile respawn (0: Disabled, 1: Enabled, 2: Enabled but default gear).
	if (isNil "WFBE_C_RESPAWN_PENALTY") then {WFBE_C_RESPAWN_PENALTY = 4}; //--- Respawn Penalty (0: None, 1: Remove All, 2: Pay full gear price, 3: Pay 1/2 gear price, 4: pay 1/4 gear price, 5: Charge on Mobile).
	if (isNil "WFBE_C_CAMP_RESPAWN_KEEP_GEAR") then {WFBE_C_CAMP_RESPAWN_KEEP_GEAR = 1}; //--- Camp respawn gear penalty exemption (1: camp spawns are free, custom gear restored without charge; 0: camps treated as any other forward spawn and subject to normal penalty). Default 1 matches pre-b89 behaviour where camp charge was unintentional.
	WFBE_C_RESPAWN_CAMPS_SAFE_RADIUS = 50;
	WFBE_C_RESPAWN_RANGE_LEADER = 50;
	WFBE_C_RESPAWN_RANGES = [250, 350, 500];

//--- Structures.
	if (isNil "WFBE_C_STRUCTURES_ANTIAIRRADAR") then {WFBE_C_STRUCTURES_ANTIAIRRADAR = 1};
	if (isNil "WFBE_C_STRUCTURES_COLLIDING") then {WFBE_C_STRUCTURES_COLLIDING = 1};
	if (isNil "WFBE_C_STRUCTURES_CONSTRUCTION_MODE") then {WFBE_C_STRUCTURES_CONSTRUCTION_MODE = 0}; //--- Structures construction mode (0: Time).
	if (isNil "WFBE_C_STRUCTURES_HQ_COST_DEPLOY") then {WFBE_C_STRUCTURES_HQ_COST_DEPLOY = 500}; //--- HQ Deploy / Mobilize Price. (Ray 2026-06-28: fallback 100->500 to match lobby default 500; old 100 only bit local/listen.)
	if (isNil "WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED") then {WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED = 200}; //--- HQ Deploy / Mobilize Price.
	if (isNil "WFBE_C_STRUCTURES_MAX") then {WFBE_C_STRUCTURES_MAX = 3};
	WFBE_C_STRUCTURES_ANTIAIRRADAR_DETECTION = 100; //--- Scalar fallback minimum detection height (m). Kept nil-safe; superseded per-tier by the array below.
	//--- Trello card #65: minimum AAR detection height now depends on the AAR upgrade level. Tier-indexed by AAR level (0/1/2): a higher-tier radar sees lower-flying aircraft. Falls back to the scalar above if nil/short.
	WFBE_C_STRUCTURES_ANTIAIRRADAR_DETECTION_TIERS = [100,60,30];
	//--- Trello card #66: minimum AAR upgrade level at which a one-shot "new contact" warning (titleText + sound) fires for each newly-acquired enemy aircraft.
	WFBE_C_AAR_WARN_LEVEL = 1;
	WFBE_C_STRUCTURES_BUILDING_DEGRADATION = 1; //--- Degredation of the building in time during a repair phase (over 100).
	WFBE_C_STRUCTURES_COMMANDCENTER_RANGE = 5500; //--- Command Center Range.
	WFBE_C_STRUCTURES_DAMAGES_REDUCTION = 6; //--- Building Damage Reduction (Current damage given / x, 1 = normal).
	WFBE_C_STRUCTURES_RUINS = if (WF_A2_Vanilla) then {"Land_budova4_ruins"} else {"Land_Mil_Barracks_i_ruins_EP1"}; //--- Ruins model.
	WFBE_C_STRUCTURES_SALE_DELAY = 50; //--- Building is sold after x seconds.
	WFBE_C_STRUCTURES_SALE_PERCENT = 50; //--- When a structure is sold, x% of supply goes back to the side.
	WFBE_C_STRUCTURES_SERVICE_POINT_RANGE = 50;
	if (isNil "WFBE_C_COIN_POLL_SLEEP") then {WFBE_C_COIN_POLL_SLEEP = 0.1}; //--- Seconds between CoIn menu affordability/commanding-menu polls. 0.1 keeps the UI responsive while cutting wake-ups 10x from the legacy 0.01.

//--- Towns.
	if (isNil "WFBE_C_TOWNS_AMOUNT") then {WFBE_C_TOWNS_AMOUNT = 4}; //--- Amount of towns (0: Very small, 1: Small, 2: Medium, 3: Large, 4: Full).
	if (isNil "WFBE_C_TOWNS_BUILD_PROTECTION_RANGE") then {WFBE_C_TOWNS_BUILD_PROTECTION_RANGE = 450}; //--- Prevent construction in towns within that radius.
	if (isNil "WFBE_C_TOWNS_CAPTURE_MODE") then {WFBE_C_TOWNS_CAPTURE_MODE = 2}; //--- All-Camps capture mode: attackers must hold every camp with dismounted infantry before the town flips. (0: Normal/Classic, 1: Threshold, 2: All Camps).
	if (isNil "WFBE_C_TOWNS_DEFENDER") then {WFBE_C_TOWNS_DEFENDER = 2}; //--- Town defender Difficulty (0: Disabled, 1: Light, 2: Medium, 3: Hard, 4: Insane).
	if (isNil "WFBE_C_TOWNS_OCCUPATION") then {WFBE_C_TOWNS_OCCUPATION = 2}; //--- Town occupation Difficulty (0: Disabled, 1: Light, 2: Medium, 3: Hard, 4: Insane).
	if (isNil "WFBE_C_TOWNS_GEAR") then {WFBE_C_TOWNS_GEAR = 1}; //--- Buy Gear From (0: None, 1: Camps, 2: Depot, 3: Camps & Depot).
	if (isNil "WFBE_C_TOWNS_PATROLS") then {WFBE_C_TOWNS_PATROLS = 6}; //--- Town-to-town patrols ON by default (up to 6 towns); set 0 in the lobby to disable. DR-57 fix makes them work.
	if (isNil "WFBE_C_TOWNS_PATROL_CONTESTED_ONLY") then {WFBE_C_TOWNS_PATROL_CONTESTED_ONLY = 0}; //--- Lane 190: 0 keeps legacy supply-drop defense flips; 1 only pulls town patrols into defense while the town is stamped contested.
	if (isNil "WFBE_C_TOWNS_PATROL_ALERT_HOLD") then {WFBE_C_TOWNS_PATROL_ALERT_HOLD = 180}; //--- r35 alert-state: seconds of defense hold after a supply-drop escalate before decay back to patrol (min 30). Replaces permanent SV-below-start latch.
	if (isNil "WFBE_C_WAYPOINT_WATER_RETRY_CAP") then {WFBE_C_WAYPOINT_WATER_RETRY_CAP = 20}; //--- Max random waypoint water rerolls before falling back to the patrol center. Default 20 (was 0 = uncapped) so coastal patrols cannot hang a scheduled thread forever when every redraw lands on water (sqf-randomness bughunt 2026-07-30).
	if (isNil "WFBE_C_TOWNS_STARTING_MODE") then {WFBE_C_TOWNS_STARTING_MODE = 0}; //--- Town starting mode (0: Resistance, 1: 50% blu, 50% red, 2: Nearby Towns, 3: Random).
	if (isNil "WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER") then {WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER = 1}; //--- Lock the vehicles of the defender side.
	if (isNil "WFBE_C_TOWNS_CAPTURE_BAR_DETAIL") then {WFBE_C_TOWNS_CAPTURE_BAR_DETAIL = 0}; //--- Lane 52: 1 adds SV trend, mode-2 Camps X/Y, and camp SV text to the client capture bar; 0 keeps the legacy label.
	if (isNil "WFBE_C_TOWN_FLIP_BROADCAST") then {WFBE_C_TOWN_FLIP_BROADCAST = 0}; //--- DISARMED on owner order 2026-08-08 (supersedes the 2026-07-21 blanket everything-on ruling): owner reported enemy captures leaking to uninvolved sides as side-sensitive intel (West has captured X shown to an EAST player). 0 restores the TownCaptured.sqf side filter: title/chat only when the client side is the old or new owner (GUER always informed - the insurgency knows its towns). Marker recolor for the OWNING side is applied regardless of this flag.

	//--- Air units.
	if (isNil "WFBE_C_JET_AA_SURVIVE") then {WFBE_C_JET_AA_SURVIVE = 1}; //--- Jets survive the 1st SPAAG (Tunguska/Linebacker) hit: fuel drained + slight damage for a landing attempt; a 2nd hit explodes. 0 disables.
	WFBE_C_TOWNS_CAPTURE_ASSIST = 400;
	WFBE_C_TOWNS_CAPTURE_RANGE = 40;
	WFBE_C_TOWNS_CAPTURE_RATE = 0.4;
	WFBE_C_TOWNS_CAPTURE_THRESHOLD_RANGE = 140;
	WFBE_C_TOWNS_DEFENSE_RANGE = 30;
	WFBE_C_TOWNS_AI_SCAN_RANGE_OVERRIDE = 0; //--- Fleet lane 106: 0 keeps the legacy 600m activation scan base range.
	WFBE_C_TOWNS_AI_SCAN_BASE_RANGE = 600; //--- Used only when WFBE_C_TOWNS_AI_SCAN_RANGE_OVERRIDE > 0.
	WFBE_C_TOWNS_DETECTION_RANGE_ACTIVE_COEF = 1.25; //--- HYSTERESIS: presence range once active (must be > idle COEF; was 1=no band)
	WFBE_C_TOWNS_DETECTION_RANGE_COEF = 1; //--- Town activation range while idling (town range * coef)
	WFBE_C_TOWNS_DETECTION_RANGE_AIR = 50; //--- Detect Air if > x
	if (isNil "WFBE_C_TOWN_SCAN_DICE") then {WFBE_C_TOWN_SCAN_DICE = 1}; //--- Perf (2026-07-06): when 1, DORMANT towns (not active, no air tier, no enemy seen within DICE_GRACE) roll per side per sweep whether to run the 600 m activation nearEntities scan. Active towns always scan. Default off = V1 behaviour.
	if (isNil "WFBE_C_TOWN_SCAN_DICE_P") then {WFBE_C_TOWN_SCAN_DICE_P = 0.3}; //--- Probability a dormant town DOES scan on a given sweep (per side). [Ray-dir 2026-07-24 FPS: 0.5->0.3 - dormant towns scan the 600m activation nearEntities less often (profiler: town_activation_scan avg 8.9ms, spikes 1.4s); active towns + DICE_GRACE unaffected; rollback 0.5.]
	if (isNil "WFBE_C_TOWN_SCAN_DICE_GRACE") then {WFBE_C_TOWN_SCAN_DICE_GRACE = 30}; //--- s after the last enemy seen before a town counts as dormant for the dice.
	if (isNil "WFBE_C_TOWN_CAPTURE_STAGGER_N") then {WFBE_C_TOWN_CAPTURE_STAGGER_N = 1}; //--- 1 = current behavior; N = each town scanned every Nth pass, rate-compensated.
	//--- deadcode-sweep 2026-07-21 (DC-06): removed orphaned town mortar/patrol tuning
	//--- constants (WFBE_C_TOWNS_MORTARS_SCAN/_INTERVAL/_PRECOGNITION/_RANGE_MAX/_RANGE_MIN/
	//--- _SPLASH_RANGE, WFBE_C_TOWNS_PATROL_HOPS) - zero reads repo-wide; live patrol/artillery
	//--- paths are server_side_patrols.sqf and AI_Patrol.sqf.
	WFBE_C_TOWNS_PATROL_RANGE = 500;
	WFBE_C_TOWNS_PURCHASE_RANGE = 60;
	WFBE_C_TOWNS_SUPPLY_LEVELS_TIME = [1, 2, 3, 4, 5];
	WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK = [5, 6, 7, 8, 10];
	WFBE_C_TOWNS_UNITS_INACTIVE = 90; //--- Remove units in town if no enemies are to be found within that time.
		WFBE_C_TOWNS_UNITS_WAYPOINTS = 9;

//--- Units.
	if (isNil "WFBE_C_UNITS_BALANCING") then {WFBE_C_UNITS_BALANCING = 1}; //--- Enable Units weaponry balancing.
	if (isNil "WFBE_C_UNITS_BOUNTY") then {WFBE_C_UNITS_BOUNTY = 1}; //--- Enable Units bounty on kill.
	if (isNil "WFBE_C_FIRSTBLOOD_ENABLED") then {WFBE_C_FIRSTBLOOD_ENABLED = 1}; //--- First-blood (claude-gaming 2026-07-07): 1 = the first PVP kill of the match fires a one-time sting + announcement + killer bonus. Default 0 = off (inert).
	if (isNil "WFBE_C_FIRSTBLOOD_BONUS") then {WFBE_C_FIRSTBLOOD_BONUS = 1000}; //--- First-blood: cash bonus credited to the killer team wallet on first blood (only paid when WFBE_C_FIRSTBLOOD_ENABLED>0).
	if (isNil "WFBE_FIRSTBLOOD_DONE") then {WFBE_FIRSTBLOOD_DONE = false}; //--- First-blood one-shot latch (runtime state, not a tunable); false each fresh mission instance.
	if (isNil "WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW") then {WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW = 60}; //--- Seconds where a damaged vehicle can still award its last valid hitter.
	if (isNil "WFBE_C_UNITS_CLEAN_TIMEOUT") then {WFBE_C_UNITS_CLEAN_TIMEOUT = 60}; //--- Lifespan of a dead body.
	if (isNil "WFBE_C_ARTY_WRECK_REAP_DELAY") then {WFBE_C_ARTY_WRECK_REAP_DELAY = 300}; //--- fix/aicom-arty-lifecycle (2026-07-21, codex round-4: FLOOR not the delay itself - a fixed delay alone would race a lobby-raised WFBE_C_UNITS_CLEAN_TIMEOUT): server_groupsGC.sqf's dedicated dead-commander-artillery reaper computes its actual age-gate as (WFBE_C_UNITS_CLEAN_TIMEOUT + 180) max WFBE_C_ARTY_WRECK_REAP_DELAY, so this constant only matters (as a minimum) when CLEAN_TIMEOUT is configured very low; at the 120s lobby default the +180 term already dominates.
	if (isNil "WFBE_C_HELI_WRECK_REAP_DELAY") then {WFBE_C_HELI_WRECK_REAP_DELAY = 300}; //--- fix/heli-husk-reaper: same FLOOR-not-delay contract as WFBE_C_ARTY_WRECK_REAP_DELAY above, for server_groupsGC.sqf's dead-commander-attack-heli reaper: actual age-gate is (WFBE_C_UNITS_CLEAN_TIMEOUT + 180) max WFBE_C_HELI_WRECK_REAP_DELAY.
	if (isNil "WFBE_C_UNITS_EMPTY_TIMEOUT") then {WFBE_C_UNITS_EMPTY_TIMEOUT = 1800}; //--- Lifespan of an empty vehicle (30 minutes).
		WFBE_C_UNITS_BODIES_TIMEOUT = 60;
	//--- qol-polish-pack tunables --------------------------------------------------------------------------------
	if (isNil "WFBE_C_UNITS_BODIES_PROX")      then {WFBE_C_UNITS_BODIES_PROX = 20};       //--- m: hold a corpse's deletion while a player is this close (capped at +1 timeout so a camper can't pin it forever). 0 = off (vanilla).
	if (isNil "WFBE_C_STRUCTURES_FLAT_CHECK")  then {WFBE_C_STRUCTURES_FLAT_CHECK = 0};    //--- cmdcon34: DISABLED (0). The player flat-gate over-blocked base placement on mountainous Takistan (structures red -> HQ red -> factories only <10m from HQ). Reverts to pre-Build-81 freedom; the server places structures fine on any ground. Re-enable with a Takistan-tuned gradient later if wanted.
	if (isNil "WFBE_C_STRUCTURES_FLAT_RADIUS") then {WFBE_C_STRUCTURES_FLAT_RADIUS = 10};  //--- isFlatEmpty footprint radius (m).
	if (isNil "WFBE_C_STRUCTURES_FLAT_GRAD")   then {WFBE_C_STRUCTURES_FLAT_GRAD = 2};     //--- isFlatEmpty max gradient (lower = stricter; matches the AI commander's lenient value). cmdcon32: 0.5 -> 2 (0.5 over-blocked player placement on mountainous Takistan - everything red).
	if (isNil "WFBE_C_STRUCTURES_TREE_CLEAR")  then {WFBE_C_STRUCTURES_TREE_CLEAR = 0};    //--- fable/player-build-placement-gate: m radius that must be clear of Tree/SmallTree objects for base structures (parity with the AI commander's WFBE_C_AICOM_BUILD_TREE_CLEAR gate, PR #733 TP-19; uses nearestObjects not nearestTerrainObjects - the latter is A3-only). 0 = OFF (no tree gate); flag-off leaves the CoIn placement preview byte-identical to HEAD.
	if (isNil "WFBE_C_AIHELI_TERRAIN_GUARD")   then {WFBE_C_AIHELI_TERRAIN_GUARD = 1};     //--- AI-heli terrain look-ahead climb (server-local helis). 1 = ON by default (changes AI flight). Set 0 to disable.
	if (isNil "WFBE_C_AIHELI_GUARD_LOOKAHEAD") then {WFBE_C_AIHELI_GUARD_LOOKAHEAD = 250}; //--- m ahead of the heli to sample terrain.
	if (isNil "WFBE_C_AIHELI_GUARD_CLEARANCE") then {WFBE_C_AIHELI_GUARD_CLEARANCE = 60};  //--- m minimum clearance over the terrain ahead before the heli is told to climb.	//-------------------------------------------------------------------------------------------------------------
	if (isNil "WFBE_C_UNITS_PRICING") then {WFBE_C_UNITS_PRICING = 0}; //--- Price Focus. (0: Default, 1: Infantry, 2: Tanks, 3: Air).
	if (isNil "WFBE_C_UNITS_TOWN_PURCHASE") then {WFBE_C_UNITS_TOWN_PURCHASE = 1}; //--- Allow AIs to be bought from depots.
	if (isNil "WFBE_C_UNITS_TRACK_INFANTRY") then {WFBE_C_UNITS_TRACK_INFANTRY = 1}; //--- Track units on map (infantry).
	if (isNil "WFBE_C_UNITS_TRACK_LEADERS") then {WFBE_C_UNITS_TRACK_LEADERS = 1}; //--- Track playable Team Leaders on map (infantry).
	WFBE_C_UNITS_BOUNTY_COEF = 1; //--- Bounty is the unit price * coef.
	WFBE_C_BUILDINGS_SCORE_COEF = 3; // Score for killing base structures and HQ is building bounty * coef
	WFBE_C_UNITS_BOUNTY_ASSISTANCE_COEF = 0.5; //--- Bounty assistance is the unit price * coef * assist coef.
	//--- Card #66 (killstreak bounty): killing a player who is on a killstreak pays MORE. The PvP bounty is
	//--- multiplied by 1 + min(victimStreak, CAP) * COEF. At COEF=0.15 / CAP=10 a victim on a 10-kill streak
	//--- pays 2.5x. Server-authoritative (RequestOnUnitKilled.sqf tracks wfbe_killstreak); applied client-side
	//--- in AwardBountyPlayer.sqf. TUNABLE: raise COEF for steeper reward, raise CAP to let very long streaks
	//--- keep scaling. Set COEF=0 to disable the feature (multiplier collapses to 1.0).
	WFBE_C_UNITS_BOUNTY_STREAK_COEF = 0.15; //--- Per-streak bounty bonus fraction (0 disables).
	WFBE_C_UNITS_BOUNTY_STREAK_CAP = 10;    //--- Streak value at which the bounty bonus stops growing.
	WFBE_C_UNITS_COUNTERMEASURE_PLANES = 64;
	WFBE_C_UNITS_COUNTERMEASURE_CHOPPERS = 32;
	WFBE_C_UNITS_CREW_COST = 120;
	WFBE_C_UNITS_PURCHASE_RANGE = 150;
	WFBE_C_UNITS_PURCHASE_GEAR_RANGE = 150;
	WFBE_C_UNITS_PURCHASE_GEAR_MOBILE_RANGE = 5;
	WFBE_C_UNITS_PURCHASE_GEAR_MOBILE_AI_RANGE = 45;
	WFBE_C_UNITS_PURCHASE_HANGAR_RANGE = 50;
	WFBE_C_UNITS_REPAIR_TRUCK_RANGE = 40;
	WFBE_C_UNITS_SALVAGER_SCAVENGE_RANGE = 60;
	WFBE_C_UNITS_SALVAGER_SCAVENGE_RATIO = 60; //--- Salvager Sell %.
	WFBE_C_UNITS_SKILL_DEFAULT = 1;
	WFBE_C_UNITS_SUPPORT_RANGE = 70; //--- Action range for repair/rearm/refuel.
	WFBE_C_UNITS_SUPPORT_HEAL_PRICE = 125;
	WFBE_C_UNITS_SUPPORT_HEAL_TIME = 10;
	WFBE_C_UNITS_SUPPORT_REARM_PRICE = 14;
	WFBE_C_UNITS_SUPPORT_REARM_TIME = 20;
	WFBE_C_UNITS_SUPPORT_REFUEL_PRICE = 16;
	WFBE_C_UNITS_SUPPORT_REFUEL_TIME = 10;
	WFBE_C_UNITS_SUPPORT_REPAIR_PRICE = 2;
	WFBE_C_UNITS_SUPPORT_REPAIR_TIME = 20;

	// === QoL Trio (work-order item 16) ===
	if (isNil "WFBE_C_QOL_TRIO") then {WFBE_C_QOL_TRIO = 1};                //--- 0 disables all three QoL features.
	if (isNil "WFBE_C_QOL_ADVISOR_INTERVAL") then {WFBE_C_QOL_ADVISOR_INTERVAL = 300}; //--- Seconds between advisor nudge checks (0 = off).

	// === Restart announcer (work-order item 15) — server-side countdown, one broadcast per minute over the final WARN window. ===
	if (isNil "WFBE_C_RESTART_ENABLED") then {WFBE_C_RESTART_ENABLED = 0};   //--- 0 disables the in-game restart announcer entirely.
	if (isNil "WFBE_C_RESTART_AT_MIN") then {WFBE_C_RESTART_AT_MIN = 90};    //--- Mission uptime (minutes) at which the scheduled restart occurs.
	if (isNil "WFBE_C_RESTART_WARN_MIN") then {WFBE_C_RESTART_WARN_MIN = 5}; //--- Start warning this many minutes out; fires exactly this many times (once per minute).
	if (isNil "WFBE_C_RESTART_MSG") then {WFBE_C_RESTART_MSG = "SERVER RESTART IN %1 MINUTE(S) - finish up and find cover."}; //--- %1 = minutes remaining.

	// === Dashboard-link announcer (claude-gaming 2026-06-14) — periodic in-game broadcast of the public live-stats URL so players know where to find updates/benchmarks. ===
	if (isNil "WFBE_C_DASHBOARD_ANNOUNCE_ENABLED") then {WFBE_C_DASHBOARD_ANNOUNCE_ENABLED = 1};    //--- 0 disables the in-game dashboard-link announcer.
	if (isNil "WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL") then {WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL = 840}; //--- Seconds between dashboard-link broadcasts (default 5 min).
	if (isNil "WFBE_C_DASHBOARD_MSG") then {WFBE_C_DASHBOARD_MSG = "WASP LIVE STATS & LEADERBOARD  >>  miksuu.com/leaderboard  <<  live server FPS, AI balance, K/D and per-build benchmarks - updated every round."}; //--- fallback single line (used only if the MSGS pool below is empty).
	//--- Build 83 (Ray 2026-07-01): rotating hint pool, cycled by server_dashboard_announcer at WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL (~14 min apart).
	if (isNil "WFBE_C_DASHBOARD_MSGS") then {WFBE_C_DASHBOARD_MSGS = [
		"WASP LIVE STATS & LEADERBOARD  >>  miksuu.com/leaderboard  <<  live server FPS, AI balance, K/D and per-build benchmarks - updated every round.",
		"Join the WASP community on Discord  >>  discord.me/warfare  <<  feedback, bug reports & match times.",
		"TIP: Town AA guards towns with active air. Check the map before you fly a supply run into a contested sector.",
		"TIP: SCUD tech is now a two-level program. Land TEL munitions and carrier launches are powerful, but TELs can be destroyed.",
		"TIP: Territorial victory is live - holding most towns long enough can win the round before every base is destroyed.",
		"TIP: The WF menu SKIN button opens the skin selector; picked skins return after respawn."
	]}; //--- the broadcast line.

	// === Top-Players leaderboard emitter (claude-gaming 2026-06-14) — periodic per-player PLAYERSTAT snapshot. ===
	// This is the ONLY telemetry carrying the player display NAME, so it powers the public Top-Players tab
	// (UID -> name -> score -> side). Kills/deaths are folded dashboard-side from the existing KILL stream.
	// Reuses the always-on WFBE_C_STATLOG gate; independent of the OFF-by-default WFBE_C_STATS_ENABLED path.
	if (isNil "WFBE_C_PLAYERSTAT_ENABLED") then {WFBE_C_PLAYERSTAT_ENABLED = 1};   //--- 0 disables the per-player leaderboard emit entirely.
	if (isNil "WFBE_C_PLAYERSTAT_INTERVAL") then {WFBE_C_PLAYERSTAT_INTERVAL = 60}; //--- Seconds between PLAYERSTAT snapshot bursts (floored at 30s in the loop).

	// === SIDESCORE honest side-activity telemetry (wasp-score-dashboard-build-20260722) - additive dual-field ===
	// SCORE|v1 (server_groupsGC.sqf) uses engine scoreSide, which credits player-driven score only, so an AI-only
	// side reads 0 on the public dashboard despite real WASPSTAT kill/capture activity. When >0, server_groupsGC.sqf
	// emits an ADDITIVE SIDESCORE|v1 line (playerWest/East from scoreSide UNCHANGED, plus per-side kill/capture
	// running counters from RequestOnUnitKilled.sqf + server_town.sqf). playerWest/East stay west/east-only by
	// design (continuity with the pre-existing engine number); SCORE|v1 separately gained a |guer= field (see
	// server_groupsGC.sqf) so GUER side score is no longer missing from that line. Kills and
	// captures are mutual-knowledge combat record (both sides already see them), not base/town-ownership intel -
	// within the 2026-06-21 competitive-integrity rule. Default 0 = flag-off, byte-identical to HEAD (no emit).
	if (isNil "WFBE_C_SIDESCORE") then {WFBE_C_SIDESCORE = 0};

	// === EXPERITAL FEATURES (experimental branch ??? each feature individually toggleable) ===
	WFBE_C_STRUCTURES_COUNTERBATTERY = 1; // Counter Battery Radar structure (mid-game, requires own AAR)
	WFBE_C_ECONOMY_BANK = 1;              // Federal Reserve / Bank Rossii endgame objective building
	WFBE_C_STRUCTURES_ARTILLERYRADAR = 0; // Artillery Radar buildable structure (WDDM walled-gate walls, fort-only by design)
	WFBE_C_STRUCTURES_RESERVE = 0;        // Reserve buildable structure (WDDM floodlit walled-yard walls)
	WFBE_C_UNITS_REDEPLOYTRUCK = 1;       // Medic redeployment truck (forward spawn)
	WFBE_C_SUPPORT_REARM_PROPORTIONAL = 1; //--- Rearm price scales with ammo actually missing (arty exempt)
	WFBE_C_UNITS_BULLDOZER = 1;           //--- Engineer base-area tree clearing
	WFBE_C_DEFENSE_BUDGET = 1;            // Per-base-area defense caps scaling with barracks level
	WFBE_C_BASE_DEFENSE_STATICS_CAP = 25; // Max player-placed static base defenses (MGs/AA/AAPOD) per base area (raised from 10)
	WFBE_C_DEFENSE_THREAT_MIN = 3;        // Min enemy ground units (west/east, no Air/GUER) inside base range before the statics/mines threat gate fires
	if (isNil "WFBE_C_DEFENSE_CLIENT_GATE_ALIGN") then {WFBE_C_DEFENSE_CLIENT_GATE_ALIGN = 1}; //--- Default OFF: client placement preview uses per-unit exitWith scan. When 1, client enemy-in-base red only fires when enemy-side unit count >= WFBE_C_DEFENSE_THREAT_MIN (mirrors the server threat gate).
	WFBE_C_WDDM_COMP_CAP = 3;            //--- Max WDDM commander compositions per base area (size-independent).
	WFBE_C_FACTORY_QUEUE_LIMITS = 1;      // Per-factory production queue caps scaling with factory level
	if (isNil "WFBE_C_FIX_FACTORY_QUEUE_TOKEN_HARDENING") then {WFBE_C_FIX_FACTORY_QUEUE_TOKEN_HARDENING = 0}; //--- Default-off: opt-in stronger player-buy FIFO tokens; 0 keeps legacy UID+diag_tickTime tokens.
	WFBE_C_STATLOG = 1;                   // [WASPSTAT] structured telemetry RPT lines
	if (isNil "WFBE_C_LOG_TOWN_COORDS") then {WFBE_C_LOG_TOWN_COORDS = 0}; // One-shot: dump every town's map position (TOWNPOS|... RPT lines) for the post-match report's TOWN_COORDS. Default OFF; flip to 1 for a single boot per map, harvest, flip back. Off = zero effect.
	if (isNil "WFBE_C_TOWNS_GUNNERS_ON_CAPTURE") then {WFBE_C_TOWNS_GUNNERS_ON_CAPTURE = true}; // Immediately man static defenses at capture (all sides); false = reactive only
	if (isNil "WFBE_C_TOWN_GUER_GUNNER_REAP") then {WFBE_C_TOWN_GUER_GUNNER_REAP = 1}; //--- fix(alife) proper #1370 (default OFF): when a WEST/EAST side captures a GUER town, also reap the AI gunner still manning the deleted GUER static. GUER's town statics are manned via the HC-delegated path (Server_HandleDefense.sqf -> WFBE_CO_FNC_DelegateAIStaticDefenceHeadless), so wfbe_defense_operator (only set on the non-HC "spawn" branch in Server_OperateTownDefensesUnits.sqf) is routinely nil here - the gunner is untracked and was previously left orphaned when only the static hull itself got deleted. 0 = legacy (hull-only delete). 1 = also delete the untracked gunner, routed to its owning machine when HC-local (server_town.sqf capture teardown) via the same WFBE_CO_FNC_SendToClient dispatch server_groupsGC.sqf uses for commander arty/heli wrecks.
	//--- Task 32: capture grace periods.
	//--- Delay (seconds) before the new owner's static defenses and defense teams spawn after capture.
	//--- A fire-time ownership guard aborts the spawn if the town changed hands again in the interim.
	WFBE_C_TOWNS_DEFENSE_SPAWN_DELAY = 300;
	//--- Linger time (seconds): the old owner's gunners keep fighting after capture before being cleaned up.
	//--- A fire-time guard aborts cleanup if the town has flipped back to the old owner's side.
	WFBE_C_TOWNS_DEFENDER_LINGER = 180;
	if (isNil "WFBE_C_TOWNS_MOPUP_TTL") then {WFBE_C_TOWNS_MOPUP_TTL = 600}; //--- Lane 200: max seconds a captured-town mop-up squad may keep scanning before it stands down.
	if (isNil "WFBE_C_EASA_CATEGORIES") then {WFBE_C_EASA_CATEGORIES = 1}; // EASA loadout category tags [AA]/[AG]/[MR] prefixed on each row (display-only)
	if (isNil "WFBE_C_AIRFIELDS") then {WFBE_C_AIRFIELDS = 1}; // Airfield capture points (NWAF/NEAF/Balota): repair-point + exclusive hangar on capture
	if (isNil "WFBE_C_CAPTURE_UNLOCKS") then {WFBE_C_CAPTURE_UNLOCKS = 1}; // Holding trigger towns unlocks premium ACR units at own factories (Krasnostav->T72M4CZ lvl4 Heavy; NWAF->RM70_ACR lvl4 Light)
	if (isNil "WFBE_C_PATROL_CONVOY_PAY") then {WFBE_C_PATROL_CONVOY_PAY = 750}; // [ORPHANED 2026-07-28 fable/patrol-reimagine: convoy truck + payout removed from Common_RunSidePatrol.sqf/Server_HandleSpecial.sqf per owner order; constant retained per repo policy, value unused.] Was: per-stop convoy cash pool.
	if (isNil "WFBE_C_SKIN_SELECTOR") then {WFBE_C_SKIN_SELECTOR = 0}; // Command Deck: join-time skin selector (1 enabled, 0 disabled)
	if (isNil "WFBE_C_VEHICLE_MARKINGS") then {WFBE_C_VEHICLE_MARKINGS = 0}; // Miksuu vehicle visuals master gate: per-side recognition markings (Common_AddVehicleMarking.sqf) + side-gated body skins / WEST matte-black (Common_AddVehicleTexture.sqf). 1 enabled, 0 disabled. DEFAULT 0 (experimental, OFF): the marking impl attaches up to 3 dim local #lightpoints PER created vehicle and the WEST case repaints EVERY blufor hull matte-black - both are unverified in-engine and FPS-sensitive. Flip to 1 only after an in-engine attach/FPS test. (Infantry skin selector is separate: WFBE_C_SKIN_SELECTOR.)
	//--- Vehicle FACTION FLAGS (Common_AddVehicleFlag.sqf): when ON, every created vehicle flies its side's
	//--- FlagCarrier pole (WEST/EAST/GUER), attached locally on every client via the wfbe_pending_texture
	//--- broadcast (JIP-safe). Independent gate from MARKINGS/TINTS so flags can be A/B'd on their own.
	if (isNil "WFBE_C_VEHICLE_FLAGS") then {WFBE_C_VEHICLE_FLAGS = 0}; // Master toggle / mission setting. 1 enabled, 0 disabled. DEFAULT 0 (opt-in, like MARKINGS/TINTS): it attaches a flag OBJECT per created vehicle, so it is FPS-sensitive on heavy-AI servers. Flip to 1 only after an in-engine attach/FPS test.
	//--- Per-side flag classes are TUNABLE so a host can match their faction set-up. Other valid examples:
	//--- FlagCarrierCDF, FlagCarrierINS, FlagCarrierTakistan_EP1, FlagCarrierTKMilitia_EP1.
	if (isNil "WFBE_C_VEHICLE_FLAG_WEST") then {WFBE_C_VEHICLE_FLAG_WEST = "FlagCarrierNATO_EP1"}; // BLUFOR flag class flown on WEST vehicles.
	if (isNil "WFBE_C_VEHICLE_FLAG_EAST") then {WFBE_C_VEHICLE_FLAG_EAST = "FlagCarrierRU"}; // OPFOR flag class flown on EAST vehicles.
	if (isNil "WFBE_C_VEHICLE_FLAG_GUER") then {WFBE_C_VEHICLE_FLAG_GUER = "FlagCarrierGUE"}; // Resistance/GUER flag class flown on GUER vehicles.
	if (isNil "WFBE_C_KILL_TALLY_DECAL") then {WFBE_C_KILL_TALLY_DECAL = 0}; // Lane 205 kill-tally GLOW, OFF (Ray pick C 2026-07-04: tally now renders as a heat-coloured star count in the TAGS name-tag overlay, Init_Client.sqf - no lightpoint). a vehicle that scores enemy kills carries ONE dim hull-hugging local #lightpoint that heat-ramps amber (1-2 kills) -> orange (3-5) -> red (6-9) -> white-hot (10+). Server increments wfbe_kill_tally in RequestOnUnitKilled.sqf (null-guarded); Common_AddVehicleMarking.sqf installs the JIP-safe local watcher. Set 0 to disable; independent from WFBE_C_VEHICLE_MARKINGS (which stays 0 - it also repaints WEST hulls matte-black and attaches 3 lights/vehicle, failed the visual/FPS bar).
	if (isNil "WFBE_C_VEHICLE_TINTS") then {WFBE_C_VEHICLE_TINTS = 0}; // B74.2 (Ray 2026-06-23): default OFF for now; switch preserved. [A/B: was flipped ON 2026-06-22 per Ray for the in-engine cosmetic check; revert to 0 if the look is bad] Vehicle faction body TINTS (cheap one-shot setObjectTexture colour strings in Common_AddVehicleTexture.sqf). Decoupled from WFBE_C_VEHICLE_MARKINGS so the tints can be LIVE while the expensive #lightpoint markings stay OFF. 1 enabled, 0 disabled. DEFAULT 0 (opt-in): the B66 side-resolve bug meant the tints were silently INERT in prod (resolved from a crewless hull = civilian -> no faction match); B67 fixed the resolution (now reads the authoritative _createSide passed by Common_CreateVehicle), so enabling this would for the FIRST TIME repaint selections 0+1 (often the whole hull) with a flat procedural colour on EVERY vehicle (WEST near-black / EAST olive / GUER tan) - unverified in-engine and possibly ugly. Flip to 1 only after an in-engine cosmetic check.
	if (isNil "WFBE_C_VEHICLE_TINT_LEGEND") then {WFBE_C_VEHICLE_TINT_LEGEND = 1}; // b67 item #3: top-right client pop-up legend explaining the vehicle body TINTS above (WEST/BLUFOR=black, EAST/OPFOR=olive, GUER=tan). Shown once on first spawn + toggled with "]" (Init_Client.sqf, cutRsc "WFBE_VehicleTintLegend"). Pure client cosmetic, zero FPS cost; only appears when WFBE_C_VEHICLE_TINTS is also ON. Nil-guarded so it can be A/B'd independently: 1 enabled, 0 disabled.
	//--- Triggered faction smoke (cosmetic): WFBE_CO_FNC_SpawnFactionSmoke drops ONE side-coloured smoke shell at assault onset / town garrison. Server-only, event-triggered, hard-capped + TTL + per-100m-grid cooldown. west=Green, east=Red, resistance=Orange. ON for live measurement.
	if (isNil "WFBE_C_FSMOKE_ENABLED") then {WFBE_C_FSMOKE_ENABLED = 1}; // Master gate: 1 enabled, 0 disabled.
	if (isNil "WFBE_C_FSMOKE_MAX") then {WFBE_C_FSMOKE_MAX = 8}; // Global hard cap on concurrent faction-smoke shells (prune dead, then refuse new at cap).
	if (isNil "WFBE_C_FSMOKE_TTL") then {WFBE_C_FSMOKE_TTL = 20}; // Seconds before each spawned shell is deleteVehicle'd + de-listed.
	if (isNil "WFBE_C_FSMOKE_COOLDOWN") then {WFBE_C_FSMOKE_COOLDOWN = 150}; // Per-100m-grid-key cooldown (s) so one spot can't re-trigger smoke spam.

	//--- Units Factions.
switch (true) do {
	case (WF_A2_CombinedOps): {
			WFBE_C_UNITS_FACTIONS_EAST = ['INS','RU','TKA']; //--- East Factions.
			WFBE_C_UNITS_FACTIONS_GUER = ['GUE','PMC','TKGUE']; //--- Guerilla Factions.
			WFBE_C_UNITS_FACTIONS_WEST = ['CDF','US','USMC']; //--- West Factions.

			// Reworked to use the the cherno/takistan parameter
            if (IS_chernarus_map_dependent) then {
                missionNamespace setVariable ['WFBE_C_UNITS_FACTION_WEST', 2]; // USMC index
                missionNamespace setVariable ['WFBE_C_UNITS_FACTION_EAST', 1]; // RU index
                missionNamespace setVariable ['WFBE_C_UNITS_FACTION_GUER', 0]; // GUE index
            } else {
                missionNamespace setVariable ['WFBE_C_UNITS_FACTION_WEST', 1]; // US index
                missionNamespace setVariable ['WFBE_C_UNITS_FACTION_EAST', 2]; // TKA index
                missionNamespace setVariable ['WFBE_C_UNITS_FACTION_GUER', 2]; // TKGUE index
            };
	};
};

//--- Victory.
	WFBE_C_VICTORY_THREEWAY = 0; //--- Victory Condition (0: Side a vs Side b [supremacy] minus defender).
	WFBE_C_VICTORY_THREEWAY_LOCATION_SWAP = 300; //--- When the defender loose depending on victory conditions, startup locations become available for respawn with a rotation (to prevent spawn camping).

//--- Overall mission coloration.
if (side group player == west) then{
missionNamespace setVariable ["WFBE_C_WEST_COLOR", "ColorGreen"];
missionNamespace setVariable ["WFBE_C_EAST_COLOR", "ColorRed"];
missionNamespace setVariable ["WFBE_C_GUER_COLOR", "ColorBlue"];
missionNamespace setVariable ["WFBE_C_CIV_COLOR", "ColorYellow"];
missionNamespace setVariable ["WFBE_C_UNKNOWN_COLOR", "ColorBlue"];
}else{
if ((side group player == resistance) && ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0)) then {
//--- GUER "Insurgents" player view: own side green; both main factions hostile (red).
missionNamespace setVariable ["WFBE_C_WEST_COLOR", "ColorRed"];
missionNamespace setVariable ["WFBE_C_EAST_COLOR", "ColorRed"];
missionNamespace setVariable ["WFBE_C_GUER_COLOR", "ColorGreen"];
missionNamespace setVariable ["WFBE_C_CIV_COLOR", "ColorYellow"];
missionNamespace setVariable ["WFBE_C_UNKNOWN_COLOR", "ColorBlue"];
} else {
missionNamespace setVariable ["WFBE_C_WEST_COLOR", "ColorRed"];
missionNamespace setVariable ["WFBE_C_EAST_COLOR", "ColorGreen"];
missionNamespace setVariable ["WFBE_C_GUER_COLOR", "ColorBlue"];
missionNamespace setVariable ["WFBE_C_CIV_COLOR", "ColorYellow"];
missionNamespace setVariable ["WFBE_C_UNKNOWN_COLOR", "ColorBlue"];
};
};

if (isNil "WFBE_C_FIX_NEUTRAL_MAP_COLOR") then {WFBE_C_FIX_NEUTRAL_MAP_COLOR = 1};
if (isNil "WFBE_C_NEUTRAL_COLOR") then {WFBE_C_NEUTRAL_COLOR = "ColorBlack"};
missionNamespace setVariable ["WFBE_C_FIX_NEUTRAL_MAP_COLOR", WFBE_C_FIX_NEUTRAL_MAP_COLOR];
missionNamespace setVariable ["WFBE_C_NEUTRAL_COLOR", WFBE_C_NEUTRAL_COLOR];

	/* Special Variables, Those are used after the typical declaration above. */

//--- Build area (Radius/Height).
	WFBE_C_BASE_COIN_AREA_HQ_DEPLOYED = [WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED, 25];
	WFBE_C_BASE_COIN_AREA_HQ_UNDEPLOYED = [WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED / 2, 25];
	WFBE_C_BASE_COIN_AREA_REPAIR = [45, 10];

//--- Max structures.
	if (isNil 'WFBE_C_STRUCTURES_MAX_BARRACKS') then {WFBE_C_STRUCTURES_MAX_BARRACKS = WFBE_C_STRUCTURES_MAX};
	if (isNil 'WFBE_C_STRUCTURES_MAX_LIGHT') then {WFBE_C_STRUCTURES_MAX_LIGHT = WFBE_C_STRUCTURES_MAX};
	if (isNil 'WFBE_C_STRUCTURES_MAX_COMMANDCENTER') then {WFBE_C_STRUCTURES_MAX_COMMANDCENTER = WFBE_C_STRUCTURES_MAX};
	if (isNil 'WFBE_C_STRUCTURES_MAX_HEAVY') then {WFBE_C_STRUCTURES_MAX_HEAVY = WFBE_C_STRUCTURES_MAX};
	if (isNil 'WFBE_C_STRUCTURES_MAX_AIRCRAFT') then {WFBE_C_STRUCTURES_MAX_AIRCRAFT = WFBE_C_STRUCTURES_MAX};
	if (isNil 'WFBE_C_STRUCTURES_MAX_SERVICEPOINT') then {WFBE_C_STRUCTURES_MAX_SERVICEPOINT = WFBE_C_STRUCTURES_MAX * 2};
	if (isNil 'WFBE_C_STRUCTURES_MAX_TENTS') then {WFBE_C_STRUCTURES_MAX_TENTS = 3};
	if (isNil 'WFBE_C_STRUCTURES_MAX_Bank') then {WFBE_C_STRUCTURES_MAX_Bank = 1};
	if (isNil 'WFBE_C_STRUCTURES_MAX_CBRadar') then {WFBE_C_STRUCTURES_MAX_CBRadar = 1};
	if (isNil 'WFBE_C_STRUCTURES_MAX_AARadar') then {WFBE_C_STRUCTURES_MAX_AARadar = 1};
	if (isNil 'WFBE_C_STRUCTURES_RADAR_PENDING_WINDOW') then {WFBE_C_STRUCTURES_RADAR_PENDING_WINDOW = 180}; //--- fable/ew-economy: CBRadar/AARadar one-per-side reservation window (s) to close the duplicate-build race (mirrors WFBE_C_ECONOMY_BANK_PENDING_WINDOW above), RequestStructure.sqf.
	//--- build/defense audit 2026-07-28: server-side cap + PENDING-reservation guard for the MULTI-INSTANCE
	//--- economy structures (Barracks/Light/Heavy/Aircraft/ServicePoint/CommandCenter), extending the
	//--- CBRadar/AARadar/Bank single-instance idiom above (RequestStructure.sqf, Construction_SmallSite.sqf,
	//--- Construction_MediumSite.sqf). 1 (default, armed) = server re-checks the SAME WFBE_C_STRUCTURES_MAX_
	//--- <type> caps the AI commander already obeys server-side (AI_Commander_Base.sqf) before accepting a
	//--- player build request; it only rejects what the declared caps already forbid. 0 = legacy client-only
	//--- enforcement (coin_interface.sqf wfbe_structures_live), byte-identical to HEAD.
	if (isNil "WFBE_C_STRUCTURES_CAP_SERVER") then {WFBE_C_STRUCTURES_CAP_SERVER = 1};
	//--- Reservation window (s) for the multi-instance PENDING array above: an entry older than this is
	//--- treated as stale and pruned on the next read, so a construction-side release path that somehow
	//--- never fires cannot permanently wedge a side's cap. Separate tunable from
	//--- WFBE_C_STRUCTURES_RADAR_PENDING_WINDOW / WFBE_C_ECONOMY_BANK_PENDING_WINDOW so those existing
	//--- single-instance defaults are untouched.
	if (isNil "WFBE_C_STRUCTURES_PENDING_WINDOW") then {WFBE_C_STRUCTURES_PENDING_WINDOW = 180};

//--- Apply a towns unit coeficient.
	WFBE_C_TOWNS_UNITS_COEF = switch (WFBE_C_TOWNS_OCCUPATION) do {case 1: {1}; case 2: {1.5}; case 3: {2}; case 4: {2.5}; default {1}};
	WFBE_C_TOWNS_UNITS_DEFENDER_COEF = switch (WFBE_C_TOWNS_DEFENDER) do {case 1: {1}; case 2: {1.5}; case 3: {2}; case 4: {2.5}; default {1}};
	WFBE_C_TOWNS_MERGE_TARGET = 9;                //--- GROUP-COUNT REDUCTION (claude-gaming 2026-06-13): target units per CONSOLIDATED town-garrison infantry group. Server_GetTownGroups/Defender fuse the SAME infantry rosters into ~this-many-unit groups (hard cap 10) so a town spawns identical units in FEWER server group-brains (server-FPS win, gameplay-transparent). Vehicles never merged. Set to 0 to disable (instant rollback to one-group-per-template).
	if (isNil 'WFBE_C_TOWNS_MERGE_TARGET_DEFENDER') then {WFBE_C_TOWNS_MERGE_TARGET_DEFENDER = 10}; //--- GUER condense A/B (task #12, claude-gaming 2026-06-14): fuse GUER garrisons into ~10-unit groups (fewer group-brains, SAME units). Measure GUER group count + fps vs Build 28. WEST/EAST use the global target (9).
	if (isNil 'WFBE_C_TOWNS_MERGE_CAP_DEFENDER') then {WFBE_C_TOWNS_MERGE_CAP_DEFENDER = 12};    //--- Defender-only merged-group size cap (raised from the global hardcoded 10 so the 10-target can flush at ~10-12; 12 = classic A2 squad max, safe for static garrison defenders).
	if (isNil 'WFBE_C_SIDE_PATROLS_MAX_DEFENDER') then {WFBE_C_SIDE_PATROLS_MAX_DEFENDER = 3};      //--- Build83 (Ray 2026-07-01): GUER (defender) side-patrol cap RAISED +2 -> 3 (effective = min(this, GUER patrol level)). [B36 2026-06-15 had 2->1: fewer GUER patrols, the survivors made deadlier (skill boost in Common_RunSidePatrol). GUER condense.
	if (isNil 'WFBE_C_GUER_PATROLS_LEVEL') then {WFBE_C_GUER_PATROLS_LEVEL = 2};                    //--- B67 (Ray 2026-06-21): fixed Patrols level for GUER (resistance has no upgrade system) so GUER side-patrols actually dispatch and show on GUER players' maps (server_side_patrols.sqf). Effective concurrent count = min(_maxSide, this). 0 = OFF (no GUER patrols, instant rollback); 1 = single; 2 = a pair; 4 adds the convoy supply truck.
	WFBE_C_GROUP_BUDGET_WARN = 120;               //--- GROUP-BUDGET ALARM (claude-gaming 2026-06-13): per-side group-count WARN threshold (GRPBUDGET line in AI_Commander.sqf). Arma 2 OA hard cap is 144/side; crossing this logs a GRPBUDGET|WARN so the watchdog/dashboard flags it before the AI can no longer found teams. (120, not 125: with the persistent-husk leak fixed, steady state should drop below 120, making the WARN a true leading indicator rather than always-on.)
	if (isNil 'WFBE_C_GROUPAUDIT_EVERY') then {WFBE_C_GROUPAUDIT_EVERY = 5}; //--- D2 server-FPS (claude-gaming 2026-06-14): run the EXPENSIVE per-faction group-classification AUDIT DUMP (server_groupsGC.sqf; auditMs ~2100ms on 276 groups) only every Nth 5-min audit window. The husk-reap GC + zombie-reap + cap-warning still run EVERY 60s cycle (they live outside the audit branch) - this throttles only diagnostic telemetry. 5 = full dump ~every 25 min instead of every 5 min. 1 = dump every window (old behavior); values < 1 are clamped to 1. Pure diagnostic throttle, no gameplay effect; instant rollback by setting to 1.

	if (isNil 'WFBE_C_TOWNS_MERGE_CAP') then {WFBE_C_TOWNS_MERGE_CAP = 10};    //--- WEST/EAST merged town-garrison group SIZE cap. Was the hardcoded 10 in Server_GetTownGroups; now a first-class tunable (symmetric with WFBE_C_TOWNS_MERGE_CAP_DEFENDER). Default 10 = byte-identical to the historical hard cap.
	//--- GARRISON GROUP-CAP HEADROOM (task wasp-garrison-mergeup-20260722, C6 pick 2, owner GO 2026-07-22 19:08): flag-gated raise
	//--- of the merged town-garrison group SIZE (target + cap) from ~9-10 (WEST/EAST) / ~10-12 (GUER defender) up to ~12-14, so a
	//--- town spawns the SAME defenders in FEWER server group-brains (~-20-30% garrison group count) -> more headroom under the
	//--- 144/side engine cap + WFBE_C_GUER_GROUPS_MAX(80) / WFBE_C_AICOM_GROUP_CAP(110) gates, smaller allGroups scans per
	//--- GC/telemetry pass, and fewer per-group FSMs. SAME units a player sees & fights (merge is group-brain consolidation only;
	//--- vehicles are never merged). Orthogonal to wasp-town-garrison-minus20 (#1266, WFBE_C_TOWN_GARRISON_SCALE): that lever
	//--- changes garrison SIZE, this one changes group GRANULARITY; the two are sequence-safe. 0 = OFF (byte-identical to HEAD;
	//--- instant rollback). The Zargabad WEST/EAST merge override (ZG-FIX block below) still wins for ZG WEST/EAST.
	if (isNil 'WFBE_C_TOWNS_MERGE_HEADROOM') then {WFBE_C_TOWNS_MERGE_HEADROOM = 1}; //--- 0->1 (owner GO 2026-07-22 19:08: arm garrison-merge headroom; infra pre-existing).
	if (WFBE_C_TOWNS_MERGE_HEADROOM > 0) then {
		WFBE_C_TOWNS_MERGE_TARGET = 12;              //--- WEST/EAST flush threshold (was 9). Paired with WFBE_C_TOWNS_MERGE_CAP (14).
		WFBE_C_TOWNS_MERGE_TARGET_DEFENDER = 12;     //--- GUER defender flush threshold (was 10).
		WFBE_C_TOWNS_MERGE_CAP_DEFENDER = 14;        //--- GUER defender max merged-group size (was 12).
		WFBE_C_TOWNS_MERGE_CAP = 14;                 //--- WEST/EAST max merged-group size (was the hardcoded 10).
	};

//--- ZG-FIX (zg-alive-population, claude-gaming 2026-07-03): Zargabad-scoped AI-POPULATION governor overrides.
//--- WHY: the 2026-07-02 Zargabad soak glaciated - AI grew to ~440 units / 120+ groups (WEST ~140 + EAST ~140
//--- + GUER ~150 at the tier-0 per-side cap of 140), server fps 47->8 by hour 3, 0 captures. ~440 sits AT the
//--- measured fps knee (~450-470 units). This block RETUNES the existing governor levers ZG-scoped so steady
//--- state lands ~280-320 total (below the knee with margin) WITHOUT feeling empty: fewer-but-FULL commander
//--- teams (team size 8 UNCHANGED - Ray rule), consolidated town garrisons (SAME units, fewer group-brains),
//--- and FASTER recycling of idle rear foot teams so the bounded budget refounds at the FRONT (density, not scarcity).
//--- CH/TK: byte-identical - the whole block is skipped by the worldName guard. GUER OUTPUT UNTOUCHED (the
//--- DEFENDER merge target + GUER group cap + GUER patrols are NOT set here; only WEST/EAST + shared totals move).
//--- These are POST-overrides (run AFTER the bare CH/TK assignments above), the same idiom as the ZG
//--- WFBE_C_ENVIRONMENT_MAX_VIEW cap (~L1383). Every value is a plain missionNamespace global - Ray retunes any
//--- of them live on the box by editing this block (no ParamsArray entry gates them). NO sim/distance-gating is
//--- wired (owner-rejected) and antistack is not touched; this is pure lever-retuning of the existing systems.
	if (worldName == "Zargabad") then {
		//--- (1) MASTER per-side WEST/EAST AI ceiling by pop-tier (0=LOW/1=MID/2=HIGH/3=FULL). Read by BOTH the
		//--- founding gate (AI_Commander_Teams.sqf ~L235) and the produce/refill gate (AI_Commander_Produce.sqf ~L28);
		//--- counts {side==_side && !isPlayer} ALL side AI incl. WEST/EAST town garrisons. CH/TK stays [140,130,100,80].
		//--- ZG low-pop 80/side: WEST 80 + EAST 80 + GUER ~150 = ~310 total (target 280-320, ~150 below the knee).
		WFBE_C_TOTAL_AI_MAX_BY_TIER = [180,170,150,120]; //--- ZG (owner 2026-07-26): 250 max AI/side on the 4-HC soak box, was [90,85,75,60]. EXPLICITLY re-opens the 2026-07-23 pullback - that pullback was measured on the OLD 2-HC Xeon box (FPS 15 at AI_TOT 383); this box is 4 HCs on 8 uniform cores and exists to find the real ceiling. If FPS collapses, roll back to [90,85,75,60]. Prior ZG pullback note (owner live-tune final 2026-07-23, after [110,100,85,70]: FPS 15 at AI_TOT 383). Prior: [80,80,70,60] pre-2-HC-split raise, then [110,100,85,70]. Rollback: [110,100,85,70]. CH/TK stay [140,130,100,80].
		//--- (2) per-side COMMANDER-TEAM hard ceiling. Fewer teams, each still founds at 8 units (TEAM_SIZE untouched)
		//--- = concentration, not sprawl. 5 x 8 = ~40 core + garrisons stays under the 80 AI cap above.
		WFBE_C_AICOM_TEAMS_HARD_CAP = 12;              //--- ZG (owner 2026-07-28, 16 -> 12 with the global). Prior: owner 2026-07-26, 8 -> 16. Still MATCHES the global - kept explicit so a global rollback does not silently re-clamp ZG. 4-HC soak box: 8 was the clamp pinning effective team target to 8 despite PC_LOW=9. Real ceiling is now WFBE_C_TOTAL_AI_MAX_BY_TIER (90/side low-pop), not the team count. Rollback: 8.
		//--- (3) low/mid-pop PC-scaled base founding target (DELTA -1 then FLOOR/hard-cap clamp still apply): keep the
		//--- base under the new hard cap so the curve, not just the clamp, sets team count. LOW 6-1=5, MID 5-1=4.
		WFBE_C_AICOM_TEAMS_PC_LOW  = 17;               //--- ZG (owner 2026-07-26, was 9 -> LOW 17-1=16). Rollback: 9.
		WFBE_C_AICOM_TEAMS_PC_MID  = 17;               //--- ZG (owner 2026-07-26, was 7 -> MID 17-1=16). Rollback: 7.
		//--- (4) GARRISON CONSOLIDATION (WEST/EAST only): fuse town-garrison infantry into ~9-unit group-brains
		//--- (was 5) so a defended town spawns the SAME units in FEWER server groups (fps win, gameplay-transparent;
		//--- vehicles never merged; town DEFENSE strength unchanged). The GUER (defender) merge target + cap are the
		//--- separate WFBE_C_TOWNS_MERGE_*_DEFENDER constants and are DELIBERATELY NOT touched (no GUER nerf).
		WFBE_C_TOWNS_MERGE_TARGET = 9;                 //--- ZG (was 5, capped at the global 10 in Server_GetTownGroups). Rollback: 5.
		//--- (5) ALIVE MANDATE - stale-team recycling. Halve the disband-pass interval so idle, REAR, foot-infantry
		//--- teams (never in-view, never in combat - the existing safety re-checks in AI_Commander_DisbandLowTier.sqf
		//--- + Common_RunCommanderTeam.sqf stand them back up if a player nears) are retired 2x faster; the freed
		//--- founding budget refounds at the front via the founding gate + maneuver brain. SAME bounded population,
		//--- MORE of it actively fighting instead of sitting stale in the rear. FLOOR 2->1 lets the short ZG rear
		//--- recycle one more idle foot team. This wires through the EXISTING disband machinery - no new system.
		WFBE_C_AICOM_DISBAND_INTERVAL = 150;           //--- ZG (was 300s). Rollback: 300.
		WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR = 1;       //--- ZG (was 2). Rollback: 2.
		//--- ALWAYS-ON init telemetry: log the resolved ZG governor caps ONCE at init so the next soak can verify the
		//--- pack loaded (diag_log, ungated). Mirrors the AICOMSTAT|v2 pipe-KV shape the soak analyzer already parses.
		diag_log ("AICOMSTAT|v2|EVENT|ZG|0|ALIVEPOP_INIT|capAI=" + str WFBE_C_TOTAL_AI_MAX_BY_TIER + "|capTeams=" + str WFBE_C_AICOM_TEAMS_HARD_CAP + "|pcLow=" + str WFBE_C_AICOM_TEAMS_PC_LOW + "|pcMid=" + str WFBE_C_AICOM_TEAMS_PC_MID + "|merge=" + str WFBE_C_TOWNS_MERGE_TARGET + "|disbandInt=" + str WFBE_C_AICOM_DISBAND_INTERVAL + "|infFloor=" + str WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR);
	};
//--- End ZG-FIX zg-alive-population Zargabad-scoped governor overrides.
	if (isServer) then { diag_log ("GARRISON|v1|merge=" + str WFBE_C_TOWNS_MERGE_TARGET + "|mergeCap=" + str WFBE_C_TOWNS_MERGE_CAP + "|mergeDef=" + str WFBE_C_TOWNS_MERGE_TARGET_DEFENDER + "|mergeCapDef=" + str WFBE_C_TOWNS_MERGE_CAP_DEFENDER + "|headroom=" + str WFBE_C_TOWNS_MERGE_HEADROOM + "|map=" + worldName); }; //--- task wasp-garrison-mergeup-20260722: soak-attributable one-shot stamp of the live merged town-garrison group target/cap (joint GARRISON|v1| family with #1266 scale= stamp).
};

// --- Player stats (feature-flagged) ---
//--- B74.1 (Ray 2026-06-23 "get the real leaderboard in"): ENABLED. Unlocks the WASPSTAT|v1 RPT
//--- emit (StatsFlush.sqf, batched every 60s) that feeds the miksuu.com leaderboard ingest pipeline
//--- (box poster -> /api/stats -> ingame_stats -> /leaderboard). Currently WIRED fields: kills
//--- infantry/vehicle/air/static (RequestOnUnitKilled), pvp_kills, playtime, side. Captures/supply/
//--- builds/deaths/factory/hq RecordStat call sites are NOT yet wired (emit 0) - fast-follow b74.2.
//--- AICOM V2 Lane 800: GUER Director (virtual resistance ledger + lightweight brain).
//--- Lane switch default 0 = inert (the documented exception to the lanes-default-1 rule).
	if (isNil "AICOMV2_LANE_GUER_DIRECTOR")         then {AICOMV2_LANE_GUER_DIRECTOR = 1};         //--- Lane 800 switch: 0=OFF (byte-identical to V1), 1=Director active.
	if (isNil "AICOMV2_GDIR_TICK_SEC")              then {AICOMV2_GDIR_TICK_SEC = 30};             //--- Brain tick interval (s).
	if (isNil "AICOMV2_GDIR_REGEN_FULL_SEC")        then {AICOMV2_GDIR_REGEN_FULL_SEC = 1800};    //--- Seconds for wiped garrison to regen to baseline with no reinforcement.
	if (isNil "AICOMV2_GDIR_SURGE_MAX")             then {AICOMV2_GDIR_SURGE_MAX = 1.0};           //--- Autonomous materialised strength cap vs V1 baseline per town (1.0 = never above V1).
	if (isNil "AICOMV2_GDIR_PAID_SURGE_MAX")        then {AICOMV2_GDIR_PAID_SURGE_MAX = 1.5};     //--- Funded-order cap (Amendment A1 Commissar Panel; panel switch default 0 = off).
	if (isNil "AICOMV2_GDIR_GROUP_BUDGET_MAX")      then {AICOMV2_GDIR_GROUP_BUDGET_MAX = 110};   //--- GUER-side group ceiling for the materialiser (144 engine hard cap).
	if (isNil "AICOMV2_GDIR_MIN_SPAWN_M")           then {AICOMV2_GDIR_MIN_SPAWN_M = 400};        //--- Minimum distance from any player for materialisation.
	if (isNil "AICOMV2_GDIR_AMBUSH_BUBBLE_M")       then {AICOMV2_GDIR_AMBUSH_BUBBLE_M = 700};   //--- Route-point bubble radius for ambush-cell materialisation.
	if (isNil "AICOMV2_GDIR_CELL_SPEED_MS") then {
		AICOMV2_GDIR_CELL_SPEED_MS = 8; //--- Virtual ground speed for cell movement (m/s).
		AICOMV2_GDIR_CELL_SPEED_MS_OWNER_SET = false;
	} else {
		if (isNil "AICOMV2_GDIR_CELL_SPEED_MS_OWNER_SET") then {AICOMV2_GDIR_CELL_SPEED_MS_OWNER_SET = true};
	};
	if (isNil "AICOMV2_GDIR_SUPPRESS_SEC")          then {AICOMV2_GDIR_SUPPRESS_SEC = 600};       //--- Post-wipe offensive-suppression window (s).
	if (isNil "AICOMV2_GDIR_SUPPRESS_WIRE")         then {AICOMV2_GDIR_SUPPRESS_WIRE = 0};         //--- 1 = wire the post-wipe suppression: on contact-end stamp ledger[4]=diag_tickTime+AICOMV2_GDIR_SUPPRESS_SEC so PHASE-3 defers reinforcement during the window. Default 0 keeps legacy always-eligible behaviour byte-identical. SOAK before arming.
	if (isNil "AICOMV2_GDIR_RETAKE")                then {AICOMV2_GDIR_RETAKE = 0};               //--- Retake-cell aggression: 0=off, 1=low. Default 0 CH; TK profile may set 1.
	if (isNil "AICOMV2_GDIR_PLAYER_SUPPORT")        then {AICOMV2_GDIR_PLAYER_SUPPORT = 0};       //--- Bias cells toward human GUER players (0=off).
//--- Amendment A2: Air-Contact Activation Tier dials (folded under AICOMV2_LANE_GUER_DIRECTOR gate).
	if (isNil "AICOMV2_GDIR_AIR_CEILING_MIN_M")     then {AICOMV2_GDIR_AIR_CEILING_MIN_M = 100}; //--- Air below this m ALWAYS activates the AA tier on each sweep.
	if (isNil "AICOMV2_GDIR_AIR_CEILING_MAX_M")     then {AICOMV2_GDIR_AIR_CEILING_MAX_M = 600}; //--- Air above this m NEVER activates the AA tier.
//--- Amendment A1: Player Commissar Panel dials (panel switch AICOMV2_GDIR_PANEL default 0).
	if (isNil "AICOMV2_GDIR_PANEL")                 then {AICOMV2_GDIR_PANEL = 1};               //--- A1 Commissar Panel gate: 0=off (byte-identical). Requires AICOMV2_LANE_GUER_DIRECTOR=1.
	if (isNil "AICOMV2_GDIR_PANEL_COOLDOWN_SEC")    then {AICOMV2_GDIR_PANEL_COOLDOWN_SEC = 180};//--- Per-town action cooldown (s) between panel buys. 600 -> 180 owner ruling 2026-07-27 (GUER town-defence purchases were too slow to matter). Read by BOTH the client display (GUI_Menu_GuerCommissar.sqf:354) and the server-authoritative check (RequestGDirPanel.sqf:241), so one value covers both. Rollback: 600.
	if (isNil "AICOMV2_GDIR_PANEL_CONTRACTS_MAX")   then {AICOMV2_GDIR_PANEL_CONTRACTS_MAX = 2}; //--- Max active contracts per town simultaneously.
	if (isNil "AICOMV2_GDIR_PANEL_INSTANT_MULT")    then {AICOMV2_GDIR_PANEL_INSTANT_MULT = 1.5};//--- Price multiplier for instant delivery vs convoy.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_REINF")     then {AICOMV2_GDIR_PANEL_PRICE_REINF = 1600}; //--- Base price: Action 1 convoy reinforcement.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_QRF_INS")   then {AICOMV2_GDIR_PANEL_PRICE_QRF_INS = 1200};  //--- Base price: Action 2 QRF insert tier.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_QRF_GUN")   then {AICOMV2_GDIR_PANEL_PRICE_QRF_GUN = 2400}; //--- Base price: Action 2 QRF gunship tier.
	if (isNil "WFBE_C_GDIR_QRF_AIRFRAME_POOL") then {WFBE_C_GDIR_QRF_AIRFRAME_POOL = 0}; //--- 1 = roll QRF gunship class from GDIR_QRF_GUNSHIP_POOL instead of hardcoded Mi24_P (RPT-DEEPDIVE-20260730: 174/174 Mi24_P). 0 = dark legacy Mi24_P only.
	if (isNil "WFBE_C_GDIR_QRF_GUNSHIP_POOL") then {WFBE_C_GDIR_QRF_GUNSHIP_POOL = ["Mi24_P","Ka60_GL_PMC","Ka60_PMC"]}; //--- classnames eligible when AIRFRAME_POOL=1; invalid/missing CfgVehicles entries skipped at fire time.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_CTR_ATK")   then {AICOMV2_GDIR_PANEL_PRICE_CTR_ATK = 1000};  //--- Base price: Action 3 counter-attack contract.
	if (isNil "AICOMV2_GDIR_PANEL_SCARCITY_STEP")   then {AICOMV2_GDIR_PANEL_SCARCITY_STEP = 0.2};  //--- Scarcity multiplier step per recent buy on same town.
	if (isNil "AICOMV2_GDIR_PANEL_SCARCITY_DECAY")  then {AICOMV2_GDIR_PANEL_SCARCITY_DECAY = 120}; //--- Seconds for scarcity to decay one step back toward 1.0.
	if (isNil "AICOMV2_GDIR_PANEL_LF_MIN")          then {AICOMV2_GDIR_PANEL_LF_MIN = 1.0};          //--- loadFactor floor (healthy server).
	if (isNil "AICOMV2_GDIR_PANEL_LF_MAX")          then {AICOMV2_GDIR_PANEL_LF_MAX = 2.5};          //--- loadFactor ceiling (stressed server).
//--- Amendment: Hardening + Shop (fable/gdir-harden-shop).
//--- P1 - Movement ETA-timeout: cells stuck past ETA teleport-merge into destination town.
	if (isNil "AICOMV2_GDIR_HARDEN")                 then {AICOMV2_GDIR_HARDEN = 1};                //--- Master switch: 0=off (P1/P2 inert), 1=hardening active.
	if (isNil "AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR") then {
		AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR = 3; //--- ETA safety factor: ETA = (dist/CELL_SPEED_MS)*factor seconds.
		AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR_OWNER_SET = false;
	} else {
		if (isNil "AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR_OWNER_SET") then {AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR_OWNER_SET = true};
	};
//--- P5/P6 salvage: both additions are default-off; an enabled map profile never replaces an explicit owner dial.
	if (isNil "AICOMV2_GDIR_MAP_PROFILE")            then {AICOMV2_GDIR_MAP_PROFILE = 0};            //--- 1 = enable per-world Director profile only where a dial remains at its registered default.
	if (isNil "AICOMV2_GDIR_AICOM_HOOK")             then {AICOMV2_GDIR_AICOM_HOOK = 0};             //--- 1 = read-only WEST/EAST occupier snapshots for bounded Director coordination.
//--- P2 - JIP PV snapshot: compact ledger snapshot pushed to late joiners.
	if (isNil "AICOMV2_GDIR_JIP_SNAP_INTERVAL")      then {AICOMV2_GDIR_JIP_SNAP_INTERVAL = 60};   //--- Min seconds between snapshot rebroadcasts (throttle).
//--- P3 - Weapons cache: per-town purchasable loadout tier for town defenders.
	if (isNil "AICOMV2_GDIR_CACHE")                  then {AICOMV2_GDIR_CACHE = 1};                 //--- fable/gdir-cache-materializer (GR-2026-07-08a): 1=on - loadout-apply hook now lives in Common_CreateTownUnits.sqf (per-unit forEach right after the town-defender skill spread, guarded on _side==WFBE_DEFENDER); reads this town's AICOMV2_GDIR_CACHE_TIER. Flipped from the 0-default now the upgrade is real.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_CACHE_T1")   then {AICOMV2_GDIR_PANEL_PRICE_CACHE_T1 = 3200}; //--- Base price: cache tier 1 (AK+RPK mix + extra mags). 2x doubled base.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_CACHE_T2")   then {AICOMV2_GDIR_PANEL_PRICE_CACHE_T2 = 6400}; //--- Base price: cache tier 2 (+RPG-7V gunners). 2x doubled base.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_CACHE_T3")   then {AICOMV2_GDIR_PANEL_PRICE_CACHE_T3 = 9600}; //--- Base price: cache tier 3 (+Strela defender). 2x doubled base.
	//--- P5 - Defensive vehicle (fable/gdir-vehicle-verb, GR-2026-07-08a): town-donate-fund purchase
	//--- of ONE tier-scaled defensive vehicle, delivered on the town's next garrison
	//--- spawn/regrow (materialiser in Common_CreateTownUnits.sqf, same hook as the weapons
	//--- cache). [FIX-931/night-sweep] Default OFF (was 1): the "Default ON, matching the
	//--- cache verb's precedent" claim was false - AICOMV2_GDIR_CACHE itself defaults to 0
	//--- (this file, ~line 2001) until its own hook lands. The GUI buttons (Rsc/Dialogs.hpp
	//--- idc 31081-83) also compile unconditionally and can't be config-gated on a runtime
	//--- var in A2 OA 1.64, so this default is the ONLY true inertness lever - see
	//--- GUI_Menu_GuerCommissar.sqf for the client-side ctrlShow/ctrlEnable + MenuAction
	//--- gate added alongside this fix.
	if (isNil "AICOMV2_GDIR_VEHICLE")                then {AICOMV2_GDIR_VEHICLE = 0};                 //--- Defensive vehicle gate. Default OFF - see comment above (FIX-931).
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T1") then {AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T1 = 4800}; //--- Base price: vehicle tier 1 (Offroad_DSHKM_Gue technical). 1.5x cache T1 (unilateral pricing call - see PR body).
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T2") then {AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T2 = 9600}; //--- Base price: vehicle tier 2 (BMP2_GUE). 1.5x cache T2.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T3") then {AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T3 = 14400}; //--- Base price: vehicle tier 3 (T72_GUE). 1.5x cache T3.
//--- P4 - Relief squad (AICOMV2_GDIR_PANEL gate). Mortar price/cooldown constants REMOVED (verb retired - see RequestGDirPanel.sqf).
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_RELIEF")     then {AICOMV2_GDIR_PANEL_PRICE_RELIEF = 800};  //--- Base price: relief squad (infantry-only fast buy). 1/2x of REINF base.
	if (isNil "WFBE_C_GDIR_GARRISON_GAIN") then {WFBE_C_GDIR_GARRISON_GAIN = 1}; //--- owner 2026-07-07: ARMED at 1.0 (Director-reinforced GUER towns wake with +~50% real garrison at max funded surge; floored at V1).
	if (isNil "WFBE_C_GUER_PRESENCE_PULSE") then {WFBE_C_GUER_PRESENCE_PULSE = 0}; //--- Grok idea #15 (2026-07-25): PLACEMENT ONLY. Biases the Director's QRF materialization spawn onto the ring (AICOMV2_GDIR_MIN_SPAWN_M..AICOMV2_GDIR_AMBUSH_BUBBLE_M) between the contact town and the nearest other GUER/unknown ledger town, instead of directly over the town center where fresh contact already means players are standing. Does NOT change GUER volume/budget/cooldown - see AICOMV2_GDIR_GROUP_BUDGET_MAX / WFBE_C_GUER_GROUPS_MAX (PR #1372 restoration pending) for that axis. 0 = byte-identical to HEAD.
	if (isNil "WFBE_C_GARRISON_SV_SCALE") then {WFBE_C_GARRISON_SV_SCALE = 0};       //--- fable/garrison-sv-scale (backlog #14): >0 arms supply-value garrison scaling in Server_GetTownGroupsDefender.sqf - a town holding MORE supply than its startingSupplyValue fields a proportionally bigger defender garrison (bonus = (sv/start - 1) * this scale, capped at MAXBONUS). ADDITIVE-ONLY: never reduces a garrison (no-GUER-nerf). 0 = off, byte-identical.
	if (isNil "WFBE_C_GARRISON_SV_MAXBONUS") then {WFBE_C_GARRISON_SV_MAXBONUS = 0.5}; //--- cap on the sv-scaling garrison bonus (+50% groups max).
	if (isNil "WFBE_C_TOWN_GARRISON_SCALE") then {WFBE_C_TOWN_GARRISON_SCALE = 0.7}; //--- owner 2026-07-22 18:52 (task wasp-town-garrison-minus20): BASE GUER town-defender garrison scale. 0.8 = -20% (entice player reinforcement + free AI budget for A-life); 1.0 = legacy/byte-identical. Applied in Server_GetTownGroupsDefender.sqf to the post-difficulty-coef base group count, BEFORE the GDIR surge and CTL-link overlays (both stack on / derive from the scaled base). Floored at 1 group. [Ray-dir 2026-07-24 AI-COUNT: 0.8->0.7 - deepen the GUER town-defender cut to -30% (AI-count is the profiler-confirmed #1 fps driver: fps 12@445 units vs 40+@300); rollback 0.8.]
	if (isNil "WFBE_C_TOWN_GARRISON_SCALE_WE") then {WFBE_C_TOWN_GARRISON_SCALE_WE = 0.7}; //--- Ray-dir 2026-07-24: extend the town-defender garrison cut to the CONVENTIONAL sides. Scales WEST/EAST-owned town garrisons (Server_GetTownGroups.sqf) by this factor, applied to the post-units-coef base BEFORE the CTL ledger overlay, floored at 1 - mirrors the GUER WFBE_C_TOWN_GARRISON_SCALE (defender path). 0.7 = -30%; 1.0 = legacy/byte-identical.
	if (isNil "WFBE_C_TOWNS_TAB_GARRISON") then {WFBE_C_TOWNS_TAB_GARRISON = 1}; //--- ARMED 2026-07-28 (owner "The towns button is not working for Blufor / Opfor"): 1 = the built read-only own-side garrison view (GUI_Menu_TownsGarrison.sqf) opens for ALL sides. At 0 the button was a hint-only dead end for WEST/EAST and the panel was unreachable dead code. GUER keeps its Commissar panel via the resistance branch. Rollback: 0.
	if (isNil "WFBE_C_TOWNS_PERIMETER") then {WFBE_C_TOWNS_PERIMETER = 1}; //--- owner 2026-07-07: town defenders spawn in a bearing-even ring at the town EDGE (0.70-0.95x range) instead of camp/center clusters. 0 = legacy. //--- Tier-1 ledger->real-garrison gain: 0=off (byte-identical). >0 = a Director-reinforced GUER town (wfbe_gdir_str ratio>1) wakes with +min(groups, round(groups*(ratio-1)*GAIN)) real defender groups, floored at V1 (no-nerf). ~1.0 => +50% at max funded surge (ratio 1.5).
//--- End AICOM V2 Lane 800 constants.
if (isNil "WFBE_C_GUER_LOCKOUT_MIN") then {WFBE_C_GUER_LOCKOUT_MIN = 0}; //--- fable/guer-lockout (owner 2026-07-07, re-confirmed pick A4 2026-07-08): GUER activation delay in MINUTES; Parameters.hpp default=0 MUST stay in sync; 0 = off. Gates: respawn-timer clamp (GUI_RespawnMenu), WF-menu buy/gear/TownActions (GUI_Menu), start-confine (Client_GuerLockout.sqf).

WFBE_C_STATS_ENABLED = true;
WFBE_C_STATS_FLUSH_INTERVAL = 60;
WFBE_STAT_KILLS_INFANTRY   = 0;
WFBE_STAT_KILLS_VEHICLE    = 1;
WFBE_STAT_KILLS_AIR        = 2;
WFBE_STAT_KILLS_STATIC     = 3;
WFBE_STAT_KILLS_FACTORY    = 4;
WFBE_STAT_KILLS_HQ         = 5;
WFBE_STAT_DEATHS           = 6;
WFBE_STAT_PVP_KILLS        = 7;
WFBE_STAT_SUPPLY_RUNS      = 8;
WFBE_STAT_SUPPLY_VALUE     = 9;
WFBE_STAT_CAPTURES_TOWN    = 10;
WFBE_STAT_CAPTURES_CAMP    = 11;
WFBE_STAT_STRUCTURES_BUILT = 12;
WFBE_STAT_DEFENSES_BUILT   = 13;
WFBE_STAT_PLAYTIME         = 14;
WFBE_STAT_FIELD_COUNT      = 15;
WFBE_STATS_DIRTY_UIDS = [];

//--- NAVAL HVT OBJECTIVES (feat/naval-hvt-objectives)
//--- Master gate: set to 0 to fully disable all naval HVT content (no objects, no logic, no CAP, no SCUD).
//--- Default 1 for testing; flip to 0 for a byte-for-byte vanilla session.
	if (isNil "WFBE_C_NAVAL_HVT") then {WFBE_C_NAVAL_HVT = 1};

//--- SCUD Strike tunables (oil-platform payoff).
	if (isNil "WFBE_C_SCUD_COST")     then {WFBE_C_SCUD_COST     = 25000};	//--- server-validated funds cost
	if (isNil "WFBE_C_SCUD_COOLDOWN") then {WFBE_C_SCUD_COOLDOWN = 300};	//--- per-platform cooldown (s)
	if (isNil "WFBE_C_SCUD_ZONE_RADIUS") then {WFBE_C_SCUD_ZONE_RADIUS = 300};	//--- target acquisition radius (m)

//--- SCUD warhead constants (confirmed mission ammo classes — do NOT change without RPT verification).
//--- NEEDS REVIEW: Sh_125_HE confirmed in A2/OA artillery configs; Bo_GBU12_LGB confirmed in drone-strike.
//--- Verify both createVehicle in RPT on first live test; substitute if "class not found" appears.
	WFBE_C_SCUD_WARHEAD_HE    = "Sh_125_HE";		//--- HE area burst (even-phase warheads)
	WFBE_C_SCUD_WARHEAD_SADARM = "Bo_GBU12_LGB";	//--- Top-attack precision (odd-phase warheads)
	WFBE_C_SCUD_WARHEAD_WP    = "SmokeShellWhite";	//--- WP/incendiary smoke layer (final phase)

//======================================================================================
//--- FACTORY WALL SLABS v3 (cmdcon43-c) + DEFENSES/FORTIFICATIONS MENU REDO (cmdcon42-g)
//--- Each feature is behind ONE flag so Ray can revert it independently.
//--- The LEGACY arrays stay UNTOUCHED in their files; the flag SELECTS the variant vs legacy.
//======================================================================================

//--- WALLS v2 (factory wall-MATERIAL ladder, cmdcon42-g). REVERTED in Build 88 (cmdcon43-c):
//--- Ray asked to undo the bagfence/HESCO/concrete material swap and instead keep the ORIGINAL
//--- walls + add concrete slabs (see WFBE_C_WALLS_V3 below). The *_WALLS_V2 factory arrays are
//--- WALLS v3 (factory ORIGINAL walls + HQ-style concrete SLABS, cmdcon43-c). Ray Build 88:
//--- "revert the factory wall changes, and then just add additional concrete slabs to them like
//--- the HQ has for survivability". 1 = each factory keeps its exact legacy walls AND gets an added
//--- ring/backing layer of Concrete_Wall_EP1 slabs (the same near-indestructible class the HQ funnel
//--- uses, WFBE_NEURODEF_HEADQUARTERS_WALLS); vehicle factories keep their +X egress face open.
//--- 0 = exact original legacy walls, NO slabs.
//--- REVERSIBILITY: set to 0 -> Construction_*Site.sqf read the plain legacy WFBE_NEURODEF_<TYPE>_WALLS
//--- (the *_WALLS_V3 arrays are only ever appended to; the legacy arrays are never edited). No deletions.
	if (isNil "WFBE_C_WALLS_V3") then {WFBE_C_WALLS_V3 = 1};

//--- DEFENSES/FORTIFICATIONS MENU v2. 1 = redone data-driven lists (dead entries pruned,
//--- recategorised, gap-fill items added: watchtower, cheaper WEST AT, hedgehog line, flak tower);
//--- 0 = exact legacy menu (legacy WFBE_<SIDE>DEFENSENAMES + legacy Core_*.sqf price/category rows).
//--- REVERSIBILITY: set to 0 -> Structures_CO_*.sqf register the legacy names list and
//--- Core_*.sqf register the legacy per-class data arrays. Legacy arrays left in place, untouched.
	if (isNil "WFBE_C_DEFMENU_V2") then {WFBE_C_DEFMENU_V2 = 1};

//--- FLAK TOWER sub-flag (elevated AA static + AI gunner on a tower deck). Independent of the
//--- menu flag so the physics-fragile roof-mount item can be pulled without reverting the menu.
//--- Only honoured when WFBE_C_DEFMENU_V2 == 1. 1 = flak tower buyable; 0 = flak tower hidden.
	if (isNil "WFBE_C_DEF_FLAKTOWER") then {WFBE_C_DEF_FLAKTOWER = 1};

//--- cmdcon44-c (Build 89, Ray 2026-07-03): FLAK TOWER — THIN TALL TOWER. Ray refined ask (item 35):
//--- "isnt there like a thinner tall tower? like one of the light towers or something". cmdcon44-a had
//--- shipped the airfield control tower (Land_Mil_ControlTower) — tall but a bulky boxy structure, not
//--- what Ray pictured. Swap it for the thin lattice FLOODLIGHT tower, which is exactly "one of the light
//--- towers": Land_Ind_IlluminantTower (displayName "Illuminant Tower", the sawmill light mast). The host
//--- structure + deck height stay flag-driven (read once by Init_Defenses.sqf when it builds
//--- WFBE_NEURODEF_FLAKTOWER_*), so both are retunable on the box WITHOUT a code change or CH->TK re-mirror.
//---
//---   WFBE_C_DEF_FLAKTOWER_STRUCTURE = host classname. DEFAULT = "Land_Ind_IlluminantTower"
//---     (thin lattice floodlight tower; mapSize=2 => ~2 m footprint = the "thinner tall tower" Ray wants).
//---     CLASSNAME CONFIRMED against the rayswaynl/arma2-co-config-reference CfgVehicles catalog
//---     (class Land_Ind_IlluminantTower : House, model \CA\Structures\Ind_SawMill\Ind_IlluminantTower),
//---     and it is ALREADY spawned live in this mission (Init_Defenses.sqf BANK_WEST/EAST centrepiece +
//---     legacy RESERVE) => proven to load on BOTH maps under Combined Operations. It is an A2 base class
//---     (no _EP1 form) — do not append _EP1.
//---   WFBE_C_DEF_FLAKTOWER_DECK_Z = FALLBACK deck z-offset the AA gun is lifted to, used ONLY if the
//---     auto-measure below is disabled or fails. DEFAULT 17.0 (documented estimate of the illuminant
//---     tower's top light-platform; NO empirical in-repo height existed, so it is measured at runtime).
//---   WFBE_C_DEF_FLAKTOWER_AUTOZ = 1 (default): Server_ConstructPosition.sqf measures the just-spawned
//---     host tower's REAL top via boundingBox and mounts the gun there (self-correcting, no magic number).
//---     This mirrors the Init_NavalHVT.sqf B754 idiom (Ray replaced a hardcoded carrier-deck "16 guess"
//---     with a boundingBox measurement; boundingBox is A2-OA 1.64-safe). Set 0 to force the fixed DECK_Z.
//---
//--- Gunner: seated via moveInGunner (Server_HandleDefense) — teleports to the turret at any height, no
//--- walk/ladder, and the static gunner stays ALWAYS-ACTIVE (no sim/distance gating — standing HARD rule).
//--- Static-on-lattice is physics-fragile in A2 (settle/jitter) -> NEEDS-BOX-VERIFY the gun sits stable on
//--- the platform. RAY-DECISION / MVP FALLBACKS if the light-tower mount misbehaves on the box:
//---   * bunker MVP (rock-solid, short): STRUCTURE="Land_fortified_nest_big_EP1" + DECK_Z=2.7 + AUTOZ=0
//---   * airfield control tower (tall, boxy): STRUCTURE="Land_Mil_ControlTower" + DECK_Z=12.5
//---   * original watchtower: STRUCTURE="Land_Fort_Watchtower_EP1" + DECK_Z=5.4 + AUTOZ=0
	if (isNil "WFBE_C_DEF_FLAKTOWER_STRUCTURE") then {WFBE_C_DEF_FLAKTOWER_STRUCTURE = "Land_Ind_IlluminantTower"};
	if (isNil "WFBE_C_DEF_FLAKTOWER_DECK_Z") then {WFBE_C_DEF_FLAKTOWER_DECK_Z = 20.8}; //--- cmdcon45 (Ray 2026-07-04 -12% nudge): 23.7 rig top * 0.88 ~= 20.8 (non-AUTOZ fallback matches the trimmed AUTOZ deck).
	if (isNil "WFBE_C_DEF_FLAKTOWER_AUTOZ") then {WFBE_C_DEF_FLAKTOWER_AUTOZ = 1};
	//--- cmdcon45 (Ray 2026-07-04 nudge order): trim factor multiplied against the boundingBox-MEASURED full illuminant-mast
	//--- height in Server_ConstructPosition.sqf (AUTOZ path). Ray asked the flak gun "nudged down 10-15%"; 0.88 = ~12% down
	//--- (mid of the range), 23.66m measured -> ~20.8m deck so the gun sits on the platform instead of slightly above it.
	if (isNil "WFBE_C_DEF_FLAKTOWER_DECK_FACTOR") then {WFBE_C_DEF_FLAKTOWER_DECK_FACTOR = 0.88};

//--- cmdcon44-a (Build 89, Ray 2026-07-03): AA / ARTILLERY / MIXED POSITIONS REWORK. Ray: "Defenses list
//--- has not changed, AA/Art/Mix positions are still the same." The Build 88 DEFMENU_V2 pass deliberately
//--- left the six WDDM AA/Art/Mix positions unchanged (docs\design\BASE-COMPOSITIONS-PROPOSAL.md B.2 marked
//--- them "keep"); it only pruned dead rows and added watchtower/hedgehog/flak. This flag turns ON a genuinely
//--- reworked set of those six composition arrays (Init_Defenses.sqf: beefier weapons + tighter interlocking
//--- layouts + relabelled menu rows in Core_CIV.sqf). 1 = reworked positions + labels; 0 = exact legacy
//--- positions + labels (both the legacy compositions and the legacy Core_CIV labels are left intact).
//--- NOTE: the definitive AA/Art/Mix content is a Ray design call — the shipped set is a first proposal.
	if (isNil "WFBE_C_DEFMENU_V2_POSITIONS") then {WFBE_C_DEFMENU_V2_POSITIONS = 1};

//--- BANK MODEL v2 (proposal part C, Ray-approved Build 87). 1 = the Bank/Reserve income
//--- objective uses the office building Land_A_Office01_EP1 (reads as "money lives here");
//--- 0 = exact legacy bunker Land_fortified_nest_big_EP1. ONLY the Bank structure model swaps —
//--- WFBE_C_DEPOT (towns) and the small Reserve nest are left as-is. Bank logic keys on the
//--- 'Bank' rlType TAG (not the classname), so income/registry/kill-handling are model-agnostic.
//--- REVERSIBILITY: set to 0 -> Structures_CO_*.sqf register the legacy bunker model + BANK anchor.
//--- NEEDS-BOX-VERIFY: footprint/door clearance vs the v2 raid-gate ring (first boot-smoke: place a
//--- bank on BOTH maps and eyeball clearance). Fallbacks if the office fails the box check:
//--- Land_Mil_Guardhouse_EP1 (~8x8 blockhouse) or Land_Ind_Garage01_EP1 (~14x8 depot). To use a
//--- fallback, change WFBE_C_BANK_MODEL_V2_CLASS below — the selection reads this one string.
	if (isNil "WFBE_C_BANK_MODEL_V2") then {WFBE_C_BANK_MODEL_V2 = 1};
	if (isNil "WFBE_C_BANK_MODEL_V2_CLASS") then {WFBE_C_BANK_MODEL_V2_CLASS = "Land_A_Office01_EP1"};

//======================================================================================
//--- cmdcon43-g (Ray 2026-07-02): FACTORY UPGRADE SOUND MODE
//--- Ray on Build 87/88: the factory/structure UPGRADE audio cues are too intrusive; he is
//--- leaning "keep but unobtrusive". This single MODE flag governs the two upgrade-flow
//--- playSound call sites in Client\Functions\Client_FNC_Special.sqf (upgrade STARTED +
//--- upgrade COMPLETE). No other notification sound (arty cooldown for artillery itself,
//--- commander notifications, victory music, SCUD voice lines) is touched - only the
//--- upgrade-flow call sites read this flag.
//---   0 = SILENT   - no upgrade sound at all.
//---   1 = LEGACY   - the historical sounds at their historical volume (upgrade-start =
//---                  "upgradeStartedSound" [now a real registered class, aliasing
//---                  commanderNotification's ogg per the long-standing code comment];
//---                  upgrade-complete = "ARTY_cooldown_over", the shared 4.1s cooldown chime).
//---   2 = QUIET    - the SAME two ogg files replayed through parallel low-volume CfgSounds
//---                  classes (WFBE_UpgradeStart_Quiet / WFBE_UpgradeComplete_Quiet in
//---                  Sounds\description.ext) - ~12 dB down, no new audio files, zero pbo cost.
//--- DEFAULT = 2 (quiet). Flip to 0 for full silence or 1 to restore the loud legacy cue.
//--- Read idiom at the call sites: missionNamespace getVariable ["WFBE_C_UPGRADE_SOUNDS", 2].
	if (isNil "WFBE_C_UPGRADE_SOUNDS") then {WFBE_C_UPGRADE_SOUNDS = 2};

//======================================================================================
//--- RESPAWN UI V2 (fable/respawn-ui-v2): master flag + tunables.
//--- WFBE_C_RESPAWN_UI_V2 = 1  → all v2 improvements active (type-tags, safety colors,
//---   leader marker, distance, tighter zoom, legend, clearer gear toggle, last-spawn memory).
//--- WFBE_C_RESPAWN_UI_V2 = 0  → byte-identical legacy respawn screen; set to revert.
//======================================================================================
	if (isNil "WFBE_C_RESPAWN_UI_V2") then {WFBE_C_RESPAWN_UI_V2 = 1};

//--- Map zoom level when the respawn menu first opens (ctrlMapAnimAdd zoom arg).
//--- Smaller = tighter / more zoomed-in. Default 0.03 (was 0.095 legacy).
//--- Set WFBE_C_RESPAWN_UI_V2 = 0 to restore the old 0.095 zoom.
	if (isNil "WFBE_C_RESPAWN_MAP_ZOOM") then {WFBE_C_RESPAWN_MAP_ZOOM = 0.03};

//--- Radius (metres) within which an enemy-held town makes a spawn point "contested"
//--- (amber marker instead of green). Tunable; only used when WFBE_C_RESPAWN_UI_V2 = 1.
	if (isNil "WFBE_C_RESPAWN_CONTESTED_RADIUS") then {WFBE_C_RESPAWN_CONTESTED_RADIUS = 500};

//--- salvage-522 / Lane 193: reset unitQueu (and per-factory queue slots) to 0 on player respawn
//--- (Client_PreRespawnHandler.sqf) so the factory-queue cap counter cannot accumulate across deaths.
//--- Default 0 (dark). Set 1 to activate the reset. The Client_BuildUnit.sqf decrements are `max 0`-clamped
//--- (salvage-522) so an in-flight buy that resolves after a reset clamps to 0 instead of going negative.

//--- fable/respawn-menu-shortcuts (owner 2026-07-09): two respawn-menu buttons that open the
//--- existing Team Menu (RscMenu_TeamV2, idd 13050) - Gear Presets / Unit Designer tabs.
//--- Pure UI convenience wiring into an already-shipped dialog (GUI_Menu_TeamV2.sqf); no new
//--- game logic. Default 0 = byte-identical legacy respawn screen (buttons hidden via
//--- `show=0`, minimap geometry untouched). See docs/design/v2/TEAM-MENU-REPURPOSE-PROPOSAL-2026-07-07.md
//--- for the Unit Designer / Gear Presets feature inventory this reuses.
	if (isNil "WFBE_C_RESPAWN_SHORTCUTS") then {WFBE_C_RESPAWN_SHORTCUTS = 1}; //--- owner 2026-07-09: ACTIVATED - respawn-screen Team-Menu shortcuts (Customise AI Soldier + Saved Kits) + trimmed minimap (GUI_RespawnMenu.sqf:47-57)

//--- DEADSPAWN NO-ARMED-UNITS GUARD (fable/deadspawn-guard, Ray 2026-07-04): while a dead AI team
//--- leader is parked on its %1TempRespawnMarker holding point during the respawn wait
//--- (AI_AdvancedRespawn.sqf / AI_SquadRespawn.sqf), make the body non-hostile + unkillable
//--- (setCaptive true + allowDamage false) so no ARMED unit sits in the deadspawn ring: it can
//--- neither fire on nor be targeted by an enemy-side bot parked on an adjacent marker (the Smarty
//--- "AI killed <player> in the deadspawn" kill), and stray fire cannot kill it there. Restored to
//--- setCaptive false + allowDamage true the instant it leaves the marker for its real respawn.
//--- Same allowDamage/setCaptive rationale as WFBE_HC_FNC_ParkDeadspawn (Init_HC.sqf). 1 = guard on
//--- (default), 0 = legacy behaviour (armed leader parked live on the marker for the wait window).
	if (isNil "WFBE_C_DEADSPAWN_GUARD") then {WFBE_C_DEADSPAWN_GUARD = 1};

	//--- fable/deadspawn-redesign: replaces the shared-marker wall pen (Init_DeadspawnWall.sqf)
	//--- with a single in-bounds underwater holding point (Common_DeadspawnPenPos.sqf) for the
	//--- join/transit window. 1 (default) = new underwater pen, 0 = today's TempRespawnMarker
	//--- pen, unchanged. Independent of WFBE_C_DEADSPAWN_GUARD above (that flag toggles the HC's
	//--- own ParkDeadspawn behaviour, not the human join-placement this flag controls).
	if (isNil "WFBE_C_DEADSPAWN_REDESIGN") then {WFBE_C_DEADSPAWN_REDESIGN = 1};

	//--- fable/deadspawn-ai-pen (owner ruling 2026-08-01): the DEADSPAWNS land holding area (the
	//--- three TempRespawnMarker points in the NE hills) is too close to the game action and
	//--- accumulates visible bodies/gear. Flag >0: the dead-AI respawn wait (AI_AdvancedRespawn.sqf /
	//--- AI_SquadRespawn.sqf) parks at the same in-bounds underwater pen the human join flow already
	//--- uses (Common_DeadspawnPenPos.sqf), with the setCaptive/allowDamage hold forced on for the
	//--- underwater window and the body surfaced on every release path. Weapon-holder litter at both
	//--- sites remains covered by the whole-island droppeditems_cleaner.sqf sweep (~10 min cadence).
	//--- 0 = legacy TempRespawnMarker land park, behaviour-identical to HEAD.
	if (isNil "WFBE_C_DEADSPAWN_AI_PEN") then {WFBE_C_DEADSPAWN_AI_PEN = 1};

//--- TP-17 (fable/tp17-marker-destination): HQ team map markers DESTINATION-direction mode.
//--- When flag>0, team arrows point toward the leader's active movement destination instead of
//--- current facing direction. Falls back to facing when no valid destination is available.
//--- Client-side only. Locality note: expectedDestination works on local units only; HC-owned
//--- AI leaders fall back to getDir facing silently. Zero server load. Flag 0 = byte-identical.
	if (isNil "WFBE_C_TEAMMARKER_DEST_DIR") then {WFBE_C_TEAMMARKER_DEST_DIR = 0}; //--- fable/marker-facing (owner 2026-07-09): reverted 1->0. Dest-dir mode hijacked the player's OWN arrow onto a NEVER-EXPIRED stored shift-click order (updateteamsmarkers.sqf:140-148; the _MAP_ORDER_TIME stamp was written but never read), permanently locking the self-arrow to a stale bearing = "facing the wrong way". Owner wants the conventional heading arrow. 0: facing (getDir); >0: destination-direction when an active destination is available, facing fallback.
//--- TP-16 / naval-cap-hinds: spawn 3x Mi-24 CAP per carrier instead of the default Hind + An2 pair.
//--- Chernarus-only feature (IS_NAVAL_MAP); flag has no effect on non-naval mirrors.
//--- Default 0 = current pair behaviour. Set > 0 to activate all-hind triple CAP.
	if (isNil "WFBE_C_NAVAL_CAP_THREE_HINDS") then {WFBE_C_NAVAL_CAP_THREE_HINDS = 1};

//--- naval-air-spawn-easa (fable/naval-air-spawn-easa, 2026-07-07):
//--- WFBE_C_NAVAL_CAP_L39: when >0, the GUER carrier CAP becomes 2x L39_TK_EP1 jets
//---   instead of the legacy Mi24_P + An2 (or THREE_HINDS) composition. L39 path
//---   takes precedence over THREE_HINDS when both >0. Default 1 (live).
//--- WFBE_C_NAVAL_EASA_RANDOM: when >0, aircraft spawned by the GUER CAP and by
//---   carrier air-purchases get a random EASA preset for their airframe (silently
//---   skips airframes not in WFBE_EASA_Vehicles). Default 1.
	if (isNil "WFBE_C_NAVAL_CAP_L39")      then {WFBE_C_NAVAL_CAP_L39      = 1}; //--- 0=legacy Hind/An2; >0=twin L39 jets.
	if (isNil "WFBE_C_NAVAL_EASA_RANDOM")  then {WFBE_C_NAVAL_EASA_RANDOM  = 1}; //--- 0=off; >0=randomise EASA on carrier/CAP spawns.

//--- fable/naval-cap-variety (owner 2026-07-08): WFBE_C_NAVAL_CAP_MODE replaces the CAP_L39/THREE_HINDS
//--- precedence chain with a weighted roll. 0 = LEGACY (byte-identical: CAP_L39 wins when both >0, else
//--- THREE_HINDS, else Hind+An2 - CAP_L39/THREE_HINDS stay live under this mode, never deleted). 1 = WEIGHTED
//--- ROLL (new default): ignore CAP_L39/THREE_HINDS, re-roll a composition every carrier arm-cycle from the
//--- WFBE_C_NAVAL_CAP_WEIGHT_* shares below. See Init_NavalHVT.sqf CAP arm block.
	if (isNil "WFBE_C_NAVAL_CAP_MODE") then {WFBE_C_NAVAL_CAP_MODE = 1}; //--- 0=legacy CAP_L39/THREE_HINDS chain; >0=weighted roll.
	if (isNil "WFBE_C_NAVAL_CAP_WEIGHT_MI24")     then {WFBE_C_NAVAL_CAP_WEIGHT_MI24     = 45}; //--- weighted-roll share: 3x Mi-24_P (owner's TP-16 ask, primary again).
	if (isNil "WFBE_C_NAVAL_CAP_WEIGHT_L39")      then {WFBE_C_NAVAL_CAP_WEIGHT_L39      = 40}; //--- weighted-roll share: 2x L39_TK_EP1 carrier circuit.
	if (isNil "WFBE_C_NAVAL_CAP_WEIGHT_SUX")      then {WFBE_C_NAVAL_CAP_WEIGHT_SUX      = 8};  //--- weighted-roll share: 1x Su34, rare heavyweight.
	if (isNil "WFBE_C_NAVAL_CAP_WEIGHT_SKIRMISH") then {WFBE_C_NAVAL_CAP_WEIGHT_SKIRMISH = 7};  //--- weighted-roll share: rare scripted air-duel spectacle.

//--- naval-cap-variety SKIRMISH outcome config: additive spectacle, never leaves the carrier bare
//--- (a WFBE_C_NAVAL_SKIRMISH_BASE_MODE composition still escorts). Intruder is a single jet, random
//--- WEST/EAST, from a non-tier-5 tunable class pool, own mission-wide concurrency cap + lifetime.
	if (isNil "WFBE_C_NAVAL_SKIRMISH_BASE_MODE")    then {WFBE_C_NAVAL_SKIRMISH_BASE_MODE    = "MI24"};
	if (isNil "WFBE_C_NAVAL_SKIRMISH_WEST_CLASSES") then {WFBE_C_NAVAL_SKIRMISH_WEST_CLASSES = ["A10","A10_US_EP1","L159_ACR"]};
	if (isNil "WFBE_C_NAVAL_SKIRMISH_EAST_CLASSES") then {WFBE_C_NAVAL_SKIRMISH_EAST_CLASSES = ["Su25_TK_EP1","Su25_Ins","ibrPRACS_MiG21mol"]};
	if (isNil "WFBE_C_NAVAL_SKIRMISH_MAX_ACTIVE")   then {WFBE_C_NAVAL_SKIRMISH_MAX_ACTIVE   = 1};   //--- mission-wide concurrent naval-skirmish cap (all 3 carriers share this).
	if (isNil "WFBE_C_NAVAL_SKIRMISH_LIFETIME")     then {WFBE_C_NAVAL_SKIRMISH_LIFETIME     = 240}; //--- s hard cleanup ceiling regardless of duel outcome.

//--- USV FLOTILLA (fable/usv-flotilla, owner 2026-07-08): 3-boat GUER coastal flotilla, PBX hull +
//--- attachTo static per boat (AA/ROCKET/HMG). Master gate default 0 = byte-identical to HEAD.
//--- Piggybacks on IS_naval_map (see Server_USVFlotilla.sqf header) - no new map define needed.
	if (isNil "WFBE_C_USV_FLOTILLA_ENABLE")   then {WFBE_C_USV_FLOTILLA_ENABLE = 1};   //--- armed 2026-07-27 owner go: #1519 fixes the gate-reopen-after-quiet-despawn bug and #1504 ships the waypoints. In-engine water-safety is still unproven; QUIET_DESPAWN reaps strays.
	if (isNil "WFBE_C_USV_FLOTILLA_PLAYER_GATE")    then {WFBE_C_USV_FLOTILLA_PLAYER_GATE = 1};    //--- ARMED 2026-07-28 (owner: "USVs also seem active the entire time... Waste of ai"): the coastal-town gate branch additionally requires a live non-HC player within PLAYER_RADIUS of the active coastal town - no audience, no flotilla. 0 = legacy activation-only gate.
	if (isNil "WFBE_C_USV_FLOTILLA_PLAYER_RADIUS")  then {WFBE_C_USV_FLOTILLA_PLAYER_RADIUS = 1500}; //--- m; player-to-coastal-town distance that counts as an audience for branch (a). Carrier branch keeps its own WFBE_C_USV_CARRIER_APPROACH_RADIUS.
	if (isNil "WFBE_C_PATROL_AIR_TIER")             then {WFBE_C_PATROL_AIR_TIER = 1};              //--- ARMED 2026-07-28 (owner: "Reimagine Patrol tiers... maybe at Tier 3-4 we can do something with air units? perhaps even from off-map?"): patrol upgrade L3+ rolls an off-map single-pass air strike when a side patrol reaches its objective town; L4 = pair. Replaces the removed T3/T4 money/SV rewards. W/E only. 0 = off (rewards stay removed).
	if (isNil "WFBE_C_PATROL_AIR_CHANCE")           then {WFBE_C_PATROL_AIR_CHANCE = 0.35};         //--- server-side roll per eligible patrol town-arrival.
	if (isNil "WFBE_C_PATROL_AIR_COOLDOWN")         then {WFBE_C_PATROL_AIR_COOLDOWN = 300};        //--- s between passes per side.
	if (isNil "WFBE_C_PATROL_AIR_PASS_TIME")        then {WFBE_C_PATROL_AIR_PASS_TIME = 90};        //--- s of attack run before the edge exit starts (W13 window).
	if (isNil "WFBE_C_AICOM_SUPPLY_SQUAD")          then {WFBE_C_AICOM_SUPPLY_SQUAD = 1};           //--- ARMED 2026-07-28 (owner: "Allow the ai commander to run a small supply squad by itself once it reaches its unlock gates (Truck, or helicopter)" - supersedes the old do-not-re-propose "AI supply trucks" entry): one autonomous supply squad per AI-commanded W/E side; truck at Light-Factory, heli at AIR>=3; each round trip credits the side supply pool. 0 = off.
	if (isNil "WFBE_C_AICOM_SUPPLY_GRANT")          then {WFBE_C_AICOM_SUPPLY_GRANT = 300};         //--- side-supply credit per completed round trip (ChangeSideSupply, clamped at the economy ceiling).
	if (isNil "WFBE_C_AICOM_SUPPLY_TICK")           then {WFBE_C_AICOM_SUPPLY_TICK = 15};           //--- s maintain-loop cadence (floor 5).
	if (isNil "WFBE_C_AICOM_SUPPLY_DWELL")          then {WFBE_C_AICOM_SUPPLY_DWELL = 20};          //--- s "loading" dwell at the town before the return leg.
	if (isNil "WFBE_C_AICOM_SUPPLY_COOLDOWN")       then {WFBE_C_AICOM_SUPPLY_COOLDOWN = 300};      //--- s respawn cooldown after the squad is destroyed - killing it matters.
	if (isNil "WFBE_C_AICOM_SUPPLY_AI_ONLY")        then {WFBE_C_AICOM_SUPPLY_AI_ONLY = 1};         //--- 1 = only while wfbe_aicom_running (human commander runs his own logistics; squad stands down player-safe on takeover). 0 = also under human command.
	if (isNil "WFBE_C_AICOM_AIRLIFT_REQ")           then {WFBE_C_AICOM_AIRLIFT_REQ = 0};             //--- OFF 2026-07-28 (live evidence): AICOM teams requesting a paid airmobile transport. The grant+delivery half works (55/55 on the live server in one match) but the LIFT half is structurally unreachable - the air-insert code runs once at team founding, before the loop that later creates the transport - so 100% of granted helicopters (4928 funds each, ~271k/match) parked at the aircraft factory with only a pilot while the team walked. 1 = re-enable ONLY after the lift is implemented at the in-loop delivery point.
	if (isNil "WFBE_C_AICOM_AIRLIFT_V2")            then {WFBE_C_AICOM_AIRLIFT_V2 = 0};              //--- fable/airlift-v2 (PR #1579 follow-up, owner 2026-07-28): the LIFT half, implemented AT the in-loop requisitioned-transport DELIVERY point (Common_RunCommanderTeam.sqf AIRMOBILE TRANSPORT GRANT CONSUMER), instead of the founding air-insert block that can never reach a hull created later - see AIRLIFT_REQ above for the full live-evidence writeup. Mount + fly + unload + RTB reuse the founding air-insert / Common_AICOMAirLeg / Common_AICOMAirReturn idioms (new Common_AICOMAirliftV2Deliver.sqf); stage telemetry via diag_log AIRLIFT2|v1|stage=. Does NOT require or re-arm AIRLIFT_REQ - the request gate now fires when EITHER flag is >0. Stays OFF until soaked.
	if (isNil "WFBE_C_FPV_SPAWN_OFFSET")            then {WFBE_C_FPV_SPAWN_OFFSET = 40};            //--- fable/fpv-spawn-safety (owner 2026-07-28 "suicide choppers spawned into each other"): m of radial offset from the launch anchor, with a height stagger + clearance retry, so two launches at one command centre cannot materialise inside each other. Floor 10.
	if (isNil "WFBE_C_FPV_ARM_DELAY")               then {WFBE_C_FPV_ARM_DELAY = 3};                //--- s before the FPV impact fuze arms; damage is then measured as a DELTA from the arming baseline, so spawn scuffing cannot detonate the warhead on the pad ("never left base ... exploded in their own base").
	if (isNil "WFBE_C_FPV_MIN_BLAST_RANGE")         then {WFBE_C_FPV_MIN_BLAST_RANGE = 120};        //--- m: within this range of the FIRING side's own structures the live warhead is suppressed (hull still dies). Enemy-facing lethality unchanged. 0 = off (legacy: blast anywhere).
	if (isNil "WFBE_C_FPV_COOLDOWN")                then {WFBE_C_FPV_COOLDOWN = 60};                //--- s between FPV launches per player. Formal registration - was lobby-param + inline code fallback only (Support_FPV.sqf), against repo flag policy; value matches the previous fallback.
	if (isNil "WFBE_C_RESERVE_GUARD")               then {WFBE_C_RESERVE_GUARD = 1};                //--- ARMED 2026-07-28 (owner picker, C9 S22): Reserve structures field the WDDM reserve-guard preset (2 flank MGs + AT overwatch, 3 crewed AI) on top of the themed cluster. 0 = plain lean dressing, byte-identical to pre-S22.
	if (isNil "WFBE_C_NAVAL_THEATER_RUMOR")  then {WFBE_C_NAVAL_THEATER_RUMOR = 0};    //--- 0 = no naval theatre activity announcements; >0 = announce existing gate flips.
	if (isNil "WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL") then {WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL = 120}; //--- seconds between announcements for the same gate.
	if (isNil "WFBE_C_USV_FLOTILLA_COUNT")    then {WFBE_C_USV_FLOTILLA_COUNT = 3};    //--- boats roaming at once (owner: 3). Bumping this is a one-line tune; roles cycle round-robin.
	if (isNil "WFBE_C_USV_FLOTILLA_ROLES")    then {WFBE_C_USV_FLOTILLA_ROLES = ["AA","ROCKET","HMG"]}; //--- role cycle order; default = one-of-each at COUNT=3.
	if (isNil "WFBE_C_USV_FLOTILLA_SIDE")     then {WFBE_C_USV_FLOTILLA_SIDE = "GUER"}; //--- GUER-only per owner (matches every other asymmetric-GUER-asset precedent: naval CAP, air-def).
	if (isNil "WFBE_C_USV_FLOTILLA_HULL")     then {WFBE_C_USV_FLOTILLA_HULL = "PBX"};  //--- GUER/RU small boat (Units_CO_RU.sqf:84,272,302).
	if (isNil "WFBE_C_USV_CARRIER_APPROACH_RADIUS") then {WFBE_C_USV_CARRIER_APPROACH_RADIUS = 1800}; //--- m; mirrors Init_NavalHVT.sqf:713 CAP arm band.
	if (isNil "WFBE_C_USV_FLOTILLA_QUIET_DESPAWN")  then {WFBE_C_USV_FLOTILLA_QUIET_DESPAWN = 120}; //--- s; mirrors naval CAP despawn timer (Init_NavalHVT.sqf:886).
	if (isNil "WFBE_C_USV_FLOTILLA_COASTAL_CHECK_RADIUS")  then {WFBE_C_USV_FLOTILLA_COASTAL_CHECK_RADIUS = 400}; //--- m; one-time boot ring-sample radius for wfbe_is_coastal tagging.
	if (isNil "WFBE_C_USV_FLOTILLA_COASTAL_CHECK_SAMPLES") then {WFBE_C_USV_FLOTILLA_COASTAL_CHECK_SAMPLES = 8}; //--- ring sample count for the same one-time pass.
	if (isNil "WFBE_C_USV_FLOTILLA_MOUNT_OFFSET")   then {WFBE_C_USV_FLOTILLA_MOUNT_OFFSET = [0, -0.8, 1.0]}; //--- PLACEHOLDER attachTo offset - hand-tune in-editor against the PBX model (mirrors FINAL-SPECS.md V3S bed offset caveat).
	if (isNil "WFBE_C_USV_FLOTILLA_ARRIVE_RADIUS")  then {WFBE_C_USV_FLOTILLA_ARRIVE_RADIUS = 50}; //--- m; waypoint-arrival threshold.
	if (isNil "WFBE_C_USV_FLOTILLA_UNSTUCK_MAX")    then {WFBE_C_USV_FLOTILLA_UNSTUCK_MAX = 5}; //--- consecutive un-wedges before a leg is skipped; mirrors WFBE_C_AICOM_PATROL_UNSTUCK_MAX.

//--- fable/ew-naval (Carrier ServicePoint): WFBE_C_NAVAL_CARRIER_SERVICE_POINTS - when >0, each captured
//---   carrier HVT spawns a side-registered repair/rearm ServicePoint on the flight deck (server_town.sqf
//---   carrier-capture block), mirroring the land-airfield Task-12 ServicePoint. Default 0 = current
//---   behaviour (no deck ServicePoint); mission stays byte-identical to HEAD with the flag off.
	if (isNil "WFBE_C_NAVAL_CARRIER_SERVICE_POINTS") then {WFBE_C_NAVAL_CARRIER_SERVICE_POINTS = 1}; //--- 0=off (byte-identical); >0=carrier deck gets a repair/rearm ServicePoint on capture.


//======================================================================================
//--- NAVAL INLINE SUPER-CARRIER (fable/naval-inline-hulls, Ray 2026-07-06):
//--- A/B-testable bow-to-stern axis for the outer-carrier twin-hull system.
//---
//--- WFBE_C_NAVAL_INLINE_HULLS  (default 0):
//---   Master switch.  When > 0, the second hull on each OUTER carrier is placed
//---   INLINE (bow-to-stern, aft of Hull A) instead of LATERALLY (side-by-side).
//---   Precedence: when this flag > 0 AND WFBE_C_NAVAL_TWIN_HULLS = 1, the inline
//---   offset formula supersedes the lateral formula; all other twin-hull logic
//---   (middle-carrier detection, SCUD, air-shop, CAP) is unchanged.
//---   When 0: exact HEAD behaviour (lateral offset if WFBE_C_NAVAL_TWIN_HULLS=1).
//---
//--- WFBE_C_NAVAL_INLINE_GAP  (default -245):
//---   Hull B anchor offset along the ship's LONG axis, in metres (body-space Y).
//---   Negative = aft of Hull A anchor.  Tunable at mission start without a code
//---   edit: read as getVariable ["WFBE_C_NAVAL_INLINE_GAP", -245] at spawn time.
//---   Safe iterate range for in-engine seam alignment: -238 to -265.  Smaller
//---   magnitude = hulls closer together (more butt overlap); larger = further apart.
//---   Paper derivation was 128m (Hull A stern-to-anchor) + 9m (Hull A stern overhang)
//---               + 8m (Hull B bow overhang) + 120m (Hull B anchor-to-bow) = 265m,
//---   but in-engine reports have walked it in twice (07-28, 08-02): the model overhangs
//---   are smaller than the paper figures, so trust the live report over the derivation.
//---
//--- WFBE_C_NAVAL_SEAM_BRIDGE  (default 0):
//---   When > 0, spawn 4x Land_nav_pier_m_1 bridge segments across the Hull A
//---   stern / Hull B bow seam, at the averaged deck-Z of both hulls.  The four
//---   body-space Y offsets are DERIVED from WFBE_C_NAVAL_INLINE_GAP (straddling the
//---   seam mid-point at half the gap), so tuning the gap moves the piers with it;
//---   they no longer need a matching hand-edit.  At the original -265 the derivation
//---   reproduces the old literals exactly: -131,-134,-137,-140.
//---   Escalation-ladder step 2: flush-butt geometry is tried first (inline=1,
//---   seam=0); add piers only if the seam wheeled-vehicle test requires it.
//---   Has no effect unless WFBE_C_NAVAL_INLINE_HULLS > 0.
//======================================================================================
	if (isNil "WFBE_C_NAVAL_INLINE_HULLS") then {WFBE_C_NAVAL_INLINE_HULLS  = 1};   //--- 0 = lateral HEAD behaviour; >0 = inline bow-to-stern axis
	if (isNil "WFBE_C_NAVAL_INLINE_GAP")   then {WFBE_C_NAVAL_INLINE_GAP    = -245}; //--- Hull B aft offset metres (body Y). [Ray-dir 2026-08-02 "still a small gap, move a bit more": -252->-245, the fallback pre-registered by the 07-28 tune. Ladder so far: -265 (paper derivation) -> -252 (Ray-dir 07-28 "decks still not touching") -> -245. NOTE the two earlier gap tunes (TWIN_GAP 42->32->26) edited the LATERAL constant, which is SKIPPED while WFBE_C_NAVAL_INLINE_HULLS=1 - THIS is the live knob. Wasp-class LOA ~253m, so -245 deliberately overlaps the butt by ~8m; the LHD parts are statics, so interpenetration is cosmetic and costs no collision work. If a sliver STILL remains next report: -238. Rollback -252.]
	if (isNil "WFBE_C_NAVAL_SEAM_BRIDGE")  then {WFBE_C_NAVAL_SEAM_BRIDGE   = 0};   //--- 0 = no bridge piers; >0 = 4x Land_nav_pier_m_1 at seam
//--- fable/naval-camps-on-deck (Ray 2026-07-07):
//--- WFBE_C_NAVAL_CAMPS_DECK: when 1 (default), re-seat Khe Sanh camp logics/models/flags +
//---   depot to deckZ after Init_Town spawns them (owner-reported: camps appeared at sea level).
//--- WFBE_C_NAVAL_SCUD_CLEARANCE: extra metres above deckZ for the MAZ_543_SCUD_TK_EP1 origin so
//---   the lower hull clears the deck surface (origin is mid-body, not bottom of vehicle).
//---   Tune in-engine; default 2.4 m (was 1.6 - owner 2026-07-09: wheels were still clipping the deck).
//--- fable/scud-polish (owner 2026-07-09):
//--- WFBE_C_NAVAL_SCUD_DECK_OX / WFBE_C_NAVAL_SCUD_DECK_OY: deck-relative launcher position, in the
//---   deck part's own model space (see the SCUD block in Init_NavalHVT.sqf for the axis derivation).
//---   OX = LATERAL/beam offset (0 = the deck part's own centerline; +/- = toward one side or the
//---   other). OY = LONGITUDINAL/fore-aft offset (+ = toward the bow, - = toward the stern). Old
//---   hardcoded offset [8, -14, 0] hugged one side hull; new defaults OX=0 (centered, off the hull)
//---   / OY=-20 (was -14; further toward the stern). Both the primary and showpiece 2nd launcher read
//---   these (showpiece keeps its ~7 m abeam gap via OX-7). Nudge in-engine - neither Claude nor Codex
//---   can see the deck geometry, treat these as a starting guess.
	if (isNil "WFBE_C_NAVAL_CAMPS_DECK")      then {WFBE_C_NAVAL_CAMPS_DECK      = 1};   //--- 1=reseat camp models to flight deck; 0=off (default 1, correctness fix)
	if (isNil "WFBE_C_NAVAL_SCUD_CLEARANCE")  then {WFBE_C_NAVAL_SCUD_CLEARANCE  = 2.4}; //--- extra metres above deckZ for SCUD vehicle origin (tune in-engine)
	if (isNil "WFBE_C_NAVAL_SCUD_DECK_OX")    then {WFBE_C_NAVAL_SCUD_DECK_OX    = 0};   //--- lateral/beam deck offset, model space (tune in-engine)
	if (isNil "WFBE_C_NAVAL_SCUD_DECK_OY")    then {WFBE_C_NAVAL_SCUD_DECK_OY    = -20}; //--- longitudinal/fore-aft deck offset, model space (tune in-engine)
	if (isNil "WFBE_C_NAVAL_SCUD_SHOWPIECE") then {WFBE_C_NAVAL_SCUD_SHOWPIECE = 1}; //--- ARMED [owner 2026-07-07: deploy ask] //--- fable/scud-showpiece: 2nd deck SCUD + props + heli-only air shop on the SCUD carrier (0=off)
//--- TELEMETRY HOST V2 (tp4, 2026-07-06): when flag=1, GRPBUDGET+SRVPERF emit from
//--- server_groupsGC.sqf (survives V2 cutover) and are suppressed in AI_Commander.sqf.
//--- Default 0 = byte-identical to HEAD (old emitters run, new host silent).
	if (isNil "WFBE_C_TELEM_HOST_V2") then {WFBE_C_TELEM_HOST_V2 = 0};

//--- TP-21 (fable/tp21-team-menu-v2): TEAM MENU V2 — gear presets + squad actions.
//--- 0 = byte-identical to HEAD (RscMenu_Team idd 13000 opens as before); >0 = opens
//--- RscMenu_TeamV2 (idd 13050) which adds 4 persistent loadout preset slots
//--- (save / apply / rebuy-last-kit, tier-gated) plus TM1-light squad actions
//--- (Eject selected AI from vehicle, Disband reuse, Get-Out-and-Repair, out-of-fuel hint).
//--- The REMOVED controls (VD/TG sliders, inline money transfer) are simply absent
//--- from the V2 dialog; old RscMenu_Team is untouched and activates at flag=0.
	if (isNil "WFBE_C_TEAM_MENU_V2") then {WFBE_C_TEAM_MENU_V2 = 1};
//--- SPOTTER MARKS TEAM-WIDE (team-intel-pack, 2026-07-02): when 1, spotter map marks
//--- are broadcast to all same-side clients (not just the spotter). Default 0 = local-only.
//--- See Client\Module\Skill\Skill_Sniper.sqf + Client\PVFunctions\SpotterMarkContact.sqf.
	if (isNil "WFBE_C_SPOTTER_TEAM_MARKS") then {WFBE_C_SPOTTER_TEAM_MARKS = 1};

//--- NOTABLE-KILL FEED (team-intel-pack, 2026-07-02): side-wide SideMessage for high-value
//--- kills (commander unit, HQ/MHQ structure, attack heli/jet, heavy tank). Default 0 = off.
//--- WFBE_C_NOTABLE_KILL_THROTTLE: minimum seconds between feed messages per-side (spam guard).
	if (isNil "WFBE_C_NOTABLE_KILL_FEED")     then {WFBE_C_NOTABLE_KILL_FEED     = 1};
	if (isNil "WFBE_C_NOTABLE_KILL_THROTTLE") then {WFBE_C_NOTABLE_KILL_THROTTLE = 10};

//--- MATCH TELEMETRY (fable/match-facts-family, 2026-07-06): master gate for the MATCH|v1| family.
//--- Default 1 (ON): this is purely additive RPT telemetry feeding the Stats V2 match-report pipeline;
//--- no gameplay logic is gated on it. Set to 0 to suppress all MATCH|v1| lines (zero overhead).
	if (isNil "WFBE_C_MATCH_TELEMETRY") then {WFBE_C_MATCH_TELEMETRY = 1};

//--- fable/wddm-functional-defenses: FACTORY WALL SLABS v4. Redesign of the v3 concrete slab
//--- layer (WFBE_NEURODEF_*_WALLS_V4, Init_Defenses.sqf): legacy ring verbatim + contiguous
//--- Concrete_Wall_EP1 runs at the HQ 2.2 m overlap pitch (no lone single panels), slab-layer
//--- gaps aligned with the legacy walking gaps, +X egress faces fully open on Light/Heavy/
//--- Aircraft, Land_CncBlock_Stripes accents at gap mouths, ServicePoint slab-free.
//--- Flag >0 -> Construction_Small/MediumSite.sqf prefer _WALLS_V4 where defined; 0 (default) ->
//--- the existing WFBE_C_WALLS_V3 selection runs untouched (V3 stays the live default look).
	if (isNil "WFBE_C_WALLS_V4") then {WFBE_C_WALLS_V4 = 1};

//--- fable/wddm-functional-defenses: FORTIFICATION PACK. Ray (owner intent, verbatim gist):
//--- "Fortifications! Not fortresses - useful items like a row of concrete walls, or a way to
//--- block LoS to your base... larger assets basically." Five PASSIVE larger buildable
//--- fortification compositions (Init_Defenses.sqf WFBE_NEURODEF_FORTIF_*: Concrete Wall Row ~22 m,
//--- Concrete Wall Corner L-section, Tall LoS Screen ~43 m of Base_WarfareBBarrier10xTall,
//--- HESCO Line ~39 m, Gate Complex drive-through mouth), WDDM-authored
//--- (docs/design/compositions/fortif_*.wddm.json). Flag >0 -> the five anchor ghosts enter
//--- WFBE_POSITION_TEMPLATE_MAP / WFBE_POSITION_ANCHOR_NAMES (Init_Defenses.sqf) + the side
//--- Fortification menus (Structures_CO_US/_CO_RU/_CO_GUE/_OA_TKA v2 blocks). 0 (default) =
//--- nothing is wired anywhere - byte-identical behaviour to HEAD.
	if (isNil "WFBE_C_DEF_FORTIF_PACK") then {WFBE_C_DEF_FORTIF_PACK = 1};
//--- Own composition cap for the fortification-pack anchors (Server\PVFunctions\RequestDefense.sqf
//--- B3b): fortif placements are counted against THIS cap (distinct placement-IDs whose stamped
//--- WFBE_WDDMAnchorClass is a fortif ghost) and are EXCLUDED from the WFBE_C_WDDM_COMP_CAP=3
//--- weapon-position pool, so walls/screens never eat the weapon-position slots. Only read when
//--- WFBE_C_DEF_FORTIF_PACK > 0 (at 0 the legacy single-pool count runs verbatim).
	if (isNil "WFBE_C_DEF_FORTIF_CAP") then {WFBE_C_DEF_FORTIF_CAP = 6};
//--- SML-1 Squad Micro Layer: camp-split captures (GR-2026-07-03a). Flag-gated default 0.
	if (isNil "WFBE_C_SML_CAMP_SPLIT")    then {WFBE_C_SML_CAMP_SPLIT    = 1};   //--- 1=enable per-unit doStop/doMove camp-split; 0=byte-identical legacy behaviour.
	if (isNil "WFBE_C_SML_CAMP_SPLIT_MIN_FOOT") then {WFBE_C_SML_CAMP_SPLIT_MIN_FOOT = 2};  //--- armed 2026-07-27 owner go (was hard-coded 3 in Common_SMLCampSplit.sqf). Minimum foot infantry before SML-1 will split across two unheld camps. At 3 a small or attrited team fell under the floor and silently deferred to the caller sequential nearest-camp loop, which has no stall protection while mode-2 stall-bail is deliberately disabled - the Dubrovka failure shape (51 min, camps=1/2, footMen=8). 2 permits a 1+1 split (_half = floor(2/2) = 1), which is the minimum that can contest both camps of a 2-camp town at once. Directly serves the smaller-better-groups directive, which otherwise pushes teams UNDER a 3-man floor. Rollback: 3.
	if (isNil "WFBE_C_SML_WATCHDOG_TTL") then {WFBE_C_SML_WATCHDOG_TTL = 240};  //--- s: per-unit TTL before the watchdog forces doFollow back (covers all exit paths).
	if (isNil "WFBE_C_SML_CAPTURE_TTL") then {WFBE_C_SML_CAPTURE_TTL = 360};  //--- s: capture-phase TTL override for SML-1 camp-split + SML-2 dismounts ONLY. 0 = OFF, byte-identical to HEAD (both keep reading the shared WFBE_C_SML_WATCHDOG_TTL). >0 = use this value instead, so the watchdog can never remount infantry BEFORE the camp-first window it exists to cover has ended; owner arms it explicitly (same idiom as WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE). Suggested arming value: 360, matching WFBE_C_AICOM_ASSAULT_HOLD. Live evidence 2026-07-27 (4-HC soak, HC1+HC3 RPTs): 78 BEGIN_CAPTURE vs 23 SML DISMOUNT, with SML|v1|REMOUNT|reason=ttl elapsed=241 firing inside a 360s _campFirstEnd - the shared 240s TTL was ending dismounts 120s early, putting cargo infantry back in their hulls for the last third of every camp-first phase where the camp nearEntities["Man"] scan can no longer see them. SML-4 overwatch / SML-5 retreat deliberately KEEP the shorter shared WFBE_C_SML_WATCHDOG_TTL (combat-reactive, not capture-phase). Rollback: set to 240.
//--- SML-2: real dismounts (cargo infantry advance on foot; driver/gunner stay mounted for fire support). Flag-gated default 0.
	if (isNil "WFBE_C_SML_DISMOUNTS")              then {WFBE_C_SML_DISMOUNTS              = 1};   //--- 1=enable real dismounts; 0=byte-identical legacy behaviour.
//--- SML-3: graceful retreats (mauled individuals pull back while healthy units keep fighting). Flag default 0.
	if (isNil "WFBE_C_SML_RETREAT")                   then {WFBE_C_SML_RETREAT                   = 1};
	if (isNil "WFBE_C_SML_RETREAT_DAMAGE_THRESHOLD")  then {WFBE_C_SML_RETREAT_DAMAGE_THRESHOLD  = 0.5};  //--- getDammage >= this -> unit is mauled and pulls back.
	if (isNil "WFBE_C_SML_RETREAT_HEALTHY_MIN")       then {WFBE_C_SML_RETREAT_HEALTHY_MIN       = 4};    //--- if fewer healthy units remain, skip retreat (whole-team attrition; disband/refit handles it).
//--- SML-4: AT overwatch (launcher pre-positions on armor approach vector before the depot assault). Flag default 0.
	if (isNil "WFBE_C_SML_AT_OVERWATCH")              then {WFBE_C_SML_AT_OVERWATCH              = 1};
	if (isNil "WFBE_C_SML_AT_OVERWATCH_ARMOR_R")      then {WFBE_C_SML_AT_OVERWATCH_ARMOR_R      = 500};  //--- m: nearEntities Tank scan radius around _townCenter.
	if (isNil "WFBE_C_SML_AT_OVERWATCH_OFFSET")       then {WFBE_C_SML_AT_OVERWATCH_OFFSET       = 80};   //--- m: overwatch offset from _dest on the armor approach bearing.
//--- SML-5: surgical unstuck (nudge only individually-wedged units; pre-tier step in the unstuck ladder). Flag default 0.
	if (isNil "WFBE_C_SML_SURGICAL_UNSTUCK")          then {WFBE_C_SML_SURGICAL_UNSTUCK          = 1};
	if (isNil "WFBE_C_SML_UNSTUCK_MAX_UNITS")         then {WFBE_C_SML_UNSTUCK_MAX_UNITS         = 2};    //--- if more than this many units are wedged, fall through to tier escalation.
	if (isNil "WFBE_C_SML_UNSTUCK_POS_DELTA")         then {WFBE_C_SML_UNSTUCK_POS_DELTA         = 8};    //--- m: unit moved less than this since last check -> considered wedged.
	if (isNil "WFBE_C_SML_UNSTUCK_NUDGE_DIST")        then {WFBE_C_SML_UNSTUCK_NUDGE_DIST        = 20};   //--- m: nudge distance toward order destination.
//--- GUER POP-UP CHECKPOINT v2 (claude/guer-cp-v2): road-snapped, road-aligned, physically blocking
//--- G2 wildcard checkpoint (AI_Commander_Wildcard_GUER.sqf case 2). 0 (default) = the legacy v1 G2
//--- block runs untouched (byte-identical behaviour); >0 = v2: candidates from `nearRoads` filtered by
//--- the guarded roadsConnectedTo>=2 usable-road idiom, WFBE_NEURODEF_FORT_CHECKPOINT composition spawned
//--- on the road axis, 2 GUER-manned MG statics, posted garrison, one-shot half-window reinforcement
//--- pulse, and a 900-base (v1: 700) clear reward. Server-side only; nothing runs while the flag is 0.
	if (isNil "WFBE_C_GUER_CP_V2") then {WFBE_C_GUER_CP_V2 = 1};
	if (isNil "WFBE_C_GUER_CP_BETWEEN") then {WFBE_C_GUER_CP_BETWEEN = 1}; //--- cmdcon45 (owner): G2 checkpoints anchor on the midpoint BETWEEN the occupied town and its nearest neighbour (0 = classic around-town).
	if (isNil "WFBE_C_TOWN_CAPTURE_FLIPS_CAMPS") then {WFBE_C_TOWN_CAPTURE_FLIPS_CAMPS = 1}; //--- cmdcon45 (owner): town capture flips its remaining camps to the new owner (0 = legacy per-camp only).
	if (isNil "WFBE_C_CAMPS_LEGACY_SKIP_ON_PERCAMP_FLIP") then {WFBE_C_CAMPS_LEGACY_SKIP_ON_PERCAMP_FLIP = 1}; //--- F8 (claude-gaming 2026-07-07): when 1 AND WFBE_C_TOWN_CAPTURE_FLIPS_CAMPS>0, suppress the legacy Server_SetCampsToSide double-flip on town capture (per-camp block already flips sideID/flag/broadcast). Default 0 = both paths fire (legacy also resets each camp supplyValue).
	if (isNil "WFBE_C_SKIP_EMPTY_CAMP_THREAD") then {WFBE_C_SKIP_EMPTY_CAMP_THREAD = 1}; //--- F3 (claude-gaming 2026-07-07): when 1, Init_Town skips launching server_town_camp.sqf for a town with zero synced camps (naval carrier towns) so no permanently-idle worker spawns. Default 0 = unchanged (thread still launched).
	if (isNil "WFBE_C_GUER_CP2_ROAD_RADIUS") then {WFBE_C_GUER_CP2_ROAD_RADIUS = 400};  //--- m: nearRoads candidate radius around the target town (v2 only).
	if (isNil "WFBE_C_GUER_CP2_FOOT_BASE") then {WFBE_C_GUER_CP2_FOOT_BASE = 4};        //--- v2 garrison base headcount (v1: 3).
	if (isNil "WFBE_C_GUER_CP2_FOOT_PER_TIER") then {WFBE_C_GUER_CP2_FOOT_PER_TIER = 2}; //--- v2 extra garrison per GUER vehicle tier (v1: 1).
	if (isNil "WFBE_C_GUER_CP2_ARMOR_EXTRA") then {WFBE_C_GUER_CP2_ARMOR_EXTRA = 1};    //--- v2 extra SAME-class hulls at tier>=2 (tier 3 = 2x T-72); read ONLY inside the CP_V2>0 branch, so inert while WFBE_C_GUER_CP_V2 = 0.
	//--- Legacy GUER wildcard/checkpoint/scavenger tunables (flag-policy registration).
	//--- Previously inline-only getVariable fallbacks in Server/Functions/AI_Commander_Wildcard_GUER.sqf;
	//--- registered here at their EXACT prior inline defaults, so this block is behavior-neutral.
	if (isNil "WFBE_C_GUER_WILDCARD")          then {WFBE_C_GUER_WILDCARD = 1};             //--- GUER wildcard deck master enable (1=on).
	if (isNil "WFBE_C_GUER_WILDCARD_INTERVAL") then {WFBE_C_GUER_WILDCARD_INTERVAL = 1800};  //--- Seconds between GUER wildcard draws.
	if (isNil "WFBE_C_GUER_CP_WINDOW")         then {WFBE_C_GUER_CP_WINDOW = 600};          //--- G2 checkpoint hold window (s) before it resolves.
	if (isNil "WFBE_C_GUER_CP_TAX")            then {WFBE_C_GUER_CP_TAX = 60};              //--- Per-tick occupier supply tax while the CP stands (scaled by 1+tier).
	if (isNil "WFBE_C_GUER_CP_TOLL")           then {WFBE_C_GUER_CP_TOLL = 250};            //--- Per-tick GUER toll payout while the CP stands (scaled by 1+tier).
	if (isNil "WFBE_C_GUER_CP_CLEAR")          then {WFBE_C_GUER_CP_CLEAR = 700};           //--- Supply injection to whoever clears the CP (scaled by 1+tier).
	if (isNil "WFBE_C_GUER_SCAV_REWARD")       then {WFBE_C_GUER_SCAV_REWARD = 300};        //--- G5 scavenger base cash per wreck scrapped.
	if (isNil "WFBE_C_GUER_SCAV_PLAYER_BONUS") then {WFBE_C_GUER_SCAV_PLAYER_BONUS = 150};  //--- G5 extra bonus when a GUER player is near the scrap.
	if (isNil "WFBE_C_GUER_SCAV_TTL")          then {WFBE_C_GUER_SCAV_TTL = 300};           //--- G5 scavenger team lifetime (s) before self-clean.
//--- TELEPORT-GUARD FIX (2026-07-06): player-visible teleport guard radius for tier-3 SNAP branches
//--- (Common_RunCommanderTeam.sqf vehicle + foot road-snap). Code previously hard-coded 100 m while
//--- the design comment specified 300 m; owner witnessed 6 teleports on 2026-07-06 from this mismatch.
//--- When any player is within this radius the snap is SKIPPED and execution falls through to the
//--- existing no-snap path: the velocity-hop fallback at ~line 1113 then visibly bumps the hull free
//--- (never-frozen guardrail). The 100 m velocity-hop fallback is a separate, intentional guard and
//--- is unaffected by this constant.
	if (isNil "WFBE_C_AICOM_RECOVERY_PLAYER_GUARD_R") then {WFBE_C_AICOM_RECOVERY_PLAYER_GUARD_R = 300};
	//--- Patrol tier-3 player-block termination: after this many consecutive guarded fires,
	//--- default behavior quietly recycles the AI group; the force-teleport option remains owner-gated.
	if (isNil "WFBE_C_AICOM_RECOVERY_PLAYER_BLOCKED_MAX") then {WFBE_C_AICOM_RECOVERY_PLAYER_BLOCKED_MAX = 3};
	if (isNil "WFBE_C_AICOM_RECOVERY_FORCE_PLAYER_TELEPORT") then {WFBE_C_AICOM_RECOVERY_FORCE_PLAYER_TELEPORT = 0};
//--- STUCK_REPAIR_RESETS_TIER (2026-07-06, flag-gated default 0): when STUCK_REPAIR fires and the
//--- hull canMove after in-place restoration, reset the team tier counter (wfbe_aicom_stuckstrikes)
//--- to 0 so AssignTowns does not re-issue the next order at a still-high tier. Investigation showed
//--- STUCK_REPAIR fired 3x but averted 0 teleports because the counter kept escalating. Inert at 0.
	if (isNil "WFBE_C_AICOM_STUCK_REPAIR_RESETS_TIER") then {WFBE_C_AICOM_STUCK_REPAIR_RESETS_TIER = 1};
//--- HC CIVILIAN cosmetic reslot (fable/hc-civ-reslot, GR-2026-07-03a): when >0, the server publishes an
//--- empty-server safe-window signal (WFBE_HC_RESLOT_SAFE) a box-side HC controller reads to bounce-reslot
//--- the HCs onto CIVILIAN slots (browser shows CIV, not WEST) only while zero real players are connected.
//--- Mission-side hook only; the CIV mission.sqm slots + the reslot itself are the remaining, rig-test-gated
//--- steps (box lane). Delegation is owner-routed (side-independent), so a CIV-slotted HC still hosts AI.
//--- LIVE DEFAULT IS 1, not 0. The flag is armed; the PV loop below DOES spawn. (The old comment here
//--- claimed "Default 0 = byte-identical to HEAD" and was wrong.) It has no in-repo consumer today, so
//--- its only live effect is Init_Server.sqf:1724 publicVariable-ing WFBE_HC_RESLOT_SAFE every 5s -
//--- the box-side reslot controller that would READ it does not exist. Do NOT flip the default
//--- without owner sign-off (repo policy).
	if (isNil "WFBE_C_HC_CIV_RESLOT") then {WFBE_C_HC_CIV_RESLOT = 1};


//--- Aircraft spawn safety (fable/aircraft-spawn-safety, GR-2026-07-03a):
//--- When >0, each aircraft purchase at an airfield/hangar attempts to find a clear
//--- spawn slot (occupancy + slope) before placing the hull.  Falls back to the nominal
//--- position on failure so the purchase is never blocked.  Default 0 = byte-identical.
	if (isNil "WFBE_C_AIR_SPAWN_SAFETY")        then {WFBE_C_AIR_SPAWN_SAFETY        = 1};   //--- Master gate: 0=off, 1=on.
	if (isNil "WFBE_C_AIR_SPAWN_CLEAR_RADIUS")  then {WFBE_C_AIR_SPAWN_CLEAR_RADIUS  = 12};  //--- m: vehicle+obstacle clear radius (rotor/wing clearance).
	if (isNil "WFBE_C_AIR_SPAWN_SLOPE_MAX")     then {WFBE_C_AIR_SPAWN_SLOPE_MAX     = 0.97}; //--- surfaceNormal z-floor; 0.97 ~ 14-deg slope limit.

//--- TOWN GARRISON DRESSING (lane 241, fable/qol-recycle-pick): server-side ZU-23 dressing
//--- on active GUER-held contested towns. One crew gunner per town, optional night searchlight.
//--- Worker: Server/Server_TownGarrisonDressing.sqf. Flag-off (0) = worker not launched = byte-identical.
	if (isNil "WFBE_C_GARRISON_DRESSING")          then {WFBE_C_GARRISON_DRESSING = 1};           //--- Master enable. 0 = off; >0 = dress active contested GUER towns.
	if (isNil "WFBE_C_GARRISON_DRESSING_INTERVAL") then {WFBE_C_GARRISON_DRESSING_INTERVAL = 90};  //--- Seconds between worker ticks. [Ray-dir 2026-07-24 CHURN: 45->90s (halve garrison-gun spawn/despawn churn, ~630 VEHDEL/session); rollback 45.]
	if (isNil "WFBE_C_GARRISON_DRESSING_RADIUS")   then {WFBE_C_GARRISON_DRESSING_RADIUS = 900};   //--- m: enemy proximity gate.
	if (isNil "WFBE_C_GARRISON_DRESSING_QUIET")    then {WFBE_C_GARRISON_DRESSING_QUIET = 240};   //--- s: remove dressed guns after this long without a nearby enemy. [Ray-dir 2026-07-24 CHURN: 300->240s (retire dressed guns sooner once the enemy leaves); rollback 300.]
	if (isNil "WFBE_C_GARRISON_DRESSING_LIFETIME") then {WFBE_C_GARRISON_DRESSING_LIFETIME = 900}; //--- s: forced recycle age per gun (anti-accumulation).
	if (isNil "WFBE_C_GARRISON_DRESSING_MAX")      then {WFBE_C_GARRISON_DRESSING_MAX = 6};        //--- Max simultaneous dressed towns across the map.
	if (isNil "WFBE_C_GARRISON_DRESSING_SEARCHLIGHT") then {WFBE_C_GARRISON_DRESSING_SEARCHLIGHT = 1}; //--- 1: add SearchLight_RUS at night; 0: gun only.

//--- GARRISON SORTIE PATROL (lane 237, docs/design/GARRISON-SORTIE-PATROL-DESIGN.md): short-lived
//--- foot/light patrol sorties dispatched from OWNED, active towns (WEST/EAST/GUER) whenever a
//--- human player is within range - moving contact near towns without standing AI at empty map
//--- locations. Worker: Server/Server_GarrisonSortie.sqf. Flag-off (0) = worker not launched =
//--- byte-identical to HEAD.
	if (isNil "WFBE_C_GARRISON_SORTIE")               then {WFBE_C_GARRISON_SORTIE = 1};               //--- armed 2026-07-27 owner go. Master enable: dispatches sorties from active owned towns.
	if (isNil "WFBE_C_GARRISON_SORTIE_INTERVAL")      then {WFBE_C_GARRISON_SORTIE_INTERVAL = 120};     //--- Seconds between worker ticks.
	if (isNil "WFBE_C_GARRISON_SORTIE_TTL")           then {WFBE_C_GARRISON_SORTIE_TTL = 300};          //--- s: forced recycle age per sortie (no "quiet" despawn - deliberately short-lived).
	if (isNil "WFBE_C_GARRISON_SORTIE_PLAYER_RANGE")  then {WFBE_C_GARRISON_SORTIE_PLAYER_RANGE = 1500}; //--- m: a human player must be within this range of the town for a sortie to spawn.
	if (isNil "WFBE_C_GARRISON_SORTIE_PATROL_MIN")    then {WFBE_C_GARRISON_SORTIE_PATROL_MIN = 300};   //--- m: minimum patrol radius around the home town.
	if (isNil "WFBE_C_GARRISON_SORTIE_PATROL_MAX")    then {WFBE_C_GARRISON_SORTIE_PATROL_MAX = 800};   //--- m: maximum patrol radius around the home town.
	if (isNil "WFBE_C_GARRISON_SORTIE_SIZE")          then {WFBE_C_GARRISON_SORTIE_SIZE = 4};           //--- Infantry per sortie group.
	if (isNil "WFBE_C_GARRISON_SORTIE_MAX_ACTIVE")    then {WFBE_C_GARRISON_SORTIE_MAX_ACTIVE = 4};     //--- Hard global cap on concurrently active sorties across the whole map.

//--- AIRFIELD-OWNERSHIP GATE (fable/airfield-ownership-gate, GR-2026-07-06a):
//--- When >0, players may only purchase/spawn aircraft at an airfield the player's own side holds.
//--- Ownership proxy: WFBE_CO_FNC_GetAirfieldOwnerSideID finds the nearest entry in the towns array
//--- within WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS and reads its sideID (set by the capture system).
//--- The airfield depot logic (wfbe_is_airfield=true) is always within ~80m of its companion
//--- LocationLogicAirport (see binding table in PR body). Unbound airfield (radius miss) = ALLOWED.
//--- Flag-off (0) = byte-identical (no gate). AI commander unaffected (AI uses Server_BuyUnit).
	if (isNil "WFBE_C_AIRFIELD_OWNERSHIP_GATE")    then {WFBE_C_AIRFIELD_OWNERSHIP_GATE = 1};    //--- 0=off (default, byte-identical); 1=on (block aircraft purchase at enemy-owned airfields).
	if (isNil "WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS") then {WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS = 500}; //--- m: radius for nearest-town ownership lookup. 500m safely binds each airport to its depot (max separation ~80m on all terrains; nearest non-airfield town is 679m+).

//--- AIRFIELD SERVICE POINT (fable/airfield-service, GR-2026-07-08a): captured airfields only get a
//--- CBR + buy-menu roster today (Client\GUI\GUI_Menu_Service.sqf:314-368 shows only base structures /
//--- repair trucks as service points). When >0, Server_ProvisionAirfieldHangar.sqf also provisions a
//--- rearm/repair/refuel structure at the airfield for its current owner, reusing the exact
//--- WarfareBVehicleServicePoint + WFBE_RepairTruckServicePoint tag pattern the Task-12 real-capture
//--- block in server_town.sqf already builds (WFBE_C_AIRFIELDS, default 1) - GUI_Menu_Service.sqf,
//--- Client_GetRepairTruckServicePoints.sqf and updateavailableactions.fsm already scan for that tag,
//--- so no client-side code changes are needed. Closes the one remaining gap: airfields that start
//--- pre-owned (Init_Town.sqf sideID default) never fire a real capture transition, so they got a
//--- hangar (fable/fix-hangar-aircraft-buy) but no service point until first captured.
//--- Flag-off (0) = byte-identical to HEAD.
	if (isNil "WFBE_C_AIRFIELD_SERVICE") then {WFBE_C_AIRFIELD_SERVICE = 0}; //--- 0=off (default, byte-identical); 1=on (provision a service point at pre-owned airfields too).

//--- FPV STRIKE DRONE (fable/fpv-strike-drone): player-piloted kamikaze mini-UAV bought from the
//--- Tactical Center (sibling of the UAV support call). Client module: Client/Module/FPV/.
//--- Flag-off (0) = no menu row, module exits on entry = byte-identical behavior.
	if (isNil "WFBE_C_FPV_DRONE")      then {WFBE_C_FPV_DRONE      = 1};           //--- Master gate: 0=off, 1=on (default). Lobby param mirrors this. RE-ENABLED (fixwave-20260717): tonight-20260717 safe-fallback reverted alongside the purchase-authority race fix (Support_FPV.sqf seat-replication window 1s->10s + client deny teardown in Client/PVFunctions/HandleSpecial.sqf).
	if (isNil "WFBE_C_FPV_DRONE_COST") then {WFBE_C_FPV_DRONE_COST = 2500};        //--- Purchase price (deducted client-side in fpv.sqf).
	if (isNil "WFBE_C_FPV_DRONE_TTL")  then {WFBE_C_FPV_DRONE_TTL  = 240};         //--- s: battery life; expiry DISARMS then scuttles (no parked bomb).
	if (isNil "WFBE_C_FPV_DRONE_AMMO") then {WFBE_C_FPV_DRONE_AMMO = "R_57mm_HE"}; //--- Warhead ammo class (RPG-warhead scale: hit 150 / indirect 40 / r 12).
	if (isNil "WFBE_C_FPV_CAUSE_LOG")  then {WFBE_C_FPV_CAUSE_LOG  = 1};           //--- fable/fpv-causation (owner 2026-07-28 "AH6J also counts as suicide chopper - misattribution evidence ledger"): log-only causation evidence, ARMED by default (diagnostic-line policy, zero behavior change - see PR body). Ring write in Support_FPV_Detonate.sqf; FPVCAUSE|v1 diag_log lines in RequestOnUnitKilled.sqf. 0 = fully inert (no ring writes, no log lines).
	if (isNil "WFBE_C_DRONE_TIERS")     then {WFBE_C_DRONE_TIERS     = 0};           //--- fable/uav-tier1-fob (owner drone rulings 2026-08-04, "go for the UAV tier lane" 2026-08-06): MASTER gate for the tiered-drone program. 0 = inert, byte-identical behavior to HEAD (all-sides Tactical FPV row + ungated GUER field launch unchanged). 1 = tier 1 armed: the FPV strike drone becomes GUER-EXCLUSIVE and purchasable only near a live GUER FOB (WFBE_GUER_FOB_ACTIVE ledger). WEST/EAST lose their Tactical row until the tier-2+ FOB shop ships (owner sequencing call, plan PR-4).
	if (isNil "WFBE_C_DRONE_FOB_RANGE") then {WFBE_C_DRONE_FOB_RANGE = 40};          //--- metres from a live GUER FOB ledger entry required to authorize a tier purchase (GuerDrones menu hint + Support_FPV.sqf authoritative server check).

//--- AWACS PLATFORM RADAR (fable/awacs-radar, flag WFBE_C_AWACS default 0, lobby param):
//--- while a CREWED friendly airframe from WFBE_C_AWACS_TYPES is airborne above MINALT the
//--- owning side gets (a) the AAR air picture on the map WITHOUT being near an Anti-Air
//--- Radar structure (gate OR-extension in Common_MarkerLoop.sqf; registry feed OR-extension
//--- in Init_Unit.sqf), and (b) a ground moving-target sweep from the PILOT's client
//--- (Client\Module\AWACS\awacs_spotter.sqf) via the existing 'uav-reveal' path (fuzzed
//--- orange ellipses, size grows with AWACS-to-target distance). Flag-off: watcher never
//--- launched, scan never runs - inert.
	if (isNil "WFBE_C_AWACS")                   then {WFBE_C_AWACS = 1};                   //--- Master gate: 0=off (default), 1=on.
	if (isNil "WFBE_C_AWACS_TYPES")             then {WFBE_C_AWACS_TYPES = ['C130J_US_EP1','MV22','Mi17_TK_EP1','Mi17_Ins','An2_TK_EP1']}; //--- Platform classnames (any side flies them; matched lowercase).
	if (isNil "WFBE_C_AWACS_MINALT")            then {WFBE_C_AWACS_MINALT = 150};          //--- m AGL: radar counts as 'up' above this altitude.
	if (isNil "WFBE_C_AWACS_AIR_SCAN_INTERVAL") then {WFBE_C_AWACS_AIR_SCAN_INTERVAL = 5}; //--- s: per-client re-check cadence for 'friendly AWACS airborne' (map open only).
	if (isNil "WFBE_C_AWACS_GROUND_RANGE")      then {WFBE_C_AWACS_GROUND_RANGE = 6000};   //--- m: ground sweep radius around the AWACS.
	if (isNil "WFBE_C_AWACS_GROUND_DELAY")      then {WFBE_C_AWACS_GROUND_DELAY = 30};     //--- s: between ground sweeps.
	if (isNil "WFBE_C_AWACS_GROUND_MINSPEED")   then {WFBE_C_AWACS_GROUND_MINSPEED = 5};   //--- km/h: MTI floor - only faster-moving targets are painted.

//--- EAST C-130 (fable/east-c130): East/OPFOR buys a captured C-130J via synthetic token EASTV_C130J
//--- (Core_US.sqf registration, Units_CO_RU roster, Client_BuildUnit remap). Gives East a big fixed-wing
//--- radar/AWACS-role platform beside the An-2. Flag-off (0) = token never registered/listed = byte-identical.
	if (isNil "WFBE_C_EAST_C130") then {WFBE_C_EAST_C130 = 1};   //--- Master gate: 0=off (default), 1=on. Lobby param mirrors this.

//--- WFBE_C_PLAYER_TEAMBAR_FIRST (fable/player-teambar-slot 2026-07-07): set player rank to COLONEL
//--- at enrollment/respawn/skin-swap so the A2 command bar sorts them to slot 1 (rank drives bar order;
//--- selectLeader sets the star but does not reorder slots). 1 = enabled (default); 0 = legacy layout.
	if (isNil "WFBE_C_PLAYER_TEAMBAR_FIRST") then {WFBE_C_PLAYER_TEAMBAR_FIRST = 1};
	//--- SMALL-MAP TUNE A/B: conditional first-init defaults; explicit overrides always win.
	if (isNil "WFBE_C_AICOM_COMMIT_COMBAT") then {if (WFBE_AICOM_SMALLMAP_ARMED) then {WFBE_C_AICOM_COMMIT_COMBAT = 1} else {WFBE_C_AICOM_COMMIT_COMBAT = 0}};
	if (isNil "WFBE_C_AICOM_COMMIT_NEAR_DIST") then {WFBE_C_AICOM_COMMIT_NEAR_DIST = 500};
	if (isNil "WFBE_C_AICOM_RETARGET_COOLDOWN") then {if (WFBE_AICOM_SMALLMAP_ARMED) then {WFBE_C_AICOM_RETARGET_COOLDOWN = 600} else {WFBE_C_AICOM_RETARGET_COOLDOWN = 0}};
//--- TEAMBAR probe (card wasp-player-group-rank-order-diagnosis-20260718): reason-coded client+server
//--- instrumentation of the #2-in-own-group mitigation guards. Telemetry-only. Round-2 review:
//--- DEFAULT 0 per feature-default policy - the capture round arms it explicitly.
	if (isNil "WFBE_C_TEAMBAR_PROBE") then {WFBE_C_TEAMBAR_PROBE = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on).
//--- VEHDEL deletion probe (card wasp-vehicle-crew-fast-despawn-20260719): reason-coded telemetry
//--- on every scripted cleanup deleteVehicle of hulls/crew + GetIn/GetOut player-use stamps.
//--- Telemetry-only (no behavior). Round-2 review: DEFAULT 0 per feature-default policy - the
//--- capture round arms it explicitly (set 1 here or via lobby) for the evidence window.
	if (isNil "WFBE_C_VEH_DELETE_PROBE") then {WFBE_C_VEH_DELETE_PROBE = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on).
	//--- C1 stable commander UID/side lease. 0 = legacy instant commander disconnect.
	if (isNil "WFBE_C_CMD_LEASE") then {WFBE_C_CMD_LEASE = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on).
	if (isNil "WFBE_C_CMD_LEASE_GRACE") then {WFBE_C_CMD_LEASE_GRACE = 90};

//--- WFBE_C_SPAWN_BUDDY_DISBAND (wasp-aicom-idle-diagnosis-20260717, owner live report 2026-07-17: "I spawn
//--- with another unit in my group" - AI-Teams pre-grouped squadmate at INITIAL spawn is by-design, but the
//--- owner wants a clean solo spawn). 1 = at INITIAL spawn only (never on respawn - a bought/earned squad is
//--- never touched), any client-local, non-player AI unit already in the fresh player group is silently
//--- disbanded into its own group and left standing (not deleted - still a valid AI asset for the side, just
//--- no longer riding the player's command bar). 0 = legacy behaviour (default; byte-identical to HEAD).
	if (isNil "WFBE_C_SPAWN_BUDDY_DISBAND") then {WFBE_C_SPAWN_BUDDY_DISBAND = 0};
//--- PLAYER BASE DEFENSE AUTO-MANNING (fable/player-defense-automan):
//--- When >0 and a player builds a gunner-capable static inside a base area, the defense is
//--- registered for AI manning via the same Construction_StationaryDefense path as AI-commander
//--- guns (DefenseTeam group, WFBE_DefenseBaseArea stamp, HandleDefense loop). The client toggle
//--- (User16 / manningDefense, default true) still gates each individual build request.
//--- Flag-off (0) = player statics never enter the manning path = current behaviour (byte-identical).
	if (isNil "WFBE_C_PLAYER_DEFENSE_AUTOMAN") then {WFBE_C_PLAYER_DEFENSE_AUTOMAN = 1}; //--- 0=off (current behaviour); 1=on (man player-built base statics, respects client manningDefense toggle).

//--- Build 91 fleet-lane flag registrations (consolidated 2026-07-07; every consumer reads
//--- these with the same inline default, so behavior is identical with or without this block).
	if (isNil "WFBE_C_VEHICLE_SELL") then {WFBE_C_VEHICLE_SELL = 1}; //--- #43: sell-back action on purchased vehicles at base. 0 = no action shown.
	if (isNil "WFBE_C_VEHICLE_SELL_FRACTION") then {WFBE_C_VEHICLE_SELL_FRACTION = 0.5}; //--- #43: refund fraction of purchase price, scaled by hull health.
	//--- #90: client-local range ellipse per friendly artillery piece. Small-map defaults stay
	//--- OFF because the TK/ZG artillery registry contains 8-9km weapons; an explicit pre-set wins.
	if (isNil "WFBE_C_ARTY_RING") then {
		WFBE_C_ARTY_RING = 1;
		if ((toLower worldName) in ["zargabad", "takistan"]) then {WFBE_C_ARTY_RING = 0};
	};
	if (isNil "WFBE_C_ARTY_RING_VISUAL_CAP") then {WFBE_C_ARTY_RING_VISUAL_CAP = 2000}; //--- #90 owner 2026-07-22: cap the DRAWN ring radius (m); real range survives in the marker label. 0 = legacy uncapped.
	if (isNil "WFBE_C_TAGS_AI") then {WFBE_C_TAGS_AI = 1}; //--- TAGS: nametags above friendly AI infantry + vehicles (shares the 18-slot pool).
	if (isNil "WFBE_C_GDIR_VIS") then {WFBE_C_GDIR_VIS = 1}; //--- Commissar visibility pack: wallet label, heatmap, order broadcasts, QRF feedback.
	if (isNil "WFBE_C_GDIR_CELL_SPREAD") then {WFBE_C_GDIR_CELL_SPREAD = 0}; //--- 1 = shuffle moveCell dest lists + transit soft-cap so depleted pressure is not funnelled into the same 2 towns (RPT-DEEPDIVE-20260730: 35.5% into Msta/Shakhovka). 0 = dark (ledger order).
	if (isNil "WFBE_C_GDIR_CELL_SPREAD_TRANSIT_FRAC") then {WFBE_C_GDIR_CELL_SPREAD_TRANSIT_FRAC = 0.45}; //--- skip destination this tick if pending transit already exceeds this fraction of baseline (forces surplus to other depleted towns).
	if (isNil "WFBE_C_ICBM_COUNTDOWN") then {WFBE_C_ICBM_COUNTDOWN = 1}; //--- #78/#455: both-sides HUD countdown to ICBM impact.
	if (isNil "WFBE_C_MISSILE_WARNING") then {WFBE_C_MISSILE_WARNING = 1}; //--- #367/#307: audible warning while an ICBM is in flight.
	if (isNil "WFBE_C_LOADOUT_REGISTRY_SCRUB") then {WFBE_C_LOADOUT_REGISTRY_SCRUB = 1}; //--- #416 cheat fix: strip non-purchasable items from player loadouts on equip.
	if (isNil "WFBE_C_HQ_REPAIR_SCALING") then {WFBE_C_HQ_REPAIR_SCALING = 1}; //--- #185: HQ repair cost 7.5k -> 49.5k over the rolling average round length (profileNamespace WFBE_RPAVG). 0 = legacy 3-tier prices.
	if (isNil "WFBE_C_GUER_PATROL_MARKERS") then {WFBE_C_GUER_PATROL_MARKERS = 1}; //--- owner: resistance-only map intel layer (friendly AI dots + owned-town health flags + inbound cell arrows).
	if (isNil "WFBE_C_UNIT_DESIGNER") then {WFBE_C_UNIT_DESIGNER = 1}; //--- Team-menu Units tab: infantry loadout templates applied to bought AI squad units.
	if (isNil "WFBE_C_SEAD") then {WFBE_C_SEAD = 1}; //--- B93 SEAD: scripted anti-radar guidance for tier-5 jets (F35B/Su34), 2-shot cap. ARMED (1) since 0be461ef4 "feat(flags): arm first-blood, SEAD, camp single-flip, idle-thread skip [owner late window]" (2026-07-07) - merged dark pending Build 93.
	if (isNil "WFBE_C_SEAD_EASA_ROW") then {WFBE_C_SEAD_EASA_ROW = 0}; //--- SEAD as opt-in EASA loadout row (owner ruling 2026-08-02): flag-off keeps auto-attach on player buy (byte-identical); flag-on moves the F35B/Su34 player-buy attach behind the EASA row while AI-spawned tier-5 hulls keep the unconditional auto-attach (AI cannot use the EASA menu). Master gate WFBE_C_SEAD stays the gameplay on/off switch either way.
if (isNil "WFBE_C_RADIUSHOLD_ENABLE") then {WFBE_C_RADIUSHOLD_ENABLE = 1}; //--- fable/radius-hold-primitive (GR-2026-07-08a): master gate for the shared radius-presence-hold primitive (Common_RadiusHold.sqf). ARMED by default (1) since ee3f8193 "release: enable all feature flags at launch" (2026-07-09, owner-authorized) - merged dark (0); 0 refuses every registration and the dispatcher never spawns.
if (isNil "WFBE_C_RADIUSHOLD_TICK_SECS") then {WFBE_C_RADIUSHOLD_TICK_SECS = 5}; //--- fable/radius-hold-primitive: shared dispatcher tick cadence (seconds) for all registered holds.
if (isNil "WFBE_C_RADIUSHOLD_CONTEST_DECAY") then {WFBE_C_RADIUSHOLD_CONTEST_DECAY = 0}; //--- fable/radius-hold-primitive: per-tick progress decay applied only when contestMode=1 while a hold is contested.
if (isNil "WFBE_C_RADIUSHOLD_MAX_ACTIVE") then {WFBE_C_RADIUSHOLD_MAX_ACTIVE = 8}; //--- fable/radius-hold-primitive: hard cap on simultaneously-registered holds.
if (isNil "WFBE_C_NAVALHVT_BUBBLE_ENABLE") then {WFBE_C_NAVALHVT_BUBBLE_ENABLE = 1}; //--- armed 2026-07-27 owner go: KOTH-style carrier capture bubble ON, now that contest mode 2 BEAT-DOWN (#1529) fixes the 2026-07-10 regression this comment used to describe (a carrier ALWAYS carries a GUER garrison, so sole-presence contest read permanently CONTESTED and the bubble never granted deck capture - commit 7ec25d16f5 disarmed it). While armed the camps-on-deck path is skipped entirely (Init_NavalHVT.sqf), so deck camps no longer spawn; capture = beat the garrison down to <= WFBE_C_RADIUSHOLD_BEATDOWN_FLOOR bodies, then hold uncontested for WFBE_C_NAVALHVT_BUBBLE_HOLDSECS (120s, cumulative - pauses while contested, does not reset). Rollback: 0 (restores camps-on-deck capture).
if (isNil "WFBE_C_NAVALHVT_BUBBLE_RADIUS") then {WFBE_C_NAVALHVT_BUBBLE_RADIUS = 180}; //--- fable/radius-hold-primitive: carrier bubble radius (metres) when WFBE_C_NAVALHVT_BUBBLE_ENABLE=1.
if (isNil "WFBE_C_RADIUSHOLD_BEATDOWN_FLOOR") then {WFBE_C_RADIUSHOLD_BEATDOWN_FLOOR = 2}; //--- contest-mode-2 only: the objective owner stops counting toward contest at or below this many bodies present, so an attacker must beat the garrison down before the hold accrues. Owner ruling 2026-07-27 ("garrison has to be beaten down first"). Raise to make carriers harder to take, 0 = must be fully cleared.
if (isNil "WFBE_C_NAVALHVT_BUBBLE_HOLDSECS") then {WFBE_C_NAVALHVT_BUBBLE_HOLDSECS = 120}; //--- fable/radius-hold-primitive: uncontested seconds of eligible presence required to complete the carrier bubble hold.
if (isNil "WFBE_C_ZG_KOTH_ENABLE") then {WFBE_C_ZG_KOTH_ENABLE = 1}; //--- fable/radius-hold-primitive consumer (GR-2026-07-08a, stacked on PR #916): Zargabad KotH city-core hold master flag. ARMED by default (1) since ee3f8193 "release: enable all feature flags at launch" (2026-07-09, owner-authorized) - merged dark (0); map-gated to Zargabad regardless (Init_ZgKoth.sqf).
if (isNil "WFBE_C_ZG_KOTH_RADIUS") then {WFBE_C_ZG_KOTH_RADIUS = 150}; //--- fable/radius-hold-primitive consumer: ZG KotH hold-zone radius (metres) at city core. Owner-TBD, tune after test.
if (isNil "WFBE_C_ZG_KOTH_HOLDSECS") then {WFBE_C_ZG_KOTH_HOLDSECS = 300}; //--- fable/radius-hold-primitive consumer: uncontested seconds of eligible presence to trigger the reward roll. Owner-TBD, tune after test.
if (isNil "WFBE_C_ZG_KOTH_COOLDOWN") then {WFBE_C_ZG_KOTH_COOLDOWN = 180}; //--- fable/radius-hold-primitive consumer: re-arm cooldown after a payout (anti-farm gate). Owner-TBD, tune after test.
	if (isNil "WFBE_C_SCUD_DRIVABLE_ALLMAPS") then {WFBE_C_SCUD_DRIVABLE_ALLMAPS = 1}; //--- fable/scud-chernarus-artillery (owner 2026-07-08): when >0, drop the worldName=="Takistan" gate on the producible/crewed SCUD (Core_TKA.sqf buy-row, Client_BuildUnit.sqf platform wiring, GUI_Menu_BuyUnits.sqf cap check, Init_IcbmTel.sqf WFBE_SE_FNC_TkScudRegister, GUI_Menu_Tactical.sqf TelMuniEnable) so it is purchasable/drivable on every map, not just Takistan. Default 1 = ARMED per owner ask; set 0 to revert to Takistan-only.
	if (isNil "WFBE_C_SCUD_ONE_PER_SIDE") then {WFBE_C_SCUD_ONE_PER_SIDE = 1}; //--- owner refinement 2026-07-08 (fable/scud-chernarus-artillery): when >0, clamps the per-side LIVE bought-SCUD cap to 1 (GUI_Menu_BuyUnits.sqf pre-purchase check + Init_IcbmTel.sqf WFBE_SE_FNC_TkScudRegister server-authoritative check both `min 1` the WFBE_C_TK_SCUD_HF_MAX-derived cap - that flag's own default of 2 is left untouched). Default 1 = ARMED per owner ask (one precious launcher per side); set 0 to fall back to the WFBE_C_TK_SCUD_HF_MAX cap alone.
	if (isNil "WFBE_C_SCUD_SPEED_CAP_KMH") then {WFBE_C_SCUD_SPEED_CAP_KMH = 20}; //--- owner refinement 2026-07-08 (fable/scud-chernarus-artillery): drivable-SCUD top-speed governor in km/h, enforced client-side via periodic setVelocity in Client_BuildUnit.sqf WFBE_CL_FNC_TkScudSpeedGovernor (A2-OA has no setMaxSpeed/limitSpeed - that command is Arma-3-only, mirrors the existing WFBE_CL_FNC_GuerVbiedM113Boost setVelocity idiom in the same file). Intent: the SCUD is slow and precious - players should prefer airlifting it over driving. Set <=0 to disable the governor (stock vehicle top speed).
	if (isNil "WFBE_C_AICOM_NO_BIKES") then {WFBE_C_AICOM_NO_BIKES = 1}; //--- fable/aicom-no-bikes (WO-5): strip ATV/Motorcycle-hull templates from AI commander team founding/buy rosters. GUARDRAIL keeps the original set if stripping would empty it. 0 = legacy behaviour (ATVs remain merely unlikely, not prohibited).


//--- Commander Town Ledger (CTL, fable/ctl-impl-v1): virtual per-town strength ledger
//--- + paid AI investment for WEST/EAST towns. Mirrors GUER Director (Lane 800). Flag-off
//--- (0) = brain never launches, every overlay read site short-circuits = byte-identical.
//--- See docs/design/v2/aicom-v2-commander-town-ledger.md for the full spec.
	if (isNil "AICOMV2_LANE_CMD_TOWN_LEDGER") then {AICOMV2_LANE_CMD_TOWN_LEDGER = 1}; //--- Lane master switch: 0=off (default, byte-identical). owner 2026-07-22: ARMED for soak (live chat ruling) - both 07-09 blockers (New-Bug-A/B) fixed on master via fable/ctl-survivor-bugs; garrison-link pre-armed 07-12. Soak watch = CTLSTAT|v1 telemetry; rollback = this flag back to 0.
	if (isNil "AICOMV2_CTL_TICK_SEC") then {AICOMV2_CTL_TICK_SEC = 30}; //--- Brain tick interval, seconds.
	if (isNil "AICOMV2_CTL_REGEN_FULL_SEC") then {AICOMV2_CTL_REGEN_FULL_SEC = 1800}; //--- Zero-to-baseline regen duration, seconds.
	if (isNil "AICOMV2_CTL_CAPTURE_SEED") then {AICOMV2_CTL_CAPTURE_SEED = 0.25}; //--- Strength at record creation (fresh capture).
	if (isNil "AICOMV2_CTL_SPAWN_MIN_STR") then {AICOMV2_CTL_SPAWN_MIN_STR = 0.25}; //--- Materialization floor - a held town never activates empty.
	if (isNil "AICOMV2_CTL_PAID_MAX") then {AICOMV2_CTL_PAID_MAX = 1.5}; //--- Funded strength cap.
	if (isNil "AICOMV2_CTL_GROUP_BUDGET_MAX") then {AICOMV2_CTL_GROUP_BUDGET_MAX = 120}; //--- Per-side group ceiling at materialization.
	if (isNil "AICOMV2_CTL_INVEST_ENABLE") then {AICOMV2_CTL_INVEST_ENABLE = 1}; //--- AI invest arm sub-flag: 0=off (default).
	if (isNil "AICOMV2_CTL_GARRISON_LINK") then {AICOMV2_CTL_GARRISON_LINK = 1}; //--- ARMED per owner ruling 2026-07-12 ("arm garrison-link after next clean soak" - owner assessed gate MET): 1=on. Connects the town DEFENDER garrison (Server_GetTownGroupsDefender.sqf) to the CTL ledger strength wfbe_ctl_str, mirroring the attacker materialization in Server_GetTownGroups.sqf: a fresh/depleted W/E town garrisons thin (floored at AICOMV2_CTL_SPAWN_MIN_STR), an invested/regenerated town garrisons up toward AICOMV2_CTL_PAID_MAX. STILL DOUBLE-GATED on AICOMV2_LANE_CMD_TOWN_LEDGER>0 - LANE stays owner-disarmed at 0 on live, so this flag alone remains inert until LANE is separately armed. Emits CTLSTAT|v1|<side>|GARRISON. Soak evidence: box-harvest.log 2026-07-12T06:06-08:51Z, err=0/19 samples, fps46-48 held to ai=318.
	if (isNil "AICOMV2_CTL_INVEST_GAIN") then {AICOMV2_CTL_INVEST_GAIN = 0.25}; //--- Strength gained per purchase.
	if (isNil "AICOMV2_CTL_INVEST_COST") then {AICOMV2_CTL_INVEST_COST = 50000}; //--- Repair-tier price.
	if (isNil "AICOMV2_CTL_INVEST_SURGE_MULT") then {AICOMV2_CTL_INVEST_SURGE_MULT = 2}; //--- Surge-tier price multiplier.
	if (isNil "AICOMV2_CTL_INVEST_FLOOR") then {AICOMV2_CTL_INVEST_FLOOR = 250000}; //--- Operating reserve (REQDRAW parity).
	if (isNil "AICOMV2_CTL_INVEST_SURGE_FLOOR") then {AICOMV2_CTL_INVEST_SURGE_FLOOR = 600000}; //--- Rich threshold for above-baseline buys.
	if (isNil "AICOMV2_CTL_INVEST_COOLDOWN") then {AICOMV2_CTL_INVEST_COOLDOWN = 480}; //--- Global seconds between buys per side.
	if (isNil "AICOMV2_CTL_INVEST_TOWN_COOLDOWN") then {AICOMV2_CTL_INVEST_TOWN_COOLDOWN = 1200}; //--- Per-town seconds between buys.
	if (isNil "AICOMV2_CTL_INVEST_HUMAN_OFF") then {AICOMV2_CTL_INVEST_HUMAN_OFF = 1}; //--- Pause AI spend while a human is seated (inert while lane=0).
	if (isNil "WFBE_C_CTL_TELEMETRY") then {WFBE_C_CTL_TELEMETRY = 1}; //--- kimi/ctl-telemetry-20260725: CTL garrison-link EPISODE telemetry (emission sites: Server/FSM/server_town_ai.sqf). 0=off (default - no episode state, no lines, byte-identical to HEAD). 1=on: one CTLSTAT|v1|<side>|ACT line per WEST/EAST ground town-activation episode (town, str at activation, planned groups/units, invest flag) + one CTLSTAT|v1|<side>|DEACT line per deactivation (hold secs, str at deactivation, peak enemy count sampled from the town's own existing per-sweep scan). TELEMETRY ONLY - no ledger/spawn/activation rule changes. Double-gated on AICOMV2_LANE_CMD_TOWN_LEDGER>0 (the system under measurement): silent wherever the lane is off.

//--- P5 CREW-COST TIER-SCALE (fable/crew-cost-tierscale, owner economy pick GR-2026-07-08a): crew-replacement cost
//--- (charged in GUI_Menu_BuyUnits.sqf at all 3 crew-cost points) scales with the crewed vehicle's own buy-price
//--- (QUERYUNITPRICE), the same price lookup the buy menu already uses for _currentCost - no new vehicle-cost
//--- table. WFBE_C_UNITS_CREW_COST (above) remains the floor; the bonus only adds on top and is capped so heavy
//--- air/armor crew never gets punitive. Default 0 = byte-identical flat WFBE_C_UNITS_CREW_COST per head.
	if (isNil "WFBE_C_UNITS_CREW_COST_TIERSCALE") then {WFBE_C_UNITS_CREW_COST_TIERSCALE = 1}; //--- master gate: 0=off (default, flat WFBE_C_UNITS_CREW_COST/head, byte-identical to HEAD), 1=on (scale by vehicle price, see COEF/CAP below).
	if (isNil "WFBE_C_UNITS_CREW_COST_TIERSCALE_COEF") then {WFBE_C_UNITS_CREW_COST_TIERSCALE_COEF = 0.03}; //--- owner-tunable: fraction of the crewed vehicle's QUERYUNITPRICE added per crew head on top of the WFBE_C_UNITS_CREW_COST floor (e.g. a 6500-price tank -> 120+6500*0.03=315/head before the cap; a 400-price jeep -> 120+400*0.03=132/head). Only read while TIERSCALE>0.
	if (isNil "WFBE_C_UNITS_CREW_COST_TIERSCALE_CAP") then {WFBE_C_UNITS_CREW_COST_TIERSCALE_CAP = 400}; //--- owner-tunable: hard per-head ceiling (post-COEF) so the priciest air/armor (e.g. AH64D/A10 at 30-35k) never becomes a punitive crew tax. Only read while TIERSCALE>0.

//--- DELEGHEALTH v2 (fable/deleghealth-v2, GR-2026-07-08a): stateful AI-only delegation-health telemetry
//--- loop (Server/FSM/server_deleghealth.sqf, spawned from Init_Server.sqf). Truthful replacement for the
//--- structurally-unfireable DELEGATION-DEAD alert (server_groupsGC.sqf:567 demands remote==0 over an
//--- allUnits census that includes players and HC avatar bodies, so it can never fire while a human is
//--- connected - proven blind on the measured 2026-07-09 double-HC-bounce collapse, remotePct 89->7).
//--- Telemetry ONLY: no delegation behavior change, DELEGSTAT untouched, RPT lines only (never a Peach+ alert).
	if (isNil "WFBE_C_DELEGHEALTH") then {WFBE_C_DELEGHEALTH = 0}; //--- master gate: 0=off (default - Init_Server never spawns the loop; runtime byte-identical to HEAD), 1=on (60s DELEGHEALTH|v2 AI-only per-owner tally + hysteretic HEALTHY/DEGRADED/COLLAPSED state lines, server only).
//--- fable/smallarms-air-envelope (GR-2026-07-08a): effectiveness-scaled small-arms x AIR engagement
//--- envelope. A NON-AA (small-arms) unit's lock on an aircraft it cannot damage is CLEARED
//--- (doTarget/doWatch objNull) ONLY when the aircraft is BEYOND the effective range - within range it
//--- still shoots (point-blank heli = everyone fires). Steering runs in the per-machine manager
//--- Common_AICOM_SmallArmsAirEnvelope.sqf (server + HC); the classifier is stamped at spawn
//--- (WFBE_effAntiAir). NOT sim/distance-gating: distance is unit<->its-air-target, never unit<->player;
//--- simulation is never frozen (precedent: the shipped default-ON B60 HELI CANNON-NUDGE). Master 0 =
//--- manager never starts + no spawn stamp = runtime byte-identical to HEAD.
	if (isNil "WFBE_C_SMALLARMS_AIR_ENVELOPE") then {WFBE_C_SMALLARMS_AIR_ENVELOPE = 1}; //--- master gate: 0=off (default), 1=on.
	if (isNil "WFBE_C_SMALLARMS_AIR_ENVELOPE_RANGE") then {WFBE_C_SMALLARMS_AIR_ENVELOPE_RANGE = 300}; //--- small-arms x Air effective envelope, metres (tunable); beyond this a small-arms unit is steered off an air lock.
	if (isNil "WFBE_C_SMALLARMS_AIR_ENVELOPE_TICK") then {WFBE_C_SMALLARMS_AIR_ENVELOPE_TICK = 5}; //--- manager sweep cadence, seconds (tunable, 4-8s band).

//--- perf/aicom-strategy-towncache (draft PR): opt-in per-call memoization for the redundant
//--- "nearest own town" distance recompute in AI_Commander_Strategy.sqf (4 sites re-scan
//--- _ownTownObjs for the same candidate town within one Strategy call - initial spearhead
//--- scorer, stall re-pick, front telemetry, AICOMDBG trace). Default 0 = every site keeps its
//--- ORIGINAL untouched computation, byte-identical to HEAD. For the matched before/after
//--- PerformanceAudit A/B only - do not flip on live before that A/B + a gameplay-invariant
//--- check confirm the cached and uncached paths pick identical targets.
	if (isNil "WFBE_C_AICOM_STRATEGY_TOWNCACHE") then {WFBE_C_AICOM_STRATEGY_TOWNCACHE = 1}; //--- master gate: 0=off (default, byte-identical to HEAD), 1=on (memoize _dNear per candidate town for this Strategy call only - perf A/B test only).
//--- CLIENT DOUBLE-TAP W AUTORUN (owner QoL, client-local): default ON; movement remains engine-owned and the
//--- handler always returns false. The A2 OA 1.64 stock rifle-lowered run animation supplies root motion.
if (isNil "WFBE_C_CLIENT_AUTORUN") then {WFBE_C_CLIENT_AUTORUN = 1};

//--- CLIENT FRAME-PACING TELEMETRY (codex-gaming-lane-2, 2026-07-13): local RPT-only baseline.
//--- 0 = no sampler VM, no diag_fps reads, no entity scan and no network traffic.
if (isNil "WFBE_C_CLIENT_FRAME_TELEMETRY") then {WFBE_C_CLIENT_FRAME_TELEMETRY = 1};
//--- CHAT RELAY REWORK (server-observable fallback, 2026-07-21): the OA 1.64 display-24 client hook
//--- is not proven by repository/config evidence, so free chat stays blocked-pending-BE. This dark flag
//--- only permits server-observable event lines (kills, joins/leaves, town flips, and round end).
if (isNil "WFBE_C_CHAT_RELAY") then {WFBE_C_CHAT_RELAY = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on).

if (isNil "WFBE_C_CLIENT_FRAME_TELEMETRY_INTERVAL") then {WFBE_C_CLIENT_FRAME_TELEMETRY_INTERVAL = 60};
//--- FORWARD FOB (owner rulings 2026-07-17; spec FORWARD-FOB-SPEC-20260717.md; OWNER CORRECTION 2026-07-17
//--- same day - v1 wrongly built from the supply truck, corrected to the repair truck before ship). A
//--- WEST/EAST repair truck can build a forward base: the per-side forward-camp tent (WFBE_%1FARP - already
//--- declared by every faction config, read by nothing else) as a real LocationLogicCamp bunker, plus a
//--- Land_Vysilac_FM mast beside it. v1 effects: forward respawn, gear resupply, a vehicle repair bubble and
//--- a side-scoped hostile-proximity ping. The repair truck is KEPT (not consumed) by default - it deploys
//--- the FOB and drives away. OWNER 2026-07-28: 'enabled by default' - the master gate ships at 1. Set it to
//--- 0 to fully disable: no addAction is ever attached, the PVF and both server functions return immediately
//--- and no loop spawns -> byte-identical to HEAD.
if (isNil "WFBE_C_STRUCTURES_FOB") then {WFBE_C_STRUCTURES_FOB = 1};             //--- master gate. 1 = ON (owner intent 2026-07-28); 0 = off (kill switch, byte-identical to HEAD).
if (isNil "WFBE_C_FOB_COST") then {WFBE_C_FOB_COST = 25000};                     //--- cash cost (owner ruling 2), charged server-side.
if (isNil "WFBE_C_FOB_CAP_PER_SIDE") then {WFBE_C_FOB_CAP_PER_SIDE = 2};         //--- hard per-side cap on ALIVE FOBs (owner ruling 2).
if (isNil "WFBE_C_FOB_MIN_RANGE") then {WFBE_C_FOB_MIN_RANGE = 370};             //--- min distance from a base area = WFBE_C_BASE_AREA_RANGE(250) + WFBE_C_BASE_HQ_BUILD_RANGE(120).
if (isNil "WFBE_C_FOB_BUILD_DIST") then {WFBE_C_FOB_BUILD_DIST = 22};            //--- metres in front of the truck (mirrors WFBE_C_GUER_FOB_BUILD_DIST).
if (isNil "WFBE_C_FOB_BUILD_RANGE") then {WFBE_C_FOB_BUILD_RANGE = 30};          //--- max player->truck distance to use the action.
if (isNil "WFBE_C_FOB_ANTENNA") then {WFBE_C_FOB_ANTENNA = "Land_Vysilac_FM"};   //--- identity mast; already live as the Radio Tower model (Structures_CO_US.sqf:112).
if (isNil "WFBE_C_FOB_CONSUME_TRUCK") then {WFBE_C_FOB_CONSUME_TRUCK = 0};       //--- 0 = keep the repair truck on a successful build (it deploys the FOB and drives away). Tunable; 1 restores the old "truck became the FOB" consume behaviour.
if (isNil "WFBE_C_FOB_PING_RADIUS") then {WFBE_C_FOB_PING_RADIUS = 300};         //--- hostile-detection radius for the ping (placeholder, tune during soak).
if (isNil "WFBE_C_FOB_PING_INTERVAL") then {WFBE_C_FOB_PING_INTERVAL = 15};      //--- seconds between GetHostilesInArea polls (placeholder, tune during soak).
if (isNil "WFBE_C_FOB_SERVICE_RADIUS") then {WFBE_C_FOB_SERVICE_RADIUS = 30};    //--- vehicle repair-bubble radius.
if (isNil "WFBE_C_FOB_SERVICE_STEP") then {WFBE_C_FOB_SERVICE_STEP = 0.05};      //--- damage removed per poll from a friendly stopped vehicle in range.
//--- Tent survivability. Camp_EP1 inherits armor=250 from Strategic, where the town-camp models this mission
//--- already uses are deliberately tanky (WarfareBCamp 20000, Land_Fort_Watchtower_EP1 2500) - so an
//--- un-scaled $25k capped FOB would die to small arms. Same divisor idiom as WFBE_C_CAMP_HEALTH_COEF
//--- (Init_Town.sqf:137-140): incoming damage is divided by this. Still destructible (owner ruling 2) -
//--- it just takes a real raid rather than a passing burst. Tune during soak.
if (isNil "WFBE_C_FOB_HEALTH_COEF") then {WFBE_C_FOB_HEALTH_COEF = 10};          //--- incoming-damage divisor for the FOB tent.
if (isNil "WFBE_C_FOB_COLLISION_COEF_MULT") then {WFBE_C_FOB_COLLISION_COEF_MULT = 8}; //--- EXTRA divisor for ammo-less (collision) damage on the FOB tent - owner report 2026-08-04: a truck bump one-shot a $25k FOB through the /10 coef. Collision now /80 total: parking mistakes survivable, deliberate weapon fire unchanged.

//--- AICOM AIR-FOUNDING TELEMETRY (P1.1 diagnosis, claude 2026-07-19; wording corrected 2026-07-19 per
//--- codex-main-sol-review-airpower-20260719 REJECT "not literal byte/execution identity"): reason-coded
//--- founding/air-cap evidence so the live "zero AICOM air / zero VEHLIFT" blocker is identified BEFORE any air
//--- tuning (instrument-first, per the independent AICOM audit synthesis SHA256 2D50EA13...). 0 = OFF (default)
//--- => no probe, no vehicle scan, no AICOMAIR diag_log token anywhere (founding worker, air-mobile gate,
//--- veh-lift) => behaviour-equivalent to HEAD (identical AI decisions, RNG draws, positions, gameplay outcomes).
//--- NOT literal byte/execution identity: these two constants are still declared here unconditionally (the same
//--- always-declare-default pattern every other WFBE_C_* flag in this file uses) and every call site still runs
//--- one getVariable check per cycle even when off - kept live-toggleable via debug console (see Init_Common.sqf
//--- WFBE_CO_FNC_AICOMAirFoundTelemetry comment) rather than compile-gated, which would be a truer no-op but would
//--- break that testing workflow. 1 = emit AICOMAIR|v1| lines (founding terminal outcome + throttled at-target
//--- snapshot + air-mobile/veh-lift lifecycle reasons). DIAGNOSTIC ONLY - changes NO founding, cap, bucket, or
//--- airlift behaviour.
	if (isNil "WFBE_C_AICOM_AIR_TELEMETRY") then {WFBE_C_AICOM_AIR_TELEMETRY = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on).
	if (isNil "WFBE_C_AICOM_AIR_TELEMETRY_SEC") then {WFBE_C_AICOM_AIR_TELEMETRY_SEC = 30}; //--- min seconds between periodic at-target air snapshots per side (founding-decision + attempt events are not throttled).
//--- AICOM ARTILLERY ECHELON (claude 2026-07-18): explicit per-side state machine for the BASE-built
//--- self-propelled AICOM guns (AI_Commander_Base.sqf builds them in a 25-38m ring around HQ;
//--- AI_Commander_Strategy.sqf block 4 fires them). LIVE evidence (wasp-aicom-live-20260718): EAST built
//--- artillery 23x but fired only 8 missions, none after minute 583, because the fire block only ever
//--- DISCOVERS pieces within 250m of HQ and the guns never move - so once the front advances past a gun's
//--- max range it silently polls forever; WEST additionally spammed ~1330 ineligible base-build skip logs.
//--- Flag ON: (a) each constructed gun is REGISTERED on an explicit per-side list (wfbe_aicom_arty_reg)
//--- that also drives the self-heal cap count, so a gun that repositioned forward past WFBE_C_BASEGC_RANGE
//--- is still tracked and NOT double-built; (b) a registered gun that cannot service the current target is
//--- REPOSITIONED via PlaceSafe (the shipped relocation primitive - same as the tactical travel-with
//--- teleport) to a SAFE owned-town anchor in range + behind the front, emitting ONE explicit REPOSITION
//--- transition instead of silent polling; (c) the base build-skip log is debounced to one line per state
//--- transition. Master 0 = every path keeps its ORIGINAL computation (near-HQ discovery, per-pass skip
//--- log, no reposition) => runtime byte-identical to HEAD. Base guns are gunner-only emplacements (no
//--- driver), so PlaceSafe redeploy is used rather than a road-march waypoint. Does NOT touch the separate
//--- HC mobile battery (Common_RunCommanderTeam.sqf ~2567) - that path is unproven-absent, not disabled.
	if (isNil "WFBE_C_AICOM_ARTY_ECHELON") then {WFBE_C_AICOM_ARTY_ECHELON = 1}; //--- ARMED (owner ruling 2026-07-21: everything flags on). master gate: 1=on (registry + forward reposition + debounced skip log); 0 reverts to the legacy byte-identical path.
	if (isNil "WFBE_C_AICOM_ARTY_ECHELON_REPOS_CD") then {WFBE_C_AICOM_ARTY_ECHELON_REPOS_CD = 180}; //--- s: minimum seconds between reposition redeploys for ONE gun (anti-thrash / bounds the owned-town scan cadence).
	if (isNil "WFBE_C_AICOM_ARTY_ECHELON_SAFE_DIST") then {WFBE_C_AICOM_ARTY_ECHELON_SAFE_DIST = 400}; //--- m: no enemy may be within this radius of the gun (never redeployed OUT of a firefight) or of a candidate anchor town (never INTO one).
	if (isNil "WFBE_C_AICOM_ARTY_ECHELON_MIN_STANDOFF") then {WFBE_C_AICOM_ARTY_ECHELON_MIN_STANDOFF = 500}; //--- m: keep the anchor at least this far from the target (never redeploy the gun on top of the objective).
//--- ============================================================================================
//--- COMMAND V2 nudge extensions (P4 design docs/design/COMMAND-V2-NUDGE-SYSTEM-DESIGN.md, owner
//--- decision packet 2026-07-18). Three independent mechanics, each behind its OWN master flag at
//--- default 0: with all three at 0 the mission is byte-identical to HEAD (every new read sits
//--- INSIDE a "> 0" master-flag branch; no new per-frame scan, no new PVF top-level name - the new
//--- verbs are sub-verbs of the already-allowlisted RequestSpecial bus). The sub-parameters below
//--- carry non-zero tuning defaults but are only ever read once their master flag is on.
//--- ============================================================================================
//--- (a) TOWN NUDGE - soft, weighted, TTL-decayed town suggestion from any live player. Biases the
//---     v2 fist scorer (AI_Commander_Allocate.sqf); it never sets wfbe_aicom_focus and never pins.
if (isNil "WFBE_C_CMD_TOWN_NUDGE")             then {WFBE_C_CMD_TOWN_NUDGE = 1};              //--- ARMED (owner ruling 2026-07-21: everything flags on). master: 1 = on; 0 reverts to verb-rejected/scorer-term-unread (byte-identical).
if (isNil "WFBE_C_CMD_TOWN_NUDGE_WEIGHT")      then {WFBE_C_CMD_TOWN_NUDGE_WEIGHT = 120};     //--- scorer bonus at full aggregated weight. Owner 2026-07-18: start ~120 and soak-tune. Deliberately < WFBE_C_AICOM_GRUDGE_BONUS(400) so a nudge breaks a near-tie, never forces a bad target. Inert while _TOWN_NUDGE = 0.
if (isNil "WFBE_C_CMD_TOWN_NUDGE_CAP")         then {WFBE_C_CMD_TOWN_NUDGE_CAP = 3};          //--- HARD SAFETY CEILING on aggregated nudge units per town (owner 2026-07-18: sqrt(n) AND a hard ceiling). sqrt() is applied first, then this clamp.
if (isNil "WFBE_C_CMD_TOWN_NUDGE_TTL")         then {WFBE_C_CMD_TOWN_NUDGE_TTL = 240};        //--- s a town nudge stays live; its weight decays LINEARLY to 0 across this window.
if (isNil "WFBE_C_CMD_TOWN_NUDGE_COOLDOWN")    then {WFBE_C_CMD_TOWN_NUDGE_COOLDOWN = 90};    //--- s per-UID anti-spam cooldown between town nudges.
if (isNil "WFBE_C_CMD_TOWN_NUDGE_RING")        then {WFBE_C_CMD_TOWN_NUDGE_RING = 16};        //--- max live nudge records kept per side (bounded ring, oldest evicted) - caps both memory and the per-tick aggregation cost.
//--- (b) TEAM DOCTRINE - per-team aggressive/defensive/garrison stance nudge. Owner 2026-07-18:
//---     NO leader-only gate - any eligible nearby player may nudge, with anti-spam + receipts.
if (isNil "WFBE_C_CMD_TEAM_DOCTRINE")          then {WFBE_C_CMD_TEAM_DOCTRINE = 1};           //--- ARMED (owner ruling 2026-07-21: everything flags on). master: 1 = on; 0 reverts to verb-rejected/stamp-never-written (byte-identical). HONEST SCOPE NOTE (review 2026-07-19, still true post-arming): the per-team stamp (Server_HandleSpecial.sqf) has NO consumer anywhere in this tree yet - AssignTowns/Allocate do not read it. Arming this flag only turns on the stamping side-effect; it does not yet bias allocator behavior.
if (isNil "WFBE_C_CMD_TEAM_DOCTRINE_COOLDOWN") then {WFBE_C_CMD_TEAM_DOCTRINE_COOLDOWN = 90}; //--- s per-UID anti-spam cooldown between team-doctrine nudges.
if (isNil "WFBE_C_CMD_POSTURE_GARRISON")       then {WFBE_C_CMD_POSTURE_GARRISON = 1};        //--- ARMED (owner ruling 2026-07-21: everything flags on). 1 = the side-posture verb also accepts "GARRISON"; 0 reverts to the PUSH/HOLD-only whitelist (byte-identical). TRUTHFUL SCOPE NOTE (still true post-arming): GARRISON currently applies the HOLD engage-gate bias plus a defensive lean ONLY - the town-garrison SORTIE loop from docs/design/GARRISON-SORTIE-PATROL-DESIGN.md is NOT implemented anywhere in this tree (no WFBE_C_GARRISON_SORTIE* flag exists), so there is nothing to reuse yet.
//--- (c) SUPPORT AIR - player requests an already-owned AI heli team as escort. Owner 2026-07-18:
//---     FREE loan (no requisition fee, no refund path); anti-abuse is cooldown + caps + telemetry.
if (isNil "WFBE_C_CMD_SUPPORT_AIR")            then {WFBE_C_CMD_SUPPORT_AIR = 1};             //--- ARMED (owner ruling 2026-07-21: everything flags on). master: 1 = on; 0 reverts to verb-rejected/no-escort-loop-spawned (byte-identical).
if (isNil "WFBE_C_CMD_SUPPORT_AIR_TTL")        then {WFBE_C_CMD_SUPPORT_AIR_TTL = 300};       //--- s max escort duration before the team auto-returns to autonomy.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_RANGE")      then {WFBE_C_CMD_SUPPORT_AIR_RANGE = 6000};    //--- m MAX FERRY distance: an eligible heli team further than this from the requester is not granted. Deliberately large (a heli flies in from base - unlike the ground WFBE_C_CMD_NUDGE_RANGE gate); the ferry distance of every grant is logged so a tighter cap can be set from soak telemetry.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_FOLLOW_INT") then {WFBE_C_CMD_SUPPORT_AIR_FOLLOW_INT = 20}; //--- s escort re-issue interval (periodic re-goto, NOT a per-frame attach or engine doFollow on a player).
if (isNil "WFBE_C_CMD_SUPPORT_AIR_MAX_ACTIVE") then {WFBE_C_CMD_SUPPORT_AIR_MAX_ACTIVE = 1};  //--- side-wide cap on concurrently granted support-heli teams (protects the AICOM fist/economy). Additionally hard-capped at one active grant per player UID.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_COOLDOWN")   then {WFBE_C_CMD_SUPPORT_AIR_COOLDOWN = 180};  //--- s per-UID cooldown between heli support requests. Started on GRANT *and* on NONE so a denied request cannot be re-spammed.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_CAS_RANGE")  then {WFBE_C_CMD_SUPPORT_AIR_CAS_RANGE = 500}; //--- m DIRECT-THREAT radius around the holder for kind "cas-heli". Owner 2026-07-18 chose the SAFE ROE: escort/orbit + respond to threats this close to the holder; the heli does NOT free-hunt the map. Widen only from telemetry.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_RECALL")     then {WFBE_C_CMD_SUPPORT_AIR_RECALL = 1};      //--- owner 2026-07-18: AICOM MAY recall a granted heli for a last-stand / HQ emergency. 1 = recall allowed, 0 = a grant is inviolable for its TTL. Only read while _SUPPORT_AIR > 0.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_RECALL_HYST")then {WFBE_C_CMD_SUPPORT_AIR_RECALL_HYST = 60};//--- s HYSTERESIS: the emergency must have been continuously true for this long before a recall fires, and no new grant is issued on the side for this long after one. Prevents flapping grants on a blinking last-stand flag.
if (isNil "WFBE_C_CMD_SUPPORT_AIR_MIN_ALT")    then {WFBE_C_CMD_SUPPORT_AIR_MIN_ALT = 120};   //--- m flyInHeight used for the escort orbit (transport stands off higher than a CAS pass).
if (isNil "WFBE_C_CMD_SUPPORT_JET")            then {WFBE_C_CMD_SUPPORT_JET = 0};             //--- RESERVED, not implemented: 0 = the "cas-jet"/"transport-jet" request kinds are parsed and explicitly REJECTED with telemetry so the UI can grey them instead of silently dropping. There is no jet grant path in this build; setting this to 1 does NOT create one.
//--- (d) TEAM STATUS STRIP (Grok idea #26, build round 2 2026-07-25): appends a one-line "Order/Target/Stuck"
//---     readout for the SELECTED war-room roster team onto the 14600 economy header (GUI_Menu_Command.sqf).
//---     Pure client read of already-broadcast AICOM vars - zero server changes. Default 0 = the read block is
//---     skipped entirely and the header is byte-identical to pre-feature HEAD.
if (isNil "WFBE_C_CMD_TEAM_STATUS")            then {WFBE_C_CMD_TEAM_STATUS = 1};              //--- master flag: 1 = on. 0 reverts GUI_Menu_Command.sqf's 14600 repaint to byte-identical pre-feature output.

//--- COMMANDER TOOLING (fable/cmd-troopmon-freelook): two independent client-only modules for the human
//---     commander. Both are pure additive GUI/camera work with no server footprint; 0 = mission is
//---     byte-identical to HEAD (no new controls admitted, no camera ever created). Owner note: an
//---     unrelated Spectator v8 lane is in flight on separate staged branches - these two flags/files
//---     are their own module and never touch Client_SpectatorEnter/Director/Attach/Exit.sqf.
//--- (e) TROOP MONITOR - filterable read-only roster dialog (RscMenu_TroopMon / GUI_Menu_TroopMon.sqf).
//---     Reuses the SAME own-side team registry resolve as the war-room roster (GUI_Menu_Command.sqf);
//---     Client_TroopMonBuildList.sqf builds its row array on a cached timer rather than a full rescan
//---     on every dialog open / filter change (WFBE_C_COMMANDER_TROOPMON_REFRESH gates the rebuild).
if (isNil "WFBE_C_COMMANDER_TROOPMON")          then {WFBE_C_COMMANDER_TROOPMON = 1}; //--- ARMED 2026-08-03 owner go (wave0803c)
if (isNil "WFBE_C_COMMANDER_TROOPMON_REFRESH")  then {WFBE_C_COMMANDER_TROOPMON_REFRESH = 2}; //--- s minimum cache age before the roster array is rebuilt; a dialog open/filter change inside this window reuses the cached array untouched.
//--- (f) RECON CAM - free-flying commander camera (Client_CommanderFreelook.sqf). Commander-only;
//---     cleanly returns control to the player's own body on exit (ESC, death, lost commander seat,
//---     or the flag going to 0 mid-flight all tear it down the same way).
if (isNil "WFBE_C_COMMANDER_CAM")               then {WFBE_C_COMMANDER_CAM = 1}; //--- ARMED 2026-08-03 owner go (wave0803c)
if (isNil "WFBE_C_COMMANDER_CAM_SPEED")         then {WFBE_C_COMMANDER_CAM_SPEED = 25};      //--- m/s base fly speed.
if (isNil "WFBE_C_COMMANDER_CAM_SPEED_FAST")    then {WFBE_C_COMMANDER_CAM_SPEED_FAST = 75}; //--- m/s fly speed while the sprint key is held.
if (isNil "WFBE_C_COMMANDER_CAM_MAX_ALT")       then {WFBE_C_COMMANDER_CAM_MAX_ALT = 400};   //--- m altitude ceiling above the terrain directly under the camera.

//--- TRASH-OBJECT LOCALITY (2026-07-21 hardening extras): Common_TrashObject.sqf ends in an unconditional
//--- deleteVehicle, which SILENTLY NO-OPS on an object that is not local to the machine running it - the same
//--- documented A2-OA fact the BASE-GC and the commander-artillery wreck reaper already guard against with
//--- their own `local` checks (server_groupsGC.sqf L224/L276/L391). Every TrashObject caller runs server-side,
//--- so any HC-local body or hull it is handed is never actually removed and persists for the match. 1 = gate
//--- on locality and route non-local deletes to the owning machine over the existing HandleSpecial channel;
//--- 0 retains the unconditional legacy deleteVehicle for emergency rollback. Ships default 1.
if (isNil "WFBE_C_TRASH_REMOTE_DELETE") then {WFBE_C_TRASH_REMOTE_DELETE = 1};

//--- HS-TRACE (picklist 4 phase 1, 2026-07-22): dispatch-entry breadcrumb for the RequestSpecial
//--- command bus. 1 = diag_log request type + argc at each dispatch into Server_HandleSpecial
//--- (RPT attribution for the next mid-match burn); 0 = INERT, no logging, dispatch byte-identical.
//--- Ships default 0.
if (isNil "WFBE_C_HS_DISPATCH_LOG") then {WFBE_C_HS_DISPATCH_LOG = 1}; //--- ARMED (owner ruling 2026-07-22 22:04: ship flagged on).
//--- HC-DELEGATION SELF-HEAL (wasp-hc-delegation-collapse-20260722; live hit wave0722g: one HC out of
//--- the registry for a whole round - HCSTAT 1u/0g flat vs 185u/32g on the survivor - while its
//--- orphaned AICOM teams froze forever and charged TOPUP requests were never spawned or refunded).
//--- Three independent slices, each behind its OWN master flag at default 0: with all three at 0 no
//--- healer loop spawns, no heartbeat publishes and every touched path keeps its original
//--- computation (the constants below are declared unconditionally like every other WFBE_C_* flag;
//--- sub-tunables are only read while their master is on).
	if (isNil "WFBE_C_HCREG_HEAL") then {WFBE_C_HCREG_HEAL = 1}; //--- ARMED (owner 2026-07-23: re-register the starved HC so foundings balance across both HCs - the live AFK-teams root cause). //--- SLICE 1 master: the isNil fallback above is 1 (ARMED, owner 2026-07-23) - Init_Server DOES spawn Server\FSM\server_hcreg_heal.sqf by default; this tail previously claimed 0=default, which was wrong. 0=off, 1=on (60s sweep: a connected HC with a fresh HCSTAT heartbeat that is missing from WFBE_HEADLESSCLIENTS_ID for > WFBE_C_HCREG_HEAL_WAIT s gets the connected-hc registration re-run server-side; HCREG|v1 lines).
	if (isNil "WFBE_C_HCREG_HEAL_WAIT") then {WFBE_C_HCREG_HEAL_WAIT = 120}; //--- s an HC must be continuously unregistered before a heal fires; also the per-owner retry cooldown. Only read while WFBE_C_HCREG_HEAL > 0.
	if (isNil "WFBE_C_AICOM_ORPHAN_HEAL") then {WFBE_C_AICOM_ORPHAN_HEAL = 1}; //--- ARMED (owner 2026-07-23: sweep+re-drive teams orphaned when an HC drops). //--- SLICE 2 master: 0=off (default - no sweep loop, no heartbeat publish), 1=on (Common_RunCommanderTeam publishes wfbe_aicom_hb_t ~60s; Server\FSM\server_aicom_orphan_heal.sqf sweeps 60s for dead-thread wfbe_aicom_hc teams: stale-topup refund + wiped-slot release + never-moved force-recycle + player-safe field retire; HCHEAL|v1 lines).
	if (isNil "WFBE_C_AICOM_ORPHAN_STALE") then {WFBE_C_AICOM_ORPHAN_STALE = 180}; //--- s heartbeat age that marks a founding thread dead (3 missed ~60s beats). Only read while WFBE_C_AICOM_ORPHAN_HEAL > 0.
	if (isNil "WFBE_C_AICOM_ORPHAN_NEVERMOVED") then {WFBE_C_AICOM_ORPHAN_NEVERMOVED = 50}; //--- m max leader distance from the journey-start pos under which an orphan counts as never-moved (pad-frozen) and may be force-recycled bypassing the proximity/combat vetoes. Only read while WFBE_C_AICOM_ORPHAN_HEAL > 0.
	if (isNil "WFBE_C_AICOM_STRAND_FASTRECYCLE") then {WFBE_C_AICOM_STRAND_FASTRECYCLE = 0}; //--- SLICE 3 master: 0=off (default - byte-identical +1 failed-journey path), 1=on (a STRANDED closure that moved < WFBE_C_AICOM_STRAND_FAST_MOVED m from journey start counts DOUBLE toward WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE; AI_Commander_AssignTowns.sqf).
	if (isNil "WFBE_C_AICOM_STRAND_FAST_MOVED") then {WFBE_C_AICOM_STRAND_FAST_MOVED = 50}; //--- m moved-from-start threshold for the double count. Only read while WFBE_C_AICOM_STRAND_FASTRECYCLE > 0.
//--- AICAP MID/HIGH TRIM (2026-07-22): default-off conservative cap trim derived from the 282-sample
//--- WASPSCALE AI_TOT-vs-FPS scatter knee. 0 retains the legacy CH/TK [140,130,100,80] cap array
//--- verbatim; 1 applies MID 130->115 and HIGH 100->90. Zargabad keeps its dedicated governor array.
if (isNil "WFBE_C_AICAP_MIDHIGH_TRIM") then {WFBE_C_AICAP_MIDHIGH_TRIM = 0};
if (WFBE_C_AICAP_MIDHIGH_TRIM > 0) then {
	if (worldName != "Zargabad") then {
		WFBE_C_TOTAL_AI_MAX_BY_TIER = [140,115,90,80];
	};
};
//--- SATCHEL-TK (wiring-sweep 2026-07-22): Client_FNC_OnFired.sqf (satchel team-kill-near-structure
//--- detection: deletes a satchel placed within 30m of a friendly structure/HQ + broadcasts the
//--- StructureTK chat callout) has been compiled since the original import but was never attached to
//--- any Fired EH, so the feature silently never worked. 1 = attach WFBE_CL_FNC_OnFired to the player
//--- body Fired EH (initial spawn + respawn); 0 = INERT, no EH attached, byte-identical current
//--- behaviour. OWNER CALL: flip to 1 to enable, or delete Client_FNC_OnFired.sqf wholesale. Ships default 0.
if (isNil "WFBE_C_SATCHEL_TK_DETECT") then {WFBE_C_SATCHEL_TK_DETECT = 0};
//--- wave0723c casualty recovery: owner-approved performance and garrison/GDIR fixes.
if (isNil "WFBE_C_AIRDEF_CHUNKED") then {WFBE_C_AIRDEF_CHUNKED = 1};
if (isNil "WFBE_C_AIRDEF_CHUNK_SLEEP") then {WFBE_C_AIRDEF_CHUNK_SLEEP = 0.4};
//--- perf/aicom-scan-chunking (2026-07-27): flag-gate the guer_airdef_cycle chunkSleep/slice pattern for the
//--- AI_Commander_Strategy.sqf + AI_Commander_Teams.sqf commander-tick scans. Default 0 = OFF = byte-identical
//--- to HEAD (no yields, no slice telemetry, wall-clock record unchanged). Flip to 1 for the matched
//--- before/after PerformanceAudit A/B; SLEEP is the per-section yield in seconds (mirror of WFBE_C_AIRDEF_*).
if (isNil "WFBE_C_AICOM_SCAN_CHUNKED") then {WFBE_C_AICOM_SCAN_CHUNKED = 1}; //--- armed 2026-07-27 owner go.
if (isNil "WFBE_C_AICOM_SCAN_CHUNK_SLEEP") then {WFBE_C_AICOM_SCAN_CHUNK_SLEEP = 0.4};
if (isNil "WFBE_C_AIRENV_CHUNKED") then {WFBE_C_AIRENV_CHUNKED = 1};
if (isNil "WFBE_C_AIRENV_CHUNK_SLEEP") then {WFBE_C_AIRENV_CHUNK_SLEEP = 0.1};
if (isNil "WFBE_C_GARRISON_CAP_GATE") then {WFBE_C_GARRISON_CAP_GATE = 1};
if (isNil "WFBE_C_GDIR_CONTRACTS_FIX") then {WFBE_C_GDIR_CONTRACTS_FIX = 1};

//--- ACR CONTENT GAP (owner 2026-07-24): opt-in registration of the Czech static-defense
//--- trio and player gear-menu exposure. Full ACR must first be unlocked on the live host;
//--- 0 keeps the pre-existing catalog and gear lists unchanged.
if (isNil "WFBE_C_ACR_CONTENT_GAP") then {WFBE_C_ACR_CONTENT_GAP = 1}; //--- ARMED 2026-07-28 (owner "lift the ACR shelf" 09:15): activates the proven+priced ACR statics (DSHKM_CZ_EP1/AGS_CZ_EP1/2b14_82mm_CZ_EP1, Core_ACR.sqf) and the CZ805/Scorpion/Phantom small-arms rows (Loadout_US/RU/GUE, Gear_US). Full ACR verified on the live box; isClass guards make every row self-defending. Rollback: 0.

//--- supportgate SECURITY (2026-07-24): Server_HandleSpecial.sqf Paratroops/ParaVehi/ParaAmmo/uav
//--- call-ins used to spawn on request with NO server-side cost or rate check - only a client-side
//--- debit (GUI_Menu_Tactical.sqf / Client\Module\UAV\uav.sqf) that a modified client can skip or
//--- spoof, then loop to flood free vehicles/troops/UAVs. 1 (default) = server-authoritative
//--- funds + per-team cooldown gate via WFBE_SE_FNC_AuthorizeSupportCallin (Server_AuthorizeSupportCallin.sqf),
//--- mirroring the pattern Support_ScudStrike.sqf already uses for the carrier SCUD. This is a correctness
//--- hardening default: no legitimate call-in relies on the unrestricted path.
if (isNil "WFBE_C_SUPPORT_SERVER_AUTH") then {WFBE_C_SUPPORT_SERVER_AUTH = 1};

//--- icbmlegacy SECURITY (kimi 2026-07-24, fleet wasp-icbm-legacy-handler-unvalidated-20260724, audit SEC-PVF-2):
//--- Server_HandleSpecial.sqf case "ICBM" (the legacy/classic nuke, only reachable with WFBE_C_ICBM_TEL=0) ran with
//--- NO validation - any client could broadcast the request and get a free, repeatable, unlimited-range area-wipe.
//--- 0 (default) = ORIGINAL unvalidated case, byte-identical to HEAD - the exploit stays OPEN until the owner arms
//--- this (same posture as WFBE_C_SUPPORT_SERVER_AUTH above). 1 = server-authoritative validation: TEL-mode refuse,
//--- payload shape, module gate, playable side, team-side match, commander-team binding (wfbe_commander), SCUD
//--- research >= 2, per-side shared cooldown, and the WFBE_C_ICBM_COST fee charged server-side at launch (the
//--- classic client stops debiting at click while armed - see GUI_Menu_Tactical.sqf MenuAction 8).
if (isNil "WFBE_C_ICBM_LEGACY_SERVER_AUTH") then {WFBE_C_ICBM_LEGACY_SERVER_AUTH = 0};
if (isNil "WFBE_C_ICBM_COST") then {WFBE_C_ICBM_COST = 75000};               //--- classic ICBM (NUKE) fee; GUI_Menu_Tactical.sqf's fee row reads this same constant (lock-step).
if (isNil "WFBE_C_ICBM_LEGACY_COOLDOWN") then {WFBE_C_ICBM_LEGACY_COOLDOWN = 300}; //--- s: per-side shared legacy-ICBM cooldown (parity with WFBE_C_ICBM_TEL_COOLDOWN).

//--- TOWN-SCAN DICE TELEMETRY (kimi townscan-tel lane, 2026-07-25; update #2 evidence): additive
//--- measurement for the server_town_ai.sqf dormant-town scan dice (WFBE_C_TOWN_SCAN_DICE_P tuning).
//--- 0 (default) = INERT: no window timers, no counters, no per-town latch setVariable and no
//--- TOWNSCAN lines - the scan/activation path stays byte-identical to HEAD. 1 = server_town_ai.sqf
//--- accumulates per-60s-window counters and emits one TOWNSCAN|v1 RPT line per window (server-local
//--- RPT only, zero network traffic).
if (isNil "WFBE_C_TOWNSCAN_TELEMETRY") then {WFBE_C_TOWNSCAN_TELEMETRY = 1};
if (isNil "WFBE_C_TOWNSCAN_TELEMETRY_MISSED_SECS") then {WFBE_C_TOWNSCAN_TELEMETRY_MISSED_SECS = 60}; //--- s: an enemy seen by a scan while its town stays dormant longer than this counts one missed_activation_suspect (clock then re-arms). Only read while WFBE_C_TOWNSCAN_TELEMETRY > 0.
//--- ASSAULT RETARGET CHURN (2026-07-25): default 0 keeps current targeting/recycle behavior.
//--- Positive grace value re-issues the current enemy town for that many stuck worker passes before a different-town retarget.
if (isNil "WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES") then {WFBE_C_AICOM_RETARGET_GRACE_DISPATCHES = 0};
//--- Positive value widens the allocator freshness window to at least 300s (the worker cadence is 120s); default 0 keeps 180s.
if (isNil "WFBE_C_AICOM2_ALLOC_TTL_HARDEN") then {WFBE_C_AICOM2_ALLOC_TTL_HARDEN = 0};
//--- Positive value counts uncommitted RETARGET/FOOT_STAGE closures toward WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE; default 0 is inert.
if (isNil "WFBE_C_AICOM_RETARGET_RECYCLE") then {WFBE_C_AICOM_RETARGET_RECYCLE = 0};
//--- overrunrazer REPAIR (owner-directed, GR-2026-07-08a): rewires the orphaned B74.1 OVERRUN razer for the
//--- post-HQ-death case (see AI_Commander_Strategy.sqf "OVERRUN MOP-UP" + Common_RunCommanderTeam.sqf
//--- "OVERRUN MOP-UP companion patch"). 0 (default) = fully inert, byte-identical to HEAD - neither the
//--- new dispatch closer nor the engage-gate patch ever execute their bodies.
if (isNil "WFBE_C_AICOM_OVERRUN_MOPUP_ENABLE") then {WFBE_C_AICOM_OVERRUN_MOPUP_ENABLE = 1};
if (isNil "WFBE_C_AICOM_OVERRUN_MOPUP_RATIO")  then {WFBE_C_AICOM_OVERRUN_MOPUP_RATIO  = 1.1}; //--- dominance bar (myEff >= enEff * ratio) to arm the post-HQ-death mop-up dispatch.
if (isNil "WFBE_C_AICOM_OVERRUN_MOPUP_TEAMS")  then {WFBE_C_AICOM_OVERRUN_MOPUP_TEAMS  = 2};   //--- max concurrent field teams pressed onto live enemy factories by the mop-up closer.
//--- AICOM CARGO AIRDROP (Stage A): registered dark by default; the worker is AI-only and adds no escort jet.
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_ENABLE") then {WFBE_C_AICOM_CARGO_AIRDROP_ENABLE = 1};
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_COOLDOWN") then {WFBE_C_AICOM_CARGO_AIRDROP_COOLDOWN = 1200}; //--- fix0807/airdrop-armed-roster: was 1800; RPT evidence showed the drop firing but under-delivering (unarmed hulls) - tightened cadence now that the roster is armed/combat-relevant.
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_COST") then {WFBE_C_AICOM_CARGO_AIRDROP_COST = 45000}; //--- fix0807/airdrop-armed-roster: was 60000; lowered alongside the cooldown cut so the AI treasury can sustain the faster cadence.
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_VEHICLES_MAX") then {WFBE_C_AICOM_CARGO_AIRDROP_VEHICLES_MAX = 2};
//--- w807-L8 AICOM HELI SLING-LIFT (owner 2026-08-07: "helicopter or plane lifting of vehicle" - owner wants to SEE
//--- AI airlifting vehicles): dedicated support call, registered ARMED by default (owner asked to see it live).
if (isNil "WFBE_C_AICOM_HELILIFT_ENABLE") then {WFBE_C_AICOM_HELILIFT_ENABLE = 1};
if (isNil "WFBE_C_AICOM_HELILIFT_COOLDOWN") then {WFBE_C_AICOM_HELILIFT_COOLDOWN = 1500}; //--- s: per-side cooldown between heli-lift calls.
if (isNil "WFBE_C_AICOM_HELILIFT_COST") then {WFBE_C_AICOM_HELILIFT_COST = 40000}; //--- AICOM-treasury $ debited atomically at dispatch; covers BOTH the transport heli and the slung vehicle (no refund on delivery - the heli is expendable-by-design; a pre-delivery setup abort still refunds in full, mirroring CargoAirdrop).
if (isNil "WFBE_C_AICOM_HELILIFT_MAX_CONCURRENT") then {WFBE_C_AICOM_HELILIFT_MAX_CONCURRENT = 1}; //--- max simultaneous in-flight heli-lifts per side.
if (isNil "WFBE_C_AICOM_HELILIFT_MIN_DIST") then {WFBE_C_AICOM_HELILIFT_MIN_DIST = 2000}; //--- m: the assault target must be at least this far from base/factory for the lift to fire (a near target is faster/cheaper by ground convoy).
//--- CONVOY COHESION (Grok #5, update wave 2026-07-25): Common_RunCommanderTeam.sqf ground road-march.
//--- 0 (default) = ORIGINAL behaviour, byte-identical to HEAD - every road-march node keeps FULL speed
//--- and WFBE_C_AICOM_ROUTE_COMPLETION's completionRadius exactly as today. 1 = when a road-marching
//--- team has >=2 alive/canMove ground vehicles, every intermediate road node EXCEPT the last one before
//--- the final destination waypoint downshifts to LIMITED speed + WFBE_C_AICOM_CONVOY_COMPLETION's wider
//--- completionRadius, so slower/rear hulls hold formation instead of leapfrogging ahead alone into
//--- combat; the last road node (final approach) and the _dest waypoint stay FULL/tight so the assault-in
//--- is still fast. Pure waypoint-parameter change - no new units, no scans, no PV.
if (isNil "WFBE_C_AICOM_CONVOY_COHESION") then {WFBE_C_AICOM_CONVOY_COHESION = 1};
if (isNil "WFBE_C_AICOM_CONVOY_COMPLETION") then {WFBE_C_AICOM_CONVOY_COMPLETION = 100}; //--- m: LIMITED-hop completionRadius while convoy cohesion is engaged (vs the normal WFBE_C_AICOM_ROUTE_COMPLETION 70). Only read while WFBE_C_AICOM_CONVOY_COHESION > 0.
//--- HC STICKY TOWN DELEGATION (Grok idea #23, feat-hc-sticky-delegation 2026-07-25): Server_PickLeastLoadedHC.sqf
//--- re-argmins the least-loaded headless client on EVERY town-AI delegation call, so a town whose AI is
//--- re-delegated across multiple waves (reinforcement/reactivation) can flip HC owner back and forth whenever
//--- the two HCs' loads flicker near-equal, even though nothing about the town changed. 0 (default) = ORIGINAL
//--- unconditional argmin re-pick every call, byte-identical to HEAD. 1 = once a town's AI batch is delegated to
//--- an HC, Server_PickLeastLoadedHC.sqf remembers that HC (stored ON the town object, alongside the town's other
//--- delegation state - wfbe_active_vehicles/wfbe_town_teams - not a parallel registry) and keeps returning it as
//--- the seed HC for WFBE_C_HC_DELEGATE_STICKY_WINDOW seconds, instead of re-picking. Broken early (falls straight
//--- through to the normal fresh argmin pick) if: the sticky HC is no longer live/healthy (same liveness test the
//--- picker already uses - dead/disconnected HC always re-picks immediately, sticky or not), the window has
//--- expired, or the LOAD-BALANCE GUARD trips (sticky HC's already-tallied share of all HC-owned units exceeds
//--- WFBE_C_HC_DELEGATE_STICKY_MAXRATIO) - this guard is why long-match stickiness cannot let one HC's founding
//--- split (currently ~54/46 live) drift further: it can only smooth OUT near-equal flicker, never hold a town on
//--- an HC that is already carrying a disproportionate share. Only changes WHICH HC is used as the round-robin
//--- SEED for a town's batch; the existing intra-batch round-robin spread across all live HCs is untouched.
if (isNil "WFBE_C_HC_DELEGATE_STICKY") then {WFBE_C_HC_DELEGATE_STICKY = 0}; //--- Master gate: 0=off (byte-identical), 1=on.
if (isNil "WFBE_C_HC_DELEGATE_STICKY_WINDOW") then {WFBE_C_HC_DELEGATE_STICKY_WINDOW = 300}; //--- s: how long a town stays pinned to its delegated HC before a fresh pick is allowed.
if (isNil "WFBE_C_HC_DELEGATE_STICKY_MAXRATIO") then {WFBE_C_HC_DELEGATE_STICKY_MAXRATIO = 0.65}; //--- Load-balance guard ceiling: sticky HC's share of all HC-owned units (0..1) above which stickiness is broken and a fresh argmin pick is forced.

//--- AICOM CARGO AIRDROP (Stage B): manned vehicles, extra paratroops, fighter escort - all dark by default; flag-off leaves Stage A byte-identical.
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_CREW_VEHICLES") then {WFBE_C_AICOM_CARGO_AIRDROP_CREW_VEHICLES = 1}; //--- 1 = mount-on-landing crew for each delivered para-vehicle (driver, plus gunner/commander only if the hull actually has that seat); 0 = Stage A empty-hull behaviour, unchanged.
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_PARATROOP_EXTRA") then {WFBE_C_AICOM_CARGO_AIRDROP_PARATROOP_EXTRA = 0}; //--- extra paratroopers beyond the tiered stick Stage A already drops (cycles the same tiered roster classes); clamped to the plane's remaining transportSoldier capacity, never aborts a call. 0 = Stage A roster unchanged.
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_ENABLE") then {WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_ENABLE = 1}; //--- 1 = attempt a single fighter-jet escort in the SAME group as the cargo transport pilot (no extra group cost); the trigger degrades to no-escort-this-call under tight shared air-cap headroom rather than skipping the whole drop.
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_COST") then {WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_COST = 35000}; //--- AICOM-treasury $ added on top of WFBE_C_AICOM_CARGO_AIRDROP_COST only on a call that actually spawns the escort this time; anchored near A10_US_EP1's registered 32,320 unit price plus a pilot.
if (isNil "WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_CLASSES") then {WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_CLASSES = ["A10_US_EP1","AV8B","AV8B2","Su25_Ins","Su25_TK_EP1","Su34","Su39"]}; //--- fixed-wing attack-jet candidates only (Plane-kind subset of AI_Commander_AirResp.sqf's allowlist); intersected against the side's own WFBE_<SIDE>AIRCRAFTUNITS roster at dispatch so the pick is always side-safe/reachable, never hardcoded to one faction.

//--- CASTER SLOTS (feat 2026-08-01, owner order): two CIV "Caster 1/2" playable slots ship in
//--- mission.sqm on every terrain (plain playable seats, NOT forceHeadlessClient - humans only).
//--- WFBE_C_CASTER_UIDS is the caster allowlist; it is MERGED into WFBE_C_SPECTATOR_UIDS below, so
//--- every existing spectator gate (Attach addAction visibility, Enter belt-and-braces re-check)
//--- accepts casters without editing the spectator files themselves (deliberate: the v3/v4 spectator
//--- rewrites are in flight in other lanes and this must not conflict with them). Defaults are inert:
//--- empty list = the merge is a no-op; flag 0 = the Init_Client auto-enter block never arms. The slot
//--- bodies mark themselves via their sqm init line (this setVariable ["wfbe_caster_slot", true]) -
//--- sqm init runs on EVERY machine, so the marker is globally readable with no publicVariable and no
//--- name-list drift (contrast the HC registry right below).
if (isNil "WFBE_C_CASTER_UIDS") then {WFBE_C_CASTER_UIDS = ["76561198046825568"]}; //--- Steam UIDs allowed to cast from a Caster slot; merged into the spectator allowlist below.
if (isNil "WFBE_C_CASTER_AUTOSPECTATE") then {WFBE_C_CASTER_AUTOSPECTATE = 1};
//--- v5 (spec 8): 1 = the spectator addAction requires a Caster SEAT as well as the UID allowlist.
if (isNil "WFBE_C_SPECTATOR_CASTER_SEAT_ONLY") then {WFBE_C_SPECTATOR_CASTER_SEAT_ONLY = 1}; //--- 1 = an allowlisted caster seated in a Caster slot auto-enters the spectator once past the deadspawn-transit window.
//--- ROOT-CAUSE FIX (owner live repro m0801h4, adversarial review flagged it pre-merge): branch
//--- merges reordered this file so this merge loop ran BEFORE the WFBE_C_SPECTATOR_UIDS isNil
//--- definition further down. The undefined read threw at runtime and ABORTED THE REST OF THIS
//--- FILE - every constant below (all spectator/director/HUD/menu flags) stayed nil for the whole
//--- session: J fell through to the WF menu, no overlay, defaults everywhere. Order-independent now.
if (isNil "WFBE_C_SPECTATOR_UIDS") then {WFBE_C_SPECTATOR_UIDS = []};
{ if !(_x in WFBE_C_SPECTATOR_UIDS) then {WFBE_C_SPECTATOR_UIDS = WFBE_C_SPECTATOR_UIDS + [_x]}; } forEach WFBE_C_CASTER_UIDS;

//--- HEADLESS-CLIENT NAME REGISTRY (fix 2026-07-26). The 4-HC rollout (#1456) added a fourth HC, but every
//--- "is this a real human player" test carried its OWN hardcoded HC name list and they drifted - the
//--- proximity helper still listed only HC-AI-Control-1..3, so HC4's body counted as a player and vetoed
//--- any spawn near wherever HC4 happened to be standing. Note the group registry WFBE_HEADLESSCLIENTS_ID
//--- cannot cover this: it is only ever written server-side (Init_Server.sqf / Server_HandleSpecial.sqf,
//--- no public third arg - NSSETVAR3 is banned), so on a HEADLESS CLIENT it always reads back [] and the
//--- name list is the sole working exclusion there. Derive the list from a slot count so adding HC5 is one
//--- number rather than a repo-wide grep. Runs before Init_Common.sqf (initJIPCompatible.sqf:140 Call vs
//--- :329 ExecVM), so WFBE_C_HC_NAMES is always defined before any consumer compiles.
if (isNil "WFBE_C_HC_SLOTS") then {WFBE_C_HC_SLOTS = 2}; //--- HC-AI-Control-<n> slots the mission SHIPS in mission.sqm. Back to 2 on owner order 2026-07-30 ("PLS NO MORE HC IN BLUFOR / OPFOR"): the live box runs Start-Wasp-2HC.ps1 (2 HC processes), so slots 3 and 4 only ever sat unfilled in the lobby. The exclusion NAME list below deliberately still covers 4 - see there.
if (isNil "WFBE_C_HC_NAMES") then {
	private ["_hcNameList"];
	_hcNameList = ["HC"]; //--- legacy single-HC profile name, still present in older box configs.
	if ((typeName WFBE_C_HC_SLOTS) != "SCALAR") then {WFBE_C_HC_SLOTS = 2}; //--- a mistyped override must not throw inside the for below.
	//--- Name list is an EXCLUSION net ("is this body a real human?"), so a SUPERSET is the safe
	//--- direction: it must keep covering HC-AI-Control-3/4 even now that the mission ships 2 slots,
	//--- because the box still has WaspHC3/WaspHC4 launchers on disk and a stray one connecting must
	//--- not be counted as a player (that exact drift is what broke spawn vetoes in #1456).
	for "_hcSlot" from 1 to (WFBE_C_HC_SLOTS max 4) do {_hcNameList set [count _hcNameList, Format ["HC-AI-Control-%1", _hcSlot]]};
	//--- QUOTED-NAME BELT (fix0807b/hc-quoted-names, live RPT evidence 2026-08-07): an A2OA launch
	//--- flag shaped -name="HC-AI-Control-1" bakes the literal double-quote characters into the
	//--- resolved profile name (CHATRELAY|v1|JOIN|"HC-AI-Control-1"| vs a real player's unquoted
	//--- CHATRELAY|v1|JOIN|Zwanon), so a plain (name _x) in WFBE_C_HC_NAMES test misses it outright -
	//--- the connect nameGate (Server_OnPlayerConnected.sqf) let a fully-enrolled HC back in as a WEST
	//--- player despite PR #2376, and the commander-vote eligibility gate (Server_VoteForCommander.sqf)
	//--- let the same HC WIN the elected-commander seat. Append the quoted twin of every bare name
	//--- already collected above so an UNCHANGED `in WFBE_C_HC_NAMES` test at every existing call site
	//--- catches both forms with zero consumer-file edits - this is the BELT; WFBE_CO_FNC_IsHcName
	//--- (Common_IsHcName.sqf) is the BRACES the highest-value consumers were additionally switched to,
	//--- for any future quoting quirk this registry widening does not anticipate. _hcDq = one literal
	//--- _hcDq = one literal double-quote character, ASCII 34, built via toString - no quote characters appear in this source line or this comment.
	//--- a double-quoted literal would need for the same character.
	private ["_hcBareNames","_hcDq"];
	_hcDq = toString [34]; //--- literal double-quote via ASCII code: ZERO quote characters in source. The previous quote-char single-quoted literal form compiled nowhere - the A2OA preprocessor treated the raw quote as an unterminated string and killed the ENTIRE file's compile (live incident wave0807a2, 2026-08-07: every WFBE_C_* constant nil, mission systemically broken).
	_hcBareNames = +_hcNameList; //--- snapshot copy: appending into _hcNameList while forEach'ing IT would rescan the growing array.
	{ _hcNameList set [count _hcNameList, _hcDq + _x + _hcDq]; } forEach _hcBareNames;
	WFBE_C_HC_NAMES = _hcNameList;
};

//--- HC LOBBY LOCK (feat/hc-lobby-lock, owner request 2026-07-26): hold joining PLAYERS out of play
//--- until every expected headless client has actually seated, then open automatically. Observed on the
//--- 4-HC soak box: on a cold start the HCs race the mission load, HC1 lands in a BLUFOR player slot and
//--- the others grey out with no slot, and the only remedy so far is a manual post-start bounce (an HC
//--- that JIPs into a LIVE mission seats correctly; one that connects during mission load does not).
//--- A2 OA gives the mission NO hook on the engine's own role/slot screen, and the two engine-level locks
//--- are both unavailable here (server.cfg `password` is read at STARTUP only and the running server holds
//--- an exclusive lock on the cfg; `#lock`/serverCommand needs a logged-in admin or BattlEye, and BattlEye
//--- is deliberately disabled on this box) - so the lock is mission-side and holds the joiner AFTER slot
//--- selection, in the deadspawn holding area, before base placement.
//--- 0 (default) = OFF, byte-identical to HEAD: the server-side authority is never launched
//--- (Init_Server.sqf) and the client-side hold is never entered (Init_Client.sqf).
if (isNil "WFBE_C_HC_LOBBY_LOCK") then {WFBE_C_HC_LOBBY_LOCK = 1}; //--- ARMED on owner order 2026-07-30 ("flip the lobby lock on"). Master gate: 0=off (byte-identical), 1=on. Joining players are held in the deadspawn pen, invulnerable, until both HCs have registered (or WFBE_C_HC_LOBBY_TIMEOUT expires, which fails OPEN and logs loudly). Rollback = set this back to 0 and rebuild; watch for HCLOBBY|v1|OPEN|reason=timeout in the server RPT, which means the hold bought nothing.
if (isNil "WFBE_C_HC_LOBBY_TIMEOUT") then {WFBE_C_HC_LOBBY_TIMEOUT = 240}; //--- s of mission time: hard fail-open. A permanently missing HC opens the server anyway (logged loudly) instead of locking it out forever. Also the window in which the client-side gate is armed at all, so an ordinary mid-match JIP joiner never sees it. Keep it under the ~120s deadspawn-transit invulnerability budget in Init_Client.sqf. RAISED 90 -> 150 on 2026-07-30 after an adversarial review of the arming: this clock starts when Init_Server.sqf ExecVMs the lock (Init_Server.sqf:198), which is BEFORE the waitUntil {commonInitComplete && townInit} at :225 and therefore before MATCH|v1|START| is emitted at :246 - the very signal Start-Wasp-2HC.ps1 waits on before it launches either HC. So the timeout clock has a head start over the whole HC launch sequence and 90 could expire before HC2 registers, failing OPEN on every cold start and making the lock pointless. Measured on the live box 2026-07-30 (m0730g): HC-AI-Control-1 registered at mission time ~3s and HC-AI-Control-2 at ~57s, so 150 carries ~2.6x margin over the observed worst case. Exceeding the ~120s deadspawn-transit invulnerability budget is safe HERE specifically because the client-side hold re-asserts allowDamage false on every tick of the hold and re-arms a fresh 120s watchdog on release (Init_Client.sqf, the HC-lobby-lock block) - do not copy this number to any other hold that lacks those two guarantees. RAISED AGAIN 150 -> 240 on 2026-07-30 to UNBLOCK the HC launch-gate fix: HC1 still takes a WEST player slot because it connects while the mission is still loading (engineSide=WEST in HCSIDE|v1|preseat, vs HC2 which connects ~10s before mission-live and gets CIV). The cure is to make Start-Wasp-2HC.ps1 actually wait for MATCH|v1|START before launching either HC - but then the HCs finish loading AFTER the mission clock starts and register around mission time 140-200s instead of ~4s, which a 150s timeout would fail open on. 240 covers that with margin and caps the worst-case hold at 4 minutes. Safe to ship BEFORE the launcher change: while the HCs still register at ~4s the timeout is only an unused ceiling.
if (isNil "WFBE_C_HC_LOBBY_EXPECTED") then {WFBE_C_HC_LOBBY_EXPECTED = if (!isNil "WFBE_C_HC_SLOTS" && {(typeName WFBE_C_HC_SLOTS) == "SCALAR"}) then {WFBE_C_HC_SLOTS} else {2}}; //--- Expected seated-HC count. Defaults to WFBE_C_HC_SLOTS (2 today - back to 2 on owner order 2026-07-30, defined just above by the HC-name registry) so the repo keeps ONE number for how many headless clients this mission ships - bumping WFBE_C_HC_SLOTS to 5 carries here automatically, which is exactly the hardcoded-list drift that registry was added to end. Falls back to a literal 4 only if that constant is absent or mistyped. 0 disables the lock. -1 opts in to RUNTIME DERIVATION from the mission's own playable CIV slot count instead.

//--- AICOM AIR BOMBS (owner request 2026-07-26, "make sure AI commander aircraft can also use FABs"): the
//--- EASA-on-AI kit table in Common_RunCommanderTeam.sqf (~L462-513) REPLACES rather than extends the A10 and
//--- Mi24_P kit arrays, so applying the kit STRIPS the airframe's own ground-attack bomb (AV8B2 never had one).
//--- 0 (default) = byte-identical to HEAD - the existing kit rows apply exactly as before. >0 = the same kit
//--- rows additionally preserve/grant the airframe's own verbatim EASA bomb launcher+magazine instead of losing
//--- it (classnames cited per row at Common_RunCommanderTeam.sqf where this flag is read).
if (isNil "WFBE_C_AICOM_AIR_BOMBS") then {WFBE_C_AICOM_AIR_BOMBS = 1}; //--- armed 2026-07-27 owner go. EASA-on-AI kit table preserves/grants FAB-250/Mk-82 bomb capability on A10/Mi24_P/AV8B2 instead of stripping it.

//--- fable/sidepatrol-front-bias-20260727: side-patrol destination picker prefers the AI Commander's
//--- published spearhead town(s) (wfbe_aicom_targets) over pure nearest-to-self when set. Default 0 =
//--- OFF, mission byte-identical to legacy behaviour (Common_RunSidePatrol.sqf). NOTE: wfbe_aicom_targets
//--- itself is only visible off-server when WFBE_C_AICOM_PUBLIC_STATE_SYNC is ALSO armed (see that flag
//--- and AI_Commander_Strategy.sqf/AI_Commander_Allocate.sqf) - arming ONLY this flag on a server with a
//--- connected HC is a silent no-op (the mandatory empty-list fallback keeps nearest-to-self behaviour).
if (isNil "WFBE_C_SIDE_PATROL_FRONT_BIAS") then {WFBE_C_SIDE_PATROL_FRONT_BIAS = 1}; //--- armed 2026-07-27 owner go.

//--- AI HQ REPURCHASE: dark by default. The HQ-loss hook records only full-AICOM losses; the worker delays then uses the nearest owned town centre and charges the AI treasury the live human HQ-deploy price.
if (isNil "WFBE_C_AICOM_HQ_REPURCHASE_ENABLE") then {WFBE_C_AICOM_HQ_REPURCHASE_ENABLE = 1}; //--- armed 2026-07-27 owner go.
if (isNil "WFBE_C_AICOM_HQ_REPURCHASE_DELAY") then {WFBE_C_AICOM_HQ_REPURCHASE_DELAY = 1200};

//--- fable/spectator-v1 (owner request 2026-07-28: spectator mode, owner first): UID-allowlisted
//--- opt-in free-camera spectator overlay for an already-enrolled player (Client_SpectatorAttach/
//--- Enter/Exit.sqf, wired from Client\Init\Init_Client.sqf). Client-side only - no HC architecture,
//--- player enrollment, or JIP flow touched. Master flag defaults ON per owner request; the UID
//--- allowlist gates ACTION VISIBILITY on each client only under standard A2 locality; it is
//--- not server-enforced authentication or authorization (empty allowlist = fully inert).
if (isNil "WFBE_C_SPECTATOR") then {WFBE_C_SPECTATOR = 1};
//--- SteamID64 strings, compared against (getPlayerUID player) - the same string shape getPlayerUID
//--- already returns everywhere else in this mission (Client_BuildUnit.sqf, Action_CancelQueue.sqf,
//--- fpv.sqf, etc.). Add more owner/admin UIDs here as extra array entries. NOTE: this file is public
//--- (rayswaynl/a2waspwarfare) - SteamID64s are public-profile identifiers, not secrets, but this list
//--- is still an intentional, curated allowlist.
if (isNil "WFBE_C_SPECTATOR_UIDS") then {WFBE_C_SPECTATOR_UIDS = ["76561198046825568"]};
//--- spectator v2 tuning (2026-07-29, docs/plans/2026-07-29-spectator-v2-design.md): free-fly
//--- base speed, Shift boost / Alt precision multipliers, mouse-look sensitivity (degrees per
//--- full UI-width delta - playtest-tune), mouse-wheel zoom clamps (0.05 = strong zoom scope).
if (isNil "WFBE_C_SPECTATOR_SPEED") then {WFBE_C_SPECTATOR_SPEED = 15};
if (isNil "WFBE_C_SPECTATOR_BOOST") then {WFBE_C_SPECTATOR_BOOST = 4};
if (isNil "WFBE_C_SPECTATOR_SLOW") then {WFBE_C_SPECTATOR_SLOW = 0.25};
if (isNil "WFBE_C_SPECTATOR_SENS") then {WFBE_C_SPECTATOR_SENS = 25};	//--- owner playtest 2026-07-30: 300 deg per full UI-width was unusable; 80 is a broadcast-friendly base. PgUp/PgDn adjust live in-session.
if (isNil "WFBE_C_SPECTATOR_FOV_MIN") then {WFBE_C_SPECTATOR_FOV_MIN = 0.05};
if (isNil "WFBE_C_SPECTATOR_AIM_RATE") then {WFBE_C_SPECTATOR_AIM_RATE = 3.5}; //--- v5 P1 follow-aim easing rate (1/s): time-constant ~0.29s, council C8 band 0.25-0.4s. Only read by Client_SpectatorAimFrame.sqf.
if (isNil "WFBE_C_SPECTATOR_FOV_MAX") then {WFBE_C_SPECTATOR_FOV_MAX = 1.2};
//--- v5 P3 (owner 2026-08-01): when the director TRACKS a subject (orbit off) the camera should
//--- sit FLATTER than when it orbits - a near-horizontal angle looks down the line of travel and
//--- sees further, reading as a chase/broadcast shot; the taller angle is what keeps a CIRCLING
//--- shot legible. Scales shot HEIGHT only, so radius/apparent size are unchanged.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TRACK_HEIGHT_MULT") then {WFBE_C_SPECTATOR_DIRECTOR_TRACK_HEIGHT_MULT = 0.45};
//--- v5 P3: occasional first-person cut - every Nth director cut becomes an eyes/POV shot on the
//--- armed subject (Man subjects only; a vehicle eyePos sits inside the hull). 0 = never.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_EYES_EVERY") then {WFBE_C_SPECTATOR_DIRECTOR_EYES_EVERY = 5};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_EYES_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_EYES_SEC = 6};
//--- v5 P3 (5b): allow GUER (resistance) AI group leaders as manual N/B watch targets. GUER is
//--- AI-only, so the isPlayer filter in the cycle excluded the entire insurgency.
if (isNil "WFBE_C_SPECTATOR_TARGET_GUER") then {WFBE_C_SPECTATOR_TARGET_GUER = 1};
//--- v5: max seconds a NO-contact shot may hold the screen before the director re-picks.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_IDLE_DWELL_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_IDLE_DWELL_SEC = 3};
//--- v5 P4: 1 = free-cam integrated per render frame in Client_SpectatorAimFrame (0 = old scheduled path).
if (isNil "WFBE_C_SPECTATOR_FREECAM_FRAME") then {WFBE_C_SPECTATOR_FREECAM_FRAME = 1};
//--- v6 (research ruleset, docs/plans/2026-08-01-director-v6-research-ruleset.md):
//--- rule 4 - TIGHT framing needs a real fight, not one bystander.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TIGHT_MIN_CONTACT") then {WFBE_C_SPECTATOR_DIRECTOR_TIGHT_MIN_CONTACT = 2};
//--- v7 POI director (owner ruling 2026-08-01): fight-cluster proximity link distance in metres -
//--- armed units of fighting sides within this range of a cluster centroid merge into that cluster.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_CLUSTER_LINK_M") then {WFBE_C_SPECTATOR_DIRECTOR_CLUSTER_LINK_M = 300};
//--- m0801h9 (owner live repro "zooms in on dirt"): FIGHT aim = density peak - the member with the
//--- most fellow members inside DENSITY_M (ties -> nearest the centroid); never the raw centroid.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_CLUSTER_DENSITY_M") then {WFBE_C_SPECTATOR_DIRECTOR_CLUSTER_DENSITY_M = 75};
//--- m0801h9 zoom-by-compactness: TIGHT band only under COMPACT_M cluster radius; WIDE_M+ = WIDE shot.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_FIGHT_COMPACT_M") then {WFBE_C_SPECTATOR_DIRECTOR_FIGHT_COMPACT_M = 120};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_FIGHT_WIDE_M") then {WFBE_C_SPECTATOR_DIRECTOR_FIGHT_WIDE_M = 200};
//--- rule 3 - minimum hold on any shot that has live contact (fire lock).
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_HOT_HOLD_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_HOT_HOLD_SEC = 7};
//--- v5 P3b (spec 7a): seconds of no caster input after which transient operator chrome (keybind
//--- wall + shot list) fades, leaving only the compact status line. On a single-PC stream the
//--- caster screen IS the stream, so idle must resolve to a clean broadcast frame by itself.
if (isNil "WFBE_C_SPECTATOR_HUD_FADE_SEC") then {WFBE_C_SPECTATOR_HUD_FADE_SEC = 6};
//--- v5 P5: caster streamer menu (J in-camera / body action out-of-camera) - WF-menu-idiom
//--- settings dialog for the broadcast toggles (director auto, orbit, GUER targets, eyes-cam
//--- cadence, HUD fade, idle dwell, cam speed + live sens readout). Default 0 = fully inert:
//--- both open paths (addAction install, J KeyDown case) check this flag.
if (isNil "WFBE_C_SPECTATOR_STREAMER_MENU") then {WFBE_C_SPECTATOR_STREAMER_MENU = 1}; //--- owner armed 2026-08-01 (was 0/dark at first ship)

//--- Spectator v3 director: explicit opt-in. All director code paths read this master gate.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR") then {WFBE_C_SPECTATOR_DIRECTOR = 1}; //--- ARMED on owner order 2026-07-30 ("fold v3 in now"), after an adversarial review found and a fix landed for the blocker that made this feature silently do nothing: the poll thread was started after the movement loop had already exited. Blast radius is one client - spectator entry is gated to WFBE_C_SPECTATOR_UIDS - so this only ever runs for an allowlisted caster. Rollback = set to 0 and rebuild.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_DWELL = 20};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_DWELL_STEP") then {WFBE_C_SPECTATOR_DIRECTOR_DWELL_STEP = 5};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_DWELL_MIN") then {WFBE_C_SPECTATOR_DIRECTOR_DWELL_MIN = 5};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_DWELL_MAX") then {WFBE_C_SPECTATOR_DIRECTOR_DWELL_MAX = 120};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ORBIT_RADIUS") then {WFBE_C_SPECTATOR_DIRECTOR_ORBIT_RADIUS = 40};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ORBIT_HEIGHT") then {WFBE_C_SPECTATOR_DIRECTOR_ORBIT_HEIGHT = 25};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ORBIT_DEG_PER_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_ORBIT_DEG_PER_SEC = 6};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TOWN_POLL_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_TOWN_POLL_SEC = 8};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TOWN_CONTEST_RADIUS") then {WFBE_C_SPECTATOR_DIRECTOR_TOWN_CONTEST_RADIUS = 200};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TEAM_CONTACT_RADIUS") then {WFBE_C_SPECTATOR_DIRECTOR_TEAM_CONTACT_RADIUS = 150};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PLAYER_CONTACT_RADIUS") then {WFBE_C_SPECTATOR_DIRECTOR_PLAYER_CONTACT_RADIUS = 100};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_HQ_CONTACT_RADIUS") then {WFBE_C_SPECTATOR_DIRECTOR_HQ_CONTACT_RADIUS = 250};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_REVEAL_ENEMY_HQ") then {WFBE_C_SPECTATOR_DIRECTOR_REVEAL_ENEMY_HQ = 0};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_COOLDOWN_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_COOLDOWN_SEC = 45};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_CONTEST") then {WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_CONTEST = 1000}; //--- 2026-07-30: contact must dominate town size/trend.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_TREND") then {WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_TREND = 10}; //--- 2026-07-30: retain a small recency signal under contact-first scoring.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_SIZE") then {WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_SIZE = 2};
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_TEAM_CONTACT") then {WFBE_C_SPECTATOR_DIRECTOR_W_TEAM_CONTACT = 1000}; //--- 2026-07-30: one live contact outranks team size by an order of magnitude.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_TEAM_SIZE") then {WFBE_C_SPECTATOR_DIRECTOR_W_TEAM_SIZE = 2}; //--- 2026-07-30: size is a tie-breaker behind contact.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_CONTACT") then {WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_CONTACT = 1000}; //--- 2026-07-30: one live contact outranks player base score.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_BASE") then {WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_BASE = 10}; //--- 2026-07-30: base remains a small idle tie-breaker.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_HQ_BASE") then {WFBE_C_SPECTATOR_DIRECTOR_W_HQ_BASE = 15}; //--- 2026-07-30: base remains below any active contact.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_HQ_UNDER_ATTACK") then {WFBE_C_SPECTATOR_DIRECTOR_W_HQ_UNDER_ATTACK = 1000}; //--- 2026-07-30: one live contact outranks HQ base score.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_W_IDLE_PENALTY") then {WFBE_C_SPECTATOR_DIRECTOR_W_IDLE_PENALTY = 250}; //--- 2026-07-30: idle targets lose unless no contact target exists.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_SMOOTHING") then {WFBE_C_SPECTATOR_DIRECTOR_SMOOTHING = 5}; //--- 2026-07-30: director camera convergence rate, per second.

//--- Spectator v3.2 shot grammar, engagement framing, and director pacing.
//--- director-auto seconds between friendly HQ base check-ins.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_BASE_CHECK_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_BASE_CHECK_SEC = 420};
//--- director-auto seconds allowed without a WIDE establish shot.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ESTABLISH_FLOOR_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_ESTABLISH_FLOOR_SEC = 120};
//--- absolute per-shot dwell floor in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_MIN_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_MIN_DWELL = 1.5};
//--- candidate score margin required over the current target.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_HYSTERESIS_MARGIN") then {WFBE_C_SPECTATOR_DIRECTOR_HYSTERESIS_MARGIN = 0.2};
//--- score margin required to repeat the current target.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_REPEAT_SCORE_MARGIN") then {WFBE_C_SPECTATOR_DIRECTOR_REPEAT_SCORE_MARGIN = 0.5};
//--- continuous aim and orbit ceiling in degrees per second.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PAN_DEG_PER_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_PAN_DEG_PER_SEC = 8};
//--- aim delta in degrees that becomes a hard cut.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PAN_CUT_DEG") then {WFBE_C_SPECTATOR_DIRECTOR_PAN_CUT_DEG = 70}; //--- v4: mid-shot snaps read as yanks on stream; 70deg gates only true breaks (a shot change still cuts).
//--- maximum in-shot FOV change per second.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_FOV_RATE") then {WFBE_C_SPECTATOR_DIRECTOR_FOV_RATE = 0.35}; //--- v4 (owner 2026-07-31): 0.05/s took 10-15s wide-to-tight - the zoom landed after the shot ended.
//--- seconds manual wheel zoom suppresses director FOV control.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_MANUAL_ZOOM_LOCK_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_MANUAL_ZOOM_LOCK_SEC = 10};
//--- fallback getDir engagement look-ahead distance in metres.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ENGAGEMENT_AIM_DISTANCE") then {WFBE_C_SPECTATOR_DIRECTOR_ENGAGEMENT_AIM_DISTANCE = 150};
//--- WIDE and BASE lower FOV bound.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MIN") then {WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MIN = 0.8};
//--- WIDE and BASE upper FOV bound.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MAX") then {WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MAX = 0.95};
//--- WIDE lower dwell bound in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_WIDE_MIN_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_WIDE_MIN_DWELL = 4};
//--- WIDE upper dwell bound in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_WIDE_MAX_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_WIDE_MAX_DWELL = 7};
//--- BASE lower dwell bound in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_BASE_MIN_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_BASE_MIN_DWELL = 6};
//--- BASE upper dwell bound in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_BASE_MAX_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_BASE_MAX_DWELL = 9};
//--- MEDIUM lower FOV bound.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_FOV_MIN") then {WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_FOV_MIN = 0.28};
//--- MEDIUM upper FOV bound.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_FOV_MAX") then {WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_FOV_MAX = 0.4};
//--- MEDIUM lower dwell bound in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_MIN_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_MIN_DWELL = 4};
//--- MEDIUM upper dwell bound in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_MAX_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_MAX_DWELL = 7};
//--- TIGHT lower FOV bound.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TIGHT_FOV_MIN") then {WFBE_C_SPECTATOR_DIRECTOR_TIGHT_FOV_MIN = 0.12};
//--- TIGHT upper FOV bound.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TIGHT_FOV_MAX") then {WFBE_C_SPECTATOR_DIRECTOR_TIGHT_FOV_MAX = 0.2};
//--- TIGHT lower dwell bound in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TIGHT_MIN_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_TIGHT_MIN_DWELL = 3}; //--- v4: 1.5-3s tight shots ended before the (now faster) zoom arrived.
//--- TIGHT upper dwell bound in seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TIGHT_MAX_DWELL") then {WFBE_C_SPECTATOR_DIRECTOR_TIGHT_MAX_DWELL = 6};
//--- WIDE and BASE camera standoff radius in metres.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_WIDE_RADIUS") then {WFBE_C_SPECTATOR_DIRECTOR_WIDE_RADIUS = 180};
//--- WIDE and BASE camera height above target in metres.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_WIDE_HEIGHT") then {WFBE_C_SPECTATOR_DIRECTOR_WIDE_HEIGHT = 110};
//--- WIDE and BASE orbit rate in degrees per second.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_WIDE_ORBIT_DEG_PER_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_WIDE_ORBIT_DEG_PER_SEC = 4};
//--- MEDIUM camera standoff radius in metres.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_RADIUS") then {WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_RADIUS = 70};
//--- MEDIUM camera height above target in metres.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_HEIGHT") then {WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_HEIGHT = 30};
//--- TIGHT camera standoff radius in metres.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TIGHT_RADIUS") then {WFBE_C_SPECTATOR_DIRECTOR_TIGHT_RADIUS = 35};
//--- TIGHT camera height above target in metres.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TIGHT_HEIGHT") then {WFBE_C_SPECTATOR_DIRECTOR_TIGHT_HEIGHT = 14};
//--- seconds of velocity feed-forward for moving director and manual-follow subjects.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_LEAD_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_LEAD_SEC = 0.4};
//--- multiplier for position convergence when subject speed exceeds 8 m/s.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_FAST_GAIN_MULT") then {WFBE_C_SPECTATOR_DIRECTOR_FAST_GAIN_MULT = 2.5};
//--- standoff multiplier for non-Man director subjects.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_VEH_STANDOFF_MULT") then {WFBE_C_SPECTATOR_DIRECTOR_VEH_STANDOFF_MULT = 2.5};
//--- minimum FOV for non-Air vehicle director subjects.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_VEH_FOV_MIN") then {WFBE_C_SPECTATOR_DIRECTOR_VEH_FOV_MIN = 0.55};
//--- standoff multiplier for Air director subjects.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_AIR_STANDOFF_MULT") then {WFBE_C_SPECTATOR_DIRECTOR_AIR_STANDOFF_MULT = 4.0};
//--- minimum FOV for Air director subjects.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_AIR_FOV_MIN") then {WFBE_C_SPECTATOR_DIRECTOR_AIR_FOV_MIN = 0.45};

//--- Spectator broadcast HUD: opt-in styled title overlay + dialog map fallback.
//--- 0 (default) leaves the existing 12455 cutText spectator card path unchanged.
//--- Layer 12456 is reserved for this title; 12450-12452/12454/12455/12461 remain occupied.
if (isNil "WFBE_C_SPECTATOR_BROADCAST_HUD") then {WFBE_C_SPECTATOR_BROADCAST_HUD = 1}; //--- owner armed 2026-08-01 (the caster overlay: "NO OVERLAY" on the h5 stream was this flag still 0/dark - the cutRsc broadcast HUD never drew)

//--- Spectator v4 streaming pass (owner 2026-07-31: autonomous TikTok/Twitch/Kick broadcast cam).
if (isNil "WFBE_C_SPECTATOR_TICK") then {WFBE_C_SPECTATOR_TICK = 0.01}; //--- camera loop sleep; 0.05 hard-capped updates at 20Hz = judder on a 60fps capture.
if (isNil "WFBE_C_SPECTATOR_AUTOSTART") then {WFBE_C_SPECTATOR_AUTOSTART = 0}; //--- 1 = allowlisted caster auto-enters spectator + director-auto (hands-off stream box). Entry still UID-gated.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PAN_MIN_DEG_PER_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_PAN_MIN_DEG_PER_SEC = 25}; //--- adaptive slew floor.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PAN_MAX_DEG_PER_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_PAN_MAX_DEG_PER_SEC = 240}; //--- adaptive slew ceiling.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PAN_EASE") then {WFBE_C_SPECTATOR_DIRECTOR_PAN_EASE = 6}; //--- rate = clamp(err*EASE, MIN, MAX); ease-out near the frame.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TOWN_LINGER_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_TOWN_LINGER_SEC = 45}; //--- a town stays fight-pickable this long after the last enemy leaves; kills fight-pause flicker.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_LEAD_MAX_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_LEAD_MAX_SEC = 0.5}; //--- velocity lead cap; scales with EMA subject speed (supersedes the flat LEAD_SEC 0.4 raw feed-forward).
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_LEAD_FULL_SPEED") then {WFBE_C_SPECTATOR_DIRECTOR_LEAD_FULL_SPEED = 25}; //--- m/s at which the full lead applies; walking infantry get ~none.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_VEL_EMA_RATE") then {WFBE_C_SPECTATOR_DIRECTOR_VEL_EMA_RATE = 8}; //--- per-second blend of the subject-velocity EMA; kills network stair-step feed-forward noise.

//--- Spectator v4.1 free-cam pass (owner 2026-07-31: caster-grade user-driven cam).
if (isNil "WFBE_C_SPECTATOR_ACCEL") then {WFBE_C_SPECTATOR_ACCEL = 6}; //--- free-cam velocity convergence per second while keys are held.
if (isNil "WFBE_C_SPECTATOR_BRAKE") then {WFBE_C_SPECTATOR_BRAKE = 9}; //--- free-cam stop convergence per second when no key is held (faster than ACCEL so stops stay crisp).
if (isNil "WFBE_C_SPECTATOR_ZOOM_RATE") then {WFBE_C_SPECTATOR_ZOOM_RATE = 8}; //--- manual wheel-zoom ease rate (FOV per second toward the wheel target).
if (isNil "WFBE_C_SPECTATOR_MOUSE_SMOOTH") then {WFBE_C_SPECTATOR_MOUSE_SMOOTH = 0.55}; //--- per-event mouse-delta EMA blend (1=instant/off, lower=smoother).
if (isNil "WFBE_C_SPECTATOR_SENS_REF_FOV") then {WFBE_C_SPECTATOR_SENS_REF_FOV = 0.8}; //--- FOV at which SENS applies 1:1; sensitivity scales linearly with zoom (scoped-aim feel).
if (isNil "WFBE_C_SPECTATOR_SENS_MIN_FACTOR") then {WFBE_C_SPECTATOR_SENS_MIN_FACTOR = 0.05}; //--- never let zoom-scaled sensitivity drop below this fraction of SENS.

//--- ===== Spectator v8 DEFINITIVE rebuild (owner mandate 2026-08-01) ===== ---
if (isNil "WFBE_C_SPECTATOR_EVENTFEED") then {WFBE_C_SPECTATOR_EVENTFEED = 1}; //--- server/HC Fired-Killed event feed for the caster auto-director (Common_SpectatorEventFeed.sqf).
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TRACK_TTL_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_TRACK_TTL_SEC = 15}; //--- unmatched fight tracks age out after this many seconds.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TRACK_MATCH_OVERLAP") then {WFBE_C_SPECTATOR_DIRECTOR_TRACK_MATCH_OVERLAP = 0.25}; //--- member-overlap fraction that keeps a track id across re-forms.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_EV_ASSIGN_TRACK_M") then {WFBE_C_SPECTATOR_DIRECTOR_EV_ASSIGN_TRACK_M = 150}; //--- event-to-track assignment slack beyond the track radius.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_EV_ASSIGN_TOWN_M") then {WFBE_C_SPECTATOR_DIRECTOR_EV_ASSIGN_TOWN_M = 250}; //--- event-to-town fallback assignment radius.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_HOLD_MIN_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_HOLD_MIN_SEC = 7}; //--- fight minimum hold (fire lock).
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_HOLD_MAX_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_HOLD_MAX_SEC = 12}; //--- extended hold ceiling while action continues.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_CUT_RATIO") then {WFBE_C_SPECTATOR_DIRECTOR_CUT_RATIO = 1.5}; //--- a rival must outscore the live shot by this ratio to steal the camera.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_RECENT_PENALTY") then {WFBE_C_SPECTATOR_DIRECTOR_RECENT_PENALTY = 0.75}; //--- last-2-shown POIs score at 75 percent...
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_RECENT_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_RECENT_SEC = 30}; //--- ...for this many seconds (bypassed at 2x the current score).
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_GLANCE_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_GLANCE_SEC = 3}; //--- cold-town WIDE glance duration.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_TOWN_COOLDOWN_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_TOWN_COOLDOWN_SEC = 45}; //--- per-town cooldown after a glance.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_DELAY_SEC") then {WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_DELAY_SEC = 3}; //--- static settle before the orbit reveal starts.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_RATE") then {WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_RATE = 6}; //--- reveal sweep speed, degrees per second.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_SWEEP_MIN") then {WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_SWEEP_MIN = 60}; //--- minimum reveal arc, degrees.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_SWEEP_RAND") then {WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_SWEEP_RAND = 30}; //--- random extra arc on top (60-90 total).
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PUSH_RATIO") then {WFBE_C_SPECTATOR_DIRECTOR_PUSH_RATIO = 1.5}; //--- escalation ratio (vs the stamp-time score) that earns the one push-in.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PUSH_SCALE") then {WFBE_C_SPECTATOR_DIRECTOR_PUSH_SCALE = 0.85}; //--- push-in standoff multiplier (15 percent closer, eased over ~5s by the frame handler).
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_FIGHT_STAND_M") then {WFBE_C_SPECTATOR_DIRECTOR_FIGHT_STAND_M = 70}; //--- compact-fight standoff radius (live-proven values).
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_FIGHT_STAND_H") then {WFBE_C_SPECTATOR_DIRECTOR_FIGHT_STAND_H = 30}; //--- compact-fight standoff height.
if (isNil "WFBE_C_SPECTATOR_DIRECTOR_PEN_EXCLUDE_M") then {WFBE_C_SPECTATOR_DIRECTOR_PEN_EXCLUDE_M = 200}; //--- eligibility exclusion radius around the deadspawn pens/parks.
if (isNil "WFBE_C_SPECTATOR_FRAME_AIM_GAIN") then {WFBE_C_SPECTATOR_FRAME_AIM_GAIN = 2.5}; //--- frame-handler aim ease gain (per second).
if (isNil "WFBE_C_SPECTATOR_FRAME_STAND_GAIN") then {WFBE_C_SPECTATOR_FRAME_STAND_GAIN = 0.6}; //--- frame-handler standoff/height ease gain (push-in glide ~5s).
//--- Director cut preload (flag, default 0 = inert). Streams terrain/models around the NEXT
//--- shot's camera position before the snapshot flips, so a cut does not reveal unloaded
//--- ground on stream. AUTO director cuts only; manual N/B cuts stay instant.
if (isNil "WFBE_C_SPECTATOR_PRELOAD") then {WFBE_C_SPECTATOR_PRELOAD = 0}; //--- 1 = preload before auto director cuts.
if (isNil "WFBE_C_SPECTATOR_PRELOAD_MAX_SEC") then {WFBE_C_SPECTATOR_PRELOAD_MAX_SEC = 1.5}; //--- hard cap on the pre-cut wait; a slow disk can never stall the director longer than this.

//======================================================================================
//--- lane194-victory-pack fold (wave2 2026-07-31): TERRITORIAL VICTORY HOLD-TICKS
//--- When 1, the territorial victory clock counts QUALIFYING LOOP TICKS rather than raw
//--- wall-time. Prevents banking wall-time across a mid-window threshold dip.
//--- When 0 (default OFF), existing wall-time clock is used (legacy / flag-off inert).
if (isNil "WFBE_C_TERRVIC_HOLDTICKS") then {WFBE_C_TERRVIC_HOLDTICKS = 0};

//======================================================================================
//--- lane194-victory-pack fold (wave2 2026-07-31): STATS ROUND-END FLUSH
//--- When 1 (default ON), per-player stats flush inline at winner declaration so all exit
//--- paths (AntiStack on/off) persist scores. When 0, only the post-loop flush runs.
if (isNil "WFBE_C_STATS_ROUNDEND_FLUSH") then {WFBE_C_STATS_ROUNDEND_FLUSH = 1};

//--- fable/founding-placement-20260802 (owner live bug 2026-08-02, m0801h-era): two AICOM production
//--- placement defects. Both default 0 (byte-identical to HEAD until armed).
if (isNil "WFBE_C_AICOM_TOPUP_REQUIRE_BARRACKS") then {WFBE_C_AICOM_TOPUP_REQUIRE_BARRACKS = 1}; //--- ARMED 2026-08-02 owner go (live report: infantry topping up at a barracks-less airfield). Rollback: 0.; //--- Produce.sqf TOWN-CENTER TOP-UP DISPATCHER 'parked' test matched ANY owned town (sideID-only, no structure check), so an infantry team resting at a captured airfield with NO Barracks still got fresh bodies conjured at its exact position - the same 'magic infantry' anti-pattern WFBE_C_AICOM_FOUND_REQUIRE_FACTORY was armed to stop for founding. 1 = also require an alive owned Barracks within the same 400m parked-range before granting town-parked status (HQ-parked path is unaffected - HQ always carries the home base's own factories). 0 = pre-fix any-owned-town behaviour.
if (isNil "WFBE_C_AICOM_FOUND_FACTORY_FORWARD") then {WFBE_C_AICOM_FOUND_FACTORY_FORWARD = 1}; //--- ARMED 2026-08-02 owner go (live report: AI produced at the ORIGINAL factory after MHQ move, never forward ones). Rollback: 0.; //--- AI_Commander_Teams.sqf resolved the founding/owned-factory-gate spawn point via forEach+exitWith over wfbe_structures, which is APPEND-ONLY build order (oldest first) - so HC founding (100% of the live army per B57) always used the side's FIRST factory of the matching type and a later player-built FORWARD factory was never reached. 1 = pick the alive matching-type factory nearest an unowned/enemy town instead (WFBE_CO_FNC_PickForwardFactory). 0 = pre-fix first-in-array selection.

//--- r110 (alife close-terrain formation/spacing): stamp STAG COLUMN/RED on camp-FOCUS town
//--- patrols (Common_WaypointPatrol.sqf, server_town_patrol.sqf focus path at radius/4).
//--- Default 0 = INERT: legacy engine-default posture (WEDGE/YELLOW) kept, byte-identical to HEAD.
if (isNil "WFBE_C_TOWNS_FOCUS_PATROL_POSTURE") then {WFBE_C_TOWNS_FOCUS_PATROL_POSTURE = 0};

//======================================================================================
//--- fable/endgame-awards (owner ruling 2026-08-02, SPEC-SCENARIO-POLISH-20260802.md lane 1):
//--- END-OF-ROUND LEADERBOARD + NAMED AWARDS
//--- When 1, GUI_EndOfGameStats.sqf renders a per-player round leaderboard (built client-
//--- local from allPlayers/score/side - no new networking, no new persistent state). When
//--- 0 (default OFF), the stats screen is byte-identical to pre-flag HEAD.
if (isNil "WFBE_C_ENDGAME_LEADERBOARD") then {WFBE_C_ENDGAME_LEADERBOARD = 1}; //--- ARMED 2026-08-03 owner go (wave0803c)

//--- Named round awards (Top Killer per side, Most Vehicles Lost) derived from the same
//--- leaderboard data above. Dependent on WFBE_C_ENDGAME_LEADERBOARD - inert unless that is
//--- also on. When 0 (default OFF), no awards section is appended.
if (isNil "WFBE_C_ENDGAME_AWARDS") then {WFBE_C_ENDGAME_AWARDS = 1}; //--- ARMED 2026-08-03 owner go (wave0803c)
//--- Team Menu V2 squad bulk mount/dismount (pattern studied from the rhs_cargosystem whole-squad
//--- bulk-load/staggered-dismount idiom, remade in vanilla A2 SQF). Master flag default 0 -
//--- Load/Unload Squad buttons stay hidden and MenuAction 2003/2004 no-op with the flag off.
if (isNil "WFBE_C_SQUAD_BULK_MOUNT") then {WFBE_C_SQUAD_BULK_MOUNT = 1}; //--- ARMED 2026-08-04 owner go (zombie-menu guards fixed 2026-08-03)
if (isNil "WFBE_C_SQUAD_BULK_MOUNT_RANGE") then {WFBE_C_SQUAD_BULK_MOUNT_RANGE = 10}; //--- metres; Load Squad only mounts units already within this range of the target vehicle (v1: no path-walking).
if (isNil "WFBE_C_SQUAD_BULK_MOUNT_STAGGER") then {WFBE_C_SQUAD_BULK_MOUNT_STAGGER = 0.15}; //--- seconds between staggered per-unit GetOut actions on Unload Squad, so a full vehicle does not dismount on a single tick.

//--- Terrain sector classifier (owner-shortlist item): averages jittered selectBestPlaces samples per
//--- axis (Houses/Forest/Trees/Hills) to classify each town sector for AICOM composition biasing.
//--- Phase 1 classify+cache (WFBE_C_TERRAIN_CLASSIFY_SECTORS, default 0 = INERT): once per town at
//--- boot, Common_TerrainClassifySector.sqf caches garrison/bush-camp/open-maneuver on the town
//--- object (wfbe_sector_class / wfbe_sector_classified). Zero composition effect on its own.
if (isNil "WFBE_C_TERRAIN_CLASSIFY_SECTORS") then {WFBE_C_TERRAIN_CLASSIFY_SECTORS = 1}; //--- ARMED 2026-08-04 owner go (phase-1 cache only; composition nudge stays dark)
//--- Number of jittered selectBestPlaces samples averaged per axis. Card spec: 5.
if (isNil "WFBE_C_TERRAIN_CLASSIFY_SAMPLES") then {WFBE_C_TERRAIN_CLASSIFY_SAMPLES = 5};
//--- selectBestPlaces precision argument (higher = finer/slower scan; engine samples ~(2*radius/precision)^2
//--- points per call - keep this well above the engine-doc's slow low-end, default chosen for boot-time safety).
if (isNil "WFBE_C_TERRAIN_CLASSIFY_PRECISION") then {WFBE_C_TERRAIN_CLASSIFY_PRECISION = 50};
//--- Max per-sample position jitter offset in metres (capped low so all 5 samples stay within the
//--- same town sector, never wandering into a neighbouring town's terrain).
if (isNil "WFBE_C_TERRAIN_CLASSIFY_JITTER_M") then {WFBE_C_TERRAIN_CLASSIFY_JITTER_M = 20};
//--- Phase 2 composition nudge (WFBE_C_TERRAIN_SECTOR_COMPOSITION, default 0 = INERT): hard-dependent
//--- on phase 1 having actually classified the town (wfbe_sector_classified == true, never a
//--- getVariable default) - applies a small clamped nudge to _percentage_inf in
//--- Server_GetTownGroups.sqf / _Defender.sqf. Never touches _groups_max/total spawn count -
//--- GUER-volume doctrine preserved by construction.
if (isNil "WFBE_C_TERRAIN_SECTOR_COMPOSITION") then {WFBE_C_TERRAIN_SECTOR_COMPOSITION = 0};
//--- Infantry-percentage nudge for a "garrison" classified sector (+8 = more infantry).
if (isNil "WFBE_C_TERRAIN_SECTOR_NUDGE_GARRISON") then {WFBE_C_TERRAIN_SECTOR_NUDGE_GARRISON = 8};
//--- Infantry-percentage nudge for a "bush-camp" classified sector (+4 = mild infantry/ambush skew).
if (isNil "WFBE_C_TERRAIN_SECTOR_NUDGE_BUSHCAMP") then {WFBE_C_TERRAIN_SECTOR_NUDGE_BUSHCAMP = 4};
//--- Infantry-percentage nudge for an "open-maneuver" classified sector (-8 = more vehicles).
if (isNil "WFBE_C_TERRAIN_SECTOR_NUDGE_OPEN") then {WFBE_C_TERRAIN_SECTOR_NUDGE_OPEN = -8};

//--- SQF utility library adoption (card #25, GR-2026-07-08a): arms Common_UtilLibSelfTest.sqf
//--- only - the hash/vector/delayless-dispatch functions themselves are unconditional and are
//--- NOT gated by this flag (see Common_UtilLibSelfTest.sqf, Init_Common.sqf).
if (isNil "WFBE_C_UTIL_LIB_SELFTEST") then {WFBE_C_UTIL_LIB_SELFTEST = 0};

//======================================================================================
//--- fable/fortif-placement-preview-facing (owner live report 2026-08-04, verbatim: "The issue
//--- is placement, preview, facing direction indications" for defense/fortification building).
//--- WDDM PLACEMENT-GHOST PREVIEW MAP: coin_interface.sqf's ghost-preview lookup (getText
//--- CfgVehicles >> _itemclass >> "ghostpreview") always falls through to the raw WDDM anchor
//--- classname because no CfgVehicles class defines that property anywhere in this mission tree
//--- - so the placement ghost for every WDDM-composition item (walls, HESCO, LoS screen, gate,
//--- hedgehog line, flak tower) is a random cheap decoy prop (cargo container / industrial tank /
//--- concrete slab) that looks nothing like what actually gets built and is too near-symmetric for
//--- a facing change to read visually. WFBE_ANCHOR_PREVIEW_MAP maps each affected WDDM anchor to
//--- ONE lightweight, correctly-shaped representative object already spawned by the real
//--- composition (Server_ConstructPosition.sqf / Init_Defenses.sqf WFBE_NEURODEF_* arrays) - not
//--- the whole multi-object composition (would churn 3-10 spawn/despawn (createVehicleLocal) pairs
//--- every preview-refresh tick). Every representative classname below is pairwise-distinct from
//--- every other entry AND from every WDDM anchor classname itself, so the existing
//--- "typeof _preview != _itemclass_preview" respawn check (coin_interface.sqf) still detects
//--- switching between adjacent buy-menu items. 0 (default) = coin_interface.sqf's read path is
//--- untouched - byte-identical to HEAD.
if (isNil "WFBE_C_DEF_PREVIEW_MAP") then {WFBE_C_DEF_PREVIEW_MAP = 1}; //--- ARMED 2026-08-04 owner fortification complaint
WFBE_ANCHOR_PREVIEW_MAP = [
	['Misc_cargo_cont_small', 'Hedgehog_EP1'],			//--- Hedgehog Line -> real WFBE_NEURODEF_HEDGEHOGLINE child
	['Land_Ind_TankSmall', 'Land_Ind_IlluminantTower'],		//--- Flak Tower -> WFBE_C_DEF_FLAKTOWER_STRUCTURE default host
	['Misc_cargo_cont_net1', 'Concrete_Wall_EP1'],		//--- Wall Row -> real WFBE_NEURODEF_FORTIF_WALL_ROW child
	['Misc_cargo_cont_net2', 'Base_WarfareBBarrier5x'],		//--- Wall Corner -> validated wall segment (composition is 10x Concrete_Wall_EP1, already Wall Row's preview - respawn check needs a distinct class)
	['Misc_cargo_cont_net3', 'Base_WarfareBBarrier10xTall'],	//--- LoS Screen -> real WFBE_NEURODEF_FORTIF_LOS_SCREEN child
	['Misc_cargo_cont_tiny', 'Land_HBarrier_large'],		//--- HESCO Line -> real WFBE_NEURODEF_FORTIF_HESCO_LINE child
	['Misc_concrete_High', 'Land_CncBlock_Stripes']	//--- Gate Complex -> proven gate-mouth block (Land_BarGate2 is A2-only/unverified in this tree - see Init_Defenses.sqf Bank precedent)
];
//--- wave0804b (placement rejected inside HQ circle): flat list of just the representative real classnames
//--- above, for the Init_Client.sqf itemcategory==2 same-classname/DEFENSENAMES proximity-check exemption.
//--- A2-safe: forEach (never A3 apply).
WFBE_ANCHOR_PREVIEW_CLASSES = [];
{WFBE_ANCHOR_PREVIEW_CLASSES = WFBE_ANCHOR_PREVIEW_CLASSES + [_x select 1]} forEach WFBE_ANCHOR_PREVIEW_MAP;

//--- TICK-INCREMENT PLACEMENT ROTATION (same owner report). coin_interface.sqf's rotate hint
//--- ("ROTATE=[Ctrl]", str_coin_rotate) had never been wired to any setDir call - _ctrl was
//--- computed every poll tick and never read again. 0 (default) = coin_interface.sqf's placement
//--- loop is untouched - byte-identical to HEAD. >0 = holding Ctrl while an existing preview is up
//--- rotates it by WFBE_C_DEF_PLACE_ROTATE_DEG_SEC degrees/second (scaled by WFBE_C_COIN_POLL_SLEEP,
//--- so speed is independent of poll rate) and shows a live degree readout next to the rotate hint.
if (isNil "WFBE_C_DEF_PLACE_ROTATE") then {WFBE_C_DEF_PLACE_ROTATE = 1}; //--- ARMED 2026-08-04 owner fortification complaint
if (isNil "WFBE_C_DEF_PLACE_ROTATE_DEG_SEC") then {WFBE_C_DEF_PLACE_ROTATE_DEG_SEC = 90};
//--- bughunt r124 (dead guards never armed): six mission-core levers whose only reference was a
//--- getVariable fallback at the read site - the fallback applied forever and the documented
//--- off/retune switch did not exist. Defaults equal the in-code fallbacks, so live behaviour is
//--- unchanged; the levers are now real and overridable.
if (isNil "WFBE_C_AB_AMPLE_ECON") then {WFBE_C_AB_AMPLE_ECON = 1}; //--- read initJIPCompatible.sqf:182 (fallback 1): B36.1 starting-economy override (30000 funds / 12800 supply per side). 0 disables; previously unarmable.
if (isNil "WFBE_C_ICBM_TEL_NUKE_COST") then {WFBE_C_ICBM_TEL_NUKE_COST = 75000}; //--- read Server/Init/Init_IcbmTel.sqf:729 (fallback 75000): NUKE munition price - the only TEL cost never registered (SAT/RECON/FASCAM/RAIN/BUSTER all were).
if (isNil "WFBE_C_GUER_VBIED_CREDIT_KILLS") then {WFBE_C_GUER_VBIED_CREDIT_KILLS = 1}; //--- read Server/Functions/Server_HandleSpecial.sqf:2400 (fallback 1): VBIED driver kill-stat credit + WFBE_GUER_PLAYER_KILLS tier progress. 0 disables; previously unarmable.
if (isNil "WFBE_C_DISCONNECT_ZOMBIE_TIMEOUT") then {WFBE_C_DISCONNECT_ZOMBIE_TIMEOUT = 600}; //--- read Server/FSM/server_groupsGC.sqf:373 (fallback 600): orphaned-team zombie reaper timeout (s). The read-site comment "set the param to 0 to disable" now works.
if (isNil "WFBE_C_MARKER_REBUILD_FPS") then {WFBE_C_MARKER_REBUILD_FPS = 15}; //--- read Common/Common_MarkerLoop.sqf:49 (fallback 15): auto map-marker rebuild while client fps stays below this. 0 disables; previously unarmable.
if (isNil "WFBE_C_MARKER_BUDGET_PER_TICK") then {WFBE_C_MARKER_BUDGET_PER_TICK = 30}; //--- read Common/Common_MarkerLoop.sqf:83 (fallback 30): fixed per-tick marker-refresh ceiling; the BUDGET_ADAPT block above references it as "above" but it was never declared.

//--- STAR FORTRESS Phase 1 MVP. Default 0 keeps the action, PV endpoint, registries, construction
//--- watcher, respawn candidate, and status watcher inert.
if (isNil "WFBE_C_STARFORT_ENABLE") then {WFBE_C_STARFORT_ENABLE = 0};
if (isNil "WFBE_C_STARFORT_UNLOCK_BARRACKS_LVL") then {WFBE_C_STARFORT_UNLOCK_BARRACKS_LVL = 3};
if (isNil "WFBE_C_STARFORT_MIN_ENEMY_TOWN_DIST") then {WFBE_C_STARFORT_MIN_ENEMY_TOWN_DIST = 800};
if (isNil "WFBE_C_STARFORT_MAX_FRONTLINE_DIST") then {WFBE_C_STARFORT_MAX_FRONTLINE_DIST = 1500};
if (isNil "WFBE_C_STARFORT_MIN_ENEMY_HQ_DIST") then {WFBE_C_STARFORT_MIN_ENEMY_HQ_DIST = 1000};
if (isNil "WFBE_C_STARFORT_OBJ_CAP") then {WFBE_C_STARFORT_OBJ_CAP = 55};
if (isNil "WFBE_C_STARFORT_OBJ_CAP_HARD") then {WFBE_C_STARFORT_OBJ_CAP_HARD = 60};
if (isNil "WFBE_C_STARFORT_BASTIONS") then {WFBE_C_STARFORT_BASTIONS = 4};
if (isNil "WFBE_C_STARFORT_BREACH_BASTIONS_LOST") then {WFBE_C_STARFORT_BREACH_BASTIONS_LOST = 2};
if (isNil "WFBE_C_STARFORT_COST_FOUNDATION") then {WFBE_C_STARFORT_COST_FOUNDATION = 6000};
if (isNil "WFBE_C_STARFORT_COST_WALLS") then {WFBE_C_STARFORT_COST_WALLS = 15000};
if (isNil "WFBE_C_STARFORT_COST_BASTIONS") then {WFBE_C_STARFORT_COST_BASTIONS = 28000};
if (isNil "WFBE_C_STARFORT_BUILD_TIME") then {WFBE_C_STARFORT_BUILD_TIME = 300};
if (isNil "WFBE_C_STARFORT_RADIUS") then {WFBE_C_STARFORT_RADIUS = 25};
if (isNil "WFBE_C_STARFORT_SLOPE_MAX") then {WFBE_C_STARFORT_SLOPE_MAX = 0.97};
if (isNil "WFBE_C_STARFORT_PENDING_WINDOW") then {WFBE_C_STARFORT_PENDING_WINDOW = 180};
if (isNil "WFBE_C_STARFORT_ALLYMARKER") then {WFBE_C_STARFORT_ALLYMARKER = 0}; //--- DESIGN-4: 0 = today's global enemy-visible marker (byte-identical); 1 = allies-only WildcardMarker + JIP replay.

//--- PR #1464 reconcile: late-game teleport for fully-AI, base-idle WEST/EAST teams.
//--- Decision runs after relief/withdrawal and before HQ hunt; execution stays on the
//--- existing team driver so HC and server-local teams move only where they are local.
//--- All defaults are 0: the feature is inert until the owner arms and tunes the complete set.
if (isNil "WFBE_C_AICOM_ENDGAME_TELEPORT_ENABLE") then {WFBE_C_AICOM_ENDGAME_TELEPORT_ENABLE = 0};
if (isNil "WFBE_C_AICOM_ENDGAME_TELEPORT_MIN_TIME") then {WFBE_C_AICOM_ENDGAME_TELEPORT_MIN_TIME = 0};
if (isNil "WFBE_C_AICOM_ENDGAME_TELEPORT_COOLDOWN") then {WFBE_C_AICOM_ENDGAME_TELEPORT_COOLDOWN = 0};
if (isNil "WFBE_C_AICOM_ENDGAME_TELEPORT_MAX_PER_TICK") then {WFBE_C_AICOM_ENDGAME_TELEPORT_MAX_PER_TICK = 0};
if (isNil "WFBE_C_AICOM_ENDGAME_TELEPORT_MIN_DIST") then {WFBE_C_AICOM_ENDGAME_TELEPORT_MIN_DIST = 0};

//--- fix0807e (chute-occupant-teardown, Server_GuerAirDef.sqf) BEGIN - keep this block intact/together
//--- at fold time if a concurrent lane's own append lands nearby; do not interleave.
if (isNil "WFBE_C_GUER_AIRDEF_DROP_LANDED_CEILING") then {WFBE_C_GUER_AIRDEF_DROP_LANDED_CEILING = 240}; //--- hard ceiling (seconds since drop registration) after which the drop-prune defer guard gives up waiting for wfbe_guer_drop_landed and lets a non-"wiped" recall through anyway; generous over the ~97s worst-case paradrop descent so it never fires in normal play.
//--- fix0807e END

//--- fix0807e (Mi-24 IFF-aware airframe selection, Server_GuerAirDef.sqf) BEGIN - owner-approved
//--- same-lane addition 2026-08-08 - keep this block intact/together at fold time if a concurrent
//--- lane's own append lands nearby; do not interleave.
if (isNil "WFBE_C_GUER_AIRDEF_IFF_AWARE") then {WFBE_C_GUER_AIRDEF_IFF_AWARE = 1}; //--- master switch: pick the Mi-24 airframe by dominant attacker side so it never radar-spoofs FRIENDLY to the side actually attacking it (A2 pre-identification colors by the airframe's own CfgVehicles side). 0 restores the single-class WFBE_C_GUER_AIRDEF_CLASS_MI24 behaviour.
if (isNil "WFBE_C_GUER_AIRDEF_CLASS_MI24_VSWEST") then {WFBE_C_GUER_AIRDEF_CLASS_MI24_VSWEST = "Mi24_P"}; //--- airframe when the detected attackers are WEST (EAST-config hull so it reads hostile to them); unchanged from today's single-class default.
if (isNil "WFBE_C_GUER_AIRDEF_CLASS_MI24_VSEAST") then {WFBE_C_GUER_AIRDEF_CLASS_MI24_VSEAST = "Mi24_D_CZ_ACR"}; //--- airframe when the detected attackers are EAST (WEST-config ACR hull so it reads hostile to them); already spawned/rostered elsewhere in this repo (Core_ACR.sqf, EASA_Init.sqf, Common_BalanceInit.sqf, Units_CO_US.sqf/Units_USMC.sqf) - no new/unverified classname.
//--- fix0807e END
//--- w807e-L17 (owner-approved 2026-08-08, feature pair: early-game GUER defense). Both flag-gated,
//--- defaults ARMED per repo flag policy (owner: we go with these); rollback = set the *_MULT to 1.0
//--- / the *_ENABLE flags to 0 (documented in the PR body).
//---
//--- (1) Early-window GUER patrol density boost - read in Server/FSM/server_side_patrols.sqf.
//--- Time-decaying multiplier on the GUER-only concurrent side-patrol cap + spawn cadence for the
//--- first EARLY_WINDOW seconds of a mission, linearly tapering to 1.0 (baseline). Telemetry:
//--- PATROLBOOST|v1| lines from the same file.
if (isNil "WFBE_C_GUER_PATROL_EARLY_ENABLE") then {WFBE_C_GUER_PATROL_EARLY_ENABLE = 1};
if (isNil "WFBE_C_GUER_PATROL_EARLY_MULT") then {WFBE_C_GUER_PATROL_EARLY_MULT = 2.0};
if (isNil "WFBE_C_GUER_PATROL_EARLY_WINDOW") then {WFBE_C_GUER_PATROL_EARLY_WINDOW = 3600};
//---
//--- (2) Siege-triggered GUER ground QRF - read in Server/Server_GuerAirDef.sqf. Reinforces a
//--- besieged GUER town from a neighboring GUER-held town, gated on the CAPGATE mode2 sustained-
//--- siege streak (server_town.sqf wfbe_capgate_siege_streak). Distinct from the pre-existing
//--- WFBE_C_GUER_GROUND_QRF (E3) feature above - see Server_GuerAirDef.sqf for the design note.
//--- Telemetry: GUERQRF|v1|DISPATCH/ARRIVE/DENY lines from the same file.
if (isNil "WFBE_C_GUER_QRF_ENABLE") then {WFBE_C_GUER_QRF_ENABLE = 1};
if (isNil "WFBE_C_GUER_QRF_CHANCE") then {WFBE_C_GUER_QRF_CHANCE = 0.3};
if (isNil "WFBE_C_GUER_QRF_SIEGE_THRESHOLD") then {WFBE_C_GUER_QRF_SIEGE_THRESHOLD = 6};
if (isNil "WFBE_C_GUER_QRF_COOLDOWN") then {WFBE_C_GUER_QRF_COOLDOWN = 300};
if (isNil "WFBE_C_GUER_QRF_MAX_ATTACKER_FORCE") then {WFBE_C_GUER_QRF_MAX_ATTACKER_FORCE = 16};
if (isNil "WFBE_C_GUER_QRF_MAX_SOURCE_DIST") then {WFBE_C_GUER_QRF_MAX_SOURCE_DIST = 3000};
if (isNil "WFBE_C_GUER_QRF_SOURCE_MAX_ENEMIES") then {WFBE_C_GUER_QRF_SOURCE_MAX_ENEMIES = 0};
if (isNil "WFBE_C_GUER_QRF_MAX_CONCURRENT") then {WFBE_C_GUER_QRF_MAX_CONCURRENT = 2};
if (isNil "WFBE_C_GUER_QRF_LIFETIME") then {WFBE_C_GUER_QRF_LIFETIME = 600};
if (isNil "WFBE_C_GUER_QRF_ARRIVE_DIST") then {WFBE_C_GUER_QRF_ARRIVE_DIST = 150};

["INITIALIZATION", "Init_CommonConstants.sqf: Constants are defined."] Call WFBE_CO_FNC_LogContent;

