# Client UI Systems Atlas

This page maps the client-facing UI layer from source: `description.ext`, `Rsc/*.hpp`, `Client/GUI`, client FSM loops, map marker scripts, HUD/title resources and WASP overlays. For a player-facing workflow tour before diving into implementation, use [Player UI workflow map](Player-UI-Workflow-Map); for a compact quick reference, use [Client UI, HUD and menus](Client-UI-HUD-And-Menus).

All paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## UI Stack

```mermaid
flowchart TD
    Description["description.ext"] --> Rsc["Rsc/Header, Styles, Parameters, Ressources, Dialogs, Titles"]
    Rsc --> Dialogs["Dialog classes in Rsc/Dialogs.hpp"]
    Rsc --> Titles["Title/cutRsc classes in Rsc/Titles.hpp"]
    Dialogs --> GUI["Client/GUI/*.sqf controller loops"]
    Titles --> HUD["Client/Client_UpdateRHUD.sqf (no Client/RHUD folder) and Client/FSM/client_title_capture.sqf"]
    GUI --> ClientFuncs["Client/Functions UI helpers"]
    GUI --> PVF["WFBE_CO_FNC_SendToServer / SendToClient flows"]
    ClientInit["Client/Init/Init_Client.sqf"] --> GUI
    ClientInit --> HUD
    ClientInit --> ActionFSM["Client/FSM/updateactions.fsm and updateavailableactions.fsm"]
    ClientInit --> MarkerLoops["Client/FSM marker loops"]
    ActionFSM --> Titles
    MarkerLoops --> Map["Map markers and display 12 controls"]
```

## Resource Include Graph

`description.ext` includes the UI stack in this order:

| Include | Role | Evidence |
| --- | --- | --- |
| `Rsc/Header.hpp` | Mission metadata and loading labels. | `description.ext:46`, `Header.hpp:9-10` |
| `Rsc/Styles.hpp` | UI constants such as `ST_*`, `CT_*` and style values. | `description.ext:49` |
| `Rsc/Parameters.hpp` | Mission parameter definitions. Several parameters directly gate UI loops such as map icon blinking, artillery UI, AFK time and EASA. | `description.ext:52`, `Parameters.hpp:86`, `:333`, `:375`, `:547` |
| `Rsc/Ressources.hpp` | Base control classes: buttons, listboxes, structured text, maps, controls groups, sliders and combos. | `description.ext:54`, `Ressources.hpp:46-563` |
| `Rsc/Dialogs.hpp` | Interactive dialog classes and `onLoad` hooks into `Client/GUI`. | `description.ext:56` |
| `Rsc/Titles.hpp` | `cutRsc` / title resources: overlay icons, RHUD/FPS HUD, capture bar, end stats and CoIn construction interface. | `description.ext:58`, `Titles.hpp:23-25` |
| `Rsc/Identities.hpp` | Non-vanilla identities. | `description.ext:62` |

## Dialog Class Map

`Rsc/Dialogs.hpp` defines the mission's modal UI classes. Most large menus are polling loops driven by global action variables (`MenuAction` or `WFBE_MenuAction`) set by control actions in the resource file.

| Class | IDD | Controller | Primary purpose |
| --- | ---: | --- | --- |
| `WFBE_UpgradeMenu` | 504000 | `Client/GUI/GUI_UpgradeMenu.sqf` | Newer upgrade list/detail view; sends `RequestUpgrade`. |
| `WFBE_VoteMenu` | 500000 | `Client/GUI/GUI_VoteMenu.sqf` | Commander vote UI; patch route in [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook). |
| `WFBE_Commander_VoteMenu` | 500999 | `Client/GUI/GUI_Commander_VoteMenu.sqf` | Commander-side vote/reassignment handling; patch route in [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook). |
| `WFBE_RespawnMenu` | 511000 | `Client/GUI/GUI_RespawnMenu.sqf` | Death/respawn map and spawn selector. |
| `WFBE_TransferMenu` | 505000 | `Client/GUI/GUI_TransferMenu.sqf` | Funds transfer from team menu. |
| `WFBE_BuyGearMenu` | 503000 | `Client/GUI/GUI_BuyGearMenu.sqf` | Gear, vehicle cargo, backpacks and profile templates. |
| `WF_Menu` | 11000 | `Client/GUI/GUI_Menu.sqf` | Main Warfare menu/router. |
| `RscMenu_Team` | 13000 | `Client/GUI/GUI_Menu_Team.sqf` | Team management and transfer entry. |
| `RscMenu_BuyUnits` | 12000 | `Client/GUI/GUI_Menu_BuyUnits.sqf` | Unit/vehicle purchase from structures, depots and hangars. |
| `RscMenu_Command` | 14000 | `Client/GUI/GUI_Menu_Command.sqf` | Commander/team orders, task assignment and squad behavior. |
| `RscMenu_Tactical` | 17000 | `Client/GUI/GUI_Menu_Tactical.sqf` | Fast travel, artillery, support requests, UAV and unit camera entry. |
| `RscMenu_Upgrade` | 18000 | `Client/GUI/GUI_Menu_Upgrade.sqf` | Stale legacy upgrade class; controller file is missing. |
| `RscMenu_Service` | 20000 | `Client/GUI/GUI_Menu_Service.sqf` | Rearm/repair/refuel/heal and EASA entry. |
| `RscMenu_UnitCamera` | 21000 | `Client/GUI/GUI_Menu_UnitCamera.sqf` | Unit camera selection. |
| `RscDisplay_Parameters` | 22000 | `Client/GUI/GUI_Display_Parameters.sqf` | Runtime mission parameter display. |
| `RscMenu_EASA` | 23000 | `Client/GUI/GUI_Menu_EASA.sqf` | Aircraft loadout selection. |
| `RscMenu_Economy` | 23000 | `Client/GUI/GUI_Menu_Economy.sqf` | Commander income/sell/respawn-supply-truck controls. |
| `RscMenu_Help` | 508000 | `Client/GUI/GUI_Menu_Help.sqf` | Online/help text panel and WASP branding. |

### Dialog Risks

- `RscDisplay_Parameters` is live and still opens `Client/GUI/GUI_Display_Parameters.sqf`, but the old uptime write to IDC `22005` is block-commented in current source, maintained Vanilla, modded copies, stable/upstream and release. The resource declares the live listbox/buttons (`22003`, `22004`) and no `22005`; treat this as safe comment cleanup, not a missing-control runtime bug.
- UI resource parity cleanup now has a canonical branch/root matrix for the stale old upgrade dialog, Economy missing-control writes and duplicate IDDs. Short version: docs/source and stable/upstream keep the old UI resource shape; release Chernarus fixes stale `RscMenu_Upgrade`, moves EASA to `idd = 24000` and rewrites Economy away from `23004`-`23006`; release Vanilla still carries the old shape; `RscOverlay`/`OptionsAvailable` remain duplicated on `idd = 10200` everywhere checked. Use [UI resource parity cleanup](UI-Resource-Parity-Cleanup) before changing these rows, then [UI IDD collision repair](UI-IDD-Collision-Repair) for duplicate-IDD patch details.
- `GUI_Menu_Service.sqf:240-244` still carries a stale `TBD: Add dialog` comment even though the live path closes the service menu and opens `RscMenu_EASA`. Treat it as stale commentary, not evidence that EASA is missing.
- UI dialog lifecycle scout 2026-06-04: `GUI_Menu_Economy.sqf:10` resets `MenuAction` but does not reset `mouseButtonUp`. Its map-sell path consumes `mouseButtonUp` at `GUI_Menu_Economy.sqf:101-106`, while comparable map-click dialogs reset the latch on open (`GUI_Menu_Command.sqf:3-4`, `GUI_Menu_Tactical.sqf:137-138`, `GUI_Menu_UnitCamera.sqf:8-9`, `GUI_RespawnMenu.sqf:28`). Smoke Economy map-sell after any dialog/map interaction work.
- UI dialog lifecycle scout 2026-06-04: `GUI_Menu_EASA.sqf:3-4` exits on unsupported `vehicle player` without closing the dialog. That can leave a blank/partial EASA surface if the dialog opens from stale context; action-time guards should close or route back cleanly.
- DR-16: `GUI_Menu_Economy.sqf:32-35` has a commented HQ-death sell guard, while active structure sell/refund logic remains at `:105-150`. The UI exposes useful commander affordances, but the sell path belongs to the server-authority migration class.
- `GUI_Menu_Economy.sqf:93-96` keeps old `WFBE_RequestSpecial` relay comments around the live `RespawnST` send-to-server path, and `:136-141` still has a cleanup TODO to replace a name/find lookup with object variables.
- The main menu and most submenus are not event-driven state machines. They are `while {alive player && dialog}` polling loops with `sleep` delays. Keep new work small inside those loops and reuse existing update flags.
- Several menu files return to `WF_Menu` by `closeDialog 0; createDialog "WF_Menu"` rather than maintaining a stack. Adding nested dialogs must preserve those return paths.

### Branch-Only UI Theme Work

`origin/feat/wf-menu-ops-console` head `0767c0b5` is a branch-only UI reskin, not stable-master truth. It changes the palette/control layer in Chernarus and maintained Vanilla (`Rsc/Styles.hpp:10-40`, `Rsc/Ressources.hpp:117-131,274-277`), adds a chevron and footer to `WF_Menu` (`Rsc/Dialogs.hpp:1057-1064,1240-1249`), sets `PuristaBold` on the hub title (`Dialogs.hpp:1173-1179`) and sets `EtelkaMonospacePro` on RHUD numeric values (`Rsc/Titles.hpp:178-179`). Treat it as visual/theme evidence until Arma 2 OA smoke proves the fonts, texture path, contrast and both Chernarus/Vanilla menu surfaces.

Static caveat for the branch: `git diff --check origin/master..origin/feat/wf-menu-ops-console` currently reports trailing whitespace in `docs/superpowers/plans/2026-06-03-wf-menu-ops-console.md:78,179`. Clean that before merge even though it is not mission runtime code.

`origin/feat/buymenu-easa-qol` head `a66d4691` is the smaller UI QoL branch. It changes only three Chernarus client UI files: `Client_UIFillListBuyUnits.sqf:1,61-62,104` colors unaffordable displayed base prices red, `GUI_Menu_BuyUnits.sqf:201-210` appends live queue counts to factory tabs, `GUI_Menu_BuyUnits.sqf:280,335,388,444,487` touches selected-unit cost display and `GUI_Menu_EASA.sqf:29-40` colors/preselects the aircraft's current loadout. Treat this as low-blast-radius UI evidence, not merged behavior: maintained Vanilla is not changed on the branch, and Arma smoke still needs to confirm affordability color versus full/crew cost, queue-label refresh/no flicker, final price field and EASA current-loadout selection. See [BuyMenu EASA QoL branch audit](BuyMenu-EASA-QoL-Branch-Audit).

## Title And HUD Resource Map

`Rsc/Titles.hpp` defines long-lived non-modal resources.

| Resource | IDD/channel | Runtime owner | Purpose |
| --- | --- | --- | --- |
| `RscOverlay` | `idd=10200`, channel 1365 | Spawned from `Init_Client.sqf:147-150` | Older GPS/option overlay; sets `uiNamespace['GUI']`. |
| `CaptureBar` | `idd=600100`, channel 600200 | `Client/FSM/client_title_capture.sqf` | Town/camp capture progress bar using controls `601000-601002`. |
| `OptionsAvailable` | `idd=10200`, channel 12450 and default `CutRsc` | `Client/Client_UpdateRHUD.sqf`, `updateavailableactions.fsm` | Shared action icons plus RHUD/FPS HUD controls. |
| `EndOfGameStats` | `idd=90000` | `Client/GUI/GUI_EndOfGameStats.sqf` | End-of-game stat bars and faction imagery. |
| `WFBE_ConstructionInterface` | `idd=112200`, channel 112200 | `Client/Module/CoIn/coin_interface.sqf` | CoIn building placement cursor, hints, controls and cash panel. |

### HUD Display Ownership

`OptionsAvailable` uses `onLoad = "_this ExecVM ""Client\GUI\GUI_SetCurrentCutDisplay.sqf"""` and `onUnload = "_this ExecVM ""Client\GUI\GUI_ClearCurrentCutDisplay.sqf"""` (`Titles.hpp:170-171`). Those one-line scripts maintain `uiNamespace["currentCutDisplay"]`, which is then used by:

- `Client/Client_UpdateRHUD.sqf:87-95` to recover/recreate the display.
- `Client/FSM/updateavailableactions.fsm:225-233` to write action icons into controls `3500 + index`.

DR-25a branch check 2026-06-05: `RscOverlay` and `OptionsAvailable` both use `idd=10200` (`Titles.hpp:44-51`, `:164-176`) in current source, stable/upstream, maintained Vanilla and the release branch. Treat them as separate `cutRsc` resources with overlapping IDD values; current mission source has no hard-coded `findDisplay 10200` caller, but future title work should not assume IDD lookup is unique.

Wave Q found a separate title lifecycle-handle collision that does not depend on matching IDDs: `EndOfGameStats` has `idd=90000`, but it also sets and clears `uiNamespace["currentCutDisplay"]` through the same `onLoad`/`onUnload` helper scripts as `OptionsAvailable` (`Titles.hpp:532-540`). `GUI_EndOfGameStats.sqf:13,34-44,86-93` cuts `EndOfGameStats` and writes stat bars through that key, while the RHUD loop keeps running (`Client_UpdateRHUD.sqf:183-190`) and can re-cut `OptionsAvailable` when the shared key is null (`:89-92`). Patch title work by splitting display ownership, for example an OptionsAvailable/action-icon/RHUD handle and a separate endgame-stats handle, or by gating RHUD/action-icon recreation once endgame begins. Use [UI IDD collision repair](UI-IDD-Collision-Repair) before changing title IDs or title display variables.

## Client Init UI Boot

`Client/Init/Init_Client.sqf` wires the UI layer in several waves:

| Lines | Behavior |
| --- | --- |
| `49-80` | Compiles old-style UI helpers (`BuildUnit`, `UIChangeComboBuyUnits`, `UIFillListBuyUnits`, `UIFillListTeamOrders`, `UIFindLBValue`). |
| `83-85` | Defines `BIS_FNC_GUIset` / `BIS_FNC_GUIget` wrappers over `uiNamespace`. |
| `116-127` | Compiles gear UI helper functions and respawn selector. |
| `147-150` | Keeps `RscOverlay` alive while no map/camera display is active. |
| `161-162` | Clears stale title displays before waiting for common init. |
| `330-339` | Initializes `RUBHUD`, `RUBFPSHUD`, `RUBGPS`, `RUBOSD`, then starts `Client/Client_UpdateRHUD.sqf`. |
| `356-387` | Starts client marker/action/resource/update loops after init. |
| `570-575` | Applies skill module, starts WASP base repair and WASP action overlay. |
| `592-593` | Loads keybind initialization. |
| `730-736` | Re-runs `Client/Init/Init_Markers.sqf` after a short JIP delay. |
| `779-782` | Starts blinking marker bookkeeping only when `WFBE_C_MAP_ICON_BLINKING_ENABLED` is enabled. |
| `785` | Plays `Videos/intro720p.ogv`. |
| `790` | Opens `WFBE_VoteMenu` if a vote is already running. |
| `959` | Shows the long new-player hint with Discord and map guidance. |

### View Distance And Target FPS Hotkeys

The current source has a live client-side view-distance system:

- Client init sets `AUTO_DISTANCE_VIEW_TARGET_FPS` to 60 and starts automatic mode off (`Init_Client.sqf:12-13,175-176`).
- Display 46 binds `Common_AdjustViewDistance.sqf` as a `KeyDown` handler (`Init_Client.sqf:236-240`).
- `User18` toggles automatic view distance, saving the current distance before enabling and restoring it when disabled (`Common_AdjustViewDistance.sqf:17-33`).
- `User19`/`User20` are dual-purpose. In automatic mode they adjust target FPS by 1 and clamp it to 30..240 while persisting `WFBE_TARGET_FPS`; in manual mode they adjust view distance by 1000 meters through the timer script (`Common_AdjustViewDistance.sqf:35-69`).
- The automatic loop runs from `updateclient.sqf` only when the toggle is enabled and the map is not visible (`updateclient.sqf:102-107`). This preserves the old upstream lesson that FPS helpers must not react to map-open view state.
- Runtime adjustment uses a target band of +/-4 FPS, hard-clamps view distance to 500..6000, lowers by 200 when below the band and raises by 300 or 50 otherwise (`Common_AutomaticViewDistance.sqf:6-36`).

Historical changelog text says +/-2 FPS. Treat that as old provenance; the current source and messages use +/-4.

## Main Menu Router

The player opens the main menu through the scroll action wired by `Client/Functions/Client_AddWFMenuAction.sqf:17` and `Client/Action/Action_Menu.sqf:1`.

`Client/GUI/GUI_Menu.sqf` polls `MenuAction` every 0.1 seconds and routes to submenus:

| `MenuAction` | Result |
| ---: | --- |
| 1 | `RscMenu_BuyUnits` |
| 2 | `WFBE_BuyGearMenu` |
| 3 | `RscMenu_Team` |
| 4 | Vote menu or commander vote flow |
| 5 | `RscMenu_Command` |
| 6 | `RscMenu_Tactical` |
| 7 | `WFBE_UpgradeMenu` |
| 8 | `RscMenu_Economy` |
| 9 | `RscMenu_Service` |
| 10 | Unflip nearby/current vehicle |
| 11 | Headbug fix via temporary vehicle move |
| 12 | `RscDisplay_Parameters` |
| 13 | `RscMenu_Help` |
| 16 | Toggle full `RUBHUD` |
| 17/18 | Dormant/orphaned GPS zoom handlers; `GUI_Menu.sqf` still handles them in Chernarus and maintained Vanilla, but audited `WF_Menu` controls expose actions 1-13, 16 and 19 only. |
| 19 | Toggle FPS-only HUD |

Range booleans such as `barracksInRange`, `gearInRange`, `commandInRange` and `serviceInRange` are maintained by `Client/FSM/updateavailableactions.fsm`, not by the main menu itself.

Mini UI scout note 2026-06-04 plus branch recheck 2026-06-05: no live buy/gear/service/tactical/vote/unit-camera control was found with an outright missing handler. The important main-menu mismatch is narrower: `MenuAction == 17/18` remains in the router for GPS zoom in current source/Vanilla, `origin/master`, `miksuu/master` and `origin/release/2026-06-feature-bundle`, but fixed-string action searches found no `MenuAction = 17` or `MenuAction = 18` emitter in maintained roots.

## Major Controller Flows

### Buy Units

`GUI_Menu_BuyUnits.sqf`:

- Selects nearest active factory/depot/hangar context (`:48`, `:214-237`).
- Refreshes unit lists through `UIChangeComboBuyUnits` and `UIFillListBuyUnits` (`:197-198`).
- Enforces AI capacity based on `WFBE_C_PLAYERS_AI_MAX`, barracks upgrade level and commander bonus (`:117-124`).
- Sends the final purchase to `BuildUnit` (`:155`), which later handles spawn details and salvage FSM entry.
- Displays ambulance and supply-truck hints for important support vehicles (`:443-449`).

### Command Menu Interaction Model

The command menu is easy to misread from source because much of its workflow is icon-driven:

| Interaction | Source evidence | Developer note |
| --- | --- | --- |
| Three icon tabs/modes | `Rsc/Dialogs.hpp:2100-2123`; `GUI_Menu_Command.sqf:111-170` | The tab buttons are icons while the title text is the main visible mode cue. Docs and future UI work should name the three modes and keep icon/title state in sync. |
| Multi-select teams plus "All" behavior | `Dialogs.hpp:1913-1923`; `GUI_Menu_Command.sqf:115-118,277-307,397-404` | Actions can target a selected subset or all teams depending on the `All` row/selection state. Smoke both selected-subset and all-teams paths after command-menu edits. |
| Two-step map orders | `Dialogs.hpp:1846-1888,2047-2059`; `GUI_Menu_Command.sqf:262-313,315-345` | The player arms an order mode with a button, then clicks the map to place move/patrol/defend/task targets, with marker-color feedback. Do not document task/order buttons as immediate actions. |

### Buy Gear

For the full source-backed data/runtime/generator map, see [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas).

`GUI_BuyGearMenu.sqf` uses `WFBE_MenuAction`, not `MenuAction`, and works across three views:

- `gear`: player/AI equipment.
- `backpack`: OA backpack content where available.
- `vehicle`: cargo inventory.

The helper functions compiled in `Init_Client.sqf:116-126` own list filling, template parsing, sanitizing, inventory display, price calculation and target selection. Profile template saving is compiled only when the OA version gate passes (`Init_Client.sqf:169-172`).

### Commander And Tactical Menus

`GUI_Menu_Command.sqf` owns team selection, AI team templates, behavior/combat/formation/speed combos, move/task controls and respawn factory choice. The move/order helpers are live, but task assignment is partial: the dialog exposes the Set Task button (`Rsc/Dialogs.hpp:2052-2053`) and `GUI_Menu_Command.sqf:315-344` gathers task data and plays HQ speech, while the `SetTask` send calls are commented at `:335-337` and `:343`.

Vote menu cleanup edge: `WFBE_Client_Teams_Count` is initialized as `count WFBE_Client_Teams` (`Init_Client.sqf:273`), but `GUI_Commander_VoteMenu.sqf:58-66` and `GUI_VoteMenu.sqf:29,61-66` use it as an inclusive `for ... to` maximum. Existing `isNil` guards make this mostly a refresh-loop polish bug rather than a proven crash, but vote UI changes should switch to `(WFBE_Client_Teams_Count - 1)` or `forEach`.

Vote behavior changes should start from [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook). That page owns the DR-47 server/UI outcome mismatch, the no-commander/tie decision matrix and the smoke cases that must accompany any `GUI_VoteMenu.sqf` preview change.

Vote row coloring has a second small indexing edge. In `GUI_VoteMenu.sqf:74-83`, the loop variable already tracks the list row while scanning `lnbSize`, but the color write uses `[_i+1,0]`. If touching vote refresh, audit both the backing team-array loop and this row-color mapping together.

Commander reassignment has a separate selector fragility. `GUI_Commander_VoteMenu.sqf:33-46` reads the selected row text, then finds the target team by comparing `name leader _x`. Because the row already stores the team index with `lnbSetValue`, future fixes should use the stored value instead of visible names so duplicate names or mid-dialog name changes cannot select the wrong commander. Keep this UI fix aligned with [Commander reassignment call shape](Commander-Reassignment-Call-Shape) and [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook).

Help dialog lifecycle edge: `RscMenu_Help` stores the display as `uiNamespace["dialog_HelpPanel"]` on load, but unload clears `uiNamespace["cti_dialog_ui_onlinehelpmenu"]` and calls `GUI_Menu_Help.sqf` with `onUnload` (`Dialogs.hpp:3446-3447`). The controller only implements `onLoad` and `onHelpLBSelChanged` (`GUI_Menu_Help.sqf:5-10`). This looks like stale namespace wiring, so avoid building new help-panel state on the old unload variable without cleaning it.

Main-menu orphan route: `GUI_Menu.sqf:202-208` still handles `MenuAction == 17/18` for GPS zoom, but the audited `WF_Menu` resource block exposes actions `1-13`, `16` and `19` only. The same handler-only shape exists in maintained Vanilla, stable master, Miksuu upstream and the current release branch; modded Napf/Eden/Lingor also keep copied handlers. Treat those router cases as dead UX baggage unless a hidden/branch control is deliberately reintroduced and smoke-tested.

`GUI_Menu_Tactical.sqf` is the support hub. It builds the support list from fast travel, ICBM, paratroopers, ammo/vehicle paradrops, UAV actions and unit camera (`:56-64`). Availability is recomputed from current upgrades, funds, cooldowns and selected support (`:144-290`), then requests are sent through `RequestSpecial` where needed (`:373` and later request branches).

### Upgrade And Economy Menus

`GUI_UpgradeMenu.sqf` reads side upgrade arrays, costs, descriptions, images, labels, levels, links and times from missionNamespace (`:9-18`). Commander-only purchase sends `RequestUpgrade` (`:158-161`) and starts local progress feedback for pure clients (`:168-174`).

`GUI_Menu_Economy.sqf` handles commander income percentage, structure selling and supply-truck respawn. The respawn supply-truck action sends `["RequestSpecial", ["RespawnST", sideJoined]]` (`:90-96`), which ties this UI directly to the partially broken AI/supply-truck feature described in [Feature status register](Feature-Status-Register).

Spark UI scout 2026-06-04 control/action map:

| Menu | Control/action | Runtime effect |
| --- | --- | --- |
| Main menu | `MenuAction == 7` | Opens `WFBE_UpgradeMenu` (`GUI_Menu.sqf:161-166`). |
| Main menu | `MenuAction == 8` | Opens `RscMenu_Economy` (`GUI_Menu.sqf:168-173`). |
| `WFBE_UpgradeMenu` | `idc 504001` | Upgrade list selection/double-click drives `WFBE_MenuAction = 1` or `2` (`Rsc/Dialogs.hpp:75-86`; `GUI_UpgradeMenu.sqf:73-83,129-161`). |
| `WFBE_UpgradeMenu` | `idc 504007` | Purchase button sets `WFBE_MenuAction = 1`; the controller validates locally and sends `RequestUpgrade` (`Rsc/Dialogs.hpp:122-131`; `GUI_UpgradeMenu.sqf:129-161`). |
| `WFBE_UpgradeMenu` | `WFBE_MenuAction == 1000` | Returns to `WF_Menu` (`GUI_UpgradeMenu.sqf:206-210`). |
| `RscMenu_Economy` | `idc 23010`, `23011`, `23012` | Income slider, percent label and Set Income button; `MenuAction == 3` applies the split (`Rsc/Dialogs.hpp:3360-3380`; `GUI_Menu_Economy.sqf:74-81`). |
| `RscMenu_Economy` | `idc 23013`, `23014` | Commander/player income labels (`Rsc/Dialogs.hpp:3381-3391`; `GUI_Menu_Economy.sqf:70-71`). |
| `RscMenu_Economy` | `idc 23015` | Sell Structure button; `MenuAction == 105` runs map-pick, refund and damage/destroy flow (`Rsc/Dialogs.hpp:3394-3401`; `GUI_Menu_Economy.sqf:105-151`). |
| `RscMenu_Economy` | `idc 23016` | Respawn supply-truck control; `MenuAction == 4` sends `RequestSpecial ["RespawnST", sideJoined]` (`Rsc/Dialogs.hpp:3407-3415`; `GUI_Menu_Economy.sqf:91-97`). |

Localization note: Economy labels are mostly `STR_*` backed, but the live `WFBE_UpgradeMenu` resource still hardcodes `"Upgrade Menu :"` and `"Upgrade"` in `Rsc/Dialogs.hpp:36,129-130`. The Buy Units and Tactical controllers also still carry live hardcoded English player-facing help/status text: vehicle help hints in `GUI_Menu_BuyUnits.sqf:443-457` and artillery ammo request status in `GUI_Menu_Tactical.sqf:604-605`. Treat these as UI consistency/localization debt, not gameplay bugs.

### EASA

EASA opens from `GUI_Menu_Service.sqf` and uses generated arrays from `Client/Module/EASA/EASA_Init.sqf`. Its dialog shares `idd=23000` with Economy, and the detailed runtime is documented in [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas).

### Respawn Menu

Respawn flow starts in `Client/Functions/Client_OnKilled.sqf:156` with `createDialog "WFBE_RespawnMenu"`. The canonical source-backed flow, spawn-source table, MASH split, AI respawn path and custom-gear penalty edge now live in [Respawn and death lifecycle atlas](Respawn-And-Death-Lifecycle-Atlas).

## RHUD And FPS HUD

There is no standalone `Client/RHUD` directory in the current checkout. RHUD is the combination of `Client/Client_UpdateRHUD.sqf`, the `OptionsAvailable` title resource and the main-menu toggles.

`Client/Client_UpdateRHUD.sqf` is the optimized HUD loop:

- Starts hidden by default: `RUBHUD = false`, `RUBFPSHUD = false` (`:3-7`).
- Uses `OptionsAvailable` as the shared display and repairs it if missing (`:87-95`).
- Caches controls, last texts, last colors and last visibility state (`:22-56`).
- Has three modes: hidden, FPS-only and full RHUD (`:205-239`).
- Refreshes expensive town/economy aggregates every 3 seconds instead of every loop (`:338-350`).
- Records local performance audit samples under `client_rhud` (`:366-370`).

Full RHUD displays health, uptime, commander, AI count, money, income, side supply, supply income/minimum, towns held and client/server FPS. FPS-only mode repositions four controls into a small upper-right overlay.

Wave P clarified the server-FPS contract: player UI reads `SERVER_FPS_GUI` from `Client/Client_UpdateRHUD.sqf:113`, populated by `Server/GUI/serverFpsGUI.sqf:6-7`. The second dedicated publisher `Server/Module/serverFPS/monitorServerFPS.sqf:4-6` publishes `WFBE_VAR_SERVER_FPS`, but no current source Chernarus player-UI reader was found. Treat that as a compatibility/redundancy channel until generated and modded consumers are deliberately retired.

## Map And Marker UI

Map UI is split across one-shot initialization, long-running refresh loops and event handlers:

| Script | Role | Performance posture |
| --- | --- | --- |
| `Client/Init/Init_Markers.sqf` | Creates local town/camp markers. Re-run after JIP delay. | One-shot plus JIP refresh. |
| `Client/FSM/updatetownmarkers.sqf` | Updates town marker text/status while map is visible. | Sleeps longer when map is closed; records `updatetownmarkers`. |
| `Client/FSM/updateteamsmarkers.sqf` | Tracks team/player/AI markers, AFK suffix and alpha/color changes. | Skips most work when no map/GPS/Warfare dialog consumer is visible; records `updateteamsmarkers`. |
| `Client/FSM/updateavailableactions.fsm` | Computes range booleans and writes action availability icons. | Tracks `nearEntities` count and records `updateavailableactions`. |
| `Client/Functions/Client_BookkeepBlinkingIcons.sqf` | Optional combat marker blinking bookkeeping. | Fully gated by `WFBE_C_MAP_ICON_BLINKING_ENABLED`. |
| `WASP/global_marking_monitor.sqf` | Adds a display-12 map double-click handler that prefixes marker text with the player's name. | Polls for the marker dialog/display before attaching `mouseButtonDblClick`; current source disables all user input, then runs an unslept wait for up to two seconds before re-enabling input (`:57-73`). Add a tiny backoff and fail-safe unlock before expansion. |

## Action Menus And Scroll Actions

The scroll-action surface is part UI, part gameplay:

- `Client_AddWFMenuAction.sqf` stores/removes the WF menu action ID on the current player object so respawn does not leave stale actions.
- `updateactions.fsm` attaches the blue `STR_WF_Options` action to the player's current vehicle and removes it from the previous vehicle.
- `Client_AddPlayerAIActions.sqf` attaches AI diagnose/recover actions and removes stale IDs first.
- `Client_PreRespawnHandler.sqf` reapplies WF menu and player AI actions after respawn, then also runs WASP `OnKilled`/RPG-drop hooks.
- `WASP/baserep/viem.sqf` attaches a commander-only base-repair action near damaged base structures and removes it when conditions change.

## UI Assets

`Client/Images` contains 45 `.paa` files plus `fps_hud.jpg`. Resource users include:

- Gear tabs: `gearicontemplate`, `geariconall`, `geariconprimary`, `geariconsecondary`, `geariconsidearm`, `geariconmisc`.
- Buy-unit controls: factory/category images and crew toggles (`i_driver`, `i_gunner`, `i_commander`, `i_extra`, `i_lock`). See [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) for the full buy/spawn flow.
- Action availability icons: `icon_wf_building_*` and `icon_wf_support_*`.
- Upgrade category icons: `wf_b`, `wf_lvf`, `wf_hvf`, `wf_air`, `wf_par`, `wf_uav`, `wf_sup`, `wf_*`.
- Help branding: `Textures/logo1.paa`.

The intro video is `Videos/intro720p.ogv`, started from `Init_Client.sqf:785`.

## Known UI Risks And Partial Work

| Area | Evidence | Risk |
| --- | --- | --- |
| Duplicate dialog IDD | EASA/Economy share `idd = 23000` in current source/stable/upstream; release Chernarus changes EASA to `24000`, but release Vanilla remains duplicated. | Parity cleanup or formal waiver. Route through [UI resource parity cleanup](UI-Resource-Parity-Cleanup) and [UI IDD collision repair](UI-IDD-Collision-Repair). |
| Stale old upgrade dialog | `RscMenu_Upgrade` references missing `Client/GUI/GUI_Menu_Upgrade.sqf` and old missing `Client\Images\wf_*.paa` assets; live flow uses `WFBE_UpgradeMenu`. | Treat as dead/stale. Route through [UI resource parity cleanup](UI-Resource-Parity-Cleanup); smoke live `WFBE_UpgradeMenu` after removal/alias. |
| Shared title IDD | `RscOverlay` and `OptionsAvailable` both use `10200` across current source/stable/upstream/release roots checked. | Route through [UI resource parity cleanup](UI-Resource-Parity-Cleanup) first, then fix title display ownership and smoke RHUD/action icons/endgame together. |
| Shared title lifecycle handle | `OptionsAvailable` and `EndOfGameStats` both set/clear `uiNamespace["currentCutDisplay"]` from their `onLoad`/`onUnload` scripts; RHUD/action-icon recovery can recreate `OptionsAvailable` while endgame stats writes through the same key. | Split title display variables or gate RHUD/action-icon recreation during endgame; smoke RHUD/FPS, action icons and endgame stat bars together. |
| Malformed clickable-text base control config | DR-25b: `RscClickableText.soundPush[] = {, 0.2, 1};` in `Rsc/Ressources.hpp:556`; the same shape is present in source Chernarus, maintained Vanilla Takistan and the main modded forks. `Ressources.hpp:92` shows the valid empty-sound shape as `{"", 0.2, 1}`. | Fix the base class before deriving new clickable controls from it; then smoke representative buttons/resources in Arma 2 OA. |
| Economy dialog missing controls | Current source/stable/upstream `GUI_Menu_Economy.sqf:7-8` writes to `23004`/`23005`/`23006`, while `RscMenu_Economy` declares `23002`, `23003` and `23008+`; release Chernarus rewrote this, release Vanilla did not. | Parity cleanup through [UI resource parity cleanup](UI-Resource-Parity-Cleanup). Smoke Economy disabled state, income controls, sell mode and supply-truck respawn after the change. |
| Polling loops | `GUI_Menu.sqf`, buy/command/tactical/service/upgrade/respawn menus all run scheduled loops. | Keep work incremental and cache expensive state. |
| Map marker loops | Marker loops are live-server sensitive and now include performance-audit records. | Preserve map-closed skip behavior and `WFBE_C_MAP_ICON_BLINKING_ENABLED` gates. |
| WASP marker dialog wait/input lock | `WASP/global_marking_monitor.sqf:57-73` disables all user input and does up to two seconds of unslept display polling before re-enabling input. | Add a tiny sleep/backoff and a fail-safe unlock; smoke map-marker creation and rapid double-click/dialog-close behavior before adding more WASP marker features. |
| Respawn selector loop | `Client_UI_Respawn_Selector.sqf` sleeps `0.03`. | Do not add expensive marker or object scans inside it. |
| Economy supply-truck UI | `GUI_Menu_Economy.sqf` can send `RespawnST`. | This touches the config-gated broken autonomous supply-truck path. |
| Command task assignment UI | `Rsc/Dialogs.hpp:2052-2053` exposes the button and `GUI_Menu_Command.sqf:315-344` builds task data/HQ speech, but the `SetTask` sends are commented. | Visible partial feature; revive only with JIP/task-spam review, or hide the affordance. |
| Commander reassignment selection by name | `GUI_Commander_VoteMenu.sqf:33-46` resolves the selected row by visible leader name instead of the row's stored team value. | Fold into [Commander reassignment call shape](Commander-Reassignment-Call-Shape) and [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook); use row value/team identity when patching DR-15. |
| Vote menu inclusive loops | `GUI_Commander_VoteMenu.sqf:58` and `GUI_VoteMenu.sqf:29,61` loop to `WFBE_Client_Teams_Count`, which equals `count WFBE_Client_Teams`. | Treat as UI correctness debt; use `count - 1` or `forEach` if touching vote refresh. |
| Vote row color offset | `GUI_VoteMenu.sqf:74-83` scans list rows but colors row `[_i+1,0]`. | Fold into the vote-refresh cleanup; smoke multiple candidates and vote changes so the highlighted/current row still matches the selected team. |
| Help menu stale unload state | `Dialogs.hpp:3446-3447` sets `dialog_HelpPanel` on load but clears `cti_dialog_ui_onlinehelpmenu` on unload; `GUI_Menu_Help.sqf` has no `onUnload` case. | Clean namespace key ownership before adding new help-menu state or controller behavior. |
| Economy sell guard commented | DR-16: `GUI_Menu_Economy.sqf:32-35` comments an HQ-death guard while `:105-150` keeps the sell/refund path active. | Treat structure selling as part of the server-authority migration class, not as a safe UI-only feature. |
| Economy stale cleanup notes | `GUI_Menu_Economy.sqf:93-96,136-141` contains dead relay comments and a TODO to replace lookup-by-find behavior. | Clean comments/lookup behavior before using this menu as a model for new commander controls. |
| Service/EASA stale TODO | `GUI_Menu_Service.sqf:240-244` says EASA dialog is TBD, but the live path opens `RscMenu_EASA`. | Do not document EASA as missing; update comments if touching service UI. |
| Buy-unit price/key alignment | `GUI_Menu_BuyUnits.sqf` and `Client_UIFillListBuyUnits.sqf` keep three related UI/economy risks: selected-detail price drift, stale `UNIT_COST_MODIFIER` after discounted list fills and uppercase/lowercase driver-default profile key split. Release and `origin/feat/buymenu-easa-qol` fix only the Chernarus selected-detail formula; Vanilla, modifier reset and driver key remain open. | Canonical matrix: [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas#buy-menu-price-and-driver-key-branch-matrix). Normalize one price helper/reset path and one profile key before buy-menu polish; smoke list/detail/charge, funds guard, checkbox state, max-out/reset and actual spawned crew/count together. |
| Hardcoded live UI text | `GUI_Menu_BuyUnits.sqf:443-457` shows English vehicle-help hints for ambulances, repair trucks, supply trucks and artillery; `GUI_Menu_Tactical.sqf:604-605` shows English artillery ammo request status. | Move to stringtable keys during UI polish; verify no missing keys and keep tactical status formatting intact. |
| Buy-unit authority | `RscMenu_BuyUnits` drives local `GUI_Menu_BuyUnits.sqf` and `Client_BuildUnit.sqf`; no `RequestBuyUnit` PVF exists. | UI purchase checks are not server authority; see [Deep-review findings](Deep-Review-Findings) DR-14 and [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas). |
| Buy-gear authority and partials | `GUI_BuyGearMenu.sqf` includes TODOs for target refresh, vehicle target content and template scope; profile-template save filtering has a confirmed `_u_upgrade` bug; cargo equip helpers have confirmed inclusive loop bounds. | Avoid expanding templates until gear, cargo, vehicle and backpack behavior is deliberately mapped; buy-gear spend joins DR-28's client-authoritative economy class. See [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) and [Deep-review findings](Deep-Review-Findings) DR-28. |
| Buy-gear stale target/content TODOs | `GUI_BuyGearMenu.sqf:64-75` refreshes targets only through `_update_target` and still says `todo refresh targets on click`; vehicle view fills from cached `_gear_vehicle_content` and carries `todo update target content` at `:140-146`; primary weapon replacement still has `todo update mags` at `:245-249`; inventory pricing later uses cached gear/vehicle content at `:480-487`. | Treat target refresh, vehicle cargo and template work as partial before adding more gear QoL. Smoke target switching, dead target refresh, vehicle cargo edits and primary-weapon magazine replacement together. |
| Tactical fast-travel fee UX | `GUI_Menu_Tactical.sqf:146-147` still has a travel-fee policy TODO; fee mode hides destinations when funds are too low (`:185-199`) and draws fee text without a confirmation prompt (`:208-217`), then debits on travel at `:403-406`. | Functional but partial UX. Decide whether paid destinations should be shown disabled/explained and whether a confirmation prompt is needed before debiting. |
| Upgrade progress feedback partial | `GUI_UpgradeMenu.sqf:157-165` locally debits funds/supply and sends `RequestUpgrade`, then sets `wfbe_upgrading`/`wfbe_upgrading_id`, but the local upgrade thread/timer/hint remains TODO. | Current source has basic "upgrade running" feedback, not a complete local progress timer. Keep server authority work separate from UI progress polish. |
| Hardcoded help menu content | `GUI_Menu_Help.sqf:7-8` hardcodes topic labels and `:12-224` embeds large English help strings in the controller. | Localization/content debt. Move to stringtable or data files only after owner decides whether the help panel should remain in-game documentation. |
| EASA/service authority and service affordability lag | `GUI_Menu_Service.sqf` and `GUI_Menu_EASA.sqf` are live aircraft/service UI paths. The service menu enables the heal button for `Man` targets using the previous `_healPrice` before recomputing it at `GUI_Menu_Service.sqf:128-137`. | Service/EASA spend and loadout changes are UI-originated; see [Deep-review findings](Deep-Review-Findings) DR-28, [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas) and the local [service menu affordability guards](Service-Menu-Affordability-Guards). As a local UI fix, recompute price before enabling the button. |
| CoIn title registration | `WFBE_ConstructionInterface` is cut from `coin_interface.sqf` and stores `wfbe_title_coin`, but it is not listed in `RscTitles.titles[]`. | Construction appears intentionally wired; verify in-game before refactoring title registration. |
| Disabled task UI | `TaskSystem` compile and town task spawn are commented in `Init_Client.sqf:75` and `:744-745`. | Task UI behavior is partial/disabled; revive only with JIP and spam review. |

## JIP And Headless-Client Verdict

The UI layer is reviewed for JIP/headless scope as of 2026-06-02. It is ordinary-client and hosted-client code; headless clients do not run the UI init path.

Client-bound PVF runtime notes are now centralized in [Networking and public variables](Networking-And-Public-Variables#registered-client-pvf-runtime-matrix). Use that matrix before reviving `SetTask`, paratrooper markers, MASH marker replay, attack-wave JIP display, endgame routing or money-changing localized messages.

| Question | Source-backed verdict |
| --- | --- |
| Does a dedicated headless client run UI scripts? | No. `initJIPCompatible.sqf:70-76` and `:224-234` run client init only for hosted server or non-headless non-dedicated clients; `:237-238` sends detected headless clients to `Headless/Init/Init_HC.sqf` instead. |
| Does a late-joining client wait for usable side/team state before UI init? | Mostly yes, but without timeouts. `initJIPCompatible.sqf:224-233` waits for `WFBE_PRESENTSIDES` and each side's `wfbe_teams` before launching `Init_Client.sqf`; `Init_Client.sqf:165`, `:360`, `:367-369`, `:384`, `:394-397`, `:463-467`, `:490`, `:595`, `:757` and `:787` then wait on common/town/client logic state. This inherits the broader boot/JIP wait-chain caveat in [Lifecycle wait-chain](Lifecycle-Wait-Chain): a never-synced variable can hang the client UI path. |
| Are local UI/title displays resilient after JIP or display loss? | Partly. `Init_Client.sqf:147-150` keeps the legacy `RscOverlay` alive, `:161-162` clears stale title display refs, `Rsc/Titles.hpp:170-171` tracks `OptionsAvailable` in `uiNamespace["currentCutDisplay"]`, and `Client_UpdateRHUD.sqf:87-95` recreates `OptionsAvailable` if the stored display is null. Caveat: `EndOfGameStats` also uses the same `currentCutDisplay` key (`Titles.hpp:539-540`), so endgame stat rendering should be smoke-tested with RHUD/action icons enabled before claiming title-display resilience. |
| Are markers and vote UI rehydrated for late joiners? | Partly. `Init_Client.sqf:730-734` re-runs `Client/Init/Init_Markers.sqf` after a short JIP delay, `updateclient.sqf:41-99` re-evaluates west/east HQ wreck marker state, and `Init_Client.sqf:787-789` opens `WFBE_VoteMenu` if the side logic says a vote is already running. Public-variable marker styling still needs the marker-specific smoke cases from [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas). |
| Do respawns restore the UI/action surface? | Yes for the audited local action surface. `Client_OnKilled.sqf:49-52` closes active dialogs, `:60-87` waits for the new player object and rebinds the killed EH, then calls `PreRespawnHandler` at `:87-89`. `Client_PreRespawnHandler.sqf:1-38` reapplies skill effects, restarts `updateactions.fsm`, re-adds the WF menu/player AI actions and restores commander build action when applicable. |
| Is "HC" wording ambiguous in this code? | Yes. `updateclient.sqf:203-205` and `:227-228` call `hcAllGroups` / `HCRemoveAllGroups`, which are player high-command UI/group controls. They are not evidence that the Arma 2 OA headless-client process is running UI code. |

Verdict: mark the UI/HUD/menus JIP/HC coverage cell as reviewed with caveats. No dedicated headless-client UI execution was found. Late-join support exists through client-role gating, marker replay, HQ marker repair and vote/menu recovery, but the UI path depends on multiple unbounded synchronized-variable waits and several event-style publicVariable handlers that require feature-specific smoke rather than a blanket "JIP clean" claim.

## Safe Extension Points

- For a new modal workflow, add a distinct class in `Rsc/Dialogs.hpp`, a controller under `Client/GUI`, and a main-menu or action entry. Use a unique IDD.
- For status HUD data, extend `OptionsAvailable` controls and update `Client/Client_UpdateRHUD.sqf` with cached text/color/show writes.
- For range/action indicators, extend `_icons` and `_usable` together in `updateavailableactions.fsm`, then verify the matching `OptionsIcon` exists in `Rsc/Titles.hpp`.
- For map marker behavior, prefer local markers and preserve map-closed sleep/backoff logic.
- For respawn UI, keep marker selection and actual respawn execution separated: marker loop in `Client_UI_Respawn_Selector.sqf`, action in `GUI_RespawnMenu.sqf`, post-respawn state in `Client_OnRespawnHandler.sqf`.
- For WASP UI additions, check [WASP overlay](WASP-Overlay) first because some old action chains are commented or missing.

## Continue Reading

Previous: [Player UI workflow map](Player-UI-Workflow-Map) | Next: [Tools/build](Tools-And-Build-Workflow)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
