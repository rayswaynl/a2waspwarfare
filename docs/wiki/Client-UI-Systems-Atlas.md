# Client UI Systems Atlas

This page maps the client-facing UI layer from source: `description.ext`, `Rsc/*.hpp`, `Client/GUI`, client FSM loops, map marker scripts, HUD/title resources and WASP overlays. For a player-facing workflow tour before diving into implementation, use [Player UI workflow map](Player-UI-Workflow-Map); for a compact quick reference, use [Client UI, HUD and menus](Client-UI-HUD-And-Menus).

All paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

Unless a row names another ref, source anchors below are valid for docs head `docs/developer-wiki-index` `68bd4dc5`. Rechecked 2026-06-14: targeted source diffs from `a03a1fb5` and `b5219d47` to `HEAD` over checked Chernarus and maintained Vanilla UI/Rsc paths return no changes, preserving the earlier `a71b42fe`, `2fef1e3d` and `f7bc72a8` source-anchor snapshots. The vote/help/main-menu matrix was separately refreshed on 2026-06-22 at docs head `087152f5`; checked vote/help/router paths are unchanged from `68bd4dc5`. The stale old upgrade dialog route was refreshed on 2026-06-23 at docs head `0fdd5602`; checked upgrade dialog/controller paths are unchanged from `d4cfef80`, while current stable `0139a346`, B69 `8d465fce` and B74 `b23f557f` have no maintained-root stale `RscMenu_Upgrade` hits. The duplicate-IDD route was refreshed on 2026-06-23 at docs head `edbd341e`; checked Dialogs/Titles IDD paths are unchanged from `b5219d47`. Stable `origin/master` `0139a346`, B69 `8d465fce`, B74 `b23f557f`, historical release `a96fdda2`, Miksuu `b8389e748243` and `origin/perf/quick-wins` `0076040f` differ by UI surface.

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

## Current Branch Scope

Use this table before turning a UI atlas line ref into a branch claim. Detailed matrices stay in the owner sections and linked pages; this table is only the route map.

| Ref | UI source shape | Practical route |
| --- | --- | --- |
| Docs head `edbd341e` for duplicate-IDD routing, `0fdd5602` for stale-upgrade dialog and `68bd4dc5` for broader UI anchors | Checked Chernarus and maintained Vanilla UI/Rsc paths are unchanged from `a03a1fb5`, `b5219d47` and the older `a71b42fe`, `2fef1e3d` and `f7bc72a8` atlas/resource snapshots; the stale-upgrade checked paths are also unchanged from `d4cfef80`. That archived docs/source shape still has visible `MenuAction = 19` as FPS HUD, handler-only `17/18` GPS zoom routes, stale `RscMenu_Upgrade` at `Rsc/Dialogs.hpp:2425,2428`, Economy/EASA dialog-resource drift, duplicate title `10200`, shared `currentCutDisplay` title ownership and malformed `RscClickableText.soundPush[]`. | Use this page for orientation and current docs-source line refs; use [UI resource parity cleanup](UI-Resource-Parity-Cleanup), [UI IDD collision repair](UI-IDD-Collision-Repair), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) and the clickable-text matrix before making patch-ready claims. Current stable `origin/master@0139a346`, B69 `8d465fce` and B74 `b23f557f` remove the stale old upgrade class and split EASA to `idd = 24000`; current stable also fixes the clickable-text base config. Title IDD/handle, vote/help/router and other branch-scoped UI work remain open. |
| Stable `origin/master` `0139a346` | Both maintained roots remove stale `RscMenu_Upgrade`, split EASA to `idd = 24000`, rewrite Economy around the current dashboard controls, expose visible action `19` as GPS enablement and now carry valid `RscClickableText.soundPush[] = {"", 0.2, 1};` at `Rsc/Ressources.hpp:556`. They still keep vote/help cleanup debt, handler-only `17/18` GPS zoom routes, duplicate title IDD and shared `currentCutDisplay` title ownership. | Treat stable as source-present for resource parity and clickable-text base config only; do not import that status into archived docs/Miksuu/perf/release refs. Title and vote/help/router work remain open, and clickable-text still needs Arma 2 OA dialog smoke before release-validated wording. |
| Trello artillery UI/UX candidates `origin/claude/trello-arty-cooldown-hud@471fc0580fd6`, `origin/claude/trello-arty-to-gunner@2dc3e7403399` and draft PR #79 `origin/claude/trello-artillery-ux@c4459d4312ef` | All three branches merge-base directly on current stable `origin/master@f8a76de34`. The cooldown branch adds the RHUD artillery row in both maintained roots (`Client_UpdateRHUD.sqf:27,259,452`; `Rsc/Titles.hpp:177,478-490`). The crew branch adds Tactical button idc `17040`, `MenuAction == 50` and the `STR_WF_TACTICAL_CrewArtillery*` keys in both roots (`GUI_Menu_Tactical.sqf:571-626`; `Rsc/Dialogs.hpp:2364-2371`; `stringtable.xml:3192-3213`). PR #79 changes the Tactical artillery list itself in both roots (`GUI_Menu_Tactical.sqf:42-57`) so rows show effective min/max range text, then updates the fire-mission warning/marker cleanup path (`Client_RequestFireMission.sqf:31-38,58-60`; `Server_HandleSpecial.sqf` Chernarus `:144-160` / Vanilla `:134-150`; `stringtable.xml` Chernarus `:9304-9311` / Vanilla `:9304-9310`). Current stable has no `RUBHUD_Arty`, no exact `if (MenuAction == 50)` tactical action, no crew-artillery string keys, no range-suffixed artillery list rows, no third gun-count placeholder and no `ArtyMarkerCleanup` tag. | Branch-only UI/UX candidates; route behavior through [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas#trello-artillery-ui-branch-intel), promotion through [Feature status](Feature-Status-Register#partial--deferred--needs-review) and smoke through [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack). PR #79 also adds a server `RequestSpecial` marker-cleanup tag, so keep marker deletion authority review with support/networking owners before stable wording. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Checked maintained roots keep the docs/source-style stale upgrade/Economy/EASA resource shape, visible action `19` as FPS HUD, handler-only `17/18` GPS zoom routes, malformed clickable-text base config and title-handle risks. | Recheck exact lines before merge wording. These refs do not rescue the UI resource, title, vote/help/router or clickable-text cleanup lanes. |
| Trello upgrade/HQ cost info candidate `origin/claude/trello-upgrade-hqcost-info@34fd202c8865` / draft PR #75 | Branch merge-base is current stable `origin/master@f8a76de34`; payload is six maintained-root files / +96 and `git diff --check` clean. In both source Chernarus and maintained Vanilla, `Client_FNC_Special.sqf:204,212-223` keeps the existing upgrade-complete command chat and adds extra scalar lines only for `WFBE_UP_ARTYTIMEOUT` and `WFBE_UP_RESPAWNRANGE`; `GUI_TransferMenu.sqf:124-129` appends `STR_WF_INFO_NewHQCost` from `WFBE_C_STRUCTURES_HQ_COST_DEPLOY`; `stringtable.xml:459-473,1055-1061` adds the new string keys. Current stable has the existing generic upgrade-complete chat at `Client_FNC_Special.sqf:204` and transfer footer at `GUI_TransferMenu.sqf:124-125`, but no new value-message or New HQ cost string keys. | Branch-only UI/info-text candidate; route upgrade semantics through [Upgrades and research](Upgrades-And-Research-Atlas#current-branch-scope), HQ deploy-cost ownership through [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas#current-branch-scope), promotion through [Feature status](Feature-Status-Register#partial--deferred--needs-review) and smoke through [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack). |
| Trello upgrade-icons candidate `origin/claude/trello-upgrade-icons@baf8d9c304ad` / draft PR #77 | Branch merge-base is current stable `origin/master@f8a76de34`; payload is two maintained-root `Client/GUI/GUI_UpgradeMenu.sqf` files / +8 and `git diff --check` clean. In source Chernarus plus maintained Vanilla, the branch keeps the existing `_upgrade_images` missionNamespace read at `GUI_UpgradeMenu.sqf:12`, then paints non-empty upgrade images into listbox `504001` column `0` at `:27-28` during initial fill and `:173-174` after refresh/reordering. Existing image paths come from `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:104-125`; current stable reads the same image array for the selected detail pane but has no maintained-root `lnbSetPicture` call in `GUI_UpgradeMenu.sqf`. Bohemia's [`lnbSetPicture`](https://community.bistudio.com/wiki/lnbSetPicture) command documentation describes the command as setting a picture at a ListNBox row/column item. | Branch-only upgrade-list visual candidate; route upgrade config semantics through [Upgrades and research](Upgrades-And-Research-Atlas#current-branch-scope), promotion through [Feature status](Feature-Status-Register#partial--deferred--needs-review) and smoke through [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack). Do not treat it as new image assets, localization, upgrade authority, stale `RscMenu_Upgrade` cleanup or current stable behavior. |
| Trello map radius circles candidate `origin/claude/trello-map-radius-circles@77dd71ba3` / draft PR #78 | Branch merge-base is current stable `origin/master@f8a76de34`; payload is six maintained-root files / +192 and `git diff --check` clean. In both source Chernarus and maintained Vanilla, `Init_BaseStructure.sqf` adds a second local `HQBuildRange*` border ellipse on the HQ/UAV terminal using `WFBE_C_BASE_AREA_RANGE + WFBE_C_BASE_HQ_BUILD_RANGE` (Chernarus `:54-65`, cleanup `:153-158`; Vanilla `:35-46`, cleanup `:134-139`). The branch also launches `Client_AmbulanceRedeployCircles.sqf` from `Init_Client.sqf:1227`; that watcher gates on `WFBE_C_RESPAWN_MOBILE`, combines `WFBE_%1AMBULANCES` and `WFBE_%1REDEPLOYTRUCKS` (`:12-18`), sizes yellow local ellipses from `WFBE_C_RESPAWN_RANGES` / `WFBE_UP_RESPAWNRANGE` (`:30-35`) and updates/removes them at `:57-68`. Current stable has the existing `CCrange*` ellipse but no `HQBuildRange`, `AmbRange_` or launcher hits. | Branch-only map-indicator candidate; route HQ radius ownership through [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas#current-branch-scope), mobile-spawn behavior through [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#branch-intel---mobile-respawn-map-circles) and the redeploy-truck eligibility caveat through [Medic redeployment truck](Medic-Redeployment-Truck-Forward-Spawn#branch-intel---map-radius-circle-candidate). Smoke through [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack). |

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
- UI resource parity cleanup owns the branch/root matrix for the stale old upgrade dialog, Economy missing-control writes and duplicate IDDs. Short version after the 2026-06-23 UI resource refreshes: docs/source, current Miksuu and perf keep the old dialog class, stale Economy-control writes and EASA/Economy duplicate `23000`; current stable `origin/master@0139a346`, B69 `8d465fce`, B74 `b23f557f` and historical release `a96fdda2` split EASA to `24000` and keep Economy on `23000`. Current stable/B69/B74/release still leave `RscOverlay`/`OptionsAvailable` duplicated on `idd = 10200` and sharing the `currentCutDisplay` title-handle path. Use [UI resource parity cleanup](UI-Resource-Parity-Cleanup) before changing these rows, then [UI IDD collision repair](UI-IDD-Collision-Repair) for duplicate-IDD and title-handle patch details.
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

This atlas only keeps the routing facts for branch-only UI work. Full evidence, owner decisions and smoke gates live on the branch-review pages below.

| Branch | Atlas-level verdict | Owner route |
| --- | --- | --- |
| `origin/feat/wf-menu-ops-console` `0767c0b5` | Branch-only UI theme evidence, not stable-master truth. Chernarus and maintained Vanilla both change Rsc/GUI/HUD theme surfaces; visual smoke, font/texture validation, Chernarus/Vanilla parity and branch whitespace cleanup remain required. | [Feature status](Feature-Status-Register#partial--deferred--needs-review), [Pending owner decisions](Pending-Owner-Decisions#branch-only-feature-promotion-decisions), [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) |
| `origin/feat/buymenu-easa-qol` `a66d4691` | Narrow Chernarus-only UI QoL branch. It is useful Buy Units/EASA evidence, but not merged behavior and not maintained Vanilla truth until propagated and smoked. | [BuyMenu EASA QoL branch audit](BuyMenu-EASA-QoL-Branch-Audit), [Feature status](Feature-Status-Register#partial--deferred--needs-review), [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) |

## Indicator Exploration Backlog

Steff asked to track "all indicators" as a future exploration lane. Initial source scan on 2026-06-06 shows this is not one feature; it is a family of visual/state surfaces that should be audited together before UI, UX or performance cleanup.

| Indicator family | Index state | Exact current-source anchors | Canonical owner / next step |
| --- | --- | --- | --- |
| HUD/title indicators | Partially indexed | `Rsc/Titles.hpp:44-47,126-132,164-173,532-540,723-729`; `Client/GUI/GUI_SetCurrentCutDisplay.sqf:1`; `Client/GUI/GUI_ClearCurrentCutDisplay.sqf:1`; `Client/Client_UpdateRHUD.sqf:7,89-92,199-201,367-369`; `Client/FSM/updateavailableactions.fsm:225-230`; `Client/FSM/client_title_capture.sqf:47-48,74-79`; `Client/GUI/GUI_EndOfGameStats.sqf:34-44,86-93`. | This page and [UI IDD collision repair](UI-IDD-Collision-Repair) already own the shared `currentCutDisplay` risk. Finish a surface/audience/cadence matrix for RHUD, FPS HUD, action icons, capture bar, end stats and CoIn placement feedback. |
| Map and tactical markers | Needs detailed matrix | `Client/Init/Init_Markers.sqf:22-24,45-48`; `Client/FSM/updatetownmarkers.sqf:20-21,29-30,106,116,129-134`; `Client/FSM/updateteamsmarkers.sqf:21-24,45-55,165-186,197-208,229`; `Common/Common_MarkerUpdate.sqf:49-57,67-88,98-109,195-209,218-241`; `Common/Common_AARadarMarkerUpdate.sqf:10-16,30-33,133,143,156,173,194,198`; `Client/GUI/GUI_Menu_Tactical.sqf:26-35,202-216,350-359,473-505,760-773`; `Client/GUI/GUI_RespawnMenu.sqf:73-82,194`. | Keep on this page. Build a marker inventory for towns, camps, teams, HQs, AARadar aircraft, artillery/ICBM/fast-travel rings, respawn selection and commander orders, with cleanup owner and update cadence. |
| Support and special markers | Partly canonical, still fragmented | `Server/Support/Support_Paratroopers.sqf:117`; `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:30-45`; `Server/Module/MASH/MASHMarker.sqf:1-11`; `Client/Module/MASH/receiverMASHmarker.sqf:1-27`; `Client/Functions/Client_FNC_Special.sqf:96-108`; `Client/Functions/Client_RequestFireMission.sqf:20-32,54-57,75`; `Client/GUI/GUI_Menu_Tactical.sqf:474-505,504-505`. | Route support-specific rows through [Support specials](Support-Specials-And-Tactical-Modules-Atlas) and [Abandoned feature revival](Abandoned-Feature-Revival-Review). Reconcile working paratrooper markers, orphan MASH relay, UAV spot markers, artillery markers and ICBM cleanup timing. |
| Menu/list icons and affordance indicators | Partially indexed | `Rsc/Dialogs.hpp:1171-1232,1525-1614,2110-2123,2372-2378,2638-2831,3463-3469`; `Rsc/Ressources.hpp:92,143,218,300-312,540-556`; `Client/GUI/GUI_Menu.sqf:29-35,47-57,101-170,191-207`; `Client/GUI/GUI_Menu_BuyUnits.sqf:84-90,165-176,237,495-496`; `Client/Functions/Client_UIFillListBuyUnits.sqf:34-62,68-90,105,107`; `Client/GUI/GUI_Menu_Tactical.sqf:42,64,104,654,660,760-773`. | Fast route is [Client UI, HUD and menus](Client-UI-HUD-And-Menus); detail stays here or in factory/gear owner pages. Audit factory tab icons, crew/lock icons, gear slots, upgrade images, affordability colors, queue labels and branch-only `feat/buymenu-easa-qol` affordances. |
| Status/debug/admin channels | Audience split seeded / branch scope refreshed | Current docs head `a27086cd`: `Server/GUI/serverFpsGUI.sqf:1,6-7`; `Server/Module/serverFPS/monitorServerFPS.sqf:1,5-6`; `Client/Client_UpdateRHUD.sqf:113,199-201,367-369`; `Common/Functions/Common_PerformanceAudit.sqf:84,160,196,234`; `Client/Module/supplyMission/townSupplyStatus.sqf:1-8`; `Client/PVFunctions/Available.sqf:1`; `Client/FSM/updateclient.sqf:12-24,161-163,230-232`. | Player HUD FPS uses `SERVER_FPS_GUI`; `WFBE_VAR_SERVER_FPS` is a compatibility/public-variable status channel in docs-source; PerformanceAudit is RPT/tooling output; supply/status scripts are transient player/admin signals. Route PV semantics through [Networking and public variables](Networking-And-Public-Variables) and FPS/runtime cleanup through [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) plus [Performance opportunity sweep](Performance-Opportunity-Sweep). |
| Image/resource references | Missing stale upgrade icon block verified | `Rsc/Ressources.hpp:300-304,312,540-556`; `Rsc/Dialogs.hpp:654,660,666,672,678,1566,1586,1593,1600,1607,1614,2123,2378,2644,2655,2666,2677,2688,2699,2710,2721,2732,2743,2754,2765,2776,2787,2798,2809,2820,2831,3469`; `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:105-108,111,125`. | [UI resource parity cleanup](UI-Resource-Parity-Cleanup) now owns the verified missing `RscMenu_Upgrade` `wf_*.paa` icon block in Chernarus and maintained Vanilla. Continue broader `Client\Images\*.paa/.jpg` integrity checks there, and keep the malformed `RscClickableText.soundPush[]` risk in the same cleanup lane. |

### Indicator Surface Matrix

This first matrix is a routing map, not a visual redesign. It keeps the broad indicator family inventory above source-backed while giving future UI owners the missing `surface`, `owner script`, `state source`, `audience`, `update cadence`, `cleanup path`, `known risk`, `branch scope` and `smoke target` fields.

| Surface | Owner script / resource | State source | Audience | Update cadence | Cleanup path | Known risk | Branch scope | Smoke target |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RHUD / FPS HUD and action icons | `Rsc/Titles.hpp:164-171`; `Client/GUI/GUI_SetCurrentCutDisplay.sqf:1`; `Client/GUI/GUI_ClearCurrentCutDisplay.sqf:1`; `Client/Client_UpdateRHUD.sqf:89-92,199-201,367-369`; `Client/FSM/updateavailableactions.fsm:225-230`. | `uiNamespace["currentCutDisplay"]`, `RUBHUD`, `RUBFPSHUD`, visible-map state, local action availability and performance-audit enablement. | Local player. | Long-running client HUD loop plus action FSM refresh. | `OptionsAvailable` `onUnload` clears the shared handle; `Client_UpdateRHUD.sqf:89-92` can recreate the title if the handle is null. | Shared `currentCutDisplay` handle also services endgame stats, so late-game title ownership can collide with RHUD/action recreation. | This page owns orientation; [UI IDD collision repair](UI-IDD-Collision-Repair) owns detailed title-ID/handle patch shape. | Join as player, toggle map/GPS, verify RHUD/FPS/action icons survive map transitions; end mission and confirm end stats are not replaced by `OptionsAvailable`. |
| Capture and endgame title bars | `Rsc/Titles.hpp:532-540,723-729`; `Client/FSM/client_title_capture.sqf:47-48,74-79`; `Client/GUI/GUI_EndOfGameStats.sqf:34-44,86-93,147`; `Client/Module/CoIn/coin_interface.sqf`. | Town/camp capture progress, endgame stat totals, CoIn placement state and the same title-display namespace helpers. | Local player / commander during build placement. | Event-driven cutRsc/title displays plus local FSM or interface loop writes. | Capture/endgame titles rely on title unload helpers; CoIn interface owns its placement display lifecycle. | Endgame stats and action/RHUD titles share the same namespace handle; CoIn placement feedback belongs with construction smoke rather than generic HUD cleanup. | Current maintained roots carry these title resources; release branch has the same shared-handle title risk. | Capture/lose a camp, place/cancel a CoIn object, and trigger endgame stats while RHUD is active. |
| Town, camp, team, HQ and tactical map markers | `Client/Init/Init_Markers.sqf:22-24,45-48`; `Client/FSM/updatetownmarkers.sqf:20-21,29-30,106,116,129-134`; `Client/FSM/updateteamsmarkers.sqf:21-24,45-55,165-186,197-208,229`; `Common/Common_MarkerUpdate.sqf:49-57,67-88,195-209,218-241`; `Client/GUI/GUI_Menu_Tactical.sqf:202-216,350-359,473-505,760-773`; `Client/GUI/GUI_RespawnMenu.sqf:73-82,194`. | Local marker arrays, town/camp side state, team/HQ/object positions, tactical selection variables and respawn selection state. | Local player; commander/tactical menu users see additional command surfaces. | Client marker FSMs poll cheaply while map/GPS is closed and force quicker full refresh when map or GPS opens. `Common_MarkerUpdate.sqf` loops at marker-specific refresh rates. | Marker scripts use local marker creation/update; tactical and respawn menus own their transient selection markers. | Map-open cadence and local marker ownership can hide stale-marker bugs unless map/GPS/JIP states are smoked separately. | Current Chernarus and maintained Vanilla carry the same marker loop topology; release changes should be treated as branch-specific until checked per marker family. | Join/JIP, open/close map and GPS, capture towns/camps, move teams/HQ, select respawn/fast travel, and check stale marker cleanup. |
| AARadar, artillery, ICBM, UAV, MASH and paratrooper markers | `Common/Common_AARadarMarkerUpdate.sqf:10-16,30-33,133,143,156,173,194,198`; `Server/Support/Support_Paratroopers.sqf:117`; `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:30-45`; old-shape `Server/Module/MASH/MASHMarker.sqf:1-11`; old-shape `Client/Module/MASH/receiverMASHmarker.sqf:1-27`; `Client/Functions/Client_FNC_Special.sqf:96-108`; `Client/Functions/Client_RequestFireMission.sqf:20-32,54-57,75`. | Server support calls, client PVF receivers, support request state, marked units/vehicles, side filters and local marker names. | Mostly local player/team/side; support markers may be side- or requester-visible depending on receiver path. | Event-driven marker creation plus client marker loops. | MarkerUpdate handles tracked-unit deletion paths; old-shape MASH and support receivers create/remove their own marker names. | Support marker families are fragmented across support, module and UI pages; paratrooper marker registration and MASH deploy/removal are branch-sensitive. | Current source has the paratrooper sender/receiver files but previous branch matrices still require registration/runtime smoke before calling revival complete; MASH marker/deploy branch scope is owned by the respawn lifecycle atlas. | Drop paratroopers, request artillery/UAV/special support, deploy/remove MASH only on old-shape or revived targets, use AARadar and verify side/audience plus stale-marker removal. |
| Menu/list icons, affordability colors and resource images | `Rsc/Dialogs.hpp:1171-1232,1525-1614,2110-2123,2372-2378,2638-2831,3463-3469`; `Rsc/Ressources.hpp:92,143,218,300-312,540-556`; `Client/GUI/GUI_Menu.sqf:29-35,47-57,101-170,191-207`; `Client/GUI/GUI_Menu_BuyUnits.sqf:84-90,165-176,237,495-496`; `Client/Functions/Client_UIFillListBuyUnits.sqf:34-62,68-90,105,107`. | Dialog IDC state, factory/unit configs, player funds, queue/build state, upgrade labels and `Client\Images\*.paa/.jpg` resources. | Local player using menus. | Dialog open/refresh loops and list-fill functions; buy-menu tabs refresh while the menu is open. | Dialog close controls clear UI state; resource cleanup belongs to [UI resource parity cleanup](UI-Resource-Parity-Cleanup). | Missing/stale image references can break many menus at once; older branches with malformed `RscClickableText.soundPush[]` need branch-scoped propagation/smoke before reuse. | Current `origin/master` `0139a346` fixes the clickable-text base-control value in both maintained roots at `Rsc/Ressources.hpp:556`; archived docs/source, Miksuu `b8389e74`, perf `0076040f` and release `a96fdda2` evidence remains branch-scoped until rechecked or merged. | Open main, buy units, gear, tactical, respawn and upgrade menus; verify icons load, unaffordable states are clear and no missing texture/config errors appear. |
| Status, debug, admin and performance counters | Current docs `a27086cd`: `Server/GUI/serverFpsGUI.sqf:1,6-7`; `Server/Module/serverFPS/monitorServerFPS.sqf:1,5-6`; `Client/Client_UpdateRHUD.sqf:113,199-201,367-369`; `Common/Functions/Common_PerformanceAudit.sqf:84,160,196,234`; `Client/Module/supplyMission/townSupplyStatus.sqf:1-8`; `Client/PVFunctions/Available.sqf:1`; `Client/FSM/updateclient.sqf:12-24,161-163,230-232`. | `diag_fps`, `SERVER_FPS_GUI`, `WFBE_VAR_SERVER_FPS`, PerformanceAudit buffers/flushes, supply-status values and client update loop state. | Split four ways: local player HUD, all-client PV status channels, admin/operator status text, and RPT/tooling consumers. | FPS publisher loops every 8 seconds on dedicated servers, RHUD/client update loops, event-style supply-status scripts and PerformanceAudit flush interval. | PerformanceAudit flushes buffered records; status channels stop with script/runtime termination; `SERVER_FPS_GUI` HUD use is independent from `WFBE_VAR_SERVER_FPS` compatibility publishing. | Do not prune player HUD, compatibility PVs, admin signals and developer RPT counters as one feature. Current source and stable also use different FPS publisher shapes, so smoke/consolidation decisions must be branch-scoped. | Docs head `a27086cd` keeps two guarded publishers in both maintained roots; current stable `origin/master@0139a346` and historical `a96fdda2` use one guarded `serverFpsGUI.sqf` publisher; Miksuu `b8389e74` and perf `0076040f` still keep the old two-publisher loop shape. Owner route: [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep). | Dedicated FPS-HUD updates, hosted/listen no-spin, `WFBE_VAR_SERVER_FPS` consumer grep before consolidation, supply mission status smoke, and client/server RPT audit collection with the audit parameter enabled. |

Future indicator cleanup should start from this table: pick one row, verify the branch/root scope for that family, then update the canonical owner page instead of adding another broad "all indicators" checklist.

### Status Counter Audience Split

The status/debug row is not a single UI feature. In current docs-source `a27086cd`, RHUD/FPS HUD reads `SERVER_FPS_GUI` at `Client/Client_UpdateRHUD.sqf:113`, and both maintained roots publish it from `Server/GUI/serverFpsGUI.sqf:6-7` after the early `!isDedicated` exit at `:1`. The second docs-source publisher, `Server/Module/serverFPS/monitorServerFPS.sqf:5-6`, still publishes `WFBE_VAR_SERVER_FPS`; no maintained-root player-HUD reader was found in this pass, so treat it as compatibility/status-channel evidence until generated or modded consumers are deliberately retired.

Keep that separate from PerformanceAudit. `Common/Functions/Common_PerformanceAudit.sqf:84,160,196,234` writes RPT/tooling counters, and `Client/Client_UpdateRHUD.sqf:199-201,367-369` records HUD loop cost when the audit toggle is enabled. Future cleanup should first decide which audience is being changed: player-visible HUD text, public-variable compatibility channel, admin/operator status signal or developer RPT data.

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

Current branch check 2026-06-23: `RscOverlay` and `OptionsAvailable` still both use `idd=10200` in both maintained roots across docs head `edbd341e` (same line refs as `b5219d47`: `Titles.hpp:44-46`, `:164-165`), current Miksuu `b8389e748243` and perf `0076040f` (same refs), current stable `origin/master@0139a346`, B69 `8d465fce`, B74 `b23f557f` and historical `a96fdda2` (`:44-46`, `:168-169`). No checked maintained root has a hard-coded `findDisplay 10200` caller, so treat this as title-resource maintenance/debug debt rather than a proven live lookup bug.

The more direct title lifecycle bug is independent of duplicate IDDs. `EndOfGameStats` has `idd=90000`, but it sets and clears `uiNamespace["currentCutDisplay"]` through the same `onLoad`/`onUnload` helpers as `OptionsAvailable` (`Titles.hpp:532-540` in docs/Miksuu/perf, `:580-588` in current stable/B69/B74/release). `GUI_EndOfGameStats.sqf:13,34-44,86-93` cuts and writes stat bars through that key, while the RHUD loop keeps running and can re-cut `OptionsAvailable` when the shared key is null (`Client_UpdateRHUD.sqf:89-92,190` in docs/Miksuu/perf; `:89-92,266` in current stable/B69/B74; `:89-92,258` in historical release). All checked maintained roots keep this shared-handle shape; patch title work by splitting display ownership or by gating RHUD/action-icon recreation once endgame begins. Use [UI IDD collision repair](UI-IDD-Collision-Repair) for the patch checklist instead of duplicating it here.

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

`GUI_Menu_Command.sqf` owns team selection, AI team templates, behavior/combat/formation/speed combos, move/task controls and respawn factory choice. Current stable `origin/master@0139a346`, current B69 `origin/claude/b69@8d465fce`, adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` and live `origin/feat/naval-hvt-objectives@2e1c59317186` carry the targeted Objective Ping path in both maintained roots: the menu gathers task data and HQ speech context at `GUI_Menu_Command.sqf:315-344`, then sends `SetTask` to the selected leader or side leaders at `:336,344` and registers the client handler at `Init_PublicVariables.sqf:40`. Docs/source `HEAD@86ab85b9d0b1`, Miksuu `b8389e748243` and `origin/perf/quick-wins@0076040f` still keep those sends commented at `GUI_Menu_Command.sqf:335,337,343` while registering `SetTask` at `:33`; historical `a96fdda2` has live sends with `:36` registration but no live `release/*` head. The old town `TaskSystem` remains disabled/residue and separate from Objective Ping.

Vote menu cleanup edge: `WFBE_Client_Teams_Count` is initialized as `count WFBE_Client_Teams` (`Init_Client.sqf:288` on current `origin/master`), but `GUI_Commander_VoteMenu.sqf:58-66` and `GUI_VoteMenu.sqf:29,61-66` use it as an inclusive `for ... to` maximum. Existing `isNil` guards make this mostly a refresh-loop polish bug rather than a proven crash, but vote UI changes should switch to `(WFBE_Client_Teams_Count - 1)` or `forEach`.

Vote behavior changes should start from [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook). That page owns the DR-47 server/UI outcome mismatch, the no-commander/tie decision matrix and the smoke cases that must accompany any `GUI_VoteMenu.sqf` preview change.

Vote row coloring has a second small indexing edge. In `GUI_VoteMenu.sqf:74-83`, the loop variable already tracks the list row while scanning `lnbSize`, but the color write uses `[_i+1,0]`. If touching vote refresh, audit both the backing team-array loop and this row-color mapping together.

Commander reassignment has a separate selector fragility. `GUI_Commander_VoteMenu.sqf:33-46` reads the selected row text, then finds the target team by comparing `name leader _x`. Because the row already stores the team index with `lnbSetValue`, future fixes should use the stored value instead of visible names so duplicate names or mid-dialog name changes cannot select the wrong commander. Keep this UI fix aligned with [Commander reassignment call shape](Commander-Reassignment-Call-Shape) and [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook).

Help dialog lifecycle edge: `RscMenu_Help` stores the display as `uiNamespace["dialog_HelpPanel"]` on load, but unload clears `uiNamespace["cti_dialog_ui_onlinehelpmenu"]` and calls `GUI_Menu_Help.sqf` with `onUnload` (`Rsc/Dialogs.hpp:3446-3447` on docs head `087152f5`; current stable/B69/B74 use `:3172-3173`; release `a96fdda2` uses `:3108-3109`). The controller only implements `onLoad` and `onHelpLBSelChanged` (`GUI_Menu_Help.sqf:5-10`). This looks like stale namespace wiring, so avoid building new help-panel state on the old unload variable without cleaning it.

Main-menu orphan route: docs head `087152f5` keeps the `68bd4dc5` line shape and still handles `MenuAction == 17/18` for GPS zoom at `GUI_Menu.sqf:202,206`, while the audited `WF_Menu` resource block exposes actions `1-13`, `16` and `19` only (`Rsc/Dialogs.hpp:1226` emits `MenuAction = 19`). Current stable `origin/master@0139a346`, current B69 `8d465fce` and adjacent B74 `b23f557f` keep handler-only zoom routes at `GUI_Menu.sqf:270,274` but reuse the visible `MenuAction = 19` control as GPS enablement (`Rsc/Dialogs.hpp:1244,1252`; `GUI_Menu.sqf:241`). B69 also refreshes `WFBE_Client_Teams_Count` from reconciled side teams at `Init_Client.sqf:534`, but that remains `count`, not a maximum index. Miksuu `b8389e74` and perf `0076040f` keep the docs-checkout FPS-HUD meaning for visible action `19`; release `a96fdda2` matches the stable GPS action shape with Chernarus/Vanilla line drift. Treat the old zoom router cases as dead UX baggage unless a hidden/branch control is deliberately reintroduced and smoke-tested.

### Vote, Help And Main-Menu Branch Matrix

This route owns the small UI correctness cluster around vote refresh/list coloring, help-panel lifecycle state and the main-menu GPS zoom router. The WASP marker input-lock wait is adjacent UX debt, but its branch matrix stays on [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup).

| Root / branch | Vote refresh and row color | Help menu lifecycle | Main-menu `17/18/19` route | Status |
| --- | --- | --- | --- | --- |
| Docs head `087152f5` | Both maintained roots are unchanged from `68bd4dc5` for checked vote/help/router paths: `WFBE_Client_Teams_Count = count WFBE_Client_Teams` at `Init_Client.sqf:273`; `GUI_VoteMenu.sqf:29,49,61` and `GUI_Commander_VoteMenu.sqf:58` loop through that inclusive value; row coloring still writes `[_i+1,0]` at `GUI_VoteMenu.sqf:80,82`. | Both maintained roots set `dialog_HelpPanel` and clear `cti_dialog_ui_onlinehelpmenu` at `Rsc/Dialogs.hpp:3446-3447`; `GUI_Menu_Help.sqf:5-10` handles load and selection, not unload. | Both roots keep handler-only `MenuAction == 17/18` zoom at `GUI_Menu.sqf:202,206`; visible `MenuAction = 19` is `CA_FPSHUD_Button` at `Rsc/Dialogs.hpp:1219-1227` and toggles `RUBFPSHUD` at `GUI_Menu.sqf:197`. | Patch-ready UI cleanup; `git diff --name-status 68bd4dc5..HEAD` is empty for checked maintained-root vote/help/router paths. |
| Current stable `origin/master@0139a346`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `b23f557f` | Both maintained roots keep the same inclusive vote-loop and row-color shape. Stable uses `Init_Client.sqf:315`; B69/B74 use `Init_Client.sqf:403` plus a reconciled team refresh at `:534`; `GUI_VoteMenu.sqf:29,49,61,80,82` and `GUI_Commander_VoteMenu.sqf:58` are unchanged. | Both maintained roots set `dialog_HelpPanel` and clear `cti_dialog_ui_onlinehelpmenu` at `Rsc/Dialogs.hpp:3172-3173`; `GUI_Menu_Help.sqf:5-10` still has no `onUnload` case. | Both maintained roots keep `MenuAction == 17/18` handlers at `GUI_Menu.sqf:270,274`; visible `MenuAction = 19` is `CA_GPS_Button` at `Rsc/Dialogs.hpp:1244-1252` and GPS enablement at `GUI_Menu.sqf:241`. `git diff --name-status origin/claude/b69..origin/claude/b74-aicom-spend` is empty for checked paths. | Stable/B69/B74 change the visible action-19 meaning, but do not rescue vote loops, row color, help unload or old zoom-router cleanup. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Same inclusive vote-loop and row-color shape in both maintained roots; Miksuu uses `Init_Client.sqf:284`, perf uses `:285`. | Same help namespace mismatch at `Rsc/Dialogs.hpp:3502-3503`. | Same handler-only `17/18` route as docs checkout; visible `MenuAction = 19` remains `CA_FPSHUD_Button` / FPS HUD at `Rsc/Dialogs.hpp:1220-1227` in both maintained roots. | No upstream/perf rescue for this UI cluster. |
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

Current-B74 Economy-control refresh 2026-06-23: docs/source `HEAD@21f0d53b` is unchanged from `d2a3f995` / `b5219d47` for checked Economy controller/resource paths and still writes disabled-state controls `23004`, `23005` and `23006` from `GUI_Menu_Economy.sqf:7-8` in both maintained roots while `RscMenu_Economy` declares `23002`, `23003` and `23008` without `23020` at `Rsc/Dialogs.hpp:3327,3339,3346`. Current stable `origin/master@0139a346`, current B69 `origin/claude/b69@8d465fce`, adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` and historical `a96fdda2` remove those stale writes in both maintained roots, read the dashboard with `DisplayCtrl 23020` at `GUI_Menu_Economy.sqf:25` and declare `23020` in `Rsc/Dialogs.hpp` (`:3070` on stable/B69/B74, `:3006` on historical release). Current Miksuu `b8389e748243` and perf `0076040f` remain old-shape. B74 changes only Chernarus dashboard label text versus stable among checked paths, not the control-map repair.

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

EASA opens from `GUI_Menu_Service.sqf` and uses generated arrays from `Client/Module/EASA/EASA_Init.sqf`. In docs/source, current Miksuu and perf its dialog shares `idd=23000` with Economy; current stable/B69/B74 and historical release split EASA to `idd = 24000`. Detailed runtime is documented in [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas), with duplicate-IDD patch detail in [UI IDD collision repair](UI-IDD-Collision-Repair).

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

Branch intel 2026-06-23: `origin/claude/upstream-blinking-mapicons@6e31f7fd5` is a branch-only mounted-player blink candidate, not current stable behavior. Its merge-base with current stable is `be2bbd084`, which is an ancestor of `origin/master@f8a76de34`; direct diffs against current stable also include unrelated B74.1 `Init_CommonConstants.sqf:914-920` player-stats drift. The payload versus `be2bbd084` is only `Client_BookkeepBlinkingIcons.sqf` in source Chernarus and maintained Vanilla (+32, `git diff --check` clean): current stable pushes only active vehicles into `BLINKING_VEHICLES_*` at `Client_BookkeepBlinkingIcons.sqf:82-94`, while the branch also pushes a mounted player gunner/commander into `BLINKING_UNITS_*` at `:96-110` so the soldier marker blinks beside the active vehicle marker. Smoke with `WFBE_C_MAP_ICON_BLINKING_ENABLED = 1`, mounted gunner and commander seats, map/GPS open and closed, dismount, death/null cleanup and both maintained roots before promotion.

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
| Objective Ping versus old town tasks | Current stable/B69/B74 and `origin/feat/naval-hvt-objectives` send `SetTask` at `GUI_Menu_Command.sqf:336,344`; docs/source, Miksuu and perf still comment those sends at `:335,:337,:343`; historical `a96fdda2` has live sends but no live `release/*` head. | Treat Objective Ping as source-present / smoke-pending only on the current stable-shaped branches. Keep old town-task revival separate and JIP/task-spam gated. |
| Buy Units UI and authority | `RscMenu_BuyUnits` drives local `GUI_Menu_BuyUnits.sqf` / `Client_BuildUnit.sqf`; no `RequestBuyUnit` PVF exists. | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) owns price/key, queue, refund and authority detail. |
| Gear, cargo, EASA and service partials | Gear target/content TODOs, profile `_u_upgrade`, vehicle cargo loop bounds, service/EASA affordability and UI-originated spend all sit outside the generic UI stack. | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), and [Service menu affordability guards](Service-Menu-Affordability-Guards). |
| Tactical fast travel | Fee mode hides unaffordable towns, draws marker-price text and debits locally on travel click; current stable has already dropped the old completed TODO comment. | Keep branch status in [Tactical Fast-Travel Fee Branch Matrix](#tactical-fast-travel-fee-branch-matrix); do not mix with `RequestSpecial` authority hardening. |
| Support and special indicators | Paratrooper, MASH, UAV, artillery, ICBM and AARadar marker anchors are listed in the indicator matrix. | [Support specials and tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Abandoned feature revival](Abandoned-Feature-Revival-Review), and [Networking and public variables](Networking-And-Public-Variables) own feature-specific PV/JIP behavior. |
| WASP marker wait/input lock | `WASP/global_marking_monitor.sqf:57-73` still disables input and polls display 54 without a sleep/backoff before final unlock. | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) owns the tiny patch and smoke route. |

### Tactical Fast-Travel Fee Branch Matrix

Fast travel is a local Tactical menu flow, not a `RequestSpecial` server asset path. The menu reads `WFBE_C_GAMEPLAY_FAST_TRAVEL` and fast-travel range constants at `GUI_Menu_Tactical.sqf:22-23`; current stable `origin/master@0139a346` defaults to `1` free travel and uses `2` for fee mode at `Common/Init/Init_CommonConstants.sqf:388,398-400`. In fee mode, the destination refresh calculates `_fee` from distance and `WFBE_C_GAMEPLAY_FAST_TRAVEL_PRICE_KM`, hides towns the player cannot afford, draws marker-text price labels, and later debits locally when the player clicks the travel destination (`GUI_Menu_Tactical.sqf:185,195-196,215,403-404` on current stable). The old `//--- TODO: Travel fee...` comment is absent on current stable but still present in the docs branch, Miksuu, perf and historical release refs, so treat it as stale policy/UX cleanup evidence in those targets rather than proof that fast travel is absent.

| Root / branch | Fee-mode destination list | Debit / prompt shape | Status |
| --- | --- | --- | --- |
| Current stable `origin/master@0139a346` | Both maintained roots hide unaffordable town destinations and draw marker text with `$fee` (`GUI_Menu_Tactical.sqf:185,195-196,215`). | Both maintained roots recalculate and locally call `ChangePlayerFunds` at `:403-404`; no confirmation prompt or second affordability recheck is present. The old completed TODO is absent. | Docs-ready owner-decision cleanup; do not reopen the stale TODO removal on current stable. |
| Docs branch `docs/developer-wiki-index@a489e6ff`, Miksuu `b8389e74`, perf `0076040f` and historical release `a96fdda2` | Same maintained-root behavior with branch line drift; docs/Miksuu/perf constants sit at `Init_CommonConstants.sqf:218,228-230`, historical release constants at `:231,241-243`. Docs/Miksuu/perf/release keep the old TODO at `GUI_Menu_Tactical.sqf:147`. | Same local debit shape at `GUI_Menu_Tactical.sqf:404-405`; adjacent support debits drift between refs, but they are not the fast-travel debit. | No checked old-shape ref rescues the fee-mode UX/policy debt; current origin exposes no live `release/*` or fast-travel feature heads on 2026-06-22. |

Practical patch rule: keep this separate from `RequestSpecial` authority hardening. First decide the user-facing policy: hide unaffordable destinations as today, show them disabled with a reason, or allow selection but block with a hint. If fee mode stays paid, add a final local funds/context recheck immediately before the debit and consider a confirmation prompt for long-distance travel. Smoke `WFBE_C_GAMEPLAY_FAST_TRAVEL` modes `0/1/2`, insufficient/exact/sufficient funds, HQ/town/command-center start points, non-friendly towns, maximum range, vehicle/group teleport, death during travel and maintained Vanilla parity.

### Clickable Text SoundPush Branch Matrix

`RscClickableText` is a base UI resource class. Current stable `origin/master@0139a346`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` now define `class RscClickableText` at `Rsc/Ressources.hpp:541` and the valid empty-sound `soundPush[] = {"", 0.2, 1};` at `:556` in both maintained roots, matching the older valid precedent at `:92`. Chernarus received the stable fix in `1a5e0b40`; maintained Vanilla received the propagated generated-file fix in `9b49883c`. The blast radius is still branch-sensitive because docs/source, current Miksuu, perf, historical release and UI theme checkpoints carry the malformed base value, and `Rsc/Dialogs.hpp` now derives 14 controls from the base class in current stable/B69/B74 while old-shape checked branches derive 17 controls.

| Root / branch | `RscClickableText.soundPush[]` | Derived clickable controls | Status |
| --- | --- | --- | --- |
| Docs head `0bb0f89f` Chernarus + maintained Vanilla | `Rsc/Ressources.hpp:556` keeps `{, 0.2, 1}` in both maintained roots; `:92` shows valid `{"", 0.2, 1}` precedent. Checked `Rsc/Ressources.hpp` / `Rsc/Dialogs.hpp` paths are unchanged from `b5219d47` and the earlier `a71b42fe` / `f7bc72a8` matrix snapshots. | 17 `: RscClickableText` controls in each `Rsc/Dialogs.hpp` root, including gear slots, WF menu toggles, construction/CoIn, artillery and economy controls. | Patch-ready, docs/source-unpatched; propagate Vanilla with any source edit. |
| Current stable `origin/master` (`0139a346`), current B69 `8d465fce` and adjacent B74 `b23f557f` Chernarus + maintained Vanilla | Fixed/source-present in both maintained roots: `Rsc/Ressources.hpp:556` now keeps `{"", 0.2, 1}`. The old malformed value is absent from the checked maintained roots; checked `origin/master..B74` and `B69..B74` resource/dialog deltas are empty. | 14 derived controls in each maintained root at `Rsc/Dialogs.hpp:670,710,742,817,868,1194,1204,1214,1587,1642,2186,2448,2828,3133`. | Current stable/B69/B74 no longer need the base config patch; keep propagation/recheck work branch-scoped and run representative Arma 2 OA dialog smoke before release-validated wording. |
| Current Miksuu `master` (`b8389e748243`) | Same malformed base-class value in both maintained roots. | 17 derived controls in both maintained roots, with line drift from docs/source. | Direct `git ls-remote` rechecked this as the current Miksuu head on 2026-06-23; no upstream rescue. |
| `origin/perf/quick-wins` (`0076040f`) | Same malformed base-class value in both maintained roots. | 17 derived controls in both maintained roots. | Perf branch does not touch this UI config. |
| Historical release `a96fdda2`; no live `release/*` head exposed on 2026-06-23 | Same malformed base-class value in both maintained roots. | 14 derived controls in each maintained release root at `Rsc/Dialogs.hpp:657,697,729,804,855,1181,1191,1201,1537,1592,2122,2384,2764,3069`. | Historical release evidence does not rescue the base config. |
| UI theme branches `origin/feat/wf-menu-ops-console` (`0767c0b5`) and `origin/feat/wf-menu-ux-phase1` (`87d86257`) | Same malformed base-class value in both maintained roots. | 17 derived controls in both maintained roots. | Theme branches still need config smoke before promotion. |

Practical patch rule: for current stable/B69/B74, do not reopen the base-class edit; it is already source-present in Chernarus and maintained Vanilla. For older branches that still carry `{, 0.2, 1}`, change only the base-class array to the valid local empty-sound precedent `{"", 0.2, 1}` unless a code owner wants a real click sound, then propagate maintained Vanilla deliberately. In all cases, run an Arma 2 OA dialog smoke that opens representative inheritors from gear, WF menu/HUD toggles, construction/CoIn, artillery and economy; treat modded mission copies as unsupported until their broader conflict/generation blockers are resolved.

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
