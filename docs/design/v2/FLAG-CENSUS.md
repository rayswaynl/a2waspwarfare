# FLAG-CENSUS

Status: SPEC-READY with partial provenance. The full Chernarus `Init_CommonConstants.sqf` was read locally, including lines beyond 1194. `git log --grep` provenance and PR-number ORPHAN checks are blocked in this sandbox.

Guide rev for downstream PR bodies: GR-2026-07-03a.

## Recommendation Meanings

- `FLIP-ON`: reasonable candidate for owner-approved default-on or soak-on after smoke.
- `HOLD-DARK`: keep default-off.
- `OWNER-DECIDE`: gameplay/product call; do not flip by agent initiative.
- `NOT-A-FEATURE-FLAG`: value is an enum/counter/side id or tuning zero, not a dark feature gate.

Hard rule: `WFBE_C_SIM_GATING` is always `HOLD-DARK`.

## Census

| Flag | Line | Current | Recommendation | Reason |
| --- | ---: | --- | --- | --- |
| `WFBE_C_WEST_ID` | 30 | 0 | NOT-A-FEATURE-FLAG | Side id constant. |
| `WFBE_C_GUER_IMPROVISED_ARMOR` | 123 | 0 | HOLD-DARK | Gameplay armor change; no soak evidence in local sources. |
| `WFBE_C_AI_COMMANDER_LOCK` | 288 | 0 | OWNER-DECIDE | Enables hybrid player commander behavior; current 0 is intentional. |
| `WFBE_C_AI_COMMANDER_GARRISON` | 289 | 0 | HOLD-DARK | AICOM front/garrison behavior change; V2 should supersede. |
| `WFBE_C_AICOM_PUBLIC_STATE_SYNC` | 290 | 0 | HOLD-DARK | Locality-sensitive; V2 commandment says one server-side namespace. |
| `WFBE_C_TOWNS_STARTUP_SLEEP` | 293 | 0 | OWNER-DECIDE | Perf pacing tuning; safe only as soak experiment. |
| `WFBE_C_AI_DELEGATION` | 299 | 0 | HOLD-DARK | HC/locality architecture risk. |
| `WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA` | 317 | 0 | NOT-A-FEATURE-FLAG | Current tuning pins low-pop teams. |
| `WFBE_C_OILFIELD_GUER_RAID` | 414 | 0 | HOLD-DARK | Adds AI units and raids; not V2 prep. |
| `WFBE_C_AICOM_AIR_TEAM_MAX_HULLS` | 431 | 0 | OWNER-DECIDE | Air founding cap can reduce empty-airframe risk but changes AICOM composition. |
| `WFBE_C_AICOM_AIR_TEAM_STAGGER` | 432 | 0 | OWNER-DECIDE | Spawn pacing knob; use only with air-founding test. |
| `WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE` | 471 | 0 | OWNER-DECIDE | Artillery threat scan behavior; no local soak proof. |
| `WFBE_C_AICOM_TIER_BIAS_EXP` | 495 | 0 | OWNER-DECIDE | Template picker math; V2 should own. |
| `WFBE_C_AI_COMMANDER_ARTILLERY` | 546 | 0 | HOLD-DARK | AI artillery is major gameplay. |
| `WFBE_C_SIM_GATING` | 547 | 0 | HOLD-DARK | Owner-rejected hard rule. |
| `WFBE_C_AICOM_GARRISON_PENALTY` | 573 | 0 | HOLD-DARK | Target scoring change; V2 replaces. |
| `WFBE_C_BASEGC_PLAYER_GUARD` | 607 | 0 | OWNER-DECIDE | Cleanup safety vs stale base objects; needs box policy decision. |
| `WFBE_C_AICOM_BOOTSTRAP_SUPPLY_ENABLE` | 630 | 0 | OWNER-DECIDE | Economy bootstrap behavior; V2 money-pressure doctrine must decide. |
| `WFBE_C_SEC_HARDENING` | 657 | 0 | FLIP-ON | Anti-forgery guard is correctness/security-shaped. Needs smoke and flag-off inert proof. |
| `WFBE_C_AICOM_FUNDS_SINK_ENABLE` | 672 | 0 | OWNER-DECIDE | Directly changes AI hoard behavior; aligns with doctrine but needs soak. |
| `WFBE_C_ENDGAME_FORCE_ENABLE` | 684 | 0 | OWNER-DECIDE | Endgame economy forcing is a product/balance choice. |
| `WFBE_C_AICOM_FEINT_ENABLE` | 714 | 0 | HOLD-DARK | V2 should design feints coherently, not enable V1 side feature. |
| `WFBE_C_AICOM_EXPAND_DEDUP` | 719 | 0 | FLIP-ON | Directly targets dogpile/churn pathology; run one soak with lens pack before default-on. |
| `WFBE_C_AICOM_HARASS_FALLBACK` | 720 | 0 | FLIP-ON | Directly targets unreachable harass picks; supports doctrine "commit, don't churn". Soak first. |
| `WFBE_C_AICOM_TARGET_AWARE_COMP` | 760 | 0 | HOLD-DARK | Composition behavior belongs to V2 planner. |
| `WFBE_C_AICOM_PLAYER_ARTY` | 780 | 0 | HOLD-DARK | Player-directed arty for AICOM is gameplay-heavy. |
| `WFBE_C_AICOM_HELI_APPROACH_LIMITED` | 800 | 0 | OWNER-DECIDE | AI heli safety tweak; needs in-engine flight check. |
| `WFBE_C_AICOM_HELI_RUNINFLOOR` | 801 | 0 | OWNER-DECIDE | Terrain-specific flight floor; map-profile V2 should own. |
| `WFBE_C_AICOM_HELI_GUNFLOOR` | 802 | 0 | OWNER-DECIDE | Terrain-specific attack-heli floor. |
| `WFBE_C_AICOM_FOUND_REQUIRE_FACTORY` | 905 | 0 | HOLD-DARK | Can starve founding; keep dark until V2 economy/factory rules. |
| `WFBE_C_AICOM_SPREAD_TIERCAP` | 917 | 0 | OWNER-DECIDE | Fist spread tuning; soak-only candidate. |
| `WFBE_C_AICOM_OVERRUN_SCRIPTRAZE` | 925 | 0 | HOLD-DARK | Owner preference is real destruction; keep scripted raze off. |
| `WFBE_C_AICOM_STRIKE_COMMIT` | 940 | 0 | FLIP-ON | Prevents HQ strike from stealing progressing teams; matches doctrine. Needs soak. |
| `WFBE_C_AICOM_RESEARCH_AIR` | 944 | 0 | OWNER-DECIDE | Air research affects tech arc. |
| `WFBE_C_AICOM_STRIKE_AT_BONUS` | 945 | 0 | OWNER-DECIDE | HQ-strike picker balance. |
| `WFBE_C_AICOM_ORBITER_DETECT` | 948 | 0 | FLIP-ON | Detects no-closing-distance stuck teams; supports no-dead-air and soak watchdog goals. |
| `WFBE_C_AICOM_STUCK_DECAY` | 950 | 0 | FLIP-ON | Improves stuck ladder hysteresis; test with stranded metrics. |
| `WFBE_C_NAVAL_WEST_AAV` | 983 | 0 | HOLD-DARK | Metadata hook only; full naval-map build later. |
| `WFBE_C_PERFORMANCE_AUDIT_SIDE_PATROL_PROBES` | 995 | 0 | FLIP-ON | Telemetry-only during soaks; default-on for soak builds, not public by default. |
| `WFBE_C_SERVER_FPS_GUI_ACTIVE_PLAYERS_ONLY` | 996 | 0 | OWNER-DECIDE | Broadcast reduction changes dashboard/client visibility. |
| `WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY` | 997 | 0 | FLIP-ON | Reduces rebroadcast noise; verify marker freshness. |
| `WFBE_C_AICOM_PLANE_FLYHEIGHT` | 1063 | 0 | NOT-A-FEATURE-FLAG | Zero means map-aware default. |
| `WFBE_C_JIP_CATCHUP_BRIEFING` | 1082 | 0 | OWNER-DECIDE | UX/briefing choice. |
| `WFBE_C_MUSIC_ENABLE` | 1086 | 0 | HOLD-DARK | Client cosmetic/audio. |
| `WFBE_C_AICOM_HC_MERGE_ENABLE` | 1182 | 0 | OWNER-DECIDE | Depleted-team merge changes lifecycle; likely V2-owned. |
| `WFBE_C_ARTILLERY_UI` | 1199 | 0 | OWNER-DECIDE | Player feature toggle. |
| `WFBE_C_ARTY_SHARED_COOLDOWN` | 1200 | 0 | OWNER-DECIDE | Player artillery balance. |
| `WFBE_C_BASE_RES` | 1214 | 0 | NOT-A-FEATURE-FLAG | Enum-style base resistance setting. |
| `WFBE_C_BASE_EGRESS_MAP_BOUNDS` | 1227 | 0 | FLIP-ON | ZG pre-set already uses 1; map-aware egress prevents out-of-bounds starts. Needs CH/TK smoke. |
| `WFBE_C_CLEANER_MAP_AWARE_ORIGINS` | 1229 | 0 | FLIP-ON | Map-aware cleaner origins are correctness-shaped for non-CH maps. Needs smoke. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_WEST` | 1237 | 0 | NOT-A-FEATURE-FLAG | Runtime counter. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_EAST` | 1238 | 0 | NOT-A-FEATURE-FLAG | Runtime counter. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_GUER` | 1239 | 0 | NOT-A-FEATURE-FLAG | Runtime counter. |
| `WFBE_C_TOWN_CAMP_SCAN_THROTTLE` | 1251 | 0 | OWNER-DECIDE | Perf tuning; soak-only candidate. |
| `WFBE_C_ECONOMY_CURRENCY_SYSTEM` | 1294 | 0 | NOT-A-FEATURE-FLAG | Existing economy mode enum. |
| `WFBE_C_CMD_DEF_SUPPLY` | 1309 | 0 | HOLD-DARK | Prior supply-pricing experiment; current cash behavior intentional. |
| `WFBE_C_FIX_INCOME_SYSTEM4_DISPLAY` | 1330 | 0 | FLIP-ON | Display correctness; should not change server payout. Needs UI smoke. |
| `WFBE_C_ENVIRONMENT_WEATHER` | 1423 | 0 | NOT-A-FEATURE-FLAG | Weather enum. |
| `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC` | 1425 | 0 | NOT-A-FEATURE-FLAG | 0 disables volumetric clouds by design. |
| `WFBE_C_GAMEPLAY_MISSILES_RANGE` | 1434 | 0 | OWNER-DECIDE | Gameplay range limiter. |
| `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE` | 1438 | 0 | OWNER-DECIDE | Start-up tech/gameplay option. |
| `WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC` | 1448 | 0 | FLIP-ON | Correctness fix candidate; verify no network spam. |
| `WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL` | 1449 | 0 | FLIP-ON | UI correctness for already-recorded stats. |
| `WFBE_C_FIX_VOTE_LIST_PRUNE` | 1450 | 0 | FLIP-ON | Safer reverse-pass/stale-index vote fix. |
| `WFBE_C_FIX_VOTE_QA_EXECUTION` | 1451 | 0 | FLIP-ON | Vote QA follow-up; smoke confirm two-click flows. |
| `WFBE_C_AMBIENT_SKIRMISH` | 1452 | 0 | HOLD-DARK | Adds ambient AI/combat outside V2. |
| `WFBE_C_FIX_IRSMOKE_PARAM_ALIAS` | 1472 | 0 | FLIP-ON | Alias correctness; low behavior risk. |
| `WFBE_C_STRUCTURES_CONSTRUCTION_MODE` | 1523 | 0 | NOT-A-FEATURE-FLAG | Construction mode enum. |
| `WFBE_C_TOWNS_CAPTURE_MODE` | 1550 | 0 | NOT-A-FEATURE-FLAG | Current capture mode intentionally Classic. |
| `WFBE_C_TOWNS_PATROL_CONTESTED_ONLY` | 1555 | 0 | OWNER-DECIDE | Town defense behavior change. |
| `WFBE_C_WAYPOINT_WATER_RETRY_CAP` | 1556 | 0 | FLIP-ON | Prevents unbounded water retry; verify route fallback. |
| `WFBE_C_TOWNS_REINFORCEMENT_DEFENDER` | 1557 | 0 | HOLD-DARK | Adds town reinforcement behavior. |
| `WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION` | 1558 | 0 | HOLD-DARK | Adds town occupation behavior. |
| `WFBE_C_TOWNS_STARTING_MODE` | 1559 | 0 | NOT-A-FEATURE-FLAG | Town starting enum. |
| `WFBE_C_TOWNS_AI_SCAN_RANGE_OVERRIDE` | 1569 | 0 | OWNER-DECIDE | Scan range tuning; soak-only candidate. |
| `WFBE_C_STRUCTURES_FLAT_CHECK` | 1598 | 0 | HOLD-DARK | Disabled because it over-blocked Takistan placement. |
| `WFBE_C_UNITS_PRICING` | 1604 | 0 | NOT-A-FEATURE-FLAG | Pricing mode enum. |
| `WFBE_C_RESTART_ENABLED` | 1645 | 0 | OWNER-DECIDE | In-game restart announcer requires ops policy. |
| `WFBE_C_STRUCTURES_ARTILLERYRADAR` | 1674 | 0 | OWNER-DECIDE | Buildable structure feature; in-engine build test needed. |
| `WFBE_C_STRUCTURES_RESERVE` | 1675 | 0 | OWNER-DECIDE | Buildable structure feature; in-engine build test needed. |
| `WFBE_C_FIX_FACTORY_QUEUE_TOKEN_HARDENING` | 1684 | 0 | FLIP-ON | Queue token hardening; correctness/security-shaped. |
| `WFBE_C_SKIN_SELECTOR` | 1700 | 0 | OWNER-DECIDE | Join-time skin UX. |
| `WFBE_C_VEHICLE_MARKINGS` | 1701 | 0 | HOLD-DARK | FPS-sensitive attached lights and hull repaint. |
| `WFBE_C_VEHICLE_FLAGS` | 1705 | 0 | HOLD-DARK | Adds flag object per vehicle; FPS-sensitive. |
| `WFBE_C_KILL_TALLY_DECAL` | 1711 | 0 | HOLD-DARK | Cosmetic vehicle marker; perf/JIP visual risk. |
| `WFBE_C_VEHICLE_TINTS` | 1712 | 0 | HOLD-DARK | Unverified full-hull repaint, possible ugly/perf risk. |
| `WFBE_C_VICTORY_THREEWAY` | 1741 | 0 | OWNER-DECIDE | Major win-condition mode. |
| `WFBE_C_WALLS_V2` | 1898 | 0 | OWNER-DECIDE | Defense/wall system behavior. |
| `WFBE_C_FWD_STATIC_MANNING` | 2024 | 0 | OWNER-DECIDE | Static manning behavior. |
| `WFBE_C_FIX_RESPAWN_UNITQUEU_RESET` | 2030 | 0 | FLIP-ON | Correctness fix candidate; verify respawn queue flow. |

## Flip Batch Proposal

Small low-risk smoke batch:

- `WFBE_C_FIX_IRSMOKE_PARAM_ALIAS`
- `WFBE_C_FIX_INCOME_SYSTEM4_DISPLAY`
- `WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL`
- `WFBE_C_FIX_VOTE_LIST_PRUNE`
- `WFBE_C_FIX_VOTE_QA_EXECUTION`
- `WFBE_C_FIX_FACTORY_QUEUE_TOKEN_HARDENING`
- `WFBE_C_FIX_RESPAWN_UNITQUEU_RESET`

Soak/telemetry batch:

- `WFBE_C_PERFORMANCE_AUDIT_SIDE_PATROL_PROBES`
- `WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY`
- `WFBE_C_AICOM_EXPAND_DEDUP`
- `WFBE_C_AICOM_HARASS_FALLBACK`
- `WFBE_C_AICOM_STRIKE_COMMIT`
- `WFBE_C_AICOM_ORBITER_DETECT`
- `WFBE_C_AICOM_STUCK_DECAY`

Never flip:

- `WFBE_C_SIM_GATING`
- vehicle markings/flags/tints unless owner explicitly asks for a cosmetic/FPS test.

