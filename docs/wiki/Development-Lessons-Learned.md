# Development Lessons Learned

This page captures implementation lessons that future developers and agents should apply before editing the Arma 2 OA Warfare mission. It is source-backed and intentionally narrow: use it as a checklist, not a replacement for the owning atlas pages.

Source root: `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

## Lesson 0: Feature-Sounding Names Are Not Proof Of Feature Completeness

The depth-2 scout wave found a good example in AI teams: `wfbe_autonomous` sounds like a working autonomous AI feature, but `Common/Functions/Common_SetTeamAutonomous.sqf:8` only writes a replicated group variable. Current source-visible consumers are commander cleanup (`Client/FSM/updateclient.sqf:191-205`), the command-menu toggle (`Client/GUI/GUI_Menu_Command.sqf:364-389`) and AI respawn order-reset logic (`Server/AI/AI_SquadRespawn.sqf:102-109`, `Server/AI/AI_AdvancedRespawn.sqf:117-125`). Before documenting or building around a feature-sounding variable, trace writers and consumers; then describe the actual behavior in player terms.

The same rule applies to network messages that sound cosmetic. `WFBE_Server_PV_SupplyMissionCompletedMessage` looks like a notification channel, but the client handler grants funds and requests score (`Client/Module/supplyMission/supplyMissionCompletedMessage.sqf:11-23`). Treat names as clues, not proof of authority or side-effect scope.

The same rule applies to launched scripts. AntiStack starts `monitorTeamToJoin.sqf` from server init when enabled (`Server/Init/Init_Server.sqf:606-608`), but the script only reads monitored west/east skill totals and assigns a local `_side` (`Server/Module/AntiStack/monitorTeamToJoin.sqf:1-15`). It has no loop, no `setVariable`, no `publicVariable`, no return consumer and no connection to `RequestJoin`. Treat `execVM` presence as "this file runs," not "this feature has an effect."

## Highest-Value Coverage Gaps

| Area | Current coverage state | Why it still deserves attention |
| --- | --- | --- |
| Config data model | The assets/config page now has a source-backed config data-model checklist. | Keep using it before content edits; the remaining work is runtime smoke when actual classes/assets change. |
| AI respawn/orders | Respawn atlas maps AI respawn; testing workflow now has a branch-specific AI respawn smoke pack. Commander-order variable proof now lives in the AI/headless page. | Runtime Arma smoke is still needed for AI respawn branches and commander Move/Patrol/Defense/Take Towns behavior. |
| Direct-PV economy helpers | Economy authority pages map the DRs, but implementation agents still need a local rule of thumb before touching helpers. | Shared helpers can look local and harmless while publishing direct mutation payloads; read helpers show the safer server-derived pattern. |
| Post-dispatch PVF handlers | The authority map has the server-bound PVF matrix and current caller examples. | Dispatcher allowlisting prevents forged handler names, but live handlers still accept payload score, vehicle, team, side, upgrade and UID/FPS data. |
| Cleanup/garbage/empty vehicles | Marker/cleanup atlas is strong, but patch handoffs are scattered. | Cleanup code has short polling loops, global replicated queues, inconsistent flags and nested-pair array traps. |
| Non-EASA modules | Modules atlas and testing workflow now carry the runtime-edge rule. | Use the edge type before module edits: boot init, respawn reapply, unit creation attach, PV/PVF event or server loop. Runtime Arma smoke is still needed when actual behavior changes. |

## Lesson 1: Smoke Both Vanilla Branches For AI Respawn

`Init_Server.sqf` compiles different AI respawn implementations depending on `WF_A2_Vanilla`: vanilla uses `AISquadRespawn`, non-vanilla uses `AIAdvancedRespawn` (`Server/Init/Init_Server.sqf:10-12`). The advanced path is an `MPRespawn` handler entrypoint (`Server/AI/AI_AddMultiplayerRespawnEH.sqf:1`), while the vanilla path is a long-running leader watch loop (`Server/AI/AI_SquadRespawn.sqf:14-21`).

Both paths share key semantics: wait by `WFBE_C_RESPAWN_DELAY`, equip from `WFBE_%SIDE_AI_Loadout_%level`, choose camp/mobile/base fallback, and reset movement mode after non-autonomous respawn (`Server/AI/AI_AdvancedRespawn.sqf:55-76`, `:80-125`; `Server/AI/AI_SquadRespawn.sqf:53-64`, `:68-110`). Any AI respawn change needs a source check and smoke plan for both branches, or the untested branch should be explicitly called out. The concrete smoke steps now live in [Testing workflow](Testing-Debugging-And-Release-Workflow#minimal-smoke-packs).

Concrete follow-up: `Server/AI/AI_SquadRespawn.sqf:1` has a private-list typo-like entry `_rcm'`. It does not stop `_rcm` assignment at line 10, but it is a low-risk cleanup candidate when vanilla AI respawn is next touched.

## Lesson 2: Team Orders Are Public Group Variables, Not A Proven Server Command Queue

The commander UI writes orders directly through shared setters: move mode/position (`Client/GUI/GUI_Menu_Command.sqf:295-306`), force respawn (`:348-360`), autonomy toggles (`:364-389`) and AI respawn target (`:431-443`). Those setters publish group variables globally: `wfbe_autonomous`, `wfbe_respawn`, `wfbe_teammode`, and `wfbe_teamgoto` (`Common/Functions/Common_SetTeamAutonomous.sqf:8`; `Common/Functions/Common_SetTeamRespawn.sqf:8`; `Common/Functions/Common_SetTeamMoveMode.sqf:8`; `Common/Functions/Common_SetTeamMovePos.sqf:8`).

Static source search found server-side reads mainly in respawn reset logic, not a clearly owned general "server command queue." AI order helpers update group behavior and waypoints (`Server/AI/Orders/AI_MoveTo.sqf:6-21`; `AI_Patrol.sqf:7-37`; `AI_WPAdd.sqf:19-39`), but their static callers are support/resistance paths rather than the commander map-order variables (`Support_Paratroopers.sqf:92,122`; `Support_ParaAmmo.sqf:38,96`; `Support_ParaVehicles.sqf:39,78`; `AI_Resistance.sqf:14-16`). `CanUpdateTeam` suppresses automatic updates when a human commander exists (`Server/Functions/Server_CanUpdateTeam.sqf:13-17`).

Development rule: before hardening or extending commander AI orders, prove the live executor path for `wfbe_teammode` and `wfbe_teamgoto` in the target scenario. Do not assume these variables imply server-authoritative validation.

## Lesson 3: Shared Economy Mutation Helpers May Publish Direct PV Payloads

`Common_ChangeSideSupply.sqf` looks like a normal shared helper, but its final step writes `wfbe_supply_temp_<side>` and calls `publicVariableServer` (`Common/Functions/Common_ChangeSideSupply.sqf:28-30`). The server handlers then trust payload `_side` and `_amount` from `wfbe_supply_temp_west` / `wfbe_supply_temp_east` (`Server/Functions/Server_ChangeSideSupply.sqf:4-13,28-37`). That is why DR-22 and DR-44 are tied together: the same negative-delta arithmetic bug and direct-PV trust boundary meet in one helper.

Do not treat signed amounts as authority. Negative deltas are normal spend data, but the server still has to clamp the resulting balance, validate side/channel/shape, and eventually re-derive whether that spend was allowed. Use `REQUEST_SUPPLY_VALUE` / `Server_PV_RequestSupplyValue.sqf:1-8` as the safer read pattern: the client requests, and the server derives the value from server-side side state before replying.

Development rule: before editing any `Common_Change*` helper, check whether it mutates local state, replicated object/group state, or a direct publicVariable channel. If it publishes a mutation, document and smoke it like a network authority path, not a harmless utility.

## Lesson 3A: PVF Dispatch Hardening Is Not Handler Authority

`Init_PublicVariables.sqf` registers 13 server-bound PVF commands and wires each to `WFBE_PVF_<Command>` (`Common/Init/Init_PublicVariables.sqf:9-21,49-52`). Replacing dispatch-time `Call Compile` with a safe namespace lookup is necessary, but it only validates the handler name. It does not validate the values inside a legitimate command.

The current source still has active callers for several thin handlers:

- `RequestVehicleLock`: MHQ lock path and spec-ops vehicle unlock (`Client/Action/Action_ToggleMHQLock.sqf:15`; `Client/Module/Skill/Skill_SpecOps.sqf:52`) reach `RequestVehicleLock.sqf:3-8`, which locks the payload vehicle.
- `RequestTeamUpdate`: commander menu sends selected teams/side and behavior/combat/formation/speed (`Client/GUI/GUI_Menu_Command.sqf:428`) to `RequestTeamUpdate.sqf:3-26`.
- `RequestUpgrade`: upgrade UI sends side/id/current level (`Client/GUI/GUI_UpgradeMenu.sqf:161`) to a wrapper that just spawns `WFBE_SE_FNC_ProcessUpgrade` (`RequestUpgrade.sqf:5`).
- `RequestChangeScore`: reward paths send absolute score targets from clients (`TownCaptured.sqf:71,79`; `CampCaptured.sqf:38`; `supplyMissionCompletedMessage.sqf:22`; `Client_FNC_Special.sqf:118`) to `RequestChangeScore.sqf:3-13`, which removes old score and applies the payload value.
- `update-clientfps`: the client FSM sends `getPlayerUID(player)` and averaged FPS (`Client/FSM/updateavailableactions.fsm:121-125`) to `Server_HandleSpecial.sqf:75-83`, and delegation later trusts that stored data.

Development rule: after the PVF dispatcher patch, claim "dispatcher RCE closed" only. Handler authority needs a second pass per effect: requester, side, object, role, range, funds/supply, idempotency and payload-shape validation. Use [Server authority migration map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) as the work queue.

## Lesson 3B: Branch-Scoped Fix Evidence Beats Generic "Shipped" Claims

Supply mission scan narrowing is a good branch-scope trap. Current docs/source Chernarus and maintained Vanilla use the narrowed truck scan (`supplyMissionStarted.sqf:25-28`), `origin/master` still uses the older broad command-center scan, `origin/feat/supply-helicopter` head `262dc431` adds `SupplyByHeli` but does not clear it on completion, and `origin/release/2026-06-feature-bundle` head `a9219d88` has the heli-aware scan at `supplyMissionStarted.sqf:50-56` plus `SupplyByHeli` cleanup after release commit `4cf443fe`.

Development rule: when a docs page says "fixed", "shipped", "current" or "propagated", record which branch proves it. Use `origin/master`, docs/source Chernarus, maintained Vanilla, feature branch and release branch as separate evidence buckets. Do not convert a release-branch fix into a stable-master claim, and do not leave older "still open" remediation steps below a newer branch-scoped update banner.

## Lesson 4: Cleanup Loops Are Server-Owned But Some Inputs Are Client-Replicated

The server starts the garbage collector, empty-vehicle collector, dropped-item cleaner, crater cleaner, ruins cleaner, building restorer and mine cleaner after init (`Server/Init/Init_Server.sqf:521-560`). Several loops run frequently or over broad areas:

- Garbage scans `allDead` every 0.5 seconds, skips HQ objects and objects carrying `wfbe_trashable`, then spawns `TrashObject` (`Server/FSM/server_collector_garbage.sqf:4-23`, `:32`).
- Empty-vehicle collection reads replicated `WF_Logic getVariable "emptyVehicles"` every 0.5 seconds and drains handled objects (`Server/FSM/emptyvehiclescollector.sqf:4-21`, `:30`).
- Client vehicle creation appends new vehicles into that replicated empty-vehicle list (`Client/Functions/Client_BuildUnit.sqf:249-253`).

Development rule: queue-processing fixes must be idempotent under repeated client publications and hosted/dedicated locality. Do not treat a server loop as fully server-owned just because it runs on the server.

## Lesson 5: Cleanup Flags And Nested Arrays Need Shape Checks

The garbage collector skips `wfbe_trashable`, but kill handling marks `wfbe_trashed` before spawning `TrashObject` (`Server/FSM/server_collector_garbage.sqf:17`; `Server/PVFunctions/RequestOnUnitKilled.sqf:50-54`). That is a flag-contract mismatch and a good example of why cleanup patches need source shape checks.

The mine cleaner initializes `mines = []`, expects `[mine, time]` pairs, and deletes expired mines, but removes with `mines = mines - _x` (`Server/FSM/cleaners/mines_cleaner.sqf:3-17`). Producers append nested pairs from RPG dropping and stationary defense (`WASP/rpg_dropping/DropRPG.sqf:65-68`; `Server/Construction/Construction_StationaryDefense.sqf:31-55`). For nested pairs, removal should preserve array shape, for example `mines = mines - [_x]`, or be rewritten as a filtered live-pair list.

Development rule: before changing cleanup arrays, cite both producer and consumer shapes.

## Lesson 6: Config Changes Propagate Through Derived Runtime Tables

`Common/Config/readme.txt` describes a modular core system: gear registers weapons/magazines/backpacks, group config defines town groups, loadout files define gear-menu templates, model/root files define side support assets and defaults (`Common/Config/readme.txt:7-26`, `:28-42`, `:50-65`). Runtime init then chooses faction roots from parameters and loads root, defense and group files (`Common/Init/Init_Common.sqf:263-308`).

The config layer is not static data only. `Init_Common` mutates derived values: it doubles some unit prices under `WFBE_C_UNITS_PRICING`, records longest build time per factory type, multiplies structure costs for money-only economy and builds aggregate repair-truck lists (`Common/Init/Init_Common.sqf:325-367`). Gear helpers validate engine config classes and set missionNamespace records (`Common/Config/Config_Weapons.sqf:12-44`; `Config_Magazines.sqf:11-34`; `Config_Backpack.sqf:11-65`), while templates compute price/upgrade from registered items (`Common/Config/Config_SetTemplates.sqf:33-123`).

Development rule: content changes are not complete when the class appears in one list. Verify the side root, factory list, gear registry, loadout template, AI loadout or squad data, upgrade level, pricing, and generated mission propagation.

Also verify the source line shape, not only the intended variable name. `Root_RU.sqf:36` places the `WFBE_%1PARAAMMO` assignment after a `//--- Starting Vehicles` comment on the same physical line, so the assignment is commented out before `Support_ParaAmmo.sqf:59-60` can read it as an array. Other root files put `WFBE_%1PARAAMMO` on its own line. For config edits, run a quick grep for the variable across peer roots and inspect whether comments, merge markers or generator skip-list files changed the executable SQF.

## Lesson 7: Module Wiring Often Happens At Creation Or Init Time

Client init compiles supply/MASH/AntiStack/PV helpers and module gates near the main function registry (`Client/Init/Init_Client.sqf:127-135`), then later applies skill, WASP actions, AutoFlip, artillery UI, EASA and CM gates (`Client/Init/Init_Client.sqf:570-589`). Common init wires ICBM, IRS and CIPHER after config loading (`Common/Init/Init_Common.sqf:319-323`).

Some module effects attach when units or vehicles are built rather than when the module file is loaded. That means a module patch can require factory/purchase smoke even if the module file itself is small.

Development rule: for module edits, identify whether the runtime edge is "boot init", "player respawn reapply", "unit creation attach", "PV/PVF event", or "server loop". Smoke the edge, not just the edited file.

## Lesson 8: Wait Gates Need Producer And Timeout Evidence

The lifecycle boot path uses hand-rolled `waitUntil` barriers instead of engine-managed init ordering. Some join gates are retrying handshakes: `RequestJoin` polls `WFBE_P_CANJOIN` and resends after 30 seconds (`Client/Init/Init_Client.sqf:416-431`), while the launch ACK path republishes `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH` after the same 30-second window (`:441-456`). Many later gates are different: `wfbe_structures`, `wfbe_supply_<side>`, `wfbe_commander`, radio HQ state, spawn/HQ state, `townInit` and `wfbe_votetime` use raw waits with no terminal timeout (`Init_Client.sqf:367-371,384,394-398,461-490,595,787-789`).

Development rule: before moving or patching lifecycle waits, cite both the consumer wait and the producer set/publicVariable. Do not copy the 30-second retry language onto raw `waitUntil` gates unless the code actually retries. Use [Lifecycle wait-chain](Lifecycle-Wait-Chain#post-join-wait-audit) as the owner table for condition, producer, timeout/logging and failure mode.

## Lesson 9: Machine Ledgers Need Branch Scope, Not Just Fix Scope

Human pages can be correct while JSON/JSONL agent ledgers still mislead future agents. The 2026-06-03 branch matrix found that docs/source `HEAD` `4163faba` carries hosted FPS loop exits, supply command-center scan narrowing, client `Skill_Init` idempotency and paratrooper marker registration in both maintained missions, while stable `origin/master` `2cdf5fb8` carries none of those four shapes. Release `origin/release/2026-06-feature-bundle` `a9219d88` is mixed: Chernarus carries FPS/supply scan changes, release Vanilla does not, and the release branch still lacks client `Skill_Init` idempotency plus paratrooper marker registration in both maintained missions.

Development rule: a machine record that says `patched`, `propagated`, `release-ready` or similar must name the branch/commit it describes and whether Chernarus and maintained Vanilla both carry the same line shape. If branch scope is missing, treat the record as a lead and re-open [Current source status snapshot](Current-Source-Status-Snapshot#2026-06-03-branch-matrix) before planning code work.

## Lesson 10: Revival Branches Need Default, Propagation And Smoke Labels

`origin/feat/ai-commander` is useful branch evidence, but it is not stable-master truth. Current head `4dba060e` adds a server-side AI commander supervisor, assignment workers, production worker and order executor; earlier branch commits `585c3519`, `1a3e3def` and `4c2abced` add AI commander constants, default-on parameter behavior, upgrade debit/index fixes and compile/start wiring. The diff is source-Chernarus-only: no maintained Vanilla files are touched.

The branch also changes behavior, not only missing plumbing. `Rsc/Parameters.hpp:96` defaults AI commander to on, `Init_Server.sqf:630-631` spawns one supervisor per side, `AI_Commander.sqf:43-72` chooses full-vs-assist mode, and `AI_Commander_Produce.sqf:73-80` spends AI commander funds through `AIBuyUnit`. At the same time, the old autonomous supply-truck path is only guarded: `UpdateSupplyTruck` remains commented and the missing `Server/FSM/supplytruck.fsm` is not restored.

Development rule: when a branch revives a dormant feature, document three labels before anyone merges or builds on it: default behavior change, propagation scope and runtime smoke state. For AI commander, smoke no-human full command, human-commander assist/no-spend, order execution, AI production cap, upgrade funds/supply, commander vote/revote, HQ death, JIP and Vanilla propagation before calling the feature revived.

## Lesson 11: Smoke Plans Are Not Runtime Proof

The branch-only feature smoke pack is intentionally marked planned. It tells release owners how to test `feat/ai-commander`, `feat/drone-saturation-strike` and `feat/recon-uav`, but it is not evidence that those features work in Arma 2 OA. The matching machine ledger keeps `plannedSmoke.status = planned-not-run` for each branch gate until a tester records RPT snippets, manual observations or artifacts against the [agent test schema](agent-test-plan.schema.json).

Development rule: never promote `planned`, `source-only` or checklist text into `passed`, `stable`, `release-ready` or `smoked` wording. A smoke claim needs target branch/commit, mission variant, server mode, relevant params, steps, observations and failure-signal review. If those are missing, keep the state as planned and link the checklist.

## Lesson 12: Dark-Launched Integration Branches Still Need Ops Gates

`origin/feat/player-stats` is deliberately safe by default: `WFBE_C_STATS_ENABLED = false` at `Init_CommonConstants.sqf:443`, `RecordStat.sqf:9-10,31-32` exits when disabled, and `StatsFlush.sqf:6-7` exits before the loop unless the flag is enabled. The DiscordBot side also no-ops unless `Preferences.StatsEnabled` is true and `ServerRptPath` is set (`Preferences.cs:16-20`, `StatsService.cs:17-23`).

That does not make the feature ready for public enablement. The branch crosses several operational boundaries: `StatsFlush.sqf:48` emits RPT lines; `RptTailer.cs:24-45,57-71` persists offset/fingerprint state beside `stats.json`; `StatsDocument.cs:22-40` returns an empty document on load errors and writes via temp/replace; `PlayerStat.cs:23-45` must stay index-aligned with SQF constants at `Init_CommonConstants.sqf:445-459`; and the identity key is Steam UID64. Local validation is useful but scoped: `dotnet test DiscordBot.Tests/DiscordBot.Tests.csproj` passed 13/13 on .NET 9.0.314, while Arma 2 OA runtime smoke and maintained Vanilla propagation remain open.

Development rule: for dark-launched integration branches, document two separate states: "safe when disabled" and "safe to enable." The second state needs runtime smoke, privacy/retention decisions, file/state ownership, failure/recovery policy, log-volume review and propagation scope. See [Player stats branch audit](Player-Stats-Branch-Audit).

## Lesson 13: Broad Feature Branches Need Payload, Baggage And Propagation Labels

`origin/feat/commander-positions` is useful branch evidence, but the branch name hides three separate facts. The feature payload is source-Chernarus WDDM commander-position construction: side defense anchors in `Structures_CO_US.sqf:168-174` and `Structures_CO_RU.sqf:166-172`, template variables and `WFBE_POSITION_TEMPLATE_MAP` in `Server/Init/Init_Defenses.sqf:93-183`, compile wiring at `Server/Init/Init_Server.sqf:26`, request routing at `Server/PVFunctions/RequestDefense.sqf:11-14`, and composition placement in `Server/Functions/Server_ConstructPosition.sqf:1-66`.

The baggage is broad. The branch has merge base `f5985b77`, not stable `origin/master` `2cdf5fb8`; `git diff --stat origin/master..origin/feat/commander-positions` reports 83 files, +524/-2025, with unrelated Valhalla, AFK/profile, service/team/upgrade UI, `Server_HandleSpecial`, `Server_AssignNewCommander`, town-AI and static-defense delegation deltas. `git diff --check` also reports trailing whitespace in Chernarus and maintained Vanilla source files.

The propagation scope is narrower than the branch footprint. Branch grep found no `Server_ConstructPosition`, `WFBE_POSITION_TEMPLATE_MAP` or WDDM commander-position anchor registrations under `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`. The branch touches Vanilla, but the new commander-position runtime is not propagated there.

Development rule: before merge/release claims for a broad feature branch, document three labels separately: feature payload, branch baggage and propagation scope. See [Commander positions branch audit](Commander-Positions-Branch-Audit).

## Lesson 14: Head-Drift Notes Must Become Current Tables

The PR #1 supply-heli page originally carried an older `ffeea4c2` line audit with a current-head note for `262dc431`. That was better than silence, but it still left adjacent pages saying the PR page needed refresh and hid a current-head state-cleanup gap. Rechecking `origin/feat/supply-helicopter@262dc431` showed the exact current shape: lobby toggle at `Rsc/Parameters.hpp:4-10`, supply-heli constants/timers at `Init_CommonConstants.sqf:168-180`, Air 3 action gate at `Skill_Apply.sqf:62-72`, client load/start at `supplyMissionStart.sqf:16-60`, server dwell/interdiction at `supplyMissionStarted.sqf:7-30,42-60,93-95`, and Air 4 cash-run completion at `supplyMissionCompleted.sqf:24-41`.

The current-head recheck also found a small but important state-cleanup decision: `SupplyByHeli` is written at start and read by the started/completed handlers, while completion clears `SupplyAmount` and `SupplyFromTown` only. That may be harmless because `SupplyAmount` is zeroed, but it should be explicitly fixed or accepted before merge.

Development rule: when a branch-head note says older line refs are superseded, refresh the canonical table and all adjacent machine/status rows in the same batch. A note is not enough once owners are using the page for merge gates. See [Current supply heli PR](Current-Work-Supply-Helicopters-PR1).

## Lesson 15: Map Branches Need Static And Runtime Done States

`origin/feature/zargabad-map` is a useful example of a strong static map branch that is still not runtime-complete. `Tools\Validate-ZargabadMission.ps1` passed on current head `e9294ede`, proving object/sync/count/value/layout invariants: 13 towns, 19 camps, 1 airport, 9 start logics, 33 town-defense logics, no duplicate mission object ids, no missing synchronization targets and no Takistan Zargabad-module spillover. The refreshed head also shows a second lesson: map branches can carry balance policy, not only object placement. Zargabad now has tuned low-pop defaults for AI caps, player AI caps, Soldier cap, supply cap, UAV/range limits, air countermeasures, starting funds/supply, ICBM state and price multipliers.

That does not prove the mission is playable. The branch's own completion gates require hosted/dedicated Arma 2 OA runtime evidence, plus JIP/HC evidence when those claims are made, screenshot packets for visual/pathing/balance rows and runtime-report validation. Future agents should say "static validation passed" and "runtime evidence open" separately for terrain branches. See [Zargabad branch audit](Zargabad-Branch-Audit).

## Lesson 16: Small Fix Branches Need Payload Tables Too

`origin/perf/quick-wins` shows why a branch name is not enough. Head `0076040f` is compact and clean (`18 files, +27/-27`, no `git diff --check` findings), but the payload crosses several ownership boundaries: DR-22 side-supply clamp shape (`Common_ChangeSideSupply.sqf:25`, `Server_ChangeSideSupply.sqf:12,36`), DR-33a factory queue cleanup (`Client_BuildUnit.sqf:366-368`), DR-2 paratrooper marker PV registration (`Init_PublicVariables.sqf:40`), mine/dead-object/resource-loop cleanup (`mines_cleaner.sqf:17`, `server_collector_garbage.sqf:17`, `updateresources.sqf:74`), patrol exit conditions (`server_patrols.sqf:26`, `server_town_patrol.sqf:18`), camp-bunker nil-code EH removal (`Server_HandleSpecial.sqf:235-236`), kill-assist bounty type (`RequestOnUnitKilled.sqf:92`) and WASP off-by-one/nil-default fixes.

The propagation scope is also narrower than the fix list. The branch touches only source Chernarus; `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` has no branch diff and still carries old shapes such as `_currentSupply - _amount`, `WFBE_SE_FNC_OnBuildingKilled`, undefined `_objectType` and `GetSleepFPS` in `updateresources.sqf`.

Development rule: even for a tiny branch, document the payload, baggage, propagation scope and smoke gates before merge/release wording. A fix can be high-confidence static evidence while still requiring Vanilla propagation and Arma runtime smoke. See [Perf quick wins branch audit](Perf-Quick-Wins-Branch-Audit).

## Lesson 17: UI QoL Branches Need Final-Control Smoke

`origin/feat/buymenu-easa-qol` is a small branch, but source review still found multiple UI lifecycle edges that static diffs alone do not prove. The branch colors Buy Units displayed base prices red when `_price > _funds` (`Client_UIFillListBuyUnits.sqf:61-62,104`), appends live queue counts to factory tabs (`GUI_Menu_BuyUnits.sqf:201-210`), updates selected-unit cost formula and idc `12034` writes (`GUI_Menu_BuyUnits.sqf:280,335,388,444,487`) and highlights the current EASA loadout (`GUI_Menu_EASA.sqf:29-40`).

Those are useful changes, but the visible behavior depends on later control writes, lock/crew toggles, row filtering and live missionNamespace queue variables. The EASA highlight also does not solve exact-funds purchase rejection or stale/unsupported vehicle context because it does not change `GUI_Menu_EASA.sqf:46-50` or `EASA_Equip.sqf`.

Development rule: for UI QoL branches, smoke the final rendered control state and interaction loop, not just the changed hunk. Include low/exact/high funds, crew toggles, tab switching, queue changes, filtered rows and maintained Vanilla propagation before release wording. See [BuyMenu EASA QoL branch audit](BuyMenu-EASA-QoL-Branch-Audit).

## Lesson 18: Valid Stringtable Keys Can Still Be Stale Design Truth

Localization integrity checks prove that referenced keys resolve; they do not prove that the copy describes current mechanics. The supply mission help text is the current example. `stringtable.xml:188-193` still says supply-truck delivery pays `4 x the actual value`, and `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF = 4` remains defined at `Init_CommonConstants.sqf:268`. Current source does something else: `supplyMissionStart.sqf:22-34` computes `SupplyAmount` as town supply value times the supply mission multiplier (`20`) times the supply upgrade modifier, and `supplyMissionCompletedMessage.sqf:8,13-14` grants raw `_supplyAmount` as the player's cash reward.

Development rule: when a player-facing string describes economics, rewards, restrictions or server policy, verify it against the live consumer before treating it as design truth. If the string is stale, document it as copy/design drift and update stringtable plus behavior together when the owning system is rebalanced. See [Economy, towns and supply](Economy-Towns-And-Supply#supply-mission-reward-formula-and-stale-copy).

## Lesson 19: Server-Side Spend Paths Can Still Have Currency Semantics Bugs

The AI commander upgrade path is server-side, but the currency tuple ordering still has to match the human path. The player upgrade menu treats `WFBE_C_UPGRADES_COSTS` as `[supply, funds]`: it reads supply from element `0`, funds from element `1`, validates both, deducts client funds and then deducts side supply (`GUI_UpgradeMenu.sqf:96-99,139-159`). The AI commander server path validates the same tuple as supply then AI funds (`Server_AI_Com_Upgrade.sqf:32-36`), but its deduction reverses the semantics: it subtracts `_cost select 0` from AI commander funds and `_cost select 1` from side supply (`Server_AI_Com_Upgrade.sqf:47-50`).

Development rule: do not assume "server-side" means "authority-correct." For every spend path, cite the tuple producer, the UI display/validation, and the mutation calls together. This belongs with [Economy authority first cut](Economy-Authority-First-Cut), [Economy, towns and supply](Economy-Towns-And-Supply) and [Feature status](Feature-Status-Register).

## Lesson 20: Income Display Is Not Payout Proof

`Client_GetIncome.sqf` is useful for the player-facing estimate, but it is not the payout owner. The server loop computes per-side supply, income, player/commander splits and side supply mutation in `updateresources.sqf:29-70`; the HUD/helper estimate recomputes the expected value in `Client_GetIncome.sqf:3-31`. Those formulas are close, but not identical in all modes. For example, income system 4 multiplies player income by `1.5` before commander split on the server (`updateresources.sqf:41-44`), while the client helper uses a simpler `_income - _ply` commander calculation (`Client_GetIncome.sqf:20-29`).

Development rule: when auditing economy balance, separate "what the UI predicts" from "what the server mutates." Any fix or docs claim about income needs both files and a test note for the active income-system parameter.

## Lesson 21: Visible UI Affordances Can Be Partial Or Stale

Several UI surfaces look wired until the final send/cleanup edge is checked. The commander task menu builds task data and even plays HQ radio speech, but the actual `SetTask` send calls are commented out (`GUI_Menu_Command.sqf:315-344`) while the receiver still exists and creates a simple task (`SetTask.sqf:8-14`). Commander vote dialogs iterate from `0` to `WFBE_Client_Teams_Count` inclusively after `WFBE_Client_Teams_Count = count WFBE_Client_Teams` (`Init_Client.sqf:273`, `GUI_Commander_VoteMenu.sqf:58-66`, `GUI_VoteMenu.sqf:29,61-66`). The help dialog mixes `execVM` on load with `call compile preprocessFileLineNumbers` on unload (`Dialogs.hpp:3446-3447`, `GUI_Menu_Help.sqf:5-10`). WASP marker capture temporarily calls `disableUserInput true` while waiting for display `54` and only releases after the timed loop (`global_marking_monitor.sqf:57-73`).

Development rule: for UI claims, trace the button/dialog surface to the receiver and the cleanup path. A receiver file existing is not proof the user can reach it, and a visible control is not proof the action survives final-control smoke. See [Client UI systems atlas](Client-UI-Systems-Atlas), [Player UI workflow map](Player-UI-Workflow-Map) and [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas).

## Lesson 22: HC Means Two Different Things In This Mission

The codebase uses "HC" for both headless-client delegation and Arma High Command UI, and those must stay separate in docs and fixes. The Arma High Command UI add path is effectively inert because `_hc_enabled = false` gates `HCSetGroup` additions (`updateavailableactions.fsm:47,115-117`), although cleanup still removes any high-command groups (`updateclient.sqf:204,228`). Headless-client registration is a different path: `Init_HC.sqf:11-15` publishes `connected-hc`, and the server only registers the HC when `owner _hc` is nonzero; owner id `0` logs a warning and has no retry in that handler (`Server_HandleSpecial.sqf:117-130`). Client FPS delegation is separate again: clients report UID/FPS through `update-clientfps` (`updateavailableactions.fsm:121-125`), the server stores the payload by UID (`Server_HandleSpecial.sqf:75-83`), and delegation selection trusts that stored FPS/slot count (`Server_FNC_Delegation.sqf:153-158`).

Commented HC revival hooks also need payload-shape review, not only compile/grep review. Static-defense HC creation receives `_retVal` from `Common_CreateUnitForStaticDefence.sqf`, assigns `_teams = _retVal select 0` (`Client_DelegateAIStaticDefence.sqf:25-26`), and the helper returns only `[_teams]` (`Common_CreateUnitForStaticDefence.sqf:69`). The commented update-back at `Client_DelegateAIStaticDefence.sqf:28` therefore cannot be restored as a complete accounting fix by itself: `Server_HandleSpecial.sqf:86-96` has only the town-vehicle `update-town-delegation` receiver, and static-defense tracking would need defense object, side, created units/groups and cleanup semantics.

Development rule: when an issue says "HC," first classify it as headless client registration, headless delegation, client-FPS delegation, or Arma High Command UI. Mixing those paths creates bad fixes and confusing docs. See [AI/headless and performance](AI-Headless-And-Performance) and [Headless delegation and failover playbook](Headless-Delegation-And-Failover-Playbook).

## Lesson 23: Spark Scouts Need File-Family Scope And Output Caps

The 2026-06-04 scout waves showed a reliable pattern: broad Spark prompts over this repo often overflow during remote compacting, even when the task is read-only. Whole-lane prompts for "AI commander/team orders", "server runtime safety" and full town lifecycle bounced with context-window errors. Narrow relaunches did better when they named exact file families and answer shape, such as `Server_AI_Com*.sqf` only, town capture/camp/supply only, or AFK/AntiStack only.

The useful reports came from scouts with tight boundaries and capped output: supports/services produced a clean transport split, respawn/MASH/gear confirmed the no-revive architecture and profile-template bug, AI commander upgrade-only clarified deterministic first-unmet upgrade selection, construction found the stationary-defense null guard, and town capture produced a compact ownership chain.

Development rule: launch Spark scouts as small drill cores, not subsystem encyclopedias. Each prompt should name exact files or search terms, forbid generated-mission scans unless needed, cap output under roughly 800-1200 words, ask for concrete file:line evidence, and say "no edits." If a scout bounces, relaunch with a smaller file family instead of retrying the same broad question. Use the dashboard/worklog to record failed broad scopes as orchestration evidence, not as source findings.

## Lesson 24: Tool Commands Are Branch-Scoped Evidence

Tooling pages can drift just like mission code. The current docs branch contains `docs/validate-wiki.ps1` as the wiki validator; it does not contain the older `Tools\ValidateWiki.ps1` or `Tools\TestWikiParity.ps1` helper names that appear in historical reconciliation notes. The Zargabad map branch is the opposite shape: `git ls-tree -r --name-only origin/feature/zargabad-map` shows branch-local validators such as `Tools/Validate-ZargabadMission.ps1` and `Tools/Validate-ZargabadRuntimeReport.ps1`, but those files are not present on the current docs branch.

Development rule: when a page says "run this tool," verify the script exists on the branch or worktree being used for the claim. For current wiki edits, use `powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1`, `git diff --check`, JSON/JSONL parsing when touched, and SHA256 parity for mirrored pages. For branch-specific features such as Zargabad, run branch-local validators from a worktree at the exact candidate head and label them branch evidence, not current-checkout tooling.

## Lesson 25: Lobby Parameters Are Not Runtime Truth By Themselves

`Init_Parameters.sqf` exports `class Params` entries by class name and index order, but later code can still diverge from the visible lobby surface. The 2026-06-04 config scout found several current examples: `Rsc/Parameters.hpp:393-397` exposes `WFBE_C_MODULE_WFBE_IRS`, while runtime init and upgrade gates read `WFBE_C_MODULE_WFBE_IRSMOKE` (`Init_CommonConstants.sqf:238`, `Init_Common.sqf:320`, `Upgrades_CO_US.sqf:24-25`); `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE` is commented out in the parameter tree but still consumed by server upgrade initialization (`Parameters.hpp:351-356`, `Init_CommonConstants.sqf:225`, `Server/Init/Init_Server.sqf:333-349`); and `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC` is visible but forced to `0` in constants and client init (`Parameters.hpp:210-214`, `Init_CommonConstants.sqf:212`, `Init_Client.sqf:218`).

Development rule: for any parameter claim, cite three layers together: the lobby class, the constants fallback and the live consumer or forced assignment. A visible host setting can be a locked switch, an orphan, a stale name or internal boot state. Do not rebalance or document operator behavior from `Parameters.hpp` alone. See [Mission parameters, localization and generated build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) and [Assets/config/localization/parameters atlas](Assets-Config-Localization-And-Parameters-Atlas).

## Lesson 26: UI Outcome Preview Is Not Server Resolution

The commander vote mismatch is a compact example of why UI prediction and server truth must be audited together. The server vote worker counts AI/no-commander votes where `wfbe_vote == -1` (`Server_VoteForCommander.sqf:24-29`), but the final condition selects any non-tied player candidate because `_highest >= _aiVotes` OR `_highest <= _aiVotes` is always true for numeric counts when `_highestTeam != -1` (`Server_VoteForCommander.sqf:43`). The client vote dialog can preview AI/no commander when no option has more than half the counted player voters or row 0 leads (`GUI_VoteMenu.sqf:87-89`).

Development rule: when a dialog predicts a winner, price, reward, permission or cooldown, inspect the server resolver before claiming behavior. Treat mismatches as semantics decisions first, then source patches. For commander voting, owners must decide plurality, strict majority, tie and AI/no-commander rules before editing `Server_VoteForCommander.sqf`.

## Proposed Backlog Patches

| Priority | Patch | Owner page target | Validation |
| --- | --- | --- | --- |
| Done | Development lessons and `agent-development-lessons.jsonl` are wired into navigation and agent context. | `Home`, `_Sidebar`, `Agent-Context`, `agent-context.json` | Link check and JSON parse; evidence rechecked at `Home.md:10,33,76,100,102`, `_Sidebar.md:10,12,119,121`, `Agent-Context.md:3,11,13,75` and `agent-context.json:69,87,141,163-185,479-480,1205`. |
| Done | Config data-model checklist added to the assets/config atlas. | `Assets-Config-Localization-And-Parameters-Atlas#config-data-model-checklist` | Runtime content-change smoke remains per feature change. |
| Done | AI respawn branch smoke is now in the testing workflow. | `Testing-Debugging-And-Release-Workflow#minimal-smoke-packs` | Runtime evidence is still pending until vanilla and non-vanilla AI leader death/respawn are run in Arma 2 OA. |
| Done | Cleanup flag/nested-pair shape rules are already accepted in the marker/cleanup atlas patch-ready section. | `Marker-Cleanup-Restoration-Systems-Atlas#patch-ready-findings` | Mine expiry and unit-kill garbage smoke remain the runtime gates before source patch acceptance. |
| Done | Cleanup/restorer cadence and cost interpretation added to the marker/cleanup atlas. | `Marker-Cleanup-Restoration-Systems-Atlas#cadence-and-cost-interpretation` | Runtime RPT samples still needed before performance tuning patches. |
| Done | Commander `wfbe_teammode`/`wfbe_teamgoto` source proof added to AI/headless and UI/feature pages. | `AI-Headless-And-Performance#commander-team-order-variables` | Dedicated commander AI order smoke is still pending. |

## Agent Handoff

This page is safe to integrate because it adds a new, source-cited lesson artifact and does not alter the DR-44-owned networking/server atlas/instructions pages. The matching machine-readable records live in `agent-development-lessons.jsonl`.
