# Fable Ultracode Master Instructions V2 — Tonight One-Shot Completion Push

Generated: 2026-07-05
Supersedes: `FABLE_ULTRACODE_MASTER_INSTRUCTIONS_2026-07-05.md`
Primary repos:
- `rayswaynl/a2waspwarfare`
- `rayswaynl/miksuus-website-discord-bot`

This V2 file keeps every rule from the original master instructions unless this addendum explicitly tightens or overrides it. The goal is a serious tonight push with two Max/Fable subscriptions, using the right agents, right effort, and final Ultra-grade review. No mystical sprint nonsense. Build it like adults, or at least like software goblins with a checklist.

---

## 0. Supreme rule for this run

**Fable 5 Ultra / Agent A has final say over plan quality and release readiness.**

Agent B may build, propose, and self-review, but Agent A must approve the active completion map, high-risk task packets, final integration plan, and any decision to shelve/discard/merge PR work.

Nothing gets treated as complete until Agent A has:

1. inspected the final diff or PR body;
2. checked owner intent;
3. checked tests / validation evidence;
4. checked hidden-intel boundaries;
5. graded the result;
6. requested fixes where needed.

---

## 1. Tonight objective

Create a controlled **one-shot update plan** across mission + website/bot. "One-shot" means a coherent release outcome, not one blind mega-commit with twelve subsystems welded together like a clown car.

Recommended structure:

1. Discovery branch / docs PR.
2. Agent A creates an active completion map.
3. Agent A creates task packets.
4. Agent B executes one bounded lane at a time.
5. High-risk lanes are staged as separate commits/PRs or stacked branches.
6. A final integration branch may combine approved lanes after evidence exists.
7. No live deploys unless owner explicitly does it outside the agent flow.

Primary goals tonight:

- Reconcile AICOM V2 direction with owner intent.
- Review open PRs, PR comments, and today's RPTs before building.
- Decide which PRs to implement, stack, rebase, shelve, discard, or convert into docs-only evidence.
- Remove unnecessary telemetry, old commander trash, stale code, duplicate systems, and mission bloat where safe.
- Replace old noisy telemetry with better telemetry that feeds:
  - after-match report / Warfare handler;
  - test Discord posting;
  - future `miksuu.com/stats` / Command Center pages;
  - admin-only performance and AI commander diagnostics.
- Produce a final LOC/bloat report.

---

## 2. Mandatory discovery before building

Agent A must perform discovery before Agent B edits code. Agent B may do read-only archaeology, but must not implement until Agent A emits task packets.

### 2.1 Repos and branches

Inspect both repos:

```text
rayswaynl/a2waspwarfare
rayswaynl/miksuus-website-discord-bot
```

For each repo:

- current default branch;
- active release/dev branches;
- open PR list;
- PR base/head/mergeability;
- CI status;
- PR body;
- PR comments and review comments;
- changed files;
- relationship to owner wishes in this file.

If `gh` is available, use it. If not, use the GitHub UI/API/export available in the environment. If PR comments cannot be inspected, stop and ask owner for an export before making irreversible decisions. Delightful that comments matter; terrible that humans keep important information there.

### 2.2 Today's RPTs and runtime evidence

Before building AICOM, telemetry, performance, HC/ASR, AI logistics, or spawn behavior, inspect today's RPT/runtime evidence.

Create:

```text
docs/project-management/RPT-EVIDENCE-2026-07-05.md
```

Minimum evidence to collect:

- list of RPT/log files inspected;
- modified time and machine/source path;
- current `MISSINIT` boundary;
- server RPT vs HC RPT distinction;
- `Error in expression`, `Undefined variable`, `No entry`, `Cannot create`, `grpNull`, script errors;
- AICOM lines: `AICOM2|`, `AICOMSTAT|`, legacy AICOM emitters;
- group/perf lines: `GRPBUDGET|`, `DELEGSTAT|`, `TOWNSTAT|`, `GRPEMPTY|`, `WASPSCALE|`;
- WASPSTAT lines relevant to after-match reporting;
- evidence from today's playtest notes, including RHUD issues, AI commander behavior, Scout/SCUD confusion, and player-visible UI bugs.

Scope all reads to today's session where possible. Do not cite stale logs as proof of current behavior unless clearly labelled historical.

### 2.3 Source-of-truth docs

Read and reconcile:

- existing `AGENTS.md` and repo guide docs;
- this V2 instruction file;
- existing V2 cutover / migration docs;
- open AICOM PR bodies and comments;
- website/bot status docs;
- Discord/guild architect docs;
- prior framework docs if present.

If instructions conflict, Agent A must record the conflict and ask the owner before building.

---

## 3. Required artifacts for this run

Agent A must create/update these docs before Agent B does serious edits:

```text
docs/project-management/FABLE-ACTIVE-COMPLETION-MAP.md
docs/project-management/PR-TRIAGE-2026-07-05.md
docs/project-management/RPT-EVIDENCE-2026-07-05.md
docs/project-management/OWNER-QUESTIONS-BEFORE-BUILD.md
docs/project-management/TELEMETRY-AND-STATS-V2-PLAN.md
docs/project-management/BLOAT-AND-LOC-REPORT-2026-07-05.md
```

Agent B must update the relevant docs after each lane:

```text
docs/project-management/FABLE-BUILD-LOG-2026-07-05.md
```

Final handoff must include:

- what changed;
- what did not change;
- PRs shelved/discarded/recommended;
- tests run;
- RPT evidence;
- LOC report;
- remaining owner questions;
- known risks;
- rollback plan.

---

## 4. Instruction file editing protocol

Agent A may edit this instruction file only if:

1. the edit clarifies owner intent;
2. the edit is recorded in a changelog section;
3. the edit does not silently weaken repo safety rules;
4. the owner can review the change.

Every change must include:

```md
## Instruction changelog entry
Date/time:
Changed by:
Reason:
Old ambiguity:
New rule:
Owner approval needed: yes/no
```

Agent B must not rewrite this file unless Agent A explicitly assigns that task.

---

## 5. PR triage requirements

Every open PR must be classified as one of:

- `MERGE-CANDIDATE`
- `NEEDS-REBASE`
- `STACKED`
- `SUPERSEDED`
- `DUPLICATE`
- `SHELVE`
- `DISCARD`
- `IMPLEMENT-IN-ONE-SHOT`
- `OWNER-DECISION`
- `EXTERNAL-BLOCKED`
- `DOCS-ONLY-REFERENCE`

For each PR, record:

```md
| PR | Title | State | Mergeable | CI | Classification | Reason | Owner action | Next step |
```

Special review focus:

- AICOM V2 PRs, especially #713 and #715.
- Older commander/balance/GUER docs-only PRs that might now be stale.
- Miksuu CI-red PRs.
- PRs that duplicate docs or update the same hub files.
- PRs that introduce noisy telemetry or stale commander concepts.

Agent A must explicitly suggest which PRs should be shelved/discarded, not merely list them like a spreadsheet-shaped shrug.

---

## 6. Owner intent overrides for AICOM and AI behavior

The owner does **not** want an omniscient AI commander that rushes the enemy base early.

Ground AI commander behavior should be:

- town-first;
- camp / bunker / town-center capture focused;
- road-following where possible;
- constantly moving and engaging;
- field-present rather than base-defense obsessed;
- aggressive in the field;
- opportunistic, not psychic.

Base/HQ/factory pressure rule:

- Ground groups should only consider enemy base/HQ/factory action after they organically come near it, roughly within about 3 km.
- Detection should be periodic and chance/dice-roll based, not constant global knowledge.
- The AI should not abandon the map-capture game to cross 40+ towns toward a known base.
- If base discovery happens, it should create nuisance/pressure and interesting PvP, not an instant win timer.
- Actual victory must come from real gameplay consequences such as overrun/razing, not a magic timer.

Air behavior:

- attack helicopters and jets may react faster than ground groups;
- they may support lanes or punish pushes quickly if pathing/flight behavior is good;
- they still should not become omniscient base hunters;
- air routing, terrain usage, weapon usage, and skill profiles deserve separate review.

Base pushing / AI base relocation:

- AI commander eventually needs to move or push the base forward, but not into places players hate.
- Agent A must ask owner specific questions before implementing base-relocation or base-push logic.

---

## 7. AI commander unit composition and logistics owner intent

Composition:

- Balanced preset doctrine is preferred over hard counter-deception.
- The AI should showcase most meaningful combat vehicles once unlocked through appropriate factory levels and dependencies.
- Exclude stupid/low-value vehicles such as ATVs and bikes unless a specific role exists.
- Anything with usable guns can be considered once the relevant factory/upgrade state allows it.

When AI is doing badly:

- It should not turtle by default.
- It can use fewer but better units.
- It may use more groups if performance/budget allows.

Logistics / stuck recovery:

- Fuel should effectively be infinite for AI commander units, otherwise they get stuck repeatedly and the world becomes a parking lot with aspirations.
- Rearm/repair should be driven by stuck/damaged conditions, not abstract front stabilization.
- Preserve current useful behavior where a vehicle driver is killed, another unit takes the driver seat, smoke is used where appropriate, and the group continues to target.
- Investigate whether AI can dismount, repair tires/vehicle, remount, and continue.

No deception:

- Do not build fake pushes, fake retreats, or elaborate deception systems.

---

## 8. Telemetry cleanup and replacement policy

Telemetry must become cleaner, not louder.

### 8.1 Remove or retire

Agent A must identify and classify telemetry as:

- `KEEP`: needed and consumed;
- `PORT`: useful but must move to new schema/consumer;
- `ADMIN-ONLY`: sensitive and not public;
- `REMOVE`: noisy/stale/unconsumed;
- `HISTORICAL`: docs/wiki only;
- `UNKNOWN`: needs owner/consumer proof.

Candidates for cleanup:

- old V1 commander telemetry after V2 mapping;
- duplicate AICOM emitters;
- unconsumed debug spam;
- old commander trash that has no active consumer;
- stale docs-only telemetry concepts that conflict with live AICOM2 direction.

Do not remove telemetry that feeds current tools until a replacement is documented or implemented.

### 8.2 New telemetry design

Create/update:

```text
docs/project-management/TELEMETRY-AND-STATS-V2-PLAN.md
```

The plan must define:

- event families;
- public vs admin-only fields;
- RPT grammar;
- DB/API ingestion route;
- after-match report integration;
- Discord test-post integration;
- `miksuu.com/stats` / Command Center integration;
- privacy and hidden-intel limits;
- telemetry volume budget.

Public/player-facing allowed examples:

- match duration;
- winner;
- player count;
- town counts at round end;
- total kills by broad category;
- vehicles destroyed by broad class;
- captures;
- economy totals that do not reveal live plans;
- map/theater stats;
- balance summaries;
- performance summaries after match.

Admin-only examples:

- AI commander target choices;
- enemy base detection events;
- exact base positions;
- current capture intentions;
- planned routes;
- live tactical intel;
- raw AICOM reasoning rows;
- detailed performance/HC internals if sensitive.

Forbidden on public pages:

- active enemy base location;
- enemy commander current target town;
- towns currently being captured if that reveals tactical advantage;
- live AI route/intent;
- anything that helps players snipe the other team’s strategy.

---

## 9. After-match report and `miksuu.com/stats` direction

The future stats/reporting system should connect these pieces:

1. Mission emits clean match/stat telemetry.
2. Ingest worker/API stores event and match data.
3. After-match / Warfare handler builds report.
4. Report posts to test Discord.
5. Website Command Center / `/stats` shows public-safe visuals.
6. Admin dashboard shows sensitive/performance/AI diagnostics.

The bot should consume DB/outbox state for new Stats V2 features. It should not become the raw RPT parser.

Website direction:

- `/wasp` should become `/stats` where practical.
- Avoid “War Room” if owner prefers “Command Center” or similar.
- Reimagine visuals with assets, shadows, subtle animation, better graphs, better map scale presentation.
- Keep player-facing stats exciting but fair.
- Move sensitive performance/AI/commander internals into admin dashboard.
- Homepage/header/nav mostly okay; revise content with owner notes.
- Guides must be updated to current feature set.
- In-game guides must be synced.
- Remove redundant map note guide if WF Help menu covers it.

---

## 10. LOC and bloat report

At the end of the run, produce:

```text
docs/project-management/BLOAT-AND-LOC-REPORT-2026-07-05.md
```

Minimum contents:

- total tracked LOC by repo;
- LOC by major directory;
- SQF mission LOC by Chernarus/TK/ZG/generated areas;
- website/bot/db LOC breakdown;
- docs LOC if useful;
- telemetry emitter count before/after where possible;
- files removed or recommended for removal;
- stale systems identified;
- PRs recommended to shelve/discard;
- bloat risks not yet fixed;
- tool used (`cloc`, fallback script, or git statistics).

If `cloc` is unavailable, write a small script using `git ls-files` and count lines by extension. Do not count `.git`, build outputs, caches, package artifacts, or generated archives.

---

## 11. Mandatory owner question gate

After discovery and before implementation, Agent A must ask concise owner questions for any unresolved high-impact behavior.

Required question areas if not already resolved:

- exact AICOM base-sensing radius / chance cadence;
- what counts as “near enemy base” for air vs ground;
- when AI base relocation should happen and how player preference is respected;
- which public stats are allowed and which must stay admin-only;
- whether to rename `/wasp` to `/stats` now or via redirect first;
- which Discord stats roles are desirable and their thresholds;
- whether open CI-red Miksuu PRs should be fixed now or left blocked;
- which old AICOM/telemetry PRs owner wants shelved outright.

Do not bury questions inside a giant report. Put them in:

```text
docs/project-management/OWNER-QUESTIONS-BEFORE-BUILD.md
```

Then summarize them to the owner.

---

## 12. Final self-grade rubric

Every major artifact must be graded.

Grade dimensions:

- owner intent fidelity: /20
- source evidence quality: /20
- task decomposition: /15
- hidden-info safety: /10
- performance safety: /10
- testability: /10
- rollback clarity: /5
- bloat/telemetry discipline: /5
- readability/handoff quality: /5

Anything below 85/100 requires revision before handoff.

---

# Base instructions from V1 continue below

# Fable Ultracode Master Instructions — WASP / Miksuu Completion Program

Generated: 2026-07-05
Intended users: two Claude/Fable Ultracode subscriptions working in parallel
Primary repos:
- `rayswaynl/a2waspwarfare`
- `rayswaynl/miksuus-website-discord-bot`

This is the control file for the next project-completion push. Read it before making plans, edits, PRs, or task splits. The purpose is to turn owner wishes into bounded, testable work without creating a bigger mess. A shockingly ambitious standard for software, but there it is.

---

## 0. How to use this file

Place this file somewhere both Fable sessions can read it, ideally in the repo root while working locally, or under:

```text
docs/project-management/FABLE_ULTRACODE_MASTER_INSTRUCTIONS_2026-07-05.md
```

Each Fable session must:

1. Read this file fully.
2. Identify whether it is acting as **Agent A: Architect / Orchestrator** or **Agent B: Builder / Implementer**.
3. Use sub-agents or simulated sub-agent passes for research, planning, implementation, review, and grading.
4. Match effort level to task risk.
5. Escalate ambiguous or high-risk decisions upstream to a stronger/higher-effort pass before editing.
6. Produce draft PRs only. No live deploys.
7. Preserve owner intent, especially where it conflicts with an existing PR/spec.

If a task conflicts with this file, stop and record the conflict. Do not “creatively interpret” around it. That is how codebases become haunted.

---

## 1. Two-subscription operating model

Use the two Fable subscriptions as different roles, not as two agents randomly attacking the same repo.

### 1.1 Agent A — Architect / Orchestrator / Final Reviewer

Agent A owns planning, triage, source-of-truth maintenance, and final quality review.

Responsibilities:

- Maintain the active completion map.
- Classify open PRs.
- Detect duplicate, stale, superseded, or risky work.
- Convert owner wishes into bounded task lanes.
- Create exact task packets for Agent B.
- Ask owner questions when behavior is ambiguous.
- Review Agent B output before merge.
- Grade final output against this file, repo rules, and owner intent.

Agent A must not casually implement code while Agent B is working in the same area.

Recommended sub-agent loop:

1. **Source Scout** — locate current files, PRs, docs, wiki references, and prior attempts.
2. **Product Analyst** — translate owner wish into player-facing outcome and acceptance criteria.
3. **Risk Analyst** — identify performance, fairness, merge, and hidden-intel risks.
4. **Task Decomposer** — split into bounded PR-sized lanes.
5. **Reviewer / Grader** — score the final task packet and identify gaps.

Output format per planning session:

```md
# Agent A Session Report

## Objective
## Sources inspected
## Current source-of-truth state
## PR classifications changed
## Owner decisions needed
## Task packet(s) for Agent B
## Risks
## Final grade: /100
## Next recommended action
```

### 1.2 Agent B — Builder / Implementer / Self-Reviewer

Agent B owns one bounded lane at a time.

Responsibilities:

- Read Agent A task packet and this file.
- Research exact code flow before editing.
- Touch only allowed files.
- Implement the smallest viable change.
- Run required checks.
- Self-review and fix issues.
- Produce a draft PR body with verification and rollback.

Recommended sub-agent loop:

1. **Code Archaeologist** — trace current flow and name exact files/functions.
2. **Implementation Planner** — propose minimal edit plan and allowed files.
3. **Builder** — make the edit.
4. **Test Runner** — run lint/tests/smoke checks or document why not run.
5. **Reviewer** — inspect diff for scope creep, A2 traps, UI regressions, and owner-intent mismatch.
6. **Final Grader** — score against acceptance criteria and make required fixes.

Output format per build session:

```md
# Agent B Build Report

## Task received
## Files inspected
## Files changed
## Why each file changed
## Commands run
## Commands not run and why
## Verification result
## Known risks
## Rollback
## Draft PR body
## Final grade: /100
```

### 1.3 Human owner

The owner decides:

- Gameplay philosophy when there are multiple valid designs.
- Merge order.
- Live deploy timing.
- External blockers such as BattlEye/RCON, `.bikey` whitelisting, Discord guild settings, and archive-drive access.
- Whether a high-risk system gets pulled earlier than the recommended order.

Agents must not silently convert an owner decision into an implementation assumption.

---

## 2. Effort and escalation rules

### 2.1 Effort levels

Use the lowest effort that is safe. Use higher effort when risk or ambiguity is high.

| Task type | Default effort | Escalate when |
|---|---:|---|
| Copy changes, guide edits, obvious docs | Low / Medium | The copy changes gameplay meaning or official instructions |
| Website visuals, layout, page restructuring | Medium | Data privacy, hidden intel, auth, or stats schema is involved |
| Discord roles, panels, guild structure | Medium | Permissions, pruning, role hierarchy, or production guild migration is involved |
| Mission UI/HUD alignment | Medium / High | Touches common dialogs, event handlers, or multi-resolution layout logic |
| SQF gameplay behavior | High | Any commander, AI, economy, purchase, spawn, or network behavior is involved |
| AICOM V2 / commander logic | Very High / Ultra | Always use higher effort; this is core project risk |
| Headless client / ASR / performance | Very High / Ultra | Always use higher effort; performance regressions are unacceptable |
| Stats V2 ingest / DB / telemetry | High / Ultra | Schema, privacy, or match history correctness is involved |

### 2.2 Escalation triggers

Escalate to a stronger/higher-effort pass before editing if:

- The current code contradicts the owner wish.
- An existing PR implements a different concept than the owner now wants.
- A task could reveal tactical hidden information to players.
- A task touches AICOM V2, HC, ASR, JIP, deploy scripts, or server runtime.
- A task could increase group count, AI count, or RPT spam.
- A proposed fix requires broad rewrites or more than one subsystem.
- Tests are red for unclear reasons.
- Mergeability is false or branch stacking is unclear.

Escalation output must be explicit:

```md
## Escalation note
I am escalating because: ...
Choices available: ...
Recommended path: ...
Owner decision needed: yes/no
```

---

## 3. Repo rules — `a2waspwarfare`

Mission repo: `rayswaynl/a2waspwarfare`

Known operating rules:

- Arma 2: Operation Arrowhead 1.64 only.
- Chernarus mission source is the source of truth.
- Takistan and Zargabad are mirrors generated through LoadoutManager.
- Draft PRs only, normally to `claude/build84-cmdcon36` unless owner says otherwise.
- No live deploys by agents.
- Do not use Arma 3 commands, syntax, docs, or assumptions.
- Preserve line endings and avoid broad reformat churn.
- New features should be default-off behind a flag unless they are clear correctness fixes.
- Do not touch HC architecture, player enrollment/JIP flow, deploy scripts, or box scripts unless explicitly assigned.
- Do not nerf GUER volume. GUER output is intentional.
- Do not resurrect shelved PRs or shelved ideas without checking the shelved register and asking owner.
- No false validation claims.

Important A2/OA traps to avoid:

- No `params`, `pushBack`, `findIf`, `apply`, `selectRandom`, `remoteExec`, `distance2D`, `worldSize`, `getPosVisual`, `setGroupOwner`, or Arma 3-only helpers.
- Do not use `missionNamespace setVariable` with third public argument.
- Avoid two-argument `getVariable [name, default]` on GROUP receivers unless repo-safe wrapper exists.
- Do not use Boolean `==` / `!=` where project guide forbids it.
- Do not add unproven classnames.

Expected SQF flow after edits:

1. Edit Chernarus source only unless task explicitly says otherwise.
2. Run required lint gates.
3. Run LoadoutManager to mirror TK/ZG.
4. Restore TK/ZG templates if they drift.
5. Confirm bracket deltas.
6. Confirm no filtered RPT script errors if smoke/soak was run.

---

## 4. Repo rules — `miksuus-website-discord-bot`

Platform repo: `rayswaynl/miksuus-website-discord-bot`

System shape:

- Monorepo: `db/`, `web/`, `bot/`.
- Shared Postgres database.
- Website: Next.js.
- Bot: Python / discord.py.
- Web-to-bot actions should go through transactional outbox.
- The Discord bot must not become the parser for new V2 match/RPT data. Stats ingest should write to DB/API; bot consumes DB/outbox state.
- CI red means stop unless owner explicitly accepts risk.
- Docs must match actual cogs, commands, routes, config, and activation steps.

Known current platform themes:

- The core website/bot/database program is mostly built.
- Recent merged work includes live server-status panel and BE RCON chat relay, but runtime activation requires owner/server steps.
- Some open PRs are blocked by CI or production setup decisions.
- Website docs and command docs may be stale against newly loaded cogs such as `chat_relay` and `live_status`.

---

## 5. Product philosophy

### 5.1 Overall project feel

The experience should sell a living Warfare world:

- PvP is the core.
- AI gives the world life, pressure, and background conflict.
- AI should be a nuisance and a dynamic battlefield presence, not the main character that solves the match.
- The world should feel alive without revealing unfair information or tanking performance.

### 5.2 Hidden information rule

Player-facing surfaces must not reveal tactical intelligence that would change live PvP fairness.

Do not show players:

- Commander decisions.
- Exact enemy base/HQ/factory locations.
- Enemy town targets.
- Exact towns currently being captured by enemy if that grants a live advantage.
- AI plans, hidden waypoints, or future movement intent.

Player-facing surfaces may show general public information:

- Total kills.
- Vehicle kills.
- Deaths.
- Captures/towns captured after safe aggregation.
- Side balance.
- General match result and history.
- Performance summaries that do not leak tactics.

Admin-only surfaces may show sensitive operational detail if protected correctly.

---

## 6. Current owner wishes — website

### 6.1 Global website visual direction

The whole website should become more visual and polished.

Owner preference:

- Use existing assets more.
- Use assets lightly: diluted, shadowed, backgrounded, or subtly animated.
- Avoid making pages text-heavy.
- Visuals should draw people in, not become busy or childish.
- Better data visualizations are important.
- Maintain the dry/factual Miksuu/WASP tone; no hype sludge.

### 6.2 Homepage

Keep:

- Header.
- Top navigation bar.

Change the second content block:

- Do not frame it as “no scripter, real brain, AI commander runs each side.”
- Frame it as **PvP plus a living AI-driven world**.
- Make clear that command can be player or AI depending on context.
- AI is an element that keeps the world alive; PvP remains central.

Homepage facts to use:

- 40+ capturable towns.
- 32 players per match.
- 500+ AI units in play.
- Escalating rounds around 2–8 hours.

Two theaters section:

- Make it more graphic and less text-heavy.
- Focus on map scale and theater feel.
- Use visuals/comparison cards/map silhouettes if available.
- Purpose is to attract players quickly.

Server section:

- Add a more visible path/link/card to optional mods.
- Do not clutter the page.

### 6.3 Stats / Command Center overhaul

This is a large redesign.

Route/name:

- Prefer `/stats` over `/wasp`.
- Do not call it “War Room” unless owner later chooses that.
- Possible name: **Command Center**.
- Need final naming decision later.

Core direction:

- Full remake, not tiny copy edits.
- More visual, more structured, better graphs/data visualization.
- Use assets, shadows, light animation, and creative visual metaphors carefully.
- Split public player-facing stats from admin-only tactical/operational stats.

Player-facing stats should include general info such as:

- Leaderboards.
- Side balance.
- What killed what / kill matrix.
- Vehicle kills.
- Total kills.
- Towns captured.
- Match history and map views where safe.
- Data across all maps/theaters currently supported.

Admin-only stats/performance should include:

- Commander decisions and intent.
- AI commander telemetry.
- Performance per patch.
- Server performance trends.
- Group count / AI count / player count tuning data.
- Stale data detection.
- Ingest health.
- Detailed match telemetry.

Performance tab/admin tooling:

- Current performance data has stale datapoints.
- Keep all existing data if possible.
- Rewire it into better tools for insight.
- Goal: tune optimal experience by adjusting groups, AI, and player limits over time.
- Must support per-patch comparisons.

### 6.4 Guides

Website guides need updating because many features changed.

Requirements:

- Update website guides to match current features.
- Update in-game guides too.
- Remove redundant guide from map notes.
- The WF menu Help menu should be the main in-game guide source.
- Do not duplicate stale guides in multiple places.

---

## 7. Current owner wishes — Discord

### 7.1 Normal user roles

Add or improve normal user roles.

Possible categories:

- Interest roles.
- Notification roles.
- Dev/interested-in-development role.
- Gameplay role preferences if useful.

### 7.2 Stats-based roles

Add a couple of roles based on stats.

Possible sources:

- Playtime.
- Match participation.
- Commander activity.
- Captures.
- Logistics contribution.
- Veteran/high-contribution thresholds.

Must avoid:

- Pay-to-win implication.
- Exposing private/opt-out data.
- Roles that create admin workload or drama.

### 7.3 Roles channel and category depth

Owner wants role selection that can help collapse/expand parts of the Discord.

Concept:

- Roles channel lets users pick interest roles such as dev.
- Some categories can be hidden/collapsed by default and become relevant when users have the role.
- Users can still manually expand if Discord allows.
- Goal is less clutter, more depth for interested users.

If using guild-architect work, ensure role hierarchy, permissions, and Community/forum gates are handled carefully.

---

## 8. Current owner wishes — game UI / HUD / menus

### 8.1 WF menu purchase units — factory queue alignment

Issue:

- In WF menu > Purchase Units, near Factory Queue, “Cancel Last” text/button does not align properly.

Task direction:

- Locate exact dialog/menu file.
- Fix alignment cleanly.
- Verify common resolutions/UI scale if possible.
- Keep scope limited to alignment unless owner expands.

### 8.2 RHUD top-right factory queue alignment and overflow

Issues:

- RHUD top-right queue does not align with actual RHUD bar.
- When queuing units/items, elements can end up outside the screen.
- Factory queue/upgrade display shows only a maximum of two upgrades in some cases.
- It should stack underneath or otherwise remain readable and inside screen bounds.

Task direction:

- Research current RHUD layout.
- Fix alignment and overflow.
- Show more queued upgrades/items, or scroll/stack cleanly.
- Do not create a giant HUD rewrite unless required.

### 8.3 Team menu clean-slate repurpose

Current issue:

- Team menu duplicates features now handled elsewhere.
- View distance and terrain grid are in Settings.
- Money transfer is in Economy.
- Existing team menu may become nearly empty if redundant items are removed.

Owner direction:

- Ask Fable to research and propose what this menu should become.
- Treat it as a clean-slate design challenge.
- Do not fill it with useless “team management” if those features are not actually useful.
- Candidate should add meaningful gameplay utility.

Possible design areas to explore:

- Player coordination/nudge menu.
- Quick support request menu.
- Squad intent / role declaration.
- AI interaction/field command hints.
- Tactical utility that does not leak hidden intel.

Deliver first as proposal, not implementation.

### 8.4 SCUD / Scout ambiguity — verify exact asset

Owner reported via voice transcription:

- “Scout is not drivable on Chernarus” OR possibly “SCUD is not drivable on Chernarus.”
- With first upgrade, owner could still not fire munitions from Tactical Center.
- Consider adding it to the artillery menu.

Important:

- Do not assume the asset name. Verify in code/UI/classnames whether this is `SCUD`, `Scout`, or another vehicle.
- Confirm Chernarus-specific availability.
- Confirm factory upgrade dependencies already exist.
- Confirm Tactical Center munition unlock logic.
- Confirm artillery menu integration rules.

### 8.5 Factory upgrades menu icons

Issue:

- Some factories have small icons in the factory upgrades menu.
- Owner wants to check whether icons exist for the other factories and make presentation consistent.

Task direction:

- Inventory current icons/assets.
- Determine missing factories.
- Reuse existing icons if available.
- If new icons needed, propose style first.

### 8.6 WF menu bottom item cleanup

Owner wants:

- Remove “earplugs in/out” from bottom of WF menu.
- Check whether the text menu / friendly name tags on/off toggle works properly.

Task direction:

- Locate current earplug menu wiring.
- Confirm whether feature exists elsewhere or can be removed from visible menu only.
- Test friendly name tags toggle.
- Fix if broken.

### 8.7 HQ team map markers destination direction

Issue:

- HQ team map markers should point toward where the unit/team is walking/driving to.
- They should not simply point in the unit’s current facing direction.

Task direction:

- Locate marker update logic.
- Determine current facing source.
- Change marker direction to destination vector when a valid move/drive target exists.
- Fall back to actual facing only if no destination is known.
- Must work for walking and driving.

---

## 9. Current owner wishes — strategic spawns and placement

### 9.1 Strategic spawn markers on roads

Owner clarification:

Strategic spawns means the existing commander-placed spawn markers from:

```text
Command -> Constructions -> Strategic
```

Do not invent a new marker system.

Desired behavior:

- Existing strategic markers remain the source of truth for spawn intent.
- Actual spawn position should prefer nearby road or roadside positions.
- Units/vehicles should not spawn in trees, blocked terrain, or bad off-road positions if a road-safe point is nearby.
- If no safe road exists, fall back to original behavior and log why.

Research first:

1. Find Strategic construction menu action.
2. Find marker creation/storage.
3. Find spawn consumption point.
4. Find existing road/safe-position helpers.
5. Report exact files before editing.

Potential implementation:

- Add or reuse road-aware spawn resolver.
- Search expanding radius around marker.
- For vehicles, align to road direction if possible.
- For infantry, road-adjacent is fine.
- Add debug evidence for resolved versus fallback.

### 9.2 Factory/base construction placement

Owner wish:

- Do not build factories on roads or in trees.
- Move placement if needed for a better base.

Task direction:

- Research current construction placement resolver.
- Add safety checks for roads, trees, objects, slope, water, and base layout if feasible.
- Do not make construction fail more often without a useful fallback.
- Prefer nudging placement to nearby valid space.

---

## 10. Current owner wishes — AI commander behavior

This is core. Use high or ultra effort.

### 10.1 AI philosophy

The AI commander exists to bring life to the world.

Owner intent:

- PvP remains central.
- AI should keep moving, capturing, engaging, and creating pressure.
- AI should be a nuisance and living battlefield presence, not an omniscient match-ending machine.
- Performance impact is the main constraint.
- Avoid behavior that causes AI to stall, camp too much, or take over the player experience.

### 10.2 Base defense vs field aggression

Owner preference:

- AI commanders should be more aggressive in the field.
- Base defense is less important because players will handle a lot of base defense.
- Field AI may naturally intercept players moving toward base.
- AI focus should be capturing towns and maintaining field presence.

### 10.3 Town capture priority

Owner preference:

- HQ teams should focus on capturing towns.
- Capture camps first, then town centers/bunkers/middle objectives.
- Move to the next town after capture.
- Follow roads where possible.
- Avoid direct early base rush.

### 10.4 Enemy base / HQ sensing

This is a key correction to PR #713 direction.

Owner does **not** want AI to know the enemy base globally and rush it too early.

Preferred behavior for ground units:

- Ground HQ teams continue town capture routes.
- If they naturally come within approximately 3 km of an enemy base/HQ/factory area, they may have periodic chances to “sense” or decide to investigate/attack.
- Use dice-roll/chance logic rather than guaranteed instant omniscience.
- This should happen organically while they are already operating nearby.
- Do not slow the entire AI commander by making it cross the whole map to chase a known base.

Air units:

- Helicopters/jets can respond more flexibly and quickly.
- Still avoid omniscient base focus.
- Air should threaten players and support lanes when organically relevant.
- Flight path, terrain use, weapon usage, skill, and survivability matter.

### 10.5 PR #713 DECAPITATE caution

Existing PR #713 concept:

- It commits dominant side toward enemy HQ based on dominance and enemy town count.
- It is currently shadow-mode/default-off.

Owner concern:

- With 40+ towns, this must not happen too early.
- Owner prefers organic base sensing near the base rather than a global HQ “kill move.”
- The current PR should be reviewed against this owner intent before merge.

Agent task:

- Review #713 and decide whether to adjust, split, shelve, or re-scope.
- Preserve useful anti-stall ideas if possible.
- Replace omniscient/global HQ targeting with organic proximity sensing if that better matches owner intent.
- Ask owner before enabling or merging a base-finisher that can redirect armies across the map.

### 10.6 Losing towns / softest lane

If AI loses a key town:

- Do not automatically rush to recapture it.
- Use bigger-picture logic.
- Push the softest lane: the lane where the AI does not get slaughtered.
- This aligns with “feelers” being added this update.

### 10.7 Player push response

Response depends on unit mobility.

Air:

- Attack helicopters and jets can react quickly.
- They should use optimized flight paths.
- They should use weapons well.
- Terrain-aware flight/hiding behind terrain is desirable if feasible.

Ground:

- Ground AI mostly continues its own plan.
- Armor may gradually respond if players push a lane hard.
- Do not overreact to every player move.

### 10.8 AI commander unit composition

Owner preference:

- Balanced preset doctrine, but wide variety.
- Show most usable vehicles.
- Anything with guns the AI can use is generally eligible.
- Avoid useless tiny vehicles such as ATVs and bikes.
- Unlock units only through appropriate factory levels and dependencies.
- Commander upgrades should control availability.

### 10.9 If AI is doing badly

Owner preference:

- Do not turtle or use deceptive tactics.
- Use fewer units but better units.
- If budget allows, maybe allow a couple more groups.
- Performance must remain safe.

### 10.10 No deception

Owner explicitly rejected deliberate deception/feints.

Do not implement:

- Fake pushes.
- Fake retreats.
- Bait behavior.
- Hidden trick systems.

Keep AI actions straightforward and readable.

---

## 11. Current owner wishes — AI unit behavior, logistics, transport

### 11.1 Transport behavior

Owner wants deeper transport behavior, including:

- Heavy/light pickups for infantry.
- Combined groups.
- Stuck handling.
- Driver killed handling.
- Tires shot out handling.
- Continue target after recovering.

Research required:

- Current group transport assignment.
- Driver replacement logic.
- Smoke pop / emergency behavior.
- Current stuck detection.
- Repair/rearm/refuel handling.

### 11.2 AI logistics

Owner preference:

- Fuel should be infinite for AI commander units. Otherwise they get stuck forever in boring ways.
- Rearm/repair/refit should be driven by being stuck or disabled, not by abstract front stabilization.
- If wheels/tires/truck are damaged and unit is stuck for some time, attempt repair if feasible.
- Preserve behavior where, if driver dies, another unit gets into driver seat, pops smoke if appropriate, and continues to target.

Question for later:

- Can AI dismount, repair wheels/truck, get back in, and continue safely in Arma 2 OA? Research before promising.

### 11.3 Aircraft spawning

Owner wishes from earlier backlog:

- Helicopters should spawn at owned airfields or safe open spaces near owned airfields / AF spawn markers.
- Planes should spawn only at owned airfields.
- Need safe open-space checks.
- Avoid aircraft spawning into bad terrain/objects.

### 11.4 Sea/air scenario tweak

Owner correction:

- A scenario currently spawns an AN-2 and an Mi-24.
- Owner wants this changed to **three Mi-24s in one group**.

Research required:

- Find exact scenario, map, side, and spawn file before editing.
- Confirm performance and balance impact.
- Confirm whether three Mi-24s in one group behaves correctly.

---

## 12. Current owner wishes — GUER / resistance director

Owner likes the GUER Director / living resistance concept because it supports the “world feels alive” goal.

Desired concept:

- GUER/resistance should create interesting scenarios for players.
- AI sides and GUER should be able to read enough intent to avoid dumb overlap and create natural conflict.
- GUER should not be nerfed into irrelevance.
- GUER Director should likely stay after AICOM V2 cutover unless owner explicitly moves it earlier.

Do not bundle GUER Director into AICOM V2 cutover unless explicitly instructed.

---

## 13. Current owner wishes — infrastructure, HC, ASR

Owner wants Fable to take another look at infrastructure:

- Headless clients.
- How new AI interacts with HC setup.
- ASR AI configuration.
- Profiles for all unit types.
- Performance, stability, and optimal AI/group/player tuning.

Rules:

- This is high-risk.
- Research first, no implementation first.
- Do not alter HC architecture without explicit owner approval.
- Produce an audit/recommendation PR before touching runtime behavior.
- Tie recommendations to performance data and soak testing.

---

## 14. Current owner wishes — in-game tips

Owner says current in-game tips “kind of suck.” Redo them.

New tip style:

- Useful only.
- Veteran-aware; many players have played for years.
- Focus on new or less obvious mechanics.
- No patch history.
- No “Patrick introduced…” or “since build X we fixed…” style.
- Give players handles to features they can use.

Topics to cover:

- Unit nudging / request help / request take town.
- AI behavior basics.
- New munitions.
- Tactical Center use.
- Strategic spawns.
- Optional mods / client-side QoL if appropriate.
- Commander interactions.
- Logistics/repair/rearm where relevant.

---

## 15. Current owner wishes — nudge system and player-AI interaction

Earlier backlog includes:

- Nudge system.
- Request help.
- Request taking a town.
- Commander roles: capture towns, support players, harass.

Interpretation:

- This may become part of the repurposed Team menu or another WF menu surface.
- It should not reveal hidden intel.
- It should let players influence AI in a lightweight way without micromanaging the whole war.

Research first:

- Existing command/request UI.
- Existing AI target assignment.
- Existing player commander requests.
- Current menus where such commands could live.

---

## 16. Stats V2 / telemetry / website-bot integration

Direction:

- Stats V2 should make match and performance data durable and useful.
- Website/API/DB own ingest and persistence.
- Bot consumes DB/outbox, not raw RPT for new match features.
- Admin gets sensitive performance/telemetry tools.
- Players get safe public stats and leaderboards.

Required split:

Player-facing:

- Leaderboards.
- Balance.
- General kills/deaths/captures.
- Kill matrix / what killed what.
- Match history where safe.

Admin-only:

- Commander decisions.
- Performance per patch.
- Server FPS / HC FPS / group health.
- Ingest freshness.
- Detailed telemetry.
- Potential hidden enemy activity.

Stats should support future tuning:

- Number of groups.
- Number of AI.
- Player limits.
- Server performance per patch.
- AI commander effectiveness.

---

## 17. PR sequencing recommendation

Do not try to one-shot all code at once. One-shot the **planning and task control**, then let bounded PRs follow. The idea that one mega-PR will “finish it” is cute in the way a house fire is warm.

Recommended sequence:

### PR 0 — Control docs

- Add/update this master file.
- Add owner wishes file.
- Add active completion map.
- No runtime changes.

### PR 1 — PR queue triage

- Classify active PRs in both repos.
- Especially review AICOM V2 PRs and Miksuu CI-blocked PRs.
- Identify duplicates/superseded work.

### PR 2 — AICOM V2 owner-intent reconciliation

- Review #713 DECAPITATE against owner preference for organic base sensing.
- Decide whether to modify, split, or shelve parts.
- Update AICOM V2 migration map/brief if needed.

### PR 3 — Website content/visual design spec

- Homepage changes.
- Stats/Command Center redesign spec.
- Guides update plan.
- Hidden information matrix.

### PR 4 — Discord roles/guild structure spec

- Normal roles.
- Stats-based roles.
- Role-picker/category depth.
- Permission and CI implications.

### PR 5 — Small UI fixes batch

Potentially grouped if safe:

- Purchase units Cancel Last alignment.
- RHUD queue alignment/overflow.
- WF menu earplugs removal.
- Friendly name tags toggle check.
- Factory upgrade icons inventory.

### PR 6 — Strategic spawn marker road resolver

- Research first.
- Implement if contained.

### PR 7 — AI commander behavior research/spec

- Town-first doctrine.
- Organic base sensing.
- Softest lane.
- Air/ground response split.
- Unit composition rules.
- Logistics/stuck recovery.

### PR 8 — HC/ASR/performance audit

- Research only first.
- No architecture changes until owner approves.

---

## 18. Required PR body format

Mission PRs should include:

```md
## Summary

## Owner intent

## Scope

## Files changed

## Flag name + default
If no flag, explain why.

## Why flag-off is inert
If applicable.

## Validation
Commands run and results.

## Mirrors
Chernarus/Takistan/Zargabad handling.

## Risks

## Rollback

## GUIDE-REV
GR-2026-07-03a
```

Website/bot PRs should include:

```md
## Summary

## Owner intent

## Scope

## Files changed

## Data/privacy impact

## Activation steps
If runtime setup is needed.

## Tests / CI

## Risks

## Rollback
```

---

## 19. Final grading rubric

Every completed task should be graded before final output.

| Category | Points |
|---|---:|
| Owner intent preserved | 25 |
| Scope controlled | 15 |
| Correct source files found | 15 |
| Tests/validation credible | 15 |
| Performance/fairness risk addressed | 10 |
| Docs/PR body clear | 10 |
| No forbidden assumptions | 10 |

Minimum acceptable grade:

- Docs/copy: 85/100.
- Website UI: 88/100.
- Mission UI: 90/100.
- AI commander / HC / ASR / telemetry: 95/100.

If below threshold, fix before handing off.

---

## 20. Immediate first task for Agent A

Agent A should start by producing an **Active Completion Map**.

Required sections:

1. Open PR queue status for `a2waspwarfare`.
2. Open PR queue status for `miksuus-website-discord-bot`.
3. AICOM V2 conflict summary: current PR #713 behavior vs owner organic base-sensing preference.
4. Website overhaul task map.
5. Discord roles task map.
6. Game UI/HUD fix task map.
7. Owner questions that must be answered before implementation.
8. First three task packets for Agent B.

Do not implement before this map exists.

---

## 21. Immediate first task for Agent B

Agent B should wait for Agent A's first task packet. If Agent B is started first, it should only do read-only reconnaissance and produce:

1. Files likely relevant to strategic spawn markers.
2. Files likely relevant to RHUD/factory queue.
3. Files likely relevant to Team menu.
4. Files likely relevant to AI commander base targeting / #713.
5. No edits.

---

## 22. Owner question queue for later

Do not ask all at once. Ask one at a time when needed.

High-value questions:

1. What final name should replace “War Room”: Command Center, Stats, Operations, or another name?
2. Which stats should be public versus admin-only?
3. What maps count as “all four” for the public stats/map views?
4. For AI base sensing, is 3 km correct, or should it vary by map/terrain/unit type?
5. Should AI base sensing require prior player sighting, AI line-of-sight, proximity only, or some combination?
6. What should happen when an AI group senses the enemy base: probe, attack factory, attack HQ, call support, or ignore unless strong?
7. Should air units be allowed to attack base assets organically, or only defend/support lanes?
8. What should replace the Team menu if the owner rejects standard team-management options?
9. Is the “Scout/SCUD” report definitely SCUD?
10. Which Discord stats-based roles should exist, and should opt-out users be excluded?

---

## 23. Absolute do-not-do list

Do not:

- Deploy live.
- Build a second strategic marker system.
- Make AICOM omniscient about enemy base location.
- Merge #713 without reviewing owner organic-base-sensing preference.
- Reveal live tactical enemy intel on public website or Discord.
- Rewrite Team menu into filler just to fill space.
- Touch HC architecture without owner approval.
- Nerf GUER volume.
- Add Arma 3 syntax.
- Claim tests passed if not run.
- Hide CI red under optimistic wording.

End of control file.


---

# Addendum A — pxpipe context policy (owner-provided 2026-07-05, appended at repo placement)

## Instruction changelog entry
Date/time: 2026-07-05 (repo placement)
Changed by: Agent A (Claude/Fable, Main PC session)
Reason: Owner supplied a pxpipe context policy + builder rule alongside the handoff; appended verbatim so both agents inherit it.
Old ambiguity: none (new policy)
New rule: see below
Owner approval needed: no (owner-authored)

## pxpipe context policy
This run may include very large starting context through pxpipe. Treat pxpipe-rendered/image context as orientation, not byte-authoritative evidence.
Use imaged context for: project history; PR intent; wiki information; edge information; old chat decisions; RPT/log themes; broad architecture; telemetry and stats design background.
Do not use imaged context for: exact file paths; exact function names; exact classnames; exact flag names; SHAs; line numbers; code snippets; patch hunks; env values; secrets; final acceptance criteria.
Before any edit or final claim:
1. Re-open the exact source file / PR / RPT / doc as text.
2. Verify the exact string or fact.
3. Record the verified source in the active completion map.
4. If verification fails, stop and ask owner or mark UNKNOWN.
If a subagent must perform byte-exact work, route that task through a non-imaged/pass-through context or explicitly re-read all inputs as text.

## pxpipe builder rule (Agent B)
You may inherit large imaged background context. Do not edit from memory. Do not edit from image recall.
For each task packet: list exact files to inspect; read each file as text before changing it; search for exact symbols as text; produce a small evidence block before implementation; implement only after evidence is confirmed; run relevant lint/tests; self-review final diff against owner intent.
Any exact value remembered from context must be treated as suspect until re-read from source.
