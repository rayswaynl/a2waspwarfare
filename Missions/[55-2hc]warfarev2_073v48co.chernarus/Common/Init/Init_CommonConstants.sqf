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
if (isNil "WFBE_C_SIDE_PATROLS_MAX") then {WFBE_C_SIDE_PATROLS_MAX = 3};

/*
	### Working with the missionNamespace ###
	 * The With command allows us to swap the Global variable Namespace.
	 * It prevents the typical long variable declaration (missionNamespace setVariable...).

	In the declaration below, the parameters are first (they are checked with the isNil command).
	The isNil check prevent us from overriding MP parameters.
*/
with missionNamespace do {

//--- Day/night cycles.
	// Marty: Defaults used when mission parameters do not provide the accelerated day/night settings.
	if (isNil "WFBE_DAYNIGHT_ENABLED") then {WFBE_DAYNIGHT_ENABLED = 1}; //--- Enable the hybrid accelerated day/night cycle.
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
	if (isNil "WFBE_C_AI_COMMANDER_LOCK") then {WFBE_C_AI_COMMANDER_LOCK = 1};
	//--- ACTIVE-TOWN BUDGET: max concurrently active towns. FPS lever; 12 for the legacy-vs-next A/B (Steff 2026-06-13).
	if (isNil "WFBE_C_TOWNS_ACTIVE_MAX") then {WFBE_C_TOWNS_ACTIVE_MAX = 12}; //--- 12 (Steff 2026-06-15): testing the camp-first capture cure at FULL load - the cure lets towns get captured -> deactivate -> garrisons despawn, so 12 stays sustainable. GUER cap (60) backstops the worst case.
	//--- GUER GROUP CAP: hard ceiling on total resistance groups. Bounds runaway GUER growth toward the engine's ~144-groups/side
	//--- limit over long stalled AI-vs-AI runs (garrisons + W9 uprising + side-patrols, none of which had a global cap).
	//--- 90 is far above any single-front GUER force, well under the 144 ceiling; raise to 999 for an instant rollback.
	if (isNil "WFBE_C_GUER_GROUPS_MAX") then {WFBE_C_GUER_GROUPS_MAX = 80}; //--- perf cap: 60->80 (Steff 2026-06-15). 60 was choking garrisons above the observed ~73 peak; 80 restores headroom while staying well under the 144 engine cap. The new GUERCAP soft-cap monitor (server_groupsGC.sqf) now WARNs at 90% (=72), so if 80 gets dangerous it is visible in the RPT/dashboard. Was 90; raise to 999 for an instant rollback.
	if (isNil "WFBE_C_AI_MAX") then {WFBE_C_AI_MAX = 10}; //--- Max AI allowed on each AI groups.
	if (isNil "WFBE_C_AI_DELEGATION") then {WFBE_C_AI_DELEGATION = 0}; //--- Enable AI delegation (0: Disabled, 1: creation of ai on the client, 2: Headless Client).
	if (isNil "WFBE_C_AI_TEAMS_ENABLED") then {WFBE_C_AI_TEAMS_ENABLED = 1}; //--- Enable or disable the AI Teams.
	if (isNil "WFBE_C_AI_TEAMS_JIP_PRESERVE") then {WFBE_C_AI_TEAMS_JIP_PRESERVE = 1}; //--- Keep the AI Teams units on JIP.
	WFBE_C_AI_COMMANDER_MOVE_INTERVALS = 3600;
	WFBE_C_AI_COMMANDER_SUPPLY_TRUCKS_MAX = 5;
	//--- AI Commander revival (feat/ai-commander).
	WFBE_C_AI_COMMANDER_TOTAL_AI_MAX = 60;     //--- Per-side AI ceiling for AI-commander unit production (FPS safety cap).
	WFBE_C_AI_COMMANDER_USE_ARC_APPROACH = 1;  //--- 1: SetTownAttackPath arc approach; 0: simple AIMoveTo fallback.
	WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL = 120;
	WFBE_C_AI_COMMANDER_TOWN_INTERVAL = 120;
	WFBE_C_AI_COMMANDER_PRODUCE_INTERVAL = 45;
	WFBE_C_AI_COMMANDER_TYPES_INTERVAL = 30;
	WFBE_C_AI_COMMANDER_TICK = 15;             //--- Supervisor base tick (s); how often the order-executor runs (hybrid responsiveness).
	WFBE_C_AI_COMMANDER_BASE_INTERVAL = 60;    //--- V0.2: base worker cadence (HQ deploy -> doctrine build order -> defenses).
	WFBE_C_AI_COMMANDER_TEAMS_INTERVAL = 90;   //--- V0.2: team-founding cadence.
	WFBE_C_AI_COMMANDER_TEAMS_TARGET = 4;      //--- V0.2: AI-led combat teams the commander maintains per side.
	WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA = 2;   //--- group-budget cap 2026-06-15: dynamic (funds-scaled) extra teams capped at base+2 (=6) instead of base+4 (=8). AI_Commander_Teams.sqf:60 read this with an inline fallback of 4; the constant did not exist here. Saves up to 2 groups/side in rich-fund late-game with no base-combat-capability loss.
	WFBE_C_AI_COMMANDER_DEFENSES_MAX = 4;      //--- V0.2: manned base statics the AI places around its HQ.
	if (isNil "WFBE_C_AICOM_AIR_MIN_TOWNS") then {WFBE_C_AICOM_AIR_MIN_TOWNS = 4}; //--- Aircraft are deferred until the AI holds this many towns (it flies poorly; air is a late, established-only asset). 0 = no gate.
	//--- P1 combined-arms ratio (claude-gaming 2026-06-15): target CLASS mix for newly-typed AI teams,
	//--- [infantry, light, heavy, air]. The type picker buckets the eligible templates by class and
	//--- rolls a class against these weights; if the rolled class has NO buildable (factory+tech-unlocked)
	//--- template it falls back to a lower vehicle class and finally to infantry, so it never forces an
	//--- un-buildable type. Infantry stays the largest single share (foot are required to capture camps),
	//--- but armour/mech rise to a meaningful ~25-35% once the heavy/light factory + tier exist. Weights
	//--- need not sum to 1 (they are normalised at pick time). Was effectively ~70% infantry from the old
	//--- doctrine-only weighting; this defaults to ~65/20/12/3 of the achievable mix.
	if (isNil "WFBE_C_AICOM_TYPE_MIX") then {WFBE_C_AICOM_TYPE_MIX = [0.65, 0.20, 0.12, 0.03]};
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
		case 2:  {WFBE_C_AI_COMMANDER_FUNDS_MULT = 2.0; WFBE_C_AI_COMMANDER_INCOME_MULT = 2.0; WFBE_C_AI_COMMANDER_INCOME_STIPEND = 60};
		default  {WFBE_C_AI_COMMANDER_FUNDS_MULT = 1.5; WFBE_C_AI_COMMANDER_INCOME_MULT = 1.5; WFBE_C_AI_COMMANDER_INCOME_STIPEND = 25};
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
	//--- V0.8 FORCE CONCENTRATION: how many teams pile onto the SAME top-priority town so the
	//--- attack overwhelms the garrison, then roll forward once it flips. Replaces "one team per
	//--- distant town". The per-tier table scales the quota by garrison size (TinyTown needs ~2,
	//--- a HugeTown needs ~5). CONCENTRATION is the global base; the tier table refines per target.
	if (isNil "WFBE_C_AICOM_CONCENTRATION") then {WFBE_C_AICOM_CONCENTRATION = 3};           //--- base teams massed on the primary spearhead (used when a town's type is unknown).
	if (isNil "WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX") then {WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX = 2};//--- cap on how many DISTINCT spearhead towns the army splits across (was implicitly 5). 1-2 keeps the punch concentrated early; raises naturally is left to AssignTowns spill-over.
	//--- V0.7 bootstrap: until the side owns >= 1 town, bias target selection to the
	//--- nearest-to-base, lowest-value town so the AI captures its first income source fast.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_BIAS") then {WFBE_C_AICOM_BOOTSTRAP_BIAS = 1};         //--- 1 enable, 0 disable.
	//--- V0.7 bootstrap stipend: trickle funds+supply per supervisor tick while town count == 0.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_FUNDS") then {WFBE_C_AICOM_BOOTSTRAP_FUNDS = 100};     //--- Funds per minute (scaled to tick spacing).
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_SUPPLY") then {WFBE_C_AICOM_BOOTSTRAP_SUPPLY = 50};    //--- Supply per minute (scaled to tick spacing).
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_MAXTIME") then {WFBE_C_AICOM_BOOTSTRAP_MAXTIME = 3600};//--- Hard cutoff (s): stipend stops even if no town yet.
	//--- TASK #6 (production): funds->supply UPGRADE FALLBACK. In dual-currency every upgrade costs
	//--- ONLY supply, and supply comes only from owned towns - so a funds-rich 0-town AI can never
	//--- research Light/Heavy/Air and stays infantry-only despite its factory tier. When this rate is
	//--- > 0, Server_AI_Com_Upgrade lets the AI pay the supply price as a FUNDS surcharge (supply price
	//--- * rate) out of its war chest when supply is dry, unlocking vehicle tech. AI-commander-only;
	//--- never touches shared/human supply. Default 0 = DISABLED (no-op; preserves legacy<->next A/B
	//--- parity). Suggested enable value ~2 (per the #6 investigation). Restart-safe nil-guard.
	if (isNil "WFBE_C_AICOM_UPGRADE_FUNDS_RATE") then {WFBE_C_AICOM_UPGRADE_FUNDS_RATE = 2}; //--- ENABLED 2026-06-15: cash-rich/supply-starved AI converts funds->Light/Heavy/Air tech so OPFOR stops buying infantry-only. Set 0 to disable.
	if (isNil "WFBE_C_AICOM_SUPPLY_RESERVE") then {WFBE_C_AICOM_SUPPLY_RESERVE = 8000}; //--- raised 2026-06-15 from 500: keep an 8k SUPPLY buffer for UNIT PRODUCTION so the AI can't drain its bootstrap supply on upgrades and stop building (it routes upgrades to FUNDS below this via FUNDS_RATE). Pairs with camp-first town supply income to cure the "AI stopped producing" supply-exhaustion.
	WFBE_C_AI_COMMANDER_RELIEF_MAX = 2;           //--- V0.5: max simultaneous town-relief diversions.
	WFBE_C_AI_COMMANDER_REINFORCE_RANGE = 1200;   //--- V0.5: Produce only refills teams this close to base (wiped teams reform at base).
	WFBE_C_AICOM_FWD_REINFORCE_RANGE = 500;       //--- FORWARD-REINFORCE (claude-gaming 2026-06-13): deep teams beyond REINFORCE_RANGE may still refill if their leader hugs an owned town within this radius (fixes the deep-spearhead bleed-out / EAST snowball). Refill spawns at the factory nearest the team, so a captured forward town resupplies its own front instead of a lone unit trekking from the rear base.
	WFBE_C_AICOM_CRITICAL_STRENGTH = 0.30;        //--- RANK-2 health-gated refill (claude-gaming 2026-06-13): a server-local AI-commander team below this fraction of its template size is rushed to FULL strength in one Produce cycle (full-deficit batch), so just-founded teams form WHOLE and depleted teams stop lingering as 2-man remnants (cuts group count + drains the stuck war chest). Bounded by funds/factory/AI-cap. 0 disables.
	WFBE_C_AI_DELEGATION_FPS_INTERVAL = 60 * 3; //--- A client send it's FPS average each x seconds to the server.
	WFBE_C_AI_DELEGATION_FPS_MIN = 25; //--- A client can handle groups if it's FPS average is above x.
	WFBE_C_AI_DELEGATION_GROUPS_MAX = 1; //--- A client max have up to x groups managed on his computer (high values may makes lag, be careful).
	WFBE_C_AI_PATROL_RANGE = 400;
	WFBE_C_AI_TOWN_ATTACK_HOPS_WP = 4; //--- AI may use up to x WP to attack a town.

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
	if (isNil "WFBE_C_BASE_STARTING_MODE") then {WFBE_C_BASE_STARTING_MODE = 2}; //--- Starting Locations Mode: 0 = WN|ES; 1 = WS|EN; 2 = Random;
	//--- Egress-quality gate (A2-fix 2026-06-14): random base placement (MODE=2) can box a side into a
	//--- corner with a single egress road, stalling its AI-commander teams (empty HC route -> PFM stall).
	//--- The Init_Server start-picker requires a candidate to have >= MIN_EGRESS_ROADS usable road
	//--- segments (roadsConnectedTo>=2) within nearRoads 250 AND sit >= EDGE_MARGIN m from any map edge.
	//--- Symmetric for both sides; degrades to accept on Vanilla A2 (no roadsConnectedTo). Fallback intact.
	if (isNil "WFBE_C_BASE_MIN_EGRESS_ROADS") then {WFBE_C_BASE_MIN_EGRESS_ROADS = 3}; //--- Min usable road segments near a candidate start.
	if (isNil "WFBE_C_BASE_EDGE_MARGIN")      then {WFBE_C_BASE_EDGE_MARGIN      = 400}; //--- Min metres a candidate start must sit from any map edge.
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
	WFBE_C_CAMPS_RANGE = 10;
	WFBE_C_CAMPS_RANGE_PLAYERS = 5;
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
	if (isNil 'WFBE_C_AICOM_ASSAULT_REACH_FOOT')    then {WFBE_C_AICOM_ASSAULT_REACH_FOOT    = 3500};  //--- m: foot teams won't be sent at spearheads farther than this; pick nearest reachable town instead.
	if (isNil 'WFBE_C_AICOM_ASSAULT_REACH_MOUNTED') then {WFBE_C_AICOM_ASSAULT_REACH_MOUNTED = 9000};  //--- m: teams with a drivable vehicle may take the long leg to a far spearhead.
	//--- Careful-gear governor (owner refinement): the HC commander executor downshifts a
	//--- transit convoy from NORMAL to LIMITED only while the lead hull's surfaceNormal.z is
	//--- below this (steep slope) OR a stuck-strike is active; back to NORMAL once flat/moving.
	//--- z = cos(slope): 0.93 ~= 21.6deg, 0.90 ~= 25.8deg, 0.87 ~= 29.5deg. A2 vehicles handle
	//--- <=15deg (z>=0.966) fine; grief starts ~22-30deg. Lower = only the steepest grades slow.
	if (isNil 'WFBE_C_AICOM_SLOPE_Z')     then {WFBE_C_AICOM_SLOPE_Z     = 0.86};  //--- A2-fix 2026-06-14: was 0.93 (~21deg, too eager); 0.86 (~31deg) stops the LIMITED<->NORMAL accordion on rolling Chernarus roads
	WFBE_C_CAMPS_REPAIR_DELAY = 15;
	WFBE_C_CAMPS_REPAIR_PRICE = 500;
	WFBE_C_CAMPS_REPAIR_RANGE = 15;

//--- Economy.
	if (isNil "WFBE_C_ECONOMY_CURRENCY_SYSTEM") then {WFBE_C_ECONOMY_CURRENCY_SYSTEM = 0}; //--- 0: Funds + Supply, 1: Funds.
	//--- EXPERITAL: boosted starting economy (Steff, play-test 2026-06-10; baseline 800/1200;
	//--- doubled to 1600/2400, +10k/+5k on 06-10, +20k cash/+3k supply on 06-11 - restart compensation)
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_WEST") then {WFBE_C_ECONOMY_FUNDS_START_WEST = if (WF_Debug) then {900000} else {31600}};
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_EAST") then {WFBE_C_ECONOMY_FUNDS_START_EAST = if (WF_Debug) then {900000} else {31600}};
	if (isNil "WFBE_C_ECONOMY_FUNDS_START_GUER") then {WFBE_C_ECONOMY_FUNDS_START_GUER = if (WF_Debug) then {900000} else {20000}};
	if (isNil "WFBE_C_ECONOMY_INCOME_INTERVAL") then {WFBE_C_ECONOMY_INCOME_INTERVAL = 60}; //--- Income Interval (Delay between each paycheck).
	if (isNil "WFBE_C_ECONOMY_INCOME_SYSTEM") then {WFBE_C_ECONOMY_INCOME_SYSTEM = 3}; //--- Income System (1:Full, 2:Half (Half -> 120 SV Town = 60$ / 60SV), 3: Commander System, 4: Commander System: Full)
	if (isNil "WFBE_C_ECONOMY_SUPPLY_START_WEST") then {WFBE_C_ECONOMY_SUPPLY_START_WEST = if (WF_Debug) then {900000} else {10400}};
	if (isNil "WFBE_C_ECONOMY_SUPPLY_START_EAST") then {WFBE_C_ECONOMY_SUPPLY_START_EAST = if (WF_Debug) then {900000} else {10400}};
	if (isNil "WFBE_C_ECONOMY_SUPPLY_START_GUER") then {WFBE_C_ECONOMY_SUPPLY_START_GUER = if (WF_Debug) then {900000} else {30000}};
	if (isNil "WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT") then {WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT = if (WF_Debug) then {900000} else {40000}};
	if (isNil "WFBE_C_ECONOMY_SUPPLY_SYSTEM") then {WFBE_C_ECONOMY_SUPPLY_SYSTEM = 1}; //--- Supply System (0: Trucks, 1: Automatic with time).
	WFBE_C_ECONOMY_INCOME_COEF = 8; //--- Town Multiplicator Coefficient (SV * x).
	WFBE_C_ECONOMY_INCOME_DIVIDED = 1.2; //--- Prevent commander from being a millionaire, and add the rest to the players pool.
	WFBE_C_ECONOMY_INCOME_PERCENT_MAX = 30; //--- Commander may set income up to x%.
	WFBE_C_ECONOMY_SUPPLY_TIME_INCREASE_DELAY = 60; //--- Increase SV delay.
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

// Attack wave.
	ATTACK_WAVE_PRICE_MODIFIER = 1;
	ATTACK_WAVE_ACTIVE_WEST = false;
	ATTACK_WAVE_ACTIVE_EAST = false;

// Unit cost modifier based on the related upgrade.

	UNIT_COST_MODIFIER = 1;

//--- Environment.
	if (isNil "WFBE_C_ENVIRONMENT_MAX_VIEW") then {WFBE_C_ENVIRONMENT_MAX_VIEW = 5000}; //--- Max view distance.
	if (isNil "WFBE_C_ENVIRONMENT_MAX_CLUTTER") then {WFBE_C_ENVIRONMENT_MAX_CLUTTER = 50}; //--- Max Terrain grid.
	if (isNil "WFBE_C_ENVIRONMENT_STARTING_HOUR") then {WFBE_C_ENVIRONMENT_STARTING_HOUR = 9}; //--- Starting Hour of the day.
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
	WFBE_C_GAMEPLAY_VOTE_TIME = if (WF_Debug) then {3} else {40};

//--- Modules.
	if (isNil "WFBE_C_MODULE_BIS_PMC") then {WFBE_C_MODULE_BIS_PMC = 1}; //--- Enable PMC content.
	if (isNil "WFBE_C_MODULE_WFBE_EASA") then {WFBE_C_MODULE_WFBE_EASA = 1}; //--- Enable the Exchangeable Armament System for Aircraft.
	if (isNil "WFBE_C_MODULE_WFBE_FLARES") then {WFBE_C_MODULE_WFBE_FLARES = 1}; //--- Enable the countermeasure system (0: Disabled, 1: Enabled with upgrade, 2: Enabled).
	if (isNil "WFBE_C_MODULE_WFBE_ICBM") then {WFBE_C_MODULE_WFBE_ICBM = 1}; //--- Enable the Intercontinental Ballistic Missile call for the commander.
	if (isNil "WFBE_C_MODULE_WFBE_IRSMOKE") then {WFBE_C_MODULE_WFBE_IRSMOKE = 1}; //--- Enable the use of IR Smoke.
	if (isNil "WFBE_ICBM_TIME_TO_IMPACT") then {WFBE_ICBM_TIME_TO_IMPACT = 1}; //--- Time for ICBM to impact 
	if (isNil "WFBE_RADZONE_TIME") then {WFBE_RADZONE_TIME = 1}; //--- Time for radiation effect 

//--- Players.
	if (isNil "WFBE_C_PLAYERS_AI_MAX") then {WFBE_C_PLAYERS_AI_MAX = 16}; //--- Max AI allowed on each player groups.
	WFBE_C_PLAYERS_BOUNTY_CAPTURE = 2000;
	WFBE_C_PLAYERS_BOUNTY_CAPTURE_ASSIST = 2000;
	WFBE_C_PLAYERS_BOUNTY_CAPTURE_MISSION = 2000;
	WFBE_C_PLAYERS_BOUNTY_CAPTURE_MISSION_ASSIST = 2000;
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
	if (isNil "WFBE_C_STRUCTURES_HQ_COST_DEPLOY") then {WFBE_C_STRUCTURES_HQ_COST_DEPLOY = 100}; //--- HQ Deploy / Mobilize Price.
	if (isNil "WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED") then {WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED = 200}; //--- HQ Deploy / Mobilize Price.
	if (isNil "WFBE_C_STRUCTURES_MAX") then {WFBE_C_STRUCTURES_MAX = 3};
	WFBE_C_STRUCTURES_ANTIAIRRADAR_DETECTION = 100;
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
	if (isNil "WFBE_C_UNITS_PRICING") then {WFBE_C_UNITS_PRICING = 0}; //--- Price Focus. (0: Default, 1: Infantry, 2: Tanks, 3: Air).
	if (isNil "WFBE_C_UNITS_TOWN_PURCHASE") then {WFBE_C_UNITS_TOWN_PURCHASE = 1}; //--- Allow AIs to be bought from depots.
	if (isNil "WFBE_C_UNITS_TRACK_INFANTRY") then {WFBE_C_UNITS_TRACK_INFANTRY = 1}; //--- Track units on map (infantry).
	if (isNil "WFBE_C_UNITS_TRACK_LEADERS") then {WFBE_C_UNITS_TRACK_LEADERS = 1}; //--- Track playable Team Leaders on map (infantry).
	WFBE_C_UNITS_BOUNTY_COEF = 1; //--- Bounty is the unit price * coef.
	WFBE_C_BUILDINGS_SCORE_COEF = 3; // Score for killing base structures and HQ is building bounty * coef
	WFBE_C_UNITS_BOUNTY_ASSISTANCE_COEF = 0.5; //--- Bounty assistance is the unit price * coef * assist coef.
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
	if (isNil "WFBE_C_RESTART_ENABLED") then {WFBE_C_RESTART_ENABLED = 1};   //--- 0 disables the in-game restart announcer entirely.
	if (isNil "WFBE_C_RESTART_AT_MIN") then {WFBE_C_RESTART_AT_MIN = 90};    //--- Mission uptime (minutes) at which the scheduled restart occurs.
	if (isNil "WFBE_C_RESTART_WARN_MIN") then {WFBE_C_RESTART_WARN_MIN = 5}; //--- Start warning this many minutes out; fires exactly this many times (once per minute).
	if (isNil "WFBE_C_RESTART_MSG") then {WFBE_C_RESTART_MSG = "SERVER RESTART IN %1 MINUTE(S) - finish up and find cover."}; //--- %1 = minutes remaining.

	// === Dashboard-link announcer (claude-gaming 2026-06-14) — periodic in-game broadcast of the public live-stats URL so players know where to find updates/benchmarks. ===
	if (isNil "WFBE_C_DASHBOARD_ANNOUNCE_ENABLED") then {WFBE_C_DASHBOARD_ANNOUNCE_ENABLED = 1};    //--- 0 disables the in-game dashboard-link announcer.
	if (isNil "WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL") then {WFBE_C_DASHBOARD_ANNOUNCE_INTERVAL = 300}; //--- Seconds between dashboard-link broadcasts (default 5 min).
	if (isNil "WFBE_C_DASHBOARD_MSG") then {WFBE_C_DASHBOARD_MSG = "WASP LIVE STATS  >>  http://78.46.107.142:8080/  <<  live server FPS, AI unit balance & K/D leaderboard, and per-build benchmarks - updated every round. That's where we post what's being tested & tuned."}; //--- the broadcast line.

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
	WFBE_C_STATLOG = 1;                   // [WASPSTAT] structured telemetry RPT lines
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
	if (isNil "WFBE_C_SKIN_SELECTOR") then {WFBE_C_SKIN_SELECTOR = 1}; // Command Deck: join-time skin selector (1 enabled, 0 disabled)

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
missionNamespace setVariable ["WFBE_C_WEST_COLOR", "ColorRed"];
missionNamespace setVariable ["WFBE_C_EAST_COLOR", "ColorGreen"];
missionNamespace setVariable ["WFBE_C_GUER_COLOR", "ColorBlue"];
missionNamespace setVariable ["WFBE_C_CIV_COLOR", "ColorYellow"];
missionNamespace setVariable ["WFBE_C_UNKNOWN_COLOR", "ColorBlue"];
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
	if (isNil 'WFBE_C_SIDE_PATROLS_MAX_DEFENDER') then {WFBE_C_SIDE_PATROLS_MAX_DEFENDER = 2};      //--- GUER condense: lower defender concurrent patrol cap vs the global 3.
	WFBE_C_GROUP_BUDGET_WARN = 120;               //--- GROUP-BUDGET ALARM (claude-gaming 2026-06-13): per-side group-count WARN threshold (GRPBUDGET line in AI_Commander.sqf). Arma 2 OA hard cap is 144/side; crossing this logs a GRPBUDGET|WARN so the watchdog/dashboard flags it before the AI can no longer found teams. (120, not 125: with the persistent-husk leak fixed, steady state should drop below 120, making the WARN a true leading indicator rather than always-on.)
	if (isNil 'WFBE_C_GROUPAUDIT_EVERY') then {WFBE_C_GROUPAUDIT_EVERY = 5}; //--- D2 server-FPS (claude-gaming 2026-06-14): run the EXPENSIVE per-faction group-classification AUDIT DUMP (server_groupsGC.sqf; auditMs ~2100ms on 276 groups) only every Nth 5-min audit window. The husk-reap GC + zombie-reap + cap-warning still run EVERY 60s cycle (they live outside the audit branch) - this throttles only diagnostic telemetry. 5 = full dump ~every 25 min instead of every 5 min. 1 = dump every window (old behavior); values < 1 are clamped to 1. Pure diagnostic throttle, no gameplay effect; instant rollback by setting to 1.
};

// --- Player stats (feature-flagged; OFF by default) ---
WFBE_C_STATS_ENABLED = false;
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

["INITIALIZATION", "Init_CommonConstants.sqf: Constants are defined."] Call WFBE_CO_FNC_LogContent;

