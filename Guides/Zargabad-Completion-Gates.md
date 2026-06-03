# Zargabad Completion Gates

This file maps the original Zargabad mission objective to the evidence needed before Codex can tell Claude to stop.
Static validation is necessary, but not enough: final completion requires real Arma 2 OA hosted/dedicated runtime evidence, with JIP/HC evidence when those gates are claimed.

## Objective Coverage

| Requirement | Static proof | Runtime proof |
| --- | --- | --- |
| Fully build out the Zargabad mission | `Tools/Validate-ZargabadMission.ps1` proves the generated mission exists, object syncs resolve, and expected town/camp/airport/start/defense counts are present. | Hosted and dedicated RPTs reach server/client init end without missing script, dependency, expression, vehicle/object creation, or WFBE class/loadout failures. |
| Bases are safe and meaningful | Static validation locks WEST/EAST start anchors, separation, base fortification templates, base static templates, and expected runtime static anchors. | Screenshots/coordinates prove no trivial spawn-to-spawn suppression, statics are manned and face useful arcs, and commander construction space remains usable with `baseFootprint [35,45,74,78]`. |
| SP/SV, town centers, and camps match likely population | Static validation locks the 13 town population/value anchors, start/max SV totals, value tiers, city-belt SV share, camp links, and camp distance bands. | Claude compares map-audit Population Flow/value tiers with screenshots/coordinates for city, airfield, district/market belt, farms/outskirts, camps, and any town center that feels misplaced. |
| Defense units spawn where they make sense | Static validation locks all 33 defense anchors, linked towns, approach-distance bands, and priority objective defense-kind mixes. | Runtime notes prove town defenses orient toward linked town centers, wake and fight on useful routes, do not block normal movement, and key visual rows include screenshot filenames. |
| Economy is balanced for the smaller map | Static validation locks Zargabad lobby defaults, supply caps, price multipliers, compact factory lists, and forbidden normal-factory heavy/attack exclusions. | Runtime buy-menu and gameplay notes prove city/airfield value, factory availability, and price pressure feel sane for low-pop 5v5-style play without runaway vehicle or air spam. |
| Weapons, vehicles, units, ranges, costs, and maximums fit map size | Static validation locks smaller-map AI/player caps, missile/UAV/town defense/mortar/patrol/support/fast-travel/purchase ranges, countermeasures, and exact factory lists. | RPT runtime audit and Claude notes confirm the active values and whether combat pressure feels sane on Zargabad terrain. |
| Flat middle and steep side hills cannot be abused | Static validation locks the 6000m boundary, 120m rim band, 325m objective safe bubbles, legal/illegal named rim test points, and central wall geometry. | Runtime rim tests prove illegal edge points are removed, legal objective-side rim fights are allowed, aircraft are exempt, and wall/pathing screenshots show the flat middle is interrupted without sealing the map. |
| Beefier defenses and fortifications prevent easy base hits | Static validation locks the base H-barrier rings, base statics, WDDM-compatible central H-barrier wall, uncrewed wall intent, and town-defense depth. | Screenshots/RPT prove fortifications spawn, central wall reports `centralWallCrewed [0]`, wall gaps pass infantry/light armor/AI, and defenses do not create unfair armed middle-map traps. |
| Fortification review uses WDDM when changes are proposed | The map audit packet and handoff document the WDDM URL, coordinate convention, origin/direction, and `CreateDefenseTemplate` flattening caveat. | Claude returns WDDM-exported SQF or coordinate deltas plus screenshots/coordinates before Codex changes base walls or the central wall. |
| Mystery feature uses existing mission code cheaply and stays under 100 LOC | Static validation proves `Zargabad_BlackMarket.sqf` is Zargabad-only, server-only, under 100 non-empty LOC, airfield ownership gated, and reuses para-ammo/smoke/trash cleanup logic. | RPT proves the feature arms after town init, surfaces only for WEST/EAST airfield ownership, spawns crate/smoke, and logs cleanup release. |
| Codex and Claude work together until Codex says stop | `Tools/New-ZargabadClaudeBrief.ps1`, `Tools/New-ZargabadRuntimeReport.ps1`, and `Tools/Validate-ZargabadRuntimeReport.ps1` define the coordination packet, report format, and stop/go validator. | Claude supplies runtime reports with PASS/FAIL/UNCERTAIN rows, row-specific evidence, screenshot filenames for key visual rows, and keep/tune/revert/investigate/patch/retest recommendations. |

## Stop Rule

Codex can tell Claude to stop only after all objective rows above have current evidence and `Tools/Validate-ZargabadRuntimeReport.ps1` passes with the switches for the claimed test scope:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeReport.ps1 -ReportPath ".\zargabad-runtime-report.md" -EvidenceRoot ".\zargabad-evidence" -RequireJip -RequireHeadlessClient -RequireEdgeGuardRemoval -RequireEdgeGuardSafeAllow -RequireNamedRimPoints -RequireBlackMarket
```

If a gate is untested, uncertain, or proven only by source inspection when runtime behavior is required, the mission is still in progress.
