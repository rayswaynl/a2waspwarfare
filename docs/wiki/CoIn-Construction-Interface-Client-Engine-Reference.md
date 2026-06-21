# CoIn Construction Interface Client Engine Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the client-side engine layer of the customized BIS construction interface (CoIn) implemented in `Client/Module/CoIn/coin_interface.sqf` (965 lines). It covers the input-router dispatcher, the four display event handlers that feed it, the transparent-wall border geometry, NVG persistence, the three near-identical teardown blocks, and the per-tick funds/affordability render loop. It deliberately does *not* re-document construction behavior, request handlers, costs, sale/refund, or authority — those are owned by [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), which compresses this entire engine into a few table rows (its `:124` "camera controls. Lines 29-56", `:126` border, and `:332` CoIn-performance rows) and explicitly scopes itself to the runtime map, request-handler map and safe-extension checklist. This page owns the camera/handler/border/render engine those rows defer.

The script is `ExecVM`-ed from `Client/Action/Action_Build.sqf` with `[player, player, 2, MCoin, getpos player, <sideHQ>]`; `_this select 3` is the logic, `select 4` the start position, `select 5` the source object (`coin_interface.sqf:1-3`). It guards `alive _source` (`:5`) and a single-instance lock (`:33` `if !(isNil {player getVariable "bis_coin_logic"}) exitWith {}`).

## Display Handler Topology

The interface display is opened, captured, and wrapped with four display event handlers that all forward into the single dispatcher `BIS_CONTROL_CAM_Handler`.

| Step | Source | Detail |
| --- | --- | --- |
| Open construction title resource | `coin_interface.sqf:29` | `112200 cutrsc ["WFBE_ConstructionInterface","plain"]` (MrNiceGuy custom layer). |
| Capture display 46 | `coin_interface.sqf:30` | `uiNamespace setVariable ["COIN_displayMain",finddisplay 46]` — the captured handle is reused by every teardown for `displayRemoveEventHandler`. |
| Open BIS construction interface | `coin_interface.sqf:56` | `1122 cutrsc ["constructioninterface","plain"]`. |
| Create camera | `coin_interface.sqf:41-52` | `"camconstruct" camCreate` at player position +15 Z, `cameraEffect ["internal","back"]`, FOV 0.9, `-30` pitch via `BIS_fnc_setPitchBank`, `camConstuctionSetParams ([_startPos] + areasize)`; stored in `BIS_CONTROL_CAM` (`:52`). |

The four display handlers are wired at `coin_interface.sqf:59-62`. Each tests `!isNil 'BIS_CONTROL_CAM_Handler'` then spawns the dispatcher; the handler-ids are stored in `WF_COIN_DEH1..DEH4` so they can be removed by id later.

| Handler var | Event | Source | Spawn payload |
| --- | --- | --- | --- |
| `WF_COIN_DEH1` | `KeyDown` | `coin_interface.sqf:59` | `['keydown',_this,commandingMenu] spawn BIS_CONTROL_CAM_Handler` |
| `WF_COIN_DEH2` | `KeyUp` | `coin_interface.sqf:60` | `['keyup',_this] spawn BIS_CONTROL_CAM_Handler` |
| `WF_COIN_DEH3` | `MouseButtonDown` | `coin_interface.sqf:61` | `['mousedown',_this,commandingMenu] spawn ...`; also sets `BIS_CONTROL_CAM_RMB`/`_LMB` from `_this select 1` (button 1 = RMB, 0 = LMB). |
| `WF_COIN_DEH4` | `MouseButtonUp` | `coin_interface.sqf:62` | clears `BIS_CONTROL_CAM_RMB`/`_LMB` to false (no dispatch). |

Note these are *separate* from the display-46 handler stack documented in [Client input and hotkey handler](Client-Input-Hotkey-Handler) (AFK/tablock/move keys wired in `Init_Client.sqf`); CoIn adds its own four onto the same display and removes them on close.

## BIS_CONTROL_CAM_Handler Input Dispatcher

`BIS_CONTROL_CAM_Handler` (`coin_interface.sqf:163-341`) is the single router for all keyboard/mouse input while the interface is open. It is defined once and short-circuited on re-entry (`:161` `if !(isNil "BIS_CONTROL_CAM_Handler") exitWith {endLoadingScreen}`). It reads `_mode`/`_input` from `_this`, resolves `_logic = bis_coin_player getVariable "bis_coin_logic"`, and exits early if the logic is nil (`:170`).

| Branch | Source | Behavior |
| --- | --- | --- |
| Banned key | `coin_interface.sqf:178,193` | `_keysBanned = [1]` (Esc/DIK 1) is never recorded into the pressed-key set `BIS_CONTROL_CAM_keys`. |
| Pressed-key tracking | `coin_interface.sqf:193,275` | keydown adds `_key` to `BIS_CONTROL_CAM_keys` (unless banned/already present); keyup removes it. This set drives ctrl/shift/alt detection in the render loop (`:438-440`). |
| Mouse terminate | `coin_interface.sqf:183-186` | on `mousedown`, `_key == 1 && 65665 in (actionkeys "MenuBack")` sets `_terminate`. |
| Key terminate | `coin_interface.sqf:196` | `_key in actionKeys "MenuBack" && isNil "BIS_Coin_noExit"` sets `_terminate`. |
| NVG toggle | `coin_interface.sqf:199-204` | `actionKeys "NightVision"` flips `BIS_COIN_nvg`, persists it to `WF_NVGPersistent`, and calls `camUseNVG`. |
| Auto-wall (User14) | `coin_interface.sqf:206-218` | toggles `isAutoWallConstructingEnabled`, group-chats the state, and sends `RequestAutoWallConstructinChange` to the server via `WFBE_CO_FNC_SendToServer`. |
| Last-built (User15) | `coin_interface.sqf:221-229` | if `lastBuilt` is populated and player can afford `(lastBuilt select 2) select 1` (and HQ deployed for HQ root), re-arms the last structure as `BIS_COIN_params`. |
| Auto-manning (User16) | `coin_interface.sqf:232-237` | toggles `manningDefense` (gated on `WFBE_C_BASE_DEFENSE_MAX_AI > 0`) and sets `WF_RequestUpdate`. |
| Sell defense (User17, commander) | `coin_interface.sqf:240-270` | commander-only; `nearestObjects` a defense at screen-center, checks side and prior `sold`, refunds `round(price/2.5)` via `ChangePlayerFunds`, increments base-area `avail`, and `deleteVehicle`s it. (Behavior detail owned by the atlas `coin_interface.sqf:238-265` row.) |

When `_terminate` fires (`:279-300`), the dispatcher either tears the camera down (top-level menu `#USER:BIS_Coin_categories_0` → `cameraEffect ["terminate","back"]` + `camDestroy`, `:285-287`) or, in a sub-menu, just clears the preview/params/helper and steps back one level (`:288-298`).

## Teardown Blocks (Three Near-Identical)

The interface has three almost-identical cleanup blocks. All null `BIS_CONTROL_CAM`/`BIS_CONTROL_CAM_Handler`, `cuttext` the `1122` resource, clear the player's `bis_coin_logic`, set `bis_coin_player = objNull`, delete preview/helper, null ~9 `BIS_COIN_*` logic vars, `displayRemoveEventHandler` all four DEHs by id, and delete the `BIS_COIN_border` ring. The differences are the *trigger* and which extra state they reset.

| Block | Source | Trigger | Notable difference |
| --- | --- | --- | --- |
| Normal close | `coin_interface.sqf:303-340` | `isNil "BIS_CONTROL_CAM" \|\| player != bis_coin_player \|\| !isNil "BIS_COIN_QUIT"` inside the dispatcher | Does **not** null the `WF_COIN_DEH1..4` id vars (removes by id but leaves the vars set); resets `BIS_COIN_QUIT` to nil. |
| Death exit | `coin_interface.sqf:374-417` | `!alive player \|\| !alive _source` in the render loop | Shows a loading screen (`startLoadingScreen` `:375`, `endLoadingScreen` `:417`); also nulls `WF_COIN_DEH1..4` (`:409-412`). |
| HQ-undeploy exit | `coin_interface.sqf:510-543` | placing the index-0 structure (HQ) while HQ is deployed (`:488`) — undeploys the MHQ | Fires inside the preview path; also nulls `WF_COIN_DEH1..4` and spawns the re-lock action restore (`:545-556`). |

The DEH-removal lines (`:330-333`, `:402-405`, `:530-533`) are exactly the four `displayRemoveEventHandler` calls against the captured `COIN_displayMain` handle. The branch-local difference where `feat/commander-positions` commit `b28b351f` swaps `WF_COIN_DEH2/DEH3` for `WF_COIN_DEH3/DEH4` in the HQ-undeploy cleanup is tracked as a diff note in [Commander positions branch audit](Commander-Positions-Branch-Audit) (`:82`), not as a master-source fact — on master all three blocks remove DEH1/DEH2/DEH3/DEH4.

## _createBorder Transparent-Wall Geometry

`_createBorder` (`coin_interface.sqf:114-157`) builds a ring of local `transparentwall` objects marking the build area. It is `spawn`-ed once at `:158` and re-spawned whenever the area-size changes (`:424-426`).

| Element | Source | Detail |
| --- | --- | --- |
| Old-border purge | `coin_interface.sqf:119-123` | reads `BIS_COIN_border`, `deleteVehicle` each, nulls the var before rebuild. |
| Width selection | `coin_interface.sqf:128-136` | a stack of overwritten `_width` assignments; the live value is `_width = 10` (`:136`) — the earlier ratio comments (`200/126` … `10/8`) and the `10 - (0.1/(_size*0.2))` line are dead overwrites. |
| Perimeter / wall count | `coin_interface.sqf:138-143` | `_perimeter = _size * pi`, rounded up to a `_width` multiple; `_wallcount = _perimeter / _width * 2`; `_total = _wallcount`. |
| Wall ring | `coin_interface.sqf:145-155` | for each of `_total`, computes `_dir = (360/_total)*_i`, places a `"transparentwall" createVehicleLocal` at `sin/cos _dir * _size` offset, `setposasl` with Z 0, `setdir (_dir + 90)`. |
| Store | `coin_interface.sqf:156` | writes the ring array to `BIS_COIN_border` (`missionNamespace`). |

The size comes from `(_logic getVariable "BIS_COIN_areasize") select 0` (`:127`). The re-spawn at `:424-426` fires when `_limitH`/`_limitV` differ from the previous tick, and also re-applies `camConstuctionSetParams`. The script waits for the initial border spawn to finish (`:343` `waitUntil {scriptDone _createBorderScope}`) before ending the loading screen.

## NVG Persistence

NVG state survives across interface opens via `WF_NVGPersistent` on the logic.

| Element | Source | Detail |
| --- | --- | --- |
| Default | `coin_interface.sqf:79-86` | if `WF_NVGPersistent` is unset, default to `daytime > 18.5 \|\| daytime < 5.5` (night) and store it; otherwise reuse the stored value. |
| Apply | `coin_interface.sqf:87-88` | `camUseNVG _nvgstate`; mirror into `BIS_COIN_nvg`. |
| Runtime toggle | `coin_interface.sqf:199-204` | the NightVision key in the dispatcher flips `BIS_COIN_nvg`, writes `WF_NVGPersistent` back, and re-applies `camUseNVG`. |

Because the toggle writes `WF_NVGPersistent` every time, the next CoIn open inherits the last-chosen NVG state rather than re-deriving from daytime.

## Per-Tick Funds + Affordability Render Loop

The main loop (`coin_interface.sqf:356-963`, `sleep 0.01` per tick `:962`) rebuilds the commanding-menu categories and items only when funds change or a restart is requested. The funds-render and affordability section is `:836-960`.

| Element | Source | Detail |
| --- | --- | --- |
| Dual-currency funds | `coin_interface.sqf:837-844` | if `BIS_COIN_funds` is an ARRAY, build `[GetSideSupply, GetPlayerFunds]` (supply + cash); else `[GetPlayerFunds]` (cash only). |
| Change gate | `coin_interface.sqf:848-856` | compares current `_cashValues` to `BIS_COIN_fundsOld` via `bis_fnc_arraycompare`; rebuild only on change or restart. |
| `BIS_COIN_restart` nil-guard (live fix) | `coin_interface.sqf:850-855` | `BIS_COIN_restart` is set to nil during teardown elsewhere; `|| _restart` with nil would throw "Undefined variable" and abort the tick (placements stop while preview shows). The fix coerces `isNil "_restart"` to `false`. |
| Cash readout | `coin_interface.sqf:857-872` | builds a structured-text block (color `#56db33`, per-currency lines from `BIS_COIN_fundsDescription`) into control `112224` and grows the control height by line count. |
| Category menu rebuild | `coin_interface.sqf:874-885` | clones `BIS_COIN_categories`, drops the Ammo category if `WFBE_UP_AMMOCOIN < 1`, and rebuilds `BIS_Coin_categories` via `BIS_fnc_createmenu`. |
| Item menu rebuild + affordability | `coin_interface.sqf:887-950` | per category, iterates `BIS_COIN_items`; computes `_canAfford = (_cashValue - _itemcost >= 0 && !_buildLimit)`, accumulates `_canAffordCount`, and rebuilds `BIS_Coin_%1_items` with the enable flags via `BIS_fnc_createmenu`. |
| Build-limit gate | `coin_interface.sqf:913-919` | for buildable structures, `_limit = WFBE_C_STRUCTURES_MAX_<type>` (default 4) compared against `wfbe_structures_live`; reaching it forces `_buildLimit = true` so the item renders disabled. |
| Menu refresh on change | `coin_interface.sqf:952` | if `_canAffordCount != _canAffordCountOld`, re-issue `showCommandingMenu` so enable/disable states repaint. |
| PR8 malformed-item guards | `coin_interface.sqf:908,923` | a malformed item (invalid anchor class → `[cash,<null>]` cost) leaves `_itemcost`/`_canAfford` nil; both are forced numeric/zero to stop an undefined-variable RPT cascade in `_canAffordCount`. |

The item-menu action string (`:936-949`) compiles the selected param array back onto the logic (`BIS_COIN_params`), captures `BIS_COIN_menu = commandingMenu`, and clears the menu so the dispatcher/render loop can switch into placement mode.

## Continue Reading

- [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) — CoIn behavior, request handlers, costs, sale/refund and construction authority (the layer this engine defers to).
- [Client input and hotkey handler](Client-Input-Hotkey-Handler) — the separate display-46 handler stack in `Init_Client.sqf` (AFK/tablock/move keys).
- [Client UI systems atlas](Client-UI-Systems-Atlas) — the `description.ext`/`Rsc` UI layer where the `112200`/`1122` construction resources are registered.
- [Commander positions branch audit](Commander-Positions-Branch-Audit) — the `b28b351f` branch-local DEH cleanup diff note.
- [Client funds income HUD readout](Client-Funds-Income-HUD-Readout) — the player-funds readout this loop mirrors into the construction cash block.
