# Spawn Primitive Function Reference (CreateUnit / CreateVehicle / CreateTeam)

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Three wrappers in `Common/Functions/` form the sole authoritative path for spawning AI units and vehicles at runtime. Direct engine calls (`createUnit`, `createVehicle`, `createGroup`) appear elsewhere only for player-side construction or editor stubs. All town AI, static defense, and factory-bought AI funnels through these three functions.

---

## WFBE_CO_FNC_CreateUnit

**File:** `Common/Functions/Common_CreateUnit.sqf`

### Signature

```sqf
[_type, _team, _position, _side, _global, _special] Call WFBE_CO_FNC_CreateUnit
```

### Parameters

| # | Name | Type | Default | Notes |
|---|------|------|---------|-------|
| 0 | `_type` | String | _(required)_ | CfgVehicles class name | `Common_CreateUnit.sqf:14` |
| 1 | `_team` | Group | _(required)_ | Target group; may be `grpNull` (function will attempt `createGroup`) | `Common_CreateUnit.sqf:15` |
| 2 | `_position` | Array | _(required)_ | `[x,y,z]` world position | `Common_CreateUnit.sqf:16` |
| 3 | `_side` | Side or Number | _(required)_ | Either a SIDE value or a numeric side ID; both forms accepted | `Common_CreateUnit.sqf:17,27-31` |
| 4 | `_global` | Bool | `true` | Whether to run global client init (`setVehicleInit` + `processInitCommands`) | `Common_CreateUnit.sqf:18` |
| 5 | `_special` | String | `"FORM"` | Engine `createUnit` placement mode (`"FORM"`, `"NONE"`, `"CAN_COLLIDE"`, etc.) | `Common_CreateUnit.sqf:19` |

### Return value

`Object` — the created unit, or `objNull` on failure.

### Group handling

If `_team` is `grpNull` on entry, a new group is created via `createGroup _sideValue` (`Common_CreateUnit.sqf:32`). If the provided group has live units but its leader is not local, a fresh local fallback group is created and a WARNING is logged (`Common_CreateUnit.sqf:33-38`). If group creation still yields `grpNull`, the function exits with `objNull` and a WARNING (`Common_CreateUnit.sqf:42-45`).

### Skill resolution

The unit's skill is read from `missionNamespace getVariable _type` (selecting index `QUERYUNITSKILL`). If that variable is nil, the fallback is `WFBE_C_UNITS_SKILL_DEFAULT` (`Common_CreateUnit.sqf:47-48`). Skill is applied immediately after creation (`Common_CreateUnit.sqf:57`).

### Loadout special-cases

| Condition | Action | Source |
|-----------|--------|--------|
| `side _unit == east` and unit lacks `"NVGoggles"` | `addWeapon "NVGoggles"` | `Common_CreateUnit.sqf:59-61` |
| `_type == "Ins_Soldier_AT"` (Insurgent AT) | Removes three `PG7VL` magazines and `RPG7V`; adds `M47Launcher_EP1` and two `Dragon_EP1` magazines | `Common_CreateUnit.sqf:63-72` |
| `_type == "MVD_Soldier_AT"` (OPFOR AT) | Removes two `PG7VL` and one `OG7`; adds two `PG7VR` magazines | `Common_CreateUnit.sqf:74-81` |

### Global init decision tree

Evaluated only when `_global == true` (`Common_CreateUnit.sqf:83`).

| Context | `_globalInitMode` | Behavior |
|---------|------------------|----------|
| Running on a Headless Client (`isHeadLessClient == true`) | `"hcSkipped"` | No `setVehicleInit` broadcast. Prevents marker/action loop spawns on every JIP client for pure AI offload units. | `Common_CreateUnit.sqf:84-88` |
| Server/client, side is NOT `WFBE_DEFENDER_ID` (or `WFBE_ISTHREEWAY` is true), and `WFBE_C_UNITS_TRACK_INFANTRY > 0` | `"vehicleInit"` | `setVehicleInit` + `processInitCommands` with `Common\Init\Init_Unit.sqf` | `Common_CreateUnit.sqf:91-94` |
| Server/client, side is NOT defender, `WFBE_C_UNITS_TRACK_INFANTRY <= 0`, group leader is a player | `"localPlayerInit"` | `[_unit, _side] ExecVM 'Common\Init\Init_Unit.sqf'` (local only, no broadcast) | `Common_CreateUnit.sqf:96-100` |
| Server/client, side is NOT defender, `WFBE_C_UNITS_TRACK_INFANTRY <= 0`, leader is AI | `"trackOffNoPlayer"` | No init at all | `Common_CreateUnit.sqf:101-103` |
| Side is `WFBE_DEFENDER_ID` and `WFBE_ISTHREEWAY == false` | `"defenderSkipped"` | No init; mirrors HC skip rationale for defender AI | `Common_CreateUnit.sqf:104-106` |

The `_globalInitMode` string is recorded in the PerformanceAudit log for every unit creation when `PerformanceAuditEnabled` is true (`Common_CreateUnit.sqf:115-119`).

### Event handlers attached at creation

- `Killed`: calls `WFBE_CO_FNC_OnUnitKilled` (spawned) with the side ID baked in at creation time (`Common_CreateUnit.sqf:110`).

### Early-exit and null handling

All failure paths log a WARNING via `WFBE_CO_FNC_LogContent` and return `objNull`:

| Failure | Log tag | Source |
|---------|---------|--------|
| Group is null after all fallbacks | WARNING | `Common_CreateUnit.sqf:42-45` |
| Engine `createUnit` returned null (group/unit limit) | WARNING | `Common_CreateUnit.sqf:52-55` |

---

## WFBE_CO_FNC_CreateVehicle

**File:** `Common/Functions/Common_CreateVehicle.sqf`

### Signature

```sqf
[_type, _position, _side, _direction, _locked, _bounty, _global, _special] Call WFBE_CO_FNC_CreateVehicle
```

### Parameters

| # | Name | Type | Default | Notes |
|---|------|------|---------|-------|
| 0 | `_type` | String | _(required)_ | CfgVehicles class name | `Common_CreateVehicle.sqf:3` |
| 1 | `_position` | Array or Object | _(required)_ | `[x,y,z]` or an object (converted via `getPos`) | `Common_CreateVehicle.sqf:4,15` |
| 2 | `_side` | Side or Number | _(required)_ | SIDE value or numeric side ID | `Common_CreateVehicle.sqf:5,16` |
| 3 | `_direction` | Number | _(required)_ | Heading in degrees | `Common_CreateVehicle.sqf:6,39` |
| 4 | `_locked` | Bool | _(required)_ | Passed directly to `lock` | `Common_CreateVehicle.sqf:7,41` |
| 5 | `_bounty` | Bool | `true` | When true, attaches `killed` and `hit` event handlers for score/bounty | `Common_CreateVehicle.sqf:8,42-45` |
| 6 | `_global` | Bool | `true` | Whether to run global client init | `Common_CreateVehicle.sqf:9` |
| 7 | `_special` | String | `"FORM"` | Engine `createVehicle` placement mode | `Common_CreateVehicle.sqf:10` |

### Return value

`Object` — the created vehicle, or `objNull` on failure.

### Post-creation steps (in order)

1. If `_position` is an Object, it is converted to `getPos _position` before use (`Common_CreateVehicle.sqf:15`).
2. Engine `createVehicle [_type, _position, [], 7, _special]` is called (`Common_CreateVehicle.sqf:18`). Clearance radius is hard-coded to **7** metres.
3. If the result is `objNull`, a WARNING is logged and `objNull` is returned (`Common_CreateVehicle.sqf:21-24`).
4. Tank and APC variants: `Common\Functions\Common_ModifyVehicle.sqf` is invoked (`Common_CreateVehicle.sqf:26`). This attaches a per-class `HandleDamage` rearmor handler that reduces incoming damage by a type-specific percentage. Air vehicles: `Common_ModifyAirVehicle.sqf` is commented out (`Common_CreateVehicle.sqf:29-31`).
5. All vehicles: `Common\Functions\Common_AddVehicleTexture.sqf` is invoked (`Common_CreateVehicle.sqf:32`).
6. Velocity is set:
   - `_special != "FLY"`: `setVelocity [0,0,-1]` (grounding nudge) (`Common_CreateVehicle.sqf:35`).
   - `_special == "FLY"`: `setVelocity [50 * (sin _direction), 50 * (cos _direction), 0]` (forward launch velocity of 50 m/s in the given heading) (`Common_CreateVehicle.sqf:37`).
7. `setDir _direction` (`Common_CreateVehicle.sqf:39`).
8. Lock applied if `_locked` is true (`Common_CreateVehicle.sqf:41`).
9. Bounty event handlers attached if `_bounty` is true: `killed` → `WFBE_CO_FNC_OnUnitKilled`, `hit` → `WFBE_CO_FNC_OnUnitHit` (`Common_CreateVehicle.sqf:42-45`).

### Global init decision tree

Evaluated only when `_global == true` (`Common_CreateVehicle.sqf:47`).

| Context | `_globalInitMode` | Behavior |
|---------|------------------|----------|
| Running on HC (`isHeadLessClient == true`) | `"hcSkipped"` | No broadcast | `Common_CreateVehicle.sqf:48-50` |
| Side is NOT `WFBE_DEFENDER_ID` (or three-way active) | `"vehicleInit"` | `setVehicleInit` + `processInitCommands` with `Common\Init\Init_Unit.sqf` | `Common_CreateVehicle.sqf:52-58` |
| Side is `WFBE_DEFENDER_ID` (two-way game) | `"defenderSkipped"` | No init | `Common_CreateVehicle.sqf:52-58` |

Note: `CreateVehicle` has no `trackOffNoPlayer` branch — that path exists only in `CreateUnit`.

### Map combat-marker Fired EH

Attached after global init, independently, when **both** conditions are true:

- `_global == true`
- `WFBE_C_MAP_ICON_BLINKING_ENABLED == 1` (default `0`)

```sqf
_vehicle addEventHandler ["Fired", {
    _u = _this select 0;
    _u Call WFBE_CL_FNC_SetMapIconStatusInCombat;
}];
```
`Common_CreateVehicle.sqf:63-68`

Town AI vehicles created with `_global == false` (delegated to HC) never receive this EH, keeping them marker-light.

### Passing `_bounty = false`

Callers that own the vehicle's scoring lifecycle (e.g. player-constructed defenses managed by another handler) can pass `false` to suppress the bounty EH pair. `CreateTeam` always passes `true` when invoking `CreateVehicle` (`Common_CreateTeam.sqf:104`).

---

## WFBE_CO_FNC_CreateTeam

**File:** `Common/Functions/Common_CreateTeam.sqf`

### Signature

```sqf
[_list, _position, _side, _lockVehicles, _team, _global, _probability] Call WFBE_CO_FNC_CreateTeam
```

### Parameters

| # | Name | Type | Default | Notes |
|---|------|------|---------|-------|
| 0 | `_list` | Array or String | _(required)_ | Array of class names (template); a bare String is auto-wrapped into `[_list]` | `Common_CreateTeam.sqf:4,23` |
| 1 | `_position` | Array | _(required)_ | `[x,y,z]` spawn position | `Common_CreateTeam.sqf:5` |
| 2 | `_side` | Side | _(required)_ | SIDE value (not numeric ID) | `Common_CreateTeam.sqf:6` |
| 3 | `_lockVehicles` | Bool | _(required)_ | Passed as `_locked` to each `CreateVehicle` call | `Common_CreateTeam.sqf:8` |
| 4 | `_team` | Group | _(required)_ | Existing group or `grpNull`; if null a new group is created | `Common_CreateTeam.sqf:9` |
| 5 | `_global` | Bool | `true` | Forwarded to every `CreateUnit` and `CreateVehicle` call | `Common_CreateTeam.sqf:10` |
| 6 | `_probability` | Number | `-1` | 0–100 spawn probability per template entry; `-1` disables probabilistic skipping | `Common_CreateTeam.sqf:11` |

### Return value

A 4-element Array: `[_units, _vehicles, _team, _crews]`

| Index | Content |
|-------|---------|
| 0 | Array of infantry `Object` values successfully created |
| 1 | Array of vehicle `Object` values successfully created |
| 2 | The `Group` actually used (may differ from the input `_team` if a new group was created) |
| 3 | Array of crew `Object` values mounted into vehicles |

`Common_CreateTeam.sqf:173`

Callers **must** read index 2 for the actual group rather than relying on the input parameter, since HC delegation may produce a new group (`Common_CreateTownUnits.sqf:37`).

### Probability gating

When `_probability != -1`, the first template entry in `_list` is always spawned (`_firstDone` guard). Each subsequent entry is only spawned if `random 100 <= _probability` (`Common_CreateTeam.sqf:87-89`). `Common_CreateTownUnits.sqf` calls with `_probability = 90` (`Common_CreateTownUnits.sqf:33`).

### Template iteration

`forEach _list` processes each class name in order (`Common_CreateTeam.sqf:85-163`):

- **Infantry** (`_x isKindOf 'Man'`): delegates to `WFBE_CO_FNC_CreateUnit` with the team and `_global` flag forwarded. Null results increment `_perfSkipped` (`Common_CreateTeam.sqf:93-102`).
- **Vehicles**: delegates to `WFBE_CO_FNC_CreateVehicle` with direction `0`, `_lockVehicles`, bounty `true`, and `_global` (`Common_CreateTeam.sqf:104`). If the vehicle is null, the template entry is skipped. If not null, crew is assigned:
  - Crew class is resolved by vehicle kind: `isKindOf 'Man'` → `WFBE_%1SOLDIER`, `isKindOf 'Air'` → `WFBE_%1PILOT`, else → `WFBE_%1CREW` (where `%1` is the side string) (`Common_CreateTeam.sqf:111`).
  - `allowCrewInImmobile true` and `addVehicle _vehicle` are called before any crew is created (`Common_CreateTeam.sqf:114-115`).
  - Roles iterated: `"driver"`, `"gunner"`, `"commander"` — each only filled if `emptyPositions _crewRole > 0` (`Common_CreateTeam.sqf:119,145`).
  - Each crew unit receives a `HandleDamage` EH (the inline `_rearmor` closure) that reduces damage from autocannon rounds (`B_20mm_AA`, `B_23mm_AA`, `B_25mm_HE`, `B_25mm_HEI`, `B_30mm_AA`, `B_30mm_HE`) by **20%** (`Common_CreateTeam.sqf:68-82,142`).
  - If zero crew were successfully created, the vehicle is immediately `deleteVehicle`'d and a WARNING is logged (`Common_CreateTeam.sqf:148-152`).

### Group-cap saturation path (TOWN_GROUP_COUNT diagnostic)

If `createGroup _side` returns `grpNull` (Arma's per-side group limit is reached), the function exits immediately before spawning any units or vehicles. The exit path:

1. Counts all current groups on this machine by side using `allGroups` + `forEach` (`Common_CreateTeam.sqf:31-55`).
2. Emits a WARNING log line prefixed `TOWN_GROUP_COUNT create_failed` containing: machine type (SERVER/CLIENT/HC), side, per-side group count, total group count, and per-side breakdown (`Common_CreateTeam.sqf:57`).
3. Returns `[[], [], _team, []]` — an empty result tuple (`Common_CreateTeam.sqf:65`).

The same TOWN_GROUP_COUNT diagnostic (prefixed `town_empty`) fires in `Common_CreateTownUnits.sqf:73-101` when a town activates with zero units and zero vehicles created.

**Interpreting TOWN_GROUP_COUNT in logs:** a `create_failed` entry means the machine creating town AI has hit the engine side group cap. The per-side count in the log identifies which side is saturated. This is the primary group-leak signal. See [AI-Headless-And-Performance](AI-Headless-And-Performance) for cap values and mitigation patterns.

---

## Call-site summary

| Caller | Function called | Notable arguments |
|--------|----------------|-------------------|
| `Common_CreateTownUnits.sqf:33` | `CreateTeam` | `_probability=90`, `_global=true` |
| `Common_CreateTeam.sqf:95` | `CreateUnit` | `_global` forwarded from team level |
| `Common_CreateTeam.sqf:104` | `CreateVehicle` | direction `0`, bounty `true`, `_global` forwarded |
| `Common_CreateTeam.sqf:120` | `CreateUnit` | crew creation, same `_global` |
| `Common_CreateUnitForStaticDefence.sqf:76` | `CreateUnit` | no `_global` arg (defaults `true`) |

---

## Shared behaviors across all three functions

### PerformanceAudit integration

All three functions record a PerformanceAudit entry when `PerformanceAudit_Record` is non-nil and `PerformanceAuditEnabled` is true:

| Function | Audit event name | Key fields logged |
|----------|-----------------|-------------------|
| `CreateUnit` | `"createunit"` | type, side, global, trackInf, init mode, leaderPlayer, isMan | `Common_CreateUnit.sqf:118` |
| `CreateVehicle` | `"createvehicle"` | type, side, global, init mode, bounty, locked, special, isAir, isTank, isCar | `Common_CreateVehicle.sqf:75` |
| `CreateTeam` | `"createteam"` | side, global, templates, infantry, vehicles, crews, skipped, groupNull | `Common_CreateTeam.sqf:62,169` |

### HC skip rationale

Both `CreateUnit` and `CreateVehicle` check `!isNil "isHeadLessClient" && {isHeadLessClient}` before any `setVehicleInit` call. When this is true, global init is skipped entirely. This prevents the `Init_Unit.sqf` client setup — which adds map markers, action menu entries, missile EHs, and AAR tracking — from being broadcast via `setVehicleInit` and re-executing on every JIP client for pure AI units that have no player-visible marker need.

### Side ID normalization

Both `CreateUnit` and `CreateVehicle` accept either a `SIDE` value or a numeric side ID and normalize via `WFBE_CO_FNC_GetSideID` / `WFBE_CO_FNC_GetSideFromID`. `CreateTeam` expects a `SIDE` value and calls `GetSideID` immediately (`Common_CreateTeam.sqf:7`).

---

## What Init_Unit.sqf does (client side)

`Common/Init/Init_Unit.sqf` is the script invoked by the `setVehicleInit` broadcast. Key client-only effects:

- Waits for `commonInitComplete` and `clientInitComplete` before proceeding (`Init_Unit.sqf:18,33`).
- Adds NVGoggles to east units lacking them (mirrors CreateUnit's server-side patch) (`Init_Unit.sqf:46-48`).
- Adds Airlift action if `WFBE_UP_AIRLIFT > 0` (`Init_Unit.sqf:52-55`).
- Adds repair/build/camp/HQ actions to repair trucks (`Init_Unit.sqf:56-69`).
- Adds Low Gear toggle to tanks and cars; Push action to ships; HALO and Cargo Eject to air transports (`Init_Unit.sqf:71-93`).
- Attaches countermeasure EH for `WFBE_C_MODULE_WFBE_FLARES` (vanilla only) (`Init_Unit.sqf:96-109`).
- Attaches AAR tracking for enemy aircraft when `WFBE_C_STRUCTURES_ANTIAIRRADAR > 0` (`Init_Unit.sqf:111-116`).
- Attaches missile masking EH for tanks, cars, and air (`Init_Unit.sqf:208-213`).
- Creates a per-side map marker (type, color, size, and refresh rate vary by vehicle kind and side match) (`Init_Unit.sqf:144-196`).
- Attaches combat blinking `Fired` EH when `WFBE_C_MAP_ICON_BLINKING_ENABLED == 1` (`Init_Unit.sqf:186-192`).

All of this runs **only on the matching player's client** (`sideID == _sideID`, exit at `Init_Unit.sqf:142`) after a hard `sleep 2` (`Init_Unit.sqf:34`). This is why broadcasting it for every town AI unit via `setVehicleInit` causes client CPU spikes.

---

## Continue Reading

- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — how player buy paths invoke `CreateUnit`/`CreateVehicle` for purchased AI
- [Towns-Camps-And-Capture-Atlas](Towns-Camps-And-Capture-Atlas) — town activation lifecycle and how `Common_CreateTownUnits.sqf` feeds into this page's functions
- [AI-Headless-And-Performance](AI-Headless-And-Performance) — HC delegation topology, per-side group caps, and interpreting TOWN_GROUP_COUNT log lines
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*`, `WFBE_UP_*`, and side ID constant conventions referenced throughout
- [Construction-And-CoIn-Systems-Atlas](Construction-And-CoIn-Systems-Atlas) — static defense creation via `Common_CreateUnitForStaticDefence.sqf`
