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
if (isNil "WFBE_C_SIDE_PATROLS_MAX") then {WFBE_C_SIDE_PATROLS_MAX = 2};  //--- B36.1 (Ray 2026-06-15): WEST/EAST patrol cap 3->2. Patrols stay LOW even as the HQ-team curve scales up; the EFFECTIVE cap is level-aware (min(this, patrol level)) in server_side_patrols.sqf, so patrol-1 => 1, patrol-2+ => 2 per side, never more.

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

//--- B61 (Ray 2026-06-21): GUER AIR DEFENSE — standalone server loop (Server\Server_GuerAirDef.sqf) keeps a
//--- Ka-137 (or, over a large town under attack, a Mi-24) over ACTIVE GUER-held towns. Default-ON but capped +
//--- self-cleaning so it can't blow up FPS. Only relevant when the GUER playable faction is enabled.
	if (isNil "WFBE_C_GUER_AIRDEF_ENABLE") then {WFBE_C_GUER_AIRDEF_ENABLE = 1};        //--- master switch (set 0 to disable the loop entirely).
	if (isNil "WFBE_C_GUER_AIRDEF_INTERVAL") then {WFBE_C_GUER_AIRDEF_INTERVAL = 120};  //--- seconds between maintain sweeps.
	if (isNil "WFBE_C_GUER_AIRDEF_MAX") then {WFBE_C_GUER_AIRDEF_MAX = 4};              //--- global alive cap on GUER air defenders (hard FPS bound).
	if (isNil "WFBE_C_GUER_AIRDEF_AT_CHANCE") then {WFBE_C_GUER_AIRDEF_AT_CHANCE = 0.20}; //--- chance a spawned Ka-137 carries the EASA AT (Konkurs/AT-5) loadout.
	if (isNil "WFBE_C_GUER_AIRDEF_MI24_CHANCE") then {WFBE_C_GUER_AIRDEF_MI24_CHANCE = 0.25}; //--- chance a LARGE GUER town under attack fields a Mi-24 gunship instead.
	if (isNil "WFBE_C_GUER_AIRDEF_CLASS_KA") then {WFBE_C_GUER_AIRDEF_CLASS_KA = "Ka137_MG_PMC"}; //--- default light air defender (recon/strike).
	if (isNil "WFBE_C_GUER_AIRDEF_CLASS_MI24") then {WFBE_C_GUER_AIRDEF_CLASS_MI24 = "Mi24_P"};   //--- heavy gunship for large contested towns.
	if (isNil "WFBE_C_GUER_AIRDEF_LIFETIME") then {WFBE_C_GUER_AIRDEF_LIFETIME = 900};  //--- max seconds a defender lives before forced recycle (anti-accumulation).
	if (isNil "WFBE_C_GUER_AIRDEF_QUIET_DESPAWN") then {WFBE_C_GUER_AIRDEF_QUIET_DESPAWN = 300}; //--- despawn after this many seconds with no enemies near the town.
	if (isNil "WFBE_C_GUER_AIRDEF_LARGE_SV") then {WFBE_C_GUER_AIRDEF_LARGE_SV = 2500}; //--- maxSupplyValue at/above which a town counts as LARGE (Mi-24 eligible); town_type Large/Huge also qualifies.
	if (isNil "WFBE_C_GUER_AIRDEF_HEIGHT") then {WFBE_C_GUER_AIRDEF_HEIGHT = 120};      //--- flyInHeight for spawned GUER air.

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
	//--- ACTIVE-TOWN BUDGET: max concurrently active towns. FPS lever; 12 for the legacy-vs-next A/B (Steff 2026-06-13).
	if (isNil "WFBE_C_TOWNS_ACTIVE_MAX") then {WFBE_C_TOWNS_ACTIVE_MAX = 12}; //--- punchy-AICOM (Ray 2026-06-18): KEEP 12 for the next test - concentration comes from SPEARHEAD_TOWNS_MAX=1 + CONCENTRATION=4 (mass on one town of the full 12-town front), NOT from shrinking the active set.
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
	WFBE_C_AI_COMMANDER_TOTAL_AI_MAX = 190;    //--- B59 (Ray 2026-06-20): 130->190 so 15 teams/side actually fill (15*12 worst-case +10 buffer) and the side-gate (AI_Commander_Produce.sqf:28-30) doesn't starve the last teams below the 8-floor. Rollback: 130. Prior punchy-AICOM (Ray 2026-06-17): 72->130. Sized for 10 teams x [8,12] units: worst case 10*12=120, +10 buffer so the side-gate in AI_Commander_Produce.sqf (:28-30) does not fire at 119 and starve the last team back below the 8-floor. DELIBERATE commander-AI raise (testing trade-off Ray accepts). Rollback: 72.
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
	WFBE_C_AICOM_TEAMS_PC_LOW  = 15;           //--- B59 (Ray 2026-06-20): 10->15 max HQ teams/side (low pop) to really push the load test, Ray's call. ~15*10 found-size = 150/side; TOTAL_AI_MAX raised 130->190 to fit so the side-gate doesn't starve the last teams. EXPECT lower server FPS (this IS the load test). Rollback: 10.  [historical B57 note follows] Pairs with the founding-pad (teams found at 8-12) for larger massed groups. ~10*8=80/side < TOTAL_AI_MAX 130 (watch server FPS). Prior B49 had cut 10->5: FEWER/BIGGER teams - the B48 soak gridlocked at ~2 captures with 10 thin (~5-unit) teams + banked funds; 5 teams fill to 8-12 each and CONCENTRATION=4 massed on the spearhead actually cracks garrisons. 5*12=60 units << TOTAL_AI_MAX 130 (FPS-safe). Rollback: 10.
	WFBE_C_AICOM_TEAMS_PC_MID  = 5;            //--- 3-5 players (Ray B36.1 tweak, was 4).
	WFBE_C_AICOM_TEAMS_PC_HIGH = 3;
	WFBE_C_AICOM_TEAMS_PC_FULL = 2;            //--- rollback the whole curve: set all four to 2.
	WFBE_C_AICOM_DISBAND_SAFE_DIST = 1200;     //--- punchy-AICOM (Ray 2026-06-17): 600->1200 - wider no-retire radius so rear teams are kept (more standing army), only retiring when truly far from any player. Rollback: 600.
	WFBE_C_AICOM_INCOME_PC_BONUS = 0.06;       //--- B36.1 income: +6% AI-commander CASH income per human player UNDER the REF pop (INVERTED - highest at LOW pop to fund the team-curve flood; 0 disables -> flat INCOME_MULT).
	WFBE_C_AICOM_INCOME_PC_REF = 10;           //--- B36.1: player count at/above which the inverted income boost is ZERO (base income). Below it, AI-commander cash income rises +BONUS per player under REF. Mirrors the team curve's high-pop end (10+ = 2 teams).
	//--- B37 BANKING VALVE (Ray 2026-06-16): convert low-pop banked funds into squads + a gentle income trim. Toggle to A/B.
	WFBE_C_AICOM_BANKING_VALVE = 1;            //--- B37: 1=on (low-pop funds->squads valve + income trim); 0=B36.1 behaviour.
	WFBE_C_AICOM_TEAMS_LOWPOP_EXTRA = 4;       //--- B74 (Ray 2026-06-22): 0->4 re-open the banking valve so the hoarded ~1.3M funds convert into a FEW more teams (kept small on purpose - 'fewer-but-stronger' dominates via the B74 cost-weighted picker). Rollback: 0.
	WFBE_C_AICOM_INCOME_PC_BONUS_VALVE = 0.045; //--- B37: gentler low-pop income boost when the valve is on (vs 0.06), so more-squads does not over-bank.
	WFBE_C_AICOM_INCOME_MULT_MAX = 4.0;        //--- B67 (Ray 2026-06-21): 3.0->4.0 - lift the town-cash multiplier ceiling so the low-pop inverted bonus is not clipped (keeps near-empty-server PvE well-funded). CASH only. hard ceiling on the scaled commander income multiplier (packed-server runaway guard).
	if (isNil "WFBE_C_AICOM_AIR_MIN_TOWNS") then {WFBE_C_AICOM_AIR_MIN_TOWNS = 3}; //--- B66: 4->3 - bring air online a town sooner. Aircraft are deferred until the AI holds this many towns (it flies poorly; air is a late, established-only asset). 0 = no gate.
	//--- B66 airfield-air rule: choppers are allowed from an Aircraft-Factory at tier 2; fixed-wing PLANES are only buildable at an OWNED airfield with the Aircraft-Factory at tier 4 (NOT the base air factory). 1 = enforce; 0 = old behaviour (planes from base air factory).
	if (isNil "WFBE_C_AICOM_AIR_REQUIRE_AIRFIELD") then {WFBE_C_AICOM_AIR_REQUIRE_AIRFIELD = 1};
	if (isNil "WFBE_C_AICOM_AIRFIELD_FREE_AIR") then {WFBE_C_AICOM_AIRFIELD_FREE_AIR = 1}; //--- B74 (Ray 2026-06-22): when a side HOLDS a captured airfield it may buy JETS+HELIS there even WITHOUT the Aircraft Factory (free-buy at the field). An Aircraft Factory alone (no airfield) still yields HELICOPTERS ONLY (jets need a field to operate/rearm). 1=on, 0=old (factory-gated, planes need both).
	if (isNil "WFBE_C_AICOM_ARTRAD_REQUIRE_ENEMY_ARTY") then {WFBE_C_AICOM_ARTRAD_REQUIRE_ENEMY_ARTY = 1}; //--- CB-GATE (Ray B48): 1 = AI commander defers the (cosmetic) ArtilleryRadar build until the ENEMY actually fields/fires artillery (re-uses wfbe_aicom_arty_threat). 0 = old human-like always-build. AI-commander build logic ONLY; humans unaffected.
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
	if (isNil "WFBE_C_AICOM_TYPE_MIX_EARLY") then {WFBE_C_AICOM_TYPE_MIX_EARLY = [0.70, 0.22, 0.07, 0.01]};
	if (isNil "WFBE_C_AICOM_TYPE_MIX_MID")   then {WFBE_C_AICOM_TYPE_MIX_MID   = [0.45, 0.28, 0.22, 0.05]};
	if (isNil "WFBE_C_AICOM_TYPE_MIX_LATE")  then {WFBE_C_AICOM_TYPE_MIX_LATE  = [0.28, 0.22, 0.35, 0.15]};
	if (isNil "WFBE_C_AICOM_TYPE_MIX_MATURE_MID")  then {WFBE_C_AICOM_TYPE_MIX_MATURE_MID  = 4}; //--- own-town count at/above which the MID tier applies.
	if (isNil "WFBE_C_AICOM_TYPE_MIX_MATURE_LATE") then {WFBE_C_AICOM_TYPE_MIX_MATURE_LATE = 8}; //--- own-town count at/above which the LATE tier applies.
	//--- B74 COST/TIER BIAS (Ray 2026-06-22): within a chosen class bucket the old picker was a UNIFORM coin-flip over
	//--- all eligible templates, so a 10310-cost premium platoon had the same odds as a 2800 squad - the commander
	//--- hoarded ~1.3M funds and only ever fielded the cheap subset. Weight each template by (summed unit price)^EXP so
	//--- it preferentially fields its EXPENSIVE unlocked units. 0 = uniform (old behaviour); ~1.5-2.0 = strong cost
	//--- preference. Default-ON at 1.5; tune in soak. The price is looked up once per template and cached.
	if (isNil "WFBE_C_AICOM_TIER_BIAS_EXP") then {WFBE_C_AICOM_TIER_BIAS_EXP = 1.5};
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
	if (isNil "WFBE_C_AICOM_INCOME_TAPER_TOWNS")    then {WFBE_C_AICOM_INCOME_TAPER_TOWNS    = 8};    //--- B74.1 (Ray 2026-06-23): AICOM income TAPER kicks in above this town count - diminishing per-town funds so a territorial LEADER's treasury can't compound unbounded (soak leader ran to +281k/tick). At/below = full income.
	if (isNil "WFBE_C_AICOM_INCOME_TAPER_RATE")     then {WFBE_C_AICOM_INCOME_TAPER_RATE     = 0.4};  //--- B74.1: each town held ABOVE the taper threshold contributes only this fraction of a normal town's funds. 0.4 = strong damping; 1.0 = no taper. AICOM-ONLY (never touches player income or supply).
	if (isNil "WFBE_C_AICOM_OVERRUN_DIST")          then {WFBE_C_AICOM_OVERRUN_DIST          = 250};  //--- B74.1 (Ray 2026-06-23): a striking side has OVERRUN the enemy base when a strike-team unit is within this many m of the enemy HQ...
	if (isNil "WFBE_C_AICOM_OVERRUN_CLEAR")         then {WFBE_C_AICOM_OVERRUN_CLEAR         = 200};  //--- B74.1: ...AND zero live enemy units remain within this many m of their own HQ. Both => base overrun => raze HQ+factories => supremacy win.
	if (isNil "WFBE_C_AICOM_OVERRUN_RAZE")          then {WFBE_C_AICOM_OVERRUN_RAZE          = 400};  //--- B74.1: on overrun, every enemy production structure within this many m of the enemy HQ is razed (setDamage 1) so factories==0 for the win check.
	if (isNil "WFBE_C_AICOM_MHQ_ENEMY_CLEAR")       then {WFBE_C_AICOM_MHQ_ENEMY_CLEAR       = 700};  //--- m: do NOT mobilize/deploy if an enemy is within this of the current HQ or the destination.
	if (isNil "WFBE_C_AICOM_MHQ_ARRIVE_DIST")       then {WFBE_C_AICOM_MHQ_ARRIVE_DIST       = 400};  //--- m: MHQ within this of the destination = arrived -> deploy.
	if (isNil "WFBE_C_AICOM_MHQ_DEADLINE")          then {WFBE_C_AICOM_MHQ_DEADLINE          = 600};  //--- s of driving before the player-safe teleport-step fallback (then deploy).
	if (isNil "WFBE_C_AICOM_MHQ_STUCK_SECS")        then {WFBE_C_AICOM_MHQ_STUCK_SECS        = 210};  //--- s with no >25m progress = stuck -> deploy where it stands (never idle).
	//--- B60 HELI CANNON-NUDGE (Ray 2026-06-21, DEFAULT-ON): A2-OA heli gunners over-prefer guided ATGMs and
	//--- ignore the cannon/rockets. When an enemy is within cannon range, drop the attack heli to a low gun-run
	//--- altitude and one-shot force the gunner onto a non-guided muzzle. Set WFBE_C_AICOM_HELI_CANNON_NUDGE = 0 to disable.
	if (isNil "WFBE_C_AICOM_HELI_CANNON_NUDGE") then {WFBE_C_AICOM_HELI_CANNON_NUDGE = 1};   //--- 1 = ON (Ray default).
	if (isNil "WFBE_C_AICOM_HELI_CANNON_RANGE") then {WFBE_C_AICOM_HELI_CANNON_RANGE = 700}; //--- m: enemy within this band -> nudge gunner to cannon.
	if (isNil "WFBE_C_AICOM_HELI_GUN_ALT")      then {WFBE_C_AICOM_HELI_GUN_ALT      = 35};  //--- m: low gun-run altitude so the engine acquires inside guided-min-range (tradeoff: more AA exposure).
	if (isNil "WFBE_C_AICOM_HELI_NUDGE_PERIOD") then {WFBE_C_AICOM_HELI_NUDGE_PERIOD = 7};   //--- s between nudges.
	//--- V0.7 bootstrap: until the side owns >= 1 town, bias target selection to the
	//--- nearest-to-base, lowest-value town so the AI captures its first income source fast.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_BIAS") then {WFBE_C_AICOM_BOOTSTRAP_BIAS = 1};         //--- 1 enable, 0 disable.
	//--- V0.7 bootstrap stipend: trickle funds+supply per supervisor tick while town count == 0.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_FUNDS") then {WFBE_C_AICOM_BOOTSTRAP_FUNDS = 100};     //--- Funds per minute (scaled to tick spacing).
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_SUPPLY") then {WFBE_C_AICOM_BOOTSTRAP_SUPPLY = 120};   //--- punchy-AICOM (Ray 2026-06-17): 50->120 supply/min while zero-town, so the AI tech-unlocks + builds faster out of the gate. Rollback: 50.
	if (isNil "WFBE_C_AICOM_BOOTSTRAP_MAXTIME") then {WFBE_C_AICOM_BOOTSTRAP_MAXTIME = 7200};//--- punchy-AICOM (Ray 2026-06-17): 3600->7200 - keep the zero-town stipend alive for 2h so a stalled AI never goes broke. Rollback: 3600.
	//--- TASK #6 (production): funds->supply UPGRADE FALLBACK. In dual-currency every upgrade costs
	//--- ONLY supply, and supply comes only from owned towns - so a funds-rich 0-town AI can never
	//--- research Light/Heavy/Air and stays infantry-only despite its factory tier. When this rate is
	//--- > 0, Server_AI_Com_Upgrade lets the AI pay the supply price as a FUNDS surcharge (supply price
	//--- * rate) out of its war chest when supply is dry, unlocking vehicle tech. AI-commander-only;
	//--- never touches shared/human supply. Default 0 = DISABLED (no-op; preserves legacy<->next A/B
	//--- parity). Suggested enable value ~2 (per the #6 investigation). Restart-safe nil-guard.
	if (isNil "WFBE_C_AICOM_UPGRADE_FUNDS_RATE") then {WFBE_C_AICOM_UPGRADE_FUNDS_RATE = 1}; //--- B67 (Ray 2026-06-21): REVERTED 2->1. This is a tech-cost funds surcharge, NOT a tech-pacing or income knob; at 2 it drained the cash that should field units and only DELAYED interval-gated upgrades. Back to cheap supply->tech conversion so the cash-rich AI keeps funds for units. 0 disables.
	if (isNil "WFBE_C_AICOM_SUPPLY_RESERVE") then {WFBE_C_AICOM_SUPPLY_RESERVE = 1000}; //--- punchy-AICOM (Ray 2026-06-17): 8000->1000 - unblock economy. The old 8k reserve hoarded supply away from upgrades; with FUNDS_RATE=1 the AI can spend down to 1k and convert the rest to tech via funds. Rollback: 8000.
	WFBE_C_AI_COMMANDER_RELIEF_MAX = 1;           //--- punchy-AICOM (Ray 2026-06-17): 2->1 - at most one team diverted to defense at a time; keep the rest on offense. Rollback: 2.
	//--- B68 (Ray 2026-06-21) ATTACK-BIAS: "defense should matter MUCH LESS than attack." LAST-STAND (recall-all-
	//--- to-HQ) + the maneuver-strength compare that gates it now fire only in genuinely dire cases; teams ASSAULT
	//--- by default. Consumed in AI_Commander_Strategy.sqf. All default-ON, tunable, rollback-documented.
	if (isNil "WFBE_C_AICOM_LASTSTAND_TOWNS") then {WFBE_C_AICOM_LASTSTAND_TOWNS = 1};    //--- recall-all only at <= this many owned towns (old implicit gate <2). Rollback to old behaviour: 1 + RATIO 0.7.
	if (isNil "WFBE_C_AICOM_LASTSTAND_RATIO") then {WFBE_C_AICOM_LASTSTAND_RATIO = 0.45}; //--- AND maneuver strength below this fraction of the enemy's. Was 0.7 (too eager - winning sides went passive). Lower = last-stand rarer = more aggressive. Rollback: 0.7.
	if (isNil "WFBE_C_AICOM_STR_LONE_ALIVE") then {WFBE_C_AICOM_STR_LONE_ALIVE = 2};      //--- a team with fewer than this many alive...
	if (isNil "WFBE_C_AICOM_STR_LONE_FARHQ") then {WFBE_C_AICOM_STR_LONE_FARHQ = 1500};   //--- ...AND farther than this (m) from HQ is a stranded remnant, EXCLUDED from the _myStr maneuver-strength count so it does not deflate strength + trip the defensive gates. 0 disables the exclusion.
	//--- B68 (Ray 2026-06-21) RETREAT-CULL hardening: the B67 progress-gated budget never culls a lone survivor
	//--- that slowly crawls home from far away (re-issues retreat forever, milling at base, never assaulting).
	if (isNil "WFBE_C_AICOM_RETREAT_MAX_ISSUES") then {WFBE_C_AICOM_RETREAT_MAX_ISSUES = 8}; //--- cull a lone survivor after this many retreat re-issues regardless of slow progress.
	if (isNil "WFBE_C_AICOM_RETREAT_MAX_DIST") then {WFBE_C_AICOM_RETREAT_MAX_DIST = 6000};  //--- cull a lone survivor immediately if farther than this (m) from HQ - not worth a multi-km walk home.
	//--- B67 (Ray 2026-06-21) BUILD PLACEMENT (item #10): minimum centre-to-centre spacing between AI-built
	//--- structures + a wider factory placement ring, so factories stop piling on top of each other.
	if (isNil "WFBE_C_AICOM_STRUCT_SPACING") then {WFBE_C_AICOM_STRUCT_SPACING = 45};       //--- m between AI structures (big hangars reach ~30m).
	if (isNil "WFBE_C_AICOM_FACTORY_RING_MIN") then {WFBE_C_AICOM_FACTORY_RING_MIN = 60};   //--- factory placement ring inner (was 45).
	if (isNil "WFBE_C_AICOM_FACTORY_RING_MAX") then {WFBE_C_AICOM_FACTORY_RING_MAX = 110};  //--- factory placement ring outer (was 75).
	//--- B67 (Ray 2026-06-21) MHQ RELOCATION (item #12): the new base must sit a GENEROUS buffer outside any
	//--- enemy/GUER town activation ring (600m base ring + this margin). HQ routes only through own-side towns.
	if (isNil "WFBE_C_AICOM_MHQ_TOWN_BUFFER") then {WFBE_C_AICOM_MHQ_TOWN_BUFFER = 1000};   //--- m beyond the 600m town ring before a relocation destination is accepted.
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
	if (isNil "WFBE_C_AICOM_TEAM_SIZE_MAX") then {WFBE_C_AICOM_TEAM_SIZE_MAX = 12};  //--- founding ceiling (matches WFBE_C_AI_MAX per-group cap).
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
	if (isNil "WFBE_C_AICOM_RELIEF_HOLD") then {WFBE_C_AICOM_RELIEF_HOLD = 180};  //--- s. B68 attack-bias (Ray 2026-06-21): 240->180 so a team diverted to defend returns to offense sooner. Rollback: 240.
	//--- ASSAULT FINISH tunables (extracted from hard-coded literals in Common_RunCommanderTeam.sqf).
	if (isNil "WFBE_C_AICOM_ASSAULT_HOLD") then {WFBE_C_AICOM_ASSAULT_HOLD = 360}; //--- s: camp-first + depot-center capture-hold loop budget (was two hard-coded 150s).
	if (isNil "WFBE_C_AICOM_ASSAULT_SAD")  then {WFBE_C_AICOM_ASSAULT_SAD  = 80};  //--- m: approach-SAD radius on arrival (towns-target) (was hard-coded 250).
	//--- WAVE-1 (2026-06-19) target-abandon + capture-loop break tunables.
	//--- STUCK_ABANDON: after this many consecutive unstuck STRIKES on the SAME town (AssignTowns CAUSE-2),
	//--- the team BLACKLISTS that town for a cooldown and re-picks the next-best reachable target, instead of
	//--- grinding one unreachable/unflippable town forever (re-issue kept re-picking the same town). Guardrail:
	//--- if every candidate is blacklisted the list is cleared so the team always gets a target (never idles).
	if (isNil "WFBE_C_AICOM_STUCK_ABANDON") then {WFBE_C_AICOM_STUCK_ABANDON = 4};
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
	if (isNil "WFBE_C_BASE_STARTING_MODE") then {WFBE_C_BASE_STARTING_MODE = 2}; //--- Starting Locations Mode: 0 = WN|ES; 1 = WS|EN; 2 = Random;
	//--- Egress-quality gate (A2-fix 2026-06-14): random base placement (MODE=2) can box a side into a
	//--- corner with a single egress road, stalling its AI-commander teams (empty HC route -> PFM stall).
	//--- The Init_Server start-picker requires a candidate to have >= MIN_EGRESS_ROADS usable road
	//--- segments (roadsConnectedTo>=2) within nearRoads 250 AND sit >= EDGE_MARGIN m from any map edge.
	//--- Symmetric for both sides; degrades to accept on Vanilla A2 (no roadsConnectedTo). Fallback intact.
	if (isNil "WFBE_C_BASE_MIN_EGRESS_ROADS") then {WFBE_C_BASE_MIN_EGRESS_ROADS = 2}; //--- B66 (Ray 2026-06-21): 3->2, loosen the egress gate so the random-start pool isn't collapsed to ~1 viable pair (the "always same 2 spots" cause). Min usable road segments near a candidate start.
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
	if (isNil 'WFBE_C_AICOM_ASSAULT_REACH_FOOT')    then {WFBE_C_AICOM_ASSAULT_REACH_FOOT    = 2500};  //--- B66 (3000->2500m): tighten foot reach further - keep thin foot teams on adjacent reachable towns (cut long death-marches; tighter contiguous front). [B57: 3500->3000.]
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
	if (isNil 'WFBE_C_AICOM_SLOPE_Z')     then {WFBE_C_AICOM_SLOPE_Z     = 0.86};  //--- A2-fix 2026-06-14: was 0.93 (~21deg, too eager); 0.86 (~31deg) stops the LIMITED<->NORMAL accordion on rolling Chernarus roads
	WFBE_C_CAMPS_REPAIR_DELAY = 15;
	WFBE_C_CAMPS_REPAIR_PRICE = 500;
	WFBE_C_CAMPS_REPAIR_RANGE = 15;

//--- Economy.
	if (isNil "WFBE_C_ECONOMY_CURRENCY_SYSTEM") then {WFBE_C_ECONOMY_CURRENCY_SYSTEM = 0}; //--- 0: Funds + Supply, 1: Funds.
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
	WFBE_C_ECONOMY_INCOME_COEF = 14; //--- B67 (Ray 2026-06-21): 8->14. Boost town-driven CASH income ~1.75x (CASH path only: updateresources.sqf:60->95; the SUPPLY credit at :76 uses WFBE_C_ECONOMY_SUPPLY_INCOME_MULT and is UNCHANGED). Town Multiplicator Coefficient (SV * x).
	WFBE_C_ECONOMY_SUPPLY_INCOME_MULT = 0.35; //--- B57 (Ray 2026-06-20): throttle ongoing town SUPPLY income (long-term buildings/upgrades pace) so the AI commander earns progression from towns+convoys instead of drowning in supply. 1.0 = stock; 0.35 = lowered a lot. Applied in updateresources.sqf. Cash/funds + starting-supply seed UNCHANGED (Ray: cash=units, supply=buildings+upgrades).
	WFBE_C_ECONOMY_INCOME_DIVIDED = 1.2; //--- Prevent commander from being a millionaire, and add the rest to the players pool.
	WFBE_C_ECONOMY_INCOME_PERCENT_MAX = 30; //--- Commander may set income up to x%.
	WFBE_C_ECONOMY_SUPPLY_TIME_INCREASE_DELAY = 60; //--- Increase SV delay.
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
	if (isNil "WFBE_C_SKIN_SELECTOR") then {WFBE_C_SKIN_SELECTOR = 0}; // Command Deck: join-time skin selector (1 enabled, 0 disabled)
	if (isNil "WFBE_C_VEHICLE_MARKINGS") then {WFBE_C_VEHICLE_MARKINGS = 0}; // Miksuu vehicle visuals master gate: per-side recognition markings (Common_AddVehicleMarking.sqf) + side-gated body skins / WEST matte-black (Common_AddVehicleTexture.sqf). 1 enabled, 0 disabled. DEFAULT 0 (experimental, OFF): the marking impl attaches up to 3 dim local #lightpoints PER created vehicle and the WEST case repaints EVERY blufor hull matte-black - both are unverified in-engine and FPS-sensitive. Flip to 1 only after an in-engine attach/FPS test. (Infantry skin selector is separate: WFBE_C_SKIN_SELECTOR.)
	if (isNil "WFBE_C_VEHICLE_TINTS") then {WFBE_C_VEHICLE_TINTS = 1}; // [A/B: flipped ON 2026-06-22 per Ray for the in-engine cosmetic check; revert to 0 if the look is bad] Vehicle faction body TINTS (cheap one-shot setObjectTexture colour strings in Common_AddVehicleTexture.sqf). Decoupled from WFBE_C_VEHICLE_MARKINGS so the tints can be LIVE while the expensive #lightpoint markings stay OFF. 1 enabled, 0 disabled. DEFAULT 0 (opt-in): the B66 side-resolve bug meant the tints were silently INERT in prod (resolved from a crewless hull = civilian -> no faction match); B67 fixed the resolution (now reads the authoritative _createSide passed by Common_CreateVehicle), so enabling this would for the FIRST TIME repaint selections 0+1 (often the whole hull) with a flat procedural colour on EVERY vehicle (WEST near-black / EAST olive / GUER tan) - unverified in-engine and possibly ugly. Flip to 1 only after an in-engine cosmetic check.
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
	if (isNil 'WFBE_C_SIDE_PATROLS_MAX_DEFENDER') then {WFBE_C_SIDE_PATROLS_MAX_DEFENDER = 1};      //--- B36 (Ray 2026-06-15): GUER (defender) side-patrol cap 2->1 - fewer GUER patrols, the survivors made deadlier (skill boost in Common_RunSidePatrol). GUER condense.
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

["INITIALIZATION", "Init_CommonConstants.sqf: Constants are defined."] Call WFBE_CO_FNC_LogContent;

