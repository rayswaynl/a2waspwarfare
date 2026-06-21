# Static-Defense Manning Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the AI **static-defence (emplaced-gun) manning family**: the helpers that put — and keep — an AI gunner in a town's M2 / MK19 / Stinger / TOW emplacement, plus the related turret-crewing and turret-rearm helpers that share the same primitives. It threads two layers:

- **Lifecycle layer (server):** `Server_SpawnTownDefense` creates the physical emplacement; `Server_OperateTownDefensesUnits` runs the per-town `spawn`/`remove` gunner state machine; `Server_ManageTownDefenses` is the (re)spawn driver invoked on the GUER recapture path.
- **Manning helper layer (common):** `Common_CreateUnitForStaticDefence` is the idempotent, HC-aware gunner-creation routine the HC delegation path calls; `Common_UseStationaryDefense`, `Common_SpawnTurrets` and `Common_SetTurretsMagazines` are adjacent crewing/rearm helpers that share `CreateUnit` / `EmptyPositions "gunner"` / `moveInTurret` mechanics.

Naming note: the source spells it **Defen*c*e** in the Common helper filename (British) and **Defen*s*e** in the Server functions (American). Both are correct as cited.

---

## 1. Town-defence gunner lifecycle (server)

### 1.1 Emplacement creation — `Server_SpawnTownDefense` (`WFBE_SE_FNC_SpawnTownDefense`)

Compiled at `Server/Init/Init_Server.sqf:77`. Params `[_defense_logic, _side]` (`Server/Functions/Server_SpawnTownDefense.sqf:9-11`). Picks an emplacement classname and spawns it as a vehicle at the town's defense-logic object.

| Step | Behavior | Citation |
|------|----------|----------|
| Read candidate kinds | `_kinds = _defense_logic getVariable "wfbe_defense_kind"`; exits if empty | `Server_SpawnTownDefense.sqf:15,18` |
| Random-kind pick (multi-kind) | Loops: random kind → `missionNamespace getVariable Format ["WFBE_%1_Defenses_%2", _side, kind]` → random classname from that pool | `Server_SpawnTownDefense.sqf:21-28` |
| Learn-and-adapt prune | Kinds whose `WFBE_<side>_Defenses_<kind>` var is nil are pushed to `_nils` and `ArrayShift`-ed out of the candidate list, then permanently removed from the logic via `setVariable ["wfbe_defense_kind", ... - _nils]` | `Server_SpawnTownDefense.sqf:26,36` |
| Single-kind path | Direct default lookup, no pruning loop | `Server_SpawnTownDefense.sqf:29-33` |
| Spawn emplacement | `createVehicle [_defense, getPos _defense_logic, [], 0, "NONE"]`, then `setDir`/`setPos` to the logic's facing | `Server_SpawnTownDefense.sqf:41-43` |
| Killed wiring | `addEventHandler ['killed', ... Spawn WFBE_CO_FNC_OnUnitKilled]` with the side ID baked into the EH string | `Server_SpawnTownDefense.sqf:44` |
| Defender tag | `setVariable ["WFBE_IsTownDefenderAI", true, true]` (public — the activation scan that must ignore these runs server-side) | `Server_SpawnTownDefense.sqf:46` |
| Store handle | `_defense_logic setVariable ["wfbe_defense", _entitie]` (non-public; the local town object owns the reference) | `Server_SpawnTownDefense.sqf:47` |

Note: this function does **not** itself contain a GUER side gate — it spawns whatever `wfbe_defense_kind` resolves to for the passed side. The GUER-only behavior is structural: only the GUER recapture branch ever calls its driver (see 1.3). GUER's own kind list is intentionally sparse, so some GUER towns get fewer statics (`Common/Config/Defenses/Defenses_GUE.sqf:21`).

### 1.2 Gunner state machine — `Server_OperateTownDefensesUnits` (`WFBE_SE_FNC_OperateTownDefensesUnits`)

Compiled at `Server/Init/Init_Server.sqf:73`. Params `[_town, _side, _action]` where `_action` is `"spawn"` or `"remove"` (`Server/Functions/Server_OperateTownDefensesUnits.sqf:11-13`). This is the manning tri-state: it allocates a pooled gunner group, mans every emplacement in the town, or de-mans and reaps.

**Pooled gunner group (group-bloat reduction).** Instead of one group per gunner, it uses **one group per town per side**, stored on the town object:

| Concern | Behavior | Citation |
|---------|----------|----------|
| Group key | `wfbe_gungrp_<sideID>_<idx>`, read from the town object | `Server_OperateTownDefensesUnits.sqf:27-28` |
| 12-unit cap | While the current group has `>= 12` units, advance `_grpIdx` and try the next slot key | `Server_OperateTownDefensesUnits.sqf:31-36` |
| Create on miss | New group via `[_side, "defense-gunners"] Call WFBE_CO_FNC_CreateGroup`, flagged `wfbe_persistent` so empty-group GC won't reap it mid-life, stored back on the town | `Server_OperateTownDefensesUnits.sqf:37-43` |
| Global fallback | If creation fails (cap reached), fall back to `WFBE_<side>_DefenseTeam` | `Server_OperateTownDefensesUnits.sqf:45` |

**`"spawn"` action** — iterates `_town getVariable "wfbe_town_defenses"` and mans each emplacement whose `wfbe_defense` exists and whose gunner is null/dead (`:48-54`):

| Branch | Behavior | Citation |
|--------|----------|----------|
| HC delegation (`WFBE_C_AI_DELEGATION == 2`) | Pushes spawn position + `WFBE_<side>SOLDIER` template, and **only if** `WFBE_HEADLESSCLIENTS_ID` is non-empty calls `WFBE_CO_FNC_DelegateAIStaticDefenceHeadless` with the per-town group as `_team`; sets `_use_server = false` | `Server_OperateTownDefensesUnits.sqf:55-67` |
| Server fallback | `WFBE_CO_FNC_CreateUnit` of the `WFBE_<side>SOLDIER` template into the pooled group, tag `WFBE_IsTownDefenderAI`, `assignAsGunner` + `orderGetIn` + `moveInGunner`, `RevealArea` 175 m | `Server_OperateTownDefensesUnits.sqf:72-82` |
| Operator tracking | `_x setVariable ["wfbe_defense_operator", _unit]` — records the *original* server-side gunner for later cleanup | `Server_OperateTownDefensesUnits.sqf:83` |
| Anti-lag stagger | `sleep 0.5` between emplacements so a town doesn't spawn all gunners in one frame | `Server_OperateTownDefensesUnits.sqf:91` |
| Area reveal | After the loop, `[_team, range, _town] Call RevealArea` if the town has any defenses | `Server_OperateTownDefensesUnits.sqf:95-97` |

**`"remove"` action** — de-mans and reaps (`:101-138`):

| Step | Behavior | Citation |
|------|----------|----------|
| De-man current gunner | For each defense, if `gunner _defense` is non-null and alive, delete it **only if** its group has no `wfbe_funds` var (i.e. it is not a player-owned/funded squad). Dead gunners are deleted unconditionally | `Server_OperateTownDefensesUnits.sqf:106-114` |
| Delete original operator | If a tracked `wfbe_defense_operator` is still alive, `deleteVehicle` it and clear the var | `Server_OperateTownDefensesUnits.sqf:116-119` |
| Reap pooled groups | Walk every `wfbe_gungrp_<sideID>_<idx>`, clear `wfbe_persistent` to `false` and null the town's reference so the now-empty groups are collected by the empty-group GC | `Server_OperateTownDefensesUnits.sqf:122-138` |

### 1.3 (Re)spawn driver — `Server_ManageTownDefenses` (`WFBE_SE_FNC_ManageTownDefenses`)

Compiled at `Server/Init/Init_Server.sqf:71`. Params `[_town, _side, _sideID_old]` (`Server/Functions/Server_ManageTownDefenses.sqf:10-12`). For each entry in `wfbe_town_defenses`, decides whether the emplacement needs (re)spawning and calls `SpawnTownDefense`:

| Condition | Action | Citation |
|-----------|--------|----------|
| `wfbe_defense` is nil | Spawn | `Server_ManageTownDefenses.sqf:19-20` |
| Emplacement dead, or side changed (`_sideID_old != _sideID`) | `deleteVehicle` the old one, then spawn | `Server_ManageTownDefenses.sqf:22-25` |
| Spawn needed | `[_x, _side] Call WFBE_SE_FNC_SpawnTownDefense` | `Server_ManageTownDefenses.sqf:28-30` |

**Call sites / GUER gate.** `ManageTownDefenses` is invoked from `Common/Init/Init_Town.sqf:138` (initial town setup) and from the town-capture FSM at `Server/FSM/server_town.sqf:288`. Per the comment at `server_town.sqf:297`, recapture re-spawns statics **via ManageTownDefenses on the GUER path only** — the WEST/EAST path never calls it, and capturing a GUER town as WEST/EAST deletes the GUER-era emplacements (`server_town.sqf:295-304`). `OperateTownDefensesUnits` is then called for `"spawn"`/`"remove"` from `server_town.sqf:271,290` and `server_town_ai.sqf:262,318`.

---

## 2. Idempotent HC-aware manning — `Common_CreateUnitForStaticDefence`

`WFBE_CO_FNC_CreateUnitForStaticDefence`, compiled at `Common/Init/Init_Common.sqf:114`. Params `[_side, _groups, _positions, _team, _defence, _moveInGunner]`; returns `[_teams]` (the array of groups it touched) (`Common/Functions/Common_CreateUnitForStaticDefence.sqf:14-19,205`). This is the routine the **HC delegation path** funnels through (called from `Client/Functions/Client_DelegateAIStaticDefence.sqf:30`, which is the handler the HC runs after the server's `WFBE_CO_FNC_DelegateAIStaticDefenceHeadless` (`Server/Functions/Server_DelegateAIStaticDefenceHeadless.sqf`) dispatches the delegation via `SendToClient`). The server `"spawn"` path uses raw `CreateUnit` instead (see 1.2) — this helper is for the headless-client side.

### 2.1 Idempotency guards (early exits)

These run before any unit is created; each returns `[_teams]` (empty) so a duplicate request is a no-op:

| Guard | Condition | Citation |
|-------|-----------|----------|
| Null defence | `isNull _defence` → warn + bail | `Common_CreateUnitForStaticDefence.sqf:28-31` |
| Already crewed | `!isNull (gunner _defence)` → skip duplicate | `Common_CreateUnitForStaticDefence.sqf:33-36` |
| Assigned unit alive | `WFBE_StaticDefenseAssignedUnit` var holds a live unit → re-issue `allowGetIn`/`assignAsGunner`/`orderGetIn` (+ `moveInGunner` if requested) and bail | `Common_CreateUnitForStaticDefence.sqf:38-50` |
| Stale assigned unit | Assigned unit exists but dead → clear the var to `objNull` (public) and fall through | `Common_CreateUnitForStaticDefence.sqf:40-42` |
| Manning in progress | `WFBE_StaticDefenseManningInProgress` is true → another call is already manning this gun; bail | `Common_CreateUnitForStaticDefence.sqf:52-57` |
| Claim the lock | Set `WFBE_StaticDefenseManningInProgress = true` (public) before the work loop; reset to `false` at the end | `Common_CreateUnitForStaticDefence.sqf:58,194` |

Per-defence state vars (all stored on the `_defence` object, all broadcast public): `WFBE_StaticDefenseAssignedUnit` (current gunner), `WFBE_StaticDefenseManningInProgress` (lock), `WFBE_StaticDefenseSettled` (set once the gunner is confirmed in the gun, `:155`).

### 2.2 HC group-bridging (12-unit cap)

Because the delegated `_team` is a **server-owned group** (non-local on the HC), the HC cannot add units to it directly. The helper bridges to a machine-local counterpart keyed on the server group (`Common_CreateUnitForStaticDefence.sqf:68-115`):

| Step | Behavior | Citation |
|------|----------|----------|
| Non-local test | `!(isNull _serverTeam) && {count units _serverTeam == 0} && {!isServer}` — A2 note: `local` on a *group* throws, so `!isServer` is the trap-free "non-local group" test | `Common_CreateUnitForStaticDefence.sqf:75-78` |
| Lookup bridge | `_serverTeam getVariable "wfbe_hc_local_grp"` (machine-local, never broadcast) | `Common_CreateUnitForStaticDefence.sqf:81-82` |
| Overflow walk | While the bridged group has `>= 12` units, walk suffixed keys `wfbe_hc_local_grp1`, `wfbe_hc_local_grp2`, … | `Common_CreateUnitForStaticDefence.sqf:84-90` |
| Create + bridge | New `defense-gunners` group, flag `wfbe_persistent`, store under the base or suffixed key | `Common_CreateUnitForStaticDefence.sqf:91-103` |
| Standard path | On the server / for a passed local group: create the group if empty, or if the existing leader is non-local fall back to a fresh local group | `Common_CreateUnitForStaticDefence.sqf:105-114` |

### 2.3 Unit creation + the two watchdog Spawns

Per template in `_groups`, the unit is created via `WFBE_CO_FNC_CreateUnit` (`:120`), recorded into `WFBE_StaticDefenseAssignedUnit` (`:127`), pushed into `_teams`, then assigned (`allowGetIn`/`assignAsGunner`/`orderGetIn`, `:134-136`). Manning then forks on `_moveInGunner`, and **each branch arms a watchdog `Spawn`** to defeat the "AI walks to the gun but never mounts" stall:

| Branch | Watchdog | Citation |
|--------|----------|----------|
| `_moveInGunner == true` (instant) | `moveInGunner` immediately, then a `Spawn` that after `sleep 1` retries the full assign+`setPosATL`+`moveInGunner` if `gunner _defence != _unit`; once seated, `disableAI "MOVE"` and set `WFBE_StaticDefenseSettled` | `Common_CreateUnitForStaticDefence.sqf:138-157` |
| `_moveInGunner == false` (walk-in) | A `Spawn` with a 90 s deadline that `waitUntil` (5 s poll) the unit boards/dies/the gun dies; if still empty, force `assignAsGunner` → `sleep 10` → `moveInGunner` and log a warning | `Common_CreateUnitForStaticDefence.sqf:158-180` |

Tail: `RevealArea` 175 m on the gunner's group (`:186`), `allowFleeing 0` (`:187`), `UpdateStatistics 'UnitsCreated'` if any built (`:192`), release the manning lock (`:194`), and an optional `PerformanceAudit_Record` scope (`:198-203`). Diagnostic `TOWN_DEFENSE_DIAG` log lines are gated on `TownDefenseDiagnosticsEnabled` (`:26,129-131,182-184`).

---

## 3. Adjacent crewing / rearm helpers

### 3.1 `Common_UseStationaryDefense` (`UseStationaryDefense`)

Compiled at `Common/Init/Init_Common.sqf:87`. Params `[_units, _range]` (`Common/Functions/Common_UseStationaryDefense.sqf:3-4`). Sends a list of loose AI to man nearby empty emplacements:

| Step | Behavior | Citation |
|------|----------|----------|
| Resolve defense whitelist | `WFBE_%1DEFENSENAMES` for `side leader group (_units select 0)` | `Common_UseStationaryDefense.sqf:9` |
| Scan nearby | `nearEntities [_defenseTypes, _range]` from the units' leader | `Common_UseStationaryDefense.sqf:10` |
| Empty-gunner filter | Keep only entities with `EmptyPositions "gunner" > 0` | `Common_UseStationaryDefense.sqf:14` |
| Assign | For each on-foot, alive unit, `allowGetIn true` + `assignAsGunner` the last empty defense, then remove it from the pool | `Common_UseStationaryDefense.sqf:24-30` |

**Status — orphan/dead in this build.** `UseStationaryDefense` is compiled but has **no call site** anywhere in source (verified: the only `UseStationaryDefense` hit outside the function body is the compile line, `Init_Common.sqf:87`). The live town-defence path mans guns through sections 1–2 above, not through this helper.

`WFBE_%1DEFENSENAMES` is the full per-side structure whitelist (statics + buildings + ammo boxes), built and registered per faction at the bottom of each `Common/Config/Core_Structures/Structures_*.sqf` (e.g. `Structures_USMC.sqf:200`, `Structures_RU.sqf:201`, `Structures_GUE.sqf:167`; `Structures_CDF.sqf:170`). It is *not* an emplaced-gun-only list — the `EmptyPositions "gunner"` filter is what narrows it to manned statics here. It is also consumed by base-area scans (`Server/FSM/basearea.sqf:12`), the CoIn interface (`Client/Module/CoIn/coin_interface.sqf:245,665,708`), and defense purchase validation (`Server/PVFunctions/RequestDefense.sqf:11,154,199`).

### 3.2 `Common_SpawnTurrets` (`SpawnTurrets`)

Compiled at `Common/Init/Init_Common.sqf:84`. Params `[_turrets, _path, _vehicle, _crew, _team]` (`Common/Functions/Common_SpawnTurrets.sqf:2-6`). Recursively crews a vehicle's turret tree:

| Step | Behavior | Citation |
|------|----------|----------|
| Walk turret pairs | `while {_i < count _turrets}`, stepping `_i += 2` (index, then sub-turret array) | `Common_SpawnTurrets.sqf:9,21` |
| Fill empty turret | If `_vehicle turretUnit _thisTurret` is null, `CreateUnit` a crewman and `moveInTurret [_vehicle, _thisTurret]` | `Common_SpawnTurrets.sqf:14-16` |
| Recurse | `[_turrets select (_i+1), _thisTurret, _vehicle, _crew, _team] call SpawnTurrets` to descend into sub-turrets | `Common_SpawnTurrets.sqf:20` |

### 3.3 `Common_SetTurretsMagazines` (`WFBE_CO_FNC_SetTurretsMagazines`)

Compiled at `Common/Init/Init_Common.sqf:160` — **vanilla-gated**: only compiled when `!WF_A2_Vanilla`, otherwise set to an empty code block `{}`. Params `[_vehicle, _turretsData]` (`Common/Functions/Common_SetTurretsMagazines.sqf:10-11`). For each turret data row, `addMagazineTurret [_mag, _turretPath]` for every magazine in the row (`:13-16`); returns `true`. Sole caller: `Common_RearmVehicleOA.sqf:13`, which feeds it the output of `WFBE_CO_FNC_GetVehicleTurretsGear` after clearing the vehicle's ammo.

---

## Continue Reading

- [Defense-Structures-Catalog](Defense-Structures-Catalog) — the emplacement classnames and per-faction `WFBE_<side>_Defenses_<kind>` pools these functions draw from
- [Spawn-Primitive-Function-Reference](Spawn-Primitive-Function-Reference) — `WFBE_CO_FNC_CreateUnit` / `CreateGroup` primitives every manning path builds on
- [Headless-Delegation-And-Failover-Playbook](Headless-Delegation-And-Failover-Playbook) — the HC delegation path (`DelegateAIStaticDefenceHeadless`) and group-bridging context
- [Town-AI-Group-Composition-Catalog](Town-AI-Group-Composition-Catalog) — the garrison infantry/vehicle group templates that coexist with these static gunners
- [Vehicle-Equip-And-Rearm-Function-Reference](Vehicle-Equip-And-Rearm-Function-Reference) — `Common_RearmVehicleOA`, the caller of `SetTurretsMagazines`
