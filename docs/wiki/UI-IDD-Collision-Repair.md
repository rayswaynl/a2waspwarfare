# UI IDD Collision Repair

Status: confirmed UI/resource risk, patch-ready. This page owns the exact source evidence and safe repair plan for duplicated `idd` values in dialogs and title resources.

All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## What To Read

- `description.ext`
- `Rsc/Dialogs.hpp`
- `Rsc/Titles.hpp`
- `Client/GUI/GUI_Menu_EASA.sqf`
- `Client/GUI/GUI_Menu_Economy.sqf`
- `Client/GUI/GUI_Menu.sqf`
- `Client/GUI/GUI_Menu_Service.sqf`
- `Client/Client_UpdateRHUD.sqf`
- `Client/FSM/updateavailableactions.fsm`
- [Client UI systems atlas](Client-UI-Systems-Atlas)
- [Feature status register](Feature-Status-Register)

## Current Collisions

`description.ext` includes the relevant UI resources:

- `description.ext:54` includes `Rsc\Ressources.hpp`.
- `description.ext:56` includes `Rsc\Dialogs.hpp`.
- `description.ext:58` includes `Rsc\Titles.hpp`.

Two dialog classes share `idd = 23000`:

| Resource | Evidence | Runtime owner |
| --- | --- | --- |
| `RscMenu_EASA` | `Rsc/Dialogs.hpp:3209-3211` | `Client/GUI/GUI_Menu_EASA.sqf` |
| `RscMenu_Economy` | `Rsc/Dialogs.hpp:3287-3289` | `Client/GUI/GUI_Menu_Economy.sqf` |

Two title resources share `idd = 10200`:

| Resource | Evidence | Runtime owner |
| --- | --- | --- |
| `RscOverlay` | `Rsc/Titles.hpp:44-46` | Started from `Client/Init/Init_Client.sqf:149` on cutRsc channel 1365. |
| `OptionsAvailable` | `Rsc/Titles.hpp:164-165` | Started from `Client/FSM/updateavailableactions.fsm:62` and `Client/Client_UpdateRHUD.sqf:7`. |

There is no standalone `Client/RHUD` subtree in the current source. RHUD is folded into `OptionsAvailable` plus `Client/Client_UpdateRHUD.sqf`, so title-ID repair must preserve that display-owner relationship.

Wave Q added a separate title-display ownership finding. `EndOfGameStats` uses `idd = 90000` (`Rsc/Titles.hpp:532-533`), but it shares the same `onLoad`/`onUnload` helper scripts and therefore the same `uiNamespace["currentCutDisplay"]` key as `OptionsAvailable` (`Titles.hpp:539-540`). `Client/GUI/GUI_EndOfGameStats.sqf:13` cuts `EndOfGameStats`, then waits for and writes controls through `currentCutDisplay` at `:34-44` and `:86-93`. Meanwhile `Client/Client_UpdateRHUD.sqf:183-190` keeps its one-second loop alive and `_RHUDGetDisplay` can re-cut `OptionsAvailable` when the shared key is null (`:89-92`). This is a handle collision even if all `idd` values are made unique.

## Why It Is A Risk

In Arma 2 OA UI terms, duplicated `idd` makes `findDisplay 23000` or `findDisplay 10200` ambiguous when more than one matching display can exist or when future code assumes uniqueness.

The dialog collision is more actionable because EASA and Economy both sit near the same control ID range:

- `GUI_Menu_EASA.sqf:7` uses listbox control `23003`.
- `GUI_Menu_Economy.sqf:3` receives a display handle and uses `DisplayCtrl 23002`.

Current normal flow reduces the chance of an immediate player-visible bug:

- `GUI_Menu.sqf:171` closes the previous dialog before opening Economy.
- `GUI_Menu_Service.sqf:243` closes the previous dialog before opening EASA.

The title IDD collision is less likely to break creation because `cutRsc` addresses resources by class/layer, but it can still confuse ID-based debug, `findDisplay`, or future display-control lookup. The `currentCutDisplay` collision is more direct: two unrelated title resources write through the same stored handle, so unloading or recreating one title can make another title's controller read the wrong display.

## Patch Shape

Keep the first patch small:

1. Assign a new unique `idd` to one of `RscMenu_EASA` or `RscMenu_Economy`.
2. Audit all `findDisplay 23000` and hard-coded display assumptions before changing scripts.
3. Keep existing `idc` values unless a specific control collision is proven after the dialog ID change.
4. Assign a distinct `idd` to either `RscOverlay` or `OptionsAvailable`.
5. Keep title IDD cleanup separate from title display-variable cleanup.
6. Split title display handles so `OptionsAvailable`/RHUD/action icons and `EndOfGameStats` do not share `currentCutDisplay`. Either add separate helper scripts/keys or make the helper accept the key name explicitly.
7. If the minimal patch instead gates RHUD/action-icon recreation during endgame, still avoid making endgame stat rendering depend on an action-HUD-owned key.

Do not combine this with EASA balance generation or Economy authority changes. This is resource hygiene and future-proofing.

## Generated And Modded Copies

The same collisions are expected in generated Vanilla Takistan and full modded mission copies. Patch source Chernarus first, propagate generated Vanilla with `Tools/LoadoutManager`, and treat modded copies as a separate maintenance decision.

## Validation

Source-only:

- `RscMenu_EASA` and `RscMenu_Economy` have distinct `idd` values.
- `RscOverlay` and `OptionsAvailable` have distinct `idd` values.
- `OptionsAvailable`/RHUD/action icons and `EndOfGameStats` no longer set/clear the same `uiNamespace` display key.
- Any `findDisplay 23000` / `findDisplay 10200` references are updated or proven safe.

Arma smoke:

- EASA opens from service menu and applies/returns as before.
- Economy opens from main menu and income/sell/supply-truck controls still render.
- RHUD/FPS HUD still appears and updates.
- Action availability icons still appear.
- Endgame stat bars populate after match end with RHUD/FPS toggled on and off.
- Unloading endgame stats does not clear the action/RHUD display handle unless endgame intentionally disables that surface.
- No title resource flicker/regression during map/menu transitions.

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
