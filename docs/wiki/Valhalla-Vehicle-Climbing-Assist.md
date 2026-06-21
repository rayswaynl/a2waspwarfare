# Valhalla — Vehicle Climbing Assist and Low-Gear System

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The Valhalla module is a client-side velocity-boost system that assists player-driven and AI-driven vehicles over steep terrain. It applies a progressive speed multiplier when the vehicle is already moving forward but too slowly — it does not cap top speed and does not brake above the target assist speed. Only `Tank` and `Car` class vehicles are eligible.

---

## Bootstrap Sequence

| Step | Where | Source |
|---|---|---|
| `Init_Valhalla.sqf` called (spawned) | `Init_Client.sqf:765-767` | Runs during client init; compiles `VALHALLA_FNC_LowGear` and installs the key EHs |
| `Func_Client_AI_LowGear_Manager.sqf` spawned | `Init_Client.sqf:968` | Separate `[] spawn` at end of client init; runs for the full session |
| Profile variable read | `Client/Init/Init_ProfileVariables.sqf:27-34` | `WFBE_HIGH_CLIMBING_DEFAULT_ENABLED` loaded from `profileNamespace` before Valhalla init |

---

## Key Tracking (Init_Valhalla.sqf)

`Init_Valhalla.sqf` binds two display-level event handlers on display 46 (the main game display):

```sqf
(findDisplay 46) displayAddEventHandler ["KeyDown", "_this call VALHALLA_FNC_HandleLowGearKeyDown"];
(findDisplay 46) displayAddEventHandler ["KeyUp", "_this call VALHALLA_FNC_HandleLowGearKeyUp"];
```
`Init_Valhalla.sqf:57-58`

The tracked keys are the union of three action-key arrays resolved at startup:

```sqf
Local_HighClimbingForwardActionKeys =
    (actionKeys "carForward") +
    (actionKeys "carFastForward") +
    (actionKeys "carSlowForward");
```
`Init_Valhalla.sqf:15-18`

**KeyDown** pushes a matching key into `Local_HighClimbingForwardKeys` and sets `Local_KeyPressedForward = true`. `Init_Valhalla.sqf:34-38`

**KeyUp** removes the key from the list and resets `Local_KeyPressedForward` to `count Local_HighClimbingForwardKeys > 0`, so multi-key holds are handled correctly. `Init_Valhalla.sqf:49-52`

**State locals initialised by Init_Valhalla.sqf:**

| Local variable | Initial value | Purpose |
|---|---|---|
| `Local_HighClimbingModeOn` | `false` | Whether climb assist is currently active |
| `Local_HighClimbingRunning` | `false` | Re-entry guard for the boost loop |
| `Local_KeyPressedForward` | `false` | Forward key currently held |
| `Local_HighClimbingForwardKeys` | `[]` | List of currently held forward keys |

`Init_Valhalla.sqf:12-14,19`

---

## Profile Persistence (WFBE_HighClimbingDefaultEnabled)

`WFBE_HighClimbingDefaultEnabled` / `WFBE_HIGH_CLIMBING_DEFAULT_ENABLED` is the player's saved preference for whether newly-entered vehicles start with climb assist enabled.

| Location | Behaviour | Source |
|---|---|---|
| `Init_ProfileVariables.sqf:27-34` | Loaded from `profileNamespace` into `missionNamespace` as `WFBE_HighClimbingDefaultEnabled`; defaults to `false` if absent or wrong type | Client init, before Valhalla |
| `Init_Valhalla.sqf:6-11` | Secondary nil-guard: if `WFBE_HighClimbingDefaultEnabled` is not yet defined, reads it again from `profileNamespace` | Runs slightly later than `Init_ProfileVariables.sqf`; guard is defensive |
| `GUI_Menu_Team.sqf:14-17` | Button label reflects current value on dialog open | `Client/GUI/GUI_Menu_Team.sqf` |
| `GUI_Menu_Team.sqf:164-181` | `MenuAction == 14` toggles the value, updates `missionNamespace`, updates button label, and persists via `WFBE_CO_FNC_SetProfileVariable` if available, otherwise direct `profileNamespace setVariable` + `saveProfileNamespace` | `Client/GUI/GUI_Menu_Team.sqf` |

The preference toggle is in the **Team Menu** (dialog idd 13000), button idc 13020, localised as `STR_WF_TEAM_HighClimbingDefaultOn` / `STR_WF_TEAM_HighClimbingDefaultOff`.

---

## Per-Vehicle Flag (WFBE_HighClimbingEnabled)

Each eligible vehicle carries a broadcast variable that gates the boost loop:

| Detail | Value | Source |
|---|---|---|
| Variable name | `WFBE_HighClimbingEnabled` | `Func_Client_LowGear.sqf:71`, `LowGear_Toggle.sqf:11` |
| Scope | `setVariable [name, value, true]` — broadcast to all machines | `LowGear_Toggle.sqf:13`, `Func_Client_AI_LowGear_Manager.sqf:34` |
| Default when unset on a Tank or Car | Value of `WFBE_HighClimbingDefaultEnabled` | `Func_Client_AI_LowGear_Manager.sqf:21-34` |
| Default for all other vehicle classes | `false` (not assigned) | `Func_Client_AI_LowGear_Manager.sqf:21-34` |

**LowGear_Toggle.sqf** is the per-vehicle runtime toggle. It flips `WFBE_HighClimbingEnabled` on the vehicle, broadcasts it, and if the local player is the driver it updates `Local_HighClimbingModeOn` and spawns the boost loop if needed. `LowGear_Toggle.sqf:1-21`

---

## Player Boost Loop (Func_Client_LowGear.sqf)

Spawned against the vehicle object (`_vehicle spawn VALHALLA_FNC_LowGear`). Protected by a re-entry guard on `Local_HighClimbingRunning`.

**Loop exit condition** — any of the following ends the loop:

- `player != driver _vehicle`
- `!Local_HighClimbingModeOn`
- `!(_vehicle getVariable ["WFBE_HighClimbingEnabled", false])`
- `!canMove _vehicle`

`Func_Client_LowGear.sqf:68-73`

**Speed parameters:**

| Parameter | Cars | Tanks | Source |
|---|---|---|---|
| `_min` — target assist speed (km/h) | 40 | 30 | `Func_Client_LowGear.sqf:52,65` |
| `_minBoostSpeed` — minimum speed before boost is applied | 1 | 1 | `Func_Client_LowGear.sqf:56` |

**Boost coefficient curve:**

| Coefficient | Value | Source |
|---|---|---|
| `_baseBoostCoef` (applied near `_min`) | 1.05 | `Func_Client_LowGear.sqf:60` |
| `_maxBoostCoef` (applied near 0 km/h) | 1.30 | `Func_Client_LowGear.sqf:61` |

The multiplier is interpolated linearly between `_baseBoostCoef` and `_maxBoostCoef` based on how far below `_min` the current speed is:

```sqf
_boostCoef = _baseBoostCoef + (((_min - _speed) / _min) * (_maxBoostCoef - _baseBoostCoef));
if (_boostCoef > _maxBoostCoef) then {_boostCoef = _maxBoostCoef};
```
`Func_Client_LowGear.sqf:88-89`

Boost is only applied when ALL conditions hold: `Local_KeyPressedForward`, engine on, `_speed > _minBoostSpeed`, `_speed < _min`, and velocity direction within 15 degrees of vehicle heading. `Func_Client_LowGear.sqf:78-99`

The Z component of velocity is not modified — vertical movement is unaffected. `Func_Client_LowGear.sqf:91-95`

Loop sleep interval: `0.1` seconds. `Func_Client_LowGear.sqf:101`

On exit, both `Local_HighClimbingModeOn` and `Local_HighClimbingRunning` are reset to `false`. `Func_Client_LowGear.sqf:104-105`

---

## AI Tank Manager (Func_Client_AI_LowGear_Manager.sqf)

A `while {!gameOver}` loop spawned once at client init (`Init_Client.sqf:968`). It runs on the owning client for all AI-driven tanks in the player's group.

**Each iteration (every 5 seconds):**

1. Checks the player's current vehicle: if the player is the driver of a Tank or Car and `WFBE_HighClimbingEnabled` is not yet set, assigns it from `WFBE_HighClimbingDefaultEnabled` and broadcasts it. `Func_Client_AI_LowGear_Manager.sqf:21-34`
2. If the player is driving and the flag is enabled and both `!Local_HighClimbingModeOn` and `!Local_HighClimbingRunning`, starts the boost loop. `Func_Client_AI_LowGear_Manager.sqf:37`
3. Iterates `units group player`: for every AI-driven Tank that is `local` and does not already have `AI_LowGear_Running == true`, spawns `Common_AI_LowGear.sqf` against that vehicle. `Func_Client_AI_LowGear_Manager.sqf:47-69`

**Performance audit integration:** the manager records a sample every iteration:

```sqf
["ai_lowgear_manager", diag_tickTime - _perfStart, Format["groupUnits:%1;started:%2", _perfUnits, _perfStarted], "CLIENT"] Call PerformanceAudit_Record;
```
`Func_Client_AI_LowGear_Manager.sqf:72-75`

The record is conditional on `PerformanceAuditEnabled` (defaults `true`) and skipped if `PerformanceAudit_Record` is nil. The payload includes group unit count and count of low-gear scripts started that tick.

**Scalability note:** on a large group the manager spawns one `Common_AI_LowGear.sqf` script per un-assisted AI tank per iteration. Each spawned script self-terminates when the vehicle is destroyed, no longer local, or `AI_LowGear_Running` is false; it does not rely on the manager to clean it up.

---

## AI Tank Boost Loop (Common_AI_LowGear.sqf)

Runs client-side on the machine that owns (is local to) the vehicle. Guards:

- Exits immediately if vehicle is null, not a `Tank`, or not local. `Common_AI_LowGear.sqf:43-47`
- Re-entry guard via `AI_LowGear_Running` vehicle variable (local-only, not broadcast). `Common_AI_LowGear.sqf:50-51`

**Speed parameters** (same curve as player variant, tank-specific values):

| Parameter | Value | Source |
|---|---|---|
| `_min` | 30 km/h | `Common_AI_LowGear.sqf:72` |
| `_minBoostSpeed` | 3 km/h | `Common_AI_LowGear.sqf:76` |
| `_baseBoostCoef` | 1.05 | `Common_AI_LowGear.sqf:80` |
| `_maxBoostCoef` | 1.30 | `Common_AI_LowGear.sqf:81` |

**Additional AI-specific guards before applying boost:**

| Guard | Effect | Source |
|---|---|---|
| `WFBE_HighClimbingEnabled` on vehicle | If player crew is present, reads `WFBE_HighClimbingEnabled` from the vehicle; if no player crew, always `true` (AI tanks without a player crew are always assisted) | `Common_AI_LowGear.sqf:103-107` |
| `!isPlayer _driver` | Human-driven tanks are not boosted by this script | `Common_AI_LowGear.sqf:96` |
| `!(stopped _driver)` | No boost if AI driver is stopped | `Common_AI_LowGear.sqf:112` |
| `!(_currentCommand in ["WAIT", "STOP"])` | No boost during explicit hold orders | `Common_AI_LowGear.sqf:112` |

**Sleep delay** is adaptive: `0.1` s when the engine is running and assist is enabled, `0.5` s otherwise. `Common_AI_LowGear.sqf:98,141`

On loop exit, `AI_LowGear_Running` is reset to `false` (local-only). `Common_AI_LowGear.sqf:144`

---

## Variable Summary

| Variable | Namespace | Type | Purpose |
|---|---|---|---|
| `WFBE_HIGH_CLIMBING_DEFAULT_ENABLED` | `profileNamespace` | BOOL | Persisted player preference |
| `WFBE_HighClimbingDefaultEnabled` | `missionNamespace` | BOOL | Session copy of above |
| `WFBE_HighClimbingEnabled` | vehicle (broadcast) | BOOL | Per-vehicle climb-assist gate |
| `AI_LowGear_Running` | vehicle (local only) | BOOL | Re-entry guard for `Common_AI_LowGear` |
| `Local_HighClimbingModeOn` | `missionNamespace` (local) | BOOL | Boost loop active flag |
| `Local_HighClimbingRunning` | `missionNamespace` (local) | BOOL | Re-entry guard for player boost loop |
| `Local_KeyPressedForward` | `missionNamespace` (local) | BOOL | Forward key currently held |
| `Local_HighClimbingForwardKeys` | `missionNamespace` (local) | ARRAY | List of held forward-key codes |
| `VALHALLA_FNC_LowGear` | `missionNamespace` | CODE | Compiled player boost loop |

---

## Continue Reading

- [Modules-Atlas](Modules-Atlas) — inventory of all client modules including the one-line Valhalla entry this page expands
- [Player-Vehicle-And-Travel-Actions-Reference](Player-Vehicle-And-Travel-Actions-Reference) — action-map route for adjacent vehicle scroll actions such as manual flip, Push, HALO, Cargo Eject and Taxi Reverse
- [AI-Headless-And-Performance](AI-Headless-And-Performance) — broader context for client-side AI performance and the Performance Audit system that `ai_lowgear_manager` records into
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — which Tank and Car classnames exist per faction; determines which vehicles the climb assist is eligible for
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` / `WFBE_UP_*` / `Local_*` naming rules
- [Client-UI-And-Server-Loop-Perf-Findings](Client-UI-And-Server-Loop-Perf-Findings) — performance findings relevant to the per-group polling loop in the AI manager
