# UI IDD Collision Repair

This page owns the current UI resource-ID collision repair lane.

## Confirmed Collisions

| Collision | Source-backed status |
| --- | --- |
| EASA / Economy menu | `RscMenu_EASA` and `RscMenu_Economy` both use `idd = 23000` in `Rsc/Dialogs.hpp` per the Feature Status DR-17/DR-25a trace. |
| Overlay / options title | `RscOverlay` and `OptionsAvailable` both use `idd = 10200` in `Rsc/Titles.hpp` per the same trace. |

## Risk Model

| Risk | Notes |
| --- | --- |
| Runtime ambiguity | Normal dialog flow closes prior menus, so the collision is a maintenance/runtime hazard more than a guaranteed visible breakage. |
| `findDisplay` assumptions | Any script that finds a display by ID can hit the wrong resource after future UI changes. |
| Patch blast radius | IDs are cross-referenced by scripts, dialogs and title resources, so repair should be source-search driven. |

## Patch Shape

| Step | Gate |
| --- | --- |
| Assign unique IDs | Pick unused IDs for EASA, Economy, overlay and options resources. |
| Audit consumers | Search for each old/new ID in `Client`, `Rsc` and WASP UI code before patching. |
| Update references | Change only the resource IDs and exact consumers that depend on them. |
| Smoke UI flows | Open EASA, Economy, overlays/options and any title display using the changed IDs. |

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [Testing workflow](Testing-Debugging-And-Release-Workflow)

Main map: [Home](Home) | Risk register: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
