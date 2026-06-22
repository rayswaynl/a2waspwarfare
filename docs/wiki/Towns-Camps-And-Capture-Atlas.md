# Towns, Camps And Capture Atlas

> Canonical map for town object initialization, camp setup, capture/SV state, marker visibility, town AI activation and economy consumers. Use this with [Economy, towns and supply](Economy-Towns-And-Supply), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety), [Supply mission architecture](Supply-Mission-Architecture) and [Victory/endgame findings](Deep-Review-Findings).

## Why This Matters

Towns are the spine of Warfare. A town is not just a marker on the map: it is a synchronized mission logic object with ownership, supply value, camps, depot/camp models, capture state, marker visibility state, AI activation state, town defenses, income/supply output, supply mission cooldowns and victory implications.

The important split:

- `mission.sqm` and common init define town/camp objects and their initial variables;
- server init assigns starting ownership and starts the global town loops;
- `server_town.sqf` owns town capture, SV drain/regeneration and town-side transitions;
- `server_town_camp.sqf` owns camp capture as one global manager;
- `server_town_ai.sqf` owns AI activation/deactivation and active-town visibility state;
- client PV functions and marker loops render state and award some local bounties.

Do not patch town capture, town AI, supply missions, income, victory, or marker visibility as unrelated systems without checking this page first.

## How To Use This Page

| Need | Start here |
| --- | --- |
| Broad town/camp architecture | [Source Files](#source-files), [Bootstrap Chain](#bootstrap-chain), [Capture Ownership Chain](#capture-ownership-chain) |
| Current branch truth before citing line anchors | [Current Branch Scope](#current-branch-scope) |
| Camp flag or zero-camp helper patch planning | [Camp Capture](#camp-capture), [Camp Helper Risks](#camp-helper-risks), [Feature status](Feature-Status-Register) |
| Current patrol behavior | [Patrols v2 Side-Upgrade Path](#patrols-v2-side-upgrade-path) |
| Pre-Patrols v2 / DR-57 history | [Historical Town Patrol Mechanic](#historical-town-patrol-mechanic-pre-patrols-v2) |
| Economy, side supply or supply missions | [Economy And Victory Consumers](#economy-and-victory-consumers), [Economy, towns and supply](Economy-Towns-And-Supply), [Supply mission architecture](Supply-Mission-Architecture) |
| Town AI vehicle safety or HC behavior | [Town AI Activation](#town-ai-activation), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) |

## Current Branch Scope

Checked 2026-06-14 after `git fetch --all --prune`. Docs head `5243f91d` has no checked town/camp/patrol/respawn/buy source-path changes from the earlier `3eefcb00` atlas checkpoint, so the docs-checkout line anchors below still apply. Rechecked the Patrols v2 path on 2026-06-21: docs branch `docs/developer-wiki-index@d30d2346` is unchanged from `5243f91d` for the checked Patrols source paths, current stable is `origin/master@0139a346`, and current origin exposes no live `release/*` heads. Zero-camp helper/caller refs were refreshed again on 2026-06-22: docs branch `docs/developer-wiki-index@ade4d356` is unchanged from `5243f91d` for the checked helper/consumer paths, current stable is still `origin/master@0139a346`, and current origin exposes no live `release/*`, `feat/*camp*` or `feat/*town*` heads. Camp flag/repair refs were refreshed on 2026-06-22 against docs branch `docs/developer-wiki-index@28a7d9c5`, current stable `origin/master@0139a346`, Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f`, historical `a96fdda2`, active B69 `origin/claude/b69@0a1ccb4d` and new `origin/feat/naval-hvt-objectives@2e1c5931`. Treat older `89ae9dad` text below as historical unless this table preserves it for a still-relevant branch.

| Ref / root scope | Camp flag branch truth | Patrol branch truth | Zero-camp helper truth |
| --- | --- | --- | --- |
| Docs branch `docs/developer-wiki-index@28a7d9c5` (camp paths unchanged from `5243f91d`) | Chernarus and maintained Vanilla write captured camp `sideID` to `_newSID` at `server_town_camp.sqf:132`, then set the flag from old `_side` at `:135`; `repair-camp` changes `sideID` at `Server_HandleSpecial.sqf:165` and broadcasts at `:168` without a flag refresh. | No `Server/FSM/server_side_patrols.sqf` exists in either maintained root; old town-patrol source remains the docs-checkout shape. | Both maintained roots keep `Common_GetTotalCamps.sqf:10` and `Common_GetTotalCampsOnSide.sqf:16` returning `1`; consumers include `server_town.sqf:179-195`, `Common_GetRespawnThreeway.sqf:7`, `Client_GetRespawnAvailable.sqf:69` and `GUI_Menu_BuyUnits.sqf:111-112`. |
| Current stable `origin/master@0139a346` | Chernarus and maintained Vanilla fix independent capture: `server_town_camp.sqf:83-86` writes `_newSID`, sets texture from `str _newSide` at `:84`, then broadcasts `CampCaptured`; `repair-camp` still changes side/broadcasts at `Server_HandleSpecial.sqf:468,471` without a flag refresh. | Patrols v2 is present in both maintained roots: `WFBE_UP_PATROLS = 23` and `WFBE_C_SIDE_PATROLS_MAX = 2` at `Init_CommonConstants.sqf:60,63`, defender cap at `:683`, runner compile at `Init_Common.sqf:107`, server driver start at `Init_Server.sqf:690`, friendly marker loop at `Init_Client.sqf:405`, and level-4 convoy/camp-sweep hooks in `Common_RunSidePatrol.sqf:18,91,108,148,245,247`. | Helper fallback is unchanged; current-master consumers line-drift to `server_town.sqf:167-183`, `Client_GetRespawnAvailable.sqf:92` and `GUI_Menu_BuyUnits.sqf:120-121`. |
| Miksuu `master` `b8389e74` | Chernarus and maintained Vanilla still set independent capture flags from old `_side` at `server_town_camp.sqf:89`; `repair-camp` still has no flag refresh at `Server_HandleSpecial.sqf:263,266`. | No Patrols v2 startup hits were found in the checked constants/init paths; treat it as the older town-patrol lineage for this atlas. | Helper fallback is unchanged; consumers are `server_town.sqf:163-179`, `Client_GetRespawnAvailable.sqf:69` and `GUI_Menu_BuyUnits.sqf:111-112`. |
| `origin/perf/quick-wins` `0076040f` | Chernarus fixes independent capture at `server_town_camp.sqf:135`; maintained Vanilla still uses old `_side` at `:135`; `repair-camp` still has no flag refresh at `Server_HandleSpecial.sqf:243,246`. | No Patrols v2 startup hits were found in the checked constants/init paths; the older Chernarus patrol-worker loop fix is not the current side-upgrade driver. | Helper fallback is unchanged; consumers match the older docs-checkout line shape: `server_town.sqf:179-195`, `Client_GetRespawnAvailable.sqf:69` and `GUI_Menu_BuyUnits.sqf:111-112`. |
| Historical release commit `a96fdda2` | Chernarus and maintained Vanilla fix independent capture at `server_town_camp.sqf:83-86`; `repair-camp` still changes side/broadcasts at `Server_HandleSpecial.sqf:263,266` without a flag refresh. | The historical release commit keeps the older release patrol changes and the maintained-root `server_patrols.sqf:26` loop-exit fix, but no Patrols v2 startup hits were found in the checked constants/init paths. Current origin exposes no live `release/*` heads on 2026-06-22. | Helper fallback is unchanged; consumers line-drift to `server_town.sqf:163-179`, `Client_GetRespawnAvailable.sqf:56` and `GUI_Menu_BuyUnits.sqf:117-118`. |

Active B69 branch note, checked 2026-06-22: `origin/claude/b69@0a1ccb4d` keeps the current-stable independent-capture flag fix in both maintained roots (`server_town_camp.sqf:83-86`). Its `repair-camp` path still lacks a flag refresh, with Chernarus line drift to `Server_HandleSpecial.sqf:491,494` and maintained Vanilla matching current stable at `:468,471`. B69 also keeps the same zero-camp helper fallback in both maintained roots (`Common_GetTotalCamps.sqf:10`, `Common_GetTotalCampsOnSide.sqf:16`); its helper consumers drift to `server_town.sqf:188-204`, `Client_GetRespawnAvailable.sqf:92` and `GUI_Menu_BuyUnits.sqf:120-121`. Keep B69 feature-readiness status on the AI commander pages rather than treating this as a stable/master fix.

New feature branch note, checked 2026-06-22: `origin/feat/naval-hvt-objectives@2e1c5931` touches town-related files and `Server_HandleSpecial.sqf`, but keeps current-stable independent-capture flag behavior in both maintained roots (`server_town_camp.sqf:83-86`). Its `repair-camp` path still changes side and broadcasts without a flag refresh, with line drift to Chernarus `Server_HandleSpecial.sqf:477,480` and maintained Vanilla `:467,470`.

## Source Files

| Area | Files |
| --- | --- |
| Mission objects | `mission.sqm:124-128` first town example, `mission.sqm:3265` WF_Logic town-removal lists and `Init_TownMode.sqf` call |
| Town amount mode | `Common/Init/Init_TownMode.sqf:3-23` |
| Per-town init | `Common/Init/Init_Town.sqf:1-165` |
| Common town wait | `Common/Init/Init_Towns.sqf:3-15` |
| Starting ownership / Patrols v2 handoff | `Server/Init/Init_Towns.sqf:3-185`; `Server/FSM/server_side_patrols.sqf:1-72` |
| Server loop startup | Docs checkout `Server/Init/Init_Server.sqf:507-533`; current stable Patrols v2 line drift `Init_Server.sqf:676,690` |
| Town capture / SV loop | `Server/FSM/server_town.sqf:12-276` |
| Camp capture manager | `Server/FSM/server_town_camp.sqf:1-160` |
| Town AI activation | `Server/FSM/server_town_ai.sqf:1-240` |
| Town unit creation | `Common/Functions/Common_CreateTownUnits.sqf:11-79` |
| Capture client PVFs | `Client/PVFunctions/TownCaptured.sqf`, `Client/PVFunctions/CampCaptured.sqf`, `Client/PVFunctions/AllCampsCaptured.sqf` |
| PVF registration | `Common/Init/Init_PublicVariables.sqf:25-35` |
| Client town markers | `Client/FSM/updatetownmarkers.sqf:1-136` |
| Economy consumers | `Common_GetTownsSupply.sqf`, `Common_GetTownsIncome.sqf`, `Common_GetTownsHeld.sqf`, `Server/FSM/updateresources.sqf` |

## Bootstrap Chain

`mission.sqm` is part of runtime, not just editor data. Each `LocationLogicDepot` object calls `Common\Init\Init_Town.sqf` with:

- town logic object;
- display name;
- dubbing name or `+`;
- starting SV;
- max SV;
- town value;
- town type/template.

Example: `mission.sqm:124-128` initializes Kamenka with `Init_Town.sqf` and disables simulation on the logic object.

`WF_Logic` at `mission.sqm:3265` stores several `Towns_Removed*` arrays and starts `Common\Init\Init_TownMode.sqf`. `Init_TownMode.sqf` waits for `WFBE_Parameters_Ready`, picks the removal template from `WFBE_C_TOWNS_AMOUNT`, counts `LocationLogicDepot` objects and sets `townModeSet = true` (`Init_TownMode.sqf:3-21`).

`Init_Town.sqf` waits for both `townModeSet` and `WFBE_Parameters_Ready` (`:18`). It then:

- exits disabled towns listed in `TownTemplate` (`:23-27`);
- sets town name, range, starting SV, max SV and supply mission seed variables (`:31-36`);
- resolves random town type templates (`:38-40`);
- on the server, finds synchronized camps and defense logic objects (`:44-64`);
- creates the depot model and initializes `sideID` / `supplyValue` if absent (`:81-88`);
- creates camp bunkers and flags, initializes camp `sideID`, `supplyValue`, `wfbe_camp_bunker` and `wfbe_flag` (`:96-127`);
- registers the town's camps with the global camp manager (`:129-130`);
- waits for `townInitServer` before creating initial defenses (`:134-139`);
- on clients, creates local camp marker names (`:149-158`);
- finally appends the town to the global `towns` array (`:165`).

`Common/Init/Init_Towns.sqf` waits until every depot logic has `sideID` or `wfbe_inactive`, then sets `townInit = true` (`:6-13`).

## Starting Ownership

After common town init, current stable `origin/master@0139a346` calls `Server\Init\Init_Towns.sqf` when a special starting mode or the patrol parameter is enabled; otherwise it sets `townInitServer = true` directly (`Init_Server.sqf:676`).

`Server/Init/Init_Towns.sqf` implements starting modes:

- mode 1: 50/50 west/east by distance from start positions (`:6-33`);
- mode 2: nearby towns for each side (`:35-64`);
- mode 3: random 25% west, 25% east, 50% resistance with optional map-boundary center selection (`:66-157`);
- Patrols v2 retired the old `wfbe_patrol_enabled` town subset path. `Server/Init/Init_Towns.sqf:159-160` now documents the handoff to the side-upgrade driver instead of flagging towns.

Starting mode writes both town `sideID` and each camp `sideID` with public broadcast (`:24-31`, `:55-62`, etc.).

## Server Loop Startup

Once side/base initialization is complete, server init starts the major town loops:

- `server_town.sqf` at `Init_Server.sqf:509-510`;
- `server_town_ai.sqf` at `:512-515` when defender or occupation AI is enabled;
- victory, resource, upgrade queue and side-patrol loops after `townInit`; on current stable `origin/master@0139a346`, `server_side_patrols.sqf` starts at `Init_Server.sqf:690`.

This ordering matters. Capture/SV, town AI, resources and victory are separate loops with overlapping state, not one monolithic FSM.

## Town Capture And SV

`server_town.sqf` is one global loop over all towns. Each cycle:

1. reads town `sideID`, `startingSupplyValue`, `maxSupplyValue` and `supplyValue`;
2. scans nearby `Man`, `Car`, `Motorcycle`, `Tank`, `Air`, `Ship` inside the configured capture range and below height 10 (`:55-63`);
3. computes enemy pressure for current owner (`:65-69`);
4. optionally regenerates supply value over time when no active enemies are present (`:78-99`);
5. applies one of three capture modes:
   - mode 0 classic contesting (`:138-147`);
   - mode 1 threshold/dominion (`:107-136`);
   - mode 2 camp-gated dominion, requiring all camps for a side before town capture proceeds (`:149-190`);
6. publishes `wfbe_attacker_sideIDs` so marker visibility can reveal attacked-town SV only to involved sides (`:202-207`);
7. drains town `supplyValue` by attacker count, camp ratio and capture-rate factors (`:192-213`);
8. restores SV up to starting SV when protected by current owner (`:216-223`);
9. on capture, sets new `sideID`, sends `TownCaptured`, sets all camps to the new side, removes old town defense units and creates new defenses if enabled (`:226-255`);
10. records `PerformanceAudit` metrics if enabled (`:262-267`);
11. sleeps cooperatively between towns and 5 seconds per full cycle (`:259-273`).

The capture loop is server-owned for town `sideID`, town `supplyValue`, attacker visibility state, camp reassignment and defense ownership.

### Capture Ownership Chain

The compact server-owned chain is:

1. `server_town.sqf:149-196` decides whether a side has enough dominance to drain/capture the town, including camp-gated mode `2`.
2. On capture, `server_town.sqf:226-241` writes the town `sideID`, broadcasts `TownCaptured` and calls `WFBE_SE_FNC_SetCampsToSide`.
3. `Server_SetCampsToSide.sqf:18-27` sets every camp to the new side, resets camp SV to the town starting SV, changes flags and broadcasts `AllCampsCaptured`.
4. Independent camp captures are handled by `server_town_camp.sqf:122-138`, which writes camp `sideID`, changes the flag and broadcasts `CampCaptured`.

That means ownership is server-owned, but player bounty/funds reactions to those broadcasts still happen client-side in the PVF handlers below.

Mini-scout follow-up 2026-06-04 also checked commander voting adjacency. No direct source path was found from town/camp capture events into commander election state. `RequestCommanderVote.sqf:8-22`, `RequestNewCommander.sqf:8-14`, `Server_VoteForCommander.sqf:16-57` and the vote menus are separate commander-flow plumbing; town capture affects economy, defenses, camps and markers, not commander assignment.

## Camp Capture

Camps are not handled by one script per camp anymore. `server_town_camp.sqf` registers each town's camps into `WFBE_SE_TownCampWorkers`, then keeps exactly one global camp manager alive (`:8-14`).

Each camp cycle:

- scans nearby `Man` entities inside `WFBE_C_CAMPS_RANGE` (`:58-63`);
- applies the shorter player-specific range from `WFBE_C_CAMPS_RANGE_PLAYERS` (`:64-70`);
- uses dominion logic to decide pressure/protection (`:72-99`);
- drains/restores camp `supplyValue` using a time-scale factor based on the previous per-camp cadence (`:45-47`, `:99-119`);
- on capture, sets camp `sideID`, changes flag texture, sends `CampCaptured`, and logs PerformanceAudit metrics (`:122-153`).

When a town itself is captured, `Server_SetCampsToSide.sqf` resets every camp to the new side and starting SV, updates flag textures, then sends `AllCampsCaptured` (`Server_SetCampsToSide.sqf:15-27`).

Camp flag texture branch detail is intentionally single-sourced in [Current Branch Scope](#current-branch-scope): current stable `origin/master@0139a346`, historical release `a96fdda2`, B69 `0a1ccb4d` and `origin/feat/naval-hvt-objectives@2e1c5931` fix independent capture in both maintained roots; docs branch `28a7d9c5` and Miksuu still use the old owner; `perf/quick-wins` fixes Chernarus only; and repair-side flag refresh remains open everywhere checked. Use [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) for the code-owner queue instead of restating the matrix here.

### Camp Helper Risks

`Common_GetTotalCamps.sqf:10` and `Common_GetTotalCampsOnSide.sqf:16` both return `1` when the computed camp array is empty. That fallback may have been intended as a divide-by-zero guard for camp-ratio logic, but it can also inflate empty-camp totals in UI, metrics or future balance code. Before reusing these helpers, decide whether the caller needs a real count or a safe denominator.

This is broader than a UI-counting footnote. The fallback feeds camp-gated capture mode 2 and capture-rate math, threeway defender respawn (`Common_GetRespawnThreeway.sqf:7` plus the branch-specific `Client_GetRespawnAvailable.sqf` wrapper), and depot infantry purchase gating. Branch line drift and checked-ref parity live in [Current Branch Scope](#current-branch-scope); no checked ref there splits real-count versus safe-denominator semantics.

Patch rule: decide which callers need a real zero and which need a divide-safe denominator, then split helpers or add caller-specific zero-camp guards. Smoke capture mode 2, threeway defender respawn and depot infantry buys on 0/partial/all-camp towns.

Camp capture marker events are also timing-sensitive: `CampCaptured.sqf:12-13` and `AllCampsCaptured.sqf:9-10` assume each camp already has a local `wfbe_camp_marker`. `Init_Town.sqf:149-158` creates those marker names on clients, so JIP or unusually early PVF delivery should be smoked before changing camp marker dispatch.

## Client Marker And Capture Feedback

Client PV functions are registered in `Init_PublicVariables.sqf:25-35`:

- `TownCaptured`
- `CampCaptured`
- `AllCampsCaptured`

`TownCaptured.sqf` recolors the town marker and shows a title only for clients whose side was old or new owner (`:15-27`). If the client's side captured the town, it awards client-local funds and requests score based on nearest group unit distance (`:37-72`), then pays commander capture bounty locally if the player is commander (`:74-81`). Exact current formulas: capture/assist bounty is `150 * supplyValue` (`TownCaptured.sqf:49-60`), while the commander bonus is `startingSupplyValue * WFBE_C_PLAYERS_COMMANDER_BOUNTY_CAPTURE_COEF` (`TownCaptured.sqf:74-80`).

False-positive guard: `Common/Init/Init_Town.sqf:1-8` still accepts `townValue` as an init argument, but the current audited economy/reward paths use `supplyValue` and `startingSupplyValue`. Do not describe `townValue` as a live income multiplier unless a future source scan finds an active consumer.

`CampCaptured.sqf` recolors local camp markers, pays camp capture bounty locally and requests score for nearby client group participation (`CampCaptured.sqf:19-40`). `AllCampsCaptured.sqf` recolors every camp marker for clients concerned by old or new side (`AllCampsCaptured.sqf:15-21`).

`updatetownmarkers.sqf` owns local town marker text. It keeps cached marker names, uses a 5-second visible refresh cadence, backs off heavy closed-map passes to 15 seconds, and displays SV only when:

- the town is friendly;
- one of the player's live group units is within range;
- server-published `wfbe_active_sideIDs` includes the client side;
- server-published `wfbe_attacker_sideIDs` includes the client side and town SV is below starting SV.

Source: `updatetownmarkers.sqf:20-136`.

## Town AI Activation

Town capture and town AI are separate. `server_town_ai.sqf` initializes active-town state on every town:

- `wfbe_active`
- `wfbe_active_air`
- `wfbe_active_sideIDs`
- `wfbe_inactivity`
- `wfbe_active_override`
- `wfbe_active_vehicles`
- `wfbe_town_teams`

Source: `server_town_ai.sqf:21-32`.

For each eligible town, the AI loop scans nearby `Man`, `Car`, `Motorcycle`, `Tank`, `Ship` and filters out air vehicles so flyovers do not wake towns (`:81-93`). If enemies are detected, it publishes only the side IDs that woke the town (`:101-108`), activates the town, selects defender or occupation group templates, chooses camp/town spawn positions, then creates groups through client delegation, headless delegation or server fallback (`:115-181`). It also mans static defenses (`:184-185`).

When inactive long enough, it clears active state and deletes town teams/vehicles (`:191-223`). The current vehicle deletion check is known unsafe for player passengers; use [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) before touching that cleanup.

Patrols v2 changed the current-master patrol ownership model. Current stable `origin/master@0139a346` Chernarus and maintained Vanilla Takistan no longer launch town patrols from `server_town_ai.sqf`; that file now carries explicit retirement comments at `:72` and `:327`. The old worker `server_patrols.sqf` remains present and now uses `while {!WFBE_GameOver && _team_alive}` at `:31`, but the live current-master patrol path is the side-upgrade driver described below.

### Resistance Patrol Branch Matrix

Checked 2026-06-14 after fetching `origin` and Miksuu upstream; current stable Patrols v2 line refs refreshed 2026-06-21 against `origin/master@0139a346`.

| Root / branch | `server_town_ai.sqf` launch shape | `server_patrols.sqf` loop | Status |
| --- | --- | --- | --- |
| Current stable `origin/master@0139a346` Chernarus | Old town-based launch is retired; `server_town_ai.sqf:72,327` route to `server_side_patrols.sqf`. | `server_patrols.sqf:31` now uses `&&`; Patrols v2 uses `Common_RunSidePatrol.sqf:119` with `&&` lifecycle plus side-slot release at `:54,264`. | Current source has the maintained-root loop fix plus the new side-upgrade patrol path; Arma smoke still pending. |
| Current stable `origin/master@0139a346` maintained Vanilla Takistan | Same retired town-based launch and side-upgrade driver. | Same `&&` loop in `server_patrols.sqf`; same `Common_RunSidePatrol` path. | Maintained Vanilla has parity; smoke still pending. |
| Previous stable/Miksuu baseline `89ae9dad` | Latches `wfbe_patrol_active` before `execVM` at `server_town_ai.sqf:295-298`. | Still `while {!WFBE_GameOver || _team_alive}` at `server_patrols.sqf:26`; reset remains after loop at `:71-72`. | Historical current-head evidence only; superseded by `0139a346` on rayswaynl `master`. |
| Historical stable baseline `origin/master` `2cdf5fb8` | Launch/latch in both maintained roots at `server_town_ai.sqf:232-235`. | Same `||` loop and post-loop reset in both maintained roots at `server_patrols.sqf:26`, `:71-72`. | Historical line baseline only; current stable moved the launch block but not the bug. |
| `origin/perf/quick-wins` `0076040f` | Chernarus keeps the same latch before launch at `:232-235`; Vanilla keeps the old shape. | Chernarus changes the loop to `while {!WFBE_GameOver && _team_alive}` at `:26`; Vanilla still uses `||`. | Chernarus-only fix candidate; not propagated to maintained Vanilla. |
| Historical release commit `a96fdda2` | Chernarus and Vanilla carry the June release patrol changes before the later master Patrols v2 branch. | Chernarus and maintained Vanilla use `while {!WFBE_GameOver && _team_alive}` at `server_patrols.sqf:26`. | Historical release evidence has maintained-root parity for the older loop-exit fix; current master has a newer side-upgrade implementation and no live `release/*` head exists on origin. |

Practical current-master rule: do not reopen DR-57/AI1 as current source-unpatched without checking the branch. For `origin/master@0139a346`, smoke the new Patrols v2 side-upgrade path: research levels 1/2/3 plus the level-4 convoy/camp-sweep hooks, confirm server or HC dispatch, verify `WFBE_ACTIVE_PATROLS` marker cleanup, kill the patrol and confirm the side slot/cooldown releases through `Server_HandleSpecial.sqf:345-380`.

### Patrols v2 Side-Upgrade Path

Patrols v2 is a side-owned upgrade feature, not the old random town flagger. Current `origin/master@0139a346` source and maintained Vanilla both add `WFBE_UP_PATROLS = 23` and `WFBE_C_SIDE_PATROLS_MAX = 2` in `Init_CommonConstants.sqf:60,63`, default `WFBE_C_TOWNS_PATROLS = 6` at `:486`, defender cap `WFBE_C_SIDE_PATROLS_MAX_DEFENDER = 1` at `:683`, compile `WFBE_CO_FNC_RunSidePatrol` at `Init_Common.sqf:107`, start the server driver at `Init_Server.sqf:690`, and run friendly patrol markers from `Init_Client.sqf:405`.

Runtime shape:

| Stage | Source | Behavior |
| --- | --- | --- |
| Upgrade/config | `Labels_Upgrades.sqf:77,103`; representative `Upgrades_USMC.sqf:29,57,85,121,149`; `Init_CommonConstants.sqf:60,63,486,683` | Adds a 4-level `Patrols` upgrade: levels 1-3 choose LIGHT/MEDIUM/HEAVY side patrols, while level 4 enables the convoy support path. Current constants cap normal sides at 2 patrols and defenders at 1. |
| Driver | `server_side_patrols.sqf:12,19,48,67,72` | Every 20 seconds, per present side, reads `WFBE_UP_PATROLS`, applies a level-aware side cap, waits/logs when no owned towns are available, selects the friendly town closest to the side HQ, chooses the patrol tier, and dispatches the patrol. |
| Locality | `server_side_patrols.sqf:67`; `Client/PVFunctions/HandleSpecial.sqf:50` | Runs on a live HC through `delegate-sidepatrol` when one is registered; otherwise spawns on the server. |
| Runner | `Common_RunSidePatrol.sqf:54,82,87,91,108,119,148,245,264` | Creates the team, publishes started/ended events through `HandleSpecial` / `RequestSpecial`, gravitates to enemy towns, runs level-4 convoy and Task 40 camp-sweep hooks, exits on game over or dead patrol, and releases the slot. |
| Markers | `Server_HandleSpecial.sqf:345-380`; `Client/FSM/updatepatrolmarkers.sqf:3,19,31-48` | Maintains `WFBE_ACTIVE_PATROLS`, updates convoy stop state and shows friendly patrol markers only. |

Smoke gate: confirm a side can research all three levels, each level spawns an appropriate patrol near the HQ-side frontline, markers appear only to the owning side, HC dispatch works when an HC is connected, slot/cooldown release after patrol death, and current Buy Units/RHUD AI-cap text matches the "running patrols reduce max AI by 1" rule.

## Upstream Miksuu Town-Defense Diagnostics

This subsection preserves upstream provenance. For current branch-head claims in this atlas, use [Current Branch Scope](#current-branch-scope): current rayswaynl `origin/master` is `0139a346`, current Miksuu is `b8389e74`, and older `89ae9dad` wording below is historical context unless explicitly named.

Current [Miksuu upstream commit intel](Upstream-Miksuu-Commit-Intel) found `miksuu/master` ahead of the then-current `rayswaynl/master` by a focused town-defense diagnostics batch as of 2026-06-03. The key Chernarus commit is [`913ecdf6`](https://github.com/Miksuu/a2waspwarfare/commit/913ecdf6b55698ad8ea5de70dc1ecb33193b17ce), followed by Takistan propagation in [`d5bfe3a2`](https://github.com/Miksuu/a2waspwarfare/commit/d5bfe3a26d677d84c49188abe8d92c03b72f049f).

The 2026-06-05 refetch added an upstream capture-state fix: [`e4be1958`](https://github.com/Miksuu/a2waspwarfare/commit/e4be1958668ade647dfec8a098a4743b4131f511) on `miksuu/master` `69e1958a`. The 2026-06-06 refetch advanced upstream to `89ae9dad`, adding a broader town-defense persistence/diagnostics model through `Marty_town_defense_overhaul`. A later 2026-06-06 fetch showed rayswaynl `origin/master` and the then-local source checkout also at `89ae9dad`. Both batches modify source Chernarus and maintained Vanilla Takistan.

What matters for this atlas:

- `WFBE_C_TOWN_DEFENSE_DIAGNOSTICS` gates focused `TOWN_DEFENSE_DIAG` RPT logging, rather than relying on broad `WF_Debug` in hot loops.
- `server_town_ai.sqf` records activation start, valid group creation, client delegation, HC delegation and server-created unit/vehicle results.
- `Common_CreateTeam.sqf` and static-defense helpers treat `createGroup` / `createUnit` / `createVehicle` failure as expected runtime pressure, not impossible state.
- The patch deletes a just-created town combat vehicle when no crew could be created, preventing empty defense vehicles from becoming the visible symptom of group-limit failure.
- `e4be1958` adds capture-side AI-state cleanup at `server_town.sqf:229-257`: it logs `capture_before`, copies and clears `wfbe_town_teams` / `wfbe_active_vehicles`, resets `wfbe_active`, `wfbe_active_air`, `wfbe_active_sideIDs`, `wfbe_active_override`, `wfbe_inactivity`, `wfbe_town_teams` and `wfbe_active_vehicles`, then logs `capture_cleanup`. The older rayswaynl stable baseline checked at `origin/master` `2cdf5fb8` lacked this reset in its capture block (`server_town.sqf:226-245`); the then-current remote `origin/master` `89ae9dad` carried the reset.
- The `89ae9dad` branch state extends the capture-state reset into temporary old-defender persistence. It compiles `WFBE_CO_FNC_MarkTownDefenseAsset` in `Common/Init/Init_Common.sqf:106`, compiles `WFBE_SE_FNC_CleanupExpiredTownDefenseAssets` and `WFBE_SE_FNC_SendTownDebugChat` in `Server/Init/Init_Server.sqf:55,60`, and adds the diagnostics parameter at `Rsc/Parameters.hpp:484-485`. On capture, `server_town.sqf:234-267` copies active town teams/vehicles, marks old groups/units/vehicles with an expiry, stores `wfbe_persistent_town_defense_assets`, and clears active state so the new owner can spawn occupation teams.

This merged town-defense work is adjacent to, but not the same as, the local [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) finding. The merge hardens failed creation and diagnostics; DR-45 hardens later inactivity cleanup of already tracked town vehicles with player occupants.

Porting caution: `e4be1958` and the newer persistence cleanup still rely on player-leader-style object guards. `Server_CleanupExpiredTownDefenseAssets.sqf:61-64` deletes expired object assets after checking only `isPlayer _asset` and `isPlayer leader group _asset`; normal Miksuu inactivity cleanup still lacks a full crew/cargo/turret player check at `server_town_ai.sqf:277-278`. If imported, combine it with the [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) guard or smoke occupied town-AI vehicles during capture and persistence cleanup.

## Economy And Victory Consumers

Town ownership and SV feed the economy:

- `Common_GetTownsSupply.sqf` sums `supplyValue` for towns whose `sideID` matches a side (`:3-8`);
- `Common_GetTownsIncome.sqf` does the same with optional income coefficient (`:4-16`);
- `Common_GetTownsHeld.sqf` counts towns held by a side (`:3-8`);
- `updateresources.sqf` reads town supply every income tick, optionally adds side supply, pays teams/commanders and AI commander funds (`updateresources.sqf:20-75`).

Side supply itself is a separate mutation pipeline: callers use `Common_ChangeSideSupply.sqf:24-31` to publish `wfbe_supply_temp_<side>` to the server, and `Server_ChangeSideSupply.sqf:1-47` applies the change and mirrors `wfbe_supply_<side>` back to clients. Town income uses that pipeline from `updateresources.sqf:47-50`. Clamp/authority fixes belong in [Economy authority first cut](Economy-Authority-First-Cut), not inside town capture logic.

Victory also depends on town ownership. The exact endgame bug/risk detail stays canonical in [Deep review findings](Deep-Review-Findings) DR-11/DR-36 and [Testing workflow](Testing-Debugging-And-Release-Workflow).

## Supply Mission Touchpoints

Town init seeds two supply mission variables:

- `lastSupplyMissionRun`
- `supplyMissionCoolDownEnabled`

Source: `Init_Town.sqf:35-36`.

The supply mission code later reads/writes `LastSupplyMissionRun` with a different capital `L`, which is a confirmed cooldown casing mismatch. Do not fix it here as a town rewrite; use [Supply mission architecture](Supply-Mission-Architecture) and [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook).

## Risk Register

| Status | Finding | Evidence | Owner page |
| --- | --- | --- | --- |
| Patch-ready | Town AI inactivity cleanup can delete a town-AI vehicle with a player passenger/crew member aboard if the player is not group leader. | `server_town_ai.sqf:211-216` | [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) |
| Branch-split / repair-side open | Independent camp-capture and repair-side world-flag status is branch-sensitive. Current stable, historical `a96fdda2`, B69 and naval HVT fix independent capture in both maintained roots; docs head and Miksuu still use the old owner; perf fixes Chernarus only; and repair-side flag refresh remains open everywhere checked. | [Current Branch Scope](#current-branch-scope); docs `server_town_camp.sqf:132,135` and `Server_HandleSpecial.sqf:165,168`; current stable repair line drift `Server_HandleSpecial.sqf:468,471` | This page, [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) |
| Smoke pending | Current stable `origin/master@0139a346` supersedes the old DR-57/AI1 resistance-patrol path with Patrols v2 side-upgrade patrols in both maintained roots. The old `89ae9dad` evidence remains historical; current source has the `&&` loop, a level-aware `server_side_patrols` driver, friendly markers and level-4 convoy/camp-sweep hooks. | `server_town_ai.sqf:72,327`; `server_side_patrols.sqf:12,19,48,67,72`; `Common_RunSidePatrol.sqf:54,82,119,148,245,264`; `Server_HandleSpecial.sqf:345-380`; branch matrix above | This page, [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Source fix propagation queue](Source-Fix-Propagation-Queue) |
| Upstream candidate | Miksuu's latest `master` adds focused town-defense diagnostics plus `grpNull`/`objNull` creation guards and Vanilla propagation; `e4be1958` additionally clears previous-side active town-AI state when a town is captured so the new owner can spawn occupation teams. | [`913ecdf6`](https://github.com/Miksuu/a2waspwarfare/commit/913ecdf6b55698ad8ea5de70dc1ecb33193b17ce), [`d5bfe3a2`](https://github.com/Miksuu/a2waspwarfare/commit/d5bfe3a26d677d84c49188abe8d92c03b72f049f), [`e4be1958`](https://github.com/Miksuu/a2waspwarfare/commit/e4be1958668ade647dfec8a098a4743b4131f511) | [Miksuu upstream commit intel](Upstream-Miksuu-Commit-Intel) |
| Patch-ready | Supply mission cooldown key casing differs between town init and supply mission code. | `Init_Town.sqf:35`; supply pages trace `LastSupplyMissionRun` | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| Authority gap | Town and camp capture bounties are awarded client-side after server capture broadcasts. | `TownCaptured.sqf:37-81`; `CampCaptured.sqf:19-40` | [Server authority map](Server-Authority-Migration-Map), [Feature status](Feature-Status-Register) |
| Authority gap | Camp repair is client-paid/client-gated, then server `repair-camp` recreates the camp bunker from payload side/camp state. | `Client/Action/Action_RepairCamp.sqf:33-66`; `Client/Action/Action_RepairCampEngineer.sqf:33-67`; `Server_HandleSpecial.sqf:147-168` | [Server authority map](Server-Authority-Migration-Map), [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas) |
| Broken dormant scaffold | Town mortar support exists as a constant/function/scanner shape, but no live town init sets `wfbe_town_mortars`, and `Server_SpawnTownMortars.sqf` reads undefined `_positions` after loading `_position`. | `Server_ManageTownDefenses.sqf:32`; `Server_SpawnTownMortars.sqf:9-13`; `Init_CommonConstants.sqf:331-334` | This page, [Feature status](Feature-Status-Register) |
| Dormant design scaffold | Resistance/three-way and static-defense delegation hooks exist, but live mission behavior does not prove a full third-side economy/commander path or active static-defense update delegation. | `Init_Common.sqf:280-283`; `Client_DelegateAIStaticDefence.sqf:28`; `server_town_ai.sqf:184-185` | [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Resistance supply scaffold](Resistance-Supply-Scaffold) |
| Validation-sensitive | Marker visibility relies on server-published `wfbe_active_sideIDs` and `wfbe_attacker_sideIDs` to avoid revealing SV globally. | `server_town.sqf:202-207`; `server_town_ai.sqf:101-108`; `updatetownmarkers.sqf:63-83` | This page plus [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Performance-sensitive | `server_town`, `server_town_camp`, `server_town_ai` and `updatetownmarkers` are continuous loops with `nearEntities` scans and network writes. | PerformanceAudit records in each loop | [Performance opportunity sweep](Performance-Opportunity-Sweep) |
| Source-completeness trap | SQF-only scans miss `mission.sqm` town object `init` fields and WF_Logic's `Init_TownMode.sqf` startup. | `mission.sqm:124-128`, `mission.sqm:3265` | [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) |

## Development Rules

- Start town edits in the Chernarus source mission, then propagate generated missions with LoadoutManager.
- Use `-LiteralPath` in PowerShell for `[55-2hc]` paths.
- Keep capture ownership (`server_town`) separate from AI activation (`server_town_ai`) and camp ownership (`server_town_camp` / `Server_SetCampsToSide`).
- Preserve public `setVariable` broadcasts for `sideID`, `supplyValue`, camp side/SV and marker-visibility state unless you replace JIP behavior deliberately.
- Do not reveal enemy town SV globally; preserve the side-scoped `wfbe_active_sideIDs` / `wfbe_attacker_sideIDs` model.
- When changing capture or camp cadence, inspect PerformanceAudit output before and after.
- When changing bounty/reward logic, treat it as server-authority work, not marker/UI work.

## Smoke Checklist

| Change type | Minimum smoke |
| --- | --- |
| Town init / mission.sqm / parameters | Hosted or dedicated boot, no `townInit` wait hang, towns appear with expected count and markers. |
| Starting mode | Dedicated smoke for mode 0/1/2/3 as applicable; camps match town starting ownership. |
| Town capture | Capture from west/east/resistance as enabled; SV drains/resets; marker color/text changes only for concerned sides. |
| Camp capture | Capture/repair camp, flag texture and marker color update, bounty behavior remains understood; specifically verify the 3D flag uses the new owner after independent capture and repair. |
| Marker visibility | JIP client sees current town/camp colors; enemy SV remains hidden unless active/attacked or nearby. |
| Town AI | Wake town by ground unit, no flyover-only wake, despawn after inactivity, no occupied-vehicle deletion regression, and Patrols v2 side patrols spawn, mark, delegate, die and release their side slot correctly. |
| Economy | Income tick still reflects town SV and ownership; side supply clamp/authority changes still use current town supply. |
| Victory | All-town and HQ/factory elimination paths still produce one winner and one endgame/log path. |

## Historical Town Patrol Mechanic (pre-Patrols v2)

> Historical mechanic write-up for the pre-Patrols v2 roaming-patrol feature. It still explains old `89ae9dad` / branch evidence, but it is not the current `origin/master@0139a346` path. For current master, use [Patrols v2 Side-Upgrade Path](#patrols-v2-side-upgrade-path).

**What patrols are.** Designated towns periodically launch a mobile AI group that wanders town-to-town and tries to **capture** enemy/neutral towns as it arrives — ambient, map-wide pressure not tied to a base assault. A patrol's side is the current owner of its origin town.

**Flow:**

| Stage | Source | Behavior |
| --- | --- | --- |
| Enable | `Server/Init/Init_Towns.sqf:160-179` | Gated on `WFBE_C_TOWNS_STARTING_MODE != 1` and `WFBE_C_TOWNS_PATROLS > 0`; flags `WFBE_C_TOWNS_PATROLS` towns with `wfbe_patrol_enabled` (all towns, or a random subset). |
| Launch gate | `Server/FSM/server_town_ai.sqf:294-298` | Per enabled town, if `!wfbe_active && !wfbe_patrol_active && time - wfbe_patrol_active_last > WFBE_C_PATROLS_DELAY_SPAWN` (360s): latch `wfbe_patrol_active=true` and `execVM server_patrols.sqf`. |
| Group build | `Server/Functions/Server_GetTownPatrol.sqf` | Strength by town supply value: SV ≤ 30 → `LIGHT`, 30 < SV < 60 → `MEDIUM`, SV > 60 → `HEAVY`; random pick from `WFBE_%side%_PATROL_%type%`. |
| Spawn | `server_patrols.sqf:16-24` | `CreateTeam` at a random empty point 50-500 m from the town (defender-side vehicle-lock per `WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER`). |
| Roam (30 s loop) | `server_patrols.sqf:41-67` | Picks the closest town not recently visited (`towns - _towns_visited`, visited cap `WFBE_C_PATROLS_TOWNS_LOCK` ≈ 25% of towns), MOVE waypoint; within 200 m of an enemy/neutral town → job `capture`. |
| Capture | `server_patrols.sqf:30-39` | Waits for the target's `sideID` to flip to the patrol's side (normal capture logic does the flip), then resumes roaming. `//todo rearm/repair/refuel` was never built. |
| Teardown | `server_patrols.sqf:71-72` | On team death / game-over, resets `wfbe_patrol_active=false` and stamps `wfbe_patrol_active_last=time` (intended cooldown anchor). |

**Three bugs made the old path dead before Patrols v2 (fix together only if reviving that path on an older branch):**

- **DR-57 — patrols never spawn** ([Deep-review findings](Deep-Review-Findings)): old `server_town_ai.sqf:67-68` unconditionally re-stamped `wfbe_patrol_active_last=time` every ~5 s scan, so the `:296` `> 360s` gate was never met. This superseded the earlier "blocked after first launch" framing for old current-head evidence.
- **AI1 — patrols never terminate** (if they did launch): old `server_patrols.sqf:26` used `while {!WFBE_GameOver || _team_alive}` (should be `&&`); the teardown reset never ran. Current `origin/master@0139a346` Chernarus and Vanilla now use `&&` at `server_patrols.sqf:31`.
- **AI6 — SV exactly 60 yields no patrol type**: the `Server_GetTownPatrol.sqf:16-19` switch has cases `<= 30`, `> 30 && < 60`, `> 60` — `== 60` falls through and `_type` is unassigned.

Patch rule for old branches only: remove the unconditional timestamp reset (DR-57), restore the `&&` loop exit (AI1), close the `== 60` case (AI6), then smoke launch, roam, capture, death and relaunch. Current master instead needs Patrols v2 smoke, not another port of the old branch matrix.

## Continue Reading

Previous: [Gameplay systems atlas](Gameplay-Systems-Atlas) | Next: [Economy, towns and supply](Economy-Towns-And-Supply)

- [Economy, towns and supply](Economy-Towns-And-Supply)
- [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)
- [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety)
- [AI, headless and performance](AI-Headless-And-Performance)
- [Supply mission architecture](Supply-Mission-Architecture)
- [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)
- [Testing workflow](Testing-Debugging-And-Release-Workflow)
- [Deep review findings](Deep-Review-Findings)
