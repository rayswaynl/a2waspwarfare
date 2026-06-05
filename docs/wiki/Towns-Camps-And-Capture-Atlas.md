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

## Source Files

| Area | Files |
| --- | --- |
| Mission objects | `mission.sqm:124-128` first town example, `mission.sqm:3265` WF_Logic town-removal lists and `Init_TownMode.sqf` call |
| Town amount mode | `Common/Init/Init_TownMode.sqf:3-23` |
| Per-town init | `Common/Init/Init_Town.sqf:1-165` |
| Common town wait | `Common/Init/Init_Towns.sqf:3-15` |
| Starting ownership / patrol flags | `Server/Init/Init_Towns.sqf:3-185` |
| Server loop startup | `Server/Init/Init_Server.sqf:507-533` |
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

After common town init, `Server/Init/Init_Server.sqf` calls `Server\Init\Init_Towns.sqf` only when a special starting mode or resistance patrols are enabled; otherwise it sets `townInitServer = true` directly (`Init_Server.sqf:518-519`).

`Server/Init/Init_Towns.sqf` implements starting modes:

- mode 1: 50/50 west/east by distance from start positions (`:6-33`);
- mode 2: nearby towns for each side (`:35-64`);
- mode 3: random 25% west, 25% east, 50% resistance with optional map-boundary center selection (`:66-157`);
- resistance patrol flags: `wfbe_patrol_enabled` on a selected town subset (`:159-181`).

Starting mode writes both town `sideID` and each camp `sideID` with public broadcast (`:24-31`, `:55-62`, etc.).

## Server Loop Startup

Once side/base initialization is complete, server init starts the major town loops:

- `server_town.sqf` at `Init_Server.sqf:509-510`;
- `server_town_ai.sqf` at `:512-515` when defender or occupation AI is enabled;
- victory and resource loops after `townInit` at `:526-533`.

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

Camp flag texture caveat: the independent camp-capture path currently computes `_newSide` and `_side`, but current source Chernarus and maintained Vanilla set the 3D flag texture from `str _side` at `server_town_camp.sqf:135`, after writing the camp `sideID` to `_newSID` at `:132`. `_side` is the old owner, so the world flag can remain visually on the previous side even though `sideID` and client markers move to the new side. `origin/master` `2cdf5fb8` and current `miksuu/master` `f532f706` keep the same old-owner texture in both maintained roots. `origin/release/2026-06-feature-bundle` `3282ff3f` has the one-line Chernarus capture fix from `0a1e6165`, using `str _newSide`, but release Vanilla still uses `str _side`. The camp repair path can also change `sideID` through `Server_HandleSpecial.sqf:243` and send `CampCaptured` at `:246` without a `setFlagTexture` refresh in current source, stable, upstream or release. Treat camp flag visuals as a source-unpatched current-source correctness issue with a partial release-Chernarus fix, not a marker-color bug.

### Camp Helper Risks

`Common_GetTotalCamps.sqf:10-11` and `Common_GetTotalCampsOnSide.sqf:16` both return `1` when the computed count is zero. That fallback may have been intended as a divide-by-zero guard for camp-ratio logic, but it can also inflate empty-camp totals in UI, metrics or future balance code. Before reusing these helpers, decide whether the caller needs a real count or a safe denominator.

Depth scout expansion 2026-06-04: this is broader than a UI-counting footnote. The fallback feeds camp-gated capture mode 2 in `server_town.sqf:179-189`, threeway defender respawn in `Common_GetRespawnThreeway.sqf:6-8` plus `Client_GetRespawnAvailable.sqf:67-80`, and depot infantry purchase gating in `GUI_Menu_BuyUnits.sqf:109-114`. Because both helper functions return `1` for zero-camp towns, a side-owned zero-camp town can look fully camp-owned to callers that expected real camp counts. If the fallback is meant only as a safe denominator for capture math, split a real-count helper or explicitly exclude zero-camp towns in respawn/buy/capture gates.

Branch check 2026-06-05 found no rescue in current docs/source Chernarus or maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706`, `origin/perf/quick-wins` `0076040f` or release `3282ff3f`: all checked roots/branches keep `Common_GetTotalCamps.sqf:10` and `Common_GetTotalCampsOnSide.sqf:16` returning `1` for zero-camp towns, plus the same capture-mode, threeway-respawn and depot-buy consumers. Release Chernarus only shifts the Buy Units caller to `GUI_Menu_BuyUnits.sqf:119`; it does not split real-count versus safe-denominator semantics. Treat this as patch-ready caller-semantics work: define which callers need a real zero, which need a divide-safe denominator, then smoke capture mode 2, threeway defender respawn and depot infantry buys on 0/partial/all-camp towns.

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

Resistance patrols have a separate lifecycle trap. `server_town_ai.sqf:226-230` starts `server_patrols.sqf` only when `wfbe_patrol_enabled` is true and `wfbe_patrol_active` is false, then immediately latches `wfbe_patrol_active = true`. The patrol worker uses `while {!WFBE_GameOver || _team_alive}` at `server_patrols.sqf:26`, so during a normal running match the loop condition stays true even after the patrol dies. The reset at `server_patrols.sqf:71-72` is therefore not reached until game-over conditions permit exit. Treat patrol respawn as effectively blocked after first launch until this lifecycle condition is patched.

### Resistance Patrol Branch Matrix

Checked 2026-06-05 after fetching `origin` and Miksuu upstream.

| Root / branch | `server_town_ai.sqf` launch shape | `server_patrols.sqf` loop | Status |
| --- | --- | --- | --- |
| Current docs/source Chernarus `HEAD` `732d408c` | Latches `wfbe_patrol_active` before `execVM` at `:227-230`. | Still `while {!WFBE_GameOver || _team_alive}` at `:26`; reset remains after loop at `:71-72`. | Source-unpatched. |
| Current maintained Vanilla Takistan `HEAD` `732d408c` | Same launch/latch at `:227-230`. | Same `||` loop and post-loop reset at `:26`, `:71-72`. | Vanilla source-unpatched. |
| Stable `origin/master` `2cdf5fb8` | Same launch/latch in both maintained roots at `:232-235`. | Same `||` loop and post-loop reset in both maintained roots at `:26`, `:71-72`. | Stable-unpatched. |
| Miksuu upstream `miksuu/master` `f532f706` | Same launch/latch in both maintained roots at `:276-279`. | Same `||` loop and post-loop reset in both maintained roots at `:26`, `:71-72`. | Upstream still carries the latch hazard; the newer town-capture reset does not fix patrol relaunch. |
| `origin/perf/quick-wins` `0076040f` | Chernarus keeps the same latch before launch at `:232-235`; Vanilla keeps the old shape. | Chernarus changes the loop to `while {!WFBE_GameOver && _team_alive}` at `:26`; Vanilla still uses `||`. | Chernarus-only fix candidate; not propagated to maintained Vanilla. |
| `origin/release/2026-06-feature-bundle` `3282ff3f` | Chernarus and Vanilla keep the same latch before launch at `:232-235`. | Chernarus uses `&&` at `:26`; Vanilla still uses `||` at `:26`. | Release branch is Chernarus-only for this fix. |

Practical patch rule: port or recreate the `&&` loop exit in source Chernarus, propagate maintained Vanilla, and smoke patrol launch, patrol death, `wfbe_patrol_active` reset / relaunch, and game-over cleanup. Keep this separate from the adjacent `server_town_patrol.sqf` worker until both loops are reviewed together.

## Upstream Miksuu Town-Defense Diagnostics

Current [Miksuu upstream commit intel](Upstream-Miksuu-Commit-Intel) found `miksuu/master` ahead of `rayswaynl/master` by a focused town-defense diagnostics batch as of 2026-06-03. The key Chernarus commit is [`913ecdf6`](https://github.com/Miksuu/a2waspwarfare/commit/913ecdf6b55698ad8ea5de70dc1ecb33193b17ce), followed by Takistan propagation in [`d5bfe3a2`](https://github.com/Miksuu/a2waspwarfare/commit/d5bfe3a26d677d84c49188abe8d92c03b72f049f).

The 2026-06-05 refetch added a newer upstream capture-state fix: [`e4be1958`](https://github.com/Miksuu/a2waspwarfare/commit/e4be1958668ade647dfec8a098a4743b4131f511) on `miksuu/master` `69e1958a`. It modifies both source Chernarus and maintained Vanilla Takistan `Server/FSM/server_town.sqf`.

What matters for this atlas:

- `WFBE_C_TOWN_DEFENSE_DIAGNOSTICS` gates focused `TOWN_DEFENSE_DIAG` RPT logging, rather than relying on broad `WF_Debug` in hot loops.
- `server_town_ai.sqf` records activation start, valid group creation, client delegation, HC delegation and server-created unit/vehicle results.
- `Common_CreateTeam.sqf` and static-defense helpers treat `createGroup` / `createUnit` / `createVehicle` failure as expected runtime pressure, not impossible state.
- The patch deletes a just-created town combat vehicle when no crew could be created, preventing empty defense vehicles from becoming the visible symptom of group-limit failure.
- `e4be1958` adds capture-side AI-state cleanup at `server_town.sqf:229-257`: it logs `capture_before`, copies and clears `wfbe_town_teams` / `wfbe_active_vehicles`, resets `wfbe_active`, `wfbe_active_air`, `wfbe_active_sideIDs`, `wfbe_active_override`, `wfbe_inactivity`, `wfbe_town_teams` and `wfbe_active_vehicles`, then logs `capture_cleanup`. The rayswaynl stable baseline checked at `origin/master` `2cdf5fb8` still lacks this reset in its capture block (`server_town.sqf:226-245`).

This upstream work is adjacent to, but not the same as, the local [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) finding. The upstream batch hardens failed creation and diagnostics; DR-45 hardens later inactivity cleanup of already tracked town vehicles with player occupants.

Porting caution: `e4be1958` deletes tracked `_captureVehicles` when the vehicle is alive and the vehicle group leader is not a player. That is better than leaving the previous side's active state latched forever, but it does not prove a full crew/cargo/turret occupant check. If imported, combine it with the [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) guard or smoke occupied town-AI vehicles during capture.

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
| Patch-ready / partial release Chernarus fix | Current source/Vanilla, stable and current Miksuu upstream set independent camp-capture world flags to the old owner; release Chernarus fixes that one line, but release Vanilla and repair-side flag refresh remain open. | Current source/Vanilla `server_town_camp.sqf:132,135`; `Server_HandleSpecial.sqf:243,246`; release Chernarus commit `0a1e6165`; release Vanilla `server_town_camp.sqf:135` | This page, [Feature status](Feature-Status-Register) |
| Patch-ready | Resistance patrols can stay latched active after the patrol dies because the worker loop runs while the game is not over, and `wfbe_patrol_active` is reset only after the loop exits. Branch check 2026-06-05: current source/Vanilla, stable and Miksuu upstream still carry the `||` loop; `perf/quick-wins` and release Chernarus use `&&`, but maintained Vanilla still needs propagation. | `server_town_ai.sqf:226-230`; `server_patrols.sqf:26,71-72`; branch matrix above | This page, [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) |
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
| Town AI | Wake town by ground unit, no flyover-only wake, despawn after inactivity, no occupied-vehicle deletion regression, and resistance patrols can relaunch or reset correctly after patrol death. |
| Economy | Income tick still reflects town SV and ownership; side supply clamp/authority changes still use current town supply. |
| Victory | All-town and HQ/factory elimination paths still produce one winner and one endgame/log path. |

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
