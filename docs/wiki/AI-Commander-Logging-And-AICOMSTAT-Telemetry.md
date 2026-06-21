# AI Commander Logging And AICOMSTAT Telemetry

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The AI commander has two distinct observability surfaces, both written to the server RPT via `diag_log`. The first is the **`WFBE_CO_FNC_AICOMLog` helper** (`Common/Functions/Common_AICommanderLog.sqf`): a deliberately always-on `[AICOM <type>] <message>` human-readable line used for narrative/diagnostic prose. The second is the **`AICOMSTAT|<ver>|<kind>|...` structured telemetry grammar**: a pipe-delimited, machine-parseable schema emitted across the `AI_Commander_*` files for an off-engine parser, dashboard, or A/B ledger. The two are independent of, and architecturally separate from, the general `Common_LogContent` logging (`[WFBE (...)]` lines, which are compiled out on live servers). This page is the contract/schema owner for both. For the runtime context in which the periodic block fires, see [AI-Commander-Execution-Loop-Reference](AI-Commander-Execution-Loop-Reference); for the toggle constant, see [AI-Commander-Tunable-Constants-Reference](AI-Commander-Tunable-Constants-Reference).

## Part 1 — The always-on `WFBE_CO_FNC_AICOMLog` helper

`Common/Functions/Common_AICommanderLog.sqf` is compiled to the global `WFBE_CO_FNC_AICOMLog` at `Common/Init/Init_Common.sqf:109`. Its entire body is a 7-line gate-and-format:

| Aspect | Detail | Source |
|---|---|---|
| Compile site | `WFBE_CO_FNC_AICOMLog = Compile preprocessFileLineNumbers "Common\Functions\Common_AICommanderLog.sqf";` | `Common/Init/Init_Common.sqf:109` |
| Signature | `_this = [_type, _msg]` — same arg shape as `WFBE_CO_FNC_LogContent` | `Common/Functions/Common_AICommanderLog.sqf:5,11-12` |
| Gate | `if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOG", 1]) > 0)` | `Common/Functions/Common_AICommanderLog.sqf:14` |
| Emit | `diag_log Format ["[AICOM %1] %2", _type, _msg]` | `Common/Functions/Common_AICommanderLog.sqf:15` |
| Default | gate defaults to `1` if unset (and is set to `1` in constants) | `Common/Functions/Common_AICommanderLog.sqf:14`, `Common/Init/Init_CommonConstants.sqf:167` |

### Why it is always-on (and how it differs from `Common_LogContent`)

The header comment (`Common_AICommanderLog.sqf:1-6`) states the design intent: `WF_LOG_CONTENT` is a compile-time define in the generated `version.sqf` and is therefore **OFF on live servers**, so the AI commander would be invisible in the RPT if it logged through the normal path. `AICOMLog` deliberately routes around that. Contrast the two helpers:

| | `WFBE_CO_FNC_LogContent` | `WFBE_CO_FNC_AICOMLog` |
|---|---|---|
| Gate | `if (LOG_CONTENT_STATE == "ACTIVATED")` | `if (WFBE_C_AI_COMMANDER_LOG > 0)` |
| Live-server state | compiled OFF (`LOG_CONTENT_STATE` not activated) | ON by default (`WFBE_C_AI_COMMANDER_LOG = 1`) |
| Line format | `[WFBE (%1)] [frameno:.. ticktime:.. fps:..] %5` | `[AICOM %1] %2` |
| Source | `Common/Functions/Common_LogContent.sqf:9,16` | `Common/Functions/Common_AICommanderLog.sqf:14-15` |

The gate constant is defined at `Common/Init/Init_CommonConstants.sqf:167`: `WFBE_C_AI_COMMANDER_LOG = 1;` with the comment "always-on [AICOM] diag_log (independent of WF_LOG_CONTENT; 0 to silence)." Set it to `0` to fully silence the helper. Note the `AICOMSTAT` lines in Part 2 are emitted by **raw `diag_log`**, not through this helper, so they are *not* silenced by this constant (see "Two channels" below).

### `_type` (log-level) convention

The first element is a free-text severity tag. Observed values across the ~90 call sites: `INITIALIZATION`, `INFORMATION`, and `WARNING`. The string is purely cosmetic (it is interpolated into `[AICOM %1]`, never compared), so a parser should treat it as an opaque level label.

| `_type` | Used for | Example site |
|---|---|---|
| `INITIALIZATION` | worker/supervisor startup | `Server/AI/Commander/AI_Commander.sqf:80`, `Server/Functions/AI_Commander_Wildcard.sqf:83` |
| `INFORMATION` | normal operational prose | `Server/AI/Commander/AI_Commander.sqf:128`, `Server/Functions/Server_AI_Com_Upgrade.sqf:113` |
| `WARNING` | recoverable faults / emergency GC | `Common/Functions/Common_CreateGroup.sqf:52,59`, `Common/Functions/Common_RunCommanderTeam.sqf:40` |

### Representative call sites

The helper has ~19 caller files. A few load-bearing ones:

| File:line | `_type` | What it reports |
|---|---|---|
| `Server/AI/Commander/AI_Commander.sqf:29` | INFORMATION | doctrine pick (primary factory path) |
| `Server/AI/Commander/AI_Commander.sqf:80` | INITIALIZATION | supervisor started for side |
| `Server/AI/Commander/AI_Commander.sqf:455` | INFORMATION | ROUND OVER summary (winner/doctrine/towns/funds) |
| `Common/Functions/Common_CreateGroup.sqf:52` | WARNING | emergency group GC near the 144/side cap |
| `Common/Functions/Common_RunCommanderTeam.sqf:74` | INFORMATION | commander team spawned (units/vehicles) |
| `Server/Functions/Server_AI_Com_Upgrade.sqf:113` | INFORMATION | upgrade research (supply/funds cost) |
| `Server/PVFunctions/RequestAIComDonate.sqf:91` | INFORMATION | accepted player donation to AI treasury |
| `Server/Functions/Server_HandleSpecial.sqf:235` | INFORMATION | HC commander team registered |

Several sites emit the AICOMLog prose line **and** an `AICOMSTAT` structured line back-to-back ("dual logging"): `AI_Commander_Wildcard.sqf:1274` (prose) + `:1275` (AICOMSTAT WILDCARD), `AI_Commander_Strategy.sqf:277` (prose FIRE MISSION) + `:277`/`Server_HandleSpecial` incidental mention. The prose is for humans reading the RPT; the AICOMSTAT line is for the parser.

## Part 2 — The `AICOMSTAT` telemetry grammar

`AICOMSTAT` lines are **raw `diag_log` string concatenations** (no `Format`, no helper). The grammar is a `|`-delimited record:

```
AICOMSTAT|<ver>|<kind>|<side>|<elapsedMin>|<kind-specific fields...>
```

| Position | Field | Meaning | Notes |
|---|---|---|---|
| 1 | literal `AICOMSTAT` | family prefix | distinguishes from sibling families (see below) |
| 2 | `<ver>` | `v1` or `v2` | schema version of *this line*, not the file |
| 3 | `<kind>` | `TICK` / `POSTURE` / `FRONT` / `END` / `EVENT` | top-level record kind |
| 4 | `<side>` | side identity | **heterogeneous** — see "Side field" |
| 5 | `<elapsedMin>` | `round (time / 60)` | round minutes since mission start |
| 6+ | kind-specific | positional (TICK/POSTURE/FRONT/END) or `key=value` (EVENT) | see per-kind tables |

### v1 vs v2 versioning

The version token marks the field layout of that record, so a parser keys `(kind, subtype, ver)` to a field map. `v1` records (`TICK`, `POSTURE`, `FRONT`, `END`, and the older positional EVENT subtypes) generally use bare positional fields. `v2` records (the newer EVENT subtypes added in the 2026-06 telemetry passes — `ECONOMY`, `ECONFLOW`, `COMBATSTAT`, `STRUCTURE_BUILT`, `ASSAULT_*`, `TOWN_FLIP`, `UPGRADE_RESEARCHED`, etc.) use explicit `key=value` pairs. A few subtypes exist in **both versions** with different layouts — `TEAM_FOUNDED` is emitted as `v2` (HC path, `AI_Commander_Teams.sqf:342`) and `v1` (server-local path, `:362`); `ARTY_THREAT_ARMED` is `v1` everywhere but with three different condition suffixes. Parse the version, then the subtype.

### Side field (parser caution)

The 4th field is **not uniform** — most emitters interpolate `str _side` or `_sideText` (which yield the side object's string, e.g. `WEST`/`EAST`/`GUER`), but a handful carry the **numeric sideID** instead:

| Form | Sites | Example value |
|---|---|---|
| `str _side` / `_sideText` (side string) | most EVENT/TICK/POSTURE/FRONT lines | `WEST` |
| `str _sideID` (numeric) | `Common/Functions/Common_RunCommanderTeam.sqf:373` (TEAM_RETIRE_HC) | `0` |
| both (carries `fromID`/`toID`) | `Server/FSM/server_town.sqf:248` (TOWN_FLIP) | side string in field 4, IDs in payload |

A parser should accept both a side-string and a small integer in field 4.

### `kind = TICK` (v1) — periodic snapshot

The supervisor emits one TICK per side every 300 s (the `_ltStat >= 300` block, `AI_Commander.sqf:259-294`). It is **positional**, not key=value (except the trailing `units=`):

`AICOMSTAT|v1|TICK|<side>|<elMin>|<towns>|<supply>|<funds>|<fTeams>|<eTeams>|<upgCsv>|units=<n>`

| Field | Computed from | Source |
|---|---|---|
| `<towns>` | count of `towns` whose `sideID` == this side | `AI_Commander.sqf:262` |
| `<supply>` | `GetSideSupply` if currency system 0, else `0` | `AI_Commander.sqf:263` |
| `<funds>` | `_side Call GetAICommanderFunds` | `AI_Commander.sqf:264` |
| `<fTeams>` | founded/HC teams (`wfbe_aicom_hc` or `wfbe_aicom_founded`) | `AI_Commander.sqf:265-273` |
| `<eTeams>` | other non-player live teams on side | `AI_Commander.sqf:267-271` |
| `<upgCsv>` | `:`-joined upgrade levels array | `AI_Commander.sqf:275-280` |
| `units=<n>` | live unit cache `wfbe_units_<side>` written by `server_groupsGC` | `AI_Commander.sqf:286-294` |

Emit: `AI_Commander.sqf:294`. The comment at `:259` notes this line is "ungated - always flows."

### `kind = POSTURE` / `FRONT` (v1) — strategy snapshots

Emitted unconditionally near the end of each strategy pass in `AI_Commander_Strategy.sqf` (key=value payload, `v1`):

| Kind | Field payload | Source |
|---|---|---|
| `POSTURE` | `<posture>|myTowns=|enTowns=|myStr=|enStr=|strikeOn=` where posture ∈ {`PRESS`,`HOLD`,...} | `AI_Commander_Strategy.sqf:240-243` |
| `FRONT` | `held=|enemyHeld=|contested=|primary=<townName/none>|onFront=` | `AI_Commander_Strategy.sqf:245` |

### `kind = END` (v1) — round verdict

One line per side at supervisor exit (round over), emitted "ungated regardless of LOG setting" (`AI_Commander.sqf:456`):

`AICOMSTAT|v1|END|<side>|<min>|<winner>|<doctrine>|<townsHeld>|<fundsLeft>`

Source `AI_Commander.sqf:457`. `<winner>` is `WF_Logic getVariable ["WF_Winner", sideUnknown]`, `<doctrine>` is `wfbe_aicom_doctrine`.

### `kind = EVENT` — the subtype catalogue

`EVENT` is the open-ended bucket; field 6 is the **subtype**, fields 7+ are subtype-specific. A parser keys on `(ver, subtype)`. Every subtype found in master, with emit site and key fields:

| Subtype | Ver | Emit site | Key fields after subtype |
|---|---|---|---|
| `ECONOMY` | v2 | `AI_Commander.sqf:310` | `funds= supply= netFunds= netSupply= towns=` |
| `ECONFLOW` | v2 | `AI_Commander.sqf:332` | `playerFunds= netPlayerFunds= aicomFunds= supply=` |
| `COMBATSTAT` | v2 | `AI_Commander.sqf:389` | `cas= vehLost= made= killed= netCas= netVehLost= netMade= netKilled=` |
| `SCAFFOLD_RESEARCH` | v1 | `AI_Commander.sqf:64` | `Convoys-PATROLS4` (literal) |
| `WEALTH_CONVERSION` | v1 | `AI_Commander.sqf:189` | `funds<n>` |
| `BOOTSTRAP_STIPEND` | v1 | `AI_Commander.sqf:205,210,213` | `start` / `end-first-town` / `end-timeout` |
| `SCAFFOLD_RESEARCH_REACTIVE` | v1 | `AI_Commander.sqf:247` | `CBRadar-1-2` (literal) |
| `POSTURE`/`FRONT`/`RELIEF`/`HQ_STRIKE`/`FIRE_MISSION` | v1 | `AI_Commander_Strategy.sqf:167,189,277` (RELIEF/HQ_STRIKE/FIRE_MISSION) | town name / `launched` / `<typeOf piece>` |
| `ARTY_THREAT_ARMED` | v1 | `AI_Commander_Base.sqf:245` (`cond-c`), `Server/PVFunctions/RequestOnUnitKilled.sqf:74` (`cond-a|count=`), `Server/Functions/Server_CounterBattery.sqf:53` (`cond-b|count=`) | `cond-a/b/c` + optional `count=` |
| `SCAFFOLD_BUILD` | v1 | `AI_Commander_Base.sqf:302` | `CBR= threat= Bank=` |
| `FACTORY_RALLY_SET` | v1 | `AI_Commander_Base.sqf:419` | `<typeOf site>|<rally>` |
| `STRUCTURE_BUILT` | v2 | `AI_Commander_Base.sqf:428` | `struct= cost= paidBy=<supply/free> branchOut=` |
| `HCDISPATCH` | v2 | `AI_Commander_Teams.sqf:121` | `pending= founded= target= pendingAgeSec=` |
| `TEAM_RETIRED` | v2 | `AI_Commander_Teams.sqf:151` | `reason=pc-scale founded= target= pc=` |
| `TEAM_FOUNDED` | v2 / v1 | `AI_Commander_Teams.sqf:342` (HC) / `:362` (server-local) | `via=HC template= class= cost=` / `server-local` |
| `TEAM_TYPED` | v2 | `AI_Commander_AssignTypes.sqf:125` | `via=server-local template= class=` |
| `ASSAULT_ARRIVED` | v2 | `AI_Commander_AssignTowns.sqf:95` | `team= town= dist= elapsed=` |
| `ASSAULT_STRANDED` | v2 | `AI_Commander_AssignTowns.sqf:103` | `team= town= dist= elapsed= moved= stuck=` |
| `UNSTUCK_STRIKE` | v2 | `AI_Commander_AssignTowns.sqf:371` | `team= tier=` |
| `ASSAULT_DISPATCH` | v2 | `AI_Commander_AssignTowns.sqf:400` | `team= town= dist= reissue=` |
| `TEAM_RETIRE_HC` | v1 | `Common/Functions/Common_RunCommanderTeam.sqf:373` | `deleted-local-units` (side field is **sideID**) |
| `UNSTUCK_FIRED` | v2 | `Common/Functions/Common_RunCommanderTeam.sqf:419` | `team= tier=` |
| `UPGRADE_RESEARCHED` | v2 | `Server/Functions/Server_AI_Com_Upgrade.sqf:118` | `id= lvl= supplyCost= fundsCost= paidBy=` |
| `UPGRADE_FUNDS_FALLBACK` | v1 | `Server/Functions/Server_AI_Com_Upgrade.sqf:134` | `id<n>-lvl<n>-surcharge<n>` |
| `UPRISING_DONE` | v2 | `Server/Functions/AI_Commander_Wildcard.sqf:788` | `cleared` |
| `CONVOY_DELIVERED` | v2 | `Server/Functions/AI_Commander_Wildcard.sqf:1004` | `supply=` |
| `WILDCARD_W<n>` | v2 | `Server/Functions/AI_Commander_Wildcard.sqf:1275` | `<result>|<detail>` |
| `DONATION` | v2 | `Server/PVFunctions/RequestAIComDonate.sqf:94` | `<donorName>|<amount>|wallet_after=` |
| `FIRST_TOWN` | v1 | `Server/FSM/server_town.sqf:227` | `<townName>-t<sec>` |
| `TOWN_FLIP` | v2 | `Server/FSM/server_town.sqf:248` | `town= from= to= fromID= toID=` |

### Two channels: AICOMLog vs AICOMSTAT gating

These are different RPT channels with different gates — do not conflate them:

| | `[AICOM ...]` prose | `AICOMSTAT|...` telemetry |
|---|---|---|
| Writer | `WFBE_CO_FNC_AICOMLog` helper | raw `diag_log (...)` string concat |
| Gate | `WFBE_C_AI_COMMANDER_LOG > 0` | none — deliberately ungated ("always flows", `AI_Commander.sqf:259,456`) |
| Audience | human reading the RPT | off-engine parser / dashboard / A/B ledger |
| Format | `[AICOM <type>] <msg>` | `AICOMSTAT|<ver>|<kind>|...` pipe record |

Setting `WFBE_C_AI_COMMANDER_LOG = 0` silences the prose but the `AICOMSTAT` telemetry keeps flowing.

## Sibling stat families (same RPT, different prefixes — NOT AICOMSTAT)

The supervisor's periodic block emits several **adjacent** structured families that share the `diag_log` channel and the `|v1|...` style but are **distinct prefixes** a parser must not fold into `AICOMSTAT`:

| Prefix | Emit site | Carries |
|---|---|---|
| `CMDRSTAT|v1` | `AI_Commander.sqf:369` | `srvTeams= hcTeams= foundedTeams= unitsPerTeam= remnants=` |
| `SRVPERF|v1` | `AI_Commander.sqf:401` | `fps= units= groups= veh= dead= activeTowns=` |
| `GRPBUDGET|v1` (+ `WARN`) | `AI_Commander.sqf:412,415` | per-side group count vs the 144/side cap |
| `HCDELEG|v1` | `AI_Commander.sqf:443` | per-HC owned-unit load + imbalance ratio |
| `ROUNDSTAT|v1` | `AI_Commander.sqf:469` | one server-global round summary (`arm= winner= townsW/E= ...`) |

These are documented at the runtime-loop level in [AI-Commander-Execution-Loop-Reference](AI-Commander-Execution-Loop-Reference); the player-economy analogue (`PLAYERSTAT`/`WASPSTAT`) lives in [Server-Broadcast-And-Telemetry-Loop-Reference](Server-Broadcast-And-Telemetry-Loop-Reference).

## Continue Reading

- [AI-Commander-Execution-Loop-Reference](AI-Commander-Execution-Loop-Reference) — the supervisor loop that fires the periodic TICK/ECONOMY/CMDRSTAT emit block.
- [AI-Commander-Tunable-Constants-Reference](AI-Commander-Tunable-Constants-Reference) — `WFBE_C_AI_COMMANDER_LOG` and the other commander toggles.
- [Commander-Team-Driver-Reference](Commander-Team-Driver-Reference) — `Common_RunCommanderTeam`, source of the `TEAM_RETIRE_HC` and `UNSTUCK_FIRED` lines.
- [Server-Broadcast-And-Telemetry-Loop-Reference](Server-Broadcast-And-Telemetry-Loop-Reference) — the `PLAYERSTAT`/`WASPSTAT` player-side telemetry analogue.
- [GLOBALGAMESTATS-Extension-Reference](GLOBALGAMESTATS-Extension-Reference) — the DLL/database.json stats path, distinct from RPT telemetry.
