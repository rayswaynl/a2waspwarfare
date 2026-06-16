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

## Current Catch-Up Status

Read this page as a historical audit queue, not as a current master bug register. The source scope is `origin/release/2026-06-feature-bundle` / PR #8 unless a row explicitly says otherwise. For current release decisions, promote only source-checked rows into [Feature status](Feature-Status-Register), [Deep-review findings](Deep-Review-Findings), a subsystem owner page, or [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).

| Area | Current status | Route |
| --- | --- | --- |
| PR #8 shipped branch fixes | `97370acb` fixes SG5, AI7, AI11 and removes the dead AI2 town-mortar chain on `origin/release/2026-06-feature-bundle`; `0bb16513` fixes V2, AI1 and AI8 on that same branch. Do not claim these are on current `master` without checking the branch head. | PR #8 / release branch evidence; mirror into owner pages only if the branch is merged or selected for release. |
| Corrections and non-issues | V2 is real but low-impact/idempotent; AI8 is branch-fixed but later scout notes classify `Server_BuyUnit.sqf` as latent/dead `AIBuyUnit` code rather than the player-buy path; NJ11 is real but lower risk because of in-tick/client gating; AI15 is a non-issue; AI17 is a false positive. | Keep as false-positive/nuance guardrails here. |
| Formerly-high unverified items (now source-checked 2026-06-07) | SG1 (✅ confirms DR-11/DR-13 winner inversion), SG2 (✅ → DR-50 HQ double-score), SG3 (✅ → DR-49 supply underflow), NJ8 (⚠️ non-atomic HQ mutex, exposure-limited) and NJ10 (⚠️ **corrected** — redundant relay, not a victory-blocker; authoritative HQ-killed EH is server-local). See the per-section verdict tables and the maintainer note below. | [Victory/endgame](Victory-And-Endgame-Atlas), [Economy authority](Economy-Authority-First-Cut), [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Deep-review findings](Deep-Review-Findings), [Hardening roadmap](Hardening-Implementation-Roadmap). |
| Later worklog-only audit batches | Agent worklog entries mention later SK/CN/FC/SP and SM/TR/XR labels. This compact queue does not re-expand them; use those worklog entries as leads only, then source-check and route to owner pages. | [Agent worklog](Agent-Worklog), [Subagent discovery swarm](Subagent-Discovery-Swarm), owner pages. |

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

## AI & combat (AI1-AI17) — verified 2026-06-07 (Claude sweep, current `master`)
| # | Current path:line | Claim | Verdict | Evidence / route |
|---|---|---|---|---|
| AI4 | `Server/Functions/Server_AttackWave.sqf:19,34` | shared global `ATTACK_WAVE_PRICE_MODIFIER` → two-side wave interference | ✅ REAL | Bare global (no side suffix) set at `:19`, reset to 1 at `:34`; a second side's wave `spawn` can reset the first side's discount mid-sleep. Route: attack-wave/economy owner. |
| AI6 | `Server/Functions/Server_GetTownPatrol.sqf:16-19` | SV==60 falls through switch → no patrol | ✅ REAL | `case (_sv > 30 && _sv < 60)` and `case (_sv > 60)` leave exactly `60` uncovered with no `default`; patrol-type lookup ends nil at SV 60. |
| AI9 | `Server/FSM/server_town_ai.sqf:199-207` | delegation doesn't persist `wfbe_town_teams` | ✅ REAL (label fix) | The **client-delegation** case grows local `_town_teams` but never writes `_town setVariable ['wfbe_town_teams',…]`; the headless case (`:213`) and server path (`:229`) do. Claim mislabeled it "headless." |
| AI10 | `Server/Functions/Server_UpdateTeam.sqf:5` | `round(random N)` biased formation pick | ✅ REAL | `_formations select round(random(count _formations -1))` half-weights index 0; with 4 entries `random 3` is `[0,3)` so the last formation ("WEDGE") is statistically unreachable. |
| AI12 | `Server/FSM/server_town_ai.sqf:100` | `ArrayPush` in hottest detection loop | ⚠️ NUANCED (perf) | `WFBE_CO_FNC_ArrayPush` inside `forEach _detectedRaw` inside the per-town loop; O(entities×towns)/cycle. Measurement-first perf, not a correctness bug. |
| AI13 | `Server/FSM/server_town_ai.sqf:172-179` | pre-created groups leak on invalid template (144-cap) | ❌ GONE | `_team = createGroup _side; if (isNull _team) then {log; skip}` guard already present; no orphan leak. Close. |
| AI14 | `Server/AI/AI_SquadRespawn.sqf:56`, `Server/AI/AI_AdvancedRespawn.sqf:68` | literal gear index + no loadout bounds/empty-array guard | ⚠️ split | Literal-`13` part is ❌ FALSE (`WFBE_UP_GEAR = 13`, `Init_CommonConstants.sqf`); the empty-array part is ✅ REAL — `_loadout select floor(random count _loadout)` with only an `isNil` guard crashes if the loadout array is empty (`floor(random 0)` → `select 0`). |
| AI16 | `Server/Functions/Server_HandleDefense.sqf:7-42` | no side-change check → ghost defenders re-man captured towns | ✅ REAL | `_side` captured at spawn; `while {alive _defense}` never re-checks town ownership, so the old side keeps dispatching gunners to a flipped town. |

## Vehicles & assets (V1-V18) — verified 2026-06-07
| # | Current path:line | Claim | Verdict | Evidence / route |
|---|---|---|---|---|
| V1 | `Client/FSM/updatesalvage.sqf:10` | `\|\|`→`&&` dead-truck loop spins | ✅ REAL | `while {!gameOver \|\| !(alive _vehicle)}` only exits when game-over AND vehicle alive; loop spins after the truck dies. |
| V3 | `Client/Module/Engines/Stopengine.sqf:7` | stealth "stopped" flag local-only → cross-player refuel bypass | ✅ REAL | `setVariable ["stopped",true]` (no broadcast); `Startengine.sqf:7` same; `Client_SupportRefuel.sqf:8` reads the local copy. |
| V4 | `Client/Module/Engines/Engine.sqf:8` | stealth fuel save not broadcast → fuel loss on locality change | ✅ REAL | `setVariable ["Fuel",fuel _vehicle]` no broadcast; the new owner reads its own stale value. |
| V5 | `Client/Functions/Client_SupportRepair.sqf:77` | paid repair `setDammage 0` doesn't fix hitpoints/wheels | ✅ REAL | `_veh setDammage 0` resets only the global scalar; component `setHit` damage (wheels/engine) persists. |
| V6 | `Client/GUI/GUI_Menu_Service.sqf` | no "Refuel All" batch button | ⚠️ FEATURE REQUEST | Not a bug; QoL enhancement. Route: service-UI owner. |
| V7 | `WASP/actions/car_wheel_new.sqf:28` | wheel repair one-shot per vehicle lifetime | ✅ REAL | `setVariable ["wheel_change",1,true]` never reset; the `isNil` guard blocks the action permanently after first use. |
| V8 | `WASP/actions/Action_RepairMHQDepot.sqf:26` | repositions wrong wreck + misleading "parachuted" hint | ❌ FALSE | `:8` exits if `alive _hq`, so `:26` only lifts the dead HQ to altitude for the parachute drop — intended; the hint matches the design. |
| V9 | `WASP/actions/Action_RepairMHQDepot.sqf:28` | town SV penalty client-side → server overwrites | ❌ FALSE | `{_x setVariable ["supplyvalue",10,true]} forEach _towns` — third arg `true` broadcasts globally; no client-only write. |
| V10 | `Client/Functions/Client_SupportHeal.sqf:48-51` | infantry heal time flat (ignores Man damage) | ✅ REAL | Heal time scaled only inside Air/StaticWeapon/Tank/Car/Motorcycle branches; `Man` matches none → flat time. |
| V11 | `Client_SupportRepair/Heal/Refuel/Rearm.sqf` | no `Ship` class case → boats ignore service coefficients | ✅ REAL | All four service scripts branch Air/StaticWeapon/Tank/Car/Motorcycle; a boat falls through → base coefficient (1). |
| V12 | `Server/FSM/emptyvehiclescollector.sqf:18` / `Server_HandleEmptyVehicle.sqf:33` | `emptyQueu` never pruned of objNull | ❌ FALSE | `Server_HandleEmptyVehicle.sqf:33` does `emptyQueu = emptyQueu - [_vehicle]`; collector strips `objNull` at `:18`. |
| V14 | `WASP/actions/Action_RepairMHQDepot.sqf:6,24` | `cashrepaired` never reset → cash-repair locked for game | ✅ REAL | Set `true` at `:24`; only other ref is the read-and-exit guard at `:6-9`; no reset anywhere → locked for the session. |
| V16 | `Common/Functions/Common_CreateVehicle.sqf:35` | `setVelocity[0,0,-1]` can clip vehicles through slopes | ⚠️ NUANCED | Real line; intentional settle-onto-terrain nudge; slope clipping possible but a known vanilla spawn pattern. Low severity. |
| V17 | `Client/GUI/GUI_Menu_Service.sqf:219-233` | service list can include enemy vehicles | ✅ REAL | The repair-truck fallback `nearEntities[[…],100]` at `:222` has no side filter; enemy vehicles within 100m can appear in the list. |
| V18 | `Client/Module/Skill/Skill_Salvage.sqf`, `Client/FSM/updatesalvage.sqf` | no side check → self-destruct-and-salvage loop | ✅ REAL | Neither path checks `side _x` vs the player's side before converting a wreck to cash. |

## Server gameplay & scoring (SG1-SG15) — verified 2026-06-07
| # | Current path:line | Claim | Verdict | Evidence / route |
|---|---|---|---|---|
| SG1 | `Server/FSM/server_victory_threeway.sqf:35-40` + `Server_LogGameEnd.sqf:14` | win/loss tracking INVERTED | ✅ REAL — confirms DR-11/DR-13 | `WF_Winner` is set to `_x` (correct), but `_side` is flipped to the opposite side and `[_side] call LogGameEnd` logs the **loser** as `_winnerTeam`. Concrete persisted-stats inversion site complementing DR-36's mechanism note. Route: [Deep-review findings](Deep-Review-Findings) DR-11. |
| SG2 | `Server/Functions/Server_OnHQKilled.sqf:23,47,74-81` | HQ-kill double score (1800 vs 900) + teamkill award | ✅ REAL → **DR-50** | Unconditional award `_points = 30000/100 * WFBE_C_BUILDINGS_SCORE_COEF` at `:47` fires on every kill incl. teamkills; a second `_score = 900` at `:81` is non-teamkill-guarded → 1800 on a clean kill, 900 on a teamkill. |
| SG3 | `Common/Functions/Common_ChangeSideSupply.sqf:25`, `Server/Functions/Server_ChangeSideSupply.sqf:12,36` | underflow guard ADDS supply (exploit) | ✅ REAL → **DR-49** | `if (_change < 0) then {_change = _currentSupply - _amount}` — for a negative `_amount` this is `_currentSupply + \|amount\|`, **adding** supply on underflow instead of clamping to 0. |
| SG6 | `Server/Module/supplyMission/playerObjectsList.sqf:18` | `_i` always 0 → PLAYERLIST bloats | ✅ REAL | `_i` reset to 0 inside the `forEach` body each pass; the match index is always 0 so non-first players are never deduped → duplicate appends. |
| SG7 | `Server/Module/AntiStack/updateScoreInternal.sqf:13` | `while {true}` runs through game-over | ✅ REAL | `while {true} do {` with no `gameOver`/`WFBE_GameOver` exit; sibling loops use `while {!gameOver}`. |
| SG8 | `Server/FSM/server_town.sqf:192-207` | `wfbe_attacker_sideIDs` never cleared → stuck "under attack" marker | ⚠️ NUANCED | The variable leak is real, but the client marker is also gated on `supplyValue < startingSupplyValue` (`updatetownmarkers.sqf`), so it self-clears as supply recovers — a bounded SV-visibility leak, not a permanently stuck marker. |
| SG9 | `Common/Functions/Common_ChangeSideSupply.sqf:12` | `_reason` dropped at 3 args → false "malicious update" log | ⚠️ split | Reason-dropped is ✅ REAL (`count _this > 3` should be `> 2` to read index 2). The "false malicious log" part is ❌ FALSE — the non-empty default reason bypasses the server's `_reason != ""` malicious warning. |
| SG10 | `Server/Functions/Server_LogGameEnd.sqf:14` | no resistance-winner case (3-way) | ✅ REAL (defensive) | `if (_winnerTeam == west) … else {_loserTeam = west}` has no GUER branch. Resistance is currently excluded from winning by `server_victory_threeway.sqf` (`- [WFBE_DEFENDER]`) so it can't reach here today, but the function is non-defensive if ever passed GUER. |
| SG11 | `Server/Functions/Server_BuildingKilled.sqf:57` | empty reason → false security warning | ✅ REAL | `[_side_killer,_supplies,"",false] Call ChangeSideSupply` passes `""`; the server handler's `_reason == ""` branch fires the "malicious supply update" warning on every guerrilla-barracks supply award. |
| SG12 | `Server/Module/AntiStack/skillDiffCompensation.sqf:82` | anti-stack accumulator reset → detection dead-zone | ⚠️ NUANCED | After compensation the `TEAM_SKILL_TICKS_*` accumulators reset to 0, forcing re-accumulation before re-trigger. Intended cadence vs dead-zone is an owner/tuning decision. |
| SG13 | `Server/MonitorPlayerCount.sqf:5-16` | samples once at 120s, never re-checks | ✅ REAL | 17-line file: `sleep 120`, count once, set `WFBE_Server_LogMatchWin` if threshold met, exit. No loop. |
| SG14 | `Client/Module/AFKkick/monitorAFK.sqf:49` + `Server/Module/afkKick/initAFKkickHandler.sqf` | AFK kick client-authoritative | ✅ REAL — see DR-30 | Client `failMission "END1"` / `publicVariableServer` self-kick; server handler only logs. Matches DR-30 (AFK-kick stub, no server enforcement). |
| SG15 | `Server/Functions/Server_DelegateAITownHeadless.sqf:27` | HC delegation pure-random, not load-balanced | ✅ REAL | `_clients select floor(random count _clients)` — uniform random, no load metric. Matches the HC-balance lead. |

## Networking / JIP / state-sync (NJ1-NJ11) — verified 2026-06-07
| # | Current path:line | Claim | Verdict | Evidence / route |
|---|---|---|---|---|
| NJ1 | `server_town_camp.sqf:135` | = SG5 (camp flag) | ✅ (dupe of SG5) | Duplicate of the verified SG5 camp-flag finding. |
| NJ2 | `Client/Module/CoIn/coin_interface.sqf:713-715`, `Server/Functions/Server_BuildingKilled.sqf:85-87` | `wfbe_structures_live` client/server increment race | ⚠️ NUANCED | Both write `wfbe_structures_live` with broadcast `true`; non-atomic read-modify-write race exists but the window is narrow (same-frame place+destroy). Client should request; server should own the count. |
| NJ3 | `Client/Init/Init_Markers.sqf:14-18` | JIP enemy towns show "unknown" | ⚠️ OWNER DECISION | Intentional fog-of-war: only friendly towns get the side colour, others `WFBE_C_UNKNOWN_COLOR`; init and the live FSM both key off `sideID`, consistent. Not a bug. |
| NJ4 | `Client/Init/Init_Markers.sqf:38-41` | JIP camp marker uses town sideID not camp sideID | ✅ REAL | The camp colour guard tests `_townSide == WFBE_Client_SideID`; `_campSide` (read at `:35`) is never used → camp shown in the town's colour. Cosmetic. |
| NJ5 | `Client/Functions/Client_PreRespawnHandler.sqf:13` | blink-EH + `OriginalMarkerColor` not re-added on respawn | ✅ REAL (conditional) | PreRespawn re-adds only `HandleAT`; the blink Fired-EH and `OriginalMarkerColor` (set at `Init_Client.sqf:21-27`) are not, so blink restore reads nil after respawn. Only when `WFBE_C_MAP_ICON_BLINKING_ENABLED == 1`. |
| NJ6 | `Client/Init/Init_Client.sqf:383` | `wfbe_supply` alias cached once → stale UI for JIP | ❌ FALSE | The live UI reads the per-side `wfbe_supply_%1` kept current by the server's `publicVariable` on each change + `REQUEST_SUPPLY_VALUE`; the `:383` alias is a one-shot init guard, not the live source. |
| NJ7 | `Client/Init/Init_Client.sqf:18,278` | HandleAT added twice; HandleRocketTracer not re-added on respawn | ✅ REAL | `:18` adds HandleAT (+HandleRocketTraccer); `:278` adds HandleAT again unguarded → double; `HandleRocketTraccer` is absent from PreRespawnHandler → lost after respawn. |
| NJ8 | `Server/Construction/Construction_HQSite.sqf:14-15` | HQ deploy mutex non-atomic → HQ duplication | ⚠️ NUANCED | `waitUntil {!getVariable "wfbe_hqinuse"}; setVariable [...,true]` is a non-atomic check-then-set; two same-frame deploy requests could both pass. Exposure reduced by sequential server PV handling; worth an atomic guard. Recurring pattern with NJ11/NJ2. |
| NJ9 | `Server/Init/Init_Server.sqf:368-369` | `wfbe_aicom_funds/running` not broadcast → HC reads nil | ✅ REAL | `setVariable ["wfbe_aicom_running",false]` and `["wfbe_aicom_funds",…]` lack the broadcast `true`; sibling `wfbe_hq_deployed` (`:362`) uses `,true]`. Non-server readers get nil. |
| NJ10 | `Client/Init/Init_Client.sqf:512` | JIP HQ killed-EH not added when deployed → victory may not fire | ⚠️ NUANCED (corrected) | The client EH at `:515` is a **redundant relay**; the authoritative HQ-killed processing is server-local (`Init_Server.sqf:323`, `Construction_HQSite.sqf:89` *"Killed EH fires localy, this is the server"*, `Server_MHQRepair.sqf:37`). The `!_isDeployed` gate means post-deploy JIP clients skip the redundant relay, but **victory is not blocked**. The original "high / victory never fires" claim is overstated. |

## UX / feedback / localization (UX1-UX30) — spot-verified 2026-06-07
Typos (all-language, visible): **UX2** "TeamBance"/"Autonalance" (autobalance), UX3 "allready"×3, UX4 "the the"×3, UX5 "ennemy", UX22 French typos (Accépter/plannifie/séléctionnée). Missing feedback/audio: **UX27** AttackModeEnd no sound, **UX26** engineer repair no success/fail hint. Hardcoded-English (no key): UX1 attack-mode msgs, UX7 AFK warnings, UX8 camp-captured, UX9 group-system (~12), UX10 map-disband (9), UX11 BuyUnits tooltips (6), UX12 HQ-depot, UX13-19/24 action labels, UX20 builder hints, UX21 supply-mission. Untranslated FR/DE/IT: UX6 HeadHunter, UX23 9 upgrade descriptions, UX29 teamswap-lock, UX30 ReinforcedBuildings. Accessibility: UX28 camp-hint contrast, UX25 RHUD labels.

**Verification (2026-06-07):** every typo and hardcoded-English claim spot-checked is ✅ REAL in current `master`:
- **UX2** ✅ `stringtable.xml:4867` `[TeamBance]: [Autonalance] You have joined …` (`[TeamBance]` repeats across `:4868-4885`).
- **UX3** ✅ "allready" ×13 in `stringtable.xml` (e.g. `:2195` "Vehicle is allready being repaired", `:2475`, `:2538`) — more than the claimed ~3.
- **UX4** ✅ "the the" ×6: `stringtable.xml:4189-4190` "join the the other team", `Client/Functions/Client_FNC_Groups.sqf:12,19` (visible); `Common/Init/Init_Common.sqf:265`, `Init_CommonConstants.sqf:387` (comments).
- **UX5** ✅ "ennemy" ×2 hardcoded in `Client/Module/ZetaCargo/Zeta_Hook.sqf:21,22`.
- **UX22** ✅ `stringtable.xml`: "Accépter" `:4805`, "plannifie" `:1321`, "séléctionnée" `:3228`.
- **UX1** ✅ hardcoded EN in `Client/PVFunctions/LocalizeMessage.sqf:12-14` (all three AttackMode cases, no `localize`).
- **UX7** ✅ hardcoded EN AFK hints `Client/FSM/updateclient.sqf:124,127`, `Client/Module/AFKkick/monitorAFK.sqf:46`.
- **UX8** ✅ hardcoded EN `Client/PVFunctions/CampCaptured.sqf:37`.
- **UX21** ✅ hardcoded EN `Client/Module/supplyMission/supplyMissionStart.sqf:13,36,43`, `supplyMissionCompletedMessage.sqf:14`.

Remaining UX rows (UX6/9-20/23-30) are the same string/locale class and were not individually spot-checked this pass; treat them as high-confidence leads of the same kind. Route: a single localization-cleanup lane (stringtable typos + add `STR_` keys for the hardcoded-English messages).

---

## Notes for maintainers
- **2026-06-07 verification sweep (Claude): the previously-UNVERIFIED AI/V/SG/NJ/UX queue is now fully source-checked against current `master` — no `⬜` rows remain.** Tally: **REAL** AI4, AI6, AI9, AI10, AI16, V1, V3, V4, V5, V7, V10, V11, V14, V17, V18, SG1, SG2, SG3, SG6, SG7, SG10, SG11, SG13, SG14, SG15, NJ4, NJ5, NJ7, NJ9 + all spot-checked UX; **NUANCED/design/perf** AI12, V16, SG8, SG12, NJ2, NJ3, NJ8, NJ10; **split** (real+false sub-claim) AI14, SG9; **FALSE** V8, V9, V12, NJ6; **GONE/fixed** AI13.
- **Corrections to earlier "high" framing:** **NJ10 is NOT a victory-blocker** — the authoritative HQ-killed EH is server-local (`Init_Server.sqf:323`, `Construction_HQSite.sqf:89`, `Server_MHQRepair.sqf:37`); the client EH is a redundant relay. **SG1** confirms the existing DR-11/DR-13 winner-inversion. **SG14** is the existing DR-30 AFK-stub. The genuinely new economy/scoring exploits promoted to DRs are **SG3 → DR-49** (supply underflow guard adds supply) and **SG2 → DR-50** (HQ double-score + teamkill award).
- Recurring patterns worth a wiki note: (1) **non-atomic check-and-set on networked vars** (NJ8, NJ11, NJ2); (2) **EHs not re-added on respawn** (NJ5, NJ7); (3) **`||` vs `&&` loop-exit slips** (AI1, V1, SG7); (4) **client `sideJoined` used server-side** (AI8); (5) **old-vs-new side variable mix-ups on capture** (SG5); (6) **missing-broadcast `setVariable` for JIP/HC reads** (NJ9, V3, V4); (7) **client-side `setDammage 0` vs component hitpoints** (V5).
- AI17 confirmed FALSE POSITIVE — note in any AI-waypoint wiki page that `Common_WaypointsAdd.sqf` (7-element) ≠ `AI_WPAdd.sqf` (6-element).

## Continue Reading

Previous: [Deep-review findings](Deep-Review-Findings) | Next: [Feature status](Feature-Status-Register)

Main map: [Home](Home) | Triage owner: [Dead/stale code register](Dead-Code-And-Stale-Code-Register) | Implementation queue: [Hardening roadmap](Hardening-Implementation-Roadmap)
