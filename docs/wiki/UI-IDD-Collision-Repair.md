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

## Why It Is A Risk

In Arma 2 OA UI terms, duplicated `idd` makes `findDisplay 23000` or `findDisplay 10200` ambiguous when more than one matching display can exist or when future code assumes uniqueness.

The dialog collision is more actionable because EASA and Economy both sit near the same control ID range:

- `GUI_Menu_EASA.sqf:7` uses listbox control `23003`.
- `GUI_Menu_Economy.sqf:3` receives a display handle and uses `DisplayCtrl 23002`.

Current normal flow reduces the chance of an immediate player-visible bug:

- `GUI_Menu.sqf:171` closes the previous dialog before opening Economy.
- `GUI_Menu_Service.sqf:243` closes the previous dialog before opening EASA.

The title collision is less likely to break creation because `cutRsc` addresses resources by class/layer, but it can still confuse ID-based debug, `findDisplay`, or future display-control lookup.

## Patch Shape

Keep the first patch small:

1. Assign a new unique `idd` to one of `RscMenu_EASA` or `RscMenu_Economy`.
2. Audit all `findDisplay 23000` and hard-coded display assumptions before changing scripts.
3. Keep existing `idc` values unless a specific control collision is proven after the dialog ID change.
4. Assign a distinct `idd` to either `RscOverlay` or `OptionsAvailable`.
5. Prefer stored display handles such as `currentCutDisplay` / `uiNamespace` over ID lookup for title resources.

Do not combine this with EASA balance generation or Economy authority changes. This is resource hygiene and future-proofing.

## Generated And Modded Copies

The same collisions are expected in generated Vanilla Takistan and full modded mission copies. Patch source Chernarus first, propagate generated Vanilla with `Tools/LoadoutManager`, and treat modded copies as a separate maintenance decision.

## Validation

Source-only:

- `RscMenu_EASA` and `RscMenu_Economy` have distinct `idd` values.
- `RscOverlay` and `OptionsAvailable` have distinct `idd` values.
- Any `findDisplay 23000` / `findDisplay 10200` references are updated or proven safe.

Arma smoke:

- EASA opens from service menu and applies/returns as before.
- Economy opens from main menu and income/sell/supply-truck controls still render.
- RHUD/FPS HUD still appears and updates.
- Action availability icons still appear.
- No title resource flicker/regression during map/menu transitions.

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
