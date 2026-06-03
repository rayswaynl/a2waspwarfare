# Development Lessons Learned

This page captures implementation lessons that future developers and agents should apply before editing the Arma 2 OA Warfare mission. It is source-backed and intentionally narrow: use it as a checklist, not a replacement for the owning atlas pages.

Source root: `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

## Highest-Value Coverage Gaps

| Area | Current coverage state | Why it still deserves attention |
| --- | --- | --- |
| Config data model | The assets/config page now has a source-backed config data-model checklist. | Keep using it before content edits; the remaining work is runtime smoke when actual classes/assets change. |
| AI respawn/orders | Respawn atlas maps AI respawn; testing workflow now has a branch-specific AI respawn smoke pack. Commander-order variable proof now lives in the AI/headless page. | Runtime Arma smoke is still needed for AI respawn branches and commander Move/Patrol/Defense/Take Towns behavior. |
| Direct-PV economy helpers | Economy authority pages map the DRs, but implementation agents still need a local rule of thumb before touching helpers. | Shared helpers can look local and harmless while publishing direct mutation payloads; read helpers show the safer server-derived pattern. |
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

`origin/feature/zargabad-map` is a useful example of a strong static map branch that is still not runtime-complete. `Tools\Validate-ZargabadMission.ps1` passed on head `1fdcb37a`, proving object/sync/count/value/layout invariants: 13 towns, 19 camps, 1 airport, 9 start logics, 33 town-defense logics, no duplicate mission object ids, no missing synchronization targets and no Takistan Zargabad-module spillover.

That does not prove the mission is playable. The branch's own completion gates require hosted/dedicated Arma 2 OA runtime evidence, plus JIP/HC evidence when those claims are made, screenshot packets for visual/pathing/balance rows and runtime-report validation. Future agents should say "static validation passed" and "runtime evidence open" separately for terrain branches. See [Zargabad branch audit](Zargabad-Branch-Audit).

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
