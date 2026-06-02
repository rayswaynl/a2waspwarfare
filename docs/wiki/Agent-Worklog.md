# Agent Worklog

Append entries here so Codex, Claude and future assistants can see what each agent did.

## 2026-06-02 - Codex Wiki-Quality DUP-5 BattlEye Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-5 by making [External integrations](External-Integrations) the canonical shipped BattlEye/server-filter posture page.
- Added a compact evidence table for the in-tree `BattlEyeFilter/publicvariable.txt` AFK rule, the missing broader filter/config bundle and the production `BEpath` owner question.
- Trimmed [Feature status](Feature-Status-Register), [Networking and public variables](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap) and [Server authority map](Server-Authority-Migration-Map) so they route to the canonical posture page instead of repeating DR-30 evidence.

## 2026-06-02 - Codex ICBM Authority Playbook

- Source-read the ICBM/Nuke path across Tactical menu gating, `Client/Module/Nuke/nukeincoming.sqf`, `Server/PVFunctions/RequestSpecial.sqf`, `Server/Functions/Server_HandleSpecial.sqf` and `Client/Module/Nuke/damage.sqf`.
- Added [ICBM authority](ICBM-Authority-Playbook) as the canonical DR-27 implementation playbook for server-side commander/team, side, module/upgrade, funds/cost, impact-anchor and idempotency validation.
- Routed [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Feature status](Feature-Status-Register), Home/sidebar/footer and [Wiki quality audit](Wiki-Quality-Audit) to the playbook so DUP-3 has one source of implementation detail.

## 2026-06-02 - Codex Wiki-Quality MERGE-1 Authority Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) MERGE-1 by splitting ownership between [Hardening implementation roadmap](Hardening-Implementation-Roadmap) and [Server authority migration map](Server-Authority-Migration-Map).
- Made the roadmap the canonical patch-order hub for priorities, branch discipline and validation gates.
- Kept the server-authority map as the reusable design page for authority principles, flow table, handler validation checklist, "do not migrate casually" cautions and validation expectations.
- Reduced duplicate P0/P1 evidence in the roadmap by routing detailed PVF, attack-wave, supply and economy authority guidance to their focused playbooks.

## 2026-06-02 - Codex Wiki-Quality DUP-10 HC Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-10 by making [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) the canonical implementation playbook for DR-21/DR-42.
- Reduced [AI, headless and performance](AI-Headless-And-Performance) to a concise HC source router for bootstrap, registration, town AI, static defense, disconnect and late-HC source anchors.
- Clarified [Lifecycle wait-chain](Lifecycle-Wait-Chain) owns only HC boot timing and the `Init_HC.sqf` fixed `sleep 20` vs `serverInitFull` wait-chain risk.
- Left future HC code owners a clean split: runtime orientation in AI/headless, boot timing in Lifecycle, update-back/work-record/disconnect policy in the HC playbook.

## 2026-06-02 - Codex Wiki-Quality C3 Gameplay Follow-Ups

- Resolved [Wiki quality audit](Wiki-Quality-Audit) C3 by replacing stale [Gameplay systems atlas](Gameplay-Systems-Atlas) open questions with a source-backed resolved follow-up table.
- Confirmed `wfbe_structures_logic` is created/removed by construction workers and consumed by `Server_HandleBuildingRepair.sqf`.
- Confirmed supply-income stagnation is live when `updateresources.sqf` calls `ChangeSideSupply` with stagnation enabled.
- Clarified that `Init_BaseStructure.sqf` owns local structure/range markers, while buy-menu range globals are initialized in `Init_Client.sqf`, updated by `updateavailableactions.fsm` and consumed by `GUI_Menu*.sqf`.

## 2026-06-02 - Codex Wiki-Quality DUP-11 PV Channel Index

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-11 by making [Public variable channel index](Public-Variable-Channel-Index) the canonical direct public-variable inventory.
- Added missing direct-channel rows to the index from the older Networking tables: server FPS publications, HQ alive/marker broadcasts, AntiStack compensation and no-player stagnation counters.
- Replaced duplicate direct-channel tables in [Networking and public variables](Networking-And-Public-Variables) and [SQF code atlas](SQF-Code-Atlas) with concise cross-links to the index.
- Kept Networking focused on dispatcher mechanics, hardening order, JIP/replay rules and specific authority risks.

## 2026-06-02 - Codex Wiki-Quality MERGE-3 Lifecycle Split

- Resolved [Wiki quality audit](Wiki-Quality-Audit) MERGE-3 by separating page ownership between [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) and [Lifecycle wait-chain](Lifecycle-Wait-Chain).
- Reduced duplicated boot timeline and lifecycle report-verification detail from Mission entrypoints.
- Kept Mission entrypoints focused on `description.ext`, `initJIPCompatible.sqf`, role dispatch, mission-object town init and per-role init responsibilities.
- Made Lifecycle wait-chain the canonical page for boot ordering, global flag dependencies, JIP waits and HC timing caveats.

## 2026-06-02 - Codex Wiki-Quality MERGE-2 UI Quick Reference

- Resolved [Wiki quality audit](Wiki-Quality-Audit) MERGE-2 by reducing [Client UI, HUD and menus](Client-UI-HUD-And-Menus) from a duplicate mini-atlas into a compact quick-reference gateway.
- Kept source anchors for the common UI entrypoints: main menu, buy units, gear/service/EASA, upgrades/economy, RHUD/FPS title resources, respawn selector and marker loops.
- Updated [Client UI systems atlas](Client-UI-Systems-Atlas) to state that it is the canonical implementation map and the HUD/menus page is the quick router.
- Updated [Progress dashboard](Progress-Dashboard), `agent-status.json`, `agent-collaboration.json` and `agent-events.jsonl` for the published lane.

## 2026-06-02 - Codex Wiki-Quality REDUCE-4 Gameplay Gateway Cleanup

- Reduced duplicated economy, construction and factory explanation in [Gameplay systems atlas](Gameplay-Systems-Atlas).
- Added explicit gateway links to [Economy, towns and supply](Economy-Towns-And-Supply), [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) and [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas).
- Preserved the new path:line anchors from the C6 citation pass while moving detailed mechanics back to the canonical subsystem atlases.
- Marked [Wiki quality audit](Wiki-Quality-Audit) REDUCE-4 resolved and surfaced the lane on [Progress dashboard](Progress-Dashboard).

## 2026-06-02 - Codex Wiki-Quality C6 Gameplay Citation Uplift

- Finished the remaining [Wiki quality audit](Wiki-Quality-Audit) C6 citation gap on [Gameplay systems atlas](Gameplay-Systems-Atlas).
- Added path:line anchors for town initialization, starting mode/patrol flags, town capture/SV/performance loop, town AI activation/delegation/cleanup, resource ticks, commander voting/assignment, upgrade processing, CoIn construction, factory production and attack-wave production.
- Updated [Progress dashboard](Progress-Dashboard), [Wiki quality audit](Wiki-Quality-Audit), `agent-status.json` and `agent-events.jsonl` so C6 now reads as resolved across UI/HUD, AI/headless and Gameplay.
- Preserved Codex-2's active `supply-mission-authority-cleanup-playbook` claim while updating shared status files.

## 2026-06-02 - Codex Markdown Research Report Intake

- Read nine Steff-provided Markdown deep-research reports from `C:\Users\Steff\Downloads\deep-research-report (1).md` through `(9).md`.
- Added sanitized metadata, hashes, sizes and titles to `external-research-report-manifest.json`; raw Markdown report bodies are not mirrored into the wiki or docs branch.
- Added a Markdown intake section to [External research reports](External-Research-Reports), including report scopes, promotion rules and a source-check lead table.
- Source-checked the modded mission/tooling claim against `Tools/LoadoutManager/ZipManager.cs` and `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs`; it matches already-documented disabled modded propagation and packaging scope in [Tools/build](Tools-And-Build-Workflow).
- Left the deeper claims as leads only; next high-value follow-ups are a PVF dispatch playbook, headless delegation/failover design review and staged server-side economy ledger design.

## 2026-06-01 - Codex

- Created initial developer wiki structure and `docs/wiki` mirror plan.
- Indexed repository shape, mission subsystems, modules, PVF registration, source mission/generator relationship, tooling, integrations and PR #1 supply helicopter context.
- Documented the clearest broken/deferred feature: autonomous AI supply logistics depends on disabled `UpdateSupplyTruck` and missing `Server/FSM/supplytruck.fsm`.
- Added coordination files for Claude and future agents.
- Added machine-readable `agent-context.json`.

## 2026-06-01 - Codex Deep-Dive Pass 1

- Synced repo/wiki remotes and confirmed PR #2 still only contains the initial docs mirror commit.
- Scanned the Chernarus source mission for `preprocessFile` and `preprocessFileLineNumbers` registrations.
- Added `SQF-Code-Atlas.md` with compile registry counts, init ownership notes, PVF command lists, direct publicVariable channels, disabled compile signals and FSM inventory.
- Recorded the PowerShell `-LiteralPath` rule for the `[55-2hc]` mission folder.
- Added GitHub wiki `_Sidebar.md` persistent navigation so readers can click through pages without returning to the page picker.

## 2026-06-01 - Codex Coordination Pass

- Added `Claude-Long-Term-Goal.md` so Claude has a complementary long-running role: independent reviewer, contradiction hunter and subsystem archaeologist.
- Updated navigation and agent context to distinguish focused Claude review from long-term Claude collaboration.

## 2026-06-01 - Codex Wiki UX Pass

- Reworked `Home.md` into a task-oriented portal for humans, reviewers, implementers and AI assistants.
- Reworked `_Sidebar.md` into shorter persistent navigation grouped by architecture, code, gameplay, operations, current work and Claude.
- Added `_Footer.md` for shared bottom navigation and source-backed documentation rules.
- Added `Quickstart-For-Humans-And-Agents.md` with first-read paths, safe edit checklist, common task routing and agent collaboration roles.

## 2026-06-01 - Codex Gameplay Systems Pass 1

- Read town initialization, town starting modes, town capture/SV loop, town AI activation, resource loop, commander PVFs, upgrade processing, CoIn construction, server construction scripts and factory/unit production paths.
- Added `Gameplay-Systems-Atlas.md` with mermaid system flow diagrams, source ownership notes, risk notes and safe extension points.
- Updated Home, sidebar, quickstart and agent context to route humans and LLMs to the gameplay atlas before core gameplay edits.

## 2026-06-01 - Codex Background Reviewer

- Reviewed the repo read-only for missing docs before publish.
- Requested stronger supply mission architecture coverage, explicit Claude coordination files, expanded partial/disabled feature inventory, external runtime dependency notes and performance-risk notes.
- Flagged PR #1 duplicate `Killed` event-handler risk for repeated supply vehicle reloads.

## 2026-06-01 - Claude Independent Review

- Reviewed Codex wiki against source on `feat/supply-helicopter` using parallel read-only sweeps across lifecycle, PV networking, economy/town/supply, AI/headless/performance, tooling/integrations, WASP overlay and broken-feature inventory.
- Added `Lifecycle-Wait-Chain.md` for role truth table, boot timelines and global flag -> `waitUntil` dependencies.
- Added `WASP-Overlay.md` for the project-specific `WASP/` subtree, live wiring, orphaned actions, base repair, RPG dropping, start vehicles and selftest.
- Sharpened PVF internals: one PV variable per command, client element-0 routing, wrapper-to-engine primitive mapping, second-level `HandleSpecial` and `LocalizeMessage` multiplexers.
- Sharpened AI/headless notes: town AI is spawn/delete distance activation, HC owns units through remote creation, late HC joins can miss delegation after init downgrade and `GetSleepFPS` intentionally shortens sleeps under low FPS.
- Confirmed Supply System 0 plus AI commanders is config-gated latent breakage because `UpdateSupplyTruck` is not compiled but the call site remains live under that configuration.
- Confirmed PR #1 stacks `Killed` event handlers on reused supply vehicles; double payment is currently bounded by `SupplyAmount = 0`, but the handler leak should be fixed.

## 2026-06-01 - Codex UX + Claude Integration Pass

- Integrated Claude's two new pages and targeted findings into the current wiki/docs branch without merging the older branch wholesale.
- Corrected one integration claim after checking source: the economy override in `initJIPCompatible.sqf:151-162` is `WF_Debug`-gated in the current source, not unconditional.
- Reworked wiki navigation for click-through reading: task-oriented Home tours, numbered sidebar start path, footer links to the new deep-dive pages and per-page **Continue Reading** links.
- Updated `agent-context.json` with the new page map, navigation metadata, Claude review pass and sharpened known risks.

## 2026-06-01 - Codex UI Systems Pass 1

- Read `description.ext`, `Rsc/Dialogs.hpp`, `Rsc/Titles.hpp`, `Rsc/Ressources.hpp`, `Client/GUI`, client UI helper compiles, RHUD, respawn selector, marker/action FSMs, CoIn title usage and WASP UI overlays.
- Added `Client-UI-Systems-Atlas.md` with dialog IDD map, title/HUD ownership, main menu router, buy/gear/command/tactical/upgrade/economy/respawn flows, map marker loops, action surfaces, UI asset inventory and safe extension points.
- Flagged UI risks: duplicate `idd = 23000` for EASA/economy, shared title `idd = 10200` for `RscOverlay`/`OptionsAvailable`, polling dialog loops, hot marker loops, respawn selector frequency and economy UI linkage to broken supply-truck work.

## 2026-06-01 - Claude Deep-Review Round 2

- Added `Deep-Review-Findings.md` with source-cited DR-1 through DR-5.
- Confirmed PVF dispatch is a live-server hardening gap: server/client handlers `Call Compile` the sender-chosen command string without validation, while BattlEye filters only contain the `kickAFK` feature rule.
- Confirmed paratrooper drop markers and MASH tent markers are dead receive-side paths.
- Confirmed Chernarus and Takistan are currently in sync except for LoadoutManager skip-list/blacklist differences, while `Modded_Missions/*` are stale or stubbed because modded propagation is commented out.
- Updated feature status, networking, tooling and agent context with round-2 risks.

## 2026-06-01 - Codex Collaboration Protocol Pass

- Added `Agent-Collaboration-Protocol.md` so Codex, Claude and future assistants have explicit claim, handoff, event and stale-branch rules.
- Added `agent-collaboration.json` for machine-readable active lanes and ownership.
- Added `agent-events.jsonl` as an append-only coordination feed for claims, findings, handoffs, completions and sync events.
- Promoted Claude's `Deep-Review-Findings.md` into the mirrored docs set as a first-class review artifact and preserved Claude's ownership-matrix/message-channel proposal.
- Updated Home, sidebar, footer, quickstart, agent context, coordination board, Claude goal pages and `CLAUDE.md` so future Claude/Codex sessions start from the same shared state.

## 2026-06-01 - Codex Construction/CoIn Systems Pass 1

- Read construction entrypoints, `Init_Coin`, `coin_interface`, server request handlers, server construction workers, HQ deploy/mobilize/repair, structure sale, repair-truck CoIn and representative structure config.
- Added `Construction-And-CoIn-Systems-Atlas.md` covering the client CoIn flow, server creation path, structure arrays, HQ lifecycle, repair flows, sale paths, base-area logic and safe extension points.
- Flagged a source-backed hardening gap: construction cost, role and placement checks are mostly client-side while `RequestStructure` / `RequestDefense` do only light class-existence checks before server-side object creation.
- Updated navigation, quickstart, agent context and collaboration state so future gameplay work routes through the construction atlas.

## 2026-06-01 - Codex Claude Autonomy Update

- Expanded `Claude-Long-Term-Goal.md` so Claude can keep working for longer by self-selecting bounded source-backed lanes instead of waiting for Codex to assign every pass.
- Updated `Agent-Collaboration-Protocol.md` and `agent-collaboration.json` to make Claude autonomous for deep reviews, Claude-owned pages, append-only shared files and focused review commits.
- Preserved Codex ownership of broad navigation, mirror parity and primary tour ordering unless Steff explicitly hands those over.

## 2026-06-01 - Claude Deep-Review Round 3 (pvf-hardening-review lane)

- Claimed the `pvf-hardening-review` lane via `agent-collaboration.json` and `agent-events.jsonl`.
- Turned DR-1 into a behavior-preserving implementation playbook in `Deep-Review-Findings.md`.
- Verified that `SRVFNC<cmd>` / `CLTFNC<cmd>` are `missionNamespace` globals, so `Spawn (Call Compile _script)` can become `Spawn (missionNamespace getVariable [_script, {}])`.
- Added optional allow-list and BattlEye filter design notes.
- Scoped the residual risk clearly: this closes arbitrary code execution, but legitimate-command forgery still needs per-handler sender and parameter validation.

## 2026-06-01 - Codex Progress Interface Pass

- Added `Progress-Dashboard.md` as the single human-facing page for current Codex/Claude lanes, event feed links, status legend and update ritual.
- Added `agent-status.json` as a compact machine-readable progress snapshot for agents and external tooling.
- Updated Home, Quickstart, sidebar, footer, Agent Context, Coordination Board and Collaboration Protocol so status checks route through the new dashboard first.

## 2026-06-01 - Claude Deep-Review Round 4 (construction-authority-review lane)

- Took Codex's handoff from the `construction-coin-atlas` lane and concretized the DR-1 command-forgery residual for the build system. New finding **DR-6** in `Deep-Review-Findings.md`.
- Verified at source: `RequestStructure.sqf` and `RequestDefense.sqf` take `_side` (and `_manned`) straight from the client payload and only check that the class exists in the side arrays; `RequestMHQRepair.sqf` is literally `[_this] Spawn MHQRepair;` and `Server_MHQRepair.sqf:3` derives everything from the client `_side`. No commander/funds/dead-HQ/base-area checks — those live only in client CoIn/actions.
- Forgery impact (source-proven, per-handler table in DR-6): a modified client can mint **free** factories, AI-manned defenses/minefields, and HQ repairs for any side, bypassing the economy and base-area `avail` budget.
- Root cause articulated: payloads omit the requesting player, and Arma 2 OA `addPublicVariableEventHandler` exposes no sender identity (`_this = [varName,value]`), so authority must be reconstructed server-side — which is why DR-1's command-name validation does not, by itself, stop forgery.
- Wrote a behavior-preserving validation playbook (add player to payload; server validates side+commander+funds; move base-area `avail` server-side; keep client previews/instant UX). Pairs with DR-1: DR-1 stops arbitrary code, DR-6 stops forged legitimate commands.
- This deepens (does not duplicate) the `Construction-And-CoIn-Systems-Atlas` "Authority Boundary" section. Handoff to code owners; optional cross-link for Codex. `ready-for-review`.

## 2026-06-02 - Claude Self-Authored Long-Term Goal + Coverage Ledger

- Authored a standing long-term goal: drive every subsystem to source-verified comprehension + implementation-hardening until there are no dark corners. Operationalized as **`Codebase-Coverage-Ledger.md`** — a subsystem × dimension (Map/Auth/PV/Perf/JIP-HC/Drift) scoreboard that makes "highest-value next lane" objective (pick the emptiest high-traffic cell).
- Seeded the matrix from current state: boot/PV/construction are deep+hardened; the biggest open cells are Integrations (AntiStack DB extension trust), Factory/purchase authority (blocked on Codex's atlas), UI/HUD adversarial pass, a JIP/HC cross-cut, and victory/endgame+DB-flush.
- Claimed the next lane **`antistack-db-trust`** (external `A2WaspDatabase` DLL boundary, `Server/Module/AntiStack/callDatabase*.sqf`) — deep review to follow next pass.
- **Handoff to Codex (nav is Codex-owned):** please add `Codebase-Coverage-Ledger` to `_Sidebar`/`Home`/`agent-context.json` pages list. Message left in the Coordination Board.

## 2026-06-02 - Claude Deep-Review Round 5 (antistack-db-trust lane)

- First lane executed under the standing Coverage-Ledger goal. Deep-reviewed the AntiStack external DB integration (`Server/Module/AntiStack/callDatabase*.sqf` + the `A2WaspDatabase` DLL, which is NOT in the repo). New findings **DR-7..DR-10** in `Deep-Review-Findings.md`.
- **DR-7 (High):** all seven handlers `call compile` the `callExtension` return — the server executes the external DLL's stdout as SQF. Empty/garbage return → `call compile ""` → `nil select 0` throws. Arma 2 OA has no `parseSimpleArray`, so the fix is defensive shape-validation (guard empty → compile → assert ARRAY of SCALARs → then read), not a parser swap.
- **DR-8 (Med):** blocking DB poll on join/skill path (RETRIEVE ≤12s, REQUEST_SIDE_SKILL ≤27s) — add circuit-breaker. **DR-9 (Med):** SEND_PLAYERLIST packs the whole roster into one `callExtension` call vs A2 OA length limits → truncation → compounds DR-7; chunk it. **DR-10 (Med):** `WFBE_C_ANTISTACK_ENABLED` defaults to 1 (`Init_CommonConstants.sqf:171`) against an absent external DLL → error spam unless disabled; auto-detect the DLL.
- Advanced ledger Integrations row (Auth/PV/Perf/JIP → 🟡; AntiStack covered, Extension/Discord/BattlEye still ⬜). Handoff to code owners (harden the 7 handlers) + Codex (document the external dependency on External-Integrations). `ready-for-review`.

## 2026-06-01 - Codex Factory/Purchase Systems Pass 1

- Read the buy-unit dialog/controller, client action range FSM, client build worker, common unit/vehicle creation helpers, unit metadata cores, factory unit lists, faction filter builder, attack-wave price path and server `AIBuyUnit` worker.
- Added `Factory-And-Purchase-Systems-Atlas.md` with the config chain, player purchase flow, queue model, spawn-pad conventions, common creation behavior, attack-wave/unit-cost modifiers, and implementation checklist.
- Corrected a false assumption in the initial lane scope: no `Server/PVFunctions/RequestBuyUnit.sqf` exists and `RequestBuyUnit` is not registered in `Init_PublicVariables.sqf`; player purchases are client-local.
- Flagged `Server_BuyUnit.sqf` / `AIBuyUnit` as latent/unused unless a dynamic caller is later proven.

## 2026-06-01 - Codex Sub-Agent Fleet Pass 1

- Spawned four read-only sub-agents with disjoint source lanes: Hilbert for network/PV, Cicero for server gameplay loops, Curie for UI/HUD/dialogs and Meitner for tooling/integrations.
- Integrated Hilbert's network findings into [Networking and public variables](Networking-And-Public-Variables), [Feature status](Feature-Status-Register) and `agent-context.json`: direct PV channel table, residual legitimate-command forgery examples and BattlEye filter scope.
- Integrated Cicero's server findings by adding [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas): lifecycle graph, data ownership, load risks, supply mission trust boundary, AI commander caveat and server end conditions.
- Integrated Curie's UI findings into [Client UI systems atlas](Client-UI-Systems-Atlas) and [Feature status](Feature-Status-Register): stale `RscMenu_Upgrade`, duplicate IDDs, suspect `RscClickableText.soundPush[]` and buy-gear partials.
- Integrated Meitner's tooling findings into [Tools/build](Tools-And-Build-Workflow), [External integrations](External-Integrations), [Content/maps](Content-Structure-And-Maps) and `agent-context.json`: LoadoutManager path/7za hazards, generated mission rules, extension-to-Discord JSON flow and stale modded missions.

## 2026-06-02 - Claude Deep-Review Round 6 (victory-endgame-review lane)

- Ledger-driven pick: victory/endgame was fully ⬜ + high-traffic. Reviewed `Server/FSM/server_victory_threeway.sqf` (the ONLY gameOver/failMission setter in `Server/`), `Server_LogGameEnd.sqf`, `PVFunctions/LogGameEnd.sqf`, `Init_CommonConstants.sqf:401`. New findings **DR-11..DR-13**.
- **DR-11 (Med-High, correctness):** the trigger merges a lose-test (`_x` HQ dead + no factories) and a win-test (`_x` holds all towns) into one `if` and handles both identically. `WFBE_CO_FNC_LogGameEnd` (arg = winner) is called with the *opposite* of `_x`, so the persisted `*_WIN_CHERNARUS` profile tally is **inverted for all-towns victories**. `WF_Winner` is a dead write (no reader). `&&` binds before `||`, `!WFBE_GameOver` guards only the towns branch, and the `forEach` has no break → endgame can double-fire.
- **DR-12 (Med, broken feature):** `WFBE_C_VICTORY_THREEWAY` defaults 0; detection gated `if(_victory==0)`; sole victory setter → non-zero (threeway) = matches never auto-end.
- **DR-13 (Low, cleanup):** duplicate `PVFunctions/LogGameEnd.sqf` is buggy (getVariable result used as setVariable key; bare-global `WEST_WIN_CHERNARUS`) — delete to prevent mis-wiring. The clean `Server_LogGameEnd.sqf` is the one wired (Init_Server:64,89).
- Advanced ledger Victory/endgame row. Handoffs to code owners; follow-up review item `WFBE_CL_FNC_EndGame` payload semantics. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 7 (factory-purchase-authority lane)

- Unblocked by Codex's `Factory-And-Purchase-Systems-Atlas`. New findings **DR-14, DR-15**; also an adversarial cross-check of Cicero's commander-assign candidate.
- **DR-14 (High, architectural):** player purchasing has **no server authority** — `GUI_Menu_BuyUnits.sqf:155-156` spawns `BuildUnit` (client `createVehicle`/`createUnit` in `Client_BuildUnit.sqf`) and deducts client-side; there is no `RequestBuyUnit` PVF. With `wfbe_funds` broadcast-writable, the player economy + unit production are fully client-trusted. This is the **ceiling** on the DR-1/DR-6 hardening thread (WFBE locality model); the only real defense is a BattlEye `scripts.txt` filter, not a PV filter. Documented so future hardening targets the right layer.
- **DR-15 (Med, confirmed):** verified Cicero's candidate end-to-end. `Init_Server.sqf:62` compiles `Server_AssignNewCommander.sqf` as `WFBE_SE_FNC_AssignForCommander`; sole caller `RequestNewCommander.sqf:13` passes `[_side,_commander]`; but `Server_AssignNewCommander.sqf:3` does `_side = _this` (the whole array) → `GetSideLogic` fails → AI-commander-stop block mis-fires. Fix: `_side = _this select 0`. Plus a redundant `new-commander-assigned` broadcast.
- Advanced ledger Factory/purchase row (Map ✅ from Codex atlas; Auth/PV 🟡). Handoffs to code owners. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 8 (ui-hud-authority-review lane)

- New findings **DR-16, DR-17**. Completes the economy authority picture and cross-checks Curie's UI candidates.
- **DR-16 (High):** `GUI_Menu_Economy.sqf:104-152` structure sale is fully client-authoritative — client-side commander check, client refund (`ChangeSideSupply`/`ChangePlayerFunds`), and `_closest setDammage 1` destruction on the client; no server PVF. So **build (DR-6), buy (DR-14), and sell (DR-16) are all client-authoritative** — the WFBE economy has no server enforcement; BattlEye `scripts.txt` is the only practical anti-cheat layer short of a server-PVF redesign.
- **DR-17 (Low-Med, confirms Curie):** `RscMenu_EASA` and `RscMenu_Economy` both `idd = 23000` (`Rsc/Dialogs.hpp:3211, :3289`) → `findDisplay 23000` ambiguous. Assign distinct IDDs.
- Advanced ledger UI/HUD row (Auth/PV 🟡). Remaining UI follow-ups (Curie): title IDD 10200, stale `RscMenu_Upgrade`, `RscClickableText.soundPush[]`. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 9 (server-loop-candidates-verify lane)

- Adversarially verified two Cicero candidates at source; both **confirmed** with exact impact. New findings **DR-18, DR-19**.
- **DR-18 (Med):** supply-cooldown key casing mismatch — `Init_Town.sqf:35` seeds `"lastSupplyMissionRun"` (lowercase) but supply logic uses `"LastSupplyMissionRun"` (capital). `setVariable` keys are case-sensitive in A2 OA, so the `0` seed is dead and the key is nil on first check → `isSupplyMissionActiveInTown.sqf:11` `nil + interval` throws, defeating the `!= 0` guard. Fix: align casing or `getVariable ["LastSupplyMissionRun", 0]`.
- **DR-19 (Med, non-dedicated):** `serverFpsGUI.sqf` + `monitorServerFPS.sqf` put `sleep 8` inside `if (isDedicated)`, so on a hosted/listen server `while {true}` busy-loops (two of them). Fix: hoist the sleep / early-exit when not dedicated; also two redundant FPS publishers (`SERVER_FPS_GUI`/`WFBE_VAR_SERVER_FPS`).
- Advanced ledger Supply JIP/HC. Handoffs to code owners (both one-liners). `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 10 (jip-headless-crosscut lane)

- Traced HQ-death detection end-to-end across server / existing clients / JIP. New finding **DR-20**.
- **DR-20 (High, multiplayer correctness / score exploit):** the HQ `Killed` EH is registered on **every owning-side client** (`set-hq-killed-eh` broadcast from `Construction_HQSite.sqf:91` / `Server_MHQRepair.sqf:43` + the JIP path `Init_Client.sqf:500-503`), but `Server_OnHQKilled.sqf` has **no idempotency guard** → on mobile-HQ death the server runs it once per owning-side client: ~2N× killer score award + N× messages. Fix: per-HQ "processed" flag in `OnHQKilled` (detect redundantly, act once). Keep the redundant EH registration.
- Verified JIP detection itself is correct (the `!_isDeployed` guard at `Init_Client.sqf:500`; deployed HQ covered by the server-side EH). The defect is downstream duplication, not a JIP miss.
- Advanced ledger JIP/HC cells (economy/construction). Remaining JIP/HC: attack-wave sync, marker re-init, headless orphan-on-disconnect. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 11 (headless-disconnect-review lane)

- Verified the round-1 HC-disconnect hypothesis at `Server_OnPlayerDisconnected.sqf`. New finding **DR-21** + a **self-correction**.
- **Correction:** round-1's "HC disconnect orphans units" is wrong — Arma 2 OA migrates a disconnecting machine's local units/groups to the **server** (ownership transfer, no loss). Logged the downgrade explicitly rather than dropping it.
- **DR-21 (Med, perf/operational):** HC delegation has **no failover** — on HC disconnect the offloaded AI lands back on the server (load spike), the disconnect handler does no re-delegation, and `WFBE_C_AI_DELEGATION` is only evaluated at boot (a reconnecting HC doesn't resume offload). Suggest `setGroupOwner`-based rebalancing on HC connect/disconnect (the mission currently never uses `setGroupOwner`).
- Advanced ledger AI/Headless JIP/HC cell. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 12 (side-supply-delta-verify lane)

- Confirmed + sharpened Faraday's "negative side-supply delta" candidate (and my round-1 inverted-guard note). New finding **DR-22**.
- **DR-22 (High, economy exploit):** the supply clamp `if (_change < 0) then {_change = _currentSupply - _amount}` is a broken floor — `_amount` is signed (deductions negative), so overspending yields `_currentSupply + |amount|` (spend 300 from 100 → 400). Live in `Server/Functions/Server_ChangeSideSupply.sqf` (both west/east handlers); the identical block in `Common_ChangeSideSupply.sqf` is **dead** (PV carries `_amount`; server recomputes). Fix: `{_change = 0}`. Resistance-side handler still missing (round-1).
- Advanced ledger Economy Auth/PV (confirmed exploit). `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 13 (upgrade-authority-verify lane)

- Confirmed Faraday's "upgrade authority gap" and closed the economy-authority thread. New finding **DR-23**.
- **DR-23 (High):** `RequestUpgrade.sqf` = `_this Spawn WFBE_SE_FNC_ProcessUpgrade` (raw payload, no validation); `Server_ProcessUpgrade.sqf` does no commander/funds/sequence/dependency check and **never deducts cost** (client-side only). Forge free upgrades for any side; client-controlled `select _upgrade_id select _upgrade_level` → out-of-range error. Fix: validate + server-side cost.
- **Synthesis:** with DR-6/14/16/22/23, the **entire WFBE economy is client-authoritative** (build/buy/sell/supply/upgrade). One architectural owner decision (server-PVF validation vs BattlEye `scripts.txt`) covers the class — piecemeal fixes won't.
- Ledger Economy authority characterized across the board. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 14 (missing-reference-inventory lane)

- Confirmed Curie's dead-dialog candidate. New finding **DR-24 (Low)**: `RscMenu_Upgrade` (`Rsc/Dialogs.hpp:2425`) `onLoad` ExecVMs `Client/GUI/GUI_Menu_Upgrade.sqf` which **doesn't exist** (only `GUI_UpgradeMenu.sqf` does); the dialog is never opened; the live upgrade UI is `GUI_UpgradeMenu.sqf`. Dead/naming-drift reference — inert today. Fix: delete or repoint.
- Tried an automated "live reference → missing file" scan; its Windows backslash path-normalization was unreliable (false positives), so I confirmed by hand and **handed a reliable missing-reference scanner to Codex/tooling** as a future task.
- Severity gradient note: the campaign is now in the long tail (Low/cleanup findings), a sign the high-traffic Auth/PV/JIP cells are largely reviewed. Open abandoned-code candidates remain (TaskSystem, blink loops, WASP OnArmor/KeyDown — see WASP-Overlay + Feature-Status).

## 2026-06-02 - Claude Deep-Review Round 15 (ui-followups-verify lane)

- Confirmed Curie's last two UI candidates; closed the UI follow-up items. New findings **DR-25a/b (both Low)**.
- **DR-25a:** `RscOverlay` (`Titles.hpp:46`) and `OptionsAvailable` (`:165`) share `idd=10200` (title-resource dup; sibling of DR-17). Assign distinct IDDs.
- **DR-25b:** `RscClickableText.soundPush[] = {, 0.2, 1}` (`Ressources.hpp:556`) is malformed (empty leading element; correct form `{"", 0.2, 1}` as at `:92`); base class so it propagates. Fix the array.
- Ledger UI candidates closed. `ready-for-review`.

## 2026-06-01 - Codex External PDF Research Intake

- Steff provided three Dutch deep-research PDFs and also handed them to Claude: `Analytisch rapport over rayswaynl_a2waspwarfare.pdf`, `Analyse van rayswaynl_a2waspwarfare.pdf` and `Diepgaande analyse van rayswaynl_a2waspwarfare.pdf`.
- Spawned three cheap read-only PDF scouts: Sagan, Helmholtz and Parfit. Each produced a compact digest with all claims marked `EXTERNAL_PDF_UNVERIFIED`.
- Added [External research reports](External-Research-Reports) as the intake ledger. It separates claims already source-backed by the wiki from leads that still need repo verification before promotion.
- Claude's later Round 16 cross-check found the PDFs are mostly downstream of the wiki/upstream proxy, making them corroboration rather than independent source verification.

## 2026-06-02 - Claude Deep-Review Round 16 (external-research-integration lane)

- Integrated Steff's 3 deep-research PDFs (also sent to Codex). Read two in full; all are the same genre. **Provenance:** their citations are `raw.githubusercontent.com/wiki/rayswaynl/...` — generated FROM our wiki (+ Miksuu upstream proxy), so **downstream corroboration**, not independent source verification.
- They re-derive our spine (DR-1 call compile, DR-6 construction authority, DR-7 callExtension, UpdateSupplyTruck latent breakage, despawn player-vehicle risk, PR#1 EH leak, MASH broken) and recommend our fixes. **Our source-verified findings are a superset** (reports lack DR-11/15/18/19/20/22/23). Good external validation; nothing higher-severity missed in code.
- **DR-26 (Low, governance):** resolved the reports' "license unspecified" — `LICENSE.md` is a **custom proprietary-style license** (Spayker 2016 / Miksuu 2025; contributions assigned to owner; reuse restricted), NOT OSI → source-available, not open-source.
- Confirmed governance/ops asks at source (handoff to Codex/owners): `DiscordBot/preferences_sample.json` ships a real `GuildID` + hardcoded `DataSourcePath`; no CI (only `FUNDING.yml`). MASH Working/broken wiki contradiction the reports flagged was **already fixed by Codex**.
- `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 17 (weather-daynight-review lane)

- Reviewed `Server_DayNightCycle.sqf` + client receiver/animation (`initJIPCompatible.sqf:174-210`, `Client_DayNightCycle.sqf`). **Clean review — no defect.** Recorded the negative result so it isn't re-reviewed (Round 17 in Deep-Review-Findings).
- Verified: no divide-by-zero (twilight weight is the non-zero constant 3; day-duration param min is 1); JIP covered via engine-synced `WFBE_DAYNIGHT_DATE` + init `setDate`; server-authoritative clock + per-machine local animation + 30 s absolute-date drift sync is coherent (consistent with `skipTime`/`setDate` being local-effect in A2 OA).
- Ledger weather/day-night cell → **reviewed-clean**. Integrity note: not manufacturing a finding where the code is correct is as important as finding bugs.

## 2026-06-02 - Claude Deep-Review Round 18 (modules-review lane) — DR-27 CRITICAL

- Reviewed the `Client/Module/` + `Server/Module/` set. Most modules are config-gated (`WFBE_C_MODULE_*`) cosmetic/QoL; the UAV `_button == 007` branch is `comment 'DISABLED'` in both `uav_interface.sqf:226` and `uav_interface_oa.sqf:100` (confirms Feature-Status "UAV partial").
- **DR-27 (Critical, network authority):** the ICBM/Nuke module is **fully client-authoritative**. Commander's Tactical-menu strike (`GUI_Menu_Tactical.sqf` MenuAction==8) runs entirely client-side, then `Client/Module/Nuke/nukeincoming.sqf:23` sends `["RequestSpecial",["ICBM",side,baseObj,cruiseObj,team]]`. `Server/PVFunctions/RequestSpecial.sqf` is `_this Spawn HandleSpecial;` → `Server/Functions/Server_HandleSpecial.sqf:97-112` spawns `NukeDammage` at the **client-supplied position** with **no** upgrade/commander/funds validation. The `waitUntil {!alive _target}` is timing-only, not a guard. One forged publicVariable = a server-applied, map-wide mass-kill. This is the apex of the client-authoritative class (DR-6/14/16/22/23) with match-wide blast radius.
- Ledger Modules cell → Map ✅, Auth/PV/Perf/JIP-HC 🟡 (DR-27). Handoff to Codex: add DR-27 to the Networking PVF-hazard table + a Nuke-module Feature-Status note; the fix is the shared economy-authority owner decision (server-side authority in the `"ICBM"` case + BattlEye `RequestSpecial` restriction), prioritised above the wallet exploits.

## 2026-06-02 - Claude Deep-Review Round 19 (gear-easa-review lane) — DR-28, economy class complete

- Reviewed EASA aircraft-loadout module (`Client/Module/EASA/`, `GUI_Menu_EASA.sqf`) + vehicle Service point (`GUI_Menu_Service.sqf`).
- **DR-28 (High):** gear/EASA loadouts and vehicle rearm/repair/refuel/heal are **client-authoritative**. No server PVF anywhere in the flow; EASA cost is a client-side `if (_funds > price)` honor check + `ChangePlayerFunds` (`GUI_Menu_EASA.sqf:46-50`); `EASA_Equip` applies `addWeapon/addMagazine` locally and broadcasts only the setup index. Service **rearm** (`:196-200`) and **refuel** (`:217-219`) deduct *unconditionally* — no affordability guard, unlike repair/heal.
- **Class now complete:** every WFBE spend path is source-confirmed client-authoritative — build (DR-6), buy (DR-14), sell (DR-16), supply (DR-22), upgrade (DR-23), ICBM (DR-27), gear/rearm (DR-28). One owner decision (server funds ledger vs BattlEye) covers all of them.
- Ledger: Gear/EASA row Auth → ✅ (characterized); Economy row note extended. Handoff to Codex: fold DR-28 into Economy page + gear atlas; minor parity fix = add `if(_funds>=price)` to Service rearm/refuel.

## 2026-06-02 - Claude Deep-Review Round 20 (extension-globalgamestats-review lane) — DR-29

- Reviewed the in-repo .NET `callExtension` DLL (`Extension/src/**`) + sole SQF caller (`Server/CallExtensions/GlobalGameStats.sqf`). Second extension trust boundary, distinct from the AntiStack `A2WaspDatabase` DLL (DR-7..DR-10, not in repo).
- **DR-29 (Medium, latent Critical):** GLOBALGAMESTATS is a one-way telemetry exporter and is **safe today** — `RvExtension._output` is never written and the SQF call discards the return (`GlobalGameStats.sqf:22`, bare statement), so nothing is `call compile`d from it (the safe contrast to DR-7); reflection is enum-gated. **But:** (2) a dormant **deserialization-RCE landmine** — the commented load path (`SerializationManager.cs:115-120`) uses `TypeNameHandling.Auto` + `JsonConvert.DeserializeObject` (Newtonsoft `$type` gadget), Critical if re-enabled (and a load path is required for real persistence); (3) **write-only/abandoned-refactor stub** — no cross-restart persistence, load path commented + references a different type graph (`Database` vs live `GameData`), stale `new string[2]` + `Todo` comments; (4) **`async void` race** — `SerializeDB` calls the also-`async void` file-create unawaited then `File.Replace` → first-run `FileNotFound`, and `async void` exceptions can crash the .NET host; (5) minor SQF `abs(playerCount-1)` HC heuristic misreports player count.
- Ledger Integrations row: Extension sub-target reviewed (AntiStack DB + Extension both done; Discord + BattlEye remain ⬜). Handoff to Codex: document GLOBALGAMESTATS in External-Integrations as a one-way, output-discarded exporter (explicitly NOT an RCE-into-SQF path); 3 code-owner asks (delete/harden dead deser path, fix async-void `File.Replace` race, fix `abs(playerCount-1)` + stale comments).

## 2026-06-02 - Claude Deep-Review Round 21 (battleye-posture-review lane) — DR-30, campaign-wide

- Source-verified the repo's entire BattlEye footprint to close the loop on the "rely on BattlEye" option offered in 8 prior findings (DR-1 + DR-6/14/16/22/23/27/28).
- **DR-30 (High):** the BattlEye mitigation is **not shipped**. The only BE filter in the repo is `BattlEyeFilter/publicvariable.txt` — **22 bytes**, one rule `5 "kickAFK"` which is the AFK-kick *feature* plumbing, not a security control. No default-deny catch-all → no restriction on any forgery-class PV (`RequestSpecial`/ICBM DR-27, `RequestStructure` DR-6, `RequestUpgrade` DR-23, `HandlePVF` DR-1). **`scripts.txt` is absent** (plus createvehicle/remoteexec/setvariable/setpos/mpeventhandler) → nothing in-repo blunts the DR-1 `call compile` RCE. A 716 KB README `.docx` exists but was not parsed (binary/untrusted-content rule).
- **Implication:** option (b) "rely on BattlEye" across the whole economy/forgery class is illusory as-shipped; realistic remediation collapses to **(a) server-side authority in SQF**. Honest caveat documented: BE filters normally live in the server `BEpath` outside the mission PBO, so production posture is an explicit owner question — the repo (source of truth) ships only the stub.
- Confirms the Codex `Gibbs` scout's high-level report at source; corroborates the accurate, non-overclaiming wiki text already in place (`External-Integrations.md:60`, `Feature-Status-Register.md:32`, `Networking-And-Public-Variables.md:122`).
- Ledger Integrations row: BattlEye sub-target done (AntiStack DB + Extension + BattlEye all reviewed; only **Discord data path** remains ⬜). Handoff to Codex: one-line cross-link to the DR-1 playbook + External-Integrations noting option (b) requires building the filter set; pose the production-BE-config question to the owner; bundle `scripts.txt`/`server.cfg`/`basic.cfg` absences into a hosting-hardening owner item.

## 2026-06-02 - Claude Deep-Review Round 22 (discord-datapath-review lane) — DR-31, Integrations row complete

- Reviewed the in-repo `DiscordBot/` (.NET / Discord.Net) — the consumer of GLOBALGAMESTATS `database.json`, closing the last Integrations sub-target. Data path: Arma server → extension writes `database.json` (DR-29) → bot reads on a 60 s timer → status embed.
- **DR-31 (High, insecure deserialization):** `GameData.LoadFromFile()` (`GameData.cs:49-56`) deserializes `database.json` with **`TypeNameHandling.All`** — the Newtonsoft `$type` gadget sink, worse than the dormant `.Auto` flagged in DR-29. Run **every 60 s** by `GameStatusUpdater` (`:9,19-22,84`) + at startup (`ProgramRuntime.cs:15`) + on a command (`CommandHandler.cs:211`), no interaction. Capability is gratuitous (data is a flat `string[] exportedArgs` DTO; the writer uses `.None`). Not remotely exploitable as-configured (file written by the trusted local extension), but any write-primitive to `C:/a2waspwarfare/Data/database.json` = **RCE in the token-holding bot process**. Trivial fix: `.All → .None` + delete the dead `.Auto` method (`GameDataDeSerialization.cs:32`, no callers). Closes DR-29 #2 end-to-end.
- **Secondary (Low):** secret hygiene is **good** — `.gitignore` excludes `token.txt` + `preferences.json`; `preferences_sample.json` is tokenless (resolves the external reports' "Discord sample hygiene" item; minor: sample commits a real `GuildID`/`AuthorizedUserID` snowflake — IDs, not secrets). Inbound commands are auth-gated (`IsUserAuthorized`, `CommandHandler.cs:49,127`). Three-way `exportedArgs` shape drift (ext `[2]` / bot `[4]` / SQF sends 5) — benign but document the canonical 5-field layout.
- Ledger Integrations row: **all four sub-targets done (AntiStack DB, Extension, BattlEye, Discord) → Map ✅.** Handoff to Codex: document the Discord data path in External-Integrations; the one actionable code-owner item is `TypeNameHandling.All → None`; cross-link DR-29/DR-31.
- Note: hit the recurring Bash-heredoc backslash-collapsing trap writing the Windows path into a JSONL event; repaired the one malformed line via a Write-tool Python script (forward slashes) and re-validated. Lesson reinforced: author any script containing Windows paths via the Write tool, not a Bash heredoc.

## 2026-06-02 - Codex PV/External Integration Batch A

- Integrated Archimedes/James/Galileo PV findings into [Networking and public variables](Networking-And-Public-Variables), adding a second-pass direct-channel inventory for attack waves, side supply, supply missions, MASH markers, HQ state, AntiStack compensation, server FPS, AFK, day/night and marker/message channels.
- Clarified that a `WFBE_PVF_*` dispatcher fix or whitelist does not harden direct publicVariable channels; BattlEye `publicvariable.txt` must cover both registered PVF commands and explicit direct channels.
- Integrated Faraday/Claude external-integration findings into [External integrations](External-Integrations): Discord sample/config hygiene, the in-repo `a2waspwarfare_Extension` vs absent out-of-repo `A2WaspDatabase`, async file export behavior, custom/source-available license and missing CI/reference validation.
- Folded Claude DR-27 into [Networking and public variables](Networking-And-Public-Variables) and [Feature status](Feature-Status-Register): `RequestSpecial` / `"ICBM"` is the highest-priority registered-command hardening target because a forged PV can create a server-applied map-wide nuke.
- Folded Claude DR-28 into [Economy](Economy-Towns-And-Supply), [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas) and [Feature status](Feature-Status-Register): gear/EASA/service authority is now the final confirmed spend path in the client-authoritative economy class.
- Added matching entries to `agent-status.json`, `agent-collaboration.json`, `agent-context.json` and `agent-events.jsonl`.

## 2026-06-02 - Codex Cheap Explorer Wave C

- Spawned six read-only explorers for the next integration batch: Newton (broken references), Linnaeus (supply mission authority), Ampere (server runtime/FSM), Pascal (boot/include graph), Boyle (AI commander/autonomy) and Peirce (hosting/BattlEye).
- Reports received so far confirm latent AI supply truck breakage, broken MASH marker listener registration, stale upgrade dialog reference, missing `server.cfg`/`basic.cfg`/`scripts.txt` bundle, duplicate/hosted server FPS risk, partial AI commander autonomy and a missing root `version.sqf` boot dependency.
- These scout reports are queued for the next source-backed integration pass; they are not yet all promoted into owner pages.
## 2026-06-02 - Claude Deep-Review Round 23 (generated-mission-drift-review lane) — DR-32, Drift characterized campaign-wide

- Cross-cutting Drift pass: file-set (`comm`) + byte-level (`cmp`) comparison of the Chernarus source mission against all 8 generated missions (1 vanilla + 7 modded).
- **DR-32 (Medium, drift + abandoned-code), three tiers:**
  - **Vanilla Takistan = faithful regeneration.** 15/671 `.sqf` differ, all map-config (per-faction `Core_Artillery/*`, `Init_Server.sqf` sole diff = `SET_MAP 1→2`, help, start vehicles) + textures; **all logic byte-identical** → every DR-1..DR-31 finding propagates verbatim to vanilla; source fix + regen corrects both.
  - **Napf/eden/lingor = divergent hand-edited forks.** 104–123 logic files differ from source, incl. `Server_HandlePVF`, `Server_HandleSpecial`, `server_victory_threeway`, `Server_ProcessUpgrade`, `Server_OnHQKilled`, `Init_PublicVariables`, `initJIPCompatible`. Hand-customized behavior (Napf's ICBM additionally spawns 3× `BO_GBU12_LGB`). Not regenerated (DR-4: modded propagation commented at `SqfFileGenerator.cs:132`) → source fixes do NOT reach them; vuln classes persist with different lines.
  - **sahrani/dingor/tavi/isladuala = abandoned stubs.** 1–20 files each (a real mission ≈ 786 files / 671 `.sqf`); missing `Server/`, `mission.sqm`, `WASP/`, most logic → non-runnable scaffolds.
- Ledger: Drift cells for Construction/UI/Modules → done; added a global "Drift dimension — campaign-wide result (DR-32)" note below the matrix. Owner decisions: complete-or-delete the 4 stubs; pick a maintenance model for the 3 forks (regenerate from hardened source vs maintain-as-forks); apply DR fixes to source first then deliberately propagate. Handoff to Codex: add a generated-mission status table to Tools-And-Build-Workflow (its lane).

## 2026-06-02 - Claude Deep-Review Round 24 (factory-perf-jip-review lane) — DR-33

- Filled the two ⬜ cells on the Factory/purchase row by reviewing the production path: `GUI_Menu_BuyUnits.sqf` (queue gate) → `Spawn BuildUnit` → `Client_BuildUnit.sqf` (production loop) + `WFBE_C_QUEUE_*` counters in `Init_Client.sqf`. Production runs entirely on the **buyer's client**.
- **DR-33a (Medium, JIP/HC / client-state leak):** `WFBE_C_QUEUE_<type>` is a client-local counter (cap e.g. Light/Heavy=5) incremented at the buy gate (`GUI_Menu_BuyUnits.sqf:145-146`) and decremented at the script tail (`Client_BuildUnit.sqf:469`). The **empty-vehicle** path `if (!_driver && !_gunner && !_commander) exitWith {}` (`:365`) returns before the decrement → each crewless-vehicle buy permanently leaks the counter; after `_MAX` such buys the gate silently soft-locks that factory type for the rest of the match. Reachable in normal play. Fix: decrement on all exit paths.
- **DR-33b (Low/Medium, Perf):** per-unit `while {…} { sleep 4; … }` poll re-broadcasts the building's `queu` array via `setVariable [...,true]` on every enqueue/advance/complete (`:172/:191/:207`) → network churn proportional to queue activity. `varQueu = random(10)+random(100)+random(1000)` (`:168`) is **not unique** → front-of-queue collision risk. Buyer-disconnect orphans the broadcast `queu` token (self-heals only via another buyer's `_ret>_longest` cleanup). Fixes: unique token + reduce broadcast.
- Ledger Factory/purchase row: Perf + JIP/HC cells filled (DR-33). Remaining 🟡 Auth/PV = DR-14 client-authoritative-purchase ceiling (economy class). Handoff to Codex: document the production queue model in the Factory atlas. Both fixes propagate to vanilla Takistan verbatim (DR-32).

## 2026-06-02 - Claude Deep-Review Round 25 (respawn-mash-review lane) — DR-34

- Reviewed the respawn UI (`Client_UI_Respawn_Selector.sqf`) + MASH respawn-marker chain (`Server/Module/MASH/MASHMarker.sqf` ↔ `Client/Module/MASH/receiverMASHmarker.sqf`); resolved the DR-2 MASH dead-path note to a full both-ends diagnosis.
- **DR-34 (Low/Medium, broken/abandoned feature):** the MASH **map-marker** feature is dead on both ends — (1) client receiver commented out (`Init_Client.sqf:132`), (2) trigger PV `WFBE_CL_MASH_MARKER_CREATED` never broadcast by any client (only the server PVEH references it), (3) server handler `WFBE_SE_FNC_MASH_MARKER` live at `Init_Server.sqf:70` but **orphaned** (listens for a never-sent PV). MASH tents are a real officer feature (`Officer_Undeploy_MASH.sqf`) but produce **no map markers**. Confirms + extends DR-2.
- **Latent JIP gap if revived:** marker delivered by `publicVariable "WFBE_SE_MASH_MARKER_SENT"` — single overwritten global, not JIP-replayed/not a list → joiners miss prior MASH; only the last is carried. Revival recipe: server-held list + JIP re-send (like the construction `set-hq-killed` re-sends) + unique names.
- **Secondary (Low):** respawn selector is a ~33 Hz `sleep 0.03` **local** marker-animation loop while the respawn UI is open (network-free, bounded). MASH marker name uses `round random 50000` (non-unique, DR-33b class) and `deleteMarker` on a `createMarkerLocal` marker (local/global mismatch) — moot while disabled.
- Ledger Markers/cleaners row: PV + JIP/HC cells reviewed (DR-34). Handoff to Codex: mark MASH map-marker dead/abandoned in Feature-Status + marker docs; owner decision = revive or remove the dead receiver + orphaned server registration.

## 2026-06-02 - Claude Deep-Review Round 26 (params-localization-review lane) — DR-35 (reviewed clean)

- Reviewed the two never-covered cross-cutting areas: localization integrity + the mission parameters system.
- **Localization: clean.** 204 static `localize` keys; a case-sensitive diff flags 4 "missing", but Arma stringtable lookup is **case-insensitive** — after case-folding (drops `STR_WF_UPGRADE_uav_Desc` = defined `..._UAV_DESC`) and liveness-checking, the survivors are 1 engine-provided (`STR_EP1_UAV_action_exit`) and 2 in **commented-out** WASP code (`STR_WASP_actions_OnArmor`, `STR_WF_Gear` at `AddActions.sqf:4,10-12`). **No live broken-string bug.** Config-side `$STR_` all resolve. ~1085 stringtable keys are unused legacy (normal).
- **Parameters: live + correctly wired.** `Init_Parameters.sqf` (MP `paramsArray select _i` / SP `default`) ← `initJIPCompatible.sqf:121`; display dialog via `Rsc/Dialogs.hpp:3136` + `Rsc/Parameters.hpp`. Fragility note (not a defect): `paramsArray` is index-aligned to `class Params` order — keep order stable when editing.
- **Abandoned-code:** WASP `OnArmor` (ride-on-tank) + `GearYourUnit` actions are commented out in `AddActions.sqf` (confirms the earlier WASP-OnArmor suspicion).
- New ledger row **Parameters / localization → reviewed-clean (DR-35)**. Handoff to Codex: optionally note the dead WASP actions in WASP-Overlay + a keep-`class Params`-order caution in params docs. Method note for future passes: case-fold + liveness-check before reporting missing-key findings, or you generate false positives.

## 2026-06-02 - Claude Deep-Review Round 27 (victory-perf-jip-review lane) — DR-36

- Filled the Victory/endgame Perf + JIP/HC cells by reviewing `Server/FSM/server_victory_threeway.sqf` (the sole victory FSM, `execVM`'d at `Init_Server.sqf:528`) and the end-of-match DB-flush tail.
- **Perf: clean.** 80 s `_loopTimer`, cheap per-side checks (`GetSideHQ`/`GetSideStructures`/`GetTownsHeld`/`GetFactories`); `_innerTimer` is a dead unused variable; `_miniSleep=0.05` only paces the one-time end-of-match per-player DB `STORE`.
- **JIP/HC: server-authoritative (correct).** One narrow gap: the endgame `SendToClients` (`:24`) and the unbroadcast `WFBE_GameOver` (`:33`) aren't replayed to a player joining the ~10 s window before `failMission "END1"` (`:88`) — moot since the mission is ending.
- **Source mechanism for DR-11 + DR-13.** Win check (`:23`) `!(alive _hq) && _factories==0 || _towns==_total && !WFBE_GameOver` parses (`&&`>`||`) as `(HQ-dead && no-factories) || (holds-all-towns && !WFBE_GameOver)` — so `!WFBE_GameOver` guards **only** the towns clause, not the HQ-elimination clause; and the `forEach WFBE_PRESENTSIDES` (`:43`) has **no break** after a winner is set. Two same-tick eliminations → double `endgame` broadcast + double `LogGameEnd` + `WF_Winner` overwritten with the opposite side (`:31,35-39`). Exact root cause of DR-11 inversion + DR-13 duplication. Fix: parenthesize+guard both clauses + `exitWith`/break the forEach/while on `gameOver`. Re-confirms DR-12 (threeway `_victory!=0` skips detection).
- Ledger Victory/endgame row: Perf + JIP/HC filled (DR-36); Auth/PV remain 🟡 = the DR-11/12/13 owner fixes. Handoff to Codex: cross-link Feature-Status victory rows to DR-36.

## 2026-06-02 - Claude Deep-Review Round 28 (boot-lifecycle-perf-jip-review lane) — DR-37 (reviewed clean + robustness note)

- Filled the Boot/lifecycle Perf + JIP/HC cells by reviewing the role router (`initJIPCompatible.sqf`) + client boot chain (`Init_Client.sqf`).
- **Perf: clean.** All boot blocking-waits are frame-throttled bare `waitUntil` with cheap conditions; `Init_Client.sqf:248` uses the `waitUntil {sleep 0.5; cond}` throttle idiom; the `while {true} {sleep 0.1; … exitWith}` loops at `:419/:444` are **bounded join-handshake polls** (exit on ACK, 30 s retry) — not perpetual 10 Hz loops. No boot perf trap.
- **JIP/HC: comprehensive + correct.** `initJIPCompatible` routes server/client-II/HC; a JIP client syncs time/date (`WFBE_DAYNIGHT_DATE`, Round 17), teams (`WFBE_PRESENTSIDES` + `wfbe_teams`), and all client state via broadcast logic-object vars; the `RequestJoin` handshake has a 30 s retry + lobby fallback.
- **Robustness note (not a live bug):** the post-join serial `waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_…"}}` chain (`Init_Client.sqf:367-502`) has **no timeouts** — if a server-side regression ever fails to set one synced var, the JIP client hangs forever with no fallback or log past that step. Unlike the handshake, which retries. Suggested: add defensive timeouts mirroring the handshake.
- Ledger Boot/lifecycle row: Perf + JIP/HC reviewed clean (DR-37). Handoff to Codex: optionally note the timeout-less post-join waits in Lifecycle-Wait-Chain.

## 2026-06-02 - Codex Explorer Wave C Integration

- Integrated Ampere, Pascal, Boyle and Peirce into owner pages: [Server runtime](Server-Gameplay-Runtime-Atlas), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [AI/headless](AI-Headless-And-Performance), [Function/module index](Function-And-Module-Index) and [Feature status](Feature-Status-Register).
- Promoted source-backed facts: generated/missing root `version.sqf` include dependency, live AI commander upgrade worker without proven scheduler, hosted/listen FPS loop risk, no shipped server config bundle, no shipped BattlEye hardening beyond AFK publicVariable support, AI commander assignment argument bug and no HC rebalancing.
- Partly integrated Newton's broken-reference pass: AI supply truck missing `supplytruck.fsm`, MASH marker receiver not registered and stale `RscMenu_Upgrade` file name are now visible in the risk/status pages. Lower-risk cleanup/resource/localization candidates remain queued.
- Integrated Linnaeus' supply-mission authority lane: master is truck-only and authority-light; PR #1 is additive heli/cash/interdiction work on the same trust model; AI logistics remain deferred and the stacked `Killed` EH issue remains unresolved.

## 2026-06-02 - Codex External PDF Reconciliation Wave D

- Steff re-shared three Dutch deep-research PDFs and is also handing them to Claude.
- Codex extracted them into shared text artifacts under `outputs/external-reports/` with `manifest.json` so all agents can read the same normalized corpus.
- Spawned five cheap read-only explorers: Erdos (architecture/lifecycle), Arendt (broken/partial/missing features), Carver (server/security/networking/integrations), Laplace (UI/HUD/wiki UX) and Tesla (agent-readable artifact schema).
- Updated [External research reports](External-Research-Reports) with the extracted text paths and second-wave promotion rule: report claims are leads until repo evidence confirms them.
- Created [`agent-knowledge.jsonl`](agent-knowledge.jsonl), an agent-readable JSONL artifact for source documents, topic clusters, claims and gaps.
## 2026-06-02 - Claude Deep-Review Round 29 (pv-dispatch-perf-jip-review lane) — DR-38

- Filled the PV/networking dispatch Perf + JIP/HC cells by reviewing the hot path (`Server/Client_HandlePVF.sqf`) + registration/precompile (`Init_PublicVariables.sqf`). (Auth/PV/RCE already DR-1.)
- **Perf:** both dispatchers do `_parameters Spawn (Call Compile _script)` (`Server_HandlePVF.sqf:14`, `Client_HandlePVF.sqf:22`) → a per-message runtime recompile of the sender string. **Redundant** — `Init_PublicVariables.sqf:44/49` already pre-compiles every PVFunction into `SRVFNC<name>`/`CLTFNC<name>` globals at init. A validated `getVariable` lookup removes the recompile **and closes the DR-1 RCE in the same one change** (Perf–Security convergence). `Spawn`-per-message adds scheduler pressure under floods (justified for sleep-using handlers; lower priority).
- **JIP/HC: clean.** Dispatchers registered via `addPublicVariableEventHandler` in `Init_PublicVariables.sqf:45/50`, which runs in `Init_Common` on all machines incl JIP clients; PVFs are **transient events** (no replay needed — state sync is the separate DR-37 layer); destination routing (nil/SIDE/UID, `Client_HandlePVF.sqf:12-15`) matches joiners.
- Ledger PV/networking dispatch row: Perf + JIP/HC filled (DR-38). Handoff to Codex: fold the Perf note into the Networking DR-1 remediation section (the security fix is free on Perf).
- **Integrity/recovery note:** this Round 29 commit (`0c1832b`) was pushed to wiki master, then **orphaned** when Codex's `28b9b2d` ("docs: integrate explorer and PDF reconciliation") was built on Round 28 (`891fb5c`) and force-pushed over master — dropping DR-38 from Deep-Review-Findings + ledger + context. Recovered by cherry-picking `0c1832b` from the local object store onto current master; the `docs/wiki` mirror branch had preserved DR-38 throughout. **Coordination ask to Codex: pull-rebase wiki master rather than force-push, so `claude:`-prefixed commits aren't dropped.**

## 2026-06-02 - Claude Deep-Review Round 30 (supply-missions-perf-jip-review lane) — DR-39

- Filled the Supply-missions Perf + JIP/HC cells by reviewing `Server/Module/supplyMission/*` + client consumers.
- **Abandoned-code:** `supplyMissionActive.sqf` is a **dead twin** — a plain function body (no PVEH), compiled to `WFBE_SE_FNC_SupplyMissionActive` (`Init_Server.sqf:81`) but **never called**; superseded by the live `supplyMissionStarted.sqf` (self-registers `WFBE_Client_PV_SupplyMissionStarted` PVEH at `:1`). Remove the dead twin + its compile.
- **Perf:** the live per-mission `while {alive truck} {sleep 3}` server loop does `nearestObjects [pos, [], 80]` (**all** object types) every 3 s just to detect a `Base_WarfareBUAVterminal` — narrow the type filter; bounded by concurrent missions otherwise.
- **JIP/HC: done right (positive counterexample to DR-34).** Cooldown status is **pull-based request/response** (`WFBE_Client_PV_IsSupplyMissionActiveInTown` → server computes from `LastSupplyMissionRun` → `WFBE_Server_PV_IsSupplyMissionActiveInTown` → client stores), so JIP joiners get correct state by asking — no replay needed. The server-side tracking loop is truck-keyed and survives the starting player's disconnect. Minor: the cooldown answer is broadcast to all clients rather than targeted to the requester.
- Ledger Supply missions row: Perf + JIP/HC filled (DR-39); Auth 🟡 remains DR-18 + PR#1 (owner). Handoff to Codex: note the dead twin + the pull-based JIP pattern in Supply-Mission-Architecture.

## 2026-06-02 - Claude Deep-Review Round 31 (wasp-overlay-perf-jip-review lane) — DR-40 (last Perf/JIP-HC cell)

- Filled the final 🟡 Perf cell + ⬜ JIP/HC cell: the WASP overlay (`WASP/*`).
- **Perf: mostly clean, one nit.** `global_marking_monitor.sqf:62` `while {time < _this} do { findDisplay 54 … }` is a **sleepless busy-spin** (polls every frame for up to a 2 s window, input-disabled, one-time at init) — its own sibling at `:80` correctly uses `waitUntil {sleep 0.1; !isNull (findDisplay 12)}`. Convert `:62` likewise. The rest are bounded: `baserep/repair.sqf` 1 Hz only while repairing; `DropRPG.sqf` `sleep 30` cooldown; `AddActions.sqf:2` `While {!alive player}{sleep 2}` one-shot wait. No sustained per-frame loop in live WASP.
- **JIP/HC: clean.** Live WASP wired per-client from `Init_Client.sqf` (`:15` DropRPG, `:267` marking monitor, `:574` baserep, `:575` AddActions) → joiners init locally; `local player` guards correct; HC skips player-local features. Dead: the old `WASP/Init_Client.sqf` path in `initJIPCompatible.sqf:243-244` is inside the commented "old wasp script" block.
- Auth/PV scoped out (WASP action authority = owner economy-class follow-up).
- **MILESTONE:** DR-40 was the **last outstanding Perf/JIP-HC cell** in the matrix. Every subsystem's Perf and JIP/HC dimension is now source-reviewed. The residual 🟡 across the ledger is **exclusively Auth/PV owner decisions** — the client-authoritative economy/forgery class (DR-1/6/14/16/22/23/27/28), the victory fixes (DR-11/12/13), supply (DR-18/PR#1), and the WASP/modules Auth follow-ups.
- Handoff to Codex: note `global_marking_monitor.sqf:62` throttle + dead `initJIPCompatible:243-244` WASP path on the WASP-Overlay page.

## 2026-06-02 - Codex Cheap Explorer Wave E

- Spawned six cheap read-only explorers against remaining thin cells: Godel (UI JIP/HC), Gauss (WASP overlay), Popper (modules/support), Locke (direct PV replay semantics), Planck (generated mission docs QA) and Schrodinger (agent-readable docs QA).
- Integrated source-backed improvements into owner pages: generated mission tiers and fresh-checkout `version.sqf` warning, factory DR-33 queue hazards, lifecycle DR-37 timeout-less JIP wait chain, WASP HQ-recovery locality and dead-action notes, victory DR-36 root cause, MASH/paratrooper marker status and direct publicVariable replay semantics.
- Schrodinger confirmed the agent docs are usable but schema-shaped too flat; added compact `openLanes`, `coordinationProtocol` and `pr1SupplyHeliContext` sections to `agent-context.json` so future agents do not have to scrape dashboard prose.

## 2026-06-02 - Codex Hardening Roadmap

- Added [Hardening implementation roadmap](Hardening-Implementation-Roadmap) to convert the reviewed residual Auth/PV owner decisions into implementation work packages.
- The roadmap defines patch order and validation gates for PVF dispatcher lookup, ICBM server validation, victory/endgame correctness, economy authority, supply mission cleanup/PR #1 readiness, factory queue fixes and smaller WASP/MASH/paratrooper cleanup.
- Wired the roadmap into Home, sidebar, footer, Quickstart, AI guide, documentation plan and `agent-context.json` so future agents find it before editing risky mission code.

## 2026-06-02 - Codex Agent Backlog And Discovery Wave F

- Extracted the three Steff-provided PDF reports into local workspace cache and published sanitized metadata in [`external-research-report-manifest.json`](external-research-report-manifest.json). Raw extracted text stays local and is not mirrored into the wiki.
- Added [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), a machine-readable backlog for future Codex/Claude/code-owner runs. It covers PVF dispatch lookup, ICBM, attack waves, victory, economy authority, supply missions, factory queues, marker/support cleanup, BattlEye/hosting, static-defense HC sync, hosted FPS sleep, town-AI vehicle safety, tooling checklist, JIP wait-chain timeouts and UI/player-map debt.
- Spawned and harvested Wave F cheap explorers: lifecycle, PV/security, economy, AI/performance, UI, support modules, tooling, PDF triage, town-AI vehicle safety and lifecycle wait-chain audit.
- Promoted the most important new confirmed bug: `server_town_ai.sqf:211-216` can delete a town-AI vehicle containing a player passenger/crew member when the player is not group leader. This is now in [Feature status](Feature-Status-Register), [AI/headless](AI-Headless-And-Performance), [Hardening roadmap](Hardening-Implementation-Roadmap) and the backlog.
- Added the post-join wait-chain audit to [Lifecycle wait-chain](Lifecycle-Wait-Chain): handshake gates retry every 30 seconds but have no terminal timeout, while later replicated-variable waits have no retry/timeout/log fallback.
- Added an operator checklist to [Tools/build](Tools-And-Build-Workflow) for LoadoutManager checkout path, `7za`, generated `version.sqf`, DiscordBot config and the in-repo Extension versus out-of-repo AntiStack DLL distinction.

## 2026-06-02 - Codex Dashboard Current-State Cleanup

- Reworked [Progress dashboard](Progress-Dashboard) so the first screen shows the current state, open lanes and recent published work instead of a stale historical roster.
- Moved detailed scout history responsibility to [Discovery swarm](Subagent-Discovery-Swarm) and this worklog.
- Updated `agent-status.json`, `agent-collaboration.json` and `agent-context.json` so machine readers agree that the Wave F backlog batch is published and the only active Codex lane is dashboard cleanup/validation.

## 2026-06-02 - Codex Town-AI Vehicle Safety Playbook

- Added [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) as a dedicated implementation playbook for the confirmed `server_town_ai.sqf:211-216` occupied-vehicle deletion bug.
- Wired the page into Home, sidebar, footer, [AI/headless](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), dashboard and machine-readable agent files.
- The page documents the source chain, exact failure condition, behavior-preserving SQF guard shape and validation gates for a future gameplay patch in the Chernarus source mission.
- Queued the Anscombe lifecycle subagent report as a separate verification lead; it contains useful boot/lifecycle notes but also uses a `Migrations` path typo, so it should be source-checked before integration.

## 2026-06-02 - Codex Lifecycle Runtime Verification

- Source-checked Anscombe's lifecycle report against `Missions/[55-2hc]warfarev2_073v48co.chernarus`; the report's `Migrations` path was a typo, not a repo path.
- Confirmed the main lifecycle claims: `description.ext` resource front door, `initJIPCompatible.sqf` branch dispatch, `Init_Parameters.sqf` missionNamespace globals, `Init_Common.sqf` shared compile/config hub, server/client readiness gates and HC registration.
- Promoted the most useful missing nuance into [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) and [Lifecycle wait-chain](Lifecycle-Wait-Chain): town startup begins from `mission.sqm` object `init` fields, with `WF_Logic` at `mission.sqm:3265` starting `Init_TownMode.sqf`.
- Reconfirmed the HC timing caveat: `Init_HC.sqf:12` uses `sleep 20` before sending `connected-hc`, while `serverInitFull` is not set until `Init_Server.sqf:507`.

## 2026-06-02 - Codex Testing Workflow And Agent Schema

- Added [Testing workflow](Testing-Debugging-And-Release-Workflow) as the repo's practical validation page for source-only checks, local tooling, hosted/dedicated/JIP/HC smoke tests and live-server-sensitive release gates.
- Added [`agent-test-plan.schema.json`](agent-test-plan.schema.json) so Codex, Claude and future agents can record test evidence without blurring source review and in-game smoke results.
- Wired the page into Home, sidebar, footer, hardening roadmap, AI guide, progress dashboard and machine-readable context/status/collaboration files.

## 2026-06-02 - Claude operating-mode change (Ray)

- Phase 1 (self-select the emptiest ledger cell) reached completion: Map + Perf + JIP/HC + Drift are reviewed for every subsystem (DR-1..DR-40); residual `🟡` is exclusively Auth/PV owner decisions.
- New standing mode set by Ray: **collaboration-follow loop with research autonomy, self-paced** — each pass read the shared coordination state and follow Codex's lead (verify at source before claiming), with autonomy to pull own threads on idle passes. Docs-only. Recorded as `Claude-Loop-Goal.md`. **Codex:** link it from nav at your convenience (your lane). Done = nothing pending from Codex + only owner-decisions left.

## 2026-06-02 - Claude Deep-Review Round 32 (attack-wave-authority-verify lane) — DR-41 [first collaboration-follow pass]

- First pass under the new mode: read Codex's recent work (hardening roadmap, agent-hardening-backlog.jsonl, wave E/F), picked the raw scout candidate `attack-wave-authority` (status `new-from-2026-06-02-pv-scout`) and source-verified it.
- **DR-41 (High, economy authority / forgery — new direct-PV channel):** `ATTACK_WAVE_INIT` is forgeable. `Server/Functions/Server_AttackWave.sqf:5-6` takes `_supply`/`_side` **directly from the client payload** — no `GetSideSupply` re-derivation, no `_side`-vs-sender check, no server-side cost deduction; the `GetSideSupply >= 25000` gate (`updateclient.sqf:240`) is **client-side only**. With `SUPPLY_MAX = 50000` (`Init_CommonConstants.sqf:166`), a forged `_supply >= 70000` drives `ATTACK_WAVE_PRICE_MODIFIER` (a side-wide unit-price multiplier) to **0 → free units side-wide**; larger → negative pricing. Not in `BattlEyeFilter/publicvariable.txt` (DR-30).
- **Architectural point:** the forgery class has **two surfaces** — the registered PVF dispatcher (DR-1, fixed by validated lookup) **and** direct `publicVariableServer` channels (DR-41). The DR-1 fix does NOT cover direct channels; each direct PVEH must re-derive trusted values server-side. Other direct channels (side-supply, supply-mission, MASH) share this surface.
- Confirms Codex backlog item `attack-wave-authority` → confirmed/High. Ledger Economy row + DR-41. Handoff to Codex: flip backlog status, cross-link DR-41 from Networking direct-PV table + economy roadmap, fold into the economy-authority owner decision with the two-surfaces note.

## 2026-06-02 - Codex Server Authority Migration Map

- Added [Server authority migration map](Server-Authority-Migration-Map) as the design layer between the hardening roadmap and testing workflow.
- Consolidated the client-authoritative/payload-authoritative class into one migration table: PVF dispatch, ICBM, construction/defense, player buys, upgrades, side supply, supply missions, attack waves, gear/EASA/service, structure sale and WASP HQ recovery.
- Wired the page into Home, sidebar, footer, AI guide, adjacent Continue Reading links and the machine-readable context/status/collaboration files.
- Handoff: future code owners should read this page before claiming `network-authority`, `economy`, `gameplay-security`, `support-systems` or BattlEye-sensitive backlog items.

## 2026-06-02 - Codex DR-41 Attack-Wave Integration

- Source-checked Claude DR-41 against `Common_AttackWaveActivate.sqf`, `Server_AttackWave.sqf`, `updateclient.sqf`, `Init_CommonConstants.sqf` and `BattlEyeFilter/publicvariable.txt`.
- Promoted `attack-wave-authority` in [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) from scout candidate to `confirmed-high-dr41`.
- Cross-linked the finding through [Networking/PV](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Economy](Economy-Towns-And-Supply) and [Feature status](Feature-Status-Register).
- Key handoff for future patch owner: the server-authority redesign must cover both registered PVF handlers and direct `publicVariableServer` channels; the PVF dispatcher fix alone does not harden `ATTACK_WAVE_INIT`.

## 2026-06-02 - Codex Attack-Wave Authority Playbook

- Added [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) as the implementation-ready DR-41 guide.
- Documented the exact source chain through `updateclient.sqf`, `Common_AttackWaveActivate.sqf`, `Server_AttackWave.sqf`, `AttackWave.sqf`, buy-unit UI pricing and `BattlEyeFilter/publicvariable.txt`.
- Captured the important design nuance: `25000` supply is currently only the action gate; the live debit spends all current side supply. Default hardening should preserve that model by re-deriving and debiting server-held side supply unless the owner approves a fixed-cost design change.
- Wired the page into Home, sidebar, footer, Networking/PV, Economy, Feature status, Hardening roadmap, Server authority map, Testing workflow, AI guide, dashboard and machine-readable agent files.
## 2026-06-02 - Claude Deep-Review Round 33 (hc-static-defense-verify lane) — DR-42 + DR-19 dedup

- Adjudicated two raw backlog scout candidates at source. **DR-42 (Low/Med):** static-defence HC delegation's update-back is **commented out** (`Client_DelegateAIStaticDefence.sqf:28`), unlike town-AI delegation which reports back (`Client_DelegateTownAI.sqf:35` → `update-town-delegation`). Server never tracks HC-created static-defence units → no cleanup/accounting/re-delegation; compounds DR-21. Owner: restore the update-back (define the server `update-delegation-static_defence` handler) or document as fire-and-forget. Confirms `hc-static-defense-sync`.
- **DR-19 dedup:** backlog `server-fps-hosted-loop-sleep` is the same defect as DR-19 (`monitorServerFPS.sqf:1-7` — `sleep` inside `isDedicated` busy-spins on hosted/listen servers). Not new; fold into DR-19.
- Ledger AI/headless row + DR-42. Handoff to Codex: flip backlog statuses + cross-link DR-42 near DR-21.

## 2026-06-02 - Claude Deep-Review Round 34 (external-research-intake-2 lane) — DR-43

- Ray supplied 9 new deep-research reports (`deep-research-report (1..9).md`). Triaged all 9 (treated as untrusted leads; cross-checked at source). They are downstream syntheses corroborating DR-1..DR-42 — notably report 8 ("Server Authority Refactor") is an independent restatement of the economy-authority thesis (funds/supply mutated client-side then announced; ledger ≠ server source of truth) + DR-1. No contradictions. Same posture as DR-26.
- **DR-43 (Low) — two new source-confirmed leads:** (a) `description.ext:39` `#include "version.sqf"` but `version.sqf` is absent from the whole committed tree -> the repo is **not buildable from source as-is** (version.sqf is supplied at pack time per AGENTS.md); source-completeness/drift note (ties DR-4/32). (b) `Server/Init/Init_Server.sqf` has duplicate compile/bind rows. Codex later corrected the live count: `LogGameEnd`, `PlayerObjectsList` and `AwardScorePlayer` are live duplicate binds; `InitAFKkickHandler`, `monitorServerFPS` and `MASH_MARKER` are commented duplicate remnants. **LogGameEnd duplication ties DR-13**.
- Ledger Tooling row + DR-43a. Handoff to Codex: add the 9 reports to `external-research-report-manifest.json` (your lane); DR-43a = commit a source `version.sqf` or document pack-time generation; DR-43b = de-dup the Init_Server binds.

## 2026-06-02 - Codex DR-42/DR-43 Reconciliation

- Promoted `hc-static-defense-sync` from raw scout backlog to `confirmed-low-dr42`, linked it into [AI/headless](AI-Headless-And-Performance), [Feature status](Feature-Status-Register) and the hardening roadmap.
- Marked `server-fps-hosted-loop-sleep` as `duplicate-of-dr19` instead of a separate finding.
- Source-checked DR-43's duplicate-bind claim against `Server/Init/Init_Server.sqf:63-93` and corrected the count: three live duplicate binds plus three commented duplicate remnants.
- Added backlog work packages for `source-version-sqf-build-gap` and `init-server-duplicate-binds`.

## 2026-06-02 - Claude Wiki-Quality Program, Pass 1 (Ray-approved plan)

- Ray asked for a wiki quality pass (dedup / audit entries / additional context). Ran 3 parallel audits (duplication, accuracy, gaps); approved plan = Claude fixes its own lane directly + creates connective pages + a source-verified module atlas, and produces ONE audit-handoff for Codex's pages (dedup/merge/cross-link). Plan: `~/.claude/plans/drifting-tickling-platypus.md`.
- **Pass 1 (Claude-lane accuracy):** Codebase-Coverage-Ledger — matrix timestamp → 2026-06-02; legend clarified (✅ = reviewed-clean *or* reviewed-with-finding; Map ✅ = a flow/source map exists); **Modules Map ✅→🟡** (only ICBM/Nuke DR-27 + UAV mapped; full modules atlas pending) and **Markers/cleaners Map ✅→🟡** (cleaners/restorers not yet atlas'd). Deep-Review-Findings — **DR-11 severity Medium-High → High** (inverted persisted win-tally); **DR-36** given a dual-purpose disambiguation note (clean Perf/JIP result vs root-cause for DR-11/13).
- Upcoming passes: agent-context systems map; Wiki-Quality-Audit handoff page; WFBE_* glossary; consolidated PV-channel index; Modules atlas (source-verified); Pending-Owner-Decisions page; then nav handoff to Codex.
- **Pass 2 done:** `agent-context.json` `systems` map +5 entries (`modules`, `victoryEndgame`, `weatherDayNight`, `markersCleanersRestorers`, `parametersLocalization`) — all 22 ledger subsystems now represented so agents loading context see them.
- **Pass 3 done:** new `Wiki-Quality-Audit.md` — a Codex-lane punch-list: (A) 11 dedup→cross-link rows, (B) page merges (Hardening-roadmap≈Server-authority-map ~70%; Client-UI-HUD ⊂ Client-UI-Systems-Atlas; Mission-entrypoints≈Lifecycle-wait-chain ~50%; Gameplay-atlas reduce-to-summary), (C) accuracy fixes (C1 HIGH: Networking MASH row contradicts DR-34; C2 HIGH: orphaned-DR cross-links to add per atlas; C3 stale Gameplay open-questions; C4 cite DR-11 by number; C5 sidebar dup entries; C6 thin citations). **Codex handoff event posted** to action A/B/C on its pages + wire upcoming new Claude pages into nav.
- **Pass 4 done:** new `Variable-And-Naming-Conventions.md` — source-cited WFBE_* prefix glossary (config/CO_FNC/SE_FNC/CL_FNC/SRVFNC/CLTFNC/WFBE_PVF_/wfbe_ object vars) + key implications (module gates, pre-compiled-vs-recompile DR-1/38, setVariable-true replication, case-sensitive getVariable keys DR-18). Sibling-new-page links backticked pending creation; final relink pass at the end.
- **Pass 5 done:** new `Public-Variable-Channel-Index.md` — canonical inventory of ALL PV channels: 13 server-bound + 14 client-bound registered PVF commands (`Init_PublicVariables.sqf:8-20`/`:23-37`, each annotated with its notable DR) + ~23 direct channels (ATTACK_WAVE_INIT DR-41, MASH DR-34, supply DR-39/DR-22, ICBM/radiation FX, AFK/kickAFK DR-30, daynight, handshakes DR-37). Trust legend + BattlEye-filter design surface. Supersedes the 2 Networking tables + SQF-atlas duplicate (DUP-11 handoff to Codex).

## 2026-06-02 - Codex HC Delegation/Failover Playbook

- Read `Headless/Init/Init_HC.sqf`, HC registration/disconnect handling, `Server_DelegateAITownHeadless.sqf`, `Server_DelegateAIStaticDefenceHeadless.sqf`, `Client_DelegateTownAI.sqf`, `Client_DelegateAIStaticDefence.sqf`, `Server_FNC_Delegation.sqf`, `Server_HandleDefense.sqf`, `Server_OperateTownDefensesUnits.sqf` and `server_town_ai.sqf`.
- Added [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) as an implementation-ready DR-21/DR-42 guide.
- Captured the key model split: HC mode is remote creation on the HC, client-FPS delegation is a separate player-client mode, town AI has vehicle update-back, and static defense currently does not.
- Documented phased patch shape: explicit static-defense update-back decision, HC work records, disconnect policy and late-HC behavior.

## 2026-06-02 - Claude Wiki-Quality Program, Pass 6 (Modules atlas)

- New `Modules-Atlas.md` — source-verified sections for the ~10 previously-undocumented modules: **IRS** (IR smoke; gate `WFBE_C_MODULE_WFBE_IRSMOKE` + `WFBE_UP_IRSMOKE`), **CM** (flares/chaff; vanilla-only gate), **Reaktiv** (ERA armor via `HandleDamage`), **Engines** (stealth = save fuel + `setFuel 0`), **AutoFlip** (Marty; flip-righting poll, tilt 0.35/cooldown 45), **ZetaCargo** (Benny sling-load; lifter allow-list + cargo types), **Valhalla** (low-gear/high-climb; display-46 key EHs), **Skill** (Benny class abilities; Engineer/Soldier/Officer/…), **NEURO** (Benny AI taxi; `NEURO_TAXI_CONDITION` hook), **CIPHER** (Benny sort util; no side effects). Cross-links the already-covered modules (Nuke DR-27, EASA DR-28, AntiStack DR-7-10, supplyMission DR-39, MASH DR-34, UAV, serverFPS DR-19, AFK DR-30).
- Ledger **Modules Map 🟡→✅** (restored; atlas now exists) and row title/anchor expanded to name the documented modules.
- **Pass 7 done (program complete):** new `Pending-Owner-Decisions.md` — consolidates every open owner decision (economy/forgery class as one two-surface decision; correctness fixes; keep-or-remove; robustness) with finding + severity + page links; it operationalizes the loop's "done = only owner decisions remain". Final relink pass converted all backticked sibling refs to real links now that the 5 new pages exist; **full-wiki link gate: no broken links**. **Codex handoff posted:** wire the 5 new pages (`Wiki-Quality-Audit`, `Variable-And-Naming-Conventions`, `Public-Variable-Channel-Index`, `Modules-Atlas`, `Pending-Owner-Decisions`) into nav, and action the Wiki-Quality-Audit A/B/C punch-list on your pages.

## 2026-06-02 - Codex Wiki-Quality C1 MASH Networking Fix

- Actioned [Wiki quality audit](Wiki-Quality-Audit) C1 on [Networking/PV](Networking-And-Public-Variables).
- Corrected the MASH direct-PV row to DR-34: the server PVEH is registered but orphaned, the client never broadcasts `WFBE_CL_MASH_MARKER_CREATED`, and the client receiver compile is commented.
- Updated replay/JIP notes to say a revival needs a server-held marker list, JIP re-send and unique marker names.

## 2026-06-02 - Codex Wiki-Quality Navigation / C5

- Wired Claude's new canonical pages into primary navigation: [Variable and naming conventions](Variable-And-Naming-Conventions), [Public variable channel index](Public-Variable-Channel-Index), [Modules atlas](Modules-Atlas), [Pending owner decisions](Pending-Owner-Decisions) and [Wiki quality audit](Wiki-Quality-Audit).
- Mirrored and surfaced Codex-2's [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) as the DR-1/DR-38 hardening guide.
- Resolved [Wiki quality audit](Wiki-Quality-Audit) C5 by keeping hardening roadmap, server authority map, attack-wave authority and testing workflow in Ops, while Current Work now focuses on dashboard/coordination/review pages.
- Added the new pages into Home reading paths/current map, `_Footer.md` and `agent-context.json`.

## 2026-06-02 - Codex Wiki-Quality C2 Atlas Cross-Links

- Actioned [Wiki quality audit](Wiki-Quality-Audit) C2 across developer-facing atlas pages.
- Added DR links in [Gameplay atlas](Gameplay-Systems-Atlas) for construction authority DR-6, purchase authority DR-14, victory/endgame DR-11/12/13/36, supply windfall DR-22, upgrade forgery DR-23 and commander assign DR-15.
- Added UI risk links for gear/template/cargo DR-16/17/24 and EASA/service DR-25a/b, plus AI/headless DR-21/DR-42, construction DR-6 and lifecycle DR-37/DR-43a.
- Partially resolved C3 by replacing the stale commander open question with a DR-15 confirmed-finding note.

## 2026-06-02 - Codex Wiki-Quality C4 Victory Searchability

- Actioned [Wiki quality audit](Wiki-Quality-Audit) C4.
- Updated [Feature status](Feature-Status-Register) and [Hardening roadmap](Hardening-Implementation-Roadmap) so the victory/endgame winner-inversion bug is searchable as DR-11, while DR-36 remains the mechanism/perf-JIP explanation.

## 2026-06-02 - Codex Wiki-Quality C6 UI Citation Uplift

- Started [Wiki quality audit](Wiki-Quality-Audit) C6 with the thinnest page, [Client UI/HUD](Client-UI-HUD-And-Menus).
- Added path:line anchors for `description.ext` Rsc includes, `Rsc/Dialogs.hpp` dialog classes/IDDs, `Rsc/Titles.hpp` HUD/title resources, `GUI_Menu.sqf` menu routing and HUD toggles, `Client_UpdateRHUD.sqf` HUD ownership, and `GUI_RespawnMenu.sqf` / `Client_UI_Respawn_Selector.sqf` marker tracking.
- Reconciled Codex-2's new `economy-authority-first-cut` claim into `agent-collaboration.json`, `agent-status.json`, `Progress-Dashboard.md` and the append-only event feed while preserving the UI citation lane.
- Left Gameplay and AI/headless citation uplift open for later passes.

## 2026-06-02 - Codex-2 PVF Dispatch Implementation Playbook

- Claimed pvf-dispatch-implementation-playbook after reading the required dashboard, protocol, machine state, DR register, roadmap, server-authority map and external-report intake files.
- Source-checked Init_PublicVariables.sqf, Server_HandlePVF.sqf, Client_HandlePVF.sqf and the PVF send helpers in the Chernarus source mission.
- Published [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook), turning DR-1 and DR-38 into a P0 patch guide with registered allowlists, missionNamespace getVariable, hosted/dedicated validation and a clear boundary against per-handler authority and direct publicVariable channels.
- Handoff: future code owner should implement this as hardening/pvf-dispatch, then validate one server-bound PVF, one client-bound PVF and a bogus handler rejection before moving to ICBM or attack-wave authority.

## 2026-06-02 - Codex-2 Economy Authority First Cut

- Claimed `economy-authority-first-cut` after checking the live dashboard/collaboration state and avoiding the already-published HC/failover lane.
- Source-checked side supply, group funds, upgrades, construction/defense, player buys, service/EASA, MHQ repair and supply mission entrypoints in the Chernarus source mission.
- Published [Economy authority first cut](Economy-Authority-First-Cut), recommending side-supply-clamp as the first small code branch, then server-owned upgrades and construction/defense, while keeping player factory buys as a separate locality redesign.
- Handoff: future code owner should patch the side-supply negative floor and temp-channel validation first; it is small, source-backed and does not claim to solve the broader client-authoritative economy.

## 2026-06-02 - Codex Wiki-Quality C6 AI Citation Uplift

- Continued [Wiki quality audit](Wiki-Quality-Audit) C6 after the UI citation pass.
- Added path:line anchors to [AI/headless](AI-Headless-And-Performance) for delegation parameters/constants, HC bootstrap, HC registry, town-AI HC delegation, static-defense HC delegation, HC disconnect handling, town-AI cleanup, server-FPS publishers and the `GetSleepFPS` scheduling tradeoff.
- Corrected loose shorthand to the real `Server_DelegateAITownHeadless.sqf` / `Server_DelegateAIStaticDefenceHeadless.sqf` source files.
- Left Gameplay atlas citation uplift as the remaining C6 item.

## 2026-06-02 - Codex-2 Supply Mission Authority Cleanup Playbook

- Claimed `supply-mission-authority-cleanup-playbook` after publishing the economy authority first cut and confirming PR #1 supply helicopters remain additive to the existing object-var trust model.
- Source-checked supply mission start, cooldown query/response, server tracking/completion, PR #1 helicopter constants/action/message changes, player resolution and the dead `supplyMissionActive.sqf` twin.
- Published [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), turning DR-18/DR-39 and the PR #1 stacked-`Killed` handler review into a practical patch guide.
- Handoff: future code owner should add server-owned loaded/tracking state and `Killed` handler idempotency first, then standardize cooldown casing and validate/recompute cargo server-side before merging supply helicopters as baseline.

## 2026-06-02 - Codex-2 Abandoned Feature Revival Review

- Published [Abandoned feature revival](Abandoned-Feature-Revival-Review) after source-checking MASH marker relay, paratrooper marker PVF, AI supply-truck logistics, UAV 007 UI branch, WASP legacy actions, stale upgrade dialog and modded mission propagation.
- Key conclusions: MASH tents are live but map markers are dead on both ends unless rebuilt with server-held/JIP-safe state; paratrooper drops are live but the marker callback is absent from `_clientCommandPV`; AI supply trucks are broken/dormant because compile is commented, a gated call remains and `Server\FSM\supplytruck.fsm` is missing.
- Handoff: future code owner should pick one bounded cleanup from the page; Claude can contradiction-check hidden marker senders or stale UI callers.

## 2026-06-02 - Codex External Arma 2 OA Reference Guide

- Published [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) as the official-reference router for future mission changes.
- Mapped BI Community Wiki references for multiplayer/JIP, `publicVariable`, PVEHs, `setVariable`, event handlers, `nearestObjects`, `preprocessFileLineNumbers`, render/simulation scope and diagnostic timing to concrete Wasp source hotspots.
- Handoff: future agents should link engine claims to this guide instead of repeating broad warnings or importing Arma 3 networking assumptions.

## Future Agents

- Add dated entries here before and after substantial documentation or code changes.

## Continue Reading

Previous: [Agent collaboration protocol](Agent-Collaboration-Protocol) | Next: [Deep-review findings](Deep-Review-Findings)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

## 2026-06-02T08:46:54+02:00 - Codex-2 performance opportunity sweep

Published [Performance opportunity sweep](Performance-Opportunity-Sweep) after source-checking hosted server FPS loops, supply mission scans, WASP marker polling, factory queue broadcasts, PVF dispatch, client marker loops, RHUD, cleaners/restorers and skill initialization.

Key conclusions:

- Highest-value performance-adjacent patch remains PVF dispatcher lookup because it also closes DR-1/DR-38.
- Smallest server patch is hosted/listen FPS loop sleep or exit; current sleep is inside isDedicated.
- New finding: Skill_Init.sqf runs twice in client init and can compound Soldier WFBE_C_PLAYERS_AI_MAX; added client-skill-init-idempotency to the backlog.
- Supply scan narrowing, factory queue cleanup and WASP marker wait cleanup are bounded follow-ups; marker/town/cleaner cadence changes should be driven by PerformanceAudit rows.
