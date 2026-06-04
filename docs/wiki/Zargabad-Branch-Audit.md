# Zargabad Branch Audit

This page deep-audits `origin/feature/zargabad-map` as branch evidence, not stable-master source truth.

## What this branch is

`origin/feature/zargabad-map` head `1fdcb37a` is a full low-pop Zargabad terrain release candidate. It is not a small generated mission copy. The branch adds terrain/tooling support, a new `[31-2hc]` Vanilla Zargabad mission, source-mission runtime hooks and its own static/runtime evidence workflow.

- Head: `1fdcb37a` (`Point Claude brief to evidence checklist`)
- Merge base versus stable `origin/master`: `2cdf5fb8`
- Diff versus `origin/master`: 832 files, +77702/-95
- Changed path families: 792 files under `Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad`, 15 source Chernarus files, 14 `Tools/` files, 4 `DiscordBot/` terrain files, 4 `Guides/` files and 3 maintained Takistan files
- Static branch validation: `Tools/Validate-ZargabadMission.ps1` passed locally in a detached worktree at `1fdcb37a`
- Static cleanup gate: `git diff --check origin/master..origin/feature/zargabad-map` reports 3542 whitespace findings, concentrated in generated Zargabad mission files
- Tooling scope note: `git ls-tree -r --name-only origin/feature/zargabad-map` shows `Tools/Validate-ZargabadMission.ps1`, `Tools/Validate-ZargabadRuntimeEvidence.ps1` and `Tools/Validate-ZargabadRuntimeReport.ps1` on that branch, but those validators are not present in the current docs branch checkout. Re-run them from the feature branch or a worktree at the exact candidate head.

## Where it lives

| Area | Branch evidence |
| --- | --- |
| New Vanilla terrain class | `Tools/LoadoutManager/Data/Terrains/Implementations/VanillaMaps/ZARGABAD.cs:1-13` |
| Terrain enum registration | `Tools/LoadoutManager/Data/Terrains/TerrainName.cs:11-12` |
| Generator target list | `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs:127-130` writes Chernarus, Takistan and Zargabad |
| Packaging scope | `Tools/LoadoutManager/ZipManager.cs:15-44` still packages only `Missions` and `Missions_Vanilla`, so Zargabad joins the maintained Vanilla package family |
| New mission folder | `Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad/*` |
| Source flag | `initJIPCompatible.sqf:121-124` defines `IS_zargabad_lowpop_map` from `IS_ZARGABAD_LOWPOP_MAP` |
| Boundary | `Common/Init/Init_Boundaries.sqf:4-10` adds `zargabad` with a `6000` boundary |
| Smaller-map constants | `Common/Init/Init_CommonConstants.sqf:430-446` sets reduced ranges, caps and edge-guard constants |
| Runtime setup | `Server/Init/Init_Zargabad.sqf:1-125` builds base fortifications, central wall, statics, town-defense orientation and Zargabad modules |
| Edge guard | `Server/Module/Zargabad/Zargabad_EdgeGuard.sqf:1-45` removes ground vehicles lingering on unsafe map rim while allowing objective-safe rim bubbles |
| Black market feature | `Server/Module/Zargabad/Zargabad_BlackMarket.sqf:1-43` spawns temporary para-ammo caches near the airfield for WEST/EAST ownership |
| Runtime audit | `Server/Module/Zargabad/Zargabad_RuntimeAudit.sqf:1-114` logs counts, SV totals, fortifications, factory restrictions, price multipliers and range constants |
| Completion gates | `Guides/Zargabad-Completion-Gates.md:8-20` maps each owner objective to static proof and runtime proof |
| Runtime report validator | `Tools/Validate-ZargabadRuntimeReport.ps1:1-80` starts the report/evidence validator used after Arma runtime tests |

The branch also adds matching terrain records under `DiscordBot/src/ExtensionData/GameData/SharedWithLoadoutManager/Terrains/Implementations/VanillaMaps/ZARGABAD.cs`, keeping DiscordBot terrain metadata in step with LoadoutManager.

## How it runs

The generated mission uses `IS_ZARGABAD_LOWPOP_MAP` to turn on source-side Zargabad behavior. `initJIPCompatible.sqf:121-124` maps that preprocessor define into `IS_zargabad_lowpop_map`, and Zargabad-only server scripts exit immediately unless both `isServer` and `IS_zargabad_lowpop_map` are true.

`Init_Zargabad.sqf` is the branch runtime anchor. It:

- stores base wall and footprint evidence at `:5-15`;
- creates an uncrewed central H-barrier wall with gap offsets at `:17-28`;
- defines side-specific base static templates at `:30-33`;
- computes central wall gap world positions and builds the wall through `CreateDefenseTemplate` at `:35-44`;
- orients town-defense logics toward their linked town centers at `:47-65`;
- builds WEST/EAST base walls, base static guns and crews at `:68-112`;
- starts the edge guard, black market and runtime audit scripts at `:121-123`.

The branch deliberately puts some important checks into tooling. `Validate-ZargabadMission.ps1` statically validates the generated mission layout, sync links, town/camp/airport/start/defense counts, Zargabad constants, central wall, edge guard, black market, map-audit packet and report-validator plumbing.

## Static validation result

I ran the branch validator from a detached worktree at `origin/feature/zargabad-map` head `1fdcb37a`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadMission.ps1
```

Result: pass. Representative checks from the output:

| Check | Result |
| --- | --- |
| Mission object graph | duplicate mission object ids `0`, missing synchronization target ids `0` |
| Map counts | 13 towns, 19 camps, 1 airport, 9 start logics, 33 town-defense logics |
| Boundary | out-of-6000 Zargabad logic positions `0`; objective safe-zone logics inside edge-guard kill rim `0` |
| Economy anchors | start SV total `185`, max SV total `648`; value tiers descend from city/airfield to district/market to flank routes |
| Camps and defenses | every camp links to one town; all 33 defense anchors match expected placement/kind/distance checks |
| Starts | WEST/EAST starts separated for spawn safety; alternates avoid city-core overlap and 120m kill rim |
| Zargabad runtime helpers | edge guard, black market and runtime audit scripts are present, Zargabad-only and under the branch's size limits |
| Tooling | map audit packet, evidence folder helper, Claude brief, runtime report and runtime report validator are present and internally wired |
| Takistan spillover | validator reports no generated Zargabad module spillover into Takistan |

This is static confidence only. It proves the branch's own file/layout invariants; it does not prove Arma 2 OA can boot and play the mission without class, texture, script, JIP, HC or gameplay-balance problems.

## What depends on it

- LoadoutManager must treat Zargabad as a maintained Vanilla target, not a modded target.
- The generated `[31-2hc]` mission must stay in sync with Chernarus source hooks and Zargabad-specific skips.
- Server boot must run `Init_Zargabad.sqf` only on Zargabad and only on the server.
- Runtime evidence must include RPTs and screenshots because many branch goals are visual/pathing/balance claims.
- If Zargabad is promoted, future generator changes must keep Chernarus, Takistan and Zargabad behavior intentional rather than accidental.

## What is risky or incomplete

| Risk | Evidence | Why it matters |
| --- | --- | --- |
| Static validation is not runtime proof | `Guides/Zargabad-Completion-Gates.md:3-5` explicitly says final completion requires real Arma 2 OA hosted/dedicated runtime evidence, with JIP/HC evidence when claimed | Do not call the map playable or maintained on static checks alone. |
| Huge generated branch | 832 files, +77702/-95; 792 files under the new generated Zargabad mission folder | Merge/review burden is closer to a release branch than a feature branch. |
| Generated whitespace | `git diff --check origin/master..origin/feature/zargabad-map` reports 3542 findings | Clean or intentionally accept generated whitespace before release/PR polish. |
| Source hooks affect Chernarus source | 15 source Chernarus files changed, including unit/artillery configs, boundaries, constants, server init and Zargabad modules | Zargabad support is not isolated to the generated folder. Source hooks need regression review for normal Chernarus/Takistan behavior. |
| Runtime edge guard can kill vehicles | `Zargabad_EdgeGuard.sqf:13-33` damages non-air vehicles after 45 seconds in unsafe rim bands | Must be playtested for false positives, especially near legal objective-side rim fights. |
| Black market is balance-sensitive | `Zargabad_BlackMarket.sqf:23-40` periodically spawns para-ammo crates and smoke near airfield-controlled cache positions | Treat as a gameplay feature, not flavor text. It needs ownership, cleanup and economy balance smoke. |
| Central wall/pathing is visual and behavioral | `Init_Zargabad.sqf:17-28,35-44` creates central wall spans/gaps via `CreateDefenseTemplate` | Static positions do not prove AI/vehicle pathing or fair infantry flow. |
| Tooling now has a third maintained Vanilla target | `SqfFileGenerator.cs:127-130`; `ZipManager.cs:15-44` | Future agents must remember Zargabad when saying "maintained Vanilla" or running generation/packaging checks. |

## Promotion gates

Before anyone calls Zargabad playable, release-ready or maintained:

1. Clean or accept the 3542 whitespace findings in generated mission files.
2. Run and record branch-local `Tools\Validate-ZargabadMission.ps1` on the exact candidate head.
3. Boot hosted and dedicated Arma 2 OA Zargabad and collect RPTs without missing script/class/texture/vehicle creation failures.
4. Run JIP and HC smoke if those claims are made.
5. Capture screenshots/coordinates for bases, town/camp placement, defenses, central wall gaps, rim tests, economy/factory lists and black-market behavior.
6. Validate the runtime report with branch-local `Tools\Validate-ZargabadRuntimeReport.ps1`, using the required switches for the claimed test scope.
7. Decide whether Zargabad joins the long-term maintained Vanilla set or stays a branch-only low-pop experiment.

## Development lesson

Map branches need two separate definitions of done:

| Definition | Proof |
| --- | --- |
| Static map/build done | Generator target exists, mission folder exists, object syncs resolve, layout/count/value invariants pass and docs/tools agree. |
| Runtime gameplay done | Arma 2 OA hosted/dedicated/JIP/HC evidence proves the mission boots, classes load, pathing works, edge cases behave and balance is acceptable. |

For Zargabad, the first definition is strong. The second is still open until real runtime evidence is attached.

## Continue Reading

Previous: [Content structure and maps](Content-Structure-And-Maps) | Next: [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack)

Main map: [Home](Home) | Branch matrix: [Current source status snapshot](Current-Source-Status-Snapshot#2026-06-04-feature-branch-matrix) | Owner decisions: [Pending owner decisions](Pending-Owner-Decisions#branch-only-feature-promotion-decisions)
