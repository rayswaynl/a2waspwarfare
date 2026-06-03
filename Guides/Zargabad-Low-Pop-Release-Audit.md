# Zargabad Low-Pop Release Audit

This audit records the source-only and local-tool evidence for the Zargabad low-pop mission in PR #9. It is not a replacement for an Arma 2 OA hosted or dedicated playtest.

## Mission Scope

- Generated mission: `Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad`
- Source support logic: `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Branch: `feature/zargabad-map`
- Latest audited branch state: `feature/zargabad-map` PR head including the edge-guard, central-wall, static-validator and runtime-evidence-validator passes.

## Placement Audit

The current layout keeps the highest SV objectives in the city, markets, north/south districts and airfield while using farms/outskirts as lower-value flank objectives.

Static camp validation now requires every camp to link to exactly one town, all 19 camps to sit in a 90m-225m band from their linked town centers, and the city center, airfield, north/south districts, Northwest Base and Rahim Villa to each have two camp approaches. This keeps camps close enough to plausible populated/road flow while avoiding camp markers stacked directly on the town core.

| Objective | Position | Start SV | Max SV | Range | Placement intent |
| --- | ---: | ---: | ---: | ---: | --- |
| Zargabad City Center | `4075,3950` | 30 | 95 | 380 | Primary population center and central fight anchor. |
| Zargabad Airfield | `2980,5200` | 20 | 75 | 300 | High-value tech/airfield objective without full-map snowball income. |
| Zargabad North District | `4140,4750` | 15 | 60 | 240 | Dense northern approach into the city. |
| Zargabad South District | `4170,3150` | 15 | 60 | 240 | Dense southern approach into the city. |
| East Market | `4960,3940` | 15 | 55 | 190 | Eastern urban/road objective between city and edge approaches. |
| Northwest Base | `2500,5600` | 15 | 55 | 220 | Airfield/northwest military-style contest point. |
| Rahim Villa | `4450,5750` | 15 | 50 | 180 | Northern settlement/objective pulled inside the 6000m boundary. |
| West Suburbs | `3300,3800` | 10 | 40 | 160 | Lower-value western city approach. |
| North Camp | `3600,5650` | 10 | 38 | 150 | Low-value northern hill/edge approach, pulled away from boundary exploitation. |
| East Farms | `5650,4300` | 10 | 30 | 130 | Low-value eastern flank objective inside boundary. |
| South Farms | `4320,2050` | 10 | 30 | 130 | Low-value southern flank objective. |
| West Farms | `2250,3350` | 10 | 30 | 130 | Low-value western flank objective. |
| Southern Outskirts | `3000,1850` | 10 | 30 | 130 | Low-value southern approach objective. |

Totals from static validation: 13 towns, 19 camps, 1 airport, 33 town-defense logics, start SV 185, max SV 648.

## Starts And Boundary

| Start | Position | Intent |
| --- | ---: | --- |
| WEST southwest | `1500,1550` | Keeps WEST away from the main city/airfield belt and leaves a route through southern/western lower-value objectives. |
| EAST northeast | `5350,5200` | Keeps EAST near the northeast edge but inside the 6000m square after the anti-edge pass. |
| Resistance central | `4100,3950` | Keeps neutral/resistance initialization near the main city area. |

Zargabad uses a `6000` boundary in `Common/Init/Init_Boundaries.sqf`; the current static check reports zero town/camp/airport/start logics outside that square. Static validation also locks the intended default start anchors: WEST stays near `1500,1550` facing `45`, EAST stays near `5350,5200` facing `225`, Resistance stays near `4100,3950`, and WEST/EAST remain at least 5000m apart for spawn safety.

`Server/Module/Zargabad/Zargabad_EdgeGuard.sqf` adds a server-side rim guard for the extreme outer 120m of that square. Ground players and their vehicles are removed after 45s in the rim unless they are within 325m of a start, town, camp or airport logic. This is deliberately conservative: it backs up the client off-map kill and deters side-hill/edge camping without banning legitimate fights around Rahim Villa, North Camp, East Farms or the airfield.

Static validation now also checks the edge-safe footprint: no start/town/camp/airport logic sits inside the 120m kill rim, exactly seven objective/start logics create 325m edge-safe bubbles, and those bubbles are limited to the north/east flank (`y >= 5680` or `x >= 5770`). The map audit packet also emits named rim test points: illegal ground tests at `80,3000`, `3000,80`, `5900,3000`, and `3000,5900`, plus legal objective-side tests inside the rim at `3600,5900`, `4330,5900`, and `5900,4340`. This keeps side-hill fights near real objectives legal while preventing broad safe corridors around the outer map.

## Balance Audit

Runtime Zargabad overrides in `Init_CommonConstants.sqf` reduce smaller-map abuse:

- Shorter fast travel, respawn camp, UAV, hangar purchase, mortar, support/service and artillery ranges.
- Lower player/AI caps and lower aircraft countermeasures.
- Lower supply cap and lower lobby starting funds/supply defaults.
- Higher base defense manning and base protection range for spawn safety.

`Tools/Validate-ZargabadMission.ps1` now locks the exact Zargabad smaller-map constants in both the source support mission and generated Zargabad mission: AI caps, player squad caps, team supply cap, fast travel, UAV spotting, respawn, command-center, town build/defense/mortar/patrol, support/service, aircraft countermeasures, and base-defense manning/protection.

The same validator also checks the generated Zargabad `Rsc/Parameters.hpp` defaults produced by LoadoutManager: lower start funds/supply, team supply cap, missile range, hard town defenders, medium occupation, reduced town build protection, locked defender vehicles, and base-defense manning range. This keeps hosted/dedicated tests from silently starting with broad-map defaults.

Runtime Zargabad price multipliers in `Init_Common.sqf` make infantry slightly cheaper while raising light, heavy, air and airport unit costs. This reduces vehicle spam without removing the low-pop infantry fight.

The normal factory lists are restricted away from MBTs, MLRS, SPAAGs, attack helicopters and attack jets. Static validation now parses the Zargabad override arrays in source and generated mission copies and requires the exact compact WEST/EAST heavy and aircraft lists before runtime testers spend time on buy-menu feel. Airport ownership remains valuable, and the black-market cache gives the airfield a cheap extra reason to contest it.

## Fortification And Defense Audit

`Server/Init/Init_Zargabad.sqf` adds side-owned start fortifications and statics for WEST/EAST. The runtime audit now reports `baseFootprint [35,45,74,78]` for commander-clear radius, nearest static radius and H-barrier ring min/max radius, giving Claude a concrete base-interior screenshot target. Extra synchronized town-defense logics were added around the city approaches, airfield, farms and outer chokepoints. During Zargabad init, the server orients those 33 defense logics toward their linked town centers before town defenses can spawn, so statics do not all inherit default north-facing editor direction.

Static validation now checks town-defense placement quality, not only count: every synchronized defense logic sits between 90m and 325m from its town center, so defenses cover approaches instead of spawning on top of the depot or far outside the fight. City center and airfield each require at least five defenses, while North District, South District, Northwest Base and Rahim Villa each require at least three. The validator also parses each `wfbe_defense_kind` mix: city requires MG/nest, GL and AT coverage; airfield requires MG/nest, AT and at least two AA defenses; the layered district/base/villa objectives require MG-or-nest plus AT; and Northwest Base keeps an AA defense for the northern air approach.

The same init now builds a WDDM-compatible `WFBE_ZARGABAD_CENTRAL_WALL` defense template centered at `3425,3375` and angled at `316` degrees, roughly perpendicular to the southwest-to-northeast base axis. It uses six separated H-barrier runs with pass-through gaps, so the flat middle has broken sightlines without turning the map into two sealed halves. Runtime audit records gap checkpoints near `[4053,2725]`, `[3789,2998]`, `[3504,3293]`, `[3195,3613]`, and `[2903,3915]` for Claude's infantry, light armor and AI pathing screenshots.

Fortification review should use Steff's WDDM tool at https://rayswaynl.github.io/WDDM/ for any proposed base-wall or central-wall edits. The map audit packet records the WDDM review anchor and coordinate convention (`+Y` front, `+X` right), so Claude can return exported SQF or coordinate deltas instead of ambiguous visual notes.

Static validation currently proves the editor data shape, not tactical effectiveness. Dedicated playtest still needs to verify:

- Spawn-to-spawn and spawn-to-city sightlines.
- Whether side statics can be trivially sniped or stolen.
- Whether the uncrewed central wall reports `centralWallCrewed [0]`, keeps gaps wide enough for normal infantry, light armor and AI movement, and still interrupts easy flat-map fire lanes without creating an armed middle-map kill strip.
- Whether extra town AT/AA/MG/GL defenses face useful routes after the runtime orientation pass and terrain placement.
- Whether north/east side hills still allow unfair shelling or overwatch outside the guarded rim.
- Whether the edge guard logs once on init, removes the illegal rim test points after the configured timeout, emits `allowed at safe edge rim` evidence for legal objective-side rim test points, and removes only sustained extreme-rim ground abuse.

## Mystery Feature

`Server/Module/Zargabad/Zargabad_BlackMarket.sqf` is a Zargabad-only airfield cache event:

- Server-only and Zargabad-guarded.
- Waits for server-side town initialization and logs its armed cache positions/timing before the random ownership-gated roll.
- Requires WEST or EAST ownership of `Zargabad Airfield`.
- Reuses existing side para-ammo arrays and smoke/trash handling.
- Keeps the crate out of normal trash cleanup during the event, releases it after 300 seconds, and logs both the cache surfacing and cleanup release to RPT.
- Current non-empty line count: 36.

## Verification Completed

- `A2WASP_SKIP_ZIP=1 dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj`
- `dotnet build Tools\LoadoutManager\LoadoutManager.csproj --no-restore`
- `dotnet build DiscordBot\DiscordBot.csproj --no-restore`
- `powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadMission.ps1`
- `git diff --check`
- `git diff --cached --check`
- Static mission validation: unique ids, all sync ids resolvable, no out-of-6000 Zargabad logic positions, no objective safe-zone logic inside the 120m edge kill rim, exactly seven north/east edge-safe objective/start bubbles, intended default starts/headings and WEST/EAST separation, 13 towns, 19 camps, 1 airport, 33 defense logics, each camp linked to one town, camps in the 90m-225m town-flow band, high-value towns with two camp approaches, priority objective defense-kind mixes, start SV 185, max SV 648, defense orientation hook present.

`Tools/Validate-ZargabadMission.ps1` is the repeatable local validator for this PR. It parses the generated Zargabad `mission.sqm`, checks town/camp/airport/start/defense counts, sync targets, 6000m boundary containment, edge-rim safe-zone footprint, default start anchors/headings/separation, SV totals, town camp/defense coverage, camp distance bands, defense approach distances, high-value objective defense depth and defense-kind mix, generated low-pop parameter defaults, smaller-map economy/range/cap constants, exact compact normal heavy/aircraft factory lists, forbidden heavy/attack normal-factory exclusions, runtime defense-orientation hook, mystery feature LOC, edge-guard LOC/hooks, central-wall template/gap geometry, and Takistan spillover.

`Tools/Validate-ZargabadRuntimeEvidence.ps1` is the repeatable RPT validator for Claude/runtime testers. It checks that Zargabad appears in supplied RPT logs, server/town/Zargabad/edge-guard init completed, the town-defense orientation pass handled all 33 defense logics, runtime audit count/SV/base/factory/compact-list/price/economy/range/weapon-pressure evidence appears, optional JIP/HC/edge-removal/edge-safe-allow/black-market spawn and cleanup evidence appears when requested, and common Arma missing-script/dependency/expression failures are absent.

`Tools/New-ZargabadRuntimeReport.ps1` wraps the runtime validator and emits a compact markdown gate snapshot, failure scan, key RPT excerpts, and Claude note prompts. Its Claude Notes table now has dedicated base-static-position and priority-defense-mix rows that point testers to actual spawned base static coordinates/facing plus the city, airfield, North/South District, Northwest Base and Rahim Villa defense rows from the map audit packet. Claude should paste this report back to Codex after each hosted/dedicated/JIP/HC pass so runtime findings are frequent, evidence-backed, and easy to act on.

`Tools/Validate-ZargabadRuntimeReport.ps1` is the stop/go checker for Claude's edited markdown report. It fails if the runtime validator did not pass, required gates are still `MISSING`, the failure scan contains `FOUND`, `_missing_` key-evidence placeholders remain, optional JIP/HC/edge/black-market gates requested by switches did not pass, or any Claude Notes row is still not `PASS`.

`Tools/New-ZargabadMapAuditPacket.ps1` emits a Claude-facing coordinate packet from the generated Zargabad `mission.sqm`: population-flow objectives, camp links/distances, defense kind/position/distance rows, start positions, base-axis midpoint, edge-safe objective/start bubbles, rim test points, central-wall gap checkpoints, and screenshot targets. Use it beside runtime screenshots so map-placement, sightline, pathing and defense-facing feedback points to exact coordinates.

`Tools/New-ZargabadClaudeBrief.ps1` emits the current Codex-to-Claude context packet: latest commit, PR head, changed files, inferred retest focus, required runtime commands, dirty local state warning, and the rule that Codex owns final stop/go while accepting Claude's evidence-backed findings.

`Server/Init/Init_Zargabad.sqf` now also logs actual WEST/EAST base static runtime positions and facing after spawn. `Server/Module/Zargabad/Zargabad_RuntimeAudit.sqf` is launched from that init file and logs the runtime town/camp/airport/defense counts, start/max SV totals, WEST/EAST base positions and separation, base static/wall counts, base footprint, central-wall gap checkpoints, exact WEST/EAST base static templates, normal factory restriction counts, exact compact normal factory lists, price multiplier/sample values, and core Zargabad economy/range/base-defense/edge-guard/weapon-pressure constants. This gives Claude concrete RPT targets for checking that the in-game mission matches the static map audit.

Known verification gap: no in-game Arma 2 OA hosted/dedicated/JIP/HC smoke has been run from this environment.

## Required Playtest Gates

Use `Guides/zargabad-low-pop-test-plan.json` as the machine-readable checklist and `Guides/Zargabad-Claude-Runtime-Handoff.md` as the Claude/runtime handoff. The goal should not be considered fully complete until at least the hosted or dedicated boot/town/economy/base-sightline gates pass with RPT evidence.
