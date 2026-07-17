# WASP Fresh-Eyes Review — KIMI lane 2026-07-17

**Scope:** Chernarus mission source (`Missions/[55-2hc]warfarev2_073v48co.chernarus/`) + local wiki mirror (`C:\Users\Steff\_wasp_wiki_claude`). Read-only review; no code or wiki edits.

**Methodology at a glance:** Read the wiki's own A2 OA trap pages first, then swept init/constants, server AICOM/Commander, GUER systems, client purchase/modules, and Common/Config price tables. Findings are cited as `path/file.sqf:line`. Verified by direct read where the number is used as evidence.

---

## 1. Executive Summary

The codebase is feature-rich but carries a growing "flag debt": many recently merged features are armed to `1` while their inline comments still describe a default-0/dark state. That makes the live configuration hard to discover and conflicts with the project's own flag policy. Beyond documentation drift, there are real mechanical gaps: GUER Director QRF units bypass standard unit-creation hooks, UAV purchase is client-authoritative and unvalidated, config registration races silently change prices/faction tags for shared classnames, and several recently shipped systems have no wiki page at all.

Highest-value take-away: **treat the current HEAD as effectively all-features-on**, then either reconcile the comments or deliberately dim the flags that are not ready for live play.

---

## 2. Mechanics / Code Findings

### 2.1 Feature-flag defaults and comments are out of sync

A recurring pattern in `Common/Init/Init_CommonConstants.sqf`: comments say "default 0 / off / byte-identical" but the value is `1`. This is the single biggest source of confusion for a fresh reader.

| Line | Flag | Comment claims | Value |
|------|------|----------------|-------|
| 105-106 | `WFBE_C_GUER_PLAYERSIDE` | "Default OFF = byte-for-byte today's behaviour" | `1` |
| 1784 | `WFBE_C_TOWN_SCAN_DICE` | "Default off = V1 behaviour" | `1` |
| 1805 | `WFBE_C_FIRSTBLOOD_ENABLED` | "Default 0 = off (inert)" | `1` |
| 1901 | `WFBE_C_DEFENSE_CLIENT_GATE_ALIGN` | "Default OFF" | `1` |
| 2077-2078 | `AICOMV2_LANE_GUER_DIRECTOR` | "Lane switch default 0 = inert" | `1` |
| 2093-2094 | `AICOMV2_GDIR_PANEL` | "panel switch AICOMV2_GDIR_PANEL default 0" | `1` |
| 2472-2474 | `WFBE_C_NOTABLE_KILL_FEED` | "Default 0 = off" | `1` |
| 2487-2489 | `WFBE_C_WALLS_V4` | "0 (default) ... V3 stays the live default look" | `1` |
| 2499-2501 | `WFBE_C_DEF_FORTIF_PACK` | "0 (default) = nothing is wired" | `1` |
| 2508-2523 | `WFBE_C_SML_*` (5 flags) | each says "Flag-gated default 0" / "Flag default 0" | all `1` |
| 2527-2533 | `WFBE_C_GUER_CP_V2` | "0 (default) = legacy v1" | `1` |
| 2536-2537 | `WFBE_C_CAMPS_LEGACY_SKIP_ON_PERCAMP_FLIP`, `WFBE_C_SKIP_EMPTY_CAMP_THREAD` | both "Default 0" | both `1` |
| 2562-2566 | `WFBE_C_AICOM_STUCK_REPAIR_RESETS_TIER` | "flag-gated default 0" | `1` |
| 2572-2573 | `WFBE_C_HC_CIV_RESLOT` | "Default 0 = byte-identical" | `1` |
| 2579-2580 | `WFBE_C_AIR_SPAWN_SAFETY` | "Default 0 = byte-identical" | `1` |
| 2586-2587 | `WFBE_C_GARRISON_DRESSING` | "0 = off (default)" | `1` |
| 2599-2600 | `WFBE_C_AIRFIELD_OWNERSHIP_GATE` | "0=off (default, byte-identical)" | `1` |
| 2605-2606 | `WFBE_C_FPV_DRONE` | "0=off (default)" | `1` |
| 2611 / 2619 | `WFBE_C_AWACS` | header says "flag WFBE_C_AWACS default 0" | `1` |
| 2629-2630 | `WFBE_C_EAST_C130` | "0=off (default)" | `1` |
| 2641-2642 | `WFBE_C_PLAYER_DEFENSE_AUTOMAN` | "0=off (current behaviour)" | `1` |
| 2686 | `AICOMV2_CTL_INVEST_ENABLE` | "0=off (default)" | `1` |
| 2701-2702 | `WFBE_C_UNITS_CREW_COST_TIERSCALE` | "Default 0 = byte-identical flat" | `1` |

Two flags are explicitly hard-set without `isNil`, so they cannot be dimmed from a parameter/lobby override:

- `Common/Init/Init_CommonConstants.sqf:603` — `WFBE_C_AI_COMMANDER_LOG = 1`; comment says "0 to silence".
- `Common/Init/Init_CommonConstants.sqf:1307-1308` — `WFBE_C_AICOM_SERVICE_ENABLED = 1`; comment says "rollback = set to 0".

**Impact:** the live configuration is not what the comments advertise. This defeats the purpose of flag-gating and makes soak analysis unreliable.

### 2.2 GUER-side systems

- **GUER Director QRF/counter-attack helis bypass standard creation hooks.** `Server/AI/Server_GuerDirector.sqf:455-498` and `Server/Functions/Server_BuyUnit.sqf:131` use raw `createVehicle` + `createGroup` + `WFBE_CO_FNC_CreateUnit` for QRF/counter-attack helicopters. They do not pass through `WFBE_CO_FNC_CreateVehicle`/`CreateUnit`, so they miss KA137 HP-mult EHs, AA-missile EHs, IRS smoke init, countermeasure stripping, vehicle-cargo clear, and `emptyQueu` handling.

- **GUER Director survivor accounting has a first-cycle blind spot.** `Server/AI/Server_GuerDirector.sqf:161-189` only applies a survivor ratio when `_lastGrpCount > 0`. If a town is wiped before the first active tick stores a non-zero count, losses are never registered and strength stays pinned at baseline.

- **GUER town-center barrel-bomb marker is created without a timeout.** `Server/Support/Support_GuerHeliDrop.sqf:113` creates a global `Incoming` marker but I found no corresponding deletion code in the same file; marker cleanup may rely on unrelated GC.

- **GUER group-cap deferral counts all resistance groups, not just garrisons.** `Server/FSM/server_town_ai.sqf:260` compares `_guerGroupCount >= _guerGroupsMax` using a count that includes side patrols, QRF helis, GUER player groups, and empty groups. A busy GUER Director can starve town garrisons.

- **GUER stipend scales off the initial town count forever.** `Server/Server_GuerStipend.sqf:30` captures `_startTownCount` once at startup and never updates it. It also has no tier decay, so GUER vehicle tier only ratchets up.

- **GUER gets three starting vehicles while WEST/EAST get two.** `Common/Config/Core_Root/Root_GUE.sqf:30` gives `['TT650_Gue','BRDM2_Gue','Offroad_DSHKM_Gue']`.

### 2.3 Purchase / build / economy

- **UAV purchase is client-authoritative, unvalidated, and underpriced relative to its cost.** `Client/Module/UAV/uav.sqf:50` directly runs `-12500 Call ChangePlayerFunds` with no fund check, no server authority, and no per-side cap. Contrast with FPV (`Client/Module/FPV/fpv.sqf:26-32`) and SCUD (`Common/Functions/Common_RequestIcbmTelPurchase.sqf`), which use server-certified purchase flows.

- **OPFOR UAV interface assumes a gunner seat that does not exist.** `Client/Module/UAV/uav.sqf:41-46` skips creating a gunner for OPFOR UAVs, yet `Client/Module/UAV/uav_interface.sqf:13-15` and `uav_interface_oa.sqf:13-15` call `remoteControl gunner _uav` and `gunner _uav removeWeapon "nvgoggles"`.

- **Vanilla UAV interface clamps speed using the altitude variable.** `Client/Module/UAV/uav_interface.sqf:78` checks `if (_newalt < 200)` when it clearly intends to bound `_newspeed`.

- **Driver-by-default toggle is reset every time the buy menu opens.** `Client/GUI/GUI_Menu_BuyUnits.sqf:47-49` force `wfbe_c_driver_enabled_by_default` back to `true` on dialog init, so the `:323-325` toggle is discarded on next open.

- **SEAD jets register two competing `Fired` handlers.** `Client/Functions/Client_BuildUnit.sqf:1135` adds `HandleAAMissiles` for `F35B`/`Su34`; `:1149` then adds `WFBE_CO_FNC_HandleSEADMissile` for the same two jets. A Maverick/Ch-29 launch triggers both guidance scripts.

- **SCUD factory-destruction refund does not match the displayed price.** `Client/Functions/Client_BuildUnit.sqf:395-399` refunds only `_currentCost`, but for SCUDs that is just the crew portion (`Client/GUI/GUI_Menu_BuyUnits.sqf:279-280`), while the buy dialog shows the full hull+crew price.

- **BuildUnit's nil-classname guard logs but does not abort.** `Client/Functions/Client_BuildUnit.sqf:22-29` warns on an unregistered classname yet continues; a direct call later reaches `_currentUnit select QUERYUNITTURRETS` at `:1287` and errors.

- **Air-spawn safety mixes `missionNamespace` and bare-variable reads.** `Client/Functions/Client_BuildUnit.sqf:629` gates on `missionNamespace getVariable "WFBE_C_AIR_SPAWN_SAFETY"`, but `:642` uses the bare identifier `WFBE_C_AIR_SPAWN_SAFETY` in a short-circuit condition.

- **Carrier fixed-wing handling can launch on land.** `Server/Functions/Server_BuyUnit.sqf:224-241` sets `_position set [2, deckz]` without verifying `surfaceIsWater` under `_position`. A land-built air factory with the carrier flag would launch a plane at 16 m AGL.

- **Forward-reinforce vehicle mount gate is 200 m and legacy.** `Server/Functions/Server_BuyUnit.sqf:289` only `addVehicle`s the new vehicle if `(_vehicle distance (leader _team) < 200)`. If the team leader is far away (forward reinforce) the driver may not auto-mount other positions.

### 2.4 AICOM / Commander / Town AI

- **AICOM team top-up request has no timeout/refund path.** `Server/AI/Commander/AI_Commander_Produce.sqf:173-207` charges the AI commander for HC-team replacements, but if the HC driver never consumes `wfbe_aicom_topup_req`, the side is charged with no refund. Stale requests can accumulate.

- **AICOM top-up log is unreachable when no class is found.** Same file, line 204 is inside `if (count _wm_infCls > 0)`, so there is no warning when the alias retry yields an empty class list.

- **CmdTownLedger `investT0` field is dead.** `Server/AI/Server_CmdTownLedger.sqf:157` writes `_rec select 4` (`investT0`) but it is never read elsewhere.

- **Town AI group cap counts non-garrison groups against GUER garrisons.** See 2.2 above (`server_town_ai.sqf:260`).

- **Victory checker uses an uninitialised `_winSide`.** `Server/FSM/server_victory_threeway.sqf:71-88` assigns `_winSide` inside a conditional block without declaring it private at scope start or initialising it. If no condition fires, the variable is stale/undefined.

### 2.5 UAV / FPV / Modules

- **UAV fund deduction is client-side and unchecked.** See 2.3 above.

- **UAV speed clamp uses altitude variable.** See 2.3 above.

- **OPFOR UAV gunner assumption.** See 2.3 above.

- **Supply mission can dereference a null town.** `Client/Module/supplyMission/supplyMissionStart.sqf:3-9` reads `_sourceTown getVariable` and sends a public variable without verifying `GetClosestFriendlyLocation` returned an object.

- **Officer skill branch is dead code.** `Client/Module/Skill/Skill_Apply.sqf:43-47` handles `case 'Officer'`, but `Client/Module/Skill/Skill_Init.sqf:54-58` never sets `WFBE_SK_V_Type` to `"Officer"`.

### 2.6 Config / balance anomalies

- **Global price races change costs for shared classnames.** First-write wins:
  - `Mi24_P` — GUER `$18,000` (`Core_GUE.sqf:128`) wins before RU `$32,600` (`Core_RU.sqf:129`), so EAST/RU pays the GUER price.
  - `Ka137_MG_PMC` — GUER `$6,000` (`Core_GUE.sqf:126`) wins before PMC `$3,500` (`Core_PMC.sqf:70`).
  - `BVP1_TK_ACR` — CDF `$2,200` (`Core_CDF.sqf:106`) wins before TKA `$2,900` (`Core_TKA.sqf:136`), and CDF fields it.

- **Faction role-price asymmetries.**
  - USMC `USMC_Soldier_AT` = `$700` (`Core_USMC.sqf:18`) vs US `US_Soldier_AT_EP1` = `$350` (`Core_US.sqf:21`) vs RU `RU_Soldier_AT` = `$310` (`Core_RU.sqf:18`).
  - EAST rocket artillery `GRAD_RU` = `$6,800` (`Core_RU.sqf:102`) vs WEST `MLRS` = `$8,500` (`Core_USMC.sqf:134` / `Core_US.sqf:188`).
  - `HMMWV` base jeep `$350` (`Core_USMC.sqf:76`) vs desert `HMMWV_DES_EP1` `$300` (`Core_US.sqf:93`).

- **Data-shape / metadata defects.**
  - `Core_TKCIV.sqf:65-69` — `Land_HBarrier5` and `Land_HBarrier_large` tuples have 9 elements (missing the upgrade field) versus the 10-element shape used elsewhere.
  - `Core_CDF.sqf:161` and `Core_INS.sqf:177` service-point entries have faction `'US'` instead of `'CDF'` / `'Insurgents'`.

- **Gear / loadout price gaps.**
  - `Loadout_RU.sqf:83-99` lists `m8_*` rifles, `AA12_PMC`, and `SMAW`, but `Gear_RU.sqf` never prices those weapons/magazines.
  - `Loadout_GUE.sqf:62-70` lists `Pecheneg`, `Saiga12K`, `RPG18`, and `Igla`, but `Gear_GUE.sqf` never prices them.

- **GUER Counter Battery Radar upgrade has no structure to build.** `Upgrades_GUE.sqf:28,55,57,84,122,148` defines CBRadar costs/times/links, but `Structures_CO_GUE.sqf` never adds a `CBRadar` structure. RU/US/TKA/West structures do include it.

- **Ka52 / Ka52Black price swings 44% behind a flag with no US counterpart.** `Core_RU.sqf:138,141` sets `$75,000` vs `$41,880 / $46,800` depending on `WFBE_C_UNITS_BALANCING`.

### 2.7 Init / versioning / boundary issues

- **`version.sqf.template` is inconsistent with live `version.sqf`.** `version.sqf.template:6` has release marker `20260704` vs `version.sqf:3` `20260703`; `:11` sets `WF_MAXPLAYERS 36` vs `version.sqf:8` `55`.

- **JIP fade watchdog duration mismatch.** `Client/Init/Init_Client.sqf:8` comment says the watchdog clears the black screen after **45 s**, but `:19-24` runs `for "_fk" from 1 to 90` with `uiSleep 1`, i.e. **90 s**.

- **Hardcoded Chernarus map size fallback.** `Server/Init/Init_Server.sqf:426` falls back to `15360` inside an egress check, while `Init_CommonConstants.sqf:625-632` already reads `CfgWorlds >> mapSize` properly.

- **Side-presence reads have no nil fallback.** `Server/Init/Init_Server.sqf:227-229` reads `WFBE_WEST_PRESENT` / `WFBE_EAST_PRESENT` / `WFBE_GUER_PRESENT` without a default. They are set in `Init_Common.sqf`, but a JIP timing change could leave them nil.

- **`profileNamespace` writes lack failure guards.** `Server/Init/Init_Server.sqf:542-544` and `:636-638` call `saveProfileNamespace` unconditionally. The rolling-average read at `:643` (`profileNamespace getVariable ["WFBE_RPAVG", [0,0]]`) never validates the returned shape.

- **Dead/commented code in server init.** `Server/Init/Init_Server.sqf:109`, `:131-132` leave commented-out duplicate compiles and a removed `monitorServerFPS` reference.

- **Redundant `isServer` guard inside server-only file.** `Server/Init/Init_Server.sqf:21-22` checks `if (isServer)` inside a file that already `exitWith`s at `:1` when `!isServer`.

---

## 3. Wiki-vs-Reality Gaps

### 3.1 Missing wiki pages for recently shipped systems

A grep of the local wiki found **no pages** for the systems the task brief called out. Each now has a live (or nearly live) implementation in source:

| System | Source location | Flag / default | Wiki page needed |
|--------|-----------------|----------------|------------------|
| **CTL** — Commander Town Ledger | `Server/AI/Server_CmdTownLedger.sqf:1`; launched `Server/Init/Init_Server.sqf:1116` | `AICOMV2_LANE_CMD_TOWN_LEDGER` = `0` (disarmed) | "Commander Town Ledger (CTL)" — virtual-strength model, capture seed, regen, AI investment tiers, garrison-link materializer. |
| **GUER Director V2** — AICOM V2 Lane 800 | `Server/AI/Server_GuerDirector.sqf:1`; launched `Server/Init/Init_Server.sqf:1109` | `AICOMV2_LANE_GUER_DIRECTOR` = `1` (armed) | "GUER Director V2" — ledger, cell movement, reinforcement/relief/retake, Commissar Panel, RPT telemetry families. |
| **FOB** — GUER Forward Operating Base | `Common/Init/Init_Unit.sqf:96`; client `Client/Action/Action_BuildFOB.sqf:1`; server `Server/PVFunctions/RequestFOBStructure.sqf:1` | gated on `WFBE_C_GUER_PLAYERSIDE` (default 1) | "GUER Forward Operating Base (FOB)" — truck types, placement rules, token economy, factory types. |
| **FM station** — WASP Vehicle Radio / Radio Tower | `WASP/Radio/Radio_Manager.sqf:1`; tower check `Common/Functions/Common_HasSideRadioTower.sqf:1` | `WFBE_C_STRUCTURES_RADIOTOWER` = `1` in SQF, **but `Rsc/Parameters.hpp:99` defaults to `0`** | "WASP Vehicle Radio / Radio Tower" — build cost, tower must stay alive, streams, vehicle action, client-side playback. |

Also worth noting: the barrel-bomb call-in (`WFBE_C_GUER_HELIBOMB_ENABLE` = `1`, 60-kill unlock) creates an `Incoming` marker and has no wiki page either.

### 3.2 Pages with stale or contradicted claims

- **`Wiki-Source-Consistency-Findings.md` § A (HIGH)** lists bugs claimed fixed that are still in source:
  - `Server/Functions/Server_AssignNewCommander.sqf:3` still has `_side = _this` (wiki claimed `_side = _this select 0`).
  - `Client/Functions/Client_BuildUnit.sqf:167-168` still uses a random `varQueu` token.
  - `Client/Functions/Client_BuildUnit.sqf:365` still `exitWith`s without decrementing the queue.
  - Both `RequestNewCommander.sqf:14` and `Server_AssignNewCommander.sqf:9` still send `new-commander-assigned`.

- **MASH marker relay is dead on both ends.** `Wiki-Quality-Audit.md` § C1 (HIGH) notes the `Networking-And-Public-Variables` page described the MASH server relay as live, but the receiver is commented at `Client/Init/Init_Client.sqf:132`, the trigger is never broadcast, and only an orphaned server PVEH remains. `Feature-Status-Register` already reflects this.

- **Channel-index / file:line drift persists.** `Wiki-Source-Consistency-Findings.md` § B/C lists wrong paths (`SERVER_FPS_GUI` location, `ATTACK_WAVE_DETAILS` direction, AFK directory name), stale client-bound PVF counts, and `Lifecycle-Wait-Chain` references that are systematically ~+10 lines high.

### 3.3 Default/value drift between source and documentation

- **Radio Tower is default-off in the lobby but default-on in SQF.** `Common/Init/Init_CommonConstants.sqf:1893` sets `WFBE_C_STRUCTURES_RADIOTOWER = 1`, but `Rsc/Parameters.hpp:95-100` overrides it to `default = 0`. Per project rules, `Parameters.hpp` wins, so the wiki should describe the feature as **default-disabled**.

- **`Feature-Status-Register.md` does not list CTL, GUER Director V2, FOB, or Radio Tower** in a way that a new reader can discover. The register's "Working / Active Systems" and "Partial / Deferred" sections mention older features (paratrooper markers, supply-scan narrowing, skill-init dedupe, hosted FPS loops) but not the four systems above.

- **GUER Director V2 design docs exist in `docs/design/v2/`** (`aicom-v2-800-guer-director.md`, `aicom-v2-commander-town-ledger.md`) but have no corresponding wiki pages, so players and most contributors cannot find them.

---

## 4. Top-10 Improvement Shortlist

| # | Size | Pitch | Why it matters |
|---|------|-------|----------------|
| 1 | **M** | Reconcile every `Init_CommonConstants.sqf` comment with its actual value, and decide which recently merged features are truly ready to be armed by default. | Eliminates the biggest fresh-eyes confusion and restores the flag policy's intent. |
| 2 | **S** | Route GUER Director QRF/counter-attack helis through `WFBE_CO_FNC_CreateVehicle`/`CreateUnit` so they receive the same EHs, cargo clear, and GC hooks as normal AI buys. | Fixes a real consistency/bug gap in a live feature path. |
| 3 | **M** | Add server-authoritative validation and fund check to UAV purchase (`Client/Module/UAV/uav.sqf:50`), matching FPV/SCUD flows. | Closes an economy exploit and removes client-side authority. |
| 4 | **S** | Stop resetting the driver-by-default toggle on every buy-menu open (`Client/GUI/GUI_Menu_BuyUnits.sqf:47-49`). | Small UX win that players will notice immediately. |
| 5 | **M** | Audit global classname registration races (`Mi24_P`, `Ka137_MG_PMC`, `BVP1_TK_ACR`, `Pchela1T`) and separate price/faction metadata from the shared global entry where needed. | Stops silent cross-faction price/tag corruption. |
| 6 | **S** | Add a CBRadar structure to `Structures_CO_GUE.sqf` or remove the CBRadar upgrade line from `Upgrades_GUE.sqf`. | Removes a dead upgrade path. |
| 7 | **M** | Create wiki pages for CTL, GUER Director V2, GUER FOB, and WASP Vehicle Radio / Radio Tower, and update `Feature-Status-Register.md` to list them. | Closes the documentation gap the task brief identified. |
| 8 | **S** | Fix UAV interface speed clamp (`Client/Module/UAV/uav_interface.sqf:78`) and OPFOR gunner assumption (`uav_interface.sqf:13-15`). | Fixes two clear module bugs. |
| 9 | **S** | Align `version.sqf.template` with live `version.sqf` (date, max players) so the template is a trustworthy reference. | Stops deployment confusion. |
| 10 | **M** | Add an RPT/telemetry review pass for the GUER Director: log the first-cycle survivor count, confirm marker cleanup for barrel bombs, and validate that group-budget stewardship does not starve town garrisons. | Turns the live-but-unsoaked Director into a measured, tunable system. |

---

## 5. Methodology

1. Read wiki trap/reference pages first: `Arma-2-OA-Command-Version-Reference.md`, `Arma-2-OA-Compatibility-Audit.md`, `AI-Assistant-Developer-Guide.md`.
2. Read current-status pages: `Current-Source-Status-Snapshot.md`, `Feature-Status-Register.md`, `Wiki-Source-Consistency-Findings.md`, `Wiki-Quality-Audit.md`.
3. Swept source in parallel across: init/constants, Server/AI/Commander, Server/Functions, Client/GUI, Client/Module, Common/Functions, Common/Config.
4. Verified every file:line citation used as evidence by direct read of the named file.
5. No code changes were made; this document is the sole deliverable.
