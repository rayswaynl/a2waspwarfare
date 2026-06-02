# Zargabad Low-Pop Release Audit

This audit records the source-only and local-tool evidence for the Zargabad low-pop mission in PR #9. It is not a replacement for an Arma 2 OA hosted or dedicated playtest.

## Mission Scope

- Generated mission: `Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad`
- Source support logic: `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- Branch: `feature/zargabad-map`
- Latest audited commit before this document: `d376afde`

## Placement Audit

The current layout keeps the highest SV objectives in the city, markets, north/south districts and airfield while using farms/outskirts as lower-value flank objectives.

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

Zargabad uses a `6000` boundary in `Common/Init/Init_Boundaries.sqf`; the current static check reports zero town/camp/airport/start logics outside that square.

## Balance Audit

Runtime Zargabad overrides in `Init_CommonConstants.sqf` reduce smaller-map abuse:

- Shorter fast travel, respawn camp, UAV, hangar purchase, mortar, support/service and artillery ranges.
- Lower player/AI caps and lower aircraft countermeasures.
- Lower supply cap and lower lobby starting funds/supply defaults.
- Higher base defense manning and base protection range for spawn safety.

Runtime Zargabad price multipliers in `Init_Common.sqf` make infantry slightly cheaper while raising light, heavy, air and airport unit costs. This reduces vehicle spam without removing the low-pop infantry fight.

The normal factory lists are restricted away from MBTs and heavy attack aircraft. Airport ownership remains valuable, and the black-market cache gives the airfield a cheap extra reason to contest it.

## Fortification And Defense Audit

`Server/Init/Init_Zargabad.sqf` adds side-owned start fortifications and statics for WEST/EAST. Extra synchronized town-defense logics were added around the city approaches, airfield, farms and outer chokepoints.

Static validation currently proves the editor data shape, not tactical effectiveness. Dedicated playtest still needs to verify:

- Spawn-to-spawn and spawn-to-city sightlines.
- Whether side statics can be trivially sniped or stolen.
- Whether extra town AT/AA/MG/GL defenses face useful routes after terrain placement.
- Whether north/east side hills still allow unfair shelling or overwatch.

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
- `git diff --check`
- `git diff --cached --check`
- Static mission validation: unique ids, all sync ids resolvable, no out-of-6000 Zargabad logic positions, 13 towns, 19 camps, 1 airport, 33 defense logics, start SV 185, max SV 648.

Known verification gap: no in-game Arma 2 OA hosted/dedicated/JIP/HC smoke has been run from this environment.

## Required Playtest Gates

Use `Guides/zargabad-low-pop-test-plan.json` as the machine-readable checklist. The goal should not be considered fully complete until at least the hosted or dedicated boot/town/economy/base-sightline gates pass with RPT evidence.
