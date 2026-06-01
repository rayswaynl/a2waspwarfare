# Agent Worklog

Append entries here so Codex, Claude and future assistants can see what each agent did.

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

## Future Agents

- Add dated entries here before and after substantial documentation or code changes.

## Continue Reading

Previous: [Agent collaboration protocol](Agent-Collaboration-Protocol) | Next: [Deep-review findings](Deep-Review-Findings)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
