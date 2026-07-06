# ARCHIVE-CTI-CATALOG

Status: PARTIAL-SPEC. Exhaustive lane blocked in this sandbox because `E:\arma2-cache` is outside the readable workspace. This file is a builder-ready catalog seed plus the exact operator procedure to complete the full sweep.

Guide rev for downstream PR bodies: GR-2026-07-03a.

## Blocker

Roster lane 446 requires mining every Warfare/CTI/AI-commander archive under `E:\arma2-cache`. The current sandbox permits the worktree and temp paths only, so the full archive tree cannot be listed, extracted, or verified here.

Do not treat this file as the final exhaustive archive census until the owner or orchestrator runs the completion procedure on the Main PC.

## Completion Procedure For Main PC

1. Open PowerShell on the Main PC where `E:\arma2-cache` is mounted.
2. Create a scratch directory outside the repo, for example `C:\tmp\a2wasp-cti-sweep`.
3. Enumerate archive names:
   ```powershell
   Get-ChildItem -LiteralPath E:\arma2-cache -Recurse -File |
     Where-Object { $_.Extension -match '\.(7z|zip|rar|pbo)$' } |
     Select-Object FullName,Length,LastWriteTimeUtc |
     Export-Csv C:\tmp\a2wasp-cti-sweep\archive-index.csv -NoTypeInformation
   ```
4. Filter likely mission archives by filename/path keywords: `warfare`, `cti`, `crcti`, `mcti`, `benny`, `gossamer`, `superpowers`, `commander`, `hetman`, `hac`, `domination`, `patrolops`.
5. Extract passworded `*_WithPW.7z` with password `armedassault`. The inner archive is not passworded.
6. For PBOs, depbo into scratch only. Do not paste raw SQF into this catalog.
7. For every hit, fill one row in the final table below.
8. Flag GPLv3 archives before any borrow recommendation.

## Required Row Fields

| Field | Meaning |
| --- | --- |
| Archive | Filename or bIdentify id. |
| Lineage | Benny WF fork, crCTI-derived, MCTI, BIS vanilla, HETMAN/HAC, Domination, Patrol Ops, other. |
| Map/Package | Mission map or package scope. |
| Commander loop | How side-level decisions are made. |
| Economy | Income, supply, salvage, logistics, or reward model. |
| Town capture | How towns/sectors flip. |
| Faction structure | Side/faction assumptions and dependencies. |
| Notable modules | Script modules worth reading. |
| Absent from WASP | Pattern WASP does not currently have. |
| License | Known license or unknown. |
| Borrow verdict | Design lead only, candidate, skip. |

## Seed Catalog From Existing Repo Research

| Archive | Lineage | Commander loop | Economy | Town capture | Notable modules | Absent from WASP | License | Borrow verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Oden Warfare Pack 1.05h / Warfare16 | Benny WF 1.6-era ancestor | Same broad `Server/AI/Commander/` shape as WASP; includes centroid influence and air-assault branch | Stubbed supply truck and salvager commander actions | Warfare town model | `Commander_SupplyTruckAction.sqf`, `Commander_SalvagerAction.sqf`, `Oden/airAssault.sqf` | Island-index air assault, AI logistics/salvage sub-behaviors | BIS Warfare lineage | Top design mine, no raw copy. |
| WarfareV2_073LiteCO.zip / bIdentify 5420 | Benny WF 2.073 parent | Parent baseline for WASP fork | Parent BE economy | Parent BE town capture | Full parent mission tree | Exact parent delta recovery | BIS Warfare lineage | Top baseline diff. |
| WarfareV2_072LiteOA.7z / bIdentify 5418 | Benny WF 2.072 | Adjacent-version baseline | Adjacent BE economy | Adjacent BE capture | Full mission | 2.072 to 2.073 delta context | BIS Warfare lineage | Secondary baseline. |
| Gossamers_Warfare_v3_04d_CO_FullPack.7z / bIdentify 5419 | Non-Benny CTI/Warfare | Independently reworked commander/garrison concepts | Independent economy tuning | Gossamer town-garrison model | Garrison and AI town scripts | Alternative garrison consolidation | Unknown | Top non-Benny design mine. |
| crcti_mpmissions / crcti_WARFARE_03 | crCTI-derived | Group order dialogs and CRC/Mando patterns | Distinct CTI income and support style | Hold-towns countdown-to-win | `TimeUntilTownWin.sqs`, group-order UI | Countdown endgame pressure, param bitmask trick | Community, verify | Candidate idea only. |
| PromanMissions_v02-28-2012.7z / bIdentify 5299 | crCTI Proman | Mature crCTI team/order loop | Rich crCTI upgrades/purchasing | CTI town model | Upgrade and AI-team ordering scripts | Alternative upgrade/order UI | Unknown | Read after parent/Gossamer. |
| mcti_r9_40vs40.Chernarus | MCTI | Compact `mca_ai_commander.sqf` | Compact CTI economy | Radio terminal captures | `mca_ai_commander.sqf` | Commander narrates each build | Community, verify | Narration idea only; avoid JIP-unsafe init patterns. |
| mcti_r10_40vs40.Chernarus.rar / bIdentify 3139 | MCTI | Newer large-scale MCTI | Large-player economy | Chernarus CTI capture | Mission scripts | Scale comparison on WASP map | Unknown | Read if available. |
| HETMAN HAC_v1.47.7z / bIdentify 4220 | HETMAN/HAC | Full side-level field commander with threat assessment, allocation, objective priority | Not CTI economy-first | Objective driven | HAC SQF decision architecture | Rich commander planning heuristics | Rydygier, verify | Required V2 prior-art mine, do not deploy. |
| Domination West-AI / bIdentify 3146 | Domination | Objective cycling and AI tasking | Co-op reward/objective model | Objective clear/cycle | West-AI target cycling, MHQ patterns | Objective-cycling and JIP patterns | Xeno/community, verify | Design mine only. |
| Patrol Operations 2 / bIdentify 5321 | Patrol Ops | Dynamic task generation with HC/JIP patterns | Task reward model | Task objective model | HC offload and JIP modules | HC/JIP architecture lessons | Roy86/community, verify | HC/JIP mine. |
| DAC V3 | Dynamic AI Creator | Zone director, not CTI commander | Spawn-budget model | Zone/camp behavior | `DAC_Config_Waypoints.sqf`, behavior tables | Terrain-aware waypoint validation | Silola/DAC, verify | Patrol/garrison tuning reference. |
| R3F Arty and Log 1.3 | Logistics/support | Not a commander | Object load/tow/lift and arty logistics | None | R3F logistics scripts | Player logistics carry layer | GPLv3 | License caution; design-only unless owner approves GPL. |

## Ranked Top 5 Borrow-As-Design Picks

1. HETMAN/HAC commander allocation heuristics: best external model for force allocation and objective prioritization. Use concepts only, behind V2 pure planning core.
2. Benny 2.073 parent baseline: exact parent delta prevents rebuilding behavior WASP deliberately changed.
3. Oden Warfare16 island-index air assault: directly matches Utes/island and amphibious insertion needs without relying on unreliable boat AI.
4. Gossamer garrison model: best non-Benny comparison for town defense and consolidation.
5. Patrol Ops 2 HC/JIP modules: useful for locality-first and JIP-safe V2 implementation patterns.

## House Rules For Borrowing

- No raw SQF pasted into design specs.
- No Arma 3 docs or A3-only commands.
- GPLv3 code requires owner approval before any port.
- TPWCAS, doctrine personalities, AI supply trucks, and ACR content are owner-rejected or already scoped out unless owner explicitly reopens them.
- Borrow architecture, thresholds, and behavior grammar; implement clean-room in WASP style.

