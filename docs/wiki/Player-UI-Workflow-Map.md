# Player UI Workflow Map

This page maps what a player or commander can actually do from the client UI, and where each workflow lives in source. Use it before editing `Rsc/Dialogs.hpp`, `Client/GUI/*`, player actions, map-click behavior, HUD/title resources or WASP action surfaces.

Canonical implementation pages remain [Client UI systems atlas](Client-UI-Systems-Atlas), [Client UI/HUD/menus](Client-UI-HUD-And-Menus), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Service menu affordability guards](Service-Menu-Affordability-Guards), [UI IDD collision repair](UI-IDD-Collision-Repair), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) and [WASP overlay](WASP-Overlay). This page is the player-clickable workflow tour, not the detailed dialog atlas.

## Workflow Map

| Flow | What the player can do | Source owners | Status |
| --- | --- | --- | --- |
| Join/init | Loading blackout, side/stack request, briefing diary, intro video, optional commander vote and new-player menu hint. | `initJIPCompatible.sqf:70`, `:224`; `Client/Init/Init_Client.sqf:416`, `:787`, `:958`; `briefing.sqf:11` | Live. |
| WF menu entry | Scroll `Options` opens the main Warfare menu; vehicle action mirror also exists. | `Client/Functions/Client_AddWFMenuAction.sqf:17`; `Client/Action/Action_Menu.sqf:1`; `Client/FSM/updateactions.fsm:114` | Live. |
| Main menu | Buy units, gear, team, voting, command, tactical, upgrade, economy, service, help, params, unflip, headbug and HUD/FPS toggles. | `Rsc/Dialogs.hpp:1019-1022`; `Client/GUI/GUI_Menu.sqf:32-208` | Live; some help/tooltips are hardcoded. GPS zoom router actions `17/18` remain in `GUI_Menu.sqf` but no audited `WF_Menu` control emits them. |
| Buy units | Select factory/depot/airport, select unit and buy; client queues, debits and spawns. | `Rsc/Dialogs.hpp:1445-1448`; `Client/GUI/GUI_Menu_BuyUnits.sqf:90-156`; `Client/Functions/Client_BuildUnit.sqf:216-253` | Live; client-authoritative purchase surface. |
| Buy gear/templates | Select target, switch `gear` / `backpack` / `vehicle` views, use `Template` / `All` / `Primary` / `Secondary` / `Pistols` / `Equipment` tabs, buy gear, create/delete/save templates. | `Rsc/Dialogs.hpp:530-533`; `Client/GUI/GUI_BuyGearMenu.sqf:8-19`, `:122-146`, `:418-509`; `Client/Functions/Client_UI_Gear_AddTemplate.sqf:132-150` | Live; client-authoritative and template-filter debt. Exit-time `_need_save` triggers profile save at `GUI_BuyGearMenu.sqf:509`. |
| Team/vote/transfer | View terrain/FX/distance, transfer funds, disband AI, toggle vote popup and vote/select commander. | `Rsc/Dialogs.hpp:1233-1236`, `:409-412`, `:145-148`, `:237-240`; `GUI_Menu_Team.sqf:86-160`; `GUI_TransferMenu.sqf:57-75`; `GUI_VoteMenu.sqf:31-36` | Live, with vote/reassignment cleanup routed through [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook): server/UI no-commander semantics, `GUI_VoteMenu.sqf:29,61` and `GUI_Commander_VoteMenu.sqf:58` inclusive loops, `GUI_VoteMenu.sqf:74-83` row coloring, and reassignment-by-name fragility. |
| Command | Commander changes team properties, respawn, auto-AI and buy-type settings. Move/Patrol/Defense are two-step: the button arms `MenuAction`, then a map click writes replicated move mode/destination variables and spawns marker/radio feedback. Task controls are visible but not sent. | `Rsc/Dialogs.hpp:1789-1792`; `GUI_Menu_Command.sqf:252-306`, `:315-344`, `:477-501` | Mixed: property PVF is live, map-order executor proof is pending, task send is dormant/commented. |
| Tactical/supports | Artillery, fast travel, ICBM, paradrop ammo/vehicle/paratroops, unit cam and UAV. | `Rsc/Dialogs.hpp:2161-2164`; `GUI_Menu_Tactical.sqf:56-61`, `:239-344`, `:363-527`, `:541-605` | Live; many paths are client-gated/debited. |
| Upgrade | Open live upgrade dialog and buy/sync upgrades. | `Rsc/Dialogs.hpp:4-7`; `GUI_Menu.sqf:161-165`; `GUI_UpgradeMenu.sqf:135-161` | Live. Old `RscMenu_Upgrade` is stale. |
| Economy/build | Commander opens CoIn build, changes income %, sells structures and respawns supply trucks. | `Client/FSM/updateclient.sqf:220`; `Action_Build.sqf:1`; `coin_interface.sqf:29`, `:672-718`; `GUI_Menu_Economy.sqf:74-150` | Live; high authority surface. `GUI_Menu_Economy.sqf:10` does not reset `mouseButtonUp` even though `:101-106` consumes it for map sell, so Economy map-click changes need stale-click smoke. |
| Service/EASA | Rearm, repair, refuel, heal and aircraft loadout dialog. | `Rsc/Dialogs.hpp:2870-2873`, `:3209-3212`; `GUI_Menu_Service.sqf:128-244`; `GUI_Menu_EASA.sqf:3-4`, `:47-50`; `EASA_Equip.sqf:8-38` | Live; affordability/authority debt, stale EASA context risk, exact-funds rejection and unsupported-vehicle fail-open risk. |
| Respawn/RHUD/map/WASP | Respawn source/gear choice, countdown, dynamic spawn discovery through `GetRespawnAvailable`, respawn marker selector, RHUD/FPS overlay, map-click AI shortcuts, capture/title overlays and WASP actions. | `Client_OnKilled.sqf:155`; `GUI_RespawnMenu.sqf:10-48`, `:103-157`; `Client_UI_Respawn_Selector.sqf:19-35`; `Client_UpdateRHUD.sqf:3-95`; `Client_HandleMapSingleClick.sqf:20-179`; `WASP/actions/AddActions.sqf:15`; `WASP/baserep/viem.sqf:13-53`; `WASP/global_marking_monitor.sqf:57-73` | Live with stale/commented WASP prototypes nearby; map double-click marker helper briefly disables all user input while polling for the marker dialog. |

## Dialog And Action Surfaces

Use [Client UI systems atlas](Client-UI-Systems-Atlas) for the full dialog/title table. As a workflow shortcut:

| Surface group | Main examples | Owner route |
| --- | --- | --- |
| Live player menus | Upgrade, vote, respawn, transfer, main, team, buy units, command, tactical, service, EASA, economy and help. | [Client UI systems atlas](Client-UI-Systems-Atlas), [Client UI/HUD/menus](Client-UI-HUD-And-Menus) |
| Authority-sensitive menus | Buy units, gear, tactical supports, upgrades, economy sale, CoIn, service/EASA and WASP repair actions. | [Server authority map](Server-Authority-Migration-Map), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Service menu affordability guards](Service-Menu-Affordability-Guards) |
| Stale or partial surfaces | Old upgrade dialog, visible command task controls, help unload mismatch, duplicate EASA/Economy IDD and duplicate title-resource IDs. | [UI IDD collision repair](UI-IDD-Collision-Repair), [Abandoned feature revival](Abandoned-Feature-Revival-Review#old-upgrade-dialog-review), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) |
| Map/HUD/WASP overlays | RHUD/action titles, capture/build/end titles, respawn marker selector, command map clicks and WASP scroll/map actions. | [Client UI systems atlas](Client-UI-Systems-Atlas), [WASP overlay](WASP-Overlay) |

## High-Risk Action Surfaces

| Risk | Action |
| --- | --- | --- |
| Client-authoritative player actions | Keep UI as affordance only in future hardening; server should validate funds, cooldowns, ownership, side, distance and effect target. |
| Commander map-order executor unproven | Smoke Move/Patrol/Defense/Take Towns orders in Arma before treating the UI as a working AI-order executor. |
| Duplicate display/title IDs | Use [UI IDD collision repair](UI-IDD-Collision-Repair) before adding `findDisplay`-based automation or new resources. |
| Visible command task partial | Hide or restore with server-backed task flow; do not document as working task assignment. |
| Help dialog/content lifecycle | Clean namespace state before extending help, and treat help text edits as UI plus localization work. |
| Orphan main-menu GPS route and stale upgrade dialog | Remove dead router/resource cases or restore visible controls deliberately; smoke main-menu HUD/GPS and upgrade dialog flows either way. |
| Hardcoded UI text | Move only in a dedicated localization pass; keep source copy stable during behavior patches. |

## Map-Click Modifier Model

The player map-click layer has more behavior than a plain `onMapSingleClick` grep suggests. `Init_Client.sqf:241-244` tracks Ctrl separately because Arma's map-click callback exposes Shift and Alt but not Ctrl; `Client_HandleMapSingleClick.sqf:19-90` uses Ctrl-click to disband a nearby AI from the player's group; `:95-164` handles plain-click selection behavior; `:165-173` stores leader shift-click move orders for newly spawned units; and `:174-179` preserves the debug teleport branch on plain clicks when `WF_Debug` is enabled. Smoke map UX with Ctrl, Shift, plain click, selected units and debug mode separately; they are intentionally multiplexed through one handler.

The command menu has its own map-click capture in addition to this global handler. `GUI_Menu_Command.sqf:262-306` arms Move/Patrol/Defense with `MenuAction`, converts the next map click to world position, then calls `SetTeamMovePos` / `SetTeamMoveMode` and spawns temporary marker feedback. Keep that separate from the spawned-unit follow-up helper in `Client_SendSpawnedUnitsToLeaderWaypoint.sqf`, which only pushes newly bought units toward an already-known destination.

## Manual UI Smoke

1. Join a fresh client and confirm the loading blackout clears, briefing appears, side/stack checks complete and the WF menu hint is visible.
2. Open the WF menu through the scroll action and verify main buttons open Buy Units, Gear, Team, Command, Tactical, Upgrade, Economy, Service and Help.
3. Buy one infantry unit and one vehicle from an appropriate factory/depot, then confirm queue cleanup and funds behavior.
4. Buy gear for self and save/delete a template; include profile-template save if testing [Gear template profile filter](Gear-Template-Profile-Filter).
5. Commander smoke: open Command, Economy/CoIn, Upgrade and Tactical; verify partial task controls are either knowingly no-op or patched.
6. Open EASA and Economy in separate flows and check no duplicate-IDD lookup assumptions appear in RPT.
7. Die and respawn from camp/mobile/MASH/leader where available; confirm RHUD and marker overlays recover after respawn.
8. Trigger WASP actions that are live in the current mission; do not revive old commented WASP init/action paths without a separate smoke.

## Continue Reading

Previous: [Client UI/HUD/menus](Client-UI-HUD-And-Menus) | Next: [Client UI systems atlas](Client-UI-Systems-Atlas)

Related: [Feature status](Feature-Status-Register) | [Server authority map](Server-Authority-Migration-Map) | [Testing workflow](Testing-Debugging-And-Release-Workflow)
