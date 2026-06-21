# Client View-Distance and Target-FPS Auto-Throttle (Adaptive View Distance)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

A three-function client feature that gives every player both **manual** view-distance control and an **automatic** mode that chases a target framerate by raising/lowering view distance. The player drives it with the custom action keys **User18/User19/User20**, and the on/off state plus target FPS persist to the profile so the choice survives map changes and reconnects. A separate WASP dialog (`FPSPicker`) wraps the same mission variables in a menu.

The three functions are:

| Function | Source | Role |
|---|---|---|
| `Common_AdjustViewDistance` | `Common/Functions/Common_AdjustViewDistance.sqf` | KeyDown handler. Toggles auto mode (User18); steps target FPS (auto) or raw view distance (manual) on User19/User20. |
| `Common_AdjustViewDistanceTimerScript` | `Common/Functions/Common_AdjustViewDistanceTimerScript.sqf` | 0.75 s debounce: only the *last* manual key-press in a burst actually commits the view distance. |
| `Common_AutomaticViewDistance` | `Common/Functions/Common_AutomaticViewDistance.sqf` | FPS-band control loop: each client tick nudges view distance to hold FPS inside `target ±4`. |

Authors per file headers: `Common_AdjustViewDistance.sqf` — Miksuu, contributor Marty (`Common_AdjustViewDistance.sqf:4-5`); `Common_AutomaticViewDistance.sqf` — Marty, contributor Miksuu (`Common_AutomaticViewDistance.sqf:2-3`).

## Mission variables and constants

All state lives on `missionNamespace` (runtime) with two values mirrored to `profileNamespace` (persistent). Note the original triple-`O` spelling `TOOGLE` is the real variable name — do not "correct" it.

| Variable | Namespace | Default / source | Meaning |
|---|---|---|---|
| `TOOGLE_AUTO_DISTANCE_VIEW` | mission | `false` at client start (`Client/Init/Init_Client.sqf:207`) | Master on/off for auto mode. |
| `AUTO_DISTANCE_VIEW_TARGET_FPS` | mission | `60` (`Client/Init/Init_Client.sqf:29`) | The FPS the auto loop chases. |
| `SAVED_VIEW_DISTANCE` | mission | set to current `viewDistance` when auto turns ON (`Common_AdjustViewDistance.sqf:28`) | Restored when auto turns OFF so the screen does not jump. |
| `newViewDistance` | mission (global) | `0` (`Client/Init/Init_Client.sqf:266`) | Pending manual value awaiting the debounce; `0` means "nothing pending". |
| `timerInstanceCount` | mission (global) | `0` (`Client/Init/Init_Client.sqf:265`) | Monotonic counter that lets a newer debounce instance cancel older ones. |
| `WFBE_TOOGLE_AUTO_DISTANCE_VIEW` | profile | restored at `Client/Init/Init_Client.sqf:209-211` | Persisted on/off choice (BOOL). |
| `WFBE_TARGET_FPS` | profile | restored at `Client/Init/Init_ProfileVariables.sqf:19-24` | Persisted target FPS (SCALAR). |
| `WFBE_C_ENVIRONMENT_MAX_VIEW` | mission const | `5000` (`Common/Init/Init_CommonConstants.sqf:376`) | Hard cap on *manual* view distance increases. |

Two fixed step sizes are declared locally in the key handler: `_adjustViewDistanceBy = 1000` and `_adjustTargetFpsBy = 1` (`Common_AdjustViewDistance.sqf:10-11`).

## Key bindings (User18/19/20)

The handler is compiled and attached to the main display once at client init:

| Step | Source |
|---|---|
| Compile to `keyPressedForAdjustingViewDistance` | `Client/Init/Init_Client.sqf:272` |
| Attach as `KeyDown` on `findDisplay 46` | `Client/Init/Init_Client.sqf:273,276` |

On every KeyDown the function reads `_key = _this select 1` (`Common_AdjustViewDistance.sqf:8`) and tests it against the *engine-mapped* action keys, so the actual physical keys are whatever the player has bound to User18/19/20 in the control options:

| Action key | Test | Behavior summary |
|---|---|---|
| **User18** | `_key in (actionKeys "User18")` (`Common_AdjustViewDistance.sqf:17`) | Toggle auto mode on/off. |
| **User19** | `_key in (actionKeys "User19")` (`Common_AdjustViewDistance.sqf:36`) | **Decrease**: target FPS −1 (auto) or view distance −1000 (manual). |
| **User20** | `_key in (actionKeys "User20")` (`Common_AdjustViewDistance.sqf:55`) | **Increase**: target FPS +1 (auto) or view distance +1000 (manual). |

The function always returns `false` (`Common_AdjustViewDistance.sqf:73`) so the KeyDown is not swallowed from other handlers.

## Toggle behavior (User18)

`Common_AdjustViewDistance.sqf:19-32`:

- **Turning OFF** (was ON): set `TOOGLE_AUTO_DISTANCE_VIEW=false`, group-chat "Automatic view distance is now OFF", play `autoViewDistanceToggledOff`, then **restore** `SAVED_VIEW_DISTANCE` via `setViewDistance` (`Common_AdjustViewDistance.sqf:21-25`).
- **Turning ON** (was OFF): snapshot current `viewDistance` into `SAVED_VIEW_DISTANCE`, set `TOOGLE_AUTO_DISTANCE_VIEW=true`, group-chat "Automatic view distance is now ON", play `autoViewDistanceToggledOn` (`Common_AdjustViewDistance.sqf:28-31`).

Note the toggle itself does **not** persist `WFBE_TOOGLE_AUTO_DISTANCE_VIEW` — only the FPSPicker dialog does (see below). So a key-driven toggle is per-session, while restore-at-start uses the last value the picker saved.

## Manual vs auto stepping (User19/User20)

The decrease (User19) and increase (User20) branches are mirror images; each first checks `TOOGLE_AUTO_DISTANCE_VIEW`.

**Auto mode — step the target FPS:**

| Direction | Operation | Source |
|---|---|---|
| Decrease | `target = (target - 1) max 30` | `Common_AdjustViewDistance.sqf:38` |
| Increase | `target = (target + 1) min 240` | `Common_AdjustViewDistance.sqf:57` |

After stepping, both branches persist the new value if the profile setter exists: `if !(isNil 'WFBE_CO_FNC_SetProfileVariable') then {['WFBE_TARGET_FPS', _target] Call WFBE_CO_FNC_SetProfileVariable}` (`Common_AdjustViewDistance.sqf:39,59`), write it back to `AUTO_DISTANCE_VIEW_TARGET_FPS` (`Common_AdjustViewDistance.sqf:40,58`), and group-chat the resulting band, e.g. `"Target FPS has been set to be min. <target-4> max <target+4>"` (`Common_AdjustViewDistance.sqf:41,60`) — the same ±4 band the auto loop uses.

**Manual mode — step the raw view distance:**

Both branches first resolve the working value: if `newViewDistance == 0` (nothing pending) start from current `viewDistance`, else continue from the pending `newViewDistance` (`Common_AdjustViewDistance.sqf:43-47, 62-66`). Then:

| Direction | Operation | Source |
|---|---|---|
| Decrease | `newViewDistance = _base - 1000 max 1` | `Common_AdjustViewDistance.sqf:48` |
| Increase | `newViewDistance = _base + 1000 min WFBE_C_ENVIRONMENT_MAX_VIEW` | `Common_AdjustViewDistance.sqf:67` |

It then group-chats `"Setting view distance to: <newViewDistance>"` and fires the debounce timer: `execVm "Common\Functions\Common_AdjustViewDistanceTimerScript.sqf"` (`Common_AdjustViewDistance.sqf:49-50, 68-69`).

> A2 operator-precedence note: SQF binary operators are left-to-right with equal precedence, so `_base - 1000 max 1` parses as `(_base - 1000) max 1` and `_base + 1000 min WFBE_C_ENVIRONMENT_MAX_VIEW` as `(_base + 1000) min WFBE_C_ENVIRONMENT_MAX_VIEW` — i.e. the floor/cap is applied to the already-stepped value, which is the intended clamp (`Common_AdjustViewDistance.sqf:48,67`).

## Debounce timer (`Common_AdjustViewDistanceTimerScript`)

Because each User19/User20 press writes a new `newViewDistance` and spawns a fresh timer script, spamming the key would otherwise call `setViewDistance` many times. The debounce makes only the final press commit (`Common_AdjustViewDistanceTimerScript.sqf`):

| Step | Line | Detail |
|---|---|---|
| Claim an instance id | `:3-4` | `timerInstanceCount = timerInstanceCount + 1; _timerInstance = timerInstanceCount` |
| Window length | `:8` | `_timerDuration = 0.75` seconds |
| Wait loop | `:17-31` | `while {_elapsedTime < _timerDuration}`; sleeps `0.01` s per pass for accuracy (`:30`) |
| Cancel if superseded | `:19` | `if (timerInstanceCount != _timerInstance) exitWith {_changeTheViewDistance = false}` — a newer press bumped the global counter |
| Commit | `:33-38` | If still the latest instance: `setViewDistance newViewDistance`, group-chat the applied value, then reset `newViewDistance = 0` |

So if you tap increase four times quickly, four timer scripts start, the first three each see a higher `timerInstanceCount` and self-cancel, and only the fourth survives 0.75 s of quiet to call `setViewDistance` once with the accumulated value. Resetting `newViewDistance = 0` (`:38`) returns the system to "nothing pending" so the next press starts from live `viewDistance`.

## Automatic FPS-band loop (`Common_AutomaticViewDistance`)

This is the closed-loop controller. It is compiled once and driven from the per-tick client FSM:

| Step | Source |
|---|---|
| Compile to `AutomaticViewDistance` | `Client/FSM/updateclient.sqf:33` |
| Per-tick gate + call | `Client/FSM/updateclient.sqf:111-115` — reads `TOOGLE_AUTO_DISTANCE_VIEW`; `if (_toggle_auto_distance_view && !visibleMap) then { call AutomaticViewDistance }` |

Note the `!visibleMap` guard: the loop does **not** run while the player has the map open (`Client/FSM/updateclient.sqf:112`), avoiding view-distance thrash on a screen where FPS is unrepresentative.

Each invocation reads the target and the live state, then makes a single bounded adjustment (`Common_AutomaticViewDistance.sqf:6-39`):

| Quantity | Value | Source |
|---|---|---|
| Target | `AUTO_DISTANCE_VIEW_TARGET_FPS` | `:6` |
| Lower band edge | `target - 4` (`_min_fps_targeted`) | `:8` |
| Upper band edge | `target + 4` (`_max_fps_targeted`) | `:9` |
| View-distance ceiling | `6000` (`_max_distance_view`) | `:10` |
| View-distance floor | `500` (`_min_distance_view`) | `:11` |
| Measured FPS | `diag_fps` | `:13` |
| Current view distance | `viewDistance` | `:14` |

Decision logic:

| Condition | Adjustment | Source |
|---|---|---|
| `fps < target-4` (too slow) | view distance **−200 m**, then `max 500`, `setViewDistance` | `Common_AutomaticViewDistance.sqf:16-22` |
| `fps ≥ target-4` and `viewDistance < 6000` and `fps > target+4` (headroom to spare) | view distance **+300 m** | `Common_AutomaticViewDistance.sqf:25-30` |
| `fps ≥ target-4` and `viewDistance < 6000` and `target-4 ≤ fps ≤ target+4` (in band) | view distance **+50 m** | `Common_AutomaticViewDistance.sqf:31-34` |
| `fps ≥ target-4` and `viewDistance ≥ 6000` | no change (cap reached) | `Common_AutomaticViewDistance.sqf:25` (the `if (_player_view_distance < _max_distance_view)` guard fails) |

After an increase the result is clamped `min 6000` before `setViewDistance` (`Common_AutomaticViewDistance.sqf:35-36`). The asymmetry is deliberate: it **drops fast** (−200) to recover FPS quickly, but **climbs cautiously** (+50 in-band) — only sprinting (+300) when FPS is comfortably above the target. There is no internal sleep; cadence is entirely set by how often `updateclient.sqf` ticks. The two `systemChat` debug lines are commented out (`Common_AutomaticViewDistance.sqf:21,37`).

## Profile persistence and restore

Two values persist to `profileNamespace`; both are restored at client init.

| Persisted var | Written by | Restored by |
|---|---|---|
| `WFBE_TARGET_FPS` | key handler (`Common_AdjustViewDistance.sqf:39,59`) and FPSPicker (`WASP/actions/FPSPicker/FPSPicker_Open.sqf:52`) | `Client/Init/Init_ProfileVariables.sqf:19-24` → seeds `AUTO_DISTANCE_VIEW_TARGET_FPS` |
| `WFBE_TOOGLE_AUTO_DISTANCE_VIEW` | FPSPicker only (`WASP/actions/FPSPicker/FPSPicker_Open.sqf:42`) | `Client/Init/Init_Client.sqf:209-211` → seeds `TOOGLE_AUTO_DISTANCE_VIEW` (and snapshots `SAVED_VIEW_DISTANCE` if restored ON) |

The restore reads are type-guarded against profile hijacking: the FPS restore requires `typeName _profile_var == "SCALAR"` (`Client/Init/Init_ProfileVariables.sqf:21`) and the toggle restore requires the stored value `typeName ... == "BOOL"` (`Client/Init/Init_Client.sqf:209`). The setter itself is trivial — `Common_SetProfileVariable.sqf:10-13` is just `profileNamespace setVariable [_var,_value]` with name/value taken from `_this select 0/1`; the sanitization lives at the read side. `WFBE_CO_FNC_SetProfileVariable` is the bound name for this function.

`Client/Init/Init_ProfileVariables.sqf` also restores a separate raw `WFBE_PERSISTENT_CONST_VIEW_DISTANCE` (`:9-16`) via `setViewDistance`, type-guarded as SCALAR and capped at `WFBE_C_ENVIRONMENT_MAX_VIEW` — this is the player's last manual view distance and is independent of the auto-throttle target.

## FPSPicker dialog (alternate front-end)

`WASP/actions/FPSPicker/FPSPicker_Open.sqf` opens dialog `WFBE_FPSPickerMenu` (idd 28000) from the WF menu and drives the same mission variables, so the menu and the User18/19/20 keys are two views of one system. Behaviors:

| Picker action | Effect | Source |
|---|---|---|
| Toggle (MenuAction 1) | flips `TOOGLE_AUTO_DISTANCE_VIEW`; on ON snapshots `SAVED_VIEW_DISTANCE`, on OFF restores it; persists `WFBE_TOOGLE_AUTO_DISTANCE_VIEW` | `WASP/actions/FPSPicker/FPSPicker_Open.sqf:30-44` |
| Pick FPS (MenuAction 2/3/4) | sets target to **45 / 50 / 60**; persists `WFBE_TARGET_FPS` | `WASP/actions/FPSPicker/FPSPicker_Open.sqf:47-54` |
| Live label | shows current ON/OFF and `"Target <fps> FPS | VD now: <m> m"` | `WASP/actions/FPSPicker/FPSPicker_Open.sqf:24-27` |

The picker offers only the discrete presets 45/50/60, whereas the keys step by ±1 across the full `30..240` range — both write the same `AUTO_DISTANCE_VIEW_TARGET_FPS` / `WFBE_TARGET_FPS`. Default stays OFF by design (header note, Steff 2026, `WASP/actions/FPSPicker/FPSPicker_Open.sqf:9`).

## Player feedback path

All on-screen text routes through `GroupChatMessage` (`Common_AdjustViewDistance.sqf:22,30,41,49,60,68` and `Common_AdjustViewDistanceTimerScript.sqf:36`), which is compiled from `Client\Functions\Client_GroupChatMessage.sqf` at `Client/Init/Init_Client.sqf:80`. The two toggle sounds `autoViewDistanceToggledOn`/`autoViewDistanceToggledOff` are played via `playSound` (`Common_AdjustViewDistance.sqf:23,31`).

## Consumers of the target FPS

Beyond the auto loop, the target FPS is surfaced by the performance-audit snapshot: `Common/Functions/Common_PerformanceAudit.sqf:64` reads `profileNamespace getVariable ["WFBE_TARGET_FPS", -1]` so each audited client records the framerate target it was chasing.

## Continue Reading

- [Namespace, Profile and Diagnostic Utility Reference](Namespace-Profile-And-Diagnostic-Utility-Reference) — catalogs `WFBE_TARGET_FPS` and the other profile variables this system persists.
- [Performance Audit Analyzer](PerformanceAuditAnalyzer) — the RPT audit pipeline that logs each client's target FPS and view distance.
- [Day-Night Cycle and Weather System](Day-Night-Cycle-And-Weather-System) — the other environment system whose fog/overcast interact with effective view distance.
- [Client UI Systems Atlas](Client-UI-Systems-Atlas) — the client init/FSM context that compiles and drives these handlers.
- [Hosted Server FPS Loop Sleep](Hosted-Server-FPS-Loop-Sleep) — the server-side framerate-governed loop counterpart to this client-side throttle.
