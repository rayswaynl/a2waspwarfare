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

## 2026-06-01 - Claude (deep-review round 2: adversarial cross-check)

Adversarial verification pass over Codex's atlas pages (`SQF-Code-Atlas`, `Gameplay-Systems-Atlas`) against the Chernarus source. New page `Deep-Review-Findings.md` holds the full source-cited writeups (DR-1..DR-5); summary:

- **DR-1 (High, security/hardening):** the PVF dispatch is a `Call Compile` trust boundary. `Server_HandlePVF.sqf`/`Client_HandlePVF.sqf` compile the sender-chosen `select 0`/`select 1` with no command-name validation, and `BattlEyeFilter/publicvariable.txt` has only the `kickAFK` feature rule (not a security filter). Clients reach the channel via `Common_SendToServerOptimized.sqf:15`. Playbook: validate against the registered `SRVFNC*`/`CLTFNC*` set before compile + add a real BE PV filter. This makes Codex's generic "high-risk" note concrete and actionable.
- **DR-2 (Medium):** paratrooper drop markers are dead — `Support_Paratroopers.sqf:117` sends `HandleParatrooperMarkerCreation`, but it is absent from `_clientCommandPV` (no EH, `CLTFNC…` never compiled). Resolves the atlas's "exists but not registered" → broken.
- **DR-3 (Medium):** MASH tent map markers are dead on the receive side — the client EH in `receiverMASHmarker.sqf` is referenced only by the commented compile at `Init_Client.sqf:132`; server re-broadcast is live. Resolves the atlas's "requires verification."
- **DR-4 (Medium, generated-mission drift):** a full recursive diff shows Chernarus↔Takistan differ **only** by LoadoutManager skip-listed files / blacklisted dirs — no accidental drift, but the skip-list (`mission.sqm`, `GUI_Menu_Help`, `StartVeh`, `Core_Artillery`, `Server/Config`, `Textures`, `loadScreen`, `texHeaders`) is a silent-divergence trap; "edit Chernarus + run LoadoutManager" is incomplete for those. `Modded_Missions/*` are abandoned (Napf/eden/lingor ~280-350 files behind; others 1-4-file stubs) because modded propagation is commented at `SqfFileGenerator.cs:132`. Expanded guidance added to `Tools-And-Build-Workflow.md`.
- **DR-5 (Low):** the atlas's `preprocessFile` counts (659/452/207) recount to 678/465/213 on the index base — present such counts as point-in-time with a regen command. Also recorded verified-accurate cross-checks (FSM count = 3; the unregistered PVF observations) for trust calibration.

Edited: `Feature-Status-Register.md` (MASH row → confirmed broken; added paratrooper-marker and PV-trust-boundary rows), `Networking-And-Public-Variables.md` (security subsection), `Tools-And-Build-Workflow.md` (propagation skip-list trap + modded staleness), `agent-context.json` (new risks + round-2 reviewPass). No gameplay code changed. Handoffs for code owners listed at the bottom of `Deep-Review-Findings.md`.

## Future Agents

- Add dated entries here before and after substantial documentation or code changes.

