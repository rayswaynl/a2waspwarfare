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

	//--- GUER improvised mortar strike (V3S_Gue driver call-in barrage; Action_GuerMortarStrike.sqf -> RequestSpecial -> Server_HandleSpecial "guer-mortar-strike").
	if (isNil "WFBE_C_GUER_MORTAR_COOLDOWN") then {WFBE_C_GUER_MORTAR_COOLDOWN = 240};	//--- seconds between GUER mortar strikes (per player).
	if (isNil "WFBE_C_GUER_MORTAR_RANGE")    then {WFBE_C_GUER_MORTAR_RANGE    = 1200};	//--- max designation range from the calling player (m).
	if (isNil "WFBE_C_GUER_MORTAR_SHELLS")   then {WFBE_C_GUER_MORTAR_SHELLS   = 6};	//--- shells per barrage.
	if (isNil "WFBE_C_GUER_MORTAR_COST")     then {WFBE_C_GUER_MORTAR_COST     = 200};	//--- funds debited from the caller's GUER team per strike (0 = free).
	if (isNil "WFBE_C_GUER_MORTAR_SPREAD")          then {WFBE_C_GUER_MORTAR_SPREAD          = 25};	//--- base +/- impact spread (m) at tier 0.
	if (isNil "WFBE_C_GUER_MORTAR_SPREAD_TIERSTEP") then {WFBE_C_GUER_MORTAR_SPREAD_TIERSTEP = 4};	//--- spread tightens by this many m per GUER vehicle tier.
	if (isNil "WFBE_C_GUER_MORTAR_SPREAD_MIN")      then {WFBE_C_GUER_MORTAR_SPREAD_MIN      = 8};	//--- floor on the +/- spread (m), however high the tier.

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
		//--- Second VBIED: an UNARMED M113 with ~2x speed (driver-detonated, same blast + cash-for-kills as the hilux),
		//--- kill-gated into the GUER depot. M113_UN_EP1 exists on both maps so the type is map-independent (no TK repoint).
		if (isNil "WFBE_C_GUER_VBIED_M113_TYPE") then {WFBE_C_GUER_VBIED_M113_TYPE = "M113_UN_EP1"};
		if (isNil "WFBE_C_GUER_VBIED_M113_KILLS") then {WFBE_C_GUER_VBIED_M113_KILLS = 50}; //--- 2x-ed (was 25): GUER kills required before the M113 VBIED appears in the depot.
		if (isNil "WFBE_C_GUER_VBIED_M113_SPEEDCOEF") then {WFBE_C_GUER_VBIED_M113_SPEEDCOEF = 2.0}; //--- target top-speed multiplier of the driver-local boost loop (~2x stock M113).
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
		//--- _this) is inside an enemy (WEST/EAST) build-restricted area - within WFBE_C_GUER_FOB_TOWN_BLOCK of an
		//--- enemy-HELD town, or inside a WEST/EAST base area. Neutral / GUER-held towns are allowed (you can "extend"
		//--- near a friendly GUE factory). No early-exit inside then{} (A2-OA gotcha) - plain flag accumulation.
		WFBE_FNC_GuerFobBlocked = {
			private ["_pos","_blocked","_tSideID","_eLogik","_eArea","_blockDist","_townList"];
			_pos = _this;
			_blocked = false;
			_blockDist = missionNamespace getVariable ["WFBE_C_GUER_FOB_TOWN_BLOCK", 600];
			//--- never on water.
			if (surfaceIsWater _pos) then {_blocked = true};
			//--- qol-polish-pack: reject too-steep ground (FOB factory floats/tilts on slopes; mirrors the AI commander's isFlatEmpty gate).
			if (!_blocked && {(missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_CHECK", 1]) > 0} && {count (_pos isFlatEmpty [(missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_RADIUS", 10]), 0, (missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_GRAD", 0.5]), 10, 0, false, objNull]) == 0}) then {_blocked = true};
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
	if (isNil "WFBE_C_GUER_AIRDEF_MAX") then {WFBE_C_GUER_AIRDEF_MAX = 4};              //--- global alive cap on GUER air defenders (hard FPS bound).
	if (isNil "WFBE_C_GUER_AIRDEF_AT_CHANCE") then {WFBE_C_GUER_AIRDEF_AT_CHANCE = 0.20}; //--- chance a spawned Ka-137 carries the EASA AT (Konkurs/AT-5) loadout.
	if (isNil "WFBE_C_GUER_AIRDEF_MI24_CHANCE") then {WFBE_C_GUER_AIRDEF_MI24_CHANCE = 0.25}; //--- chance a LARGE GUER town under attack fields a Mi-24 gunship instead.
	if (isNil "WFBE_C_GUER_AIRDEF_AA_CHANCE") then {WFBE_C_GUER_AIRDEF_AA_CHANCE = 0.75}; //--- chance a Ka-137 fields the EASA Igla AA loadout when ENEMY AIR is near the town (counter-air; takes priority over Mi-24/AT roll).
	if (isNil "WFBE_C_GUER_AIRDEF_CLASS_KA") then {WFBE_C_GUER_AIRDEF_CLASS_KA = "Ka137_MG_PMC"}; //--- default light air defender (recon/strike).
	if (isNil "WFBE_C_GUER_AIRDEF_CLASS_MI24") then {WFBE_C_GUER_AIRDEF_CLASS_MI24 = "Mi24_P"};   //--- heavy gunship for large contested towns.
	if (isNil "WFBE_C_GUER_AIRDEF_LIFETIME") then {WFBE_C_GUER_AIRDEF_LIFETIME = 900};  //--- max seconds a defender lives before forced recycle (anti-accumulation).
	if (isNil "WFBE_C_GUER_AIRDEF_QUIET_DESPAWN") then {WFBE_C_GUER_AIRDEF_QUIET_DESPAWN = 300}; //--- despawn after this many seconds with no enemies near the town.
	if (isNil "WFBE_C_GUER_AIRDEF_LARGE_SV") then {WFBE_C_GUER_AIRDEF_LARGE_SV = 2500}; //--- maxSupplyValue at/above which a town counts as LARGE (Mi-24 eligible); town_type Large/Huge also qualifies.
	if (isNil "WFBE_C_GUER_AIRDEF_HEIGHT") then {WFBE_C_GUER_AIRDEF_HEIGHT = 120};      //--- flyInHeight for spawned GUER air.

//--- KA-137 SWARM ROLL (cmdcon42, Ray 2026-07-02): when the AIRDEF loop fields a COMBAT Ka-137 (recon-MG / AT / AA,
//--- NOT the paradrop bird or the Mi-24), roll for it to be MORE THAN ONE — extras created INTO THE SAME group so
//--- they formation-fly as a drone flock. Extras COUNT toward WFBE_C_GUER_AIRDEF_MAX; the roll is skipped once the
//--- cap is reached, so a swarm never exceeds the air budget. Only relevant when the GUER AIRDEF loop is enabled.
	if (isNil "WFBE_C_GUER_KA137_SWARM") then {WFBE_C_GUER_KA137_SWARM = 1};                //--- master switch (1 = swarm rolls enabled, 0 = single drone only).
	if (isNil "WFBE_C_GUER_KA137_SWARM_CHANCE") then {WFBE_C_GUER_KA137_SWARM_CHANCE = 0.25}; //--- chance a combat Ka-137 spawn also fields a 2nd drone in the same group.
	if (isNil "WFBE_C_GUER_KA137_SWARM_CHANCE3") then {WFBE_C_GUER_KA137_SWARM_CHANCE3 = 0.15}; //--- chance (only if the 2nd rolled) for a 3rd drone in the same group.

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
	if (isNil "WFBE_C_AICOM_PUBLIC_STATE_SYNC") then {WFBE_C_AICOM_PUBLIC_STATE_SYNC = 0}; //--- Default OFF: keep wfbe_aicom_funds/running server-local. 1 = broadcast side-logic AICOM state writes for HC readers.
	if (isNil "WFBE_C_AICOM_TELEPORT_ORDER_FLUSH") then {WFBE_C_AICOM_TELEPORT_ORDER_FLUSH = 1}; //--- Lane 377: after teleport-equivalent relocation, publish a fresh HC order from the new position.
	//--- ACTIVE-TOWN BUDGET: max concurrently active towns. FPS lever; 12 for the legacy-vs-next A/B (Steff 2026-06-13).
	if (isNil "WFBE_C_TOWNS_ACTIVE_MAX") then {WFBE_C_TOWNS_ACTIVE_MAX = 12}; //--- punchy-AICOM (Ray 2026-06-18): KEEP 12 for the next test - concentration comes from SPEARHEAD_TOWNS_MAX=1 + CONCENTRATION=4 (mass on one town of the full 12-town front), NOT from shrinking the active set.
	if (isNil "WFBE_C_TOWNS_STARTUP_SLEEP") then {WFBE_C_TOWNS_STARTUP_SLEEP = 0}; //--- Fleet lane 115: optional startup pacing for server_town_ai's two town init passes. 0 = legacy 0.01s; try 0.05-0.10 to soften large-map startup spikes.
	//--- GUER GROUP CAP: hard ceiling on total resistance groups. Bounds runaway GUER growth toward the engine's ~144-groups/side
	//--- limit over long stalled AI-vs-AI runs (garrisons + W9 uprising + side-patrols, none of which had a global cap).
	//--- 90 is far above any single-front GUER force, well under the 144 ceiling; raise to 999 for an instant rollback.
	if (isNil "WFBE_C_GUER_GROUPS_MAX") then {WFBE_C_GUER_GROUPS_MAX = 80}; //--- 60->80 (Ray 2026-06-15, fold from fleet group-budget tuning): 60 choked GUER garrisons above the observed ~73 peak; 80 restores headroom, still well under the 144 engine cap. Was 90; raise to 999 for instant rollback.
	if (isNil "WFBE_C_AI_MAX") then {WFBE_C_AI_MAX = 12}; //--- Max AI allowed on each AI groups.
	if (isNil "WFBE_C_AI_DELEGATION") then {WFBE_C_AI_DELEGATION = 0}; //--- Enable AI delegation (0: Disabled, 1: creation of ai on the client, 2: Headless Client).
	if (isNil "WFBE_C_STATIC_DEF_COMBAT") then {WFBE_C_STATIC_DEF_COMBAT = 1}; //--- D10#4: 1 = manned static town-defence gunners get an explicit combat posture (setBehaviour AWARE + setCombatMode RED) so they engage; 0 = legacy passive. AWARE (not COMBAT) keeps them on the gun. Balance change (defended towns harder); ships inert.
	if (isNil "WFBE_C_AI_TEAMS_ENABLED") then {WFBE_C_AI_TEAMS_ENABLED = 1}; //--- Enable or disable the AI Teams.
	if (isNil "WFBE_C_AI_TEAMS_JIP_PRESERVE") then {WFBE_C_AI_TEAMS_JIP_PRESERVE = 1}; //--- Keep the AI Teams units on JIP.
	WFBE_C_AI_COMMANDER_MOVE_INTERVALS = 3600;
	WFBE_C_AI_COMMANDER_SUPPLY_TRUCKS_MAX = 5;
	//--- AI Commander revival (feat/ai-commander).
	WFBE_C_AI_COMMANDER_TOTAL_AI_MAX = 140;    //--- B59 (Ray 2026-06-20): 130->190 so 15 teams/side actually fill (15*12 worst-case +10 buffer) and the side-gate (AI_Commander_Produce.sqf:28-30) doesn't starve the last teams below the 8-floor. Rollback: 130. Prior punchy-AICOM (Ray 2026-06-17): 72->130. Sized for 10 teams x [8,12] units: worst case 10*12=120, +10 buffer so the side-gate in AI_Commander_Produce.sqf (:28-30) does not fire at 119 and starve the last team back below the 8-floor. DELIBERATE commander-AI raise (testing trade-off Ray accepts). Rollback: 72.
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
	WFBE_C_AICOM_TEAMS_PC_LOW  = 10;           //--- B59 (Ray 2026-06-20): 10->15 max HQ teams/side (low pop) to really push the load test, Ray's call. ~15*10 found-size = 150/side; TOTAL_AI_MAX raised 130->190 to fit so the side-gate doesn't starve the last teams. EXPECT lower server FPS (this IS the load test). Rollback: 10.  [historical B57 note follows] Pairs with the founding-pad (teams found at 8-12) for larger massed groups. ~10*8=80/side < TOTAL_AI_MAX 130 (watch server FPS). Prior B49 had cut 10->5: FEWER/BIGGER teams - the B48 soak gridlocked at ~2 captures with 10 thin (~5-unit) teams + banked funds; 5 teams fill to 8-12 each and CONCENTRATION=4 massed on the spearhead actually cracks garrisons. 5*12=60 units << TOTAL_AI_MAX 130 (FPS-safe). Rollback: 10.
	WFBE_C_AICOM_TEAMS_PC_MID  = 7;            //--- Build83 (Ray 2026-07-01): ~20% commander-team trim, 8->7. 3-5 players.
	WFBE_C_AICOM_TEAMS_PC_HIGH = 4;            //--- Build83: ~20% trim, 5->4.
	WFBE_C_AICOM_TEAMS_PC_FULL = 3;            //--- rollback the whole curve: set all four to 2.
	WFBE_C_AICOM_TEAMS_HARD_CAP = 10;          //--- Ray 2026-06-29: 8 -> 10 max teams/side (Ray: low-pop fielding; reverts the 2026-06-28 10->8). [prior B752 2026-06-25: back to 8 max teams (13 over-throttled the per-side TOTAL_AI cap + fed the hoard in the 12h TK soak). Shared CH+TK via LoadoutManager. HARD ceiling on the AI-commander founding target regardless of the PC curve + banking valve (was fielding ~15 at low pop = base 12 + valve 3). Clamped in AI_Commander_Teams.sqf. Rollback: 99 (effectively off).
	//--- cmdcon42-k (Ray 2026-07-02): DROP N teams off EACH AI commander's BASE founding target on BOTH maps (the new
	//--- dynamic transport/patrol/swarm systems in Build 87 add per-team AI; HQ teams now hand the server too much AI to
	//--- handle). DELTA is applied to the PC-scaled base team target (WFBE_C_AICOM_TEAMS_PC_* after the curve overwrites
	//--- WFBE_C_AI_COMMANDER_TEAMS_TARGET) in AI_Commander_Teams.sqf, so the funds-extra + surge (+2) ride ON TOP of the
	//--- REDUCED base, and the hard cap (above) still clamps the ceiling. FLOOR guards a config accident from zeroing the
	//--- army (a side that founds 0 teams loses this fork by walkover). DELTA 0 => EXACT current behaviour (easy revert).
	WFBE_C_AICOM_TEAMS_DELTA = -1;             //--- cmdcon42-k: teams dropped from the base founding target per AI commander (both maps). 0 = no change (rollback).
	WFBE_C_AICOM_TEAMS_FLOOR = 3;              //--- cmdcon42-k: minimum effective base target after the delta - never let a config accident starve the army below this.
	WFBE_C_AICOM_DISBAND_SAFE_DIST = 1200;     //--- punchy-AICOM (Ray 2026-06-17): 600->1200 - wider no-retire radius so rear teams are kept (more standing army), only retiring when truly far from any player. Rollback: 600.
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
	WFBE_C_TOTAL_AI_MAX_BY_TIER       = [140,130,100,80];     //--- per-side commander-AI ceiling (founding gate + AI_Commander_Produce)
	WFBE_C_AICOM_LOWPOP_EXTRA_BY_TIER = [3,2,0,0];            //--- funds-valve extra teams (valve only fires pop<=5 = LOW/MID)
	WFBE_C_TOWNS_DEFENDER_BY_TIER     = [2,2,2,1];            //--- town garrison difficulty -> COEF (Medium/Medium/Medium/Light)
	WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER   = [12,12,10,8];         //--- concurrently-active-towns cap (the single largest AI slice)
	WFBE_C_SIDE_PATROLS_MAX_BY_TIER   = [3,3,3,2];            //--- Build83 (Ray 2026-07-01): +1 WEST/EAST side-patrol cap per tier ([2,2,2,1]->[3,3,3,2]). Effective = min(this, patrol level).
	WFBE_C_PLAYERS_AI_MAX_BY_TIER     = [16,14,12,10];        //--- per-player AI buy-cap (recruit cap; never deletes an existing squad)
	WFBE_C_AICOM_INCOME_PC_BONUS_VALVE = 0.045; //--- B37: gentler low-pop income boost when the valve is on (vs 0.06), so more-squads does not over-bank.
	WFBE_C_AICOM_INCOME_MULT_MAX = 4.0;        //--- B67 (Ray 2026-06-21): 3.0->4.0 - lift the town-cash multiplier ceiling so the low-pop inverted bonus is not clipped (keeps near-empty-server PvE well-funded). CASH only. hard ceiling on the scaled commander income multiplier (packed-server runaway guard).
	if (isNil "WFBE_C_AICOM_AIR_MIN_TOWNS") then {WFBE_C_AICOM_AIR_MIN_TOWNS = 3}; //--- B66: 4->3 - bring air online a town sooner. Aircraft are deferred until the AI holds this many towns (it flies poorly; air is a late, established-only asset). 0 = no gate.
	if (isNil "WFBE_C_AIR_ATTACK_GUNNER") then {WFBE_C_AIR_ATTACK_GUNNER = 1}; //--- 0 = off (default, byte-identical). Set 1 to mount a GUNNER on AICOM attack helicopters (AI_Commander_AirResp/Wildcard W13) so AH64/AH1Z/Mi24 can actually fire their gunner-seat armament (Hellfire/TOW/Vikhr) instead of flying pilot-only + never engaging. Mirrors the shipped B62 gunner-mount (Server_GuerAirDef.sqf:378-387). Gunner mounted only if the airframe has an empty gunner seat. Balance-affecting (AI air becomes lethal) => soak/playtest before arming.
	if (isNil "WFBE_C_AICOM_AIR_COUNCIL_PACK") then {WFBE_C_AICOM_AIR_COUNCIL_PACK = 0}; //--- B757 roster council air templates: 0 = registered but dark; owner can arm the additive air pack explicitly.
	//--- B74.2 EMPTY-HELI FIX (Ray 2026-06-24, AH1Z piling at base): hard per-side cap on how many attack-heli
	//--- (non-transport Helicopter) airframes the commander may have ALIVE at once. Once at/over the cap the
	//--- founding path strips air templates from _eligible (it degrade-walks to a buildable ground class), so it
	//--- stops founding more premium AH1Z teams that the cost-weighted draw keeps picking and that nothing retires.
	//--- 0 = no cap (old behaviour). Counts ALL alive non-transport helis on the side (founded teams + any others),
	//--- so it is self-limiting regardless of where the airframe came from.
	if (isNil "WFBE_C_AICOM_ATTACKHELI_MAX") then {WFBE_C_AICOM_ATTACKHELI_MAX = 4};
	//--- === Build 83 / cmdcon35 constants (claude-gaming 2026-07-01) ===
	if (isNil "WFBE_C_AICOM_HQ_NUDGE_MAX_R") then {WFBE_C_AICOM_HQ_NUDGE_MAX_R = 200};  //--- AI HQ off-road nudge: max expanding-ring radius (m) before using best off-road candidate.
	if (isNil "WFBE_C_AICOM_HQ_NUDGE_STEP") then {WFBE_C_AICOM_HQ_NUDGE_STEP = 25};     //--- AI HQ off-road nudge: ring radius growth per step (m).
	if (isNil "WFBE_C_GUER_AIRDEF_DROP_CHANCE") then {WFBE_C_GUER_AIRDEF_DROP_CHANCE = 0.18}; //--- Ka-137 cargo/paradrop roll when a GUER town is under GROUND attack.
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
	if (isNil "WFBE_C_OILFIELD_INCOME_SUPPLY") then {WFBE_C_OILFIELD_INCOME_SUPPLY = 25};   //--- supply credited to the owner per income tick (small).
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
	//--- === cmdcon42-oilrig DYNAMIC placement (Ray placement spec 2026-07-02: derrick on open ground BETWEEN the teams) ===
	if (isNil "WFBE_C_OILFIELD_DYNAMIC") then {WFBE_C_OILFIELD_DYNAMIC = 1};               //--- 1 = per-match dynamic placement: HQ-midpoint + open-ground ring search + spawned derrick composition. 0 = legacy fixed-anchor auto-snap (no composition).
	if (isNil "WFBE_C_OILFIELD_HQ_WAIT") then {WFBE_C_OILFIELD_HQ_WAIT = 600};             //--- max seconds to wait for BOTH start HQs to exist before falling back to the legacy anchor.
	if (isNil "WFBE_C_OILFIELD_RING_STEP") then {WFBE_C_OILFIELD_RING_STEP = 100};         //--- ring-search radius step (m) out from the HQ midpoint (floored 25m in code).
	if (isNil "WFBE_C_OILFIELD_RING_MAX") then {WFBE_C_OILFIELD_RING_MAX = 2000};          //--- max ring-search radius (m); beyond this the dynamic path gives up (WARNING + legacy fallback).
	if (isNil "WFBE_C_OILFIELD_FLAT_Z") then {WFBE_C_OILFIELD_FLAT_Z = 0.90};              //--- min (surfaceNormal) z for a candidate spot (1.0=flat; foot-snap uses 0.85, structures want flatter).
	if (isNil "WFBE_C_OILFIELD_ROAD_CLEAR") then {WFBE_C_OILFIELD_ROAD_CLEAR = 60};        //--- candidate rejected if any road within this (m) (nearRoads).
	if (isNil "WFBE_C_OILFIELD_TOWN_CLEAR") then {WFBE_C_OILFIELD_TOWN_CLEAR = 500};       //--- candidate rejected if any town center (towns list) within this (m).
	if (isNil "WFBE_C_OILFIELD_HOUSE_CLEAR") then {WFBE_C_OILFIELD_HOUSE_CLEAR = 80};      //--- candidate rejected if any building ("House") within this (m).
	if (isNil "WFBE_C_PATROL_T3_CASH") then {WFBE_C_PATROL_T3_CASH = 8000};                //--- Build83 (Ray): one-time CASH granted to a side on completing Patrol upgrade level 3 (split among alive players via BankPayout). 0 = off.
	if (isNil "WFBE_C_PATROL_T4_SUPPLY") then {WFBE_C_PATROL_T4_SUPPLY = 1500};             //--- Build83 (Ray): one-time SUPPLY granted to a side's pool on completing Patrol upgrade level 4 (ChangeSideSupply, clamped). 0 = off.
	if (isNil "WFBE_C_AICOM_PLANE_AIRSTART") then {WFBE_C_AICOM_PLANE_AIRSTART = 1};        //--- Build83 (Ray): founded PLANES air-start (FLY) at the captured airfield, aligned to the runway logic, de-conflicted (helis/ground unchanged). 0 = old grounded/scattered FORM behavior.
	if (isNil "WFBE_C_AICOM_PLANE_STACK_DEG") then {WFBE_C_AICOM_PLANE_STACK_DEG = 25};     //--- Build83: per-plane heading fan (deg) so a multi-plane team's air-started hulls don't spawn stacked.
	if (isNil "WFBE_C_AICOM_AIR_TEAM_MAX_HULLS") then {WFBE_C_AICOM_AIR_TEAM_MAX_HULLS = 0}; //--- Lane 179: 0 = off. >0 caps retained Air hulls created by one CreateTeam pass; intended for AICOM air founding templates.
	if (isNil "WFBE_C_AICOM_AIR_TEAM_STAGGER") then {WFBE_C_AICOM_AIR_TEAM_STAGGER = 0};    //--- Lane 179: seconds to wait between retained Air hull spawns for this side. 0 = no delay.
	if (isNil "WFBE_C_AIRLIFT_OWN_HQ") then {WFBE_C_AIRLIFT_OWN_HQ = 1};                    //--- Build83 (Ray 2026-07-01): re-enable airlifting your OWN HQ (Zeta_Hook; was disabled by Trello #87). 0 = restore the old exclusion.
	if (isNil "WFBE_C_AICOM_AIR_MAX_TOTAL") then {WFBE_C_AICOM_AIR_MAX_TOTAL = 3};          //--- Build83 (Ray): flat per-side cap on TOTAL alive AICOM air (planes + attack + transport helis together). Supersedes WFBE_C_AICOM_ATTACKHELI_MAX. 0 = no cap.
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
	if (isNil "WFBE_C_AICOM_TYPE_MIX") then {WFBE_C_AICOM_TYPE_MIX = [0.65, 0.20, 0.12, 0.03]};
	//--- B66 combined-arms RAMP: the static TYPE_MIX above stays the fallback. The type picker selects an
	//--- [inf,light,heavy,air] weight tier by the AI commander's OWN-TOWN count: EARLY (mostly foot, the
	//--- opening land-grab), MID (armour/mech rising once factories exist), LATE (heavy+air heavy, an
	//--- established war machine). MATURE_MID / MATURE_LATE are the own-town thresholds at/above which the
	//--- MID / LATE tiers apply. Weights need not sum to 1 (normalised at pick time).
	if (isNil "WFBE_C_AICOM_TYPE_MIX_EARLY") then {WFBE_C_AICOM_TYPE_MIX_EARLY = [0.32,0.31,0.31,0.06]}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: mix-first inf reduction (45->32 early) instead of bias push (B756 overshoot guard).
	if (isNil "WFBE_C_AICOM_TYPE_MIX_MID") then {WFBE_C_AICOM_TYPE_MIX_MID = [0.30,0.25,0.28,0.17]}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: balanced mid roster; shift infantry reduction into the mix rather than multiplying biases.
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
		if (isNil "WFBE_C_AICOM_STUCK_REPAIR")         then {WFBE_C_AICOM_STUCK_REPAIR         = 1};  //--- TP-15: 1 = at a tier-2/3 UNSTUCK event, restore+rearm the stuck lead hull IN PLACE (no town detour), reusing the SELFREPAIR safe-dist gate. 0 = off (byte-identical).
		//--- B754: also GROW the attack-heli cap (WFBE_C_AICOM_ATTACKHELI_MAX) over the match so the late air push isn't throttled at the early cap. Only when a base cap > 0 exists (0 still = no cap). Effective cap = base + floor(timeRatio * BONUS).
		if (isNil "WFBE_C_AICOM_ATTACKHELI_MAX_TIME_BONUS") then {WFBE_C_AICOM_ATTACKHELI_MAX_TIME_BONUS = 4};
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
		//--- B756 (Ray 2026-06-26) DISMOUNT-CARRIER bias: within the team-template draw, multiply a template's weight if it carries INFANTRY dismounts (so IFV/APC + squad beat bare MBTs in the heavy bucket = "infantry seated in armed vehicles" rather than gun-tanks). 1.0 = no-op.
		if (isNil "WFBE_C_AICOM_DISMOUNT_BIAS") then {WFBE_C_AICOM_DISMOUNT_BIAS = 1.7}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: mix-first inf reduction instead of bias push (B756 overshoot guard).
	//--- Codex review MEDIUM fix: crew-only dismount (Common_RunCommanderTeam.sqf) threat-gate radius - see the dismount-decision block there.
	if (isNil "WFBE_C_AICOM_CREW_DISMOUNT_THREAT_RADIUS") then {WFBE_C_AICOM_CREW_DISMOUNT_THREAT_RADIUS = 100};
		//--- B756 MOUNT seat-capacity gate: only GROUND MOUNT-UP / re-mount a team if its ride pool can seat at least this FRACTION of the squad. A partial mount splits the team (the APC drives off, the foot element strands -> ASSAULT_STRANDED). Below this the team stays foot-cohesive (the hull paces the group road-march). 0 = old behaviour (always partial-mount).
		if (isNil "WFBE_C_AICOM_MOUNT_MIN_SEAT_FRAC") then {WFBE_C_AICOM_MOUNT_MIN_SEAT_FRAC = 0.8};
		//--- B756 NAVAL-RAID gate: naval-HVT (carrier) spearhead targets are only assigned to teams with a TRANSPORT HELI (they're offshore, only reachable by air-insertion). Ground teams never get tasked to the sea (no stranding). This makes the carriers a real - but air-only - assault objective. Gate lives in AI_Commander_AssignTowns.sqf.
		if (isNil "WFBE_C_AICOM_NAVAL_AIR_ONLY") then {WFBE_C_AICOM_NAVAL_AIR_ONLY = 1};
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
	if (isNil "WFBE_C_AICOM_DISTANCE_DIVISOR") then {WFBE_C_AICOM_DISTANCE_DIVISOR = 50};   //--- score divisor on distance-to-front: one supply point is worth this many metres of march. Was effectively 150 (too weak); 50 makes distance dominate so the nearest contestable town wins.
	if (isNil "WFBE_C_AICOM_HQ_PULL_DIVISOR") then {WFBE_C_AICOM_HQ_PULL_DIVISOR = 250};    //--- score divisor on distance-to-ENEMY-HQ: adds a small spearhead bias toward the enemy capital so the front advances in one direction instead of wandering. Larger = weaker pull. 0 disables the pull.
	if (isNil "WFBE_C_AICOM_FAR_PENALTY") then {WFBE_C_AICOM_FAR_PENALTY = 1000};           //--- flat score penalty applied to any candidate OUTSIDE the frontier radius, so a rich deep city can no longer buy its way over a near contestable town. Large enough to swamp supply spread.
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
	//--- B60 MHQ RELOCATION (Ray 2026-06-21, DEFAULT-ON): the commander mobilizes its static HQ into the MHQ,
	//--- an AI driver DRIVES it forward to a standoff behind the front town, then it re-deploys. Safety rails:
	//--- stuck-timer, deadline (player-safe teleport-step fallback), enemy-standoff, always re-deploys (never idle/frozen).
	//--- Set WFBE_C_AICOM_MHQ_RELOCATE = 0 to make it fully inert.
	if (isNil "WFBE_C_AICOM_MHQ_RELOCATE")          then {WFBE_C_AICOM_MHQ_RELOCATE          = 1};    //--- 1 = ON (Ray default), 0 = off (no-op).
	if (isNil "WFBE_C_AICOM_MHQ_RELOCATE_INTERVAL") then {WFBE_C_AICOM_MHQ_RELOCATE_INTERVAL = 180};  //--- s between relocation evaluations per side.
	if (isNil "WFBE_C_AICOM_MHQ_FRONT_DIST")        then {WFBE_C_AICOM_MHQ_FRONT_DIST        = 2500}; //--- m: relocate only once the front (spearhead town) is farther than this from the HQ.
	if (isNil "WFBE_C_AICOM_MHQ_STANDOFF")          then {WFBE_C_AICOM_MHQ_STANDOFF          = 1500}; //--- B74 (Ray 2026-06-22): 800->1500. m: new base sits this far BEHIND the front town (toward the old HQ), capped so it never overshoots.
	if (isNil "WFBE_C_AICOM_MHQ_MIN_ADVANCE")       then {WFBE_C_AICOM_MHQ_MIN_ADVANCE       = 1500}; //--- B74.1 (2026-06-23): 3000->1500. The b74 soak proved 3000 unreachable on Chernarus - the DEEPEST standoff candidate all night was 2790m, so the gate rejected ALL 376 relocations + zeroed _destPos before the new teleport-on-stuck path could help, leaving #9 forward-factory dormant. 1500 admits the real candidates (still far enough to not stack on the old base, which the original 800m moves did).
	if (isNil "WFBE_C_AICOM_REBASE_ON")             then {WFBE_C_AICOM_REBASE_ON             = 1};    //--- B74 (Ray 2026-06-22): after an MHQ relocation, (re)build the production factories at the NEW HQ (supply-gated, HQ-local check) so a moved base is not a dead base. 1=on.
	if (isNil "WFBE_C_AICOM_BASE_RADIUS")           then {WFBE_C_AICOM_BASE_RADIUS           = 450};  //--- B74: m radius around the CURRENT HQ within which 'do we already have this factory' is judged, so a forward HQ rebuilds locally instead of counting the OLD base's factories side-wide.
	if (isNil "WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS")    then {WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS    = 12};   //--- B74.1 (Ray 2026-06-23): a side launches the HQ-STRIKE round-ender once it holds this many towns. Replaces the DEAD ceil(count-towns*0.5)=~20 gate (unreachable on Chernarus' 40+ towns; sides peaked at 13), so a dominant side now actually goes for the kill instead of grinding forever. Absolute town count.
	if (isNil "WFBE_C_AICOM_HQSTRIKE_CAP_FRAC")     then {WFBE_C_AICOM_HQSTRIKE_CAP_FRAC     = 0.5};  //--- B74.1 (Ray 2026-06-23): once striking, commit this FRACTION of the side's live field teams to the enemy-HQ assault (was a flat 3). 0.5 = half the army razes the enemy base (HQ+factories => the supremacy/HQ-loss win fires).
	if (isNil "WFBE_C_AICOM_RELIEF_ENEMY_DIST")     then {WFBE_C_AICOM_RELIEF_ENEMY_DIST     = 500};  //--- B74.1 (Ray 2026-06-23): a team is only diverted to DEFEND an own town when a live hostile is within this many m of it (REACTIVE defense). Stops the old "too defensive" behaviour of pinning teams to quiet but 'active' (near-front) towns. m.
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
	if (isNil "WFBE_C_AICOM_FUNDS_SINK_ENABLE")     then {WFBE_C_AICOM_FUNDS_SINK_ENABLE     = 0};       //--- 1 = arm the funds-sink worker; 0 = inert (worker early-exits). Default 0 (dark).
	if (isNil "WFBE_C_AICOM_FUNDS_SINK_THRESHOLD")  then {WFBE_C_AICOM_FUNDS_SINK_THRESHOLD  = 1000000}; //--- funds: only drain a commander's hoard ABOVE this (well under the 1.5M WEALTH_CAP, so the drip bites before the cap pins it).
	if (isNil "WFBE_C_AICOM_FUNDS_SINK_DRAIN_PCT")  then {WFBE_C_AICOM_FUNDS_SINK_DRAIN_PCT  = 0.25};    //--- per-tick discounted drain = this fraction of the OVER-THRESHOLD surplus (0.25 = bleed a quarter of the excess each ~60s income tick).
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
	if (isNil "WFBE_C_AICOM2_HARASS_TEAMS")    then {WFBE_C_AICOM2_HARASS_TEAMS    = 1};  //--- M2: how many (mounted) teams peel off the fist to raid the enemy's deepest REAR town (supply hub). 0 = pure concentration.
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
	if (isNil "WFBE_C_AICOM2_DECAP_ARM_TICKS")   then {WFBE_C_AICOM2_DECAP_ARM_TICKS   = 3};    //--- consecutive dominant strategy ticks required to ARM -> COMMIT (durability latch; blocks single-tick effective-strength gaming).
	if (isNil "WFBE_C_AICOM2_DECAP_MIN_COMMIT")  then {WFBE_C_AICOM2_DECAP_MIN_COMMIT  = 300};  //--- seconds a COMMITTED decap must persist before an ABORT is even considered (stops flap; the siege counter needs time to accrue).
	//--- ORGANIC BASE SENSING (owner Q1 2026-07-06): the closer must not ACT on global HQ knowledge. A ground
	//--- team must organically come near the enemy base, then a periodic dice roll must succeed, before the
	//--- latch may even start arming. Per-map radius follows the standard worldName idiom below.
	if (isNil "WFBE_C_AICOM2_DECAP_SENSE_RADIUS")   then {WFBE_C_AICOM2_DECAP_SENSE_RADIUS   = if (worldName == "Zargabad") then {2000} else {3000}}; //--- m: an eligible offensive team leader must be within this range of the enemy HQ for sensing to be possible (3000 CH/TK, 2000 dense-urban ZG).
	if (isNil "WFBE_C_AICOM2_DECAP_SENSE_INTERVAL") then {WFBE_C_AICOM2_DECAP_SENSE_INTERVAL = 4};    //--- strategy ticks between dice rolls (~4 min at the 60s cadence). No roll, no ARM progress.
	if (isNil "WFBE_C_AICOM2_DECAP_SENSE_CHANCE")   then {WFBE_C_AICOM2_DECAP_SENSE_CHANCE   = 0.35}; //--- chance a due dice roll latches "sensed" while a team is in range (random 1 < this; A2-safe).
	if (isNil "WFBE_C_AICOM2_DECAP_COMMIT_RADIUS")  then {WFBE_C_AICOM2_DECAP_COMMIT_RADIUS  = WFBE_C_AICOM2_DECAP_SENSE_RADIUS}; //--- m: on COMMIT only teams with a leader inside this radius are stamped to press; distant teams keep their town orders (default = sense radius).

	//--- GRUDGE LEDGER (feat/aicom-grudge-ledger, generated by apply_grudge.py): "The Long Memory" A-Life feature - see docs/design/GRUDGE-DESIGN.md
	if (isNil "WFBE_C_AICOM_GRUDGE")                then {WFBE_C_AICOM_GRUDGE                = 1};     //--- master switch. 0 = inert (no stamping, no scorer bonus, no sub-options). 1 = armed.
	if (isNil "WFBE_C_AICOM_GRUDGE_BONUS")          then {WFBE_C_AICOM_GRUDGE_BONUS          = 400};   //--- flat score bonus for a live grudge site in BOTH scorers (calibration: NEAR_BAND_BONUS=300, FAR_PENALTY=1000).
	if (isNil "WFBE_C_AICOM_GRUDGE_DECAY")          then {WFBE_C_AICOM_GRUDGE_DECAY          = 2400};  //--- seconds a grudge site stays live before pruning (same prune-on-read idiom as SIDE_BLACKLIST_COOLDOWN).
	if (isNil "WFBE_C_AICOM_GRUDGE_MAX_SITES")      then {WFBE_C_AICOM_GRUDGE_MAX_SITES      = 3};     //--- cap on concurrent live grudge sites per side; oldest dropped first.
	if (isNil "WFBE_C_AICOM_GRUDGE_RELIEF_TRIGGER") then {WFBE_C_AICOM_GRUDGE_RELIEF_TRIGGER = 0};     //--- 0 = only offensive failures (SIDE_BLACKLIST, DECAP ABORT) stamp a grudge; 1 = also RELIEF_TOWN_LOST (defensive loss, opt-in).
	if (isNil "WFBE_C_AICOM_GRUDGE_ARM_SHORTCUT")   then {WFBE_C_AICOM_GRUDGE_ARM_SHORTCUT   = 0};     //--- SUB-OPTION, own flag. 1 = shortcut Decapitate's ARM streak at a grudge-site HQ (min() of the two tick counts, never raises it).
	if (isNil "WFBE_C_AICOM_GRUDGE_ARM_TICKS")      then {WFBE_C_AICOM_GRUDGE_ARM_TICKS      = 1};     //--- reduced ARM streak length used only when GRUDGE_ARM_SHORTCUT fires.
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

	//--- D7 AICOM FEINT: AI commander occasionally dispatches a small feint team toward a
	//--- NON-target enemy town, then recalls it, to pressure the enemy rear and split attention.
	//--- All four constants are inert while FEINT_ENABLE=0 (default). No gameplay effect at 0.
	if (isNil "WFBE_C_AICOM_FEINT_ENABLE")   then {WFBE_C_AICOM_FEINT_ENABLE   = 0};   //--- 0 = off (dark). Set to 1 to arm feint dispatch.
	if (isNil "WFBE_C_AICOM_FEINT_INTERVAL") then {WFBE_C_AICOM_FEINT_INTERVAL = 600}; //--- s between feint dispatches per side (per-side cooldown).
	if (isNil "WFBE_C_AICOM_FEINT_DUR")      then {WFBE_C_AICOM_FEINT_DUR      = 120}; //--- s a feint team holds at the feint town before recall to the fist.
	if (isNil "WFBE_C_AICOM_FEINT_COOLDOWN") then {WFBE_C_AICOM_FEINT_COOLDOWN = 120}; //--- reserved: per-side anti-double-dispatch stamp (used by wfbe_aicom_feint_t0 in the Allocator).
	if (isNil "WFBE_C_AICOM2_EXPAND_TEAMS")    then {WFBE_C_AICOM2_EXPAND_TEAMS    = 3};  //--- Ray 2026-06-28: up to N teams divert to capture the nearest reachable NEUTRAL town instead of all-in on the fist (issue: 42/46 towns sat neutral). 0 = off (restores fist-only).
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
	if (isNil "WFBE_C_AICOM_CONCENTRATE_TOWNS") then {WFBE_C_AICOM_CONCENTRATE_TOWNS = 4};//--- Ray 2026-06-28 CONCENTRATE-FIRST: while a commander owns FEWER than this many towns it puts its FULL strength on ONE fist town (no expand/harass split) - a true opening steamroller. Once it owns this many, the normal expand(EXPAND_TEAMS)+harass spread resumes. 0 = off (spread from town one).
	if (isNil "WFBE_C_AICOM_DISBAND_LOWTIER_ENABLE") then {WFBE_C_AICOM_DISBAND_LOWTIER_ENABLE = 1};//--- Ray 2026-06-28: retire idle rear FOOT-infantry teams once the side fields mobile (light/heavy/air) teams - keeps force modern + frees pop/group cap for armour. 0 = off.
	if (isNil "WFBE_C_AICOM_DISBAND_LOWTIER_INTERVAL") then {WFBE_C_AICOM_DISBAND_LOWTIER_INTERVAL = 600};//--- seconds between low-tier disband passes (at most ONE team retired per pass). Dedicated operator knob; DISBAND_INTERVAL remains for shared/full disband pacing.
	if (isNil "WFBE_C_AICOM_DISBAND_INTERVAL") then {WFBE_C_AICOM_DISBAND_INTERVAL = 300};//--- seconds between disband passes (at most ONE team retired per pass) - long for immersion.
	if (isNil "WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR") then {WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR = 2};//--- never disband below this many FOOT teams/side (keep a footprint). 3->2: with the 8-team cap a side rarely holds >3 foot teams so disband never fired.
	if (isNil "WFBE_C_AICOM_PHASE_ENABLE") then {WFBE_C_AICOM_PHASE_ENABLE = 1}; //--- AI-BEHAVIOR-LOOP-DESIGN.md sec1: per-team phase-state var wfbe_aicom_phase (MARCH/CAMP_SWEEP/CENTER_PUSH/CONSOLIDATE/NEXT_TARGET), stamped HC-side in Common_RunCommanderTeam.sqf at 5 existing choke points. 0 = off: var never written/read anywhere, zero behavior change.
	if (isNil "WFBE_C_AICOM_DWELL_ENABLE") then {WFBE_C_AICOM_DWELL_ENABLE = 1}; //--- AI-BEHAVIOR-LOOP-DESIGN.md sec2: cumulative per-team-per-town dwell clock (wfbe_aicom_dwell_town0), surviving a RELEASE->repick-same-town cycle, consumed as a 4th sibling abandon trigger in AI_Commander_AssignTowns.sqf. 0 = off: var never stamped, existing 3-trigger abandon ladder untouched.
	if (isNil "WFBE_C_AICOM_DWELL_MAX_SECS") then {WFBE_C_AICOM_DWELL_MAX_SECS = 900}; //--- AI-BEHAVIOR-LOOP-DESIGN.md sec2.3: OWNER-TUNABLE. Cumulative dwell ceiling (s) before DWELL_ABANDON fires - engineering default = 2x WFBE_C_AICOM_ASSAULT_HOLD (720s worst-case camp-first+depot-hold) + headroom, NOT soak-calibrated. Only consulted when WFBE_C_AICOM_DWELL_ENABLE=1.
	if (isNil "WFBE_C_AICOM_WEAKTEAM_ENABLE") then {WFBE_C_AICOM_WEAKTEAM_ENABLE = 1}; //--- AI-BEHAVIOR-LOOP-DESIGN.md sec3: widens AI_Commander_DisbandLowTier.sqf's idle-candidate test to also catch an attrited (<=WFBE_C_AICOM_BREAKOFF_MIN live units) mobile-team remnant of ANY type for disband-refund. 0 = off: candidate test stays exactly _typeIdx==0 (byte-identical foot-only culling).
	if (isNil "WFBE_C_AICOM_DISBAND_VIEW_DIST") then {WFBE_C_AICOM_DISBAND_VIEW_DIST = 1500};//--- Ray 2026-06-28: NEVER retire a foot team with a human player within this many m (immersion - no team vanishing in a player's view). Proximity proxy for line-of-sight.
	if (isNil "WFBE_C_AICOM_DISBAND_COOLDOWN") then {WFBE_C_AICOM_DISBAND_COOLDOWN = 900};//--- claude-gaming 2026-06-30 (Ray): PLAYER-COMMANDER disband-ALL failsafe (Command Console button) - min seconds between full AI-field-team disbands, per side. Reuses the wfbe_aicom_disband path; the HC deletes each team only when no player is within DISBAND_SAFE_DIST and it is not in combat (no vanish-in-view).
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
	//--- COMMAND CONSOLE (full rework): extra TTL/amount knobs the new "Command" console orders ride. Backend (Server_HandleSpecial)
	//--- reads these for the aicom-reinforce / aicom-posture / aicom-request-unit stamps + the aicom-donate amount. isNil-guarded.
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
	if (isNil "WFBE_C_AICOM_DONATE_AMOUNT")    then {WFBE_C_AICOM_DONATE_AMOUNT    = 10000};//--- funds moved from the player's team wallet to the AI commander's treasury per Donate press (affordability checked client-side, re-validated server-side).
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
	if (isNil "WFBE_C_AICOM_RETREAT_MAX_ISSUES") then {WFBE_C_AICOM_RETREAT_MAX_ISSUES = 8}; //--- cull a lone survivor after this many retreat re-issues regardless of slow progress.
	if (isNil "WFBE_C_AICOM_RETREAT_MAX_DIST") then {WFBE_C_AICOM_RETREAT_MAX_DIST = 6000};  //--- cull a lone survivor immediately if farther than this (m) from HQ - not worth a multi-km walk home.
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
	if (isNil "WFBE_C_AICOM_TEAM_SIZE_MIN") then {WFBE_C_AICOM_TEAM_SIZE_MIN = 8};   //--- founding floor for infantry/mixed teams.
	if (isNil "WFBE_C_AICOM_TEAM_SIZE_MAX") then {WFBE_C_AICOM_TEAM_SIZE_MAX = 8};  //--- Build84 (Ray): founding ceiling 12 -> 8 (lighter server load); single-vehicle MBT/attack-heli teams exempt.
	//--- === Build 84 / cmdcon36 wave-2/3 constants (claude-gaming 2026-07-01) ===
	if (isNil "WFBE_C_AICOM_HIGHCLIMB") then {WFBE_C_AICOM_HIGHCLIMB = 1};                 //--- Build84 (Ray, ON): AICOM tanks get demand-based Valhalla climb-assist on server/HC (boosts only a bogged tank moving forward). 0 = off.
	//--- T1.5 ADD (R3-SYNTHESIS 2026-07-20): from-zero unstick pulse - a small bounded nudge along
	//--- the hull heading when a hull has fully stopped (<=3 km/h), escalating a per-vehicle strike
	//--- counter so a genuinely wedged/flipped hull is not nudged forever. See Common_AICOM_HighClimb.sqf.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_PULSE") then {WFBE_C_AICOM_HIGHCLIMB_PULSE = 1}; //--- 0 = off (byte-identical to pre-T1.5 behaviour: only the existing rolling-hull boost applies).
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_PULSE_MAX_STRIKES") then {WFBE_C_AICOM_HIGHCLIMB_PULSE_MAX_STRIKES = 6}; //--- consecutive still-stuck pulses before this hull is handed back to the normal stuck/strand/abandon ladder.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_PULSE_COOLDOWN") then {WFBE_C_AICOM_HIGHCLIMB_PULSE_COOLDOWN = 15}; //--- s between from-zero pulses on the same hull; review minimum is 15s.
	if (isNil "WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE") then {WFBE_C_AICOM_HIGHCLIMB_ZEROPULSE = 0}; //--- Review fix #1194: master gate for the from-zero pulse; owner arms it explicitly.
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
	if (isNil "WFBE_C_AICOM_AIR_LATE_MINS") then {WFBE_C_AICOM_AIR_LATE_MINS = 45};        //--- Build84 (Ray): mission minute at/after which 'late game' air scaling applies.
	if (isNil "WFBE_C_AICOM_AIR_MAX_LATE") then {WFBE_C_AICOM_AIR_MAX_LATE = 8}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: late game leans air per owner pick; capture rail: air bucket must stay lift-majority.
	if (isNil "WFBE_C_AICOM_HELI_SHARE_LATE") then {WFBE_C_AICOM_HELI_SHARE_LATE = 0.62}; //--- B757 (Ray 2026-07-20) ROSTER COUNCIL: late game leans air per owner pick; capture rail: air bucket must stay lift-majority.
	//--- === cmdcon37 AI-behaviour fixes (claude-gaming overnight 2026-07-02) ===
	if (isNil "WFBE_C_AICOM_CAMP_GATE_MODE2") then {WFBE_C_AICOM_CAMP_GATE_MODE2 = 1};        //--- cmdcon37 (afraid-of-camps): in AllCamps mode (WFBE_C_TOWNS_CAPTURE_MODE=2) hold + aggressively clear a town's camps instead of bailing to a depot that can't flip. 0 = old bail behaviour.
	if (isNil "WFBE_C_AICOM_STALL_ADVANCE_SECS") then {WFBE_C_AICOM_STALL_ADVANCE_SECS = if (worldName == "Takistan") then {900} else {420}}; //--- cmdcon37 (never-stand floor): if a team is parked at a town > this many s with no flip/progress, blacklist it + retarget to the nearest OTHER enemy town same tick (bypasses the strike ladder that rarely accrues live). 0 = off. cmdcon38: 240 -> 420 so it no longer preempts a full travel(~60s)+drain-wait-hold(360s) capture attempt on Chernarus/Zargabad scale. T1.3a (R3-SYNTHESIS 2026-07-20): 420 was BELOW the executor's own ~890s TK attempt budget, so the floor preempted a still-working long-distance capture before it could finish - worldName branch raises TK to 900 (same per-map pattern as ROAD_STANDOFF/REACH_FOOT), CH/ZG stay at the proven 420.
	//--- === cmdcon41 wave-1 (claude-gaming 2026-07-02): SPREAD+HOLD, real-combat base assault (Ray: ON), siege decay, remnant caution ===
	if (isNil "WFBE_C_AICOM_SPREAD_MODE")            then {WFBE_C_AICOM_SPREAD_MODE = 1};            //--- anti-dogpile: cap teams per fist town in the Allocator (0 = legacy uncapped pile-up).
	if (isNil "WFBE_C_AICOM2_FIST_PERTOWN")          then {WFBE_C_AICOM2_FIST_PERTOWN = 4};          //--- max teams the Allocator stacks on one fist town before spilling to the next.
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
	if (isNil "WFBE_C_AICOM_WITHDRAW_EVAL")           then {WFBE_C_AICOM_WITHDRAW_EVAL = 1};           //--- graceful-withdrawal evaluator: bleeding HC teams get a "rally" order to the nearest own HQ/town (Ray: reinforce at friendly towns).
	if (isNil "WFBE_C_AICOM_WITHDRAW_MIN_ALIVE")      then {WFBE_C_AICOM_WITHDRAW_MIN_ALIVE = 3};      //--- alive-count floor that triggers the withdrawal (MBT/attack-heli teams exempt).
	if (isNil "WFBE_C_AICOM_WITHDRAW_COOLDOWN")       then {WFBE_C_AICOM_WITHDRAW_COOLDOWN = 240};     //--- claude/aicom-west-stuck (bug M): min seconds between auto-rally re-arms for the SAME understrength team - ends the rally-arrive-rally livelock, gives a bounded assault window between withdrawal episodes. Explicit driver wantrally requests bypass this.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE")            then {WFBE_C_AICOM_STRIKE_STAGE = 1};            //--- HQ-strike staging: mass strikers at a rally short of the enemy HQ, then hit together.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_BODIES")     then {WFBE_C_AICOM_STRIKE_STAGE_BODIES = 14};    //--- staged bodies required before release.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_TIMEOUT")    then {WFBE_C_AICOM_STRIKE_STAGE_TIMEOUT = 240};  //--- s: release with whatever is staged (never deadlock).
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_DIST")       then {WFBE_C_AICOM_STRIKE_STAGE_DIST = 800};     //--- m short of the enemy HQ where the staging rally sits.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_ARRIVE")     then {WFBE_C_AICOM_STRIKE_STAGE_ARRIVE = 400};   //--- m: a striker within this of the rally counts as staged.
	if (isNil "WFBE_C_AICOM_JOURNEY_COMMIT")          then {WFBE_C_AICOM_JOURNEY_COMMIT = 1};          //--- never retarget a team that is closing on its town (progress >= 150m since dispatch).
	if (isNil "WFBE_C_AICOM_STRIKE_COMMIT") then {WFBE_C_AICOM_STRIKE_COMMIT = 0}; //--- 0=current (any towns-mode team is strike-grabbable); 1=a PROGRESSING team (open dispatch + progress>=150m + target still enemy) is skipped for the HQ strike-grab so an active journey is not killed. Exempts recycle-flagged + genuinely-stuck teams.
	if (isNil "WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE") then {WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE = 6}; //--- a team with this many failed journeys since its last arrival is recycled (combat- and player-guarded).
	//--- cmdcon43-pack2: AICOM effectiveness additions (items 2-4).
	if (isNil "WFBE_C_AICOM_RESEARCH_AIR")    then {WFBE_C_AICOM_RESEARCH_AIR    = 0}; //--- 0=off; 1=AI appends [AIR,1][AIR,2] to doctrine research when an Aircraft Factory is present.
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
	//--- cmdcon41-w3d COMMAND-MENU V2: new steering verbs (RALLY/REFIT/HOLD) + non-commander REQUEST-AI-SUPPORT nudge.
	if (isNil "WFBE_C_CMD_MENU_V2")                    then {WFBE_C_CMD_MENU_V2 = 1};                   //--- master flag for the cmdcon41-w3d command-menu additions (steering verbs, nudge, UnitCamera guard). 0 = off.
	if (isNil "WFBE_C_CMD_NUDGE_COOLDOWN")            then {WFBE_C_CMD_NUDGE_COOLDOWN = 180};          //--- s per-player cooldown on the non-commander "REQUEST AI SUPPORT" nudge.
	if (isNil "WFBE_C_TEAM_FOCUS_COOLDOWN")           then {WFBE_C_TEAM_FOCUS_COOLDOWN = 120};         //--- s SERVER-SIDE per-player cooldown on the commander "aicom-focus" order (TP-13; client guard alone was spammable). 0 = disable (legacy behaviour).
	if (isNil "WFBE_C_CMD_VERB_COOLDOWN")             then {WFBE_C_CMD_VERB_COOLDOWN = 60};            //--- s SERVER-SIDE per-player cooldown on the aicom-posture/fieldorder/defend/reinforce command verbs (TP-20; each verb had only a client-side cooldown). 0 = disable.
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
	if (isNil "WFBE_C_PATROLS_ROADBIAS")              then {WFBE_C_PATROLS_ROADBIAS = 1};              //--- upgrade-tier patrols route along ROADS between owned towns/HQ (players drive roads -> encounters); legacy random fallback.
	if (isNil "WFBE_C_PATROLS_ROADBIAS_MOTORIZED")    then {WFBE_C_PATROLS_ROADBIAS_MOTORIZED = 1};    //--- road patrols prefer vehicle-containing pool entries (full-pool fallback for foot-only pools e.g. TKGUE).
	if (isNil "WFBE_C_AICOM_SMOKE")                   then {WFBE_C_AICOM_SMOKE = 1};                   //--- smoke discipline: shells on the assault approach axis + covering smoke on break-off.
	if (isNil "WFBE_C_AICOM_SMOKE_COOLDOWN")          then {WFBE_C_AICOM_SMOKE_COOLDOWN = 120};        //--- s between smoke uses per team.
	if (isNil "WFBE_C_AICOM_ARMOR_SCREEN")    then {WFBE_C_AICOM_ARMOR_SCREEN = 0};    //--- armor-screen: tanks screen outward on arrival instead of SAD with infantry (0=off, default).
	if (isNil "WFBE_C_AICOM_ARMOR_SCREEN_R")  then {WFBE_C_AICOM_ARMOR_SCREEN_R = 80}; //--- m stand-off radius for the outward screen position.
	if (isNil "WFBE_C_NAVAL_TWIN_HULLS")              then {WFBE_C_NAVAL_TWIN_HULLS = 1};              //--- Khe Sanh: outer carriers become deck-bridged TWIN-HULL super-carriers (middle keeps the SCUD, single hull).
	if (isNil "WFBE_C_NAVAL_WEST_AAV")                then {WFBE_C_NAVAL_WEST_AAV = 0};                //--- Lane 45: default-off WEST AAV buy-row metadata hook for future naval-map beach-assault work.
	if (isNil "WFBE_C_COASTAL_UTILITY_BOATS")         then {WFBE_C_COASTAL_UTILITY_BOATS = 0};         //--- Lane 184: default-off cheap PBX/RHIB-class Light-factory utility boats on coastal/naval maps only.
	if (isNil "WFBE_C_COASTAL_UTILITY_BOAT_WATER_PROBES") then {WFBE_C_COASTAL_UTILITY_BOAT_WATER_PROBES = switch (toLower worldName) do {case "chernarus": {[[7000,150,0],[13500,1800,0],[600,6500,0]]}; default {[]};}}; //--- Lane 184: edge-water probes used to qualify coastal utility boats.
	if (isNil "WFBE_C_VICTORY_TERRITORIAL")           then {WFBE_C_VICTORY_TERRITORIAL = 1};           //--- Ray: hold >= FRAC of all towns for MINS unbroken -> win (announced start/milestones/broken; existing win path).
	if (isNil "WFBE_C_VICTORY_TERRITORIAL_FRAC")      then {WFBE_C_VICTORY_TERRITORIAL_FRAC = 0.8};    //--- town share required to run the clock.
	if (isNil "WFBE_C_VICTORY_TERRITORIAL_MINS")      then {WFBE_C_VICTORY_TERRITORIAL_MINS = 30};     //--- unbroken minutes at/above FRAC to win.
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
	if (isNil "WFBE_C_AICOM_RECOVERY_V2")             then {WFBE_C_AICOM_RECOVERY_V2 = 1};             //--- unstuck v2: vehicle unflip, reverse+lane-flip repath, dead-driver swap, slope-aware foot nodes, water guard.
	if (isNil "WFBE_C_AICOM_RECOVERY_REVERSE_SPEED")  then {WFBE_C_AICOM_RECOVERY_REVERSE_SPEED = 6};  //--- m/s of the brief reverse pulse before re-pathing a stuck vehicle.
	if (isNil "WFBE_C_AICOM_RECOVERY_SLOPE_Z")        then {WFBE_C_AICOM_RECOVERY_SLOPE_Z = if (worldName == "Takistan") then {0.80} else {0.85}};     //--- surfaceNormal z below this = too steep for a foot waypoint node -> snap to nearest road. TK ridge grades hit 0.85 (~32deg) far more than rolling Chernarus, so a lower TK threshold (0.80, ~37deg) snaps only genuinely-too-steep foot nodes instead of constantly. isNil guard keeps any pre-set (flag/param) global as the override.
	if (isNil "WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R")    then {WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R = if (worldName == "Takistan") then {300} else {200}};  //--- m search radius for that road snap. Wider on TK's sparse mountain road net so the snap actually finds a track.
	if (isNil "WFBE_C_AICOM_RECOVERY_NOROAD_STEP")     then {WFBE_C_AICOM_RECOVERY_NOROAD_STEP = 1};      //--- cmdcon44i: when the tier-3 road-snap finds NO road (roadless mountain shelf - the ZG SE spawn shelf that pinned EAST foot teams at match start), step the leader/hull toward the objective instead of leaving it wedged forever. 0 = old behaviour (do nothing when no road).
	if (isNil "WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST") then {WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST = 90};//--- m the no-road recovery step moves toward the order destination (clamped so it never overshoots past the dest; snapped to nearest isFlatEmpty non-water ground).

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
	if (isNil "WFBE_C_AICOM_BUILD_ROAD_CLEAR") then {WFBE_C_AICOM_BUILD_ROAD_CLEAR = 6};   //--- TP-19 (owner report 2026-07-06: AI built on dirt roads): metres radius around a build candidate that must be clear of any road segment (paved OR dirt, via nearRoads - A2-OA-safe). 0 = OFF (default, gate inert). Suggested live value 6-8 m; complement to WFBE_C_AICOM_BUILD_ROADCLEAR (the primary ON-by-default road gate).
	if (isNil "WFBE_C_SKINSEL")                       then {WFBE_C_SKINSEL = 1};                       //--- cmdcon41-w3l: skin selector master (WF-menu SKIN button + first-spawn dialog + respawn restore). Legacy WFBE_C_SKIN_SELECTOR still honored as an OR.
	if (isNil "WFBE_C_SKINSWAP_FUNDS_CARRY")          then {WFBE_C_SKINSWAP_FUNDS_CARRY = 1};          //--- cmdcon43-h: carry the player's wfbe_funds + wfbe_side across a skin swap so a failed rejoin (fresh/diverted/CIV group) never orphans his wallet to $0 (LIVE-confirmed cmdcon42b). 1 on, 0 off.
	if (isNil "WFBE_C_FUNDS_HEAL_ZERO_GRACE")         then {WFBE_C_FUNDS_HEAL_ZERO_GRACE = 90};         //--- Ray pick A (2026-07-03): seconds the client funds self-heal refuses to accept a 0 wfbe_funds as "healed" (a transient JIP-sync 0 was the old zero-latch); keeps re-requesting the server lock-step record restore. Belt-and-suspenders atop the record fix. Higher = longer no-zero window.
	if (isNil "WFBE_C_SKIN_PERSIST") then {WFBE_C_SKIN_PERSIST = 0};           //--- skin-persist 2026-07-06: persist player skin choice via profileNamespace across session reconnects; re-applies on respawn. 0 = off (default, byte-identical).

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
	if (isNil "WFBE_C_AICOM_TEAM_FOUND_SIZE") then {WFBE_C_AICOM_TEAM_FOUND_SIZE = 10}; //--- DRAFT founding target (>=MIN, <=MAX).
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
	WFBE_C_AI_COMMANDER_REINFORCE_RANGE = 1200;   //--- V0.5: Produce only refills teams this close to base (wiped teams reform at base).
	WFBE_C_AICOM_FWD_REINFORCE_RANGE = 900;       //--- FILL-FIX 2026-06-18: 500->900 (rollback 500) - forward spearheads 500-900m out of the rear base couldn't refill and bled toward ~4 units; widen so front-line teams top up from the nearest forward factory. Still requires an OWNED town within range (never resupplies on enemy ground). --- FORWARD-REINFORCE (claude-gaming 2026-06-13): deep teams beyond REINFORCE_RANGE may still refill if their leader hugs an owned town within this radius (fixes the deep-spearhead bleed-out / EAST snowball). Refill spawns at the factory nearest the team, so a captured forward town resupplies its own front instead of a lone unit trekking from the rear base.
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
	//--- Patch E: AICOM supervisor watchdog restart loop. A standalone watchdog re-spawns a side's commander
	//--- supervisor PFM if its heartbeat goes stale, with a per-side cooldown (restart-storm guard).
	if (isNil "WFBE_C_AICOM_WATCHDOG") then {WFBE_C_AICOM_WATCHDOG = 1};                 //--- 1 = watchdog on (default); 0 = inert (instant rollback).
	if (isNil "WFBE_C_AICOM_WATCHDOG_SCAN") then {WFBE_C_AICOM_WATCHDOG_SCAN = 30};      //--- s between watchdog scans.
	if (isNil "WFBE_C_AICOM_WATCHDOG_COOLDOWN") then {WFBE_C_AICOM_WATCHDOG_COOLDOWN = 120}; //--- per-side min s between two restarts (restart-storm guard).
	//--- Patch E: supervisor spawn-phase jitter. Random 0..JITTER s stagger on supervisor (re)spawn so both
	//--- sides' heavy worker passes don't land on the same frame (smooths the server-FPS sawtooth).
	if (isNil "WFBE_C_AICOM_SUPERVISOR_JITTER") then {WFBE_C_AICOM_SUPERVISOR_JITTER = 7}; //--- s max random spawn-phase stagger.
	if (isNil "WFBE_C_LOOP_PHASE_JITTER") then {WFBE_C_LOOP_PHASE_JITTER = 1}; //--- Perf (2026-07-06): when 1, the heavy server loops (town capture + activation sweeps, groupsGC, dead collector, side patrols) each sleep a one-time random offset (up to one own period) at startup so their ticks stop landing on the same frames. Default off = V1 behaviour.
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
	if (isNil "WFBE_C_AICOM_HC_MERGE_ENABLE") then {WFBE_C_AICOM_HC_MERGE_ENABLE = 0};   //--- 1 = ON, 0 = off (default; ships dark). fix(tonight-20260717): reverted 1->0 - both this and HC_TOPUP_ENABLE below only ever call WFBE_SE_FNC_AI_Com_HCTopUp (AI_Commander.sqf:572, nil-guarded), which is never compiled/registered anywhere in the tree, so arming either flag is a pure no-op. Do not re-arm until the DRAFT worker is actually implemented and registered.
	if (isNil "WFBE_C_AICOM_HC_TOPUP_ENABLE") then {WFBE_C_AICOM_HC_TOPUP_ENABLE = 0};   //--- B74 (Ray 2026-06-22): refill attrited HC field teams - Produce skips live HC teams so they bleed to 1-2-man remnants and never recover. When on, the commander ships replacement bodies to under-strength HC teams (charged to AI funds). 1=on. fix(tonight-20260717): reverted 1->0 - inert no-op, see WFBE_C_AICOM_HC_MERGE_ENABLE comment above.
	if (isNil "WFBE_C_AICOM_HC_TOPUP_FRAC")   then {WFBE_C_AICOM_HC_TOPUP_FRAC   = 0.6}; //--- B74: a live HC team at/below this fraction of its template size gets topped up.
	if (isNil "WFBE_C_AICOM_HC_TOPUP_MAX")    then {WFBE_C_AICOM_HC_TOPUP_MAX    = 2};   //--- B74: max teams topped up per commander tick (rate-limit the spend + the spawn load).
	if (isNil "WFBE_C_AICOM_HC_MERGE_FRAC")   then {WFBE_C_AICOM_HC_MERGE_FRAC   = 0.6}; //--- a team at/below this fraction of its template size is "depleted" (merge candidate).
	if (isNil "WFBE_C_AICOM_HC_MERGE_RANGE")  then {WFBE_C_AICOM_HC_MERGE_RANGE  = 300}; //--- m: only merge a depleted pair whose leaders are within this of each other.
	//--- STRANDED-survivor merge (default-ON). A lone stranded remnant near another friendly team is folded in
	//--- rather than walking home / being culled; same merge payload contract. Group-count DOWN.
	if (isNil "WFBE_C_AICOM_STRANDED_MERGE")       then {WFBE_C_AICOM_STRANDED_MERGE       = 1};    //--- 1 = ON (default), 0 = off.
	if (isNil "WFBE_C_AICOM_STRANDED_MERGE_RANGE") then {WFBE_C_AICOM_STRANDED_MERGE_RANGE = 1200}; //--- m: a stranded remnant within this of a friendly team is merged into it.
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
	if (isNil "WFBE_C_BASE_RES") then {WFBE_C_BASE_RES = 0}; //--- RES Parameters (0 Disabled, 1 West, 2 East, 3 both).
	if (isNil "WFBE_C_BASE_DEFENSE_MAX_AI") then {WFBE_C_BASE_DEFENSE_MAX_AI = 40}; //--- Maximum AIs that will be able to man defense within the barracks area.
	if (isNil "WFBE_C_BASE_DEFENSE_MANNING_RANGE") then {WFBE_C_BASE_DEFENSE_MANNING_RANGE = 250}; //--- Within x meters, defenses may be manned.
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
	if (isNil "WFBE_C_DROPPEDITEMS_CLEANER_DEFER_FIRST") then {WFBE_C_DROPPEDITEMS_CLEANER_DEFER_FIRST = 0}; //--- Default OFF: keep the early ~90s first droppeditems sweep (HEAD). 1 = defer the first whole-island weaponholder sweep to the steady cadence so it runs on a settled server instead of inside the boot storm (fixes the ~6.5s first-sweep wall-time spike; the early sweep finds zero drops anyway).
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
	WFBE_C_CAMPS_RANGE_PLAYERS = 5.5; //--- owner 2026-07-07: +10% capture bubble (5 -> 5.5) alongside CAMPS_RANGE 11.5 -> 12.65.
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
	if (isNil 'WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS') then {WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS = 250};
	if (isNil 'WFBE_C_AICOM_ASSAULT_TIMEOUT')       then {WFBE_C_AICOM_ASSAULT_TIMEOUT       = 420};
	//--- T0.2 ADD (R3-SYNTHESIS 2026-07-20): diagnostic-only, tighter than ARRIVE_RADIUS -
	//--- lets the STUCKSTAT uncap-parked line distinguish "still closing the last 150m" from
	//--- "genuinely at capture range and still not converting". Does not feed any capture,
	//--- abandon, or strike-ladder decision -- read-only in AI_Commander_AssignTowns.sqf.
	if (isNil 'WFBE_C_AICOM_CAPTURE_READY_RADIUS') then {WFBE_C_AICOM_CAPTURE_READY_RADIUS = 60};
	//--- Codex review MEDIUM fix: CAPGATE (server_town.sqf) throttle interval - see the diag_log call there.
	if (isNil 'WFBE_C_CAPGATE_LOG_INTERVAL') then {WFBE_C_CAPGATE_LOG_INTERVAL = 30};
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
	//--- (in a canMove LandVehicle) before the team classifies as "mounted" for reach purposes, UNLESS
	//--- the leader alone is embarked (leader-mounted always counts). 0.5 = the deliberation's spec.
	if (isNil 'WFBE_C_AICOM_MOUNTED_FRAC') then {WFBE_C_AICOM_MOUNTED_FRAC = 0.5};
	//--- FIX A: distance/mobility-aware assault timeout (fable, GR-2026-07-08a; design ASSAULT-DYNTIMEOUT-DESIGN.md
	//--- + ADDENDUM 1). Flag WFBE_C_AICOM_ASSAULT_DYNTIMEOUT: 0 = legacy flat WFBE_C_AICOM_ASSAULT_TIMEOUT for every
	//--- team (byte-identical to pre-change). 1 = per-dispatch dist/mobility-aware timeout, clamped MIN..MAX. ALL
	//--- numeric defaults below are ENGINEERING DEFAULTS, NOT live-measured - re-derive via the design's Section 1.3
	//--- calibration protocol from a confirmed-live ASSAULT_* RPT window before flipping this to 1 in production.
	if (isNil 'WFBE_C_AICOM_ASSAULT_DYNTIMEOUT')    then {WFBE_C_AICOM_ASSAULT_DYNTIMEOUT    = 1};
	if (isNil 'WFBE_C_AICOM_ASSAULT_SPEED_FOOT')    then {WFBE_C_AICOM_ASSAULT_SPEED_FOOT    = 2.2};  //--- m/s conservative cross-country foot pace. ENGINEERING DEFAULT.
	if (isNil 'WFBE_C_AICOM_ASSAULT_SPEED_MOUNTED') then {WFBE_C_AICOM_ASSAULT_SPEED_MOUNTED = 7.5};  //--- m/s effective AI-driven road speed incl. hop-node deceleration. ENGINEERING DEFAULT.
	if (isNil 'WFBE_C_AICOM_ASSAULT_SPEED_AIR')     then {WFBE_C_AICOM_ASSAULT_SPEED_AIR     = 35};   //--- m/s transport-heli team (_teamAir path, AI_Commander_AssignTowns.sqf only). ENGINEERING DEFAULT.
	//--- Map-aware route-overhead factor (worldName idiom already used elsewhere in this file, e.g. REACH_FOOT just
	//--- below). TERRAIN-CENSUS.md (docs/design/v2/) describes TK as ridges/long line-of-sight (worst detour) and ZG
	//--- as compact urban (moderate detour despite short raw distance); CH is the mixed-road-network baseline. Per-
	//--- map value, NOT a flat factor - confirm/correct via the design's Section 1.3 step 4, do not assume this ordering.
	if (isNil 'WFBE_C_AICOM_ASSAULT_ROUTE_FACTOR')  then {WFBE_C_AICOM_ASSAULT_ROUTE_FACTOR  = if (worldName == "Takistan") then {1.5} else {if (worldName == "Zargabad") then {1.35} else {1.25}}};
	if (isNil 'WFBE_C_AICOM_ASSAULT_SLACK')         then {WFBE_C_AICOM_ASSAULT_SLACK         = 120};  //--- s, one extra WFBE_C_AI_COMMANDER_TOWN_INTERVAL (120s) worker-pass margin.
	if (isNil 'WFBE_C_AICOM_ASSAULT_TIMEOUT_MIN')   then {WFBE_C_AICOM_ASSAULT_TIMEOUT_MIN   = 420};  //--- s, floor = today's flat value - short legs are byte-identical to current behaviour.
	if (isNil 'WFBE_C_AICOM_ASSAULT_TIMEOUT_MAX')   then {WFBE_C_AICOM_ASSAULT_TIMEOUT_MAX   = 1500}; //--- s, hard ceiling - beyond this a team is genuinely stuck (existing Recovery-V2 ladder applies), not just far.
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
	if (isNil "WFBE_C_ECONOMY_SUPPLY_START_GUER") then {WFBE_C_ECONOMY_SUPPLY_START_GUER = if (WF_Debug) then {900000} else {30000}};
	//--- PRODUCTION SUPPLY CAP LIVES IN THE MISSION PARAMETER, NOT IN THIS LINE. On a dedicated server, Init_Parameters.sqf
	//--- sets WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT from paramsArray (Rsc\Parameters.hpp class default = 50000) BEFORE this file runs,
	//--- so this isNil fallback is DEAD in MP - the 40000 only applies to non-MP/local (editor) runs. The supply clamp in
	//--- Server\Functions\Server_ChangeSideSupply.sqf reads THIS variable, so the real live ceiling = the param (default 50000).
	//--- That (not the same-numbered WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT below) is why B74 telemetry saw both sides pin at "50k".
	//--- TO RAISE THE LIVE CAP: edit Rsc\Parameters.hpp 'WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT' default/values[]; changing this 40000 does nothing in prod.
	if (isNil "WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT") then {WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT = if (WF_Debug) then {900000} else {40000}};
	if (isNil "WFBE_C_ECONOMY_SUPPLY_SYSTEM") then {WFBE_C_ECONOMY_SUPPLY_SYSTEM = 1}; //--- Supply System (0: Trucks, 1: Automatic with time).
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

// Attack wave.
	ATTACK_WAVE_PRICE_MODIFIER = 1;
	ATTACK_WAVE_ACTIVE_WEST = false;
	ATTACK_WAVE_ACTIVE_EAST = false;

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
	if (isNil "WFBE_C_TOWNS_CAPTURE_MODE") then {WFBE_C_TOWNS_CAPTURE_MODE = 2}; //--- A/B (claude-gaming 2026-06-14): 2->0 Classic. Mode 2 "All Camps" required an attacker to hold EVERY camp simultaneously with dismounted infantry (server_town.sqf:169-177) - AI commander teams arrive mounted + visit camps sequentially, so capDis=0 and only GUER (garrison stands on all camps) ever flipped towns. Mode 0 flips on defender-clear + presence within 40m; camps become a capture-SPEED bonus, not a gate. GUER unchanged (still defends/caps by presence). Reversible: revert to 2, or try 1 (Threshold/140m majority) if towns flip too fast. (0: Normal/Classic, 1: Threshold, 2: All Camps).
	if (isNil "WFBE_C_TOWNS_DEFENDER") then {WFBE_C_TOWNS_DEFENDER = 2}; //--- Town defender Difficulty (0: Disabled, 1: Light, 2: Medium, 3: Hard, 4: Insane).
	if (isNil "WFBE_C_TOWNS_OCCUPATION") then {WFBE_C_TOWNS_OCCUPATION = 2}; //--- Town occupation Difficulty (0: Disabled, 1: Light, 2: Medium, 3: Hard, 4: Insane).
	if (isNil "WFBE_C_TOWNS_GEAR") then {WFBE_C_TOWNS_GEAR = 1}; //--- Buy Gear From (0: None, 1: Camps, 2: Depot, 3: Camps & Depot).
	if (isNil "WFBE_C_TOWNS_PATROLS") then {WFBE_C_TOWNS_PATROLS = 6}; //--- Town-to-town patrols ON by default (up to 6 towns); set 0 in the lobby to disable. DR-57 fix makes them work.
	if (isNil "WFBE_C_TOWNS_PATROL_CONTESTED_ONLY") then {WFBE_C_TOWNS_PATROL_CONTESTED_ONLY = 0}; //--- Lane 190: 0 keeps legacy supply-drop defense flips; 1 only pulls town patrols into defense while the town is stamped contested.
	if (isNil "WFBE_C_WAYPOINT_WATER_RETRY_CAP") then {WFBE_C_WAYPOINT_WATER_RETRY_CAP = 0}; //--- Max random waypoint water rerolls before falling back to the patrol center; 0 keeps legacy uncapped retries.
	if (isNil "WFBE_C_TOWNS_REINFORCEMENT_DEFENDER") then {WFBE_C_TOWNS_REINFORCEMENT_DEFENDER = 0}; //--- Enable towns defender reinforcement.
	if (isNil "WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION") then {WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION = 0}; //--- Enable towns occupation reinforcement.
	if (isNil "WFBE_C_TOWNS_STARTING_MODE") then {WFBE_C_TOWNS_STARTING_MODE = 0}; //--- Town starting mode (0: Resistance, 1: 50% blu, 50% red, 2: Nearby Towns, 3: Random).
	if (isNil "WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER") then {WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER = 1}; //--- Lock the vehicles of the defender side.
	if (isNil "WFBE_C_TOWNS_CAPTURE_BAR_DETAIL") then {WFBE_C_TOWNS_CAPTURE_BAR_DETAIL = 0}; //--- Lane 52: 1 adds observed SV trend text to the client capture bar; 0 keeps the legacy town/SV label.

	//--- Air units.
	if (isNil "WFBE_C_JET_AA_SURVIVE") then {WFBE_C_JET_AA_SURVIVE = 1}; //--- Jets survive the 1st SPAAG (Tunguska/Linebacker) hit: fuel drained + slight damage for a landing attempt; a 2nd hit explodes. 0 disables.
	WFBE_C_TOWNS_CAPTURE_ASSIST = 400;
	WFBE_C_TOWNS_CAPTURE_RANGE = 40;
	WFBE_C_TOWNS_CAPTURE_RATE = 0.4;
	WFBE_C_TOWNS_CAPTURE_THRESHOLD_RANGE = 140;
	WFBE_C_TOWNS_DEFENSE_RANGE = 30;
	WFBE_C_TOWNS_AI_SCAN_RANGE_OVERRIDE = 0; //--- Fleet lane 106: 0 keeps the legacy 600m activation scan base range.
	WFBE_C_TOWNS_AI_SCAN_BASE_RANGE = 600; //--- Used only when WFBE_C_TOWNS_AI_SCAN_RANGE_OVERRIDE > 0.
	WFBE_C_TOWNS_DETECTION_RANGE_ACTIVE_COEF = 1; //--- Town activation range once active (town range * coef)
	WFBE_C_TOWNS_DETECTION_RANGE_COEF = 1; //--- Town activation range while idling (town range * coef)
	WFBE_C_TOWNS_DETECTION_RANGE_AIR = 50; //--- Detect Air if > x
	if (isNil "WFBE_C_TOWN_SCAN_DICE") then {WFBE_C_TOWN_SCAN_DICE = 1}; //--- Perf (2026-07-06): when 1, DORMANT towns (not active, no air tier, no enemy seen within DICE_GRACE) roll per side per sweep whether to run the 600 m activation nearEntities scan. Active towns always scan. Default off = V1 behaviour.
	if (isNil "WFBE_C_TOWN_SCAN_DICE_P") then {WFBE_C_TOWN_SCAN_DICE_P = 0.5}; //--- Probability a dormant town DOES scan on a given sweep (per side).
	if (isNil "WFBE_C_TOWN_SCAN_DICE_GRACE") then {WFBE_C_TOWN_SCAN_DICE_GRACE = 30}; //--- s after the last enemy seen before a town counts as dormant for the dice.
	WFBE_C_TOWNS_MORTARS_SCAN = 60; //--- Scan the area around a target for friends and enemies.
	WFBE_C_TOWNS_MORTARS_INTERVAL = 200; //--- AI Mortars may fire each x seconds.
	WFBE_C_TOWNS_MORTARS_PRECOGNITION = 25; //--- AI Mortars may fire at a target by precognition. This value is a percentage.
	WFBE_C_TOWNS_MORTARS_RANGE_MAX = 750; //--- AI Mortars may not fire at target further than that range (Cannot be higher than artillery core values).
	WFBE_C_TOWNS_MORTARS_RANGE_MIN = 125; //--- AI Mortars may not fire at targets within that range (Cannot be lower than artillery core values).
	WFBE_C_TOWNS_MORTARS_SPLASH_RANGE = 60; //--- AI Mortar firing area of effect.
	WFBE_C_TOWNS_PATROL_HOPS = 5; //--- Amount of Waypoints given to the AI Patrol in towns (Higher is wider).
	WFBE_C_TOWNS_PATROL_RANGE = 500;
	WFBE_C_TOWNS_PURCHASE_RANGE = 60;
	WFBE_C_TOWNS_SUPPLY_LEVELS_TIME = [1, 2, 3, 4, 5];
	WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK = [5, 6, 7, 8, 10];
	WFBE_C_TOWNS_UNITS_INACTIVE = 90; //--- Remove units in town if no enemies are to be found within that time.
	WFBE_C_TOWNS_UNITS_SPAWN_CAPTURE_DELAY = 1200; //--- If x seconds has elapsed since a town last capture, units may spawn again during that town capture.
	WFBE_C_TOWNS_UNITS_WAYPOINTS = 9;

//--- Units.
	if (isNil "WFBE_C_UNITS_BALANCING") then {WFBE_C_UNITS_BALANCING = 1}; //--- Enable Units weaponry balancing.
	if (isNil "WFBE_C_UNITS_BOUNTY") then {WFBE_C_UNITS_BOUNTY = 1}; //--- Enable Units bounty on kill.
	if (isNil "WFBE_C_FIRSTBLOOD_ENABLED") then {WFBE_C_FIRSTBLOOD_ENABLED = 1}; //--- First-blood (claude-gaming 2026-07-07): 1 = the first PVP kill of the match fires a one-time sting + announcement + killer bonus. Default 0 = off (inert).
	if (isNil "WFBE_C_FIRSTBLOOD_BONUS") then {WFBE_C_FIRSTBLOOD_BONUS = 1000}; //--- First-blood: cash bonus credited to the killer team wallet on first blood (only paid when WFBE_C_FIRSTBLOOD_ENABLED>0).
	if (isNil "WFBE_FIRSTBLOOD_DONE") then {WFBE_FIRSTBLOOD_DONE = false}; //--- First-blood one-shot latch (runtime state, not a tunable); false each fresh mission instance.
	if (isNil "WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW") then {WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW = 60}; //--- Seconds where a damaged vehicle can still award its last valid hitter.
	if (isNil "WFBE_C_UNITS_CLEAN_TIMEOUT") then {WFBE_C_UNITS_CLEAN_TIMEOUT = 60}; //--- Lifespan of a dead body.
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
		"TIP: Build 91 is live - Zargabad towns now flip, WDDM-designed defense positions & fortifications ring the front, and town AA now guards active-air towns. Watch the skies.",
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

	// === EXPERITAL FEATURES (experimental branch ??? each feature individually toggleable) ===
	WFBE_C_STRUCTURES_COUNTERBATTERY = 1; // Counter Battery Radar structure (mid-game, requires own AAR)
	WFBE_C_ECONOMY_BANK = 1;              // Federal Reserve / Bank Rossii endgame objective building
	WFBE_C_STRUCTURES_ARTILLERYRADAR = 0; // Artillery Radar buildable structure (WDDM walled-gate walls, fort-only by design)
	WFBE_C_STRUCTURES_RESERVE = 0;        // Reserve buildable structure (WDDM floodlit walled-yard walls)
	WFBE_C_STRUCTURES_RADIOTOWER = 1;     // Radio Tower buildable - gates the vehicle radio feature (WASP/Radio); Land_Telek2 model NOT verified present on TK/ZG runtime content
	WFBE_C_STRUCTURES_RADIOTOWER_CASH_COST = 2500; // owner 2026-07-09: Radio Tower is bought with player CASH (not side supply). Read at the 3 coin economy touchpoints (Init_Coin buy-menu currency index 1, coin_interface deduction, GUI_Menu_Economy sell-refund), keyed on rlType "RadioTower".
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
	WFBE_C_LOG_TOWN_COORDS = 1;           // One-shot: dump every town's map position (TOWNPOS|... RPT lines) for the post-match report's TOWN_COORDS. Flip to 1 for a single boot per map, harvest, flip back. Off = zero effect.
	if (isNil "WFBE_C_TOWNS_GUNNERS_ON_CAPTURE") then {WFBE_C_TOWNS_GUNNERS_ON_CAPTURE = true}; // Immediately man static defenses at capture (all sides); false = reactive only
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
	if (isNil "WFBE_C_PATROL_CONVOY_PAY") then {WFBE_C_PATROL_CONVOY_PAY = 750}; // Task 41: cash pool paid to the side each time a convoy patrol stops at a town (split equally among living players)
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
if (isNil "WFBE_C_NEUTRAL_COLOR") then {WFBE_C_NEUTRAL_COLOR = "ColorGray"};
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

//--- Apply a towns unit coeficient.
	WFBE_C_TOWNS_UNITS_COEF = switch (WFBE_C_TOWNS_OCCUPATION) do {case 1: {1}; case 2: {1.5}; case 3: {2}; case 4: {2.5}; default {1}};
	WFBE_C_TOWNS_UNITS_DEFENDER_COEF = switch (WFBE_C_TOWNS_DEFENDER) do {case 1: {1}; case 2: {1.5}; case 3: {2}; case 4: {2.5}; default {1}};
	WFBE_C_TOWNS_MERGE_TARGET = 9;                //--- GROUP-COUNT REDUCTION (claude-gaming 2026-06-13): target units per CONSOLIDATED town-garrison infantry group. Server_GetTownGroups/Defender fuse the SAME infantry rosters into ~this-many-unit groups (hard cap 10) so a town spawns identical units in FEWER server group-brains (server-FPS win, gameplay-transparent). Vehicles never merged. Set to 0 to disable (instant rollback to one-group-per-template).
	if (isNil 'WFBE_C_TOWNS_MERGE_TARGET_DEFENDER') then {WFBE_C_TOWNS_MERGE_TARGET_DEFENDER = 10}; //--- GUER condense A/B (task #12, claude-gaming 2026-06-14): raised 9->11 units/group to fuse GUER garrisons harder (fewer group-brains, SAME units). Measure GUER group count + fps vs Build 28. WEST/EAST untouched (global 5).
	if (isNil 'WFBE_C_TOWNS_MERGE_CAP_DEFENDER') then {WFBE_C_TOWNS_MERGE_CAP_DEFENDER = 12};    //--- Defender-only merged-group size cap (raised from the global hardcoded 10 so the 11-target can actually flush at ~11-12; 12 = classic A2 squad max, safe for static garrison defenders).
	if (isNil 'WFBE_C_SIDE_PATROLS_MAX_DEFENDER') then {WFBE_C_SIDE_PATROLS_MAX_DEFENDER = 3};      //--- Build83 (Ray 2026-07-01): GUER (defender) side-patrol cap RAISED +2 -> 3 (effective = min(this, GUER patrol level)). [B36 2026-06-15 had 2->1: fewer GUER patrols, the survivors made deadlier (skill boost in Common_RunSidePatrol). GUER condense.
	if (isNil 'WFBE_C_GUER_PATROLS_LEVEL') then {WFBE_C_GUER_PATROLS_LEVEL = 2};                    //--- B67 (Ray 2026-06-21): fixed Patrols level for GUER (resistance has no upgrade system) so GUER side-patrols actually dispatch and show on GUER players' maps (server_side_patrols.sqf). Effective concurrent count = min(_maxSide, this). 0 = OFF (no GUER patrols, instant rollback); 1 = single; 2 = a pair; 4 adds the convoy supply truck.
	WFBE_C_GROUP_BUDGET_WARN = 120;               //--- GROUP-BUDGET ALARM (claude-gaming 2026-06-13): per-side group-count WARN threshold (GRPBUDGET line in AI_Commander.sqf). Arma 2 OA hard cap is 144/side; crossing this logs a GRPBUDGET|WARN so the watchdog/dashboard flags it before the AI can no longer found teams. (120, not 125: with the persistent-husk leak fixed, steady state should drop below 120, making the WARN a true leading indicator rather than always-on.)
	if (isNil 'WFBE_C_GROUPAUDIT_EVERY') then {WFBE_C_GROUPAUDIT_EVERY = 5}; //--- D2 server-FPS (claude-gaming 2026-06-14): run the EXPENSIVE per-faction group-classification AUDIT DUMP (server_groupsGC.sqf; auditMs ~2100ms on 276 groups) only every Nth 5-min audit window. The husk-reap GC + zombie-reap + cap-warning still run EVERY 60s cycle (they live outside the audit branch) - this throttles only diagnostic telemetry. 5 = full dump ~every 25 min instead of every 5 min. 1 = dump every window (old behavior); values < 1 are clamped to 1. Pure diagnostic throttle, no gameplay effect; instant rollback by setting to 1.

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
		WFBE_C_TOTAL_AI_MAX_BY_TIER = [80,80,70,60];   //--- ZG (was [140,130,100,80]). Rollback: restore the CH/TK array.
		//--- (2) per-side COMMANDER-TEAM hard ceiling. Fewer teams, each still founds at 8 units (TEAM_SIZE untouched)
		//--- = concentration, not sprawl. 5 x 8 = ~40 core + garrisons stays under the 80 AI cap above.
		WFBE_C_AICOM_TEAMS_HARD_CAP = 5;               //--- ZG (was 10). Rollback: 10.
		//--- (3) low/mid-pop PC-scaled base founding target (DELTA -1 then FLOOR/hard-cap clamp still apply): keep the
		//--- base under the new hard cap so the curve, not just the clamp, sets team count. LOW 6-1=5, MID 5-1=4.
		WFBE_C_AICOM_TEAMS_PC_LOW  = 6;                //--- ZG (was 10). Rollback: 10.
		WFBE_C_AICOM_TEAMS_PC_MID  = 5;                //--- ZG (was 7).  Rollback: 7.
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
	if (isNil "AICOMV2_GDIR_CELL_SPEED_MS")         then {AICOMV2_GDIR_CELL_SPEED_MS = 8};        //--- Virtual ground speed for cell movement (m/s).
	if (isNil "AICOMV2_GDIR_SUPPRESS_SEC")          then {AICOMV2_GDIR_SUPPRESS_SEC = 600};       //--- Post-wipe offensive-suppression window (s).
	if (isNil "AICOMV2_GDIR_RETAKE")                then {AICOMV2_GDIR_RETAKE = 0};               //--- Retake-cell aggression: 0=off, 1=low. Default 0 CH; TK profile may set 1.
	if (isNil "AICOMV2_GDIR_PLAYER_SUPPORT")        then {AICOMV2_GDIR_PLAYER_SUPPORT = 0};       //--- Bias cells toward human GUER players (0=off).
//--- Amendment A2: Air-Contact Activation Tier dials (folded under AICOMV2_LANE_GUER_DIRECTOR gate).
	if (isNil "AICOMV2_GDIR_AIR_CEILING_MIN_M")     then {AICOMV2_GDIR_AIR_CEILING_MIN_M = 100}; //--- Air below this m ALWAYS activates the AA tier on each sweep.
	if (isNil "AICOMV2_GDIR_AIR_CEILING_MAX_M")     then {AICOMV2_GDIR_AIR_CEILING_MAX_M = 600}; //--- Air above this m NEVER activates the AA tier.
//--- Amendment A1: Player Commissar Panel dials (panel switch AICOMV2_GDIR_PANEL default 0).
	if (isNil "AICOMV2_GDIR_PANEL")                 then {AICOMV2_GDIR_PANEL = 1};               //--- A1 Commissar Panel gate: 0=off (byte-identical). Requires AICOMV2_LANE_GUER_DIRECTOR=1.
	if (isNil "AICOMV2_GDIR_PANEL_COOLDOWN_SEC")    then {AICOMV2_GDIR_PANEL_COOLDOWN_SEC = 600};//--- Per-town action cooldown (s) between panel buys.
	if (isNil "AICOMV2_GDIR_PANEL_CONTRACTS_MAX")   then {AICOMV2_GDIR_PANEL_CONTRACTS_MAX = 2}; //--- Max active contracts per town simultaneously.
	if (isNil "AICOMV2_GDIR_PANEL_INSTANT_MULT")    then {AICOMV2_GDIR_PANEL_INSTANT_MULT = 1.5};//--- Price multiplier for instant delivery vs convoy.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_REINF")     then {AICOMV2_GDIR_PANEL_PRICE_REINF = 1600}; //--- Base price: Action 1 convoy reinforcement.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_QRF_INS")   then {AICOMV2_GDIR_PANEL_PRICE_QRF_INS = 1200};  //--- Base price: Action 2 QRF insert tier.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_QRF_GUN")   then {AICOMV2_GDIR_PANEL_PRICE_QRF_GUN = 2400}; //--- Base price: Action 2 QRF gunship tier.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_CTR_ATK")   then {AICOMV2_GDIR_PANEL_PRICE_CTR_ATK = 1000};  //--- Base price: Action 3 counter-attack contract.
	if (isNil "AICOMV2_GDIR_PANEL_SCARCITY_STEP")   then {AICOMV2_GDIR_PANEL_SCARCITY_STEP = 0.2};  //--- Scarcity multiplier step per recent buy on same town.
	if (isNil "AICOMV2_GDIR_PANEL_SCARCITY_DECAY")  then {AICOMV2_GDIR_PANEL_SCARCITY_DECAY = 120}; //--- Seconds for scarcity to decay one step back toward 1.0.
	if (isNil "AICOMV2_GDIR_PANEL_LF_MIN")          then {AICOMV2_GDIR_PANEL_LF_MIN = 1.0};          //--- loadFactor floor (healthy server).
	if (isNil "AICOMV2_GDIR_PANEL_LF_MAX")          then {AICOMV2_GDIR_PANEL_LF_MAX = 2.5};          //--- loadFactor ceiling (stressed server).
	if (isNil "AICOMV2_GDIR_QRF_CAS_SEC")           then {AICOMV2_GDIR_QRF_CAS_SEC = 180};          //--- Gunship on-station duration (s).
//--- Amendment: Hardening + Shop (fable/gdir-harden-shop).
//--- P1 - Movement ETA-timeout: cells stuck past ETA teleport-merge into destination town.
	if (isNil "AICOMV2_GDIR_HARDEN")                 then {AICOMV2_GDIR_HARDEN = 1};                //--- Master switch: 0=off (P1/P2 inert), 1=hardening active.
	if (isNil "AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR")    then {AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR = 3};   //--- ETA safety factor: ETA = (dist/CELL_SPEED_MS)*factor seconds.
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
//--- P4 - Relief squad (AICOMV2_GDIR_PANEL gate) + mortar harassment.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_RELIEF")     then {AICOMV2_GDIR_PANEL_PRICE_RELIEF = 800};  //--- Base price: relief squad (infantry-only fast buy). 1/2x of REINF base.
	if (isNil "AICOMV2_GDIR_PANEL_PRICE_MORTAR")     then {AICOMV2_GDIR_PANEL_PRICE_MORTAR = 1200}; //--- Base price: mortar harassment action.
	if (isNil "AICOMV2_GDIR_MORTAR_COOLDOWN_SEC")    then {AICOMV2_GDIR_MORTAR_COOLDOWN_SEC = 900}; //--- Per-town mortar action cooldown (s); separate from action cooldown.
	if (isNil "WFBE_C_GDIR_GARRISON_GAIN") then {WFBE_C_GDIR_GARRISON_GAIN = 1}; //--- owner 2026-07-07: ARMED at 1.0 (Director-reinforced GUER towns wake with +~50% real garrison at max funded surge; floored at V1).
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
	if (isNil "WFBE_C_USV_FLOTILLA_ENABLE")   then {WFBE_C_USV_FLOTILLA_ENABLE = 1};   //--- master flag. 0 = OFF, byte-identical to HEAD.
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
//--- WFBE_C_NAVAL_INLINE_GAP  (default -265):
//---   Hull B anchor offset along the ship's LONG axis, in metres (body-space Y).
//---   Negative = aft of Hull A anchor.  Tunable at mission start without a code
//---   edit: read as getVariable ["WFBE_C_NAVAL_INLINE_GAP", -265] at spawn time.
//---   Safe iterate range for in-editor seam alignment: -258 to -275.
//---   Derivation: 128m (Hull A stern-to-anchor) + 9m (Hull A stern overhang)
//---               + 8m (Hull B bow overhang) + 120m (Hull B anchor-to-bow) = 265m.
//---
//--- WFBE_C_NAVAL_SEAM_BRIDGE  (default 0):
//---   When > 0, spawn 4x Land_nav_pier_m_1 bridge segments across the Hull A
//---   stern / Hull B bow seam.  Placed at body-space Y offsets (-131,-134,-137,-140
//---   from Hull A anchor) at the averaged deck-Z of both hulls.
//---   Escalation-ladder step 2: flush-butt geometry is tried first (inline=1,
//---   seam=0); add piers only if the seam wheeled-vehicle test requires it.
//---   Has no effect unless WFBE_C_NAVAL_INLINE_HULLS > 0.
//======================================================================================
	if (isNil "WFBE_C_NAVAL_INLINE_HULLS") then {WFBE_C_NAVAL_INLINE_HULLS  = 1};   //--- 0 = lateral HEAD behaviour; >0 = inline bow-to-stern axis
	if (isNil "WFBE_C_NAVAL_INLINE_GAP")   then {WFBE_C_NAVAL_INLINE_GAP    = -265}; //--- Hull B aft offset metres (body Y); tune -258..-275 in-editor
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
	if (isNil "WFBE_C_SML_WATCHDOG_TTL") then {WFBE_C_SML_WATCHDOG_TTL = 240};  //--- s: per-unit TTL before the watchdog forces doFollow back (covers all exit paths).
//--- SML-2: real dismounts (cargo infantry advance on foot; driver/gunner stay mounted for fire support). Flag-gated default 0.
	if (isNil "WFBE_C_SML_DISMOUNTS")              then {WFBE_C_SML_DISMOUNTS              = 1};   //--- 1=enable real dismounts; 0=byte-identical legacy behaviour.
	if (isNil "WFBE_C_SML_DISMOUNTS_RANGE")        then {WFBE_C_SML_DISMOUNTS_RANGE        = 150}; //--- m: dismount is triggered only when the team leader is within this range of the objective (reserved; caller already at capture site).
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
//--- Default 0 = byte-identical to HEAD (the PV loop below never spawns).
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
	if (isNil "WFBE_C_GARRISON_DRESSING")          then {WFBE_C_GARRISON_DRESSING = 1};           //--- Master enable. 0 = off (default); >0 = dress active contested GUER towns.
	if (isNil "WFBE_C_GARRISON_DRESSING_INTERVAL") then {WFBE_C_GARRISON_DRESSING_INTERVAL = 45};  //--- Seconds between worker ticks.
	if (isNil "WFBE_C_GARRISON_DRESSING_RADIUS")   then {WFBE_C_GARRISON_DRESSING_RADIUS = 900};   //--- m: enemy proximity gate + quiet-timeout radius.
	if (isNil "WFBE_C_GARRISON_DRESSING_LIFETIME") then {WFBE_C_GARRISON_DRESSING_LIFETIME = 900}; //--- s: forced recycle age per gun (anti-accumulation).
	if (isNil "WFBE_C_GARRISON_DRESSING_MAX")      then {WFBE_C_GARRISON_DRESSING_MAX = 6};        //--- Max simultaneous dressed towns across the map.
	if (isNil "WFBE_C_GARRISON_DRESSING_SEARCHLIGHT") then {WFBE_C_GARRISON_DRESSING_SEARCHLIGHT = 1}; //--- 1: add SearchLight_RUS at night; 0: gun only.
//--- AIRFIELD-OWNERSHIP GATE (fable/airfield-ownership-gate, GR-2026-07-06a):
//--- When >0, players may only purchase/spawn aircraft at an airfield the player's own side holds.
//--- Ownership proxy: WFBE_CO_FNC_GetAirfieldOwnerSideID finds the nearest entry in the towns array
//--- within WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS and reads its sideID (set by the capture system).
//--- The airfield depot logic (wfbe_is_airfield=true) is always within ~80m of its companion
//--- LocationLogicAirport (see binding table in PR body). Unbound airfield (radius miss) = ALLOWED.
//--- Flag-off (0) = byte-identical (no gate). AI commander unaffected (AI uses Server_BuyUnit).
	if (isNil "WFBE_C_AIRFIELD_OWNERSHIP_GATE")    then {WFBE_C_AIRFIELD_OWNERSHIP_GATE = 1};    //--- 0=off (default, byte-identical); 1=on (block aircraft purchase at enemy-owned airfields).
	if (isNil "WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS") then {WFBE_C_AIRFIELD_OWNER_TOWN_RADIUS = 500}; //--- m: radius for nearest-town ownership lookup. 500m safely binds each airport to its depot (max separation ~80m on all terrains; nearest non-airfield town is 679m+).

//--- FPV STRIKE DRONE (fable/fpv-strike-drone): player-piloted kamikaze mini-UAV bought from the
//--- Tactical Center (sibling of the UAV support call). Client module: Client/Module/FPV/.
//--- Flag-off (0) = no menu row, module exits on entry = byte-identical behavior.
	if (isNil "WFBE_C_FPV_DRONE")      then {WFBE_C_FPV_DRONE      = 1};           //--- Master gate: 0=off, 1=on (default). Lobby param mirrors this. RE-ENABLED (fixwave-20260717): tonight-20260717 safe-fallback reverted alongside the purchase-authority race fix (Support_FPV.sqf seat-replication window 1s->10s + client deny teardown in Client/PVFunctions/HandleSpecial.sqf).
	if (isNil "WFBE_C_FPV_DRONE_COST") then {WFBE_C_FPV_DRONE_COST = 2500};        //--- Purchase price (deducted client-side in fpv.sqf).
	if (isNil "WFBE_C_FPV_DRONE_TTL")  then {WFBE_C_FPV_DRONE_TTL  = 240};         //--- s: battery life; expiry DISARMS then scuttles (no parked bomb).
	if (isNil "WFBE_C_FPV_DRONE_AMMO") then {WFBE_C_FPV_DRONE_AMMO = "R_57mm_HE"}; //--- Warhead ammo class (RPG-warhead scale: hit 150 / indirect 40 / r 12).

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
	if (isNil "WFBE_C_ARTY_RING") then {WFBE_C_ARTY_RING = 1}; //--- #90: client-local range ellipse per friendly artillery piece.
	if (isNil "WFBE_C_TAGS_AI") then {WFBE_C_TAGS_AI = 1}; //--- TAGS: nametags above friendly AI infantry + vehicles (shares the 18-slot pool).
	if (isNil "WFBE_C_GDIR_VIS") then {WFBE_C_GDIR_VIS = 1}; //--- Commissar visibility pack: wallet label, heatmap, order broadcasts, QRF feedback.
	if (isNil "WFBE_C_ICBM_COUNTDOWN") then {WFBE_C_ICBM_COUNTDOWN = 1}; //--- #78/#455: both-sides HUD countdown to ICBM impact.
	if (isNil "WFBE_C_MISSILE_WARNING") then {WFBE_C_MISSILE_WARNING = 1}; //--- #367/#307: audible warning while an ICBM is in flight.
	if (isNil "WFBE_C_LOADOUT_REGISTRY_SCRUB") then {WFBE_C_LOADOUT_REGISTRY_SCRUB = 1}; //--- #416 cheat fix: strip non-purchasable items from player loadouts on equip.
	if (isNil "WFBE_C_HQ_REPAIR_SCALING") then {WFBE_C_HQ_REPAIR_SCALING = 1}; //--- #185: HQ repair cost 7.5k -> 49.5k over the rolling average round length (profileNamespace WFBE_RPAVG). 0 = legacy 3-tier prices.
	if (isNil "WFBE_C_GUER_PATROL_MARKERS") then {WFBE_C_GUER_PATROL_MARKERS = 1}; //--- owner: resistance-only map intel layer (friendly AI dots + owned-town health flags + inbound cell arrows).
	if (isNil "WFBE_C_UNIT_DESIGNER") then {WFBE_C_UNIT_DESIGNER = 1}; //--- Team-menu Units tab: infantry loadout templates applied to bought AI squad units.
	if (isNil "WFBE_C_SEAD") then {WFBE_C_SEAD = 1}; //--- B93 SEAD: scripted anti-radar guidance for tier-5 jets (F35B/Su34), 2-shot cap. ARMED (1) since 0be461ef4 "feat(flags): arm first-blood, SEAD, camp single-flip, idle-thread skip [owner late window]" (2026-07-07) - merged dark pending Build 93.
if (isNil "WFBE_C_RADIUSHOLD_ENABLE") then {WFBE_C_RADIUSHOLD_ENABLE = 1}; //--- fable/radius-hold-primitive (GR-2026-07-08a): master gate for the shared radius-presence-hold primitive (Common_RadiusHold.sqf). ARMED by default (1) since ee3f8193 "release: enable all feature flags at launch" (2026-07-09, owner-authorized) - merged dark (0); 0 refuses every registration and the dispatcher never spawns.
if (isNil "WFBE_C_RADIUSHOLD_TICK_SECS") then {WFBE_C_RADIUSHOLD_TICK_SECS = 5}; //--- fable/radius-hold-primitive: shared dispatcher tick cadence (seconds) for all registered holds.
if (isNil "WFBE_C_RADIUSHOLD_CONTEST_DECAY") then {WFBE_C_RADIUSHOLD_CONTEST_DECAY = 0}; //--- fable/radius-hold-primitive: per-tick progress decay applied only when contestMode=1 while a hold is contested.
if (isNil "WFBE_C_RADIUSHOLD_MAX_ACTIVE") then {WFBE_C_RADIUSHOLD_MAX_ACTIVE = 8}; //--- fable/radius-hold-primitive: hard cap on simultaneously-registered holds.
if (isNil "WFBE_C_NAVALHVT_BUBBLE_ENABLE") then {WFBE_C_NAVALHVT_BUBBLE_ENABLE = 0}; //--- fable/fix-carrier-capture (owner live 2026-07-10 "carrier not capturing while on its deck"): default was 1, which SKIPS the camps-on-deck capture-drain (server_town.sqf:285) and registers proximity bubbles that do not grant deck capture - so a carrier could never be captured by standing on it. Restored to 0 = the DARK/intended default this comment already documented; camps-on-deck (with the B755 deckZ+12 height fix) is the live capture path.
if (isNil "WFBE_C_NAVALHVT_BUBBLE_RADIUS") then {WFBE_C_NAVALHVT_BUBBLE_RADIUS = 180}; //--- fable/radius-hold-primitive: carrier bubble radius (metres) when WFBE_C_NAVALHVT_BUBBLE_ENABLE=1.
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
	if (isNil "AICOMV2_LANE_CMD_TOWN_LEDGER") then {AICOMV2_LANE_CMD_TOWN_LEDGER = 0}; //--- Lane master switch: 0=off (default, byte-identical). owner 2026-07-09: DISARMED for this patch (reconcile flip armed it, but its spec ships it dark) - CTL was never soak-tested + has 2 open survivor-tracking defects (New-Bug-A/B, CTL-ARMING-SPEC.md). Queued to next patch: fix both, then arm after a real soak.
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
//--- CLIENT FRAME-PACING TELEMETRY (codex-gaming-lane-2, 2026-07-13): local RPT-only baseline.
//--- 0 = no sampler VM, no diag_fps reads, no entity scan and no network traffic.
if (isNil "WFBE_C_CLIENT_FRAME_TELEMETRY") then {WFBE_C_CLIENT_FRAME_TELEMETRY = 1};
if (isNil "WFBE_C_CLIENT_FRAME_TELEMETRY_INTERVAL") then {WFBE_C_CLIENT_FRAME_TELEMETRY_INTERVAL = 60};

["INITIALIZATION", "Init_CommonConstants.sqf: Constants are defined."] Call WFBE_CO_FNC_LogContent;

