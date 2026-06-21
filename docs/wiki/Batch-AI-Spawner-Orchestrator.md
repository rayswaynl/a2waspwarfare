# Batch AI Spawner Orchestrators

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Two `Common\Functions` orchestrators sit one tier above the single-entity spawn primitives (`WFBE_CO_FNC_CreateTeam`, `WFBE_CO_FNC_CreateUnit`). They take a *list* of group templates and loop over it, instantiating each template and then wiring the spawned AI into the surrounding gameplay systems (patrols, garrison tracking, stats, cleanup). `WFBE_CO_FNC_CreateTownUnits` is the town garrison/defender spawner; `WFBE_CO_FNC_CreateUnitsForResBases` is the resistance-base spawner. Both run on whichever machine the AI was delegated to — server, a player client, or a headless client — which is why so much of their bookkeeping is locality-aware (public `setVariable` tags, machine-side group diagnostics, per-machine cleanup registries).

Both are compiled once in `Common/Init/Init_Common.sqf`:

| Function | Registration | Source file |
|---|---|---|
| `WFBE_CO_FNC_CreateTownUnits` | `Common/Init/Init_Common.sqf:106` | `Common/Functions/Common_CreateTownUnits.sqf` |
| `WFBE_CO_FNC_CreateUnitsForResBases` | `Common/Init/Init_Common.sqf:115` | `Common/Functions/Common_CreateUnitsForResBases.sqf` |

## WFBE_CO_FNC_CreateTownUnits — town garrison spawner

The town defender spawner. For each group template it calls `WFBE_CO_FNC_CreateTeam`, tags every spawned entity as a town defender, launches a patrol FSM, and registers vehicles for cleanup.

| Property | Detail | Source |
|---|---|---|
| Parameters | `[_town, _side, _groups, _positions, _teams]` | `Common_CreateTownUnits.sqf:13-17` |
| `_groups` | Array of group templates; the loop runs `0` to `count(_groups)-1` | `Common_CreateTownUnits.sqf:34` |
| `_positions` / `_teams` | Parallel arrays indexed by `_i` — one spawn position and one preallocated group per template | `Common_CreateTownUnits.sqf:35-36` |
| Returns | `[_town_teams, _town_vehicles]` — the actual groups and vehicles created | `Common_CreateTownUnits.sqf:132` |

### Per-template loop behaviour

| Step | Detail | Source |
|---|---|---|
| Lock resolution (Task 34) | `_lock` is computed once before the loop. When `_side == WFBE_DEFENDER` and `WFBE_C_TOWNS_DEFENDER == 0` (resistance AI disabled) vehicles are **unlocked** (`false`); otherwise the `WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER` parameter governs the defender lock; all other sides lock (`true`) | `Common_CreateTownUnits.sqf:25-32` |
| Spawn the template | `[_groups select _i, _position, _side, _lock, _team, true, 90] call WFBE_CO_FNC_CreateTeam` — the `true` is the global-init flag, `90` the placement radius | `Common_CreateTownUnits.sqf:40` |
| Unpack the return | `CreateTeam` returns `[_units, _vehicles, _team, _crews]`; `_crews` is read defensively (`if (count _retVal > 3)`) | `Common_CreateTownUnits.sqf:41-45`; see `Common_CreateTeam.sqf:185` |
| Re-read `_team` | The returned group replaces the passed-in one — "delegated HC creation may replace grpNull locally" (Marty note) | `Common_CreateTownUnits.sqf:43-44` |
| Defender tag (PUBLIC) | `_x setVariable ["WFBE_IsTownDefenderAI", true, true]` over `_units + _crews + _vehicles`. The third arg `true` (broadcast) is deliberate: town AI may be built on an HC while the activation scan that must ignore these runs on the server, so a local-only tag would be invisible | `Common_CreateTownUnits.sqf:47-50` |
| Airfield garrison tag | When `_town getVariable "wfbe_town_type" == "PMCAirfield"`, every entity is also tagged `wfbe_airfield_garrison` (public), and on the server the entities are appended into the town's `wfbe_airfield_garrison_units` array for bulk deletion on capture | `Common_CreateTownUnits.sqf:53-69` |
| Empty-team guard | If `_team` is null or the template produced zero units+vehicles, patrol setup is skipped with a WARNING log | `Common_CreateTownUnits.sqf:74-77` |
| Patrol wiring | On a valid team: stamp `WFBE_TownAI_Town` / `_Side` / `_Group` (all local), `execVM "Server\FSM\server_town_patrol.sqf"`, `spawn WFBE_CO_FNC_RevealArea` over a 400 m radius, push into `_town_teams`, and `_team allowFleeing 0` (brave) | `Common_CreateTownUnits.sqf:78-84` |
| Vehicle wiring | Each vehicle is pushed into `_town_vehicles`; on the server only, `spawn WFBE_SE_FNC_HandleEmptyVehicle` and `_x setVariable ["WFBE_Taxi_Prohib", true]` (excludes it from the taxi pool) | `Common_CreateTownUnits.sqf:87-93` |

### Post-loop accounting

| Step | Detail | Source |
|---|---|---|
| Statistics | `UnitsCreated` and `VehiclesCreated` are incremented via `UpdateStatistics` keyed on `str _side` | `Common_CreateTownUnits.sqf:96-97` |
| `TOWN_GROUP_COUNT` diagnostic | If the town activated with **zero** assets, the function counts every group on the current machine by side, identifies the machine (`SERVER`/`CLIENT`/`HC`), and emits a `TOWN_GROUP_COUNT town_empty ...` WARNING — a failure-diagnostic for group-cap saturation | `Common_CreateTownUnits.sqf:99-128` |
| Closing log | Always logs the activation total before returning | `Common_CreateTownUnits.sqf:130` |

### Callers

| Caller | Context | Source |
|---|---|---|
| `server_town_ai.sqf` | The server fallback path when delegation is disabled or unavailable (`_use_server` branch) | `Server/FSM/server_town_ai.sqf:254` |
| `Server_FNC_Delegation.sqf` | Server-side creation of the *residual* templates that were not handed to clients (after the `**NIL**` filter) | `Server/Functions/Server_FNC_Delegation.sqf:56` |
| `Client_DelegateTownAI.sqf` | The delegated client/HC path: pre-fills null/empty `_teams` slots via `WFBE_CO_FNC_CreateGroup`, calls `CreateTownUnits`, registers the local groups in `WFBE_CL_TownAI_Groups`, and reports them back to the server via `RequestSpecial update-town-delegation` | `Client/Functions/Client_DelegateTownAI.sqf:23-44` |

## WFBE_CO_FNC_CreateUnitsForResBases — resistance-base spawner

The leaner sibling. It loops a list of unit classnames through the single-unit primitive `WFBE_CO_FNC_CreateUnit` and records a performance sample. (Despite the header comment "Create units for static defence" and the internal `Common_CreateUnitForstaticForResBases.sqf` log strings, this is the resistance/delegated-base unit spawner — the static-defence manning function is a separate file.)

| Property | Detail | Source |
|---|---|---|
| Parameters | `[_side, _groups, _positions, _team]` | `Common_CreateUnitsForResBases.sqf:14-17` |
| `_groups` | Array of unit classnames; loop runs `0` to `count(_groups)-1` | `Common_CreateUnitsForResBases.sqf:27` |
| `_team` | A **single** group object (not a parallel array). Inside the loop the call passes `_team select 0` as the group into which every unit is created | `Common_CreateUnitsForResBases.sqf:17,35` |
| `_positions` | Passed whole as the position argument to `CreateUnit` (the commented-out `_positions select _i` shows per-index positioning was abandoned) | `Common_CreateUnitsForResBases.sqf:28,35` |
| Spawn call | `[_groups select _i, _team select 0, _positions, _sideID] Call WFBE_CO_FNC_CreateUnit` — note `_sideID` is the side **ID**, re-fetched via `GetSideID` each iteration | `Common_CreateUnitsForResBases.sqf:33-35` |
| Brave units | `_unit allowFleeing 0` after each creation | `Common_CreateUnitsForResBases.sqf:41` |
| `_teams` push | `_team` (the same group each time) is pushed into `_teams` every iteration via `ArrayPush` | `Common_CreateUnitsForResBases.sqf:39` |
| Statistics | `UnitsCreated` incremented by `_built` (count of templates) | `Common_CreateUnitsForResBases.sqf:44` |
| Performance audit | Accumulates per-item `CreateUnit` time into `_perfActive` and emits a `create_resbase_units` record (`side`, `groups`, `units`, `cycleMs`) when `PerformanceAudit_Record` is defined and enabled | `Common_CreateUnitsForResBases.sqf:24,34-36,48-52` |
| Returns | `[_teams]` (a one-element array wrapping the group list) | `Common_CreateUnitsForResBases.sqf:55` |

### Caller

The single live caller is `Client_DelegateAI.sqf:22`, which passes `[_side, _unitType, _position, _team]` — note it extracts `select 0` from each of the request's groups/positions/teams arrays before delegating (`Client/Functions/Client_DelegateAI.sqf:13-15`). After spawning, it spawns a per-group watcher that `deleteGroup`s each returned team once it naturally empties, client-side (`Client_DelegateAI.sqf:25-32`). This contradicts the AI-Runtime-HC-Loop-Map note flagging the function as having "no clear live caller" — the caller exists and is exercised by the client-delegation path.

## Locality and the delegation split

Both orchestrators are written to run anywhere because town/resbase AI creation is *delegated*: `server_town_ai.sqf` either hands the templates to a client (`WFBE_SE_FNC_DelegateAITown`), to a headless client (`WFBE_CO_FNC_DelegateAITownHeadless`), or — as a fallback — creates them itself on the server (`Server/FSM/server_town_ai.sqf:233-259`). Consequences visible in the code:

- Defender/garrison tags use the broadcast (`true`) form so the server's activation scans see them even when units were built on a remote machine (`Common_CreateTownUnits.sqf:50,60`).
- Server-only side effects (`HandleEmptyVehicle`, `Taxi_Prohib`, the airfield-garrison array) are guarded by `isServer` (`Common_CreateTownUnits.sqf:63,89`).
- The empty-town and group-saturation diagnostics label the reporting machine explicitly (`Common_CreateTownUnits.sqf:126`).
- Delegated callers (`Client_DelegateTownAI.sqf`, `Client_DelegateAI.sqf`) own the *cleanup*: they watch their local groups and `deleteGroup` them where deletion is actually effective.

## Continue Reading

- [Spawn-Primitive-Function-Reference](Spawn-Primitive-Function-Reference) — the `CreateTeam` / `CreateUnit` / `CreateVehicle` primitives these loops drive.
- [Town-AI-Group-Composition-Catalog](Town-AI-Group-Composition-Catalog) — the group template DATA library and server-side selection that decide *what* gets spawned.
- [Town-AI-Vehicle-Despawn-Safety](Town-AI-Vehicle-Despawn-Safety) — capture-time cleanup of town/garrison vehicles spawned here.
- [Static-Defense-Manning-Reference](Static-Defense-Manning-Reference) — the sibling `Common_CreateUnitForStaticDefence` manning function (distinct from this resbase spawner).
- [Headless-Delegation-And-Failover-Playbook](Headless-Delegation-And-Failover-Playbook) — how town/resbase AI creation is delegated to HCs and falls back to the server.
- [AI-Runtime-HC-Loop-Map](AI-Runtime-HC-Loop-Map) — the runtime loop map that lists these orchestrators among the HC/AI loops.
