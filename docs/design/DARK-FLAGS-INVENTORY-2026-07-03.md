# Dark Flags Inventory - 2026-07-03

## Scope

Lane 186 requested a mechanical inventory of `WFBE_C_*` flags that default to
`0` and therefore leave optional behavior dark on `claude/build84-cmdcon36`.
This report is documentation only: no mission source, lobby parameters, wiki
pages, generated mission output, live deploy artifacts, or package files were
changed.

The scan source was the Chernarus source mission because maintained terrain
copies are generated from it unless a lane is explicitly mission.sqm-specific.

## Counting Rules

Counted:

- `WFBE_C_*` values in `Common/Init/Init_CommonConstants.sqf` where `0` means
  off, inert, legacy behavior, disabled, or "not opted in".
- Lobby parameter classes in `Rsc/Parameters.hpp` where default `0` exposes an
  off or baseline choice to hosts.

Not counted:

- Side IDs, counters, coefficients, ranges, prices, caps, timestamps, and map
  coordinates where `0` is only a numeric value.
- Defaults where the feature is already on and `0` only disables it.
- Historical comments that mention `WFBE_C_* = 0` but do not define the current
  live default.

## Dark Source Flags

| Flag | Source | Flip effect | Owner-risk class |
| --- | --- | --- | --- |
| `WFBE_C_GUER_IMPROVISED_ARMOR` | `Common/Init/Init_CommonConstants.sqf:93` | Enables the GUER improvised armor damage-reduction path. | Medium: combat balance |
| `WFBE_C_AICOM_PUBLIC_STATE_SYNC` | `Common/Init/Init_CommonConstants.sqf:252` | Broadcasts AICOM funds/running state to side logic for HC readers. | Medium: replication/locality |
| `WFBE_C_TOWNS_STARTUP_SLEEP` | `Common/Init/Init_CommonConstants.sqf:255` | Adds optional pacing to town AI startup passes. | Low: startup performance |
| `WFBE_C_AI_DELEGATION` | `Common/Init/Init_CommonConstants.sqf:261` | Enables client/HC AI delegation modes. | High: HC locality |
| `WFBE_C_OILFIELD_GUER_RAID` | `Common/Init/Init_CommonConstants.sqf:376` | Adds occasional GUER foot raids against paying oilfields. | Medium: AI volume |
| `WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE` | `Common/Init/Init_CommonConstants.sqf:430` | Replaces the legacy 10 km artillery-threat scan with the tunable radius. | Low: AICOM scan tuning |
| `WFBE_C_AI_COMMANDER_ARTILLERY` | `Common/Init/Init_CommonConstants.sqf:505` | Lets AICOM use/build artillery paths that are currently hard-dark. | High: owner-locked artillery |
| `WFBE_C_SIM_GATING` | `Common/Init/Init_CommonConstants.sqf:506` | Would enable AI simulation gating far from active towns. | High: owner-rejected sim gating |
| `WFBE_C_AICOM_BOOTSTRAP_SUPPLY_ENABLE` | `Common/Init/Init_CommonConstants.sqf:581` | Lets AICOM bootstrap supply while in dual-currency mode. | Medium: economy/AICOM |
| `WFBE_C_SEC_HARDENING` | `Common/Init/Init_CommonConstants.sqf:608` | Arms anti-forgery guards behind the existing hardening switch. | High: security false-positive risk |
| `WFBE_C_AICOM_FUNDS_SINK_ENABLE` | `Common/Init/Init_CommonConstants.sqf:623` | Arms the AICOM funds-sink worker on the income cadence. | Medium: AI economy |
| `WFBE_C_ENDGAME_FORCE_ENABLE` | `Common/Init/Init_CommonConstants.sqf:635` | Arms the late-round income taper / soft-forcing path. | High: match pacing |
| `WFBE_C_AICOM_PLAYER_ARTY` | `Common/Init/Init_CommonConstants.sqf:698` | Enables the separate player-requested AICOM artillery helper. | High: artillery owner gate |
| `WFBE_C_AICOM_HELI_APPROACH_LIMITED` | `Common/Init/Init_CommonConstants.sqf:718` | Slows AICOM transport helis to LIMITED on final LZ approach. | Medium: aircraft behavior |
| `WFBE_C_AICOM_FOUND_REQUIRE_FACTORY` | `Common/Init/Init_CommonConstants.sqf:820` | Requires matching owned factories before founding AICOM team types. | Medium: AICOM starvation risk |
| `WFBE_C_AICOM_OVERRUN_SCRIPTRAZE` | `Common/Init/Init_CommonConstants.sqf:839` | Re-enables scripted siege-timer razing instead of real destruction only. | High: victory/base assault semantics |
| `WFBE_C_AICOM_STRIKE_COMMIT` | `Common/Init/Init_CommonConstants.sqf:854` | Protects progressing teams from HQ-strike grabs. | Medium: AICOM strategy |
| `WFBE_C_NAVAL_WEST_AAV` | `Common/Init/Init_CommonConstants.sqf:886` | Enables WEST AAV buy-row metadata for future naval beach-assault work. | Low: dormant metadata |
| `WFBE_C_PERFORMANCE_AUDIT_SIDE_PATROL_PROBES` | `Common/Init/Init_CommonConstants.sqf:898` | Adds extra PerformanceAudit records around side-patrol dispatch/feed work. | Low: telemetry volume |
| `WFBE_C_SERVER_FPS_GUI_ACTIVE_PLAYERS_ONLY` | `Common/Init/Init_CommonConstants.sqf:899` | Sends server FPS GUI only while non-HC humans are connected. | Low: telemetry/UI |
| `WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY` | `Common/Init/Init_CommonConstants.sqf:900` | Changes side-patrol feed broadcasts from fixed cadence to change/keepalive. | Medium: marker freshness |
| `WFBE_C_AICOM_HC_MERGE_ENABLE` | `Common/Init/Init_CommonConstants.sqf:1074` | Enables the same-HC depleted-team merge pass. | High: HC team ownership |
| `WFBE_C_ARTILLERY_UI` | `Common/Init/Init_CommonConstants.sqf:1091` | Enables direct-fire artillery UI scripts. | Medium: module/UI |
| `WFBE_C_BASE_EGRESS_MAP_BOUNDS` | `Common/Init/Init_CommonConstants.sqf:1118` | Uses map-aware bounds for random-start egress checks. | Low: map parity |
| `WFBE_C_CLEANER_MAP_AWARE_ORIGINS` | `Common/Init/Init_CommonConstants.sqf:1120` | Uses map-aware cleaner/restorer scan centers and radii. | Low: map parity |
| `WFBE_C_TOWN_CAMP_SCAN_THROTTLE` | `Common/Init/Init_CommonConstants.sqf:1142` | Adds slower sleeps to the camp scan loop. | Low: performance tuning |
| `WFBE_C_GAMEPLAY_MISSILES_RANGE` | `Common/Init/Init_CommonConstants.sqf:1322` | Applies guided-missile range limiting when nonzero. | Medium: weapon behavior |
| `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE` | `Common/Init/Init_CommonConstants.sqf:1326` | Starts upgrades pre-cleared for selected sides when nonzero. | Medium: progression rules |
| `WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC` | `Common/Init/Init_CommonConstants.sqf:1335` | Publishes stopped-engine stealth state across locality changes. | Medium: vehicle stealth state |
| `WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL` | `Common/Init/Init_CommonConstants.sqf:1336` | Shows the recorded GUER stats as a third endgame column. | Low: UI |
| `WFBE_C_FIX_VOTE_LIST_PRUNE` | `Common/Init/Init_CommonConstants.sqf:1337` | Uses safer reverse-pass vote-dialog row pruning. | Low: UI correctness |
| `WFBE_C_FIX_VOTE_QA_EXECUTION` | `Common/Init/Init_CommonConstants.sqf:1338` | Enables vote QA follow-up fixes for stored-index colors and placeholder confirms. | Low: UI correctness |
| `WFBE_C_FIX_IRSMOKE_PARAM_ALIAS` | `Common/Init/Init_CommonConstants.sqf:1347` | Aliases lobby IRS naming to runtime IRSMOKE naming. | Low: parameter compatibility |
| `WFBE_C_WAYPOINT_WATER_RETRY_CAP` | `Common/Init/Init_CommonConstants.sqf:1430` | Caps random patrol waypoint water rerolls when nonzero. | Low: pathing safety |
| `WFBE_C_TOWNS_REINFORCEMENT_DEFENDER` | `Common/Init/Init_CommonConstants.sqf:1431` | Enables town defender reinforcements. | Medium: AI volume |
| `WFBE_C_TOWNS_REINFORCEMENT_OCCUPATION` | `Common/Init/Init_CommonConstants.sqf:1432` | Enables town occupation reinforcements. | Medium: AI volume |
| `WFBE_C_STRUCTURES_FLAT_CHECK` | `Common/Init/Init_CommonConstants.sqf:1472` | Re-enables the player flat-ground structure placement gate. | High: Takistan base placement |
| `WFBE_C_RESTART_ENABLED` | `Common/Init/Init_CommonConstants.sqf:1519` | Enables the in-game restart announcer. | Low: operations messaging |
| `WFBE_C_FIX_FACTORY_QUEUE_TOKEN_HARDENING` | `Common/Init/Init_CommonConstants.sqf:1558` | Uses stronger player-buy FIFO tokens. | Medium: factory queue behavior |
| `WFBE_C_SKIN_SELECTOR` | `Common/Init/Init_CommonConstants.sqf:1573` | Enables the legacy join-time skin selector gate. | Low: player UX |
| `WFBE_C_VEHICLE_MARKINGS` | `Common/Init/Init_CommonConstants.sqf:1574` | Enables per-side vehicle recognition markings and body-skin path. | High: FPS/cosmetic risk |
| `WFBE_C_VEHICLE_FLAGS` | `Common/Init/Init_CommonConstants.sqf:1578` | Attaches flag objects to created vehicles. | High: object-count/FPS risk |
| `WFBE_C_VEHICLE_TINTS` | `Common/Init/Init_CommonConstants.sqf:1584` | Applies faction body tints to vehicles. | Medium: cosmetic coverage |
| `WFBE_C_WALLS_V2` | `Common/Init/Init_CommonConstants.sqf:1725` | Remains registered but is documented as dead/reverted wall-ladder code. | Low: dead flag cleanup |

## Lobby Defaults With Baseline 0

These are not all "dark feature" flags, but they are host-visible `WFBE_C_*`
parameters whose default is `0` and therefore belong on the same owner
decision surface.

| Parameter | Source | Default-0 meaning | Owner-risk class |
| --- | --- | --- | --- |
| `WFBE_C_AI_TEAMS_JIP_PRESERVE` | `Rsc/Parameters.hpp:53` | Do not keep AI across JIP/team changes. | Medium: AI/JIP |
| `WFBE_C_AI_TEAMS_ENABLED` | `Rsc/Parameters.hpp:59` | Player AI teams disabled. | Medium: player-AI availability |
| `WFBE_C_ARTILLERY_UI` | `Rsc/Parameters.hpp:71` | Direct-fire artillery UI disabled. | Medium: module/UI |
| `WFBE_C_ECONOMY_CURRENCY_SYSTEM` | `Rsc/Parameters.hpp:149` | Funds plus supply economy, not funds-only. | Medium: economy rules |
| `WFBE_C_ENVIRONMENT_WEATHER` | `Rsc/Parameters.hpp:213` | Clear weather. | Low: environment |
| `WFBE_C_UNITS_PRICING` | `Rsc/Parameters.hpp:305` | Default unit pricing, no specialization focus. | Medium: economy balance |
| `WFBE_C_UNITS_TRACK_INFANTRY` | `Rsc/Parameters.hpp:317` | Infantry tracking disabled. | Low: map marker volume |
| `WFBE_C_RESPAWN_LEADER` | `Rsc/Parameters.hpp:462` | Leader respawn disabled. | Medium: respawn rules |
| `WFBE_C_RESPAWN_PENALTY` | `Rsc/Parameters.hpp:474` | Respawn penalty disabled. | Medium: player economy |
| `WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER` | `Rsc/Parameters.hpp:558` | Defender town vehicles do not get this lock mode. | Medium: town vehicle access |
| `WFBE_C_TOWNS_STARTING_MODE` | `Rsc/Parameters.hpp:564` | Towns start in the normal resistance setup. | Medium: match start shape |
| `WFBE_C_GUER_SCAV` | `Rsc/Parameters.hpp:645` | GUER scavenger wildcard disabled. | Medium: GUER wildcard content |

## Highest-Risk Flip Buckets

- **Owner-locked or explicitly risky:** `WFBE_C_AI_COMMANDER_ARTILLERY`,
  `WFBE_C_AICOM_PLAYER_ARTY`, `WFBE_C_SIM_GATING`,
  `WFBE_C_STRUCTURES_FLAT_CHECK`.
- **HC/locality-sensitive:** `WFBE_C_AI_DELEGATION`,
  `WFBE_C_AICOM_HC_MERGE_ENABLE`, `WFBE_C_AICOM_PUBLIC_STATE_SYNC`.
- **FPS/object-count-sensitive cosmetics:** `WFBE_C_VEHICLE_MARKINGS`,
  `WFBE_C_VEHICLE_FLAGS`, `WFBE_C_VEHICLE_TINTS`.
- **Round-pacing/economy levers:** `WFBE_C_ENDGAME_FORCE_ENABLE`,
  `WFBE_C_AICOM_FUNDS_SINK_ENABLE`, `WFBE_C_AICOM_BOOTSTRAP_SUPPLY_ENABLE`,
  `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE`.

## Validation

- Searched current `github/claude/build84-cmdcon36@b1608b096`.
- Scanned `Common/Init/Init_CommonConstants.sqf` for `WFBE_C_* = 0`
  definitions and filtered out non-switch numeric constants.
- Scanned `Rsc/Parameters.hpp` for default-zero `WFBE_C_*` parameter
  classes, especially `{0,1}` toggle surfaces.
- Changed-file scope is docs-only; LoadoutManager was not run because no
  mission source changed.
