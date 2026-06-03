# Pending Owner Decisions

> Claude-owned (2026-06-02). The single place a code owner can see every open decision the deep-review campaign surfaced, each with its finding(s) and the affected subsystem. The [Codebase coverage ledger](Codebase-Coverage-Ledger) is "green except Auth/PV cells"; **those residual cells are exactly the decisions below** — review work is complete, what remains is choosing and applying fixes. Severity uses the [Deep-review findings](Deep-Review-Findings) tiers.

## How To Use This Page

Read this as a decision register, not a bug list. A row belongs here when source evidence is already strong enough and the next step is choosing a policy: server authority, filter posture, revive/remove, smoke gate or branch ownership.

Quick path:

1. Start with the [Owner Decision Queue](Feature-Status-Register#owner-decision-queue) if you need the human-readable triage view.
2. Pick one decision class below and open its canonical page before editing code.
3. If you patch gameplay, update the Chernarus source mission first, run LoadoutManager propagation when needed, and record smoke status in [Source fix queue](Source-Fix-Propagation-Queue) / [`agent-release-readiness.json`](agent-release-readiness.json).

## Fast Decision Queue

| Queue | Decision type | Canonical implementation route |
| --- | --- | --- |
| P0 public-server safety | Choose server-side authority and dispatcher/direct-channel hardening before public hosting, or document a real BattlEye/filter deployment as defense in depth only. | [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), [Public variable channel index](Public-Variable-Channel-Index), [ICBM authority](ICBM-Authority-Playbook), [Economy authority first cut](Economy-Authority-First-Cut), [External integrations](External-Integrations). |
| P1 economy and direct-PV migration | Treat spend/effect/direct-PV payloads as requests and re-derive side/funds/supply/effects server-side. | [Server authority migration map](Server-Authority-Migration-Map), [Public variable channel index](Public-Variable-Channel-Index), [Attack-wave authority](Attack-Wave-Authority-Playbook). |
| P1/P2 match correctness | Patch default victory winner/double-fire behavior and choose whether threeway victory is real or unsupported. | [Victory/endgame atlas](Victory-And-Endgame-Atlas), [Hardening roadmap](Hardening-Implementation-Roadmap). |
| P1 logistics baseline | Decide PR #1 supply heli merge requirements separately from dormant autonomous AI logistics. | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Supply mission architecture](Supply-Mission-Architecture), [Current supply heli PR](Current-Work-Supply-Helicopters-PR1). |
| P2 revive/remove backlog | Decide whether to revive, hide or delete dormant UI/support/marker/mission paths. | [Abandoned feature revival](Abandoned-Feature-Revival-Review), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Client UI systems atlas](Client-UI-Systems-Atlas). |
| P2/P3 scoped hardening | Patch ready local defects once a maintainer schedules smoke. | [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety), [Service guards](Service-Menu-Affordability-Guards), [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas). |

## Branch-Only Feature Promotion Decisions

These rows are merge/release gates for useful branch work. They are not stable-`master` findings until the target branch is named, Chernarus and maintained Vanilla scope is explicit, and smoke is recorded.

| Branch / feature | Confirmed branch evidence | Owner decision before promotion |
| --- | --- | --- |
| `origin/feat/ai-commander` head `4dba060e` | Source-Chernarus-only diff from `origin/master` `2cdf5fb8`: 9 files, +366/-5. The branch changes `WFBE_C_AI_COMMANDER_ENABLED` default to enabled (`Rsc/Parameters.hpp:96`), compiles commander workers (`Server/Init/Init_Server.sqf:49-54`), starts one supervisor per side (`:630-631`), runs full/assist loops (`Server/AI/Commander/AI_Commander.sqf:29-81`) and only guards the old `UpdateSupplyTruck` nil path (`Init_Server.sqf:387-389`). | Decide whether default-on AI commander is desired, whether human-commander assist mode may run by default, and whether autonomous logistics stays deferred. Before calling it revived: propagate/review maintained Vanilla, then smoke no-human full command, human assist/no-spend, order execution, town assignment, AI production cap, upgrade debit/costs, commander handoff, HQ death and JIP. |
| `origin/feat/drone-saturation-strike` head `8ca4be90` | Mission runtime changes are source-Chernarus-only: 15 mission files, +379/-4, with **0 maintained Vanilla mission files changed**. The total branch diff is 17 files, +1133/-4 because it also ships `docs/superpowers` plan/spec files. Drone constants are latest branch tuning: enabled/enhanced defaults, 2 flare + 2 munition drones, 300m cruise altitude, 6m scatter, HP 20, cost 22000 and cooldown 300 (`Common/Init/Init_CommonConstants.sqf:243-263`). Server support trusts the request payload for side/destination/team (`Server/Support/Support_DroneStrike.sqf:1-14`) and only checks toggle/cap locally (`:16-18`, `:46-52`); the Tactical menu still debits client funds and sends `RequestSpecial` before server acceptance (`Client/GUI/GUI_Menu_Tactical.sqf`, `DroneStrike` / `ChangePlayerFunds` / `RequestSpecial`). | Decide whether this is an economy-affecting paid support or an admin/test feature. If paid, move acceptance, cost, cooldown, upgrade, caller/team/side and map validation server-side before merge; debit only after server accept. Also decide generated Vanilla propagation vs explicit Chernarus-only scope and smoke active-cap cleanup, JIP cooldown, marker/audience behavior, resistance targeting, score effects and performance. |
| `origin/feat/recon-uav` head `563418ea` | Separate support replacement branch, not just "drone strike plus recon". Mission runtime changes are source-Chernarus-only: 22 mission files, +593/-657, with **0 maintained Vanilla mission files changed**. The total branch diff is 25 files, +1461/-657 because it also carries drone/recon `docs/superpowers` files. It adds `ReconUAV`/`ReconUAVRecall` cases (`Server/Functions/Server_HandleSpecial.sqf:63-82`), deletes the old client UAV module scripts and old `Server/Support/Support_UAV.sqf`, and adds server AI-flown recon with side-scoped reveal and cleanup (`Server/Support/Support_ReconUAV.sqf:1-22`, `:83-102`, `:119-132`, `:140-151`). It includes drone history only through `93b47594`, not latest `8ca4be90`. | Decide whether ReconUAV replaces the old UAV feature or remains experimental. Rebase/merge consciously against latest drone tuning, then smoke old-UAV removal, deploy/recall, cap decrement, destroyed-UAV cleanup, side-only reveal audience, JIP during active orbit, HQ-loss cleanup and generated Vanilla propagation. |
| `origin/feat/wf-menu-ops-console` head `0767c0b5` | UI/theme branch from stable `origin/master` `2cdf5fb8`: 23 files, +1033/-154. It rewrites the Chernarus and Vanilla palette macros (`Rsc/Styles.hpp:10-40`), retints base controls (`Rsc/Ressources.hpp:117-131`, `:274-277`), adds a main-menu chevron/footer (`Rsc/Dialogs.hpp:1057-1064`, `:1240-1249`), uses bundled-font candidates (`Dialogs.hpp:1179`, `Rsc/Titles.hpp:178-179`), mirrors the same shape to Vanilla, and ships `docs/superpowers/*` plan/spec/mockup files. Static check caveat: branch `git diff --check origin/master..origin/feat/wf-menu-ops-console` reports trailing whitespace in `docs/superpowers/plans/2026-06-03-wf-menu-ops-console.md:78,179`. | Decide whether the ops-console reskin is acceptable as a full UI theme. Before merge: clean branch whitespace, confirm `PuristaBold` and `EtelkaMonospacePro` load in Arma 2 OA or choose stock fallbacks, verify `Client\images\brand_chevron.jpg` loads from the shipped `Client/Images/brand_chevron.jpg` asset on a packed mission, smoke main menu, buy units, buy gear, upgrades, tactical/help, RHUD/FPS HUD and both Chernarus + Vanilla. |
| `origin/feat/buymenu-easa-qol` head `a66d4691` | Narrow Chernarus UI branch: `Client_UIFillListBuyUnits.sqf:1,61-62,104` tints unaffordable displayed base prices red, `GUI_Menu_BuyUnits.sqf:201-210` appends live queue counts to factory tabs, `GUI_Menu_BuyUnits.sqf:280,335,388,444,487` updates selected-unit cost display and `GUI_Menu_EASA.sqf:29-40` marks the current aircraft loadout green and preselects it. Diff is 3 files, +42/-6; `git diff --check` is clean; no maintained Vanilla files are touched. See [BuyMenu EASA QoL branch audit](BuyMenu-EASA-QoL-Branch-Audit). | Decide whether to accept these as UI-only QoL changes and whether they need maintained Vanilla propagation. Before merge, smoke Buy Units with affordable/unaffordable units, exact-funds/full-crew cases, queue count refresh without UI churn, final idc `12034` price after the later write, and EASA current-loadout selection with visible, filtered and unset current loadouts. |
| `origin/feat/player-stats` head `e01e47e1` | Adds an off-by-default stats pipeline: `WFBE_C_STATS_ENABLED = false` (`Init_CommonConstants.sqf:443`), kill stat hooks (`RequestOnUnitKilled.sqf:51-65`), `Server/Stats/RecordStat.sqf`/`StatsFlush.sqf`, DiscordBot `StatsService` RPT tailing/accumulation and `DiscordBot.Tests/*` coverage. Diff is 23 files, +1919/-1; `git diff --check` is clean; local `dotnet test` passed 13/13. See [Player stats branch audit](Player-Stats-Branch-Audit). | Decide the deployment model before enabling: RPT path/state files, stats JSON location, UID/privacy policy, log volume, corrupt-JSON recovery policy, Chernarus-only vs Vanilla propagation, DiscordBot test/build gate and whether this should remain in DiscordBot or move toward the mission extension. Runtime smoke should include disabled-by-default proof, enabled stats flush from real RPT lines, bot restart/tail-state behavior and RPT rotation behavior. |
| `origin/perf/quick-wins` head `0076040f` | Chernarus-only fix branch: 18 files, +27/-27, clean `git diff --check`, merge base `2cdf5fb8`. Fix families include side-supply clamp (`Common_ChangeSideSupply.sqf:25`, `Server_ChangeSideSupply.sqf:12,36`), crewless-buy queue decrement (`Client_BuildUnit.sqf:366-368`), paratrooper marker PV registration (`Init_PublicVariables.sqf:40`), mine cleaner pair removal (`mines_cleaner.sqf:17`), garbage collector `wfbe_trashed` guard (`server_collector_garbage.sqf:17`), patrol `&&` exits (`server_patrols.sqf:26`, `server_town_patrol.sqf:18`), fixed income interval (`updateresources.sqf:74`), camp-bunker nil-code EH removal (`Server_HandleSpecial.sqf:235-236`), kill-assist bounty type (`RequestOnUnitKilled.sqf:92`) and WASP off-by-one/nil defaults. See [Perf quick wins branch audit](Perf-Quick-Wins-Branch-Audit). | Decide whether to cherry-pick, merge whole, or split into per-fix branches. Before release wording, reconcile with existing docs/source fixes, propagate maintained Vanilla, keep DR-44 side-supply authority separate from the clamp, and smoke economy debit/no-credit inversion, factory queue counters, paratrooper markers, cleaner/camp nil-code behavior, resource-loop cadence and WASP action regressions. |
| `origin/feat/commander-positions` head `560db61c` | Broad branch with merge base `f5985b77`, not current stable `2cdf5fb8`: 83 files, +524/-2025. It adds source-Chernarus WDDM commander-position anchors/compositions through `Structures_CO_US.sqf:168-174`, `Structures_CO_RU.sqf:166-172`, `Init_Defenses.sqf:93-183`, `RequestDefense.sqf:11-14` and `Server_ConstructPosition.sqf:1-66`. It also carries Valhalla, UI, AFK/profile, HC/static-defense, performance-audit and Vanilla deltas. Branch grep found no maintained Vanilla `Server_ConstructPosition` or `WFBE_POSITION_TEMPLATE_MAP`. See [Commander positions branch audit](Commander-Positions-Branch-Audit). | Decide whether to split the construction-position feature from unrelated branch baggage and whether to propagate the actual feature to maintained Vanilla. Promotion gates: clean whitespace, recheck DR-6 construction authority, smoke placement-at-clicked-position rather than map corner, CoIn/HQ undeploy cleanup, modular wall usability/pathing and Chernarus/Vanilla scope. |
| `origin/feature/zargabad-map` head `1fdcb37a` | Terrain branch: 832 files, +77702/-95. Adds `Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad`, terrain integration (`ZARGABAD.cs:1-13`, `SqfFileGenerator.cs:127-130`), source hooks (`initJIPCompatible.sqf:121-124`, `Init_Boundaries.sqf:4-10`, `Init_Zargabad.sqf:1-125`) and Zargabad completion/runtime evidence guides. Local static validation with `Tools\Validate-ZargabadMission.ps1` passed in a detached worktree: 13 towns, 19 camps, 1 airport, 9 starts, 33 town-defense logics, no duplicate ids/missing syncs and no Takistan Zargabad-module spillover. See [Zargabad branch audit](Zargabad-Branch-Audit). | Decide whether Zargabad is a maintained Vanilla target, a separate low-pop experiment or a branch-only playtest. Before promotion: clean or accept 3542 generated whitespace findings, rerun static validation on the candidate head, run hosted/dedicated/JIP/HC smoke, review screenshots/RPT packet, verify class loads, smoke edge guard and black market, and tune town/base/camp/economy balance. |
| `origin/feat/supply-helicopter` head `262dc431` | Current PR #1 docs are refreshed against this head. Evidence includes Air-factory upgrade 3 load/action gates (`Skill_Apply.sqf:62-72`, `supplyMissionStart.sqf:21-29`), Air upgrade 4 cash-run branch (`supplyMissionCompleted.sqf:24-35`), load/unload timer constants (`Init_CommonConstants.sqf:172-173`), lobby toggle (`Rsc/Parameters.hpp:4-10`) and retained `SupplyByHeli` state after completion (`supplyMissionCompleted.sqf:40-41` clears amount/source only). No maintained Vanilla `SupplyByHeli`/heli constant hits found. | Decide Air-upgrade level semantics, cash-run economy, pilot/commander payout behavior, whether to clear `SupplyByHeli`, load/unload timer UX and Vanilla propagation. Also review non-supply baggage and branch whitespace because the diff is not supply-only. |

## 1. The big one — economy/forgery authority (one decision, whole class)

**Decision:** add server-side authority to spend/effect paths, **or** accept client-authoritative economy and ship a real BattlEye filter set. The forgery class has **two surfaces** and the decision must cover both:
- **PVF dispatcher** — `Server/Functions/Server_HandlePVF.sqf` / `Client/Functions/Client_HandlePVF.sqf` `Call Compile` the sender's command string (DR-1). Fix: validate against the known `SRVFNC*`/`CLTFNC*` set + re-derive authority in each handler. (Same change removes a per-message recompile, DR-38.)
- **Direct `publicVariableServer` channels** — e.g. `ATTACK_WAVE_INIT` (DR-41); each needs its own server re-derivation. See [Public variable channel index](Public-Variable-Channel-Index).

| Path | Finding | Severity |
| --- | --- | --- |
| PVF dispatch RCE/forgery | DR-1 | High |
| `SEND_MESSAGE` direct-PV message-text RCE | DR-46 | High |
| Construction (`RequestStructure`/`RequestDefense`/MHQ) | DR-6 | High |
| Unit purchase | DR-14 | High (architectural) |
| Structure sale | DR-16 | High |
| Side-supply transfer (overspend floor) | DR-22 | High |
| Side-supply ledger directly client-writable (forged `wfbe_supply_temp_<side>`) | DR-44 | High |
| Upgrades | DR-23 | High |
| ICBM superweapon (forged `RequestSpecial`) | DR-27 | **Critical** |
| Gear/EASA + vehicle rearm/repair/refuel/heal | DR-28 | High |
| Attack-wave price modifier (direct PV) | DR-41 | High |
| BattlEye option is **not shipped** (22-byte `kickAFK` stub only, no `scripts.txt`) | DR-30 | informs the choice |

> Caveat (DR-30): BattlEye filter files normally live in the server's `BEpath` outside the mission PBO, so confirm the production posture with the server owner before assuming it is unprotected.

## 2. Other correctness fixes (owner-scoped, source-cited)

| Decision | Finding | Severity | Note |
| --- | --- | --- | --- |
| Victory winner-inversion + duplicate game-end | DR-11, DR-13 (mechanism DR-36) | High | one-line: parenthesize/guard both win clauses with `!WFBE_GameOver` + `exitWith` the side `forEach` on win |
| Threeway mode has no victory detection | DR-12 | Medium | enable detection when `WFBE_C_VICTORY_THREEWAY != 0` |
| Commander-assign call-shape bug | DR-15 | Medium | `_side = _this` → `_this select 0` |
| Supply-mission cooldown key casing | DR-18 | Medium | align `lastSupplyMissionRun` vs `LastSupplyMissionRun` (case-sensitive getVariable) |
| HQ-killed non-idempotent score exploit | DR-20 | Medium | idempotency guard on the killed-EH |
| Factory queue soft-lock + broadcast churn | DR-33 | Medium | decrement `WFBE_C_QUEUE` on all exit paths; unique token |
| HC static-defence update-back commented out | DR-42 | Low/Med | restore the update-back or document as fire-and-forget |
| DiscordBot `TypeNameHandling.All` insecure deser | DR-31 | High (latent) | `.All` → `.None` (data is a flat DTO) |
| GLOBALGAMESTATS extension dormant deser + async-void race | DR-29 | Med | delete dead `.Auto` load; fix `File.Replace` race |

## 3. Keep-or-remove / maintenance-model decisions

Use [Abandoned feature revival](Abandoned-Feature-Revival-Review) for the source-backed revive/remove matrix behind the MASH, WASP, AI supply truck, stale UI and modded-mission rows. Paratrooper markers have moved out of the revive/remove bucket for maintained source/Vanilla: see [Paratrooper marker revival](Paratrooper-Marker-Revival) and the smoke-pending row below.

| Decision | Finding | Note |
| --- | --- | --- |
| Modded missions: regenerate from source vs maintain as forks | DR-32 | Napf/eden/lingor are divergent hand-edited forks; source fixes don't reach them |
| 4 abandoned stub missions: complete or delete | DR-32 | sahrani/dingor/tavi/isladuala are non-runnable (1–20 files) |
| MASH map-marker feature: revive or remove | DR-34 | dead both ends; revive needs server-held list + JIP re-send |
| Paratrooper drop markers: smoke propagated fix / decide modded drift | DR-2 | source Chernarus + maintained Vanilla now register the callback and ship the handler; Arma smoke and divergent modded folders remain |
| Dead WASP actions (OnArmor, GearYouUnit) | DR-35 | commented in `WASP/actions/AddActions.sqf:4` |
| `supplyMissionActive.sqf` dead twin | DR-39 | compiled but never called |
| `Init_Server.sqf` duplicate binds: 3 live + 3 commented remnants | DR-43b | Live duplicates are `LogGameEnd` (`Init_Server.sqf:64,89`), `PlayerObjectsList` (`:69,91`) and `AwardScorePlayer` (`:83,93`); commented remnants are AFK kick, server FPS and MASH marker. De-duplicate live binds; coordinate `LogGameEnd` with DR-13/DR-36. |
| `version.sqf` referenced by `description.ext:39` and `initJIPCompatible.sqf:4` but absent from tracked source | DR-43a | `git ls-files` has no `version.sqf`; commit a safe source placeholder or keep generated-only with explicit pre-pack/pre-test checks. |

## 4. Robustness / defense-in-depth (optional)

| Decision | Finding | Note |
| --- | --- | --- |
| Post-join `wfbe_*` `waitUntil` chain has no timeouts | DR-37 | a never-set synced var hangs the JIP client; add defensive timeouts |
| Server-FPS hosted/listen busy-loop | DR-19 | docs/source Chernarus + Vanilla now early-exit on `!isDedicated` (`serverFpsGUI.sqf:1`, `monitorServerFPS.sqf:1`); stable `origin/master` still has the old inner-`isDedicated` sleep, release `a9219d88` is Chernarus-only, and Arma smoke remains. |
| WASP `global_marking_monitor.sqf:62` sleepless display-wait | DR-40 | use the throttled `waitUntil {sleep …; cond}` idiom |

## Agent Handoff Contract

- Do not open a gameplay branch from this page alone; follow the canonical implementation page for source paths, exact evidence and smoke gates.
- Treat "owner decision" as **not a remaining research gap** unless a page explicitly says "research-needed".
- If a decision is made, update this page, [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and [`agent-feature-status.jsonl`](agent-feature-status.jsonl).
- If a feature is removed instead of revived, preserve a short source-backed note explaining why so future agents do not rediscover it as "missing".

## Continue Reading

Scoreboard: [Codebase coverage ledger](Codebase-Coverage-Ledger) | Evidence: [Deep-review findings](Deep-Review-Findings) | Channels: [Public variable channel index](Public-Variable-Channel-Index)
