# Earplugs Audio Toggle Reference

> Verified 2026-06-21 against `master` `0139a346` (Arma 2 OA 1.64); paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

This page documents the live earplugs feature. Current Chernarus has two entry points with separate state variables: the WASP scroll/vehicle action uses `WFBE_WASP_EarplugActive`, while the main WF menu button uses `WFBE_Earplugs` (`WASP/actions/EarplugToggle.sqf:12,19,25`; `Client/GUI/GUI_Menu.sqf:279-291`).

## Entry Points

| Surface | Runtime path | Evidence |
| --- | --- | --- |
| Initial client startup | Client init executes `WASP\actions\AddActions.sqf`, which is where the on-foot earplugs action and mounted-vehicle mirror loop are created. | `Client/Init/Init_Client.sqf:650`; `WASP/actions/AddActions.sqf:37-39,50-65` |
| Respawn | The pre-respawn handler starts `WASP\actions\OnKilled.sqf`, and that one-line script executes `AddActions.sqf` again. | `Client/Functions/Client_PreRespawnHandler.sqf:11`; `WASP/actions/OnKilled.sqf:1` |
| Skin selector return path | Skin selector apply restores player menu/action wiring and then runs `AddActions.sqf`. | `WASP/actions/SkinSelector/SkinSelector_Apply.sqf:230-235` |
| WF menu button | `CA_EAR_Button` is `idc = 11022`, displays `EAR`, sets `MenuAction = 22`, and has tooltip text for earplugs. | `Rsc/Dialogs.hpp:1269-1278` |
| WF menu handler | `MenuAction == 22` toggles `WFBE_Earplugs`, applies `fadeSound`, and shows `Earplugs: IN` / `Earplugs: OUT` hints. | `Client/GUI/GUI_Menu.sqf:279-291` |
| Player-facing help text | The mission briefing and Help menu both say earplugs fade radio/voice and work while mounted. That statement matches the WASP scroll/vehicle path, not the simpler WF menu handler. | `briefing.html:53`; `Client/GUI/GUI_Menu_Help.sqf:199-205`; `WASP/actions/EarplugToggle.sqf:16-23`; `Client/GUI/GUI_Menu.sqf:279-291` |

## Behavior Matrix

| Action path | State key | Earplugs in | Earplugs out | Title / feedback | Evidence |
| --- | --- | --- | --- | --- | --- |
| WASP scroll action and vehicle mirror | `WFBE_WASP_EarplugActive` in `missionNamespace` | `0.25 fadeSound 0.3`, `0.25 fadeRadio 0.12`, and `autoViewDistanceToggledOn` sound. | `1 fadeSound 0.3`, `1 fadeRadio 1`, and `autoViewDistanceToggledOff` sound. | The title is `Earplugs OUT` when active and `Earplugs IN` when inactive. | `WASP/actions/EarplugToggle.sqf:12-28` |
| WF menu `EAR` button | Global `WFBE_Earplugs` variable | `1 fadeSound 0.2` and `hint "Earplugs: IN"`. | `1 fadeSound 1` and `hint "Earplugs: OUT"`. | The button label stays `EAR`; the handler only changes hints and `WFBE_Earplugs`. | `Rsc/Dialogs.hpp:1269-1278`; `Client/GUI/GUI_Menu.sqf:279-291` |

The two paths are not synchronized in source: `EarplugToggle.sqf` reads/writes `WFBE_WASP_EarplugActive`, while `GUI_Menu.sqf` reads/writes `WFBE_Earplugs` (`WASP/actions/EarplugToggle.sqf:12,19,25`; `Client/GUI/GUI_Menu.sqf:282-289`). A player can therefore change the engine sound level from either surface, but the action title/state for the other surface is not updated by that handler (`WASP/actions/EarplugToggle.sqf:28,34-46`; `Client/GUI/GUI_Menu.sqf:279-291`).

## WASP Scroll And Vehicle Mirror

| Component | Source-backed behavior | Evidence |
| --- | --- | --- |
| On-foot action | `AddActions.sqf` chooses `Earplugs OUT` / `Earplugs IN` from `WFBE_WASP_EarplugActive`, adds the player action, and stores the action id in `WFBE_WASP_EarplugFootID`. | `WASP/actions/AddActions.sqf:33-39` |
| Vehicle-loop guard | `WFBE_WASP_EarplugVehLoop` prevents spawning another mirror loop when `AddActions.sqf` is run again. | `WASP/actions/AddActions.sqf:41-52` |
| Poll cadence | The mounted-vehicle mirror loop runs permanently and sleeps for `2` seconds each pass. | `WASP/actions/AddActions.sqf:56-58` |
| Mount behavior | When the player is in a vehicle and the vehicle changes, the loop removes the previous vehicle action, adds the current title to the new vehicle, and stores `WFBE_WASP_EarplugVehID` plus `WFBE_WASP_EarplugVehRef`. | `WASP/actions/AddActions.sqf:59-68` |
| Dismount cleanup | When the player returns to on-foot state, the loop removes the mirror action from the last vehicle and resets vehicle id/ref variables. | `WASP/actions/AddActions.sqf:70-75` |
| Death cleanup | If the player dies while a vehicle action exists, the loop removes the old vehicle action using loop-local copies and clears the local tracking variables. | `WASP/actions/AddActions.sqf:77-84` |
| Toggle refresh | `EarplugToggle.sqf` removes and re-adds the on-foot action by remembered id, then does the same for the mounted vehicle mirror if the player is currently in a vehicle. | `WASP/actions/EarplugToggle.sqf:30-46` |

## Main Menu EAR Button

| Component | Source-backed behavior | Evidence |
| --- | --- | --- |
| Resource button | The button is part of the main dialog, uses `idc = 11022`, displays the compact label `EAR`, and sets `MenuAction = 22`. | `Rsc/Dialogs.hpp:1269-1278` |
| Comment scope | The source comment calls the button an Arma 3-style QoL affordance, but the executable path is a local `MenuAction` button plus `fadeSound`. Treat the comment as user-facing intent, not as an Arma 3 scripting dependency. | `Rsc/Dialogs.hpp:1268-1278`; `Client/GUI/GUI_Menu.sqf:279-291` |
| First use | If `WFBE_Earplugs` is nil, the handler initializes it to `false` before toggling. | `Client/GUI/GUI_Menu.sqf:280-283` |
| Audio scope | The menu handler changes only `fadeSound`; it does not call `fadeRadio`. | `Client/GUI/GUI_Menu.sqf:283-291`; contrast `WASP/actions/EarplugToggle.sqf:16-23` |

## Development Notes

| Note | Why it matters | Evidence |
| --- | --- | --- |
| Do not document the feature as one unified state machine. | The scroll/vehicle path and WF menu path use different state keys and different volume values. | `WASP/actions/EarplugToggle.sqf:12-28`; `Client/GUI/GUI_Menu.sqf:282-291` |
| Do not claim the WF menu button fades radio/voice. | The player-facing help text says radio/voice, and the WASP toggle does call `fadeRadio`, but the WF menu handler does not. | `Client/GUI/GUI_Menu_Help.sqf:205`; `WASP/actions/EarplugToggle.sqf:16-23`; `Client/GUI/GUI_Menu.sqf:279-291` |
| Keep respawn and skin-selector paths in sync if changing action ids or titles. | Respawn and skin selector both re-run `AddActions.sqf`, and `EarplugToggle.sqf` later removes/re-adds actions using stored ids. | `Client/Functions/Client_PreRespawnHandler.sqf:11`; `WASP/actions/OnKilled.sqf:1`; `WASP/actions/SkinSelector/SkinSelector_Apply.sqf:230-235`; `WASP/actions/EarplugToggle.sqf:30-46` |
| Treat this as local UI/audio behavior unless a future source change adds network effects. | The cited handlers are client UI/action scripts that call local audio/action commands and local state writes. | `Client/Init/Init_Client.sqf:650`; `Rsc/Dialogs.hpp:1269-1278`; `WASP/actions/EarplugToggle.sqf:16-46`; `Client/GUI/GUI_Menu.sqf:279-291` |

## Continue Reading

Previous: [WASP overlay](WASP-Overlay) | Next: [Client UI systems atlas](Client-UI-Systems-Atlas)

Main map: [Home](Home) | UI route: [Client UI, HUD and menus](Client-UI-HUD-And-Menus) | Player flow: [Player UI workflow map](Player-UI-Workflow-Map)
