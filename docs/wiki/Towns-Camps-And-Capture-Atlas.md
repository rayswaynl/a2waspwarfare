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

## Camp Capture

Camps are not handled by one script per camp anymore. `server_town_camp.sqf` registers each town's camps into `WFBE_SE_TownCampWorkers`, then keeps exactly one global camp manager alive (`:8-14`).

Each camp cycle:

- scans nearby `Man` entities inside `WFBE_C_CAMPS_RANGE` (`:58-63`);
- applies the shorter player-specific range from `WFBE_C_CAMPS_RANGE_PLAYERS` (`:64-70`);
- uses dominion logic to decide pressure/protection (`:72-99`);
- drains/restores camp `supplyValue` using a time-scale factor based on the previous per-camp cadence (`:45-47`, `:99-119`);
- on capture, sets camp `sideID`, changes flag texture, sends `CampCaptured`, and logs PerformanceAudit metrics (`:122-153`).

When a town itself is captured, `Server_SetCampsToSide.sqf` resets every camp to the new side and starting SV, updates flag textures, then sends `AllCampsCaptured` (`Server_SetCampsToSide.sqf:15-27`).

## Client Marker And Capture Feedback

Client PV functions are registered in `Init_PublicVariables.sqf:25-35`:

- `TownCaptured`
- `CampCaptured`
- `AllCampsCaptured`

`TownCaptured.sqf` recolors the town marker and shows a title only for clients whose side was old or new owner (`:15-27`). If the client's side captured the town, it awards client-local funds and requests score based on nearest group unit distance (`:37-72`), then pays commander capture bounty locally if the player is commander (`:74-81`).

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

## Economy And Victory Consumers

Town ownership and SV feed the economy:

- `Common_GetTownsSupply.sqf` sums `supplyValue` for towns whose `sideID` matches a side (`:3-8`);
- `Common_GetTownsIncome.sqf` does the same with optional income coefficient (`:4-16`);
- `Common_GetTownsHeld.sqf` counts towns held by a side (`:3-8`);
- `updateresources.sqf` reads town supply every income tick, optionally adds side supply, pays teams/commanders and AI commander funds (`updateresources.sqf:20-75`).

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
| Patch-ready | Supply mission cooldown key casing differs between town init and supply mission code. | `Init_Town.sqf:35`; supply pages trace `LastSupplyMissionRun` | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| Authority gap | Town and camp capture bounties are awarded client-side after server capture broadcasts. | `TownCaptured.sqf:37-81`; `CampCaptured.sqf:19-40` | [Server authority map](Server-Authority-Migration-Map), [Feature status](Feature-Status-Register) |
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
| Camp capture | Capture/repair camp, flag texture and marker color update, bounty behavior remains understood. |
| Marker visibility | JIP client sees current town/camp colors; enemy SV remains hidden unless active/attacked or nearby. |
| Town AI | Wake town by ground unit, no flyover-only wake, despawn after inactivity, no occupied-vehicle deletion regression. |
| Economy | Income tick still reflects town SV and ownership; side supply clamp/authority changes still use current town supply. |
| Victory | All-town and HQ/factory elimination paths still produce one winner and one endgame/log path. |

## Next Pages

Previous: [Gameplay systems atlas](Gameplay-Systems-Atlas) | Next: [Economy, towns and supply](Economy-Towns-And-Supply)

- [Economy, towns and supply](Economy-Towns-And-Supply)
- [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)
- [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety)
- [AI, headless and performance](AI-Headless-And-Performance)
- [Supply mission architecture](Supply-Mission-Architecture)
- [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)
- [Testing workflow](Testing-Debugging-And-Release-Workflow)
- [Deep review findings](Deep-Review-Findings)
