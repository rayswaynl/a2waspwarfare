# Flag Census

GUIDE-REV: GR-2026-07-03a
Lane: 454 / H-3
Base checked: `origin/codex/hygiene-hub-page@83e12b30f` stacked on `origin/claude/build84-cmdcon36@b61bf7864`
Prompt SHA256: `9C367EC1F5100DD59576A5939140D439F23220D012C9C802A945B57A5145708B`

## Scope

This is a source-backed owner decision table for default-zero `WFBE_C_*` flags in
`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`.

The scan found 92 `WFBE_C_* = 0` defaults. This report separates:

- real default-off feature or behavior flags that can be considered for `FLIP-ON`, `HOLD-DARK`, or `OWNER-DECIDE`;
- baseline enum/counter values where `0` is the intended live choice and not a dark feature.

No SQF, SQM, HPP, generated mirror, package, deploy, or live runtime file is changed by this lane.

## Recommendation Counts

| Recommendation | Count | Meaning |
|---|---:|---|
| `FLIP-ON` | 8 | Low-blast-radius correctness, compatibility, or map-parity switches that look ready for a guarded default-on PR. |
| `OWNER-DECIDE` | 43 | Plausible but changes balance, UX, telemetry volume, pathing, economy, or V2 design semantics; needs explicit owner choice and/or soak proof. |
| `HOLD-DARK` | 24 | Keep default 0 for now due owner rejection, HC/locality risk, artillery/AI-volume risk, object/FPS risk, or known negative history. |
| `NO-FLIP` | 17 | Default 0 is an ID, counter, enum baseline, already-selected live baseline, or non-switch numeric value. |

## Highest Confidence Flip-On Candidates

| Flag | Source | Recommendation | Why |
|---|---|---|---|
| `WFBE_C_BASE_EGRESS_MAP_BOUNDS` | `Init_CommonConstants.sqf:1227` | `FLIP-ON` | Map-parity guard: uses `Init_Boundaries` world size instead of legacy Chernarus 15360 edge box. Zargabad already pre-sets this to 1 at boot, so the remaining default-off surface is CH/TK parity. |
| `WFBE_C_CLEANER_MAP_AWARE_ORIGINS` | `Init_CommonConstants.sqf:1229` | `FLIP-ON` | Map-aware cleaner/restorer centers and radii. Low gameplay blast radius; validates the Zargabad lesson that CH scan anchors should not leak into smaller terrain assumptions. |
| `WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL` | `Init_CommonConstants.sqf:1449` | `FLIP-ON` | UI-only third-column display for already-recorded GUER stats. Does not create new scoring state. |
| `WFBE_C_FIX_VOTE_LIST_PRUNE` | `Init_CommonConstants.sqf:1450` | `FLIP-ON` | Safer reverse-pass vote-dialog row pruning; correctness fix behind a flag. |
| `WFBE_C_FIX_VOTE_QA_EXECUTION` | `Init_CommonConstants.sqf:1451` | `FLIP-ON` | Vote QA follow-up for stale stored-index coloring and placeholder confirms; scoped to UI correctness. |
| `WFBE_C_FIX_IRSMOKE_PARAM_ALIAS` | `Init_CommonConstants.sqf:1472` | `FLIP-ON` | Compatibility alias from lobby `WFBE_C_MODULE_WFBE_IRS` to runtime `WFBE_C_MODULE_WFBE_IRSMOKE`; low-risk bridge for naming drift. |
| `WFBE_C_FIX_INCOME_SYSTEM4_DISPLAY` | `Init_CommonConstants.sqf:1330` | `FLIP-ON` | Display-only alignment so `Client_GetIncome` mirrors the server income-system 4 x1.5 payout. |
| `WFBE_C_FIX_RESPAWN_UNITQUEU_RESET` | `Init_CommonConstants.sqf:2030` | `FLIP-ON` | Correctness flag for respawn unit queue reset. Needs normal UI smoke, but default-on risk is smaller than leaving a stale-queue fix dark. |

## Owner Decision Table

| Flag | Source | Recommendation | Evidence and rationale |
|---|---|---|---|
| `WFBE_C_GUER_IMPROVISED_ARMOR` | `Init_CommonConstants.sqf:123` | `OWNER-DECIDE` | Whole-feature GUER damage reduction. Balance-facing and player-visible; do not flip without owner balance call. |
| `WFBE_C_AI_COMMANDER_GARRISON` | `Init_CommonConstants.sqf:289` | `OWNER-DECIDE` | Moves AICOM teams into base-garrison behavior. Relevant to V2 defense doctrine but changes front pressure. |
| `WFBE_C_AICOM_PUBLIC_STATE_SYNC` | `Init_CommonConstants.sqf:290` | `OWNER-DECIDE` | Broadcasts AICOM funds/running state for HC readers. Useful for observability/locality cleanup, but replication-sensitive. |
| `WFBE_C_TOWNS_STARTUP_SLEEP` | `Init_CommonConstants.sqf:293` | `OWNER-DECIDE` | Numeric pacing knob, not a boolean flip. Try `0.05-0.10` only after startup spike evidence. |
| `WFBE_C_OILFIELD_GUER_RAID` | `Init_CommonConstants.sqf:414` | `OWNER-DECIDE` | Adds GUER foot raids while an oilfield is paying. AI-volume and economy pressure change. |
| `WFBE_C_AICOM_AIR_TEAM_MAX_HULLS` | `Init_CommonConstants.sqf:431` | `OWNER-DECIDE` | Air-team cap tuning for retained Air hulls. Needs AICOM air template review before nonzero. |
| `WFBE_C_AICOM_AIR_TEAM_STAGGER` | `Init_CommonConstants.sqf:432` | `OWNER-DECIDE` | Air-team spawn pacing. Pair with max-hulls decision and soak timings. |
| `WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE` | `Init_CommonConstants.sqf:471` | `OWNER-DECIDE` | Replaces legacy 10 km conditional-C enemy artillery scan with tunable radius. Low code risk, but artillery behavior changes. |
| `WFBE_C_AICOM_TIER_BIAS_EXP` | `Init_CommonConstants.sqf:495` | `OWNER-DECIDE` | AICOM picker/scoring exponent. Needs V2 doctrine acceptance, not a hygiene flip. |
| `WFBE_C_AICOM_GARRISON_PENALTY` | `Init_CommonConstants.sqf:573` | `OWNER-DECIDE` | Penalizes garrison hardness tiers in fist scoring. Good V2 tuning candidate; needs soak proof. |
| `WFBE_C_BASEGC_PLAYER_GUARD` | `Init_CommonConstants.sqf:607` | `OWNER-DECIDE` | Player-proximity guard for base cleanup candidates. Ray note says 0 means proximity does not block cleanup; changing can preserve debris near players. |
| `WFBE_C_AICOM_BOOTSTRAP_SUPPLY_ENABLE` | `Init_CommonConstants.sqf:630` | `OWNER-DECIDE` | AICOM bootstrap supply in dual-currency mode. Economy-sensitive; previous readiness sweep says needs soak proof. |
| `WFBE_C_SEC_HARDENING` | `Init_CommonConstants.sqf:657` | `OWNER-DECIDE` | Anti-forgery guards. Security-positive, but can false-positive live player flows; enable only with focused request-path smoke. |
| `WFBE_C_AICOM_FEINT_ENABLE` | `Init_CommonConstants.sqf:714` | `OWNER-DECIDE` | Arms feint dispatch. V2 behavioral doctrine candidate; needs accept/harness metric. |
| `WFBE_C_AICOM_EXPAND_DEDUP` | `Init_CommonConstants.sqf:719` | `OWNER-DECIDE` | Prevents multiple expand teams dogpiling one neutral. Looks aligned with V2 "commit, don't churn", but should be soak-measured. |
| `WFBE_C_AICOM_HARASS_FALLBACK` | `Init_CommonConstants.sqf:720` | `OWNER-DECIDE` | Makes harass pick deepest reachable instead of deepest overall. Behavior fix candidate; needs route/pathing smoke. |
| `WFBE_C_AICOM_TARGET_AWARE_COMP` | `Init_CommonConstants.sqf:760` | `OWNER-DECIDE` | Target-aware team composition. V2 build/research doctrine adjacent; not a hygiene flip. |
| `WFBE_C_AICOM_HELI_APPROACH_LIMITED` | `Init_CommonConstants.sqf:800` | `OWNER-DECIDE` | Slows transport helis on final LZ run-in. May improve insert behavior but changes air tempo. |
| `WFBE_C_AICOM_HELI_RUNINFLOOR` | `Init_CommonConstants.sqf:801` | `OWNER-DECIDE` | Numeric heli transport altitude floor. Map-specific values needed before nonzero. |
| `WFBE_C_AICOM_HELI_GUNFLOOR` | `Init_CommonConstants.sqf:802` | `OWNER-DECIDE` | Numeric gun-run altitude floor. Needs CH/TK/ZG profile choice. |
| `WFBE_C_AICOM_SPREAD_TIERCAP` | `Init_CommonConstants.sqf:917` | `OWNER-DECIDE` | Scales fist spread cap by town type. V2 concentration/churn metric should decide. |
| `WFBE_C_AICOM_STRIKE_COMMIT` | `Init_CommonConstants.sqf:940` | `OWNER-DECIDE` | Protects progressing teams from HQ-strike grabs. Strongly relevant to V2 commitment doctrine; enable after targeted HQ-strike soak. |
| `WFBE_C_AICOM_RESEARCH_AIR` | `Init_CommonConstants.sqf:944` | `OWNER-DECIDE` | Appends air upgrades when Aircraft Factory exists. Tech tempo change. |
| `WFBE_C_AICOM_STRIKE_AT_BONUS` | `Init_CommonConstants.sqf:945` | `OWNER-DECIDE` | Launcher-team bonus in HQ-strike picker. Pair with strike-commit/HQ package review. |
| `WFBE_C_AICOM_ORBITER_DETECT` | `Init_CommonConstants.sqf:948` | `OWNER-DECIDE` | Detects orbiting en-route teams and enters stuck ladder. Useful, but touches stuck classification. |
| `WFBE_C_AICOM_STUCK_DECAY` | `Init_CommonConstants.sqf:950` | `OWNER-DECIDE` | Decays strike counter on progress instead of hard reset. Needs stuck/abandon KPI comparison. |
| `WFBE_C_AICOM_ARMOR_SCREEN` | `Init_CommonConstants.sqf:980` | `OWNER-DECIDE` | Changes tank arrival orders from infantry SAD to outward screening. Behavior-facing. |
| `WFBE_C_PERFORMANCE_AUDIT_SIDE_PATROL_PROBES` | `Init_CommonConstants.sqf:995` | `OWNER-DECIDE` | Telemetry-only but adds PerformanceAudit volume. Enable only for targeted profiling windows. |
| `WFBE_C_SERVER_FPS_GUI_ACTIVE_PLAYERS_ONLY` | `Init_CommonConstants.sqf:996` | `OWNER-DECIDE` | Reduces server-FPS GUI broadcasts when no non-HC humans are connected. Likely safe, but changes monitoring visibility. |
| `WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY` | `Init_CommonConstants.sqf:997` | `OWNER-DECIDE` | Changes side-patrol marker feed from fixed cadence to change/keepalive. Needs JIP/marker freshness smoke. |
| `WFBE_C_JIP_CATCHUP_BRIEFING` | `Init_CommonConstants.sqf:1082` | `OWNER-DECIDE` | JIP briefing catch-up. Player UX positive but needs JIP smoke. |
| `WFBE_C_MUSIC_ENABLE` | `Init_CommonConstants.sqf:1086` | `OWNER-DECIDE` | Client playMusic hooks. Pure UX, but owner taste/annoyance risk. |
| `WFBE_C_ARTY_SHARED_COOLDOWN` | `Init_CommonConstants.sqf:1200` | `OWNER-DECIDE` | Side-shared artillery cooldown instead of client-local only. Gameplay fairness and artillery pacing change. |
| `WFBE_C_TOWN_CAMP_SCAN_THROTTLE` | `Init_CommonConstants.sqf:1251` | `OWNER-DECIDE` | Performance tuning for camp scans. Needs before/after town response and FPS evidence. |
| `WFBE_C_CMD_DEF_SUPPLY` | `Init_CommonConstants.sqf:1309` | `OWNER-DECIDE` | Host toggle for b88 supply-pricing experiment; current live report restored cash defenses. |
| `WFBE_C_AMBIENT_SKIRMISH` | `Init_CommonConstants.sqf:1452` | `OWNER-DECIDE` | Adds ambient WEST/EAST skirmish cells. AI volume and narrative value trade-off. |
| `WFBE_C_TOWNS_PATROL_CONTESTED_ONLY` | `Init_CommonConstants.sqf:1555` | `OWNER-DECIDE` | Changes town patrol defense behavior to contested-only. Could reduce noise but affects defense feel. |
| `WFBE_C_WAYPOINT_WATER_RETRY_CAP` | `Init_CommonConstants.sqf:1556` | `OWNER-DECIDE` | Caps water waypoint retries. Low risk, but pathing behavior should be map-smoked. |
| `WFBE_C_TOWNS_REINFORCEMENT_DEFENDER` | `Init_CommonConstants.sqf:1557` | `OWNER-DECIDE` | Adds defender reinforcements. AI-volume and capture pacing change. |
| `WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION` | `Init_CommonConstants.sqf:1558` | `OWNER-DECIDE` | Adds occupation reinforcements. AI-volume and capture pacing change. |
| `WFBE_C_TOWNS_AI_SCAN_RANGE_OVERRIDE` | `Init_CommonConstants.sqf:1569` | `OWNER-DECIDE` | Numeric override for town AI activation scan range. Needs map/profile target. |
| `WFBE_C_RESTART_ENABLED` | `Init_CommonConstants.sqf:1645` | `OWNER-DECIDE` | Operations messaging. Enable only when restart cadence is actually owned by the operator. |
| `WFBE_C_FWD_STATIC_MANNING` | `Init_CommonConstants.sqf:2024` | `OWNER-DECIDE` | Forward static manning behavior. Needs defense doctrine decision. |

## Hold-Dark Table

| Flag | Source | Recommendation | Reason |
|---|---|---|---|
| `WFBE_C_AI_DELEGATION` | `Init_CommonConstants.sqf:299` | `HOLD-DARK` | HC/client AI delegation is locality-sensitive and AGENTS.md says never touch HC architecture casually. |
| `WFBE_C_AI_COMMANDER_ARTILLERY` | `Init_CommonConstants.sqf:546` | `HOLD-DARK` | AICOM artillery remains owner-locked/high risk. |
| `WFBE_C_SIM_GATING` | `Init_CommonConstants.sqf:547` | `HOLD-DARK` | Hard constraint from prompt/AGENTS: owner-rejected sim gating; never flip. |
| `WFBE_C_AICOM_FUNDS_SINK_ENABLE` | `Init_CommonConstants.sqf:672` | `HOLD-DARK` | Previous readiness sweep requires economy soak before enabling. |
| `WFBE_C_ENDGAME_FORCE_ENABLE` | `Init_CommonConstants.sqf:684` | `HOLD-DARK` | Late-round taper changes match pacing; keep dark until long-round soak proves value. |
| `WFBE_C_AICOM_PLAYER_ARTY` | `Init_CommonConstants.sqf:780` | `HOLD-DARK` | Player-requested AICOM artillery helper; same artillery owner gate. |
| `WFBE_C_AICOM_FOUND_REQUIRE_FACTORY` | `Init_CommonConstants.sqf:905` | `HOLD-DARK` | Source comment says ships OFF for founding-starvation safety. |
| `WFBE_C_AICOM_OVERRUN_SCRIPTRAZE` | `Init_CommonConstants.sqf:925` | `HOLD-DARK` | Source comment says Ray wants real destruction, not scripted siege-timer raze. |
| `WFBE_C_NAVAL_WEST_AAV` | `Init_CommonConstants.sqf:983` | `HOLD-DARK` | Dormant metadata for future naval-map work; do not arm before Utes/Invasion lane. |
| `WFBE_C_AICOM_HC_MERGE_ENABLE` | `Init_CommonConstants.sqf:1182` | `HOLD-DARK` | Same-HC depleted-team merge touches HC team ownership/locality. |
| `WFBE_C_ARTILLERY_UI` | `Init_CommonConstants.sqf:1199` | `HOLD-DARK` | Direct-fire artillery UI is artillery/module scope; needs explicit owner approval. |
| `WFBE_C_GAMEPLAY_MISSILES_RANGE` | `Init_CommonConstants.sqf:1434` | `HOLD-DARK` | Weapon behavior and range limiting. Not V2 hygiene. |
| `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE` | `Init_CommonConstants.sqf:1438` | `HOLD-DARK` | Starts upgrades pre-cleared for selected sides; progression rules change. |
| `WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC` | `Init_CommonConstants.sqf:1448` | `HOLD-DARK` | Publishes stealth-engine state across locality; needs vehicle-state authority smoke. |
| `WFBE_C_STRUCTURES_FLAT_CHECK` | `Init_CommonConstants.sqf:1598` | `HOLD-DARK` | Explicitly disabled because the player flat gate over-blocked mountainous Takistan base placement. |
| `WFBE_C_STRUCTURES_ARTILLERYRADAR` | `Init_CommonConstants.sqf:1674` | `HOLD-DARK` | WDDM artillery radar buildable structure; artillery/WDDM scope. |
| `WFBE_C_STRUCTURES_RESERVE` | `Init_CommonConstants.sqf:1675` | `HOLD-DARK` | WDDM reserve structure; new buildable structure scope. |
| `WFBE_C_FIX_FACTORY_QUEUE_TOKEN_HARDENING` | `Init_CommonConstants.sqf:1684` | `HOLD-DARK` | Stronger player-buy FIFO tokens can affect purchases; keep dark until queue smoke. |
| `WFBE_C_SKIN_SELECTOR` | `Init_CommonConstants.sqf:1700` | `HOLD-DARK` | Legacy join-time skin selector. Do not revive without UX decision. |
| `WFBE_C_VEHICLE_MARKINGS` | `Init_CommonConstants.sqf:1701` | `HOLD-DARK` | Per-vehicle lightpoints/body skins; object/FPS and visual risk. |
| `WFBE_C_VEHICLE_FLAGS` | `Init_CommonConstants.sqf:1705` | `HOLD-DARK` | Attaches flag object per created vehicle; object/FPS risk. |
| `WFBE_C_KILL_TALLY_DECAL` | `Init_CommonConstants.sqf:1711` | `HOLD-DARK` | Cosmetic vehicle marker path; depends on marking watcher and visual/FPS test. |
| `WFBE_C_VEHICLE_TINTS` | `Init_CommonConstants.sqf:1712` | `HOLD-DARK` | Cosmetic faction body tints; source comment says unverified and possibly ugly. |
| `WFBE_C_WALLS_V2` | `Init_CommonConstants.sqf:1898` | `HOLD-DARK` | Tombstone/dead wall-ladder switch from prior docs; do not flip. |

## No-Flip Defaults

These rows were in the mechanical `= 0` scan but are not feature switches to flip.

| Name | Source | Classification | Reason |
|---|---|---|---|
| `WFBE_C_WEST_ID` | `Init_CommonConstants.sqf:30` | `NO-FLIP` | Side id constant, not a feature gate. |
| `WFBE_C_AI_COMMANDER_LOCK` | `Init_CommonConstants.sqf:288` | `NO-FLIP` | Default 0 is the intended live hybrid commander enablement. |
| `WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA` | `Init_CommonConstants.sqf:317` | `NO-FLIP` | Current team-curve tuning; rollback value is 1, but 0 is not dark feature work. |
| `WFBE_C_AICOM_PLANE_FLYHEIGHT` | `Init_CommonConstants.sqf:1063` | `NO-FLIP` | 0 means map-aware altitude floor, not disabled feature. |
| `WFBE_C_AICOM_SVC_ARMOUR_ONLY` | `Init_CommonConstants.sqf:1135` | `NO-FLIP` | 0 is the intended broader service behavior from B66. |
| `WFBE_C_BASE_RES` | `Init_CommonConstants.sqf:1214` | `NO-FLIP` | Enum parameter where 0 means disabled RES base, not hidden feature readiness. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_WEST` | `Init_CommonConstants.sqf:1237` | `NO-FLIP` | Runtime counter. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_EAST` | `Init_CommonConstants.sqf:1238` | `NO-FLIP` | Runtime counter. |
| `WFBE_C_BASE_HQ_REPAIR_COUNT_GUER` | `Init_CommonConstants.sqf:1239` | `NO-FLIP` | Runtime counter. |
| `WFBE_C_ECONOMY_CURRENCY_SYSTEM` | `Init_CommonConstants.sqf:1294` | `NO-FLIP` | Enum: 0 is funds+supply, current live economy. |
| `WFBE_C_ENVIRONMENT_WEATHER` | `Init_CommonConstants.sqf:1423` | `NO-FLIP` | Enum: 0 is clear weather baseline. |
| `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC` | `Init_CommonConstants.sqf:1425` | `NO-FLIP` | Weather presentation baseline; not a V2 feature switch. |
| `WFBE_C_STRUCTURES_CONSTRUCTION_MODE` | `Init_CommonConstants.sqf:1523` | `NO-FLIP` | Enum: 0 is time-based construction mode. |
| `WFBE_C_TOWNS_CAPTURE_MODE` | `Init_CommonConstants.sqf:1550` | `NO-FLIP` | Current live Classic capture mode; source comment says All Camps over-blocked AI captures. |
| `WFBE_C_TOWNS_STARTING_MODE` | `Init_CommonConstants.sqf:1559` | `NO-FLIP` | Enum: 0 is normal resistance town start. |
| `WFBE_C_UNITS_PRICING` | `Init_CommonConstants.sqf:1604` | `NO-FLIP` | Enum: 0 is default pricing. |
| `WFBE_C_VICTORY_THREEWAY` | `Init_CommonConstants.sqf:1741` | `NO-FLIP` | Victory-condition enum baseline. |

## Completeness Notes

- No `ORPHANED` rows were identified in the classified dark-feature set: every `FLIP-ON`, `OWNER-DECIDE`, and `HOLD-DARK` flag above has at least one current non-definition reference in maintained source or design documentation. Therefore no orphaned PR-number citations are required in this revision.
- The scan did not stop at the old AICOM block: post-1194 defaults are covered through `WFBE_C_FIX_RESPAWN_UNITQUEU_RESET` at `Init_CommonConstants.sqf:2030`, including artillery UI/shared cooldown, map-aware cleaners, camp scan throttle, command defense supply, ambient skirmish, IR smoke alias, factory queue hardening, vehicle markings/flags/tints, walls, respawn map zoom, and forward static manning.
## Lobby Defaults

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Parameters.hpp` still matters for dedicated multiplayer because `Init_Parameters.sqf` loads lobby params before `Init_CommonConstants.sqf`. This lane did not re-catalog every lobby enum. Use the table above for source flip decisions and verify any parameter-exposed flag in `Rsc/Parameters.hpp` before changing defaults.

`WFBE_C_GUER_SCAV` remains lobby-exposed in `Parameters.hpp:638` and defaults to `0`; it is a GUER wildcard/content decision, so treat it as `OWNER-DECIDE`, not a hygiene flip.

## Verification

- Re-read mission `AGENTS.md`, `docs/AGENT-HANDBOOK.md`, wiki `AGENTS.md`, and wiki `Agent-Guide` from current refs.
- Checked active branch `codex/hygiene-flag-census` stacked on `origin/codex/hygiene-hub-page`.
- Mechanically scanned `Init_CommonConstants.sqf` for 92 current `WFBE_C_* = 0` defaults and classified all real flip candidates above.
- Cross-checked previous docs: `docs/design/DARK-FLAGS-INVENTORY-2026-07-03.md`, `docs/design/DEFAULT-OFF-FEATURE-FLAG-READINESS-SWEEP.md`, and `docs/design/FLAG-SYSTEM-QUICK-REFERENCE.md`.
- Updated `docs/design/v2/V2-PROGRAM-HUB.md` row 454 to `DRAFT`.
- LoadoutManager not run because no mission source or generated mirror files changed.
