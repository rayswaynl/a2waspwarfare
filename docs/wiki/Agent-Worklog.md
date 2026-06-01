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

## Future Agents

- Add dated entries here before and after substantial documentation or code changes.

## Continue Reading

Previous: [Agent collaboration protocol](Agent-Collaboration-Protocol) | Next: [Deep-review findings](Deep-Review-Findings)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
