# Client UI Systems Atlas

This page maps the client-facing UI layer from source: `description.ext`, `Rsc/*.hpp`, `Client/GUI`, client FSM loops, map marker scripts, HUD/title resources and WASP overlays. For a player-facing workflow tour before diving into implementation, use [Player UI workflow map](Player-UI-Workflow-Map); for a compact quick reference, use [Client UI, HUD and menus](Client-UI-HUD-And-Menus).

All paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

Unless a row names another ref, source anchors below are from docs checkout `docs/developer-wiki-index` `a71b42fe`. Rechecked 2026-06-14: the UI source paths behind the vote/help/main-menu and clickable-text matrices are unchanged from the earlier `f7bc72a8` anchor snapshot, so the docs-checkout line refs remain valid while stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` differ by UI surface.

## How To Use This Page

Use this atlas for UI ownership, controller routing, title/display lifecycle, marker/UI surfaces and compact source anchors. Do not put full patch matrices here when a narrower owner page already exists.

| Need | Open this |
| --- | --- |
| Resource, IDD and image-reference cleanup | [UI resource parity cleanup](UI-Resource-Parity-Cleanup), [UI IDD collision repair](UI-IDD-Collision-Repair) |
| Vote, commander reassignment and task/objective controls | [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), [Commander reassignment call shape](Commander-Reassignment-Call-Shape) |
| Buy Units UI, queue, price and purchase semantics | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) |
| Gear, EASA, service and profile-template details | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Service menu affordability guards](Service-Menu-Affordability-Guards), [Gear template profile filter](Gear-Template-Profile-Filter) |
| Tactical supports, paratrooper/MASH/UAV/artillery markers | [Support specials and tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Abandoned feature revival](Abandoned-Feature-Revival-Review) |
| Cadence/performance evidence | [Performance opportunity sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow) |

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
- UI resource parity cleanup owns the branch/root matrix for the stale old upgrade dialog, Economy missing-control writes and duplicate IDDs. Short version after the 2026-06-14 check: docs/source, Miksuu and perf keep the old dialog/Economy shape; stable `origin/master` `cf2a6d6a` and release `a96fdda2` remove `RscMenu_Upgrade`, move EASA to `idd = 24000`, and rewrite Economy away from `23004`-`23006` in both maintained roots; `RscOverlay`/`OptionsAvailable` remain duplicated on `idd = 10200` everywhere checked. Use [UI resource parity cleanup](UI-Resource-Parity-Cleanup) before changing these rows, then [UI IDD collision repair](UI-IDD-Collision-Repair) for duplicate-IDD and title-handle patch details.
- `GUI_Menu_Service.sqf:240-244` still carries a stale `TBD: Add dialog` comment even though the live path closes the service menu and opens `RscMenu_EASA`. Treat it as stale commentary, not evidence that EASA is missing.
- UI dialog lifecycle scout 2026-06-04: `GUI_Menu_Economy.sqf:10` resets `MenuAction` but does not reset `mouseButtonUp`. Its map-sell path consumes `mouseButtonUp` at `GUI_Menu_Economy.sqf:101-106`, while comparable map-click dialogs reset the latch on open (`GUI_Menu_Command.sqf:3-4`, `GUI_Menu_Tactical.sqf:137-138`, `GUI_Menu_UnitCamera.sqf:8-9`, `GUI_RespawnMenu.sqf:28`). Smoke Economy map-sell after any dialog/map interaction work.
- UI dialog lifecycle scout 2026-06-04: `GUI_Menu_EASA.sqf:3-4` exits on unsupported `vehicle player` without closing the dialog. That can leave a blank/partial EASA surface if the dialog opens from stale context; action-time guards should close or route back cleanly.
- DR-16: `GUI_Menu_Economy.sqf:32-35` has a commented HQ-death sell guard, while active structure sell/refund logic remains at `:105-150`. The UI exposes useful commander affordances, but the sell path belongs to the server-authority migration class.
- `GUI_Menu_Economy.sqf:93-96` keeps old `WFBE_RequestSpecial` relay comments around the live `RespawnST` send-to-server path, and `:136-141` still has a cleanup TODO to replace a name/find lookup with object variables.
- The main menu and most submenus are not event-driven state machines. They are `while {alive player && dialog}` polling loops with `sleep` delays. Keep new work small inside those loops and reuse existing update flags.
- Several menu files return to `WF_Menu` by `closeDialog 0; createDialog "WF_Menu"` rather than maintaining a stack. Adding nested dialogs must preserve those return paths.

### Client Modal Loop Cadence

This cadence map is an index for performance triage, not a patch order. It separates dialog-only high-frequency loops from already-instrumented long-running UI/HUD/marker loops. Current Chernarus and maintained Vanilla share the same checked line refs for the `.01` and `.05` rows below.

| Cadence | Scope | Current-source anchors | Instrumentation state | Owner / next step |
| --- | --- | --- | --- | --- |
| `sleep .01` | Highest under-covered dialog-only cadence. Buy Gear, Transfer, Respawn and Upgrade menus poll menu action/state while the dialog is open. | `Client/GUI/GUI_BuyGearMenu.sqf:503`; `Client/GUI/GUI_TransferMenu.sqf:94`; `Client/GUI/GUI_RespawnMenu.sqf:113`; `Client/GUI/GUI_UpgradeMenu.sqf:282`. Maintained Vanilla has the same paths/lines. | No local `PerformanceAudit_Record` writer was found in those four controllers. | Add client-side measurement first, then consider dirty flags, event latches or coarser sleeps only after gear, transfer, respawn selector and upgrade-list smoke proves no UI regression. Route details through [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) and [Upgrades/research](Upgrades-And-Research-Atlas). |
| `sleep 0.05` | Commander vote, regular vote and team menu polling while visible. | `Client/GUI/GUI_VoteMenu.sqf:92`; `Client/GUI/GUI_Commander_VoteMenu.sqf:67`; `Client/GUI/GUI_Menu_Team.sqf:77`. Maintained Vanilla has the same paths/lines. | No local `PerformanceAudit_Record` writer was found in those controllers. | Lower priority than the `.01` modal loops. Keep vote refresh, row-color and reassignment smoke tied to [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook). |
| `sleep 0.1` | Standard main/menu controllers. | `Client/GUI/GUI_Menu.sqf:211`; `Client/GUI/GUI_Menu_BuyUnits.sqf:492`; `Client/GUI/GUI_Menu_Command.sqf:534`; `Client/GUI/GUI_Menu_Tactical.sqf:750`; `Client/GUI/GUI_Display_Parameters.sqf:20`; additional service/camera/economy/EASA menus follow the same broad modal pattern. | Mostly uninstrumented at controller level, but lower cadence and dialog-only. | Treat as owner-page context, not a first performance patch target. Avoid adding work inside these loops when routing new UI features. |
| `sleep .03` / `sleep 0.03` | Local marker animation / respawn selector visual refresh. | `Client/Functions/Client_UI_Respawn_Selector.sqf:20`; `Client/Functions/Client_MarkerAnim.sqf:33`. | No local audit writer in the checked helpers. | Visual-only active loops; smoke marker animation and respawn selection before changing cadence. |
| Long-running UI/HUD/marker loops | RHUD/action/title and map marker surfaces. | `Client/Client_UpdateRHUD.sqf:199-201,367-369`; `Client/FSM/updateavailableactions.fsm:237`; `Client/FSM/updatetownmarkers.sqf:119-134`. | Already has PerformanceAudit coverage on representative high-value paths. | Prefer collecting client RPT audit rows before touching cadence. Keep these routed through [Performance opportunity sweep](Performance-Opportunity-Sweep) and the [indicator surface matrix](#indicator-surface-matrix). |

### Branch-Only UI Theme Work

`origin/feat/wf-menu-ops-console` head `0767c0b5` is a branch-only UI reskin, not stable-master truth. It changes the palette/control layer in Chernarus and maintained Vanilla (`Rsc/Styles.hpp:10-40`, `Rsc/Ressources.hpp:117-131,274-277`), adds a chevron and footer to `WF_Menu` (`Rsc/Dialogs.hpp:1057-1064,1240-1249`), sets `PuristaBold` on the hub title (`Dialogs.hpp:1173-1179`) and sets `EtelkaMonospacePro` on RHUD numeric values (`Rsc/Titles.hpp:178-179`). Treat it as visual/theme evidence until Arma 2 OA smoke proves the fonts, texture path, contrast and both Chernarus/Vanilla menu surfaces.

Static caveat for the branch: `git diff --check origin/master..origin/feat/wf-menu-ops-console` currently reports trailing whitespace in `docs/superpowers/plans/2026-06-03-wf-menu-ops-console.md:78,179`. Clean that before merge even though it is not mission runtime code.

`origin/feat/buymenu-easa-qol` head `a66d4691` is the smaller UI QoL branch. It changes only three Chernarus client UI files: `Client_UIFillListBuyUnits.sqf:1,61-62,104` colors unaffordable displayed base prices red, `GUI_Menu_BuyUnits.sqf:201-210` appends live queue counts to factory tabs, `GUI_Menu_BuyUnits.sqf:280,335,388,444,487` touches selected-unit cost display and `GUI_Menu_EASA.sqf:29-40` colors/preselects the aircraft's current loadout. Treat this as low-blast-radius UI evidence, not merged behavior: maintained Vanilla is not changed on the branch, and Arma smoke still needs to confirm affordability color versus full/crew cost, queue-label refresh/no flicker, final price field and EASA current-loadout selection. See [BuyMenu EASA QoL branch audit](BuyMenu-EASA-QoL-Branch-Audit).

## Indicator Exploration Backlog

Steff asked to track "all indicators" as a future exploration lane. Initial source scan on 2026-06-06 shows this is not one feature; it is a family of visual/state surfaces that should be audited together before UI, UX or performance cleanup.

| Indicator family | Index state | Exact current-source anchors | Canonical owner / next step |
| --- | --- | --- | --- |
| HUD/title indicators | Partially indexed | `Rsc/Titles.hpp:44-47,126-132,164-173,532-540,723-729`; `Client/GUI/GUI_SetCurrentCutDisplay.sqf:1`; `Client/GUI/GUI_ClearCurrentCutDisplay.sqf:1`; `Client/Client_UpdateRHUD.sqf:7,89-92,199-201,367-369`; `Client/FSM/updateavailableactions.fsm:225-230`; `Client/FSM/client_title_capture.sqf:47-48,74-79`; `Client/GUI/GUI_EndOfGameStats.sqf:34-44,86-93`. | This page and [UI IDD collision repair](UI-IDD-Collision-Repair) already own the shared `currentCutDisplay` risk. Finish a surface/audience/cadence matrix for RHUD, FPS HUD, action icons, capture bar, end stats and CoIn placement feedback. |
| Map and tactical markers | Needs detailed matrix | `Client/Init/Init_Markers.sqf:22-24,45-48`; `Client/FSM/updatetownmarkers.sqf:20-21,29-30,106,116,129-134`; `Client/FSM/updateteamsmarkers.sqf:21-24,45-55,165-186,197-208,229`; `Common/Common_MarkerUpdate.sqf:49-57,67-88,98-109,195-209,218-241`; `Common/Common_AARadarMarkerUpdate.sqf:10-16,30-33,133,143,156,173,194,198`; `Client/GUI/GUI_Menu_Tactical.sqf:26-35,202-216,350-359,473-505,760-773`; `Client/GUI/GUI_RespawnMenu.sqf:73-82,194`. | Keep on this page. Build a marker inventory for towns, camps, teams, HQs, AARadar aircraft, artillery/ICBM/fast-travel rings, respawn selection and commander orders, with cleanup owner and update cadence. |
| Support and special markers | Partly canonical, still fragmented | `Server/Support/Support_Paratroopers.sqf:117`; `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:30-45`; `Server/Module/MASH/MASHMarker.sqf:1-11`; `Client/Module/MASH/receiverMASHmarker.sqf:1-27`; `Client/Functions/Client_FNC_Special.sqf:96-108`; `Client/Functions/Client_RequestFireMission.sqf:20-32,54-57,75`; `Client/GUI/GUI_Menu_Tactical.sqf:474-505,504-505`. | Route support-specific rows through [Support specials](Support-Specials-And-Tactical-Modules-Atlas) and [Abandoned feature revival](Abandoned-Feature-Revival-Review). Reconcile working paratrooper markers, orphan MASH relay, UAV spot markers, artillery markers and ICBM cleanup timing. |
| Menu/list icons and affordance indicators | Partially indexed | `Rsc/Dialogs.hpp:1171-1232,1525-1614,2110-2123,2372-2378,2638-2831,3463-3469`; `Rsc/Ressources.hpp:92,143,218,300-312,540-556`; `Client/GUI/GUI_Menu.sqf:29-35,47-57,101-170,191-207`; `Client/GUI/GUI_Menu_BuyUnits.sqf:84-90,165-176,237,495-496`; `Client/Functions/Client_UIFillListBuyUnits.sqf:34-62,68-90,105,107`; `Client/GUI/GUI_Menu_Tactical.sqf:42,64,104,654,660,760-773`. | Fast route is [Client UI, HUD and menus](Client-UI-HUD-And-Menus); detail stays here or in factory/gear owner pages. Audit factory tab icons, crew/lock icons, gear slots, upgrade images, affordability colors, queue labels and branch-only `feat/buymenu-easa-qol` affordances. |
| Status/debug/admin channels | Needs audience split | `Server/GUI/serverFpsGUI.sqf:7-8`; `Server/Module/serverFPS/monitorServerFPS.sqf:3-5`; `Client/Client_UpdateRHUD.sqf:113,199-201,367-369`; `Common/Functions/Common_PerformanceAudit.sqf:160,196,234`; `Client/Module/supplyMission/townSupplyStatus.sqf:1-8`; `Client/PVFunctions/Available.sqf:1`; `Client/FSM/updateclient.sqf:12-24,161-163,230-232`. | Route publicVariable/status-channel semantics through [Networking and public variables](Networking-And-Public-Variables) and performance counters through [Performance opportunity sweep](Performance-Opportunity-Sweep). Split player-facing, admin-only and developer-only outputs before pruning. |
| Image/resource references | Missing stale upgrade icon block verified | `Rsc/Ressources.hpp:300-304,312,540-556`; `Rsc/Dialogs.hpp:654,660,666,672,678,1566,1586,1593,1600,1607,1614,2123,2378,2644,2655,2666,2677,2688,2699,2710,2721,2732,2743,2754,2765,2776,2787,2798,2809,2820,2831,3469`; `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:105-108,111,125`. | [UI resource parity cleanup](UI-Resource-Parity-Cleanup) now owns the verified missing `RscMenu_Upgrade` `wf_*.paa` icon block in Chernarus and maintained Vanilla. Continue broader `Client\Images\*.paa/.jpg` integrity checks there, and keep the malformed `RscClickableText.soundPush[]` risk in the same cleanup lane. |

### Indicator Surface Matrix

This first matrix is a routing map, not a visual redesign. It keeps the broad indicator family inventory above source-backed while giving future UI owners the missing `surface`, `owner script`, `state source`, `audience`, `update cadence`, `cleanup path`, `known risk`, `branch scope` and `smoke target` fields.

| Surface | Owner script / resource | State source | Audience | Update cadence | Cleanup path | Known risk | Branch scope | Smoke target |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RHUD / FPS HUD and action icons | `Rsc/Titles.hpp:164-171`; `Client/GUI/GUI_SetCurrentCutDisplay.sqf:1`; `Client/GUI/GUI_ClearCurrentCutDisplay.sqf:1`; `Client/Client_UpdateRHUD.sqf:89-92,199-201,367-369`; `Client/FSM/updateavailableactions.fsm:225-230`. | `uiNamespace["currentCutDisplay"]`, `RUBHUD`, `RUBFPSHUD`, visible-map state, local action availability and performance-audit enablement. | Local player. | Long-running client HUD loop plus action FSM refresh. | `OptionsAvailable` `onUnload` clears the shared handle; `Client_UpdateRHUD.sqf:89-92` can recreate the title if the handle is null. | Shared `currentCutDisplay` handle also services endgame stats, so late-game title ownership can collide with RHUD/action recreation. | This page owns orientation; [UI IDD collision repair](UI-IDD-Collision-Repair) owns detailed title-ID/handle patch shape. | Join as player, toggle map/GPS, verify RHUD/FPS/action icons survive map transitions; end mission and confirm end stats are not replaced by `OptionsAvailable`. |
| Capture and endgame title bars | `Rsc/Titles.hpp:532-540,723-729`; `Client/FSM/client_title_capture.sqf:47-48,74-79`; `Client/GUI/GUI_EndOfGameStats.sqf:34-44,86-93,147`; `Client/Module/CoIn/coin_interface.sqf`. | Town/camp capture progress, endgame stat totals, CoIn placement state and the same title-display namespace helpers. | Local player / commander during build placement. | Event-driven cutRsc/title displays plus local FSM or interface loop writes. | Capture/endgame titles rely on title unload helpers; CoIn interface owns its placement display lifecycle. | Endgame stats and action/RHUD titles share the same namespace handle; CoIn placement feedback belongs with construction smoke rather than generic HUD cleanup. | Current maintained roots carry these title resources; release branch has the same shared-handle title risk. | Capture/lose a camp, place/cancel a CoIn object, and trigger endgame stats while RHUD is active. |
| Town, camp, team, HQ and tactical map markers | `Client/Init/Init_Markers.sqf:22-24,45-48`; `Client/FSM/updatetownmarkers.sqf:20-21,29-30,106,116,129-134`; `Client/FSM/updateteamsmarkers.sqf:21-24,45-55,165-186,197-208,229`; `Common/Common_MarkerUpdate.sqf:49-57,67-88,195-209,218-241`; `Client/GUI/GUI_Menu_Tactical.sqf:202-216,350-359,473-505,760-773`; `Client/GUI/GUI_RespawnMenu.sqf:73-82,194`. | Local marker arrays, town/camp side state, team/HQ/object positions, tactical selection variables and respawn selection state. | Local player; commander/tactical menu users see additional command surfaces. | Client marker FSMs poll cheaply while map/GPS is closed and force quicker full refresh when map or GPS opens. `Common_MarkerUpdate.sqf` loops at marker-specific refresh rates. | Marker scripts use local marker creation/update; tactical and respawn menus own their transient selection markers. | Map-open cadence and local marker ownership can hide stale-marker bugs unless map/GPS/JIP states are smoked separately. | Current Chernarus and maintained Vanilla carry the same marker loop topology; release changes should be treated as branch-specific until checked per marker family. | Join/JIP, open/close map and GPS, capture towns/camps, move teams/HQ, select respawn/fast travel, and check stale marker cleanup. |
| AARadar, artillery, ICBM, UAV, MASH and paratrooper markers | `Common/Common_AARadarMarkerUpdate.sqf:10-16,30-33,133,143,156,173,194,198`; `Server/Support/Support_Paratroopers.sqf:117`; `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:30-45`; `Server/Module/MASH/MASHMarker.sqf:1-11`; `Client/Module/MASH/receiverMASHmarker.sqf:1-27`; `Client/Functions/Client_FNC_Special.sqf:96-108`; `Client/Functions/Client_RequestFireMission.sqf:20-32,54-57,75`. | Server support calls, client PVF receivers, support request state, marked units/vehicles, side filters and local marker names. | Mostly local player/team/side; support markers may be side- or requester-visible depending on receiver path. | Event-driven marker creation plus client marker loops. | MarkerUpdate handles tracked-unit deletion paths; MASH and support receivers create/remove their own marker names. | Support marker families are fragmented across support, module and UI pages; paratrooper marker registration is branch-sensitive on older/current stable docs. | Current source has the paratrooper sender/receiver files but previous branch matrices still require registration/runtime smoke before calling revival complete; release evidence remains branch-scoped. | Drop paratroopers, request artillery/UAV/special support, deploy/remove MASH, use AARadar and verify side/audience plus stale-marker removal. |
| Menu/list icons, affordability colors and resource images | `Rsc/Dialogs.hpp:1171-1232,1525-1614,2110-2123,2372-2378,2638-2831,3463-3469`; `Rsc/Ressources.hpp:92,143,218,300-312,540-556`; `Client/GUI/GUI_Menu.sqf:29-35,47-57,101-170,191-207`; `Client/GUI/GUI_Menu_BuyUnits.sqf:84-90,165-176,237,495-496`; `Client/Functions/Client_UIFillListBuyUnits.sqf:34-62,68-90,105,107`. | Dialog IDC state, factory/unit configs, player funds, queue/build state, upgrade labels and `Client\Images\*.paa/.jpg` resources. | Local player using menus. | Dialog open/refresh loops and list-fill functions; buy-menu tabs refresh while the menu is open. | Dialog close controls clear UI state; resource cleanup belongs to [UI resource parity cleanup](UI-Resource-Parity-Cleanup). | Missing/stale image references and malformed `RscClickableText.soundPush[]` can break many menus at once; branch-only QoL icon/color changes are not current-source behavior. | Current `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, perf `0076040f` and release `a96fdda2` all keep the malformed clickable-text base-control value in both maintained roots. | Open main, buy units, gear, tactical, respawn and upgrade menus; verify icons load, unaffordable states are clear and no missing texture/config errors appear. |
| Status, debug, admin and performance counters | `Server/GUI/serverFpsGUI.sqf:7-8`; `Server/Module/serverFPS/monitorServerFPS.sqf:3-5`; `Client/Client_UpdateRHUD.sqf:199-201,367-369`; `Common/Functions/Common_PerformanceAudit.sqf:160,196,234`; `Client/Module/supplyMission/townSupplyStatus.sqf:1-8`; `Client/PVFunctions/Available.sqf:1`; `Client/FSM/updateclient.sqf:12-24,161-163,230-232`. | `diag_fps`, `SERVER_FPS_GUI`, `WFBE_VAR_SERVER_FPS`, performance-audit buffers, supply-status values and client update loop state. | Split between all clients, local player, admins/operators and RPT/tooling consumers. | FPS publisher loops, client update loop, supply-status events and performance-audit flush interval. | Performance audit flushes buffered local records; FPS/status channels stop only with script/runtime termination. | Player-facing indicators, admin status and developer-only RPT counters should not be pruned together; hosted/listen FPS loop behavior has separate release-gate smoke. | Current source/stable and release branch status must stay separated through [Performance opportunity sweep](Performance-Opportunity-Sweep) and [Testing workflow](Testing-Debugging-And-Release-Workflow). | Dedicated and hosted/listen FPS smoke, supply mission status smoke, and client/server RPT audit collection with the audit parameter enabled. |

Future indicator cleanup should start from this table: pick one row, verify the branch/root scope for that family, then update the canonical owner page instead of adding another broad "all indicators" checklist.

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

Current branch check 2026-06-14: `RscOverlay` and `OptionsAvailable` still both use `idd=10200` in both maintained roots across docs checkout `2fef1e3d` (`Titles.hpp:44-46`, `:164-165`), stable `origin/master` `cf2a6d6a` (`:44-46`, `:168-169`), Miksuu `b8389e74`, perf `0076040f` and release `a96fdda2`. No checked maintained root has a hard-coded `findDisplay 10200` caller, so treat this as title-resource maintenance/debug debt rather than a proven live lookup bug.

The more direct title lifecycle bug is independent of duplicate IDDs. `EndOfGameStats` has `idd=90000`, but it sets and clears `uiNamespace["currentCutDisplay"]` through the same `onLoad`/`onUnload` helpers as `OptionsAvailable` (`Titles.hpp:532-540` in docs/Miksuu/perf, `:580-588` in stable/release). `GUI_EndOfGameStats.sqf:13,34-44,86-93` cuts and writes stat bars through that key, while the RHUD loop keeps running and can re-cut `OptionsAvailable` when the shared key is null (`Client_UpdateRHUD.sqf:89-92,183-190` in docs/Miksuu/perf; `:89-92,251-258` in stable/release). All checked maintained roots keep this shared-handle shape; patch title work by splitting display ownership or by gating RHUD/action-icon recreation once endgame begins. Use [UI IDD collision repair](UI-IDD-Collision-Repair) for the patch checklist instead of duplicating it here.

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
| 19 | Branch-sensitive: docs checkout/Miksuu/perf toggle the FPS-only HUD; stable `origin/master` `cf2a6d6a` and release `a96fdda2` reuse this visible slot as the GPS enabler. |

Range booleans such as `barracksInRange`, `gearInRange`, `commandInRange` and `serviceInRange` are maintained by `Client/FSM/updateavailableactions.fsm`, not by the main menu itself.

Mini UI scout note 2026-06-04 plus branch recheck 2026-06-14: no live buy/gear/service/tactical/vote/unit-camera control was found with an outright missing handler. The important main-menu mismatch is narrower: `MenuAction == 17/18` remains in the router for GPS zoom in docs checkout, stable, release, Miksuu and perf maintained roots, but fixed-string action searches found no `MenuAction = 17` or `MenuAction = 18` emitter. `MenuAction = 19` is visible everywhere checked, but its meaning is branch-sensitive: FPS HUD in docs/Miksuu/perf and GPS enablement on stable/release.

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

`GUI_Menu_Command.sqf` owns team selection, AI team templates, behavior/combat/formation/speed combos, move/task controls and respawn factory choice. Current `origin/master` `cf2a6d6a` and release `a96fdda2` now carry the targeted Objective Ping path in both maintained roots: the menu gathers task data and HQ speech context at `GUI_Menu_Command.sqf:315-344`, then sends `SetTask` to the selected leader or side leaders at `:336,344`. Miksuu `b8389e74` still keeps those sends commented at `GUI_Menu_Command.sqf:335,337,343`. The old town `TaskSystem` remains disabled/residue in all checked roots (`Init_Client.sqf:75`, `:758-759`; `TownCaptured.sqf:35-36,87-88` depending on branch line drift).

Vote menu cleanup edge: `WFBE_Client_Teams_Count` is initialized as `count WFBE_Client_Teams` (`Init_Client.sqf:288` on current `origin/master`), but `GUI_Commander_VoteMenu.sqf:58-66` and `GUI_VoteMenu.sqf:29,61-66` use it as an inclusive `for ... to` maximum. Existing `isNil` guards make this mostly a refresh-loop polish bug rather than a proven crash, but vote UI changes should switch to `(WFBE_Client_Teams_Count - 1)` or `forEach`.

Vote behavior changes should start from [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook). That page owns the DR-47 server/UI outcome mismatch, the no-commander/tie decision matrix and the smoke cases that must accompany any `GUI_VoteMenu.sqf` preview change.

Vote row coloring has a second small indexing edge. In `GUI_VoteMenu.sqf:74-83`, the loop variable already tracks the list row while scanning `lnbSize`, but the color write uses `[_i+1,0]`. If touching vote refresh, audit both the backing team-array loop and this row-color mapping together.

Commander reassignment has a separate selector fragility. `GUI_Commander_VoteMenu.sqf:33-46` reads the selected row text, then finds the target team by comparing `name leader _x`. Because the row already stores the team index with `lnbSetValue`, future fixes should use the stored value instead of visible names so duplicate names or mid-dialog name changes cannot select the wrong commander. Keep this UI fix aligned with [Commander reassignment call shape](Commander-Reassignment-Call-Shape) and [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook).

Help dialog lifecycle edge: `RscMenu_Help` stores the display as `uiNamespace["dialog_HelpPanel"]` on load, but unload clears `uiNamespace["cti_dialog_ui_onlinehelpmenu"]` and calls `GUI_Menu_Help.sqf` with `onUnload` (`Rsc/Dialogs.hpp:3133-3134` on current `origin/master`; release `a96fdda2` uses `:3108-3109`). The controller only implements `onLoad` and `onHelpLBSelChanged` (`GUI_Menu_Help.sqf:5-10`). This looks like stale namespace wiring, so avoid building new help-panel state on the old unload variable without cleaning it.

Main-menu orphan route: docs checkout `a71b42fe` still handles `MenuAction == 17/18` for GPS zoom at `GUI_Menu.sqf:202,206`, while the audited `WF_Menu` resource block exposes actions `1-13`, `16` and `19` only (`Rsc/Dialogs.hpp:1226` emits `MenuAction = 19`). Stable `origin/master` `cf2a6d6a` keeps the same handler-only zoom routes at `GUI_Menu.sqf:243,247` but reuses the visible `MenuAction = 19` control as GPS enablement (`Rsc/Dialogs.hpp:1252`; `GUI_Menu.sqf:214`). Miksuu `b8389e74` and perf `0076040f` keep the docs-checkout FPS-HUD meaning for visible action `19`; release `a96fdda2` matches the stable GPS action shape with Chernarus/Vanilla line drift. Treat the old zoom router cases as dead UX baggage unless a hidden/branch control is deliberately reintroduced and smoke-tested.

### Vote, Help And Main-Menu Branch Matrix

This route owns the small UI correctness cluster around vote refresh/list coloring, help-panel lifecycle state and the main-menu GPS zoom router. The WASP marker input-lock wait is adjacent UX debt, but its branch matrix stays on [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup).

| Root / branch | Vote refresh and row color | Help menu lifecycle | Main-menu `17/18/19` route | Status |
| --- | --- | --- | --- | --- |
| Docs checkout `a71b42fe` | Both maintained roots set `WFBE_Client_Teams_Count = count WFBE_Client_Teams` at `Init_Client.sqf:273`; `GUI_VoteMenu.sqf:29,49,61` and `GUI_Commander_VoteMenu.sqf:58` loop through that inclusive value. | Both maintained roots set `dialog_HelpPanel` and clear `cti_dialog_ui_onlinehelpmenu` at `Rsc/Dialogs.hpp:3446-3447`; `GUI_Menu_Help.sqf:5-10` handles load and selection, not unload. | Both roots keep handler-only `MenuAction == 17/18` zoom at `GUI_Menu.sqf:202,206`; visible `MenuAction = 19` is `CA_FPSHUD_Button` at `Rsc/Dialogs.hpp:1219-1227` and toggles `RUBFPSHUD` at `GUI_Menu.sqf:197`. | Patch-ready UI cleanup; source unchanged from the earlier `f7bc72a8` atlas snapshot for these paths. |
| Current `origin/master` `cf2a6d6a` | Both maintained roots set `WFBE_Client_Teams_Count = count WFBE_Client_Teams` at `Init_Client.sqf:288`; `GUI_VoteMenu.sqf:29,49,61` and `GUI_Commander_VoteMenu.sqf:58` loop through that inclusive value. | Both maintained roots set `dialog_HelpPanel` and clear `cti_dialog_ui_onlinehelpmenu` at `Rsc/Dialogs.hpp:3133-3134`; `GUI_Menu_Help.sqf:5-10` handles load and selection, not unload. | Both maintained roots keep `MenuAction == 17/18` handlers at `GUI_Menu.sqf:243,247`; visible `MenuAction = 19` is `CA_GPS_Button` at `Rsc/Dialogs.hpp:1244-1253` and GPS enablement at `GUI_Menu.sqf:214`. | Stable changes the visible action-19 meaning, but vote/help and old zoom-router cleanup remain open. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Same inclusive vote-loop shape; perf Chernarus line refs still use `Init_Client.sqf:285`, and Miksuu keeps older UI line drift. | Same help namespace mismatch. | Same handler-only `17/18` route as docs checkout; visible `MenuAction = 19` remains `CA_FPSHUD_Button` / FPS HUD in both maintained roots. | No upstream/perf rescue for this UI cluster. |
| Release `origin/release/2026-06-feature-bundle` `a96fdda2` | Same vote shapes in both maintained roots at `Init_Client.sqf:288`, `GUI_VoteMenu.sqf:29,49,61` and `GUI_Commander_VoteMenu.sqf:58`. | Same mismatch in both maintained roots at `Rsc/Dialogs.hpp:3108-3109`. | Release exposes `CA_GPS_Button` / `MenuAction = 19` at `Rsc/Dialogs.hpp:1231-1240`, but the old `17/18` handlers remain at `GUI_Menu.sqf:243,247` in Chernarus and `:235,239` in Vanilla. | Release matches stable GPS visibility but does not rescue vote/help or old zoom-router cleanup. |

Patch order:

1. Fix vote loops with `count - 1` or `forEach`, and correct the row-color target so highlighted rows match the candidate rows.
2. Use one help-display namespace key and either implement a real `onUnload` branch or remove the stale controller call.
3. Decide whether GPS zoom should be visible again. If not, remove or comment the dead `17/18` router cases; if yes, add controls deliberately and smoke HUD/GPS state.
4. Propagate maintained Vanilla and smoke vote refresh/list coloring, help open/close and main-menu HUD/FPS/GPS behavior together.

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

| Route | Local evidence kept here | Canonical owner / action |
| --- | --- | --- |
| Resource, IDD and image cleanup | EASA/Economy IDD overlap, stale `RscMenu_Upgrade`, shared title IDDs, Economy missing-control writes and `RscClickableText.soundPush[]` all start in `Rsc/*.hpp`. | [UI resource parity cleanup](UI-Resource-Parity-Cleanup), [UI IDD collision repair](UI-IDD-Collision-Repair), and this page's [clickable-text matrix](#clickable-text-soundpush-branch-matrix). |
| Title display ownership | `OptionsAvailable` and `EndOfGameStats` both use the `currentCutDisplay` helper path, while RHUD/action recovery can recreate `OptionsAvailable`. | Keep orientation in [HUD Display Ownership](#hud-display-ownership); patch details belong in [UI IDD collision repair](UI-IDD-Collision-Repair). |
| Controller cadence and marker loops | Modal `.01` / `.05` loops, RHUD/action loops and marker loops are indexed above with representative anchors. | Use [Client modal loop cadence](#client-modal-loop-cadence), [Indicator Surface Matrix](#indicator-surface-matrix) and [Performance opportunity sweep](Performance-Opportunity-Sweep); collect RPT/audit evidence before cadence edits. |
| Vote, help and main-menu router cleanup | Vote inclusive loops, help unload namespace mismatch and old GPS zoom handlers are branch-checked in the matrix above. | Keep small UI patch scope here and route commander outcome semantics through [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook). |
| Objective Ping versus old town tasks | Current `origin/master` / release send `SetTask` at `GUI_Menu_Command.sqf:336,344`; Miksuu still comments those sends; old town `TaskSystem` remains commented in all checked roots. | Treat Objective Ping as source-present / smoke-pending. Keep old town-task revival separate and JIP/task-spam gated. |
| Buy Units UI and authority | `RscMenu_BuyUnits` drives local `GUI_Menu_BuyUnits.sqf` / `Client_BuildUnit.sqf`; no `RequestBuyUnit` PVF exists. | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) owns price/key, queue, refund and authority detail. |
| Gear, cargo, EASA and service partials | Gear target/content TODOs, profile `_u_upgrade`, vehicle cargo loop bounds, service/EASA affordability and UI-originated spend all sit outside the generic UI stack. | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), and [Service menu affordability guards](Service-Menu-Affordability-Guards). |
| Tactical fast travel | Fee mode hides unaffordable towns, draws marker-price text and debits locally on travel click. | Keep branch status in [Tactical Fast-Travel Fee Branch Matrix](#tactical-fast-travel-fee-branch-matrix); do not mix with `RequestSpecial` authority hardening. |
| Support and special indicators | Paratrooper, MASH, UAV, artillery, ICBM and AARadar marker anchors are listed in the indicator matrix. | [Support specials and tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Abandoned feature revival](Abandoned-Feature-Revival-Review), and [Networking and public variables](Networking-And-Public-Variables) own feature-specific PV/JIP behavior. |
| WASP marker wait/input lock | `WASP/global_marking_monitor.sqf:57-73` still disables input and polls display 54 without a sleep/backoff before final unlock. | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) owns the tiny patch and smoke route. |

### Tactical Fast-Travel Fee Branch Matrix

Fast travel is a local Tactical menu flow, not a `RequestSpecial` server asset path. The menu reads `WFBE_C_GAMEPLAY_FAST_TRAVEL` and fast-travel range constants at `GUI_Menu_Tactical.sqf:22-23`; the current `origin/master` constant default is `1` free, with `2` meaning fee mode (`Common/Init/Init_CommonConstants.sqf:235,244-247`; Miksuu line drift is `:218,227-230`, release line drift is `:231,240-243`). In fee mode, the destination refresh calculates `_fee` from distance and `WFBE_C_GAMEPLAY_FAST_TRAVEL_PRICE_KM`, hides towns the player cannot afford, draws a marker-text price, and later debits locally when the player clicks the travel destination (`GUI_Menu_Tactical.sqf:188,196,404-405` on current `origin/master`; Miksuu and release keep the same shape). The old `:146-147` TODO in older line maps is therefore stale policy/UX debt, not proof that fast travel is absent.

| Root / branch | Fee-mode destination list | Debit / prompt shape | Status |
| --- | --- | --- | --- |
| Current `origin/master` `cf2a6d6a` | Both maintained roots hide unaffordable town destinations and draw marker text with `$fee` (`GUI_Menu_Tactical.sqf:188-217`). | Both maintained roots recalculate and locally call `ChangePlayerFunds` at `:404-405`; no confirmation prompt or second affordability recheck is present. | Docs-ready owner-decision cleanup. |
| Miksuu `b8389e74`, perf `0076040f` and release `a96fdda2` | Same maintained-root behavior with branch line drift; Miksuu constants sit at `Init_CommonConstants.sqf:218,227-230`, release constants at `:231,240-243`. | Same local debit shape; Miksuu has adjacent `_currentFee` debits at `:469,514,525`, while current/release line drift is `:470,515,526`. | No checked branch rescues the fee-mode UX/policy debt. |

Practical patch rule: keep this separate from `RequestSpecial` authority hardening. First decide the user-facing policy: hide unaffordable destinations as today, show them disabled with a reason, or allow selection but block with a hint. If fee mode stays paid, add a final local funds/context recheck immediately before the debit and consider a confirmation prompt for long-distance travel. Smoke `WFBE_C_GAMEPLAY_FAST_TRAVEL` modes `0/1/2`, insufficient/exact/sufficient funds, HQ/town/command-center start points, non-friendly towns, maximum range, vehicle/group teleport, death during travel and maintained Vanilla parity.

### Clickable Text SoundPush Branch Matrix

`RscClickableText` is a base UI resource class. Every checked maintained root still defines `class RscClickableText` at `Rsc/Ressources.hpp:541` and the malformed `soundPush[] = {, 0.2, 1};` at `:556`; the same file shows the valid empty-sound precedent `{"", 0.2, 1}` at `:92`. The blast radius is branch-sensitive because `Rsc/Dialogs.hpp` derives 17 controls from it in docs/source, upstream, perf and UI theme branches, while current `origin/master` and release now derive 14 controls after menu/dialog drift.

| Root / branch | `RscClickableText.soundPush[]` | Derived clickable controls | Status |
| --- | --- | --- | --- |
| Docs checkout `a71b42fe` Chernarus + maintained Vanilla | `Rsc/Ressources.hpp:556` keeps `{, 0.2, 1}` in both maintained roots; `:92` shows valid `{"", 0.2, 1}` precedent. Source unchanged from the earlier `f7bc72a8` matrix snapshot for checked UI paths. | 17 `: RscClickableText` controls in each `Rsc/Dialogs.hpp` root, including gear slots, WF menu toggles, construction/CoIn, artillery and economy controls. | Patch-ready, docs/source-unpatched; propagate Vanilla with any source edit. |
| Current stable `origin/master` (`cf2a6d6a`) Chernarus + maintained Vanilla | Same malformed base-class value in both maintained roots. The `89ae9dad..cf2a6d6a` diff touches `Rsc/Dialogs.hpp` but not checked `Rsc/Ressources.hpp`. | 14 derived controls in each maintained root at `Rsc/Dialogs.hpp:670,710,742,817,868,1194,1204,1214,1562,1617,2147,2409,2789,3094`. | No current-master rescue; base config still needs a source patch. |
| Miksuu upstream `miksuu/master` (`b8389e74`) | Same malformed base-class value in both maintained roots. | 17 derived controls in both maintained roots, with line drift from docs/source. | No upstream rescue. |
| `origin/perf/quick-wins` (`0076040f`) | Same malformed base-class value in both maintained roots. | 17 derived controls in both maintained roots. | Perf branch does not touch this UI config. |
| Release `origin/release/2026-06-feature-bundle` (`a96fdda2`) | Same malformed base-class value in both maintained roots; `7ff18c49..a96fdda2` does not touch checked `Rsc/Ressources.hpp`. | 14 derived controls in each maintained release root at `Rsc/Dialogs.hpp:657,697,729,804,855,1181,1191,1201,1537,1592,2122,2384,2764,3069`. | Release branch does not rescue the base config. |
| UI theme branches `origin/feat/wf-menu-ops-console` (`0767c0b5`) and `origin/feat/wf-menu-ux-phase1` (`87d86257`) | Same malformed base-class value in both maintained roots. | 17 derived controls in both maintained roots. | Theme branches still need config smoke before promotion. |

Practical patch rule: change only the base-class array to a valid value first, preferably the local empty-sound precedent `{"", 0.2, 1}` unless a code owner wants a real click sound. Propagate maintained Vanilla deliberately, then run an Arma 2 OA dialog smoke that opens representative inheritors from gear, WF menu/HUD toggles, construction/CoIn, artillery and economy; treat modded mission copies as unsupported until their broader conflict/generation blockers are resolved.

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
