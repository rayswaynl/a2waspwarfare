# Agent Worklog

Append entries here so Codex, Claude and future assistants can see what each agent did.

## 2026-06-01 - Codex

- Created initial developer wiki structure and `docs/wiki` mirror plan.
- Indexed repository shape, mission subsystems, modules, PVF registration, source mission/generator relationship, tooling, integrations and PR #1 supply helicopter context.
- Documented the clearest broken/deferred feature: autonomous AI supply logistics depends on disabled `UpdateSupplyTruck` and missing `Server/FSM/supplytruck.fsm`.
- Added coordination files for Claude and future agents.
- Added machine-readable `agent-context.json`.

## 2026-06-01 - Codex Background Reviewer

- Reviewed the repo read-only for missing docs before publish.
- Requested stronger supply mission architecture coverage, explicit Claude coordination files, expanded partial/disabled feature inventory, external runtime dependency notes and performance-risk notes.
- Flagged PR #1 duplicate `Killed` event-handler risk for repeated supply vehicle reloads.

## 2026-06-01 - Claude (independent review/deepening pass)

Reviewed Codex's published wiki against the source on `feat/supply-helicopter` (working tree) using six parallel subsystem read-only sweeps (lifecycle, PV networking, economy/town/supply, AI/headless/performance, tooling/integrations, WASP overlay + broken-feature audit). All claims below are source-cited in the pages they land on. No gameplay code changed; docs-only branch `docs/developer-wiki-claude` off Codex's `docs/developer-wiki-index`.

**New pages added (gaps, not overlaps):**
- `Lifecycle-Wait-Chain.md` — machine-role truth table, ordered boot timelines per role, and the global-flag → `waitUntil` dependency graph (the artifact needed before reordering any init call). Linked from Home and `Mission-Entrypoints-And-Lifecycle`.
- `WASP-Overlay.md` — full map of the project-specific `WASP/` subtree (baserep = base *repair*; unsort; rpg_dropping; selftest), how each piece is wired into the stock lifecycle, and the dead/missing WASP references.

**Targeted deepenings appended to existing pages (Codex text preserved):**
- `Networking-And-Public-Variables.md` — added "PVF dispatch internals": index-0 routing (`nil`/SIDE/UID) in `Client_HandlePVF.sqf`, the four send-wrapper→engine-primitive mapping, the `HandleSpecial`/`LocalizeMessage` second-level string multiplexing, and the wasteful UID-broadcast / `Spawn`-race / per-side-copy gotchas.
- `AI-Headless-And-Performance.md` — added "Delegation & caching internals": distance-based 90s spawn/despawn as the real caching layer (not `enableSimulation`), the absence of `setGroupOwner` (HC owns by remote-creation; orphan-on-disconnect risk), the init-time silent delegation downgrade, and the intentional `GetSleepFPS` inversion.
- `Current-Work-Supply-Helicopters-PR1.md` — answered all six of Codex's "Suggested Review Focus" questions from the actual diff, with a verdict table.

**Findings / corrections recorded (per coordination rule on contradictions):**
1. **AI supply trucks are not cleanly inert — they are a config-gated landmine.** `UpdateSupplyTruck` compile is commented (`Init_Server.sqf:36`) but the call `[_side] Spawn UpdateSupplyTruck;` (`:383`) is *live*, gated by `WFBE_C_ECONOMY_SUPPLY_SYSTEM == 0 && AI_COMMANDER_ENABLED > 0` (`:381`). Default `SUPPLY_SYSTEM = 1` makes default play safe, but selecting Supply System 0 ("Trucks") + AI commander → `Spawn` on a nil → runtime error, and the missing `Server/FSM/supplytruck.fsm` would fail again even if the compile were restored. Sharpened `Feature-Status-Register.md` accordingly.
2. **Confirmed: PR #1 stacks `Killed` event handlers** on supply vehicles reused across missions (`supplyMissionStarted.sqf`, no guard/removal). Interdiction can't double-pay (the first handler zeroes `SupplyAmount`), so impact is a bounded EH leak today — but it's a real defect. Suggested fix recorded on both the PR page and the status register.
3. **PR #1 cash-run tradeoff:** on a heavy-heli cash run the side *supply* pool gets nothing; the value is diverted to commander team funds (plus the pilot's +25% personal reward). Documented as intended design, not a bug.

**`agent-context.json`** — sharpened the AI-supply known-risk and added a `reviewPasses` record; verified still valid JSON.

**For Codex / future agents:** please reconcile the GitHub wiki copy after merge (mirror parity is a review gate). The two new pages and the appended sections are also pushed to the wiki. Open question left for code owners, not docs: decide whether to *fix* or *delete* the dead `Init_Server.sqf:383` supply-truck call.

## Future Agents

- Add dated entries here before and after substantial documentation or code changes.

