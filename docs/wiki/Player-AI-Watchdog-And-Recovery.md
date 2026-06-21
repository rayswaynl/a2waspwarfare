# Player AI Watchdog and Recovery System

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The Player AI Watchdog and Recovery system is a WASP-original feature that automatically detects stuck player-owned AI units and issues corrective movement orders, and also exposes a manual mouse-wheel action so the group leader can trigger recovery on demand. It comprises three source files:

| File | Role |
|---|---|
| `Client/Functions/Client_WatchdogPlayerAI.sqf` | Singleton background loop; detects stuck units, triggers automatic recovery |
| `Client/Functions/Client_RecoverPlayerAI.sqf` | 3-phase recovery algorithm; invoked by both the watchdog (automatic) and the player action (manual) |
| `Client/Functions/Client_AddPlayerAIActions.sqf` | Adds the "Recover my AI movement" mouse-wheel action (and debug "Diagnose my AI") to the player |

---

## Startup and Singleton Guard

The watchdog is spawned unconditionally for every client during `Init_Client.sqf`:

```sqf
[] Spawn Compile preprocessFileLineNumbers "Client\Functions\Client_WatchdogPlayerAI.sqf";
```

`Client/Init/Init_Client.sqf:530`

A single-instance guard at the top of the watchdog file prevents duplicate loops if the file is ever compiled twice:

```sqf
if (missionNamespace getVariable ["Player_AI_Watchdog_Running", false]) exitWith {};
missionNamespace setVariable ["Player_AI_Watchdog_Running", true];
```

`Client/Functions/Client_WatchdogPlayerAI.sqf:58-59`

The watchdog then waits 20 seconds before its first tick to allow the client to finish initialising. `Client/Functions/Client_WatchdogPlayerAI.sqf:147`

---

## Watchdog Configuration Constants

All constants are local variables set at the top of `Client_WatchdogPlayerAI.sqf`. There are no mission-parameter overrides; changing them requires editing the file.

| Constant | Value | Meaning | Source |
|---|---|---|---|
| `_check_interval` | 15 s | Sleep between each watchdog pass | `:66` |
| `_required_stuck_time` | 45 s | Elapsed time without movement before recovery fires (normal destinations) | `:67` |
| `_required_close_stuck_time` | 75 s | Same threshold for close-range destinations | `:68` |
| `_recovery_cooldown` | 120 s | Minimum time between two automatic recoveries for the same unit | `:69` |
| `_min_destination_distance` | 50 m | Destinations closer than this are ignored (auto mode) | `:70` |
| `_min_close_destination_distance` | 50 m | Lower bound for the "close destination" code path (same value as above in auto mode) | `:74` |
| `_min_movement_distance` | 5 m | Unit must have moved less than this over `_required_stuck_time` to count as stuck | `:76` |
| `_destination_change_distance` | 25 m | If the `expectedDestination` shifts by more than this, the stuck timer resets | `:77` |
| `_max_valid_destination_coordinate` | 50 000 | X or Y coordinate above this is treated as an engine sentinel and rejected | `:80` |
| `_max_valid_destination_z` | 10 000 | Z coordinate above this is treated as an engine sentinel and rejected | `:81` |

---

## Unit Eligibility Filter (Watchdog Pass)

On each 15-second tick the watchdog iterates `units (group _player)`. A unit is skipped unless all of the following hold. These checks are inside a `Call {}` block, so each failing condition is an early `exitWith {false}`.

`Client/Functions/Client_WatchdogPlayerAI.sqf:175-209`

| Gate | Check | Notes |
|---|---|---|
| Player is group leader | `leader (group _player) == _player` | Entire pass exits if false `:162` |
| Unit not null | `!isNull _current_unit` | `:176` |
| Unit alive | `alive _current_unit` | `:177` |
| Not a player | `!isPlayer _current_unit` | `:178` |
| Not the player himself | `_current_unit != _player` | `:179` |
| Not crew in player's current vehicle | `!(_player_vehicle != _player && _vehicle == _player_vehicle)` | Prevents conflicting crew orders `:185` |
| Unit is the movement controller | `_vehicle == _current_unit` OR `driver _vehicle == _current_unit` | Passengers are never recovered `:190-198` |
| Unit is local | `local _current_unit` | `:199` |
| Vehicle is local | `local _vehicle` | `:200` |
| Movement physically possible | `[_current_unit, _vehicle] Call _movement_can_work` | `canMove` check `:201` |
| Not under a deliberate STOP order | `currentCommand _current_unit != "STOP"` | Explicit stop orders are never overridden `:207` |

---

## Destination Validation

`expectedDestination` can return engine sentinel values such as `[0, 0, 1e+009]` when AI state is corrupted. Both files share the same validation logic:

`Client/Functions/Client_WatchdogPlayerAI.sqf:116-140` / `Client/Functions/Client_RecoverPlayerAI.sqf:262-286`

Rejection conditions (any one causes the destination to be treated as unusable):

- Result is not an `ARRAY` or has fewer than 2 elements
- X or Y component is not `SCALAR`
- `X == 0 && Y == 0` (null origin)
- X or Y is negative (off-map)
- X or Y exceeds `_max_valid_destination_coordinate` (50 000)
- Z exceeds `_max_valid_destination_z` (10 000) or is below -100

---

## Stuck Detection Algorithm

For each eligible unit the watchdog reads three per-unit variables set on previous ticks:

| Variable | Type | Purpose | Source |
|---|---|---|---|
| `Player_AI_Watchdog_Last_Position` | `ARRAY` (ATL pos) | Unit position at last tick | `:255` |
| `Player_AI_Watchdog_Last_Time` | `SCALAR` | Mission time at last tick | `:256` |
| `Player_AI_Watchdog_Last_Destination` | `ARRAY` (position) | `expectedDestination` at last tick | `:257` |
| `Player_AI_Watchdog_Last_Recovery` | `SCALAR` | Mission time of last automatic recovery (-5000 default) | `:258` |

The unit resets all three state variables (timer restarts) in the following cases:

1. No previous position recorded — first observation `:260-266`
2. No previous destination recorded `:268-274`
3. The current `expectedDestination` has moved more than `_destination_change_distance` (25 m) from the recorded value — the unit received a new order `:276-282`
4. The unit has moved at least `_min_movement_distance` (5 m) since last tick — unit is progressing normally `:284-292`

Recovery fires only when:

- None of the above resets occurred (same position, same destination, same order)
- The elapsed time since `_last_check_time` meets the applicable threshold:
  - Normal destination: ≥ 45 s (`_required_stuck_time`) `:299`
  - Close destination: ≥ 75 s (`_required_close_stuck_time`) `:295`
- At least 120 s have passed since the last automatic recovery for this unit (`_recovery_cooldown`) `:302`

`_is_close_destination` is always false in automatic mode because `_min_close_destination_distance` and `_min_destination_distance` are both 50 m. The "close" branch is only reached when `_distance_to_destination` is not > 50 m (outer check at `:233` already set `_has_useful_destination = false`), but the inner check at `:238` also requires `_distance_to_destination > _min_close_destination_distance` (> 50 m) — a condition that can never hold in that branch. The close-destination code path is therefore effectively disabled in automatic mode and exists as a reserved extension point. As a consequence the engine-guard block at `:250-253` (`currentCommand == "MOVE" && !unitReady`) is unreachable in practice.

On a recovery decision the watchdog sets `Player_AI_Watchdog_Last_Recovery` and resets the position/time/destination state variables, then appends the unit to `_stuck_units_to_recover` `:307-313`.

---

## Watchdog → Recovery Handoff

After a complete group pass, the watchdog launches the recovery script via `ExecVM` (not `Call` or `Spawn`), passing the collected list and the automatic-mode flag:

```sqf
[objNull, _player, -1, [_stuck_units_to_recover, true]] ExecVM "Client\Functions\Client_RecoverPlayerAI.sqf";
```

`Client/Functions/Client_WatchdogPlayerAI.sqf:332`

The argument array `_action_args` (`_this select 3`) carries:
- `select 0` — array of stuck unit objects
- `select 1` — `true` (automatic mode flag)

`Client/Functions/Client_RecoverPlayerAI.sqf:82-88`

---

## PerformanceAudit Integration

At the end of each watchdog pass, three counters are emitted to the Performance Audit subsystem (enabled when the runtime variable `PerformanceAuditEnabled` is true; this is set from mission parameter `WFBE_C_PERFORMANCE_AUDIT_ENABLED` via `Common/Functions/Common_PerformanceAudit.sqf:9`):

```sqf
["player_ai_watchdog", diag_tickTime - _perfStart, Format["groupUnits:%1;watched:%2;recovered:%3", _perfGroupUnits, _perfWatched, _perfRecovered], "CLIENT"] Call PerformanceAudit_Record;
```

`Client/Functions/Client_WatchdogPlayerAI.sqf:337`

| Counter | Meaning |
|---|---|
| `groupUnits` | Total units in the player's group this tick |
| `watched` | Units that passed the eligibility filter |
| `recovered` | Units queued for automatic recovery this tick |

The watchdog evaluates two nested guards before emitting (`Client/Functions/Client_WatchdogPlayerAI.sqf:335-338`):

```sqf
if !(isNil "PerformanceAudit_Record") then {
    if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
        ["player_ai_watchdog", ...] Call PerformanceAudit_Record;
    };
};
```

The outer `isNil "PerformanceAudit_Record"` guard ensures the block is silently skipped if the audit system did not initialise. The inner `PerformanceAuditEnabled` check is the runtime variable (default `true` if the audit module never ran at all; at runtime `Common_PerformanceAudit.sqf:9` sets `PerformanceAuditEnabled` to `false` unless `WFBE_C_PERFORMANCE_AUDIT_ENABLED` > 0) that is populated from the mission parameter. Auditing is off by default. A reader tracing the watchdog source to find the controlling variable should look for `PerformanceAuditEnabled` at the guard site, then follow it to `Common_PerformanceAudit.sqf:9` for the mission-parameter binding.

---

## Manual Recovery — Mouse-Wheel Action

`Client_AddPlayerAIActions.sqf` is called as `player Call WFBE_CL_FNC_AddPlayerAIActions` during `Init_Client.sqf:529`. It registers:

| Action | Label colour | Priority | File invoked | Gate |
|---|---|---|---|---|
| Recover my AI movement | `#11ec52` (green) | 1.1 | `Client\Functions\Client_RecoverPlayerAI.sqf` | Player alive and group leader |
| Diagnose my AI | `#ffbd4c` (amber) | 1.2 | `Client\Functions\Client_DiagnosePlayerAI.sqf` | Same — **only added when `WF_Debug` is true** |

`Client/Functions/Client_AddPlayerAIActions.sqf:58, 66-77, 80-89`

Action IDs are stored on the player object (`Player_AI_Recover_Action`, `Player_AI_Diagnose_Action`) so `Client_AddPlayerAIActions.sqf` can remove old entries cleanly on respawn before re-adding them. `Client/Functions/Client_AddPlayerAIActions.sqf:39-48`

---

## Recovery Script: Mode Differences

`Client_RecoverPlayerAI.sqf` handles both the automatic watchdog call and the player action. The two paths share the same 3-phase algorithm but differ in several respects:

| Aspect | Manual (player action) | Automatic (watchdog) |
|---|---|---|
| `_is_automatic_recovery` | `false` | `true` |
| Cooldown check | 10 s global (`Player_AI_Recover_Last_Use`), with chat feedback | None — watchdog enforces its own 120 s per-unit cooldown |
| Source unit list | All living AI in `units (group _player)` | Only the pre-screened `_automatic_units` list from the watchdog |
| `_min_destination_distance` | 2 m — allows recovering short movement orders | 50 m — avoids refreshing near-completed orders |
| Phase 3 availability | Yes — vehicles only | No — skipped (`_is_automatic_recovery` gate `:820`) |
| Chat feedback | `GroupChatMessage` "AI movement recovery checked N units." `:515` | Suppressed |
| Success notification | `systemChat` with `STR_WF_INFO_AI_Recovered` localisation key | Same |

`Client/Functions/Client_RecoverPlayerAI.sqf:107-113, 155-170, 183-185, 514-516`

---

## 3-Phase Recovery Algorithm

### Phase 1 — FSM Reset and doMove

`Client/Functions/Client_RecoverPlayerAI.sqf:329-512`

Executed immediately on all eligible units as a group.

1. **Save snapshot**: `expectedDestination`, `getPosATL`, movement-controller flag, `has_useful_destination` flag saved for each unit `:228-326`.
2. **Eligibility**: unit must be alive, be the movement controller, have a useful destination, and pass `_movement_can_work` `:346-385`.
3. **Prepare**: `enableAI "MOVE"`, `enableAI "ANIM"`, `enableAI "TARGET"`, `enableAI "AUTOTARGET"`, `setUnitPos "AUTO"`, `doWatch objNull`, then `disableAI "FSM"` `:403-411`.
4. **0.25 s sleep** `:415`.
5. **FSM restart**: `enableAI "FSM"` `:436`.
6. **doMove** to the saved `expectedDestination` `:501`.

### Phase 2 — Shifted Destination

`Client/Functions/Client_RecoverPlayerAI.sqf:519-856`

Runs in a `Spawn {}` block. After 5 s sleep it checks each Phase 1 unit.

- If the unit moved ≥ 2 m from its Phase 1 start position it is considered recovered `:629`.
- If it did not move and is still eligible: a random offset of ±4 m is added to both X and Y of the original destination to produce `_new_destination` `:670-683`.

```sqf
_x_offset = (random 8) - 4;
_y_offset = (random 8) - 4;
_new_destination = [
    (_destination select 0) + _x_offset,
    (_destination select 1) + _y_offset,
    _z
];
```

`Client/Functions/Client_RecoverPlayerAI.sqf:670-683`

Phase 2 sequence (applied as one batch to all stuck-after-Phase-1 units):

1. `doStop` all Phase 2 units `:720-723`
2. 0.1 s sleep `:725`
3. `enableAI "MOVE"`, `enableAI "ANIM"`, `setUnitPos "AUTO"`, `doWatch objNull`, `disableAI "FSM"` `:738-745`
4. 0.15 s sleep `:748`
5. `enableAI "FSM"`, `doMove _new_destination` `:763-765`
6. 4 s sleep `:769`
7. Check: ≥ 2 m movement → recovered `:800-804`

### Phase 3 — Vehicle doFollow Reset (Manual Only)

`Client/Functions/Client_RecoverPlayerAI.sqf:860-999`

Phase 3 is entered only when:

- `_is_automatic_recovery` is `false` `:820`
- The unit did not move after Phase 2
- The unit is a vehicle driver (not infantry) — gate `:826` exits early when `_vehicle == _current_unit` (i.e., infantry)
- Unit and vehicle are both local `:828-829`
- Player is not currently in the affected vehicle `:827`

`Client/Functions/Client_RecoverPlayerAI.sqf:819-832`

Sequence:

1. `enableAI "MOVE"`, `enableAI "ANIM"`, `enableAI "FSM"`, `setUnitPos "AUTO"`, `doWatch objNull`, `doFollow _player` `:879-885`
2. 5 s sleep `:895`
3. `doStop` `:906-910`
4. 0.2 s sleep `:912`
5. `enableAI "MOVE"`, `enableAI "ANIM"`, `enableAI "FSM"`, `setUnitPos "AUTO"`, `doWatch objNull`, `doMove _destination` (original, not shifted) `:929-935`
6. 5 s sleep `:946`
7. Check: ≥ 2 m movement → recovered `:975`; otherwise logs WARNING `:992-996`

---

## Phase Timing Summary

| Phase | Delay before action | Failure check after |
|---|---|---|
| Phase 1 (FSM reset + doMove) | 0 s (immediate) | 5 s (Phase 2 check) |
| Phase 2 (doStop + shifted doMove) | 5 s after Phase 1 | 4 s (Phase 3 eligible check) |
| Phase 3 (doFollow + doStop + doMove) | 4 s after Phase 2 | 5 s (final log only) |

Total worst-case wall time from watchdog detection to end of Phase 3: 15 s watchdog interval + up to 120 s cooldown + ~14 s recovery execution ≈ up to ~149 s before a manual follow-up is needed.

---

## Per-Unit State Variables

All variables use `setVariable` with the `public` flag set to `false` — client-local only.

| Variable | Scope | Set by | Read by |
|---|---|---|---|
| `Player_AI_Watchdog_Running` | `missionNamespace` | Watchdog (singleton guard) | Watchdog `:58-59` |
| `Player_AI_Watchdog_Last_Position` | per unit | Watchdog each tick | Watchdog `:255` |
| `Player_AI_Watchdog_Last_Time` | per unit | Watchdog each tick | Watchdog `:256` |
| `Player_AI_Watchdog_Last_Destination` | per unit | Watchdog each tick | Watchdog `:257` |
| `Player_AI_Watchdog_Last_Recovery` | per unit | Watchdog on recovery | Watchdog cooldown gate `:258, 302` |
| `Player_AI_Recover_Last_Use` | `missionNamespace` | Recovery (manual path) | Manual cooldown gate `:159-161` |
| `Player_AI_Recover_Action` | per unit | `Client_AddPlayerAIActions.sqf` | Same file (respawn dedup) `:45, 97` |
| `Player_AI_Diagnose_Action` | per unit | Same (debug only) | Same file `:39, 77` |

---

## Design Constraints and Pitfalls

- **STOP order is sacred.** If `currentCommand _unit == "STOP"` the watchdog unconditionally skips the unit `:207`. Recovery cannot override a deliberate player stop order.
- **Passengers are never recovered.** Only the movement controller (infantry self, or vehicle driver) receives doMove. A unit that is neither `_vehicle == _current_unit` nor `driver _vehicle == _current_unit` is excluded `:190-198, 337-340`.
- **Locality is required.** Both the unit and its vehicle must be local on the calling client for recovery to take full effect `:199-200`. Non-local warnings are logged but recovery still proceeds (partial effect).
- **Destination mode is ignored.** `expectedDestination` can return `"DoNotPlan"` as its mode but the scripts evaluate usefulness purely by distance, not by mode `:224` / `:244-246`. This is intentional — the engine may retain a valid position even when it reports DoNotPlan.
- **Phase 3 is manual-only and vehicle-only.** Automatic recovery deliberately stops at Phase 2 to avoid the implicit formation disruption caused by `doFollow` `:820`.
- **Close-destination branch is disabled in auto mode.** `_min_close_destination_distance` and `_min_destination_distance` are both 50 m, making `_is_close_destination` permanently false in automatic mode. The `_required_close_stuck_time` (75 s) threshold and the engine guard at `:250-253` are therefore unreachable in the current configuration. The constants are preserved as an extension point should the two values ever be differentiated.
- **Spurious "ready" radio calls.** Refreshing a near-complete order causes the engine to emit an AI "ready" radio. The 50 m minimum destination guard in automatic mode (`_min_destination_distance = 50`) prevents this for micro-orders.
- **Radio spam from false recoveries.** Because Phase 1 issues `doMove` on every eligible unit simultaneously, a large group with many stuck units will produce a burst of radio calls. The 120 s cooldown and the 5 m movement threshold bound the worst case to one burst per 120 s.

---

## Continue Reading

- [AI-Headless-And-Performance](AI-Headless-And-Performance) — overview of HC task delegation, FPS management, and where the watchdog fits in the broader AI architecture
- [AI-Runtime-HC-Loop-Map](AI-Runtime-HC-Loop-Map) — HC loop timing and FSM scheduling context relevant to understanding why FSM reset/re-enable is necessary
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — mission-namespace and per-object variable naming patterns used throughout the system
- [Client-UI-Systems-Atlas](Client-UI-Systems-Atlas) — how the "Recover my AI movement" mouse-wheel action fits into the broader client action registration system
- [Architecture-Overview](Architecture-Overview) — overall client/server/HC boundary context
