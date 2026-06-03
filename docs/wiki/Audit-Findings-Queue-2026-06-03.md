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
| AI14 | `AI_SquadRespawn.sqf:56`,`AI_AdvancedRespawn.sqf:68` | hardcoded upgrade index 13, no bounds check | 4 | ⬜ |
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

---

## Verification run 2 (2026-06-03) — owner-reviewed; fixes shipped + corrections
Re-verified against the release tree (triple-check). Outcomes:

**✅ FIXED & shipped to PR #8 (commit `97370acb`):**
- **SG5** — `server_town_camp.sqf:135` `str _side` → `str _newSide` (captured camp now flies the captor's flag).
- **AI7** — `Server_AI_SetTownAttackPath.sqf:41` now submits the built first waypoint before the 30% `exitWith`, so the flanking approach is kept.
- **AI11** — capped the water-avoidance loop at 20 retries + fallback to town centre in **both** `AI_Patrol.sqf:26` and `AI_TownPatrol.sqf:50`.
- **AI2** — town-mortar feature **removed**: deleted orphan `Server_SpawnTownMortars.sqf` (no compile registration) + the never-true caller line in `Server_ManageTownDefenses.sqf:32`. (`WFBE_%1DEFENSES_MORTAR` config vars in the 11 Structures files are now orphaned — optional further cleanup, left to limit blast radius.)

**Verification corrections (owner decided NOT to fix):**
- **V2** — REAL duplicate (`Client_BuildUnit.sqf:332`/`:334` differ only by a stray space) but **impact overstated**: `HandleReload`→`Common_HandleReload.sqf` only calls `setWeaponReloadingTime` (idempotent), so it's a redundant per-shot script spawn, **not** "double ammo." Low-value cleanup; owner querying necessity → left.
- **AI1** — CONFIRMED real (`||` should be `&&`; wiped/deleted patrol teams loop forever — teams are not refilled in place). Owner querying → left for now.
- **AI8** — CONFIRMED: IR-smoke is gated on `IRSMOKE upgrade > 0` (only once researched) and `_side` is the in-scope param (`_this select 3`); `sideJoined` is wrong server-side. Fix is safe (AI vehicles get IR-smoke only when the side researched it). Awaiting owner go.
- **NJ11** — REAL in theory, but **low practical risk**: the queue's check→set is atomic in-tick and the manual buy button is client-greyed while `wfbe_upgrading`, leaving only a tiny network-latency window. (Note: the queue IS player-usable via `RequestEnqueue.sqf`, so the race is queue-vs-manual, not player-vs-AI-commander.) Owner skip = defensible.
- **AI15** — **NON-ISSUE / CLOSED.** Overstated: `AI_MoveTo`/`AI_Patrol` set `setSpeedMode "NORMAL"` (not `"LIMITED"`) → cautious, not crawling; heavy combat AI uses the AWARE attack path anyway. Dev TODO noted at `Server_AI_SetTownAttackPath.sqf:74`. Do not action.
- **NJ3** — design decision (reveal-enemy vs fog-of-war); owner chose to leave as-is.
- **AI3** — backburner (balance change; verify captured towns retain `wfbe_town_defenses` + occupied gunner type first).
- **AI5** — skip (marginal).

Maintainers: SG5/AI7/AI11/AI2 are done on PR #8 — please cross-check and close those rows; AI15 → mark non-issue; the rest of the UNVERIFIED rows above still need cross-referencing.

**✅ Also now FIXED & shipped to PR #8 (commit `0bb16513`):**
- **V2** — removed the duplicate IFV `fired`→HandleReload EH (`Client_BuildUnit.sqf`); one fewer spawn/shot, no behaviour change (idempotent).
- **AI1** — `||`→`&&` in `server_town_patrol.sqf:18` and `server_patrols.sqf:26`; wiped patrol-team loops now exit instead of running forever. (Triple-check: both files init the alive flag before the loop, so `&&` is safe — verified `server_patrols.sqf:7` `_team_alive=false` precedes the loop.)
- **AI8** — `Server_BuyUnit.sqf:117` now uses the buying side `_side` (not client `sideJoined`); AI Tank/Car get IR-smoke on dedicated servers, still gated on the researched upgrade.
  - ⚠️ **Round-3 correction:** `Server_BuyUnit.sqf` is **dead code** (`AIBuyUnit` compiled at `Init_Server.sqf:10`, zero callers — see FC1). So AI8 edited never-executed code: harmless, but the premise doesn't manifest. Recommend scrapping the file (FC1) rather than keeping the AI8 line. Do NOT cite AI8 as a live fix.

---

## Round 3 (2026-06-03) — Skills / Construction-CoIn / Factory / Support delivery
4-agent sweep on fresh systems. Labels SK1-14, CN1-14, FC1-11, SP1-14. Verified a few; the rest are ⬜ UNVERIFIED — please cross-check against the codebase + the Construction/Factory/Modules atlases.

**Verified this round:**
- **FC1** — ✅ `Server_BuyUnit.sqf` / `AIBuyUnit` is DEAD CODE (no callers). Scrap candidate. (Supersedes/moots AI8.)
- **SK1** — ✅ `WFBE_SK_V_Type` never set to "Officer" (`Skill_Init.sqf:42-47`); the whole MASH/Officer forward-respawn feature is unreachable. Revivable with SK2 (+ officer classnames).
- **CN1** — ⚠️ `Construction_SmallSite.sqf:99` uses `+` where `Construction_MediumSite.sqf:114` uses `-` on `wfbe_structures_logic` (likely a leak — verify the +/- intent against the repair system).
- **SP8** — ❌ FALSE POSITIVE (agent self-corrected: server `deleteMarker` is global, works).
- **SP9** — marginal (cargo vehicle is tracked by emptyQueu).

**High-value ⬜ to verify (correctness/game-affecting):**
- **CN4** `Server_HandleBuildingRepair.sqf:66` — `_redu` referenced inside a `handleDamage` EH block (no closure capture in A2 → nil at fire-time) → repaired buildings possibly invulnerable when friendly-fire handling off. (1 LOC)
- **CN8** `Server_HandleBuildingRepair.sqf:54` — increments `_bindex` (caller idx) instead of trimmed `_index` into `wfbe_structures_live` → wrong slot. (1)
- **CN6** missing `WFBE_C_STRUCTURES_MAX_AARADAR` → AA Radar ignores build cap. (1)
- **CN3** `coin_interface.sqf:261,728` — `avail` defense-slot counter local-only → resets on commander transfer → build-cap bypass. (2-6)
- **CN11** `coin_interface.sqf:239-268` — defense **sell** is client-only `deleteVehicle` → broken in dedicated MP (refund given, defense stays). (~25)
- **FC2** `Client_BuildUnit.sqf:211` — no refund when factory destroyed mid-build → lost funds. (5-8)
- **FC5** `Client_BuildUnit.sqf:180` — `_queu select 0` on empty queue → crash → factory soft-lock. (3)
- **FC3** `Client_BuildUnit.sqf:167` — `varQueu` read/write race → duplicate queue tokens → queue bypass. (2)
- **FC11** `Common_CreateVehicle.sqf:19,25` — `Compile preprocessFile` per vehicle spawn → pre-compile once. (4, perf)
- **SP1** `Support_ParaAmmo.sqf:85` — `_sideID` nil in nested spawn → broken Killed EH on ammo crates. (4-6)
- **SP3** `ARTY_HandleSADARM.sqf:137` — `while{true}` immortal thread leak per SADARM round. (3)
- **SP4** `uav.sqf:33` — `createGroup` never `deleteGroup` → group leak toward 288 cap. (1-2)
- **SP12** `Server_HandleSpecial.sqf:55` — RespawnST doesn't clear `wfbe_ai_supplytrucks` → trucks never respawn. (1-3)
- **SP11** ICBM Chukar object race on high-latency dedi → $75k strike may deal no damage. (3-4)
- **SK3** sniper spot marker uses global `setMarkerText` on a local marker → no label. (1)
- **SK4** lockpick `typeOf` switch never matches the abstract class → uniform difficulty. (~5)

**Exploit-class (owner priority = gameplay over exploit; likely defer):** SP2 (no server-side support validation), SP13 (fast-travel client-authoritative), SP14 (artillery cooldown client-only), CN3/CN11 also have exploit angles.

Lower-value/cleanup: SK5/6/7/8/9/10/11/12/13/14, CN2/5/7/9/10/12/13, FC4/6/7/8/9/10, SP5/6/7/10 — see chat summary; cross-check as capacity allows.

**✅ FIXED & shipped to PR #8 (commit `b8a895b0`):**
- **FC2** — destroyed-factory builds now refund the purchase price. `_currentCost` is passed into `BuildUnit` (`GUI_Menu_BuyUnits.sqf:162`) and refunded in the factory-destroyed `exitWith` (`Client_BuildUnit.sqf`), mirroring the deduction. Guarded so it's a no-op for other callers / never double-refunds.
- **SP4** — `uav.sqf` now deletes the crew group(s) after the UAV lifecycle ends (incl. the driver's split-off group), closing the per-UAV group leak toward the 288-group cap. Residual: a UAV active at *player disconnect* still leaks its group (server has no group ref) — minor follow-up.

---

## Round 4 (2026-06-03) — Supply-Mission / Logistics subsystem
Random wiki-seeded pick (Supply-Mission-Architecture + the two cleanup/scan playbooks). 3-agent sweep: SM (lifecycle, 16), TR (trucks/economy, 15), XR (wiki-vs-code cross-reference, 15). Headline items verified by direct read.

**✅ Verified REAL — recommend (low-LOC correctness):**
- **TR12** — `Server_AI_Com_Upgrade.sqf:47,50` deducts SWAPPED cost indices vs the check at `:34`. `_cost = [supply, funds]`; check is `supply>=cost[0] && funds>=cost[1]`, but line 47 takes `cost[0]` (supply price) from **funds** and line 50 takes `cost[1]` (funds price) from **supply**. AI commander is ON by default (`WFBE_C_AI_COMMANDER_ENABLED=1`); bites in currency-system 0. Fix: 47→`_cost select 1`, 50→`_cost select 0`. 2 LOC. HIGH.
- **XR4** — cooldown var casing: `Init_Town.sqf:35` seeds `lastSupplyMissionRun` (lowercase) but `isSupplyMissionActiveInTown.sqf:8` reads `LastSupplyMissionRun`. First check reads nil → nil arithmetic (benign-by-accident, allows first mission). The wiki's own DR-18. 1-char fix.
- **XR3** — `supplyMissionCompleted.sqf:40-41` clears `SupplyAmount`+`SupplyFromTown` but NOT `SupplyByHeli` → stale heli flag mis-classifies a reused vehicle's next run as a cash-run. 1 LOC (the cleanup playbook itself says "clear state on completion"). Add `setVariable ["SupplyByHeli", false, true]`.
- **SM8/XR9** — `supplyMissionActive.sqf` is DEAD (compiled `Init_Server.sqf:82` as `WFBE_SE_FNC_SupplyMissionActive`, zero callers — confirmed by grep). The cleanup playbook asked to retire it; never done. ~68 LOC removable.
- **SM9/XR2** — `checkCCProximity.sqf` is DEAD (compiled `Init_Client.sqf:134` as `WFBE_CL_FNC_CheckCCProximity`, zero callers). Not even mentioned in the wiki. ~16 LOC removable.
- **XR5/SM7** — `supplyMissionStart.sqf:73` re-sends `WFBE_Client_PV_IsSupplyMissionActiveInTown` a second time (first at :6-7). Redundant network + server-handler invocation. −1 LOC.
- **XR6** — `supplyMissionStarted.sqf` (PVEH) spawns a NEW tracking loop on every `WFBE_Client_PV_SupplyMissionStarted` with no per-vehicle guard → reloading the same vehicle runs parallel loops. ~8 LOC (add a `wfbe_supply_tracking` flag).
- **XR15/SM2** — `supplyMissionStarted.sqf:50,56` CC-proximity scan filters by CLASS only (`Base_WarfareBUAVterminal`), no friendly-side check → a supply run can complete at the ENEMY CC and still credit the deliverer's own side. ~5 LOC (verify CC side). Borderline exploit.

**🔎 Wiki DRIFT (cross-ref; docs-only fix, HIGH value — prevents re-doing shipped work):**
- **XR1/XR7** — all 3 Supply-Mission wiki pages claim the CC scan "still uses broad `nearestObjects [pos,[],80]`". Live `supplyMissionStarted.sqf:56` is ALREADY class-filtered with a heli 400m radius. Scan-narrowing is SHIPPED; wiki is stale.
- **XR8** — heli 2D horizontal-distance qualifier (`supplyMissionStarted.sqf:51-54`, `<6400`) undocumented.
- **XR14** — `supplyMissionTimerForTown.sqf` push-based cooldown-expiry broadcast undocumented.

**❌ FALSE POSITIVE (verified by direct read):**
- **SM6** — "`_friendlyCommandCenterInProximity` never reset in the loop": the LIVE `supplyMissionStarted.sqf:48` DOES reset it each iteration. The agent described the dead twin `supplyMissionActive.sqf`. NOT a live bug.

**🛑 Exploit-class (owner priority = gameplay over exploit → defer):** SM1/SM14/SM15 (client-authoritative supply amount / score / funds), TR4 (free upgrades — `RequestUpgrade` no server affordability check), TR5 (free structures + infinite supply via client-side sell), TR6 (`Action_RepairMHQDepot.sqf:28` client-side broadcast nuke of all friendly town SVs to 10), TR10 (`Server_AttackWave.sqf:15` discount uses stale client-supplied supply), TR11 (client-side repair supply drain), SM3/SM11 (cooldown checked client-side). Root cause shared: supply mutations are client-authoritative with no server re-validation.

**Known/deferred (confirmed, NOT new):** TR1/TR2/XR12 — AI truck supply mode is dead (`UpdateSupplyTruck` compile commented at `Init_Server.sqf:37`; `supplytruck.fsm` missing). Wiki already documents this.

Lower-value/cleanup: TR3/7/8/9/13/15, SM4/5/10/13/16/17, XR10/11/13 — see chat; cross-check as capacity allows. Nothing from Round 4 built yet — awaiting owner pick.
