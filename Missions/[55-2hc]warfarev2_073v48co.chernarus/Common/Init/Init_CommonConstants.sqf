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

//--- GUER "Insurgents" playable faction master gate (0=off, 1=on). Default OFF = byte-for-byte today's behaviour.
	if (isNil "WFBE_C_GUER_PLAYERSIDE") then {WFBE_C_GUER_PLAYERSIDE = 1}; //--- B66: 0->1 GUER playable ON (trial round).
	if (isNil "WFBE_C_GUER_VBIED_ARM_DELAY") then {WFBE_C_GUER_VBIED_ARM_DELAY = 3};
	if (isNil "WFBE_C_GUER_VBIED_BLAST_RADIUS") then {WFBE_C_GUER_VBIED_BLAST_RADIUS = 60}; //--- B74.1 (Ray 2026-06-23): 30->60. The blast is now 3x Bo_FAB_250 (far bigger than the old 3x 122mm HE), so widen the cash-for-kills snapshot radius to match the real lethal zone - otherwise kills outside 30m didn't pay (Ray: "grant money whenever something is killed").
	if (isNil "WFBE_C_GUER_VBIED_TYPE") then {WFBE_C_GUER_VBIED_TYPE = "hilux1_civil_2_covered"};
	if (isNil "WFBE_C_GUER_KILL_BOUNTY_COEF") then {WFBE_C_GUER_KILL_BOUNTY_COEF = 0.5};
	if (isNil "WFBE_C_GUER_IED_KILL_COEF") then {WFBE_C_GUER_IED_KILL_COEF = 0.30}; //--- B67 (Ray 2026-06-21) item #8: an IED kill pays only 30% of the normal vehicle/unit bounty (anti-farm) so spamming IEDs for cash is not worthwhile. Applied in RequestOnUnitKilled when the kill is tagged as an IED kill.

	//--- GUER improvised mortar strike (V3S_Gue driver call-in barrage; Action_GuerMortarStrike.sqf -> RequestSpecial -> Server_HandleSpecial "guer-mortar-strike").
	if (isNil "WFBE_C_GUER_MORTAR_COOLDOWN") then {WFBE_C_GUER_MORTAR_COOLDOWN = 240};	//--- seconds between GUER mortar strikes (per player).
	if (isNil "WFBE_C_GUER_MORTAR_RANGE")    then {WFBE_C_GUER_MORTAR_RANGE    = 1200};	//--- max designation range from the calling player (m).
	if (isNil "WFBE_C_GUER_MORTAR_SHELLS")   then {WFBE_C_GUER_MORTAR_SHELLS   = 6};	//--- shells per barrage.
	if (isNil "WFBE_C_GUER_MORTAR_COST")     then {WFBE_C_GUER_MORTAR_COST     = 200};	//--- funds debited from the caller's GUER team per strike (0 = free).
	if (isNil "WFBE_C_GUER_MORTAR_SPREAD")          then {WFBE_C_GUER_MORTAR_SPREAD          = 25};	//--- base +/- impact spread (m) at tier 0.
	if (isNil "WFBE_C_GUER_MORTAR_SPREAD_TIERSTEP") then {WFBE_C_GUER_MORTAR_SPREAD_TIERSTEP = 4};	//--- spread tightens by this many m per GUER vehicle tier.
	if (isNil "WFBE_C_GUER_MORTAR_SPREAD_MIN")      then {WFBE_C_GUER_MORTAR_SPREAD_MIN      = 8};	//--- floor on the +/- spread (m), however high the tier.

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

//--- AI.
	if (isNil "WFBE_C_AI_COMMANDER_ENABLED") then {WFBE_C_AI_COMMANDER_ENABLED = 1}; //--- Enable or disable the AI Commanders.
	//--- AI COMMANDER LOCK: when 1, AI retains full command regardless of who occupies the slot.
	//--- Protects eval/night sessions from accidental human takeover. Default 0 = normal play.
	if (isNil "WFBE_C_AI_COMMANDER_LOCK") then {WFBE_C_AI_COMMANDER_LOCK = 0}; //--- B67 (Ray 2026-06-21): 1->0 to ENABLE the hybrid commander feature (#5). Players can now vote out the AI commander; the AI then keeps founding/refilling its teams (assist mode) while the player builds + can re-task all teams. Set back to 1 to relock (AI always commands - the eval/night-soak posture).
	if (isNil "WFBE_C_AICOM_PUBLIC_STATE_SYNC") then {WFBE_C_AICOM_PUBLIC_STATE_SYNC = 0}; //--- Default OFF: keep wfbe_aicom_funds/running server-local. 1 = broadcast side-logic AICOM state writes for HC readers.
	//--- ACTIVE-TOWN BUDGET: max concurrently active towns. FPS lever; 12 for the legacy-vs-next A/B (Steff 2026-06-13).
	if (isNil "WFBE_C_TOWNS_ACTIVE_MAX") then {WFBE_C_TOWNS_ACTIVE_MAX = 12}; //--- punchy-AICOM (Ray 2026-06-18): KEEP 12 for the next test - concentration comes from SPEARHEAD_TOWNS_MAX=1 + CONCENTRATION=4 (mass on one town of the full 12-town front), NOT from shrinking the active set.
	if (isNil "WFBE_C_TOWNS_STARTUP_SLEEP") then {WFBE_C_TOWNS_STARTUP_SLEEP = 0}; //--- Fleet lane 115: optional startup pacing for server_town_ai's two town init passes. 0 = legacy 0.01s; try 0.05-0.10 to soften large-map startup spikes.
	//--- GUER GROUP CAP: hard ceiling on total resistance groups. Bounds runaway GUER growth toward the engine's ~144-groups/side
	//--- limit over long stalled AI-vs-AI runs (garrisons + W9 uprising + side-patrols, none of which had a global cap).
	//--- 90 is far above any single-front GUER force, well under the 144 ceiling; raise to 999 for an instant rollback.
	if (isNil "WFBE_C_GUER_GROUPS_MAX") then {WFBE_C_GUER_GROUPS_MAX = 80}; //--- 60->80 (Ray 2026-06-15, fold from fleet group-budget tuning): 60 choked GUER garrisons above the observed ~73 peak; 80 restores headroom, still well under the 144 engine cap. Was 90; raise to 999 for instant rollback.
	if (isNil "WFBE_C_AI_MAX") then {WFBE_C_AI_MAX = 12}; //--- Max AI allowed on each AI groups.
	if (isNil "WFBE_C_AI_DELEGATION") then {WFBE_C_AI_DELEGATION = 0}; //--- Enable AI delegation (0: Disabled, 1: creation of ai on the client, 2: Headless Client).
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
	WFBE_C_TOTAL_AI_MAX_BY_TIER       = [140,130,100,80];     //--- per-side commander-AI ceiling (founding gate + AI_Commander_Produce)
	WFBE_C_AICOM_LOWPOP_EXTRA_BY_TIER = [3,2,0,0];            //--- funds-valve extra teams (valve only fires pop<=5 = LOW/MID)
	WFBE_C_TOWNS_DEFENDER_BY_TIER     = [2,2,2,1];            //--- town garrison difficulty -> COEF (Medium/Medium/Medium/Light)
	WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER   = [12,12,10,8];         //--- concurrently-active-towns cap (the single largest AI slice)
	WFBE_C_SIDE_PATROLS_MAX_BY_TIER   = [3,3,3,2];            //--- Build83 (Ray 2026-07-01): +1 WEST/EAST side-patrol cap per tier ([2,2,2,1]->[3,3,3,2]). Effective = min(this, patrol level).
	WFBE_C_PLAYERS_AI_MAX_BY_TIER     = [16,14,12,10];        //--- per-player AI buy-cap (recruit cap; never deletes an existing squad)
	WFBE_C_AICOM_INCOME_PC_BONUS_VALVE = 0.045; //--- B37: gentler low-pop income boost when the valve is on (vs 0.06), so more-squads does not over-bank.
	WFBE_C_AICOM_INCOME_MULT_MAX = 4.0;        //--- B67 (Ray 2026-06-21): 3.0->4.0 - lift the town-cash multiplier ceiling so the low-pop inverted bonus is not clipped (keeps near-empty-server PvE well-funded). CASH only. hard ceiling on the scaled commander income multiplier (packed-server runaway guard).
	if (isNil "WFBE_C_AICOM_AIR_MIN_TOWNS") then {WFBE_C_AICOM_AIR_MIN_TOWNS = 3}; //--- B66: 4->3 - bring air online a town sooner. Aircraft are deferred until the AI holds this many towns (it flies poorly; air is a late, established-only asset). 0 = no gate.
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
	if (isNil "WFBE_C_OILFIELD_GUER_RAID") then {WFBE_C_OILFIELD_GUER_RAID = 0};           //--- (GUER raids) DEFAULT OFF (adds AI units): 1 = occasional GUER foot party raids the field while it is PAYING. Group-budget-aware.
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
	if (isNil "WFBE_C_AICOM_TYPE_MIX_EARLY") then {WFBE_C_AICOM_TYPE_MIX_EARLY = [0.45, 0.27, 0.25, 0.03]};   //--- Ray 2026-06-27: less foot, more light/heavy early (was [0.70,0.22,0.07,0.01]) so the AI fields armed vehicles sooner, not infantry-in-trucks. Self-gating: an empty bucket (no factory) still falls back to foot, so capture infantry is never starved.
	if (isNil "WFBE_C_AICOM_TYPE_MIX_MID")   then {WFBE_C_AICOM_TYPE_MIX_MID   = [0.38, 0.24, 0.26, 0.12]};  //--- AICOM v2 (Ray): air 5%->12% mid so choppers start ramping in before the late tier.
	if (isNil "WFBE_C_AICOM_TYPE_MIX_LATE")  then {WFBE_C_AICOM_TYPE_MIX_LATE  = [0.25, 0.15, 0.30, 0.30]};  //--- AICOM v2 (Ray): air 15%->30% late (inf/light/heavy/air) - choppers a defining late-game feature.
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
		if (isNil "WFBE_C_AICOM_MECH_BIAS")  then {WFBE_C_AICOM_MECH_BIAS  = 1.5}; //--- B756 (Ray 2026-06-26): trimmed 2.0->1.5 after the b755 soak (heavy OVERTOOK infantry 38% vs 32%; want mech prominent, not infantry suppressed). Pairs with WFBE_C_AICOM_DISMOUNT_BIAS to favour IFV/APC dismount-carriers over bare MBT within the heavy pick.
		if (isNil "WFBE_C_AICOM_MOTOR_BIAS") then {WFBE_C_AICOM_MOTOR_BIAS = 1.4};
		//--- B755 RE-MOUNT FOR THE LONG LEG: a team re-tasked to a far town after a prior capture has its infantry ON FOOT (the capture dismount unassigned them). 1 = re-seat them into the team's drivable hulls before the road-march so they RIDE the long leg instead of foot-marching (no-op on the first march). 0 = old behaviour.
		if (isNil "WFBE_C_AICOM_REMOUNT_LONG_LEG") then {WFBE_C_AICOM_REMOUNT_LONG_LEG = 1};
		//--- B756 (Ray 2026-06-26) DISMOUNT-CARRIER bias: within the team-template draw, multiply a template's weight if it carries INFANTRY dismounts (so IFV/APC + squad beat bare MBTs in the heavy bucket = "infantry seated in armed vehicles" rather than gun-tanks). 1.0 = no-op.
		if (isNil "WFBE_C_AICOM_DISMOUNT_BIAS") then {WFBE_C_AICOM_DISMOUNT_BIAS = 1.6};
		//--- B756 MOUNT seat-capacity gate: only GROUND MOUNT-UP / re-mount a team if its ride pool can seat at least this FRACTION of the squad. A partial mount splits the team (the APC drives off, the foot element strands -> ASSAULT_STRANDED). Below this the team stays foot-cohesive (the hull paces the group road-march). 0 = old behaviour (always partial-mount).
		if (isNil "WFBE_C_AICOM_MOUNT_MIN_SEAT_FRAC") then {WFBE_C_AICOM_MOUNT_MIN_SEAT_FRAC = 0.8};
		//--- B756 NAVAL-RAID gate: naval-HVT (carrier) spearhead targets are only assigned to teams with a TRANSPORT HELI (they're offshore, only reachable by air-insertion). Ground teams never get tasked to the sea (no stranding). This makes the carriers a real - but air-only - assault objective. Gate lives in AI_Commander_AssignTowns.sqf.
		if (isNil "WFBE_C_AICOM_NAVAL_AIR_ONLY") then {WFBE_C_AICOM_NAVAL_AIR_ONLY = 1};
	//--- A/B EXPERIMENT (legacy-vs-next): arm label + sim-gating switch. LEGACY arm = control (gating off).
	if (isNil "WFBE_C_AB_ARM") then {WFBE_C_AB_ARM = "NEXT-T1c"};
	//--- Steff 2026-06-13: the AI must NOT be able to use artillery. Forced off (not a default)
	//--- so no param/override can enable it - blocks both the fire-mission worker AND building base guns.
	WFBE_C_AI_COMMANDER_ARTILLERY = 0;
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
	WFBE_C_AI_COMMANDER_SPEARHEAD_PER_TOWN = 3;   //--- V0.5: teams concentrated per spearhead town (legacy/fallback quota; per-tier quota below overrides).
	//--- V0.8 COHERENT FRONT (claude-gaming 2026-06-14): the old spearhead scorer was
	//--- supplyValue - dNear/150, which let a fat enemy city 8km away outscore the nearest
	//--- contestable town (STUCKSTAT distTgt=8122 = one squad sent piecemeal across the map).
	//--- The fix ranks enemy/neutral towns by NEAREST-TO-OUR-FRONT first (frontier prefilter +
	//--- distance-dominant score) with a small pull toward the enemy HQ, so the army advances as
	//--- a wave onto achievable nearby objectives instead of cherry-picking the enemy's rear.
	if (isNil "WFBE_C_AICOM_FRONTIER_RADIUS") then {WFBE_C_AICOM_FRONTIER_RADIUS = 3000};   //--- m: a candidate town is "on the front" if it is within this distance of one of OUR owned towns (fallback: our HQ). Towns past this are deprioritised, not banned (guardrail: still targetable if the front is empty).
	if (isNil "WFBE_C_AICOM_DISTANCE_DIVISOR") then {WFBE_C_AICOM_DISTANCE_DIVISOR = 50};   //--- score divisor on distance-to-front: one supply point is worth this many metres of march. Was effectively 150 (too weak); 50 makes distance dominate so the nearest contestable town wins.
	if (isNil "WFBE_C_AICOM_HQ_PULL_DIVISOR") then {WFBE_C_AICOM_HQ_PULL_DIVISOR = 250};    //--- score divisor on distance-to-ENEMY-HQ: adds a small spearhead bias toward the enemy capital so the front advances in one direction instead of wandering. Larger = weaker pull. 0 disables the pull.
	if (isNil "WFBE_C_AICOM_FAR_PENALTY") then {WFBE_C_AICOM_FAR_PENALTY = 1000};           //--- flat score penalty applied to any candidate OUTSIDE the frontier radius, so a rich deep city can no longer buy its way over a near contestable town. Large enough to swamp supply spread.
	if (isNil "WFBE_C_AICOM_SOFT_WEIGHT")  then {WFBE_C_AICOM_SOFT_WEIGHT  = 12};            //--- A8: score points SUBTRACTED per garrison hardness tier (wfbe_town_type Tiny=0..Huge=4) so at comparable distance the AI prefers SOFTER towns. Full swing ~48pts (~2.4 town-spacings at DISTANCE_DIVISOR=50); under FAR_PENALTY so front-contiguity is unaffected. 0 = rollback to distance-only.
	if (isNil "WFBE_C_AICOM_VALUE_DIVISOR") then {WFBE_C_AICOM_VALUE_DIVISOR = 50};           //--- A8: divisor on the (previously dead) per-town wfbe_town_value (100..1000) -> 2..20 pts; rewards rich towns at comparable distance. Larger = weaker. Clamped to 1 if <=0.
	//--- F5 NEAR-BAND BONUS: if the candidate town is within WFBE_C_AICOM_NEAR_BAND_DIST metres of our nearest
	//--- owned town, add a flat score bonus to boost near-front objectives relative to equally-close but
	//--- higher-supply-value towns further back. Gate flag 0 = inert (default; owner flips to 1 to enable).
	if (isNil "WFBE_C_AICOM_NEAR_BAND") then {WFBE_C_AICOM_NEAR_BAND = 1};                    //--- cmdcon43 Ray-approved flip-ON (near-band bonus): 1 = near-band bonus active, 0 = inert.
	if (isNil "WFBE_C_AICOM_NEAR_BAND_DIST") then {WFBE_C_AICOM_NEAR_BAND_DIST = 2000};       //--- m: candidate must be within this distance of our nearest owned town to earn the bonus.
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
	//--- Ships default-OFF (dark) so Ray can enable + tune the thresholds in soak. AI-commander build logic ONLY; humans unaffected.
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
	if (isNil "WFBE_C_AICOM2_EXPAND_TEAMS")    then {WFBE_C_AICOM2_EXPAND_TEAMS    = 3};  //--- Ray 2026-06-28: up to N teams divert to capture the nearest reachable NEUTRAL town instead of all-in on the fist (issue: 42/46 towns sat neutral). 0 = off (restores fist-only).
	if (isNil "WFBE_C_AICOM_ENGAGE_MIN_TOWNS") then {WFBE_C_AICOM_ENGAGE_MIN_TOWNS = 10};//--- Ray 2026-06-28 EXPANSION-FIRST: a commander captures NEUTRAL towns only (fist+harass) until it OWNS this many towns, THEN it attacks the enemy - so both sides build an empire before they clash (no early enemy-rush that ends matches premature). ANTI-STALL: if no neutral town remains reachable it engages the enemy anyway. Round-ender HQ-strike keeps its own higher gate (WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS). 0 = disable (engage from turn one).
	if (isNil "WFBE_C_AICOM_CONCENTRATE_TOWNS") then {WFBE_C_AICOM_CONCENTRATE_TOWNS = 4};//--- Ray 2026-06-28 CONCENTRATE-FIRST: while a commander owns FEWER than this many towns it puts its FULL strength on ONE fist town (no expand/harass split) - a true opening steamroller. Once it owns this many, the normal expand(EXPAND_TEAMS)+harass spread resumes. 0 = off (spread from town one).
	if (isNil "WFBE_C_AICOM_DISBAND_LOWTIER_ENABLE") then {WFBE_C_AICOM_DISBAND_LOWTIER_ENABLE = 1};//--- Ray 2026-06-28: retire idle rear FOOT-infantry teams once the side fields mobile (light/heavy/air) teams - keeps force modern + frees pop/group cap for armour. 0 = off.
	if (isNil "WFBE_C_AICOM_DISBAND_INTERVAL") then {WFBE_C_AICOM_DISBAND_INTERVAL = 300};//--- seconds between disband passes (at most ONE team retired per pass) - long for immersion.
	if (isNil "WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR") then {WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR = 2};//--- never disband below this many FOOT teams/side (keep a footprint). 3->2: with the 8-team cap a side rarely holds >3 foot teams so disband never fired.
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
		//--- WFBE_C_AI_COMMANDER_ARTILLERY (which Steff hard-locks to 0 so the AI can neither fire nor BUILD artillery). When
		//--- this is >0 the player request is accepted by the handler and serviced by the assist-mode resolver
		//--- (WFBE_SE_FNC_AI_Com_PlayerArty), which only ever fires friendly artillery pieces that ALREADY exist on the map -
		//--- it never builds guns - so enabling it does NOT reopen the AI's autonomous-artillery behaviour. Default 0 (off):
		//--- with no base guns built (Steff lock) the order is a no-op, so it ships dark and safe until a build adds guns.
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
	if (isNil "WFBE_C_AICOM_SPAWNBEACON_ENABLE")   then {WFBE_C_AICOM_SPAWNBEACON_ENABLE   = 1};    //--- 0 = INERT (feature fully off), 1 = arm the forward-ambulance beacon worker.
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
	if (isNil "WFBE_C_AICOM_AUTOFLIP") then {WFBE_C_AICOM_AUTOFLIP = 1};                   //--- Build84 (Ray, ON): auto-right flipped AICOM ground vehicles on server/HC (Marty AutoFlip thresholds; only when flipped+stuck). 0 = off.
	if (isNil "WFBE_C_AICOM_SPAWN_ON_ROADS") then {WFBE_C_AICOM_SPAWN_ON_ROADS = 1};       //--- Build84: snap AICOM factory-produced unit spawn to nearest road within SPAWN_ROAD_RADIUS of the factory pad. 0 = pre-Build84 pad behaviour.
	if (isNil "WFBE_C_AICOM_SPAWN_ROAD_RADIUS") then {WFBE_C_AICOM_SPAWN_ROAD_RADIUS = 60};//--- Build84: nearRoads search radius (m) for the AICOM road-spawn snap.
	if (isNil "WFBE_C_AICOM_FOUND_REQUIRE_FACTORY") then {WFBE_C_AICOM_FOUND_REQUIRE_FACTORY = 0}; //--- Build84 (ships OFF - founding-starvation safety): 1 = only found a team type whose matching factory the side owns (no HQ 'magic' fallback); 0 = current HQ-fallback allowed.
	if (isNil "WFBE_C_AICOM_PATROL_UNSTUCK_MAX") then {WFBE_C_AICOM_PATROL_UNSTUCK_MAX = 5}; //--- Build84: after N consecutive side-patrol wedges, drop target + re-pick a different frontline town (anti-orbit).
	if (isNil "WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS") then {WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS = 250}; //--- Build84: 'at target' radius (m) for assault-arrive / uncapturable-abandon logic (was getVariable-default-only).
	if (isNil "WFBE_C_AICOM_AIR_LATE_MINS") then {WFBE_C_AICOM_AIR_LATE_MINS = 45};        //--- Build84 (Ray): mission minute at/after which 'late game' air scaling applies.
	if (isNil "WFBE_C_AICOM_AIR_MAX_LATE") then {WFBE_C_AICOM_AIR_MAX_LATE = 7};           //--- Build84 (Ray): late-game total air cap (early game stays WFBE_C_AICOM_AIR_MAX_TOTAL=3).
	if (isNil "WFBE_C_AICOM_HELI_SHARE_LATE") then {WFBE_C_AICOM_HELI_SHARE_LATE = 0.55};  //--- Build84 (Ray): late-game target helicopter share of AICOM air (~55% helis, rest planes). 0 = restore Build83.
	//--- === cmdcon37 AI-behaviour fixes (claude-gaming overnight 2026-07-02) ===
	if (isNil "WFBE_C_AICOM_CAMP_GATE_MODE2") then {WFBE_C_AICOM_CAMP_GATE_MODE2 = 1};        //--- cmdcon37 (afraid-of-camps): in AllCamps mode (WFBE_C_TOWNS_CAPTURE_MODE=2) hold + aggressively clear a town's camps instead of bailing to a depot that can't flip. 0 = old bail behaviour.
	if (isNil "WFBE_C_AICOM_STALL_ADVANCE_SECS") then {WFBE_C_AICOM_STALL_ADVANCE_SECS = 420}; //--- cmdcon37 (never-stand floor): if a team is parked at a town > this many s with no flip/progress, blacklist it + retarget to the nearest OTHER enemy town same tick (bypasses the strike ladder that rarely accrues live). 0 = off. cmdcon38: 240 -> 420 so it no longer preempts a full travel(~60s)+drain-wait-hold(360s) capture attempt (the WAVE-2 DRAIN-WAIT fix in Common_RunCommanderTeam now holds up to _holdEnd to finish a slow drain); this stays the backstop for genuinely-stuck teams.
	//--- === cmdcon41 wave-1 (claude-gaming 2026-07-02): SPREAD+HOLD, real-combat base assault (Ray: ON), siege decay, remnant caution ===
	if (isNil "WFBE_C_AICOM_SPREAD_MODE")            then {WFBE_C_AICOM_SPREAD_MODE = 1};            //--- anti-dogpile: cap teams per fist town in the Allocator (0 = legacy uncapped pile-up).
	if (isNil "WFBE_C_AICOM2_FIST_PERTOWN")          then {WFBE_C_AICOM2_FIST_PERTOWN = 4};          //--- max teams the Allocator stacks on one fist town before spilling to the next.
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
	if (isNil "WFBE_C_AICOM_LOSING_PRESS")            then {WFBE_C_AICOM_LOSING_PRESS = 1};            //--- losing-side aggression floor: behind on towns + near strength parity + base safe -> minimum PRESS (never park in DEFEND).
	if (isNil "WFBE_C_AICOM_WITHDRAW_EVAL")           then {WFBE_C_AICOM_WITHDRAW_EVAL = 1};           //--- graceful-withdrawal evaluator: bleeding HC teams get a "rally" order to the nearest own HQ/town (Ray: reinforce at friendly towns).
	if (isNil "WFBE_C_AICOM_WITHDRAW_MIN_ALIVE")      then {WFBE_C_AICOM_WITHDRAW_MIN_ALIVE = 3};      //--- alive-count floor that triggers the withdrawal (MBT/attack-heli teams exempt).
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE")            then {WFBE_C_AICOM_STRIKE_STAGE = 1};            //--- HQ-strike staging: mass strikers at a rally short of the enemy HQ, then hit together.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_BODIES")     then {WFBE_C_AICOM_STRIKE_STAGE_BODIES = 14};    //--- staged bodies required before release.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_TIMEOUT")    then {WFBE_C_AICOM_STRIKE_STAGE_TIMEOUT = 240};  //--- s: release with whatever is staged (never deadlock).
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_DIST")       then {WFBE_C_AICOM_STRIKE_STAGE_DIST = 800};     //--- m short of the enemy HQ where the staging rally sits.
	if (isNil "WFBE_C_AICOM_STRIKE_STAGE_ARRIVE")     then {WFBE_C_AICOM_STRIKE_STAGE_ARRIVE = 400};   //--- m: a striker within this of the rally counts as staged.
	if (isNil "WFBE_C_AICOM_JOURNEY_COMMIT")          then {WFBE_C_AICOM_JOURNEY_COMMIT = 1};          //--- never retarget a team that is closing on its town (progress >= 150m since dispatch).
	if (isNil "WFBE_C_AICOM_STRIKE_COMMIT") then {WFBE_C_AICOM_STRIKE_COMMIT = 0}; //--- 0=current (any towns-mode team is strike-grabbable); 1=a PROGRESSING team (open dispatch + progress>=150m + target still enemy) is skipped for the HQ strike-grab so an active journey is not killed. Exempts recycle-flagged + genuinely-stuck teams.
	if (isNil "WFBE_C_AICOM_LADDER_DECAY")            then {WFBE_C_AICOM_LADDER_DECAY = 1};            //--- stuck-strike ladder decays (-1) on progress instead of resetting to 0 (wedgers eventually reach tier-3 recovery).
	if (isNil "WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE") then {WFBE_C_AICOM_FAILED_JOURNEYS_RECYCLE = 6}; //--- a team with this many failed journeys since its last arrival is recycled (combat- and player-guarded).
	if (isNil "WFBE_C_AICOM_SVC_ALLTEAMS")            then {WFBE_C_AICOM_SVC_ALLTEAMS = 1};            //--- service/refit admits understrength INFANTRY teams too (was armour-only). Headcount-gated.
	if (isNil "WFBE_C_AICOM_TOPUP_UNIT_COST")         then {WFBE_C_AICOM_TOPUP_UNIT_COST = 300};       //--- funds charged per replacement infantryman at a rally top-up.
	if (isNil "WFBE_C_AICOM_TOPUP_COOLDOWN")          then {WFBE_C_AICOM_TOPUP_COOLDOWN = 240};        //--- s between top-ups per team.
	if (isNil "WFBE_C_AICOM_TOPUP_HUMAN_MULT")        then {WFBE_C_AICOM_TOPUP_HUMAN_MULT = 0.25};     //--- cmdcon42 (Ray, TOPUP Option B): refit-cost multiplier while a HUMAN holds the commander seat (heavily discounted - the player commander gets no kill income from his squads). AI commander pays full (1). 1 = no discount.
	//--- cmdcon41-w3d COMMAND-MENU V2: new steering verbs (RALLY/REFIT/HOLD) + non-commander REQUEST-AI-SUPPORT nudge.
	if (isNil "WFBE_C_CMD_MENU_V2")                    then {WFBE_C_CMD_MENU_V2 = 1};                   //--- master flag for the cmdcon41-w3d command-menu additions (steering verbs, nudge, UnitCamera guard). 0 = off.
	if (isNil "WFBE_C_CMD_NUDGE_COOLDOWN")            then {WFBE_C_CMD_NUDGE_COOLDOWN = 180};          //--- s per-player cooldown on the non-commander "REQUEST AI SUPPORT" nudge.
	if (isNil "WFBE_C_CMD_NUDGE_RANGE")              then {WFBE_C_CMD_NUDGE_RANGE = 1500};            //--- m max distance a nudged AI team may be from the requesting player.
	//--- cmdcon42-o ENEMY-BASE INTEL-LEAK CLAMP (Ray 2026-07-02): the war-room roster + AI-objective marker must not reveal the hidden enemy HQ when your squads push it (HQ-strike / base-assault order destinations). Producer-side: any RENDERED order destination within HQ_RADIUS of an ENEMY side's HQ is clamped to the nearest enemy-held town ("(advancing)"), never the true base pin. The team's real movement destination is untouched (recon-by-presence still works).
	if (isNil "WFBE_C_CMD_INTEL_SANITIZE")            then {WFBE_C_CMD_INTEL_SANITIZE = 1};            //--- 1 = clamp order-destination DISPLAY surfaces near the enemy base; 0 = legacy (show true destination).
	if (isNil "WFBE_C_CMD_INTEL_HQ_RADIUS")           then {WFBE_C_CMD_INTEL_HQ_RADIUS = 800};         //--- m: a rendered order destination within this of an ENEMY HQ is clamped to the nearest enemy-held town.
	if (isNil "WFBE_C_AICOM_ECON_SINK")               then {WFBE_C_AICOM_ECON_SINK = 1};               //--- Ray: convert capped funds into pressure - dep-respecting research + team-cap surge + heavier draws.
	if (isNil "WFBE_C_AICOM_ECON_SINK_FRAC")          then {WFBE_C_AICOM_ECON_SINK_FRAC = 0.85};       //--- rich threshold as a fraction of the wealth cap.
	if (isNil "WFBE_C_AICOM_ECON_SINK_TEAMCAP")       then {WFBE_C_AICOM_ECON_SINK_TEAMCAP = 2};       //--- extra founding target while rich (still under the hard cap).
	if (isNil "WFBE_C_AICOM_ECON_SINK_HUMAN_OFF")     then {WFBE_C_AICOM_ECON_SINK_HUMAN_OFF = 1};     //--- cmdcon42 (Ray): 1 = pause the econ-sink (surge + auto-research/spend) whenever a HUMAN sits in the commander slot, even under AICOM_LOCK. 0 = legacy (sink runs regardless).
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
	if (isNil "WFBE_C_NAVAL_TWIN_HULLS")              then {WFBE_C_NAVAL_TWIN_HULLS = 1};              //--- Khe Sanh: outer carriers become deck-bridged TWIN-HULL super-carriers (middle keeps the SCUD, single hull).
	if (isNil "WFBE_C_NAVAL_WEST_AAV")                then {WFBE_C_NAVAL_WEST_AAV = 0};                //--- Lane 45: default-off WEST AAV buy-row metadata hook for future naval-map beach-assault work.
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
	if (isNil "WFBE_C_ICBM_TEL_RAIN_COST")            then {WFBE_C_ICBM_TEL_RAIN_COST = 9000};          //--- STEEL RAIN price.
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
	if (isNil "WFBE_C_TK_SCUD_HF")                    then {WFBE_C_TK_SCUD_HF = 1};                     //--- master: producible SCUD at HF on Takistan (all behaviour also worldName-gated to "Takistan").
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
	if (isNil "WFBE_C_SKINSEL")                       then {WFBE_C_SKINSEL = 1};                       //--- cmdcon41-w3l: skin selector master (WF-menu SKIN button + first-spawn dialog + respawn restore). Legacy WFBE_C_SKIN_SELECTOR still honored as an OR.
	if (isNil "WFBE_C_SKINSWAP_FUNDS_CARRY")          then {WFBE_C_SKINSWAP_FUNDS_CARRY = 1};          //--- cmdcon43-h: carry the player's wfbe_funds + wfbe_side across a skin swap so a failed rejoin (fresh/diverted/CIV group) never orphans his wallet to $0 (LIVE-confirmed cmdcon42b). 1 on, 0 off.

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
	//--- AICOM SELF-SERVICE (B48, default OFF; ships dark for A/B). A damaged/low-ammo team detours to the nearest SAFE friendly town-centre, repairs+rearms+heals via the player primitives, then returns. See Common_AICOMServiceTick.sqf.
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
	if (isNil "WFBE_C_AICOM_HC_MERGE_ENABLE") then {WFBE_C_AICOM_HC_MERGE_ENABLE = 0};   //--- 1 = ON, 0 = off (default; ships dark).
	if (isNil "WFBE_C_AICOM_HC_TOPUP_ENABLE") then {WFBE_C_AICOM_HC_TOPUP_ENABLE = 1};   //--- B74 (Ray 2026-06-22): refill attrited HC field teams - Produce skips live HC teams so they bleed to 1-2-man remnants and never recover. When on, the commander ships replacement bodies to under-strength HC teams (charged to AI funds). 1=on.
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
	WFBE_C_CAMPS_RANGE = 11.5;  //--- B74.2 (Ray 2026-06-23): 10 -> 11.5 (+15%). Widens the AI camp capture bubble so it registers the presence-based flip instead of orbiting the tight 10m ring (Ray: let the AI capture camps easier + not get stuck on them). PLAYERS are UNCHANGED - WFBE_C_CAMPS_RANGE_PLAYERS (below) still gates them at 5m (server_town_camp.sqf:29 filters players past that).
	WFBE_C_CAMPS_RANGE_PLAYERS = 5;
	if (isNil "WFBE_C_TOWN_CAMP_SCAN_THROTTLE") then {WFBE_C_TOWN_CAMP_SCAN_THROTTLE = 0}; //--- Lane 107: default off; when 1, server_town_camp uses the slower scan sleeps below.
	if (isNil "WFBE_C_TOWN_CAMP_STEP_SLEEP") then {WFBE_C_TOWN_CAMP_STEP_SLEEP = 0.03}; //--- Per-camp sleep while scan throttle is enabled.
	if (isNil "WFBE_C_TOWN_CAMP_LOOP_SLEEP") then {WFBE_C_TOWN_CAMP_LOOP_SLEEP = 0.25}; //--- Full-pass sleep while scan throttle is enabled.
	//--- Commander stuck-reaction (Slot 2, task #14): the AssignTowns breadcrumb re-issues a
	//--- parked team's order. Was hardcoded 600s (10min) = stalemate-slow. Now config-driven.
	if (isNil 'WFBE_C_AICOM_STUCK_SECS')  then {WFBE_C_AICOM_STUCK_SECS  = 210};
	if (isNil 'WFBE_C_AICOM_STUCK_MOVED') then {WFBE_C_AICOM_STUCK_MOVED = 200};
	if (isNil 'WFBE_C_AICOM_STUCK_FAR')   then {WFBE_C_AICOM_STUCK_FAR   = 300};
	//--- ASSAULT TELEMETRY (task #48, #2): dispatch->arrival watcher thresholds (AssignTowns Hook B).
	//--- ARRIVE_RADIUS 250m ~= town SAD radius (AIMoveTo uses 200) + leader margin to count "at the town".
	//--- TIMEOUT 420s = ~2x the 120s worker interval beyond STUCK_SECS(210) so a team gets ~3 watcher
	//--- passes before being declared stranded; this is the dispatch->arrival budget, not the stuck-reissue.
	if (isNil 'WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS') then {WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS = 250};
	if (isNil 'WFBE_C_AICOM_ASSAULT_TIMEOUT')       then {WFBE_C_AICOM_ASSAULT_TIMEOUT       = 420};
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
	if (isNil "WFBE_C_CMD_DEF_SUPPLY") then {WFBE_C_CMD_DEF_SUPPLY = 1};
	//--- EXPERITAL: boosted starting economy (Steff, play-test 2026-06-10; baseline 800/1200;
	//--- doubled to 1600/2400, +10k/+5k on 06-10, +20k cash/+3k supply on 06-11 - restart compensation)
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_WEST") then {WFBE_C_ECONOMY_FUNDS_START_WEST = if (WF_Debug) then {900000} else {30000}};
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_EAST") then {WFBE_C_ECONOMY_FUNDS_START_EAST = if (WF_Debug) then {900000} else {30000}};
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_GUER") then {WFBE_C_ECONOMY_FUNDS_START_GUER = if (WF_Debug) then {900000} else {20000}};
	//--- B36 hotfix (Ray 2026-06-15): AI commander starts with a flat 200k cash (was FUNDS_START x FUNDS_MULT ~=45k); it runs the whole side. Players start with 30k.
	if (isNil "WFBE_C_AI_COMMANDER_START_FUNDS") then {WFBE_C_AI_COMMANDER_START_FUNDS = 200000}; //--- B67 (Ray 2026-06-21): RESTORED to 200000 (cash-rich directive). The earlier 60k trim was counterproductive - START_FUNDS cannot prepay un-unlocked tech (tech is interval-gated at 300s, money-independent), it only fuels UNIT FIELDING, which Ray now wants maximised. CASH only; never supply.
	if (isNil "WFBE_C_ECONOMY_INCOME_INTERVAL") then {WFBE_C_ECONOMY_INCOME_INTERVAL = 60}; //--- Income Interval (Delay between each paycheck).
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
	WFBE_C_ECONOMY_INCOME_COEF = 14; //--- B67 (Ray 2026-06-21): 8->14. Boost town-driven CASH income ~1.75x (CASH path only: updateresources.sqf:60->95; the SUPPLY credit at :76 uses WFBE_C_ECONOMY_SUPPLY_INCOME_MULT and is UNCHANGED). Town Multiplicator Coefficient (SV * x).
	WFBE_C_ECONOMY_SUPPLY_INCOME_MULT = 1.0; //--- Ray 2026-06-29 FULL SV-INCOME PARITY: un-throttle ongoing town SUPPLY income to stock 1.0. The credit is SIDE-WIDE (updateresources.sqf:87; funds AI + human commanders + GUER equally - see L420), so 1.0 gives AI commanders the same full supply SV income a human commander's economy gets (there was never an AI-specific handicap - the throttle hit everyone). Supersedes the B57 progression-throttle (0.35->0.5): the funds->supply bridge that made throttling safe is gone, research + factory-rebuild are now SUPPLY-ONLY, and 0.35/0.5 was starving the AI (live no-affordable-upgrade RPT: needed 9500 supply with ~1650 banked). NOTE: founding/research/structure costs were tuned against 0.35 (see L593) -> economy now runs ~2-3x faster; review costs if the AI over-builds. Cash/funds + starting-supply seed UNCHANGED (Ray: cash=units, supply=buildings+upgrades).
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
	BLINKING_VEHICLES_WEST = [];
	BLINKING_VEHICLES_EAST = [];

//--- cmdcon43-b (Build 88): BIG-MAP FPS - marker RENDER-pass mitigation. The consolidated marker loop
//--- (Common\Common_MarkerLoop.sqf) gates identically on any map consumer, so the script load is the same
//--- whether the player has the full-screen map (M) or a menu minimap open. The difference is the ENGINE
//--- marker render pass: the big map draws every registered own-side unit marker + its TEXT label at wide
//--- zoom (150-400 at peak), a menu minimap draws a handful. These flags cut the render + churn cost.
//--- Each is INDEPENDENTLY toggleable and default-safe; both maps read the same constants (mirrored to TK).
	if (isNil "WFBE_C_MARKER_MOVE_INPLACE") then {WFBE_C_MARKER_MOVE_INPLACE = 1};      //--- 1: refresh nudges marker pos/dir/text in place (setMarker*Local) instead of delete+recreate on the rebuild path. 0: legacy delete+recreate. Cheapest win; no visible change.
	if (isNil "WFBE_C_MARKER_LABEL_CULL") then {WFBE_C_MARKER_LABEL_CULL = 1};          //--- 1: when registered unit markers exceed the threshold, blank the TEXT on bulk unit markers (keep HQ/own-team/named); restore under threshold. Text draw is the expensive part of the A2 marker pass. 0: never cull.
	if (isNil "WFBE_C_MARKER_LABEL_CULL_THRESHOLD") then {WFBE_C_MARKER_LABEL_CULL_THRESHOLD = 120}; //--- Registered-unit-marker count at/above which label culling engages (hysteresis-guarded in the loop).
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
	WFBE_C_GAMEPLAY_VOTE_TIME = if (WF_Debug) then {3} else {40};
	if (isNil "WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC") then {WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC = 0}; //--- Default-off: publish stealth-engine stopped state across locality changes; 0 keeps legacy local vehicle state.
	if (isNil "WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL") then {WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL = 0}; //--- Default-off: show the already-recorded GUER endgame stats as a third stats-panel column.
	if (isNil "WFBE_C_FIX_VOTE_LIST_PRUNE") then {WFBE_C_FIX_VOTE_LIST_PRUNE = 0}; //--- Default-off: safer vote-dialog live-team row prune (reverse pass + stale index guard). 0 = legacy forward delete behaviour.
	if (isNil "WFBE_C_FIX_VOTE_QA_EXECUTION") then {WFBE_C_FIX_VOTE_QA_EXECUTION = 0}; //--- Default-off: vote QA follow-up fixes for stored-index row color and commander primitive placeholder confirms.

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
if (WF_A2_Vanilla) then {
		WFBE_C_BASE_COIN_DISTANCE_MIN = 8;
		WFBE_C_BASE_COIN_GRADIENT_MAX = 4;
} else {
		WFBE_C_BASE_COIN_DISTANCE_MIN = 100;
		WFBE_C_BASE_COIN_GRADIENT_MAX = 4;
};

//--- Towns.
	if (isNil "WFBE_C_TOWNS_AMOUNT") then {WFBE_C_TOWNS_AMOUNT = 7}; //--- Amount of towns (0: Very small, 1: Small, 2: Medium, 3: Large, 4: Full).
	if (isNil "WFBE_C_TOWNS_BUILD_PROTECTION_RANGE") then {WFBE_C_TOWNS_BUILD_PROTECTION_RANGE = 450}; //--- Prevent construction in towns within that radius.
	if (isNil "WFBE_C_TOWNS_CAPTURE_MODE") then {WFBE_C_TOWNS_CAPTURE_MODE = 0}; //--- A/B (claude-gaming 2026-06-14): 2->0 Classic. Mode 2 "All Camps" required an attacker to hold EVERY camp simultaneously with dismounted infantry (server_town.sqf:169-177) - AI commander teams arrive mounted + visit camps sequentially, so capDis=0 and only GUER (garrison stands on all camps) ever flipped towns. Mode 0 flips on defender-clear + presence within 40m; camps become a capture-SPEED bonus, not a gate. GUER unchanged (still defends/caps by presence). Reversible: revert to 2, or try 1 (Threshold/140m majority) if towns flip too fast. (0: Normal/Classic, 1: Threshold, 2: All Camps).
	if (isNil "WFBE_C_TOWNS_DEFENDER") then {WFBE_C_TOWNS_DEFENDER = 2}; //--- Town defender Difficulty (0: Disabled, 1: Light, 2: Medium, 3: Hard, 4: Insane).
	if (isNil "WFBE_C_TOWNS_OCCUPATION") then {WFBE_C_TOWNS_OCCUPATION = 2}; //--- Town occupation Difficulty (0: Disabled, 1: Light, 2: Medium, 3: Hard, 4: Insane).
	if (isNil "WFBE_C_TOWNS_GEAR") then {WFBE_C_TOWNS_GEAR = 1}; //--- Buy Gear From (0: None, 1: Camps, 2: Depot, 3: Camps & Depot).
	if (isNil "WFBE_C_TOWNS_PATROLS") then {WFBE_C_TOWNS_PATROLS = 6}; //--- Town-to-town patrols ON by default (up to 6 towns); set 0 in the lobby to disable. DR-57 fix makes them work.
	if (isNil "WFBE_C_WAYPOINT_WATER_RETRY_CAP") then {WFBE_C_WAYPOINT_WATER_RETRY_CAP = 0}; //--- Max random waypoint water rerolls before falling back to the patrol center; 0 keeps legacy uncapped retries.
	if (isNil "WFBE_C_TOWNS_REINFORCEMENT_DEFENDER") then {WFBE_C_TOWNS_REINFORCEMENT_DEFENDER = 0}; //--- Enable towns defender reinforcement.
	if (isNil "WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION") then {WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION = 0}; //--- Enable towns occupation reinforcement.
	if (isNil "WFBE_C_TOWNS_STARTING_MODE") then {WFBE_C_TOWNS_STARTING_MODE = 0}; //--- Town starting mode (0: Resistance, 1: 50% blu, 50% red, 2: Nearby Towns, 3: Random).
	if (isNil "WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER") then {WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER = 1}; //--- Lock the vehicles of the defender side.

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
	if (isNil "WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW") then {WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW = 60}; //--- Seconds where a damaged vehicle can still award its last valid hitter.
	if (isNil "WFBE_C_UNITS_CLEAN_TIMEOUT") then {WFBE_C_UNITS_CLEAN_TIMEOUT = 60}; //--- Lifespan of a dead body.
	if (isNil "WFBE_C_UNITS_EMPTY_TIMEOUT") then {WFBE_C_UNITS_EMPTY_TIMEOUT = 1800}; //--- Lifespan of an empty vehicle (30 minutes).
		WFBE_C_UNITS_BODIES_TIMEOUT = 60;
	//--- qol-polish-pack tunables --------------------------------------------------------------------------------
	if (isNil "WFBE_C_UNITS_BODIES_PROX")      then {WFBE_C_UNITS_BODIES_PROX = 20};       //--- m: hold a corpse's deletion while a player is this close (capped at +1 timeout so a camper can't pin it forever). 0 = off (vanilla).
	if (isNil "WFBE_C_STRUCTURES_FLAT_CHECK")  then {WFBE_C_STRUCTURES_FLAT_CHECK = 0};    //--- cmdcon34: DISABLED (0). The player flat-gate over-blocked base placement on mountainous Takistan (structures red -> HQ red -> factories only <10m from HQ). Reverts to pre-Build-81 freedom; the server places structures fine on any ground. Re-enable with a Takistan-tuned gradient later if wanted.
	if (isNil "WFBE_C_STRUCTURES_FLAT_RADIUS") then {WFBE_C_STRUCTURES_FLAT_RADIUS = 10};  //--- isFlatEmpty footprint radius (m).
	if (isNil "WFBE_C_STRUCTURES_FLAT_GRAD")   then {WFBE_C_STRUCTURES_FLAT_GRAD = 2};     //--- isFlatEmpty max gradient (lower = stricter; matches the AI commander's lenient value). cmdcon32: 0.5 -> 2 (0.5 over-blocked player placement on mountainous Takistan - everything red).
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
		"TIP: Build 88 command verbs are live - use PUSH/HOLD/SPREAD, RALLY, REFIT and REQUEST AI SUPPORT from the command menu.",
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
	WFBE_C_STRUCTURES_ARTILLERYRADAR = 1; // Artillery Radar buildable structure (WDDM walled-gate walls, fort-only by design)
	WFBE_C_STRUCTURES_RESERVE = 1;        // Reserve buildable structure (WDDM floodlit walled-yard walls)
	WFBE_C_UNITS_REDEPLOYTRUCK = 1;       // Medic redeployment truck (forward spawn)
	WFBE_C_SUPPORT_REARM_PROPORTIONAL = 1; //--- Rearm price scales with ammo actually missing (arty exempt)
	WFBE_C_UNITS_BULLDOZER = 1;           //--- Engineer base-area tree clearing
	WFBE_C_DEFENSE_BUDGET = 1;            // Per-base-area defense caps scaling with barracks level
	WFBE_C_BASE_DEFENSE_STATICS_CAP = 25; // Max player-placed static base defenses (MGs/AA/AAPOD) per base area (raised from 10)
	WFBE_C_DEFENSE_THREAT_MIN = 3;        // Min enemy ground units (west/east, no Air/GUER) inside base range before the statics/mines threat gate fires
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

//--- Apply a towns unit coeficient.
	WFBE_C_TOWNS_UNITS_COEF = switch (WFBE_C_TOWNS_OCCUPATION) do {case 1: {1}; case 2: {1.5}; case 3: {2}; case 4: {2.5}; default {1}};
	WFBE_C_TOWNS_UNITS_DEFENDER_COEF = switch (WFBE_C_TOWNS_DEFENDER) do {case 1: {1}; case 2: {1.5}; case 3: {2}; case 4: {2.5}; default {1}};
	WFBE_C_TOWNS_MERGE_TARGET = 5;                //--- GROUP-COUNT REDUCTION (claude-gaming 2026-06-13): target units per CONSOLIDATED town-garrison infantry group. Server_GetTownGroups/Defender fuse the SAME infantry rosters into ~this-many-unit groups (hard cap 10) so a town spawns identical units in FEWER server group-brains (server-FPS win, gameplay-transparent). Vehicles never merged. Set to 0 to disable (instant rollback to one-group-per-template).
	if (isNil 'WFBE_C_TOWNS_MERGE_TARGET_DEFENDER') then {WFBE_C_TOWNS_MERGE_TARGET_DEFENDER = 11}; //--- GUER condense A/B (task #12, claude-gaming 2026-06-14): raised 9->11 units/group to fuse GUER garrisons harder (fewer group-brains, SAME units). Measure GUER group count + fps vs Build 28. WEST/EAST untouched (global 5).
	if (isNil 'WFBE_C_TOWNS_MERGE_CAP_DEFENDER') then {WFBE_C_TOWNS_MERGE_CAP_DEFENDER = 12};    //--- Defender-only merged-group size cap (raised from the global hardcoded 10 so the 11-target can actually flush at ~11-12; 12 = classic A2 squad max, safe for static garrison defenders).
	if (isNil 'WFBE_C_SIDE_PATROLS_MAX_DEFENDER') then {WFBE_C_SIDE_PATROLS_MAX_DEFENDER = 3};      //--- Build83 (Ray 2026-07-01): GUER (defender) side-patrol cap RAISED +2 -> 3 (effective = min(this, GUER patrol level)). [B36 2026-06-15 had 2->1: fewer GUER patrols, the survivors made deadlier (skill boost in Common_RunSidePatrol). GUER condense.
	if (isNil 'WFBE_C_GUER_PATROLS_LEVEL') then {WFBE_C_GUER_PATROLS_LEVEL = 2};                    //--- B67 (Ray 2026-06-21): fixed Patrols level for GUER (resistance has no upgrade system) so GUER side-patrols actually dispatch and show on GUER players' maps (server_side_patrols.sqf). Effective concurrent count = min(_maxSide, this). 0 = OFF (no GUER patrols, instant rollback); 1 = single; 2 = a pair; 4 adds the convoy supply truck.
	WFBE_C_GROUP_BUDGET_WARN = 120;               //--- GROUP-BUDGET ALARM (claude-gaming 2026-06-13): per-side group-count WARN threshold (GRPBUDGET line in AI_Commander.sqf). Arma 2 OA hard cap is 144/side; crossing this logs a GRPBUDGET|WARN so the watchdog/dashboard flags it before the AI can no longer found teams. (120, not 125: with the persistent-husk leak fixed, steady state should drop below 120, making the WARN a true leading indicator rather than always-on.)
	if (isNil 'WFBE_C_GROUPAUDIT_EVERY') then {WFBE_C_GROUPAUDIT_EVERY = 5}; //--- D2 server-FPS (claude-gaming 2026-06-14): run the EXPENSIVE per-faction group-classification AUDIT DUMP (server_groupsGC.sqf; auditMs ~2100ms on 276 groups) only every Nth 5-min audit window. The husk-reap GC + zombie-reap + cap-warning still run EVERY 60s cycle (they live outside the audit branch) - this throttles only diagnostic telemetry. 5 = full dump ~every 25 min instead of every 5 min. 1 = dump every window (old behavior); values < 1 are clamped to 1. Pure diagnostic throttle, no gameplay effect; instant rollback by setting to 1.
};

// --- Player stats (feature-flagged) ---
//--- B74.1 (Ray 2026-06-23 "get the real leaderboard in"): ENABLED. Unlocks the WASPSTAT|v1 RPT
//--- emit (StatsFlush.sqf, batched every 60s) that feeds the miksuu.com leaderboard ingest pipeline
//--- (box poster -> /api/stats -> ingame_stats -> /leaderboard). Currently WIRED fields: kills
//--- infantry/vehicle/air/static (RequestOnUnitKilled), pvp_kills, playtime, side. Captures/supply/
//--- builds/deaths/factory/hq RecordStat call sites are NOT yet wired (emit 0) - fast-follow b74.2.
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
//--- DELETED and the Construction_*Site hooks no longer read this flag, so it is now DEAD.
//--- Kept REGISTERED (default 0) only as a tombstone so no stale host profile forces the old ladder.
	if (isNil "WFBE_C_WALLS_V2") then {WFBE_C_WALLS_V2 = 0};

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
//--- NEEDS-BOX-VERIFY: roof-mount stability on Land_Fort_Watchtower_EP1 (per proposal B.5).
	if (isNil "WFBE_C_DEF_FLAKTOWER") then {WFBE_C_DEF_FLAKTOWER = 1};

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

["INITIALIZATION", "Init_CommonConstants.sqf: Constants are defined."] Call WFBE_CO_FNC_LogContent;

