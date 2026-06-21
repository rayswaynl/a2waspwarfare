# Client Input And Hotkey Handler

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The client input layer is a single block in `Client/Init/Init_Client.sqf` that grabs the main mission display (`findDisplay 46`) and stacks several independent `KeyDown`/`KeyUp` event handlers onto it, plus a separate per-player hotkey script (`Client/Init/Init_Keybind.sqf`) called later in the same boot. Each handler reads the engine-supplied keycode from `_this select 1` and either compares it against an engine *action-key* binding (`actionKeys "User##"` / `actionKeys "VehLockTargets"` / move keys) or against a raw DirectInput (DIK) scancode. Because Arma stacks display handlers rather than replacing them, every handler in the block fires on every key press; the order below is registration order.

This page documents the registration block and the handler scripts it installs. The **User18/User19/User20 view-distance** handler is registered in the very same block (`Init_Client.sqf:272,276`) but is fully documented on its own page — see [View Distance And Target FPS Auto Throttle](View-Distance-And-Target-FPS-Auto-Throttle). The **User11 skin-selector** hotkey from `Init_Keybind.sqf` is documented on [Skin Selector And Class Swap Reference](Skin-Selector-And-Class-Swap-Reference). Both are cross-linked here, not re-documented.

## findDisplay 46 registration block (Init_Client.sqf)

Three handler bodies are compiled into global names first, then attached to `_display = findDisplay 46` (`Init_Client.sqf:273`):

| Step | Line | What it does |
| --- | --- | --- |
| Compile `keyPressed` | `Init_Client.sqf:270` | `compile preprocessFile "Common\Functions\Common_DisableTablock.sqf"` |
| Compile `keyPressedForAutoSendSpawnedUnitsToWaypoint` | `Init_Client.sqf:271` | `compile preprocessFile "Common\Functions\Common_AutoSendSpawnedUnitsToWaypoint.sqf"` |
| Compile `keyPressedForAdjustingViewDistance` | `Init_Client.sqf:272` | view-distance handler — see [View Distance And Target FPS Auto Throttle](View-Distance-And-Target-FPS-Auto-Throttle) |
| Attach tab-lock `KeyDown` | `Init_Client.sqf:274` | `_this call keyPressed` |
| Attach auto-send `KeyDown` | `Init_Client.sqf:275` | `_this call keyPressedForAutoSendSpawnedUnitsToWaypoint` |
| Attach view-distance `KeyDown` | `Init_Client.sqf:276` | `_this call keyPressedForAdjustingViewDistance` |
| Attach debug-teleport `KeyDown` (inline) | `Init_Client.sqf:278` | DIK 26 arms teleport under `WF_Debug` |
| Attach map-disband Ctrl `KeyDown` (inline) | `Init_Client.sqf:280` | DIK 29/157 set Ctrl-down flag true |
| Attach map-disband Ctrl `KeyUp` (inline) | `Init_Client.sqf:281` | DIK 29/157 clear Ctrl-down flag |
| Attach tab-lock `KeyDown` (again) | `Init_Client.sqf:290,292` | `WFBE_CO_FNC_DisableTabLock` = same `Common_DisableTablock.sqf` re-compiled and re-attached |
| Attach AFK move-key `KeyDown` | `Init_Client.sqf:294,304` | `WFBE_CO_FNC_HandleAFKkeys` = `Client\Module\AFKkick\handleKeys.sqf` |

After the AFK handler, the block kicks off the AFK monitor loop with `[] execVM "Client\Module\AFKkick\monitorAFK.sqf"` (`Init_Client.sqf:306`). The map-click consumer `WFBE_CL_FNC_HandleMapSingleClick` is wired separately at `Init_Client.sqf:282` via `onMapSingleClick` (not a display handler), and it reads the two state flags the inline handlers maintain.

Note that `Common_DisableTablock.sqf` is compiled and attached **twice** — once as `keyPressed` (`:270`, `:274`) and again as `WFBE_CO_FNC_DisableTabLock` (`:290`, `:292`) — so the tab-lock suppression runs on two stacked handlers. Both bodies are identical (the second uses `preprocessFileLineNumbers`); neither short-circuits the other because each returns its own `_handled` value.

## Key -> action map

| Handler | Bound key / DIK | Action key name | Effect | Source |
| --- | --- | --- | --- | --- |
| Tab-lock disable | `VehLockTargets` (default Tab) | `actionKeys "VehLockTargets"` | Returns `true` (swallows the key, blocking lock-on) for ground vehicles except a whitelist; returns `false` (lock allowed) on foot, in Air, and for listed AA platforms | `Common_DisableTablock.sqf:14,18-38` |
| Auto-send spawned units toggle | `User13` | `actionKeys "User13"` | Toggles `AUTO_SEND_SPAWNED_UNITS_TO_WAYPOINT`, prints a group-chat line, plays a toggle sound; always returns `false` | `Common_AutoSendSpawnedUnitsToWaypoint.sqf:10-22` |
| View distance / target FPS | `User18` / `User19` / `User20` | `actionKeys "User18/19/20"` | Auto-mode toggle and FPS/view-distance stepping — see dedicated page | `Common_AdjustViewDistance.sqf` (see [View Distance And Target FPS Auto Throttle](View-Distance-And-Target-FPS-Auto-Throttle)) |
| Debug teleport arm | DIK `26` (the `[` key) | raw scancode | Only when `WF_Debug`: sets `WFBE_DEBUG_TELEPORT_ARMED = true`, hints "Debug teleport ARMED", returns `true`; otherwise `false` | `Init_Client.sqf:278` |
| Map-disband Ctrl track (down) | DIK `29` / `157` (Left/Right Ctrl) | raw scancode | Sets `WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN = true`; returns `false` | `Init_Client.sqf:280` |
| Map-disband Ctrl track (up) | DIK `29` / `157` (Left/Right Ctrl) | raw scancode (KeyUp) | Sets `WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN = false`; returns `false` | `Init_Client.sqf:281` |
| AFK move-key reset | Move/map keys | `actionKeys "MoveBack" + ... + "showMap"` | Sets `WFBE_CO_VAR_NotAFK_update = true` so the AFK monitor resets its timer; returns `false` | `handleKeys.sqf:11-16` |
| Skin selector open | `User11` | `actionKeys "User11"` | Opens the skin selector — bound on `player`, not display 46; see dedicated page | `Init_Keybind.sqf:6-12` (see [Skin Selector And Class Swap Reference](Skin-Selector-And-Class-Swap-Reference)) |

A handler that returns `true` reports the key as *handled* and suppresses the engine's default for that frame; the WASP handlers that return `false` (auto-send, map-disband tracking, AFK) are passive observers that never eat the key. The DIK codes are raw because the affected keys (`[`, Ctrl) are not exposed through `onMapSingleClick`, which only surfaces Shift and Alt.

## Handler details

### Tab-lock disable (Common_DisableTablock.sqf)

Reads `_key` (`:12`) and the player's lock-target binding `_tabbuttons = actionKeys "VehLockTargets"` (`:14`). It allows tab-lock (`_handled = false`) when the player is on foot (`_vehicle == player`, also covers using a bipod), in any `Air` vehicle, or in one of the listed AA platforms while that platform's AA weapon is selected: `M6_EP1`/`2S6M_Tunguska` with `9M311Laucher`, `HMMWV_Avenger`/`HMMWV_Avenger_DES_EP1` with `StingerLaucher`, and `ZSU_INS`/`ZSU_CDF`/`ZSU_TK_EP1` with `AZP85` (`:18-26`). For any other vehicle, pressing a lock key sets `_handled = true` (`:33-37`), which suppresses lock-on. Returns `_handled` (`:40`). The file's TODO notes man-portable Stinger/Igla and BRDM AA are not yet covered (`:5`).

### Auto-send spawned units toggle (Common_AutoSendSpawnedUnitsToWaypoint.sqf)

On `User13` (`:10`) it flips `AUTO_SEND_SPAWNED_UNITS_TO_WAYPOINT` (`:11-19`), announces the new state through `GroupChatMessage`, and plays `autoViewDistanceToggledOff`/`autoViewDistanceToggledOn` (`:14,18`) — it reuses the view-distance toggle sounds. The flag is initialized to `false` at `Init_Client.sqf:213` and is read by the spawned-unit waypoint logic at `Client/Functions/Client_SetAttackWaveDetails.sqf:13` and `Client/Functions/Client_SendSpawnedUnitsToLeaderWaypoint.sqf:13`. Always returns `false` (`:22`).

### Debug teleport arm and map-disband Ctrl tracking (inline)

These two are inline handler strings, not separate files. The debug-teleport handler (`Init_Client.sqf:278`) is gated on `WF_Debug`; pressing `[` (DIK 26) arms a one-shot `WFBE_DEBUG_TELEPORT_ARMED`. The next plain (non-Shift) map click consumes and disarms it in `Client/Functions/Client_HandleMapSingleClick.sqf:175,179`. The inline comment (`:277`) records the prior behavior — every map click teleported while `WF_Debug` was on, which ate the sell/ICBM confirm clicks — so arming was added to make it deliberate. The Ctrl-tracking pair (`:280-281`) maintains `WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN` because `onMapSingleClick` does not expose the Ctrl modifier; the flag is read by the disband path in `Client_HandleMapSingleClick.sqf:17`.

### AFK move-key reset (handleKeys.sqf)

`WFBE_CO_FNC_HandleAFKkeys` builds `_moveButtons` from the union of `actionKeys` for MoveBack, MoveDown, MoveForward, MoveFastForward, MoveLeft, MoveRight, HideMap and showMap (`:11`). If the pressed key is in that set it sets `WFBE_CO_VAR_NotAFK_update = true` (`:14`) and returns `false` (passive). The companion loop `monitorAFK.sqf` polls that flag once per cycle: on `true` it resets `_timer` to 0 and clears the flag (`:12-14`); otherwise it increments, warns once past `WFBE_CO_VAR_AFKkickThreshold / 1.5` (`:19-22`), and self-kicks via `publicVariableServer "AFKthresholdExceededName"` + `failMission "END1"` when `_timer` exceeds `WFBE_CO_VAR_AFKkickThreshold` (`:24-27`). The threshold is set to 30 at `Init_Client.sqf:297`.

## Init_Keybind.sqf (per-player hotkeys)

`Init_Keybind.sqf` is called by `[] Call Compile preprocessFile "Client\Init\Init_Keybind.sqf"` at `Init_Client.sqf:667`. It defines two function globals and attaches one of them to `player` (not display 46):

| Item | Source | Status |
| --- | --- | --- |
| `WF_SkinSelector_Hotkey` | `Init_Keybind.sqf:2-13` | Registered via `player addEventHandler ["KeyDown", WF_SkinSelector_Hotkey]` (`:14`). On `User11`, opens `WASP\actions\SkinSelector\SkinSelector_Open.sqf` only when `WFBE_C_SKIN_SELECTOR == 1`, the player is alive, on foot, and no dialog is open (`:6-11`). |
| `WF_Gear_Hotkeys` | `Init_Keybind.sqf:17-40` | **Defined but never registered.** No `addEventHandler` references `WF_Gear_Hotkeys` anywhere in the mission, so these bindings never fire. |

`WF_Gear_Hotkeys` was intended to set the gear-filler mode by writing `WF_Logic setVariable ['filler', ...]`: `User15` = `all`, `User16` = `template`, `User17` = `primary`, `User18` = `secondary`, `User19` = `sidearm`, `User20` = `misc` (`Init_Keybind.sqf:22-39`). Because the closing brace at `Init_Keybind.sqf:40` ends the file without an `addEventHandler` call, this is dead code in the current master. Note the overlap: `User18/User19/User20` are *live* on display 46 for view distance (`Init_Client.sqf:276`), so even if the gear function were registered, those three action keys would drive both systems at once.

## Continue Reading

- [View Distance And Target FPS Auto Throttle](View-Distance-And-Target-FPS-Auto-Throttle)
- [Skin Selector And Class Swap Reference](Skin-Selector-And-Class-Swap-Reference)
- [Mission Entrypoints And Lifecycle](Mission-Entrypoints-And-Lifecycle)
- [Player UI Workflow Map](Player-UI-Workflow-Map)
- [Player Join Disconnect And AntiStack Lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle)
