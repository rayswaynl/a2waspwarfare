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

## Balance Audit

Runtime Zargabad overrides in `Init_CommonConstants.sqf` reduce smaller-map abuse:

- Shorter fast travel, respawn camp, UAV, hangar purchase, mortar, support/service and artillery ranges.
- Lower player/AI caps and lower aircraft countermeasures.
- Lower supply cap and lower lobby starting funds/supply defaults.
- Higher base defense manning and base protection range for spawn safety.

`Tools/Validate-ZargabadMission.ps1` now locks the exact Zargabad smaller-map constants in both the source support mission and generated Zargabad mission: AI caps, player squad caps, team supply cap, fast travel, UAV spotting, respawn, command-center, town build/defense/mortar/patrol, support/service, aircraft countermeasures, and base-defense manning/protection.

Runtime Zargabad price multipliers in `Init_Common.sqf` make infantry slightly cheaper while raising light, heavy, air and airport unit costs. This reduces vehicle spam without removing the low-pop infantry fight.

The normal factory lists are restricted away from MBTs and heavy attack aircraft. Airport ownership remains valuable, and the black-market cache gives the airfield a cheap extra reason to contest it.

## Fortification And Defense Audit

`Server/Init/Init_Zargabad.sqf` adds side-owned start fortifications and statics for WEST/EAST. Extra synchronized town-defense logics were added around the city approaches, airfield, farms and outer chokepoints. During Zargabad init, the server orients those 33 defense logics toward their linked town centers before town defenses can spawn, so statics do not all inherit default north-facing editor direction.

Static validation now checks town-defense placement quality, not only count: every synchronized defense logic sits between 90m and 325m from its town center, so defenses cover approaches instead of spawning on top of the depot or far outside the fight. City center and airfield each require at least five defenses, while North District, South District, Northwest Base and Rahim Villa each require at least three.

The same init now builds a WDDM-compatible `WFBE_ZARGABAD_CENTRAL_WALL` defense template centered at `3425,3375` and angled at `316` degrees, roughly perpendicular to the southwest-to-northeast base axis. It uses six separated H-barrier runs with pass-through gaps, so the flat middle has broken sightlines without turning the map into two sealed halves.

Static validation currently proves the editor data shape, not tactical effectiveness. Dedicated playtest still needs to verify:

- Spawn-to-spawn and spawn-to-city sightlines.
- Whether side statics can be trivially sniped or stolen.
- Whether the central wall gaps are wide enough for normal infantry, light armor and AI movement while still interrupting easy flat-map fire lanes.
- Whether extra town AT/AA/MG/GL defenses face useful routes after the runtime orientation pass and terrain placement.
- Whether north/east side hills still allow unfair shelling or overwatch outside the guarded rim.
- Whether the edge guard logs once on init, ignores objective-side fights, and removes only sustained extreme-rim ground abuse.

## Mystery Feature

`Server/Module/Zargabad/Zargabad_BlackMarket.sqf` is a Zargabad-only airfield cache event:

- Server-only and Zargabad-guarded.
- Waits for town initialization.
- Requires WEST or EAST ownership of `Zargabad Airfield`.
- Reuses existing side para-ammo arrays and smoke/trash handling.
- Current non-empty line count: 35.

## Verification Completed

- `A2WASP_SKIP_ZIP=1 dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj`
- `dotnet build Tools\LoadoutManager\LoadoutManager.csproj --no-restore`
- `dotnet build DiscordBot\DiscordBot.csproj --no-restore`
- `powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadMission.ps1`
- `git diff --check`
- `git diff --cached --check`
- Static mission validation: unique ids, all sync ids resolvable, no out-of-6000 Zargabad logic positions, intended default starts/headings and WEST/EAST separation, 13 towns, 19 camps, 1 airport, 33 defense logics, each camp linked to one town, camps in the 90m-225m town-flow band, high-value towns with two camp approaches, start SV 185, max SV 648, defense orientation hook present.

`Tools/Validate-ZargabadMission.ps1` is the repeatable local validator for this PR. It parses the generated Zargabad `mission.sqm`, checks town/camp/airport/start/defense counts, sync targets, 6000m boundary containment, default start anchors/headings/separation, SV totals, town camp/defense coverage, camp distance bands, defense approach distances, high-value objective defense depth, smaller-map economy/range/cap constants, runtime defense-orientation hook, mystery feature LOC, edge-guard LOC/hooks, central-wall template/gaps, and Takistan spillover.

`Tools/Validate-ZargabadRuntimeEvidence.ps1` is the repeatable RPT validator for Claude/runtime testers. It checks that Zargabad appears in supplied RPT logs, server/town/Zargabad/edge-guard init completed, the town-defense orientation pass handled all 33 defense logics, runtime audit count/SV/base/factory/price/economy evidence appears, optional JIP/HC/edge-removal/black-market evidence appears when requested, and common Arma missing-script/dependency/expression failures are absent.

`Tools/New-ZargabadRuntimeReport.ps1` wraps the runtime validator and emits a compact markdown gate snapshot, failure scan, key RPT excerpts, and Claude note prompts. Claude should paste this report back to Codex after each hosted/dedicated/JIP/HC pass so runtime findings are frequent, evidence-backed, and easy to act on.

`Server/Module/Zargabad/Zargabad_RuntimeAudit.sqf` is launched from `Init_Zargabad.sqf` and logs the runtime town/camp/airport/defense counts, start/max SV totals, WEST/EAST base positions and separation, base static/wall counts, exact WEST/EAST base static templates, normal factory restriction counts, price multiplier/sample values, and core Zargabad economy/range/base-defense/edge-guard constants. This gives Claude a concrete RPT target for checking that the in-game mission matches the static map audit.

Known verification gap: no in-game Arma 2 OA hosted/dedicated/JIP/HC smoke has been run from this environment.

## Required Playtest Gates

Use `Guides/zargabad-low-pop-test-plan.json` as the machine-readable checklist and `Guides/Zargabad-Claude-Runtime-Handoff.md` as the Claude/runtime handoff. The goal should not be considered fully complete until at least the hosted or dedicated boot/town/economy/base-sightline gates pass with RPT evidence.
