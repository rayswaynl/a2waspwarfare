# Audit Findings Queue — 2026-06-03

Source: a multi-agent code-audit sweep (Claude) over the WASP Warfare mission on branch
**`release/2026-06-feature-bundle`** (PR #8), mission folder
`Missions/[55-2hc]warfarev2_073v48co.chernarus/`. All `file:line` refs are against that branch.

**Purpose for wiki maintainers (codex / claude):** cross-reference these against the codebase and
existing wiki pages ([Deep Review Findings](Deep-Review-Findings),
[Client UI And Server Loop Perf Findings](Client-UI-And-Server-Loop-Perf-Findings),
[Bottleneck Removal Queue](Bottleneck-Removal-Queue),
[Abandoned Feature Revival Review](Abandoned-Feature-Revival-Review)). **Confirm whether each is real,
dedupe, and correct/close false positives.** ~1 in 4 deep-dived items needed correction, so treat
UNVERIFIED rows as *claims to check*, not facts.

**Verification legend:** ✅ verified real · ❌ false positive · ⚠️ real-but-nuanced / design-decision / verify-first · ⬜ UNVERIFIED (please cross-check)

> Earlier sweeps already triaged/partly shipped to PR #8 (logged in the owner's notes, not repeated here):
> bug pack BQ1-15, perf PF1-16, scrap S1-9 (S1/S5/S9 removed), recycle R1-7 (Tasks→Objective-Ping shipped).

---

## Deep-dived by Claude (verdicts)
| Label | File:line | Claim | Verdict | Note |
|---|---|---|---|---|
| SG4 | `Server/PVFunctions/RequestOnUnitKilled.sqf:95-96` | kill-assist bounty broken (`_objectType` undefined) | ✅+ | **Double bug**: also `alive _killed` guard is false at kill-time → block never runs. Fix var→`_killed_type` AND guard→`alive (vehicle _killed)`. |
| AI11 | `Server/AI/Orders/AI_Patrol.sqf:26-30`; `AI_TownPatrol.sqf:~50` | water-avoidance `while` no cap → hang | ✅ | Scheduler-starvation (Spawn context) on water-centred towns; cap + fallback-to-centre. |
| NJ11 | `Server/Functions/Server_ProcessUpgrade.sqf:20` | upgrade double-deduct race | ✅ | ProcessUpgrade only *sets* `wfbe_upgrading`, never checks. Make it the atomic gate. |
| NJ3 | `Client/Init/Init_Markers.sqf:16` | JIP enemy towns show "unknown" | ⚠️ | Real **vs current design**: `TownCaptured.sqf:21` colours enemy-captured towns → live reveals ownership; init doesn't. If fog-of-war is wanted, fix the *opposite* direction. OWNER DECISION. |
| AI2 | `Server/Functions/Server_SpawnTownMortars.sqf:20` | mortars never spawn (`_positions` undefined) | ✅+ | **Also never invoked**: nothing sets `wfbe_town_mortars`, so `Server_ManageTownDefenses.sqf:32` guard is always false. Recommend REMOVE the whole mortar chain (dead). |
| AI3 | `Server/Functions/Server_OperateTownDefensesUnits.sqf:24` | captured-town statics never manned (GUER guard) | ⚠️ | Real: guard blocks WEST/EAST. Call site `server_town_ai.sqf:190` passes current side. Relaxing = man captured statics (balance). VERIFY captured towns retain `wfbe_town_defenses` + occupied gunner type first. |
| V2 | `Client/Functions/Client_BuildUnit.sqf:332,334` | duplicate HandleReload Fired-EH on IFVs | ✅ | Lines byte-identical → 2 reload threads/shot. Delete :334. |
| SG5 | `Server/FSM/server_town_camp.sqf:135` | captured camp shows old flag (`_side` vs `_newSide`) | ✅ | Both sides in scope (old needed for LostAt msg); flag line grabbed old. Fix `str _newSide`. |
| AI1 | `Server/FSM/server_town_patrol.sqf:18`; `server_patrols.sqf:26` | zombie loop (`\|\|` vs `&&`) | ✅ | Exits only when game-over AND team-dead → dead teams loop forever (30s perf-audit). Fix `\|\|`→`&&`. |
| AI5 | `Server/FSM/server_town_ai.sqf:223` | `wfbe_town_teams` not written back on despawn | ⚠️ | Real but marginal; nothing reads it while inactive. SKIP unless already editing. |
| AI7 | `Server/Functions/Server_AI_SetTownAttackPath.sqf:41` | 30% `exitWith` discards approach path | ✅ | First WP built (:39) then block bailed; `_wp_sel` reset (:76) → 30% of long-range attacks beeline depot. Submit partial path before exit. |
| AI8 | `Server/Functions/Server_BuyUnit.sqf:117` | `sideJoined` on server → AI vehicles miss IR smoke (dedi) | ⚠️ | Real if server-side; change `sideJoined`→`_side` (verify param). Concrete: AI Tank/Car get IR-smoke flares on dedicated. |
| AI15 | `Server/AI/Orders/AI_MoveTo.sqf:6-9`; `AI_Patrol.sqf:7-10` | COMBAT on all orders → AI crawls | ⚠️ | **Overstated**: SpeedMode is NORMAL (not LIMITED) → cautious, not crawling; town-attack AI uses AWARE path anyway. Tuning preference; likely SKIP. Dev TODO at `Server_AI_SetTownAttackPath.sqf:74`. |
| AI17 | `Server_AI_SetTownAttackPath.sqf` 7-elem WPs | attack-formation system dead (7th elem ignored) | ❌ | **FALSE POSITIVE.** Attack path uses `Common_WaypointsAdd.sqf` (not `AI_WPAdd.sqf`), which DOES read `_x select 6` and apply behaviour/formation (`:24,33`). System is live. Close. |

---

## AI & combat (AI1-AI17) — UNVERIFIED unless verdict above
| # | File:line | Claim | LOC | Status |
|---|---|---|--:|---|
| AI4 | `Server_AttackWave.sqf:19,34` | shared global `ATTACK_WAVE_PRICE_MODIFIER` → two-side wave interference | 4 | ⬜ |
| AI6 | `Server_GetTownPatrol.sqf:19` | SV==60 falls through switch → no patrol | 1 | ⬜ |
| AI9 | `server_town_ai.sqf:165` | case-1 delegation doesn't persist `wfbe_town_teams` | 1 | ⬜ |
| AI10 | `Server_UpdateTeam.sqf:5` | `round(random N)` biased formation pick | 1 | ⬜ |
| AI12 | `server_town_ai.sqf:96` | `ArrayPush` in hottest detection loop | 1 | ⬜ |
| AI13 | `server_town_ai.sqf:157` | pre-created groups leak on invalid template (144-cap) | 3 | ⬜ |
| AI14 | `AI_SquadRespawn.sqf:56`,`AI_AdvancedRespawn.sqf:68` | literal gear-upgrade index and no loadout bounds/empty-array guard | 4 | ⚠️ real cleanup: `13` matches `WFBE_UP_GEAR`, but code should use the named constant, clamp tier selection and guard empty `WFBE_%SIDE_AI_Loadout_*` arrays before `random count`. |
| AI16 | `Server_HandleDefense.sqf:8` | no side-change check → ghost defenders re-man captured towns | 3 | ⬜ |

## Vehicles & assets (V1-V18)
| # | File:line | Claim | LOC | Status |
|---|---|---|--:|---|
| V1 | `updatesalvage.sqf:10` | `\|\|`→`&&` dead-truck loop spins | 1 | ⬜ |
| V3 | `Stopengine.sqf:7` | stealth "stopped" flag local-only → cross-player refuel bypass | 2 | ⬜ |
| V4 | `Engine.sqf:8` | stealth fuel save not broadcast → fuel loss on locality change | 1 | ⬜ |
| V5 | `Client_SupportRepair.sqf:77` | paid repair `setDammage 0` doesn't fix hitpoints/wheels | 2 | ⬜ |
| V6 | `GUI_Menu_Service.sqf` | no "Refuel All" batch button | ~15 | ⬜ |
| V7 | `car_wheel_new.sqf` | wheel repair one-shot per vehicle lifetime | 2 | ⬜ |
| V8 | `Action_RepairMHQDepot.sqf:26` | repositions wrong wreck + misleading "parachuted" hint | 2 | ⬜ |
| V9 | `Action_RepairMHQDepot.sqf:27` | town SV penalty client-side → server overwrites | ~5 | ⬜ |
| V10 | `Client_SupportHeal.sqf:48` | infantry heal time flat (ignores Man damage) | 1 | ⬜ |
| V11 | service scripts | no `Ship` class case → boats ignore service coefficients | 4 | ⬜ |
| V12 | `emptyvehiclescollector.sqf` | `emptyQueu` never pruned of objNull | 1 | ⬜ |
| V14 | `Action_RepairMHQDepot.sqf:6` | `cashrepaired` never reset → cash-repair locked for game | 2 | ⬜ |
| V16 | `Common_CreateVehicle.sqf:28` | `setVelocity[0,0,-1]` can clip vehicles through slopes | 1 | ⬜ |
| V17 | `GUI_Menu_Service.sqf:237` | service list can include enemy vehicles | 2 | ⬜ |
| V18 | `updatesalvage.sqf`/`Skill_Salvage.sqf` | no side check → self-destruct-and-salvage loop | 2-3 | ⬜ |

## Server gameplay & scoring (SG1-SG15)
| # | File:line | Claim | LOC | Status |
|---|---|---|--:|---|
| SG1 | `server_victory_threeway.sqf:41` | win/loss tracking INVERTED | 1 | ⬜ (high) |
| SG2 | `Server_OnHQKilled.sqf:46-50` | HQ-kill double score (1800 vs 900) + teamkill award | 5 | ⬜ (high) |
| SG3 | `Common_ChangeSideSupply.sqf:25` (+`Server_ChangeSideSupply.sqf:12,36`) | underflow guard ADDS supply (exploit) | 3 | ⬜ (high) |
| SG6 | `playerObjectsList.sqf:18` | `_i` always 0 → PLAYERLIST bloats + supply-mission perf | 2 | ⬜ |
| SG7 | `updateScoreInternal.sqf:13` | `while {true}` runs through game-over | 1 | ⬜ |
| SG8 | `server_town.sqf:207` | `wfbe_attacker_sideIDs` never cleared → stuck "under attack" marker | ~5 | ⬜ |
| SG9 | `Common_ChangeSideSupply.sqf:12` | `_reason` dropped at 3 args → false "malicious update" log | 1 | ⬜ |
| SG10 | `Server_LogGameEnd.sqf:14` | no resistance-winner case (3-way) | ~8 | ⬜ |
| SG11 | `Server_BuildingKilled.sqf:57` | empty reason → false security warning | 1 | ⬜ |
| SG12 | `skillDiffCompensation.sqf:82` | anti-stack accumulator reset → detection dead-zone | 4 | ⬜ |
| SG13 | `MonitorPlayerCount.sqf` | samples once at 120s, never re-checks | ~5 | ⬜ |
| SG14 | `initAFKkickHandler.sqf` | AFK kick client-authoritative (no server enforcement) | ~35 | ⬜ |
| SG15 | `Server_DelegateAITownHeadless.sqf:27` | HC delegation pure-random, not load-balanced | ~9 | ⬜ |

## Networking / JIP / state-sync (NJ1-NJ11)
| # | File:line | Claim | LOC | Status |
|---|---|---|--:|---|
| NJ1 | `server_town_camp.sqf:135` | = SG5 (camp flag) | 1 | ✅ (dupe of SG5) |
| NJ2 | `coin_interface.sqf:713`/`Server_BuildingKilled.sqf:85` | `wfbe_structures_live` client/server increment race | ~8 | ⬜ |
| NJ4 | `Init_Markers.sqf:38` | JIP camp marker uses town sideID not camp sideID | 2 | ⬜ |
| NJ5 | `Client_PreRespawnHandler.sqf` | blink-EH + `OriginalMarkerColor` not re-added on respawn | 5 | ⬜ |
| NJ6 | `Init_Client.sqf:384` | `wfbe_supply` alias cached once → stale UI for JIP | 3 | ⬜ |
| NJ7 | `Init_Client.sqf:18,279` | HandleAT added twice; HandleRocketTracer not re-added on respawn | 3 | ⬜ |
| NJ8 | `Construction_HQSite.sqf:14` | HQ deploy mutex non-atomic → HQ duplication | 3 | ⬜ (high) |
| NJ9 | `Init_Server.sqf:362-363` | `wfbe_aicom_funds/running` not broadcast → HC reads nil | 2 | ⬜ |
| NJ10 | `Init_Client.sqf:512` | JIP HQ killed-EH not added when deployed → victory may not fire | 1 | ⬜ (high) |

## UX / feedback / localization (UX1-UX30)
Typos (all-language, visible): **UX2** "TeamBance"/"Autonalance" (autobalance), UX3 "allready"×3, UX4 "the the"×3, UX5 "ennemy", UX22 French typos (Accépter/plannifie/séléctionnée). Missing feedback/audio: **UX27** AttackModeEnd no sound, **UX26** engineer repair no success/fail hint. Hardcoded-English (no key): UX1 attack-mode msgs, UX7 AFK warnings, UX8 camp-captured, UX9 group-system (~12), UX10 map-disband (9), UX11 BuyUnits tooltips (6), UX12 HQ-depot, UX13-19/24 action labels, UX20 builder hints, UX21 supply-mission. Untranslated FR/DE/IT: UX6 HeadHunter, UX23 9 upgrade descriptions, UX29 teamswap-lock, UX30 ReinforcedBuildings. Accessibility: UX28 camp-hint contrast, UX25 RHUD labels. (All ⬜ UNVERIFIED — string/locale checks.)

---

## Notes for maintainers
- Cross-check the ⬜ rows; several "high" SG/NJ items (SG1 win-inversion, SG3 supply-underflow, SG2 HQ double-score, NJ8 HQ-dup, NJ10 JIP-HQ-killed) are economy/victory-critical — confirm before any fix.
- Recurring patterns worth a wiki note: (1) **non-atomic check-and-set on networked vars** (NJ8, NJ11, NJ2); (2) **EHs not re-added on respawn** (NJ5, NJ7); (3) **`||` vs `&&` loop-exit slips** (AI1, V1, SG7); (4) **client `sideJoined` used server-side** (AI8); (5) **old-vs-new side variable mix-ups on capture** (SG5).
- AI17 confirmed FALSE POSITIVE — note in any AI-waypoint wiki page that `Common_WaypointsAdd.sqf` (7-element) ≠ `AI_WPAdd.sqf` (6-element).
