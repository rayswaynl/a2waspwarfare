# Wiki Improvements Proposal — 2026-07-06

<!-- GUIDE-REV: GR-2026-07-03a -->

**Author:** Fable (Agent A), `claude/fable-completion-push` session, 2026-07-06  
**Scope:** DRAFT PROPOSAL ONLY — do not publish to the live wiki without owner approval.  
**Source basis:** Discovery workflow `wf_a00082ab-7ef` artifacts on this branch:
- `docs/project-management/TELEMETRY-AND-STATS-V2-PLAN.md`
- `docs/project-management/RPT-EVIDENCE-2026-07-05.md`
- `docs/project-management/FABLE-ACTIVE-COMPLETION-MAP.md`
- `docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md`
- Local wiki clone at `C:\Users\Steff\_wasp-wiki-work`

---

## Summary

Three pages are proposed. All three fill real documentation gaps confirmed against the live wiki
(pages do not exist) and are grounded in verified session evidence.

| # | Proposed wiki page title | Hook in _Sidebar.md | Gap type |
|---|---|---|---|
| 1 | `Telemetry-Families-Reference` | Under **Content, reference and catalogs** — after the existing `AICOMSTAT-V2-Event-Vocabulary-Census` and `WASPSCALE-V2-Telemetry-Reference` entries | Missing: no single dev-facing index of all ~40 RPT prefix families, their custody, and tool consumers |
| 2 | `AICOM-V2-Cutover-Status` | Under **AI / HC** — after the existing `AI-Commander-B69-Improvement-Roadmap` entry | Missing: no page tracks the five-step cutover sequence, live reconciliation state, and pre-soak blockers |
| 3 | `RPT-Telemetry-Consumer-Port-Map` | Under **Tooling / release / integrations** — after `Testing-Debugging-And-Release-Workflow` | Missing: the cutover brief lists off-engine consumers that must port before V1 emitters retire; no wiki record of what ports where |

---

## Page 1 — Telemetry Families Reference

### Rationale

The wiki has deep coverage of individual families (`AICOMSTAT`, `WASPSCALE`) but no overview page
a developer can open to see all ~40 RPT prefix families, understand which code owns them, and know
whether they survive V2 cutover. The telemetry census performed in this session (workflow
`wf_a00082ab-7ef`, source-scanned Chernarus mission tree, `Tools/`, and box-side scripts) provides
the verified basis for this page. This page is **dev-facing only** and contains no live tactical
intel — families that would reveal current AI targeting or enemy positions are noted as
admin-only in the public/admin split.

### _Sidebar.md hook

Under **Content, reference and catalogs**, after the existing block:
```
  - [AICOMSTAT v2 event census](AICOMSTAT-V2-Event-Vocabulary-Census)
  - [WASPSCALE v2 telemetry](WASPSCALE-V2-Telemetry-Reference)
  - [WASPSCALE v2-ext coverage audit](WASPSCALE-V2-Ext-Coverage-Gap-Audit)
```
Insert:
```
  - [Telemetry families reference](Telemetry-Families-Reference)
```

### Full markdown body

```markdown
# Telemetry Families Reference

<!-- GUIDE-REV: GR-2026-07-03a -->

> Dev-facing reference. Covers all RPT prefix families emitted by the mission. No live tactical
> intel is recorded here; see the public/admin split in the Stats V2 plan for what surfaces
> on public pages vs. the admin console.

Source-verified 2026-07-05 against `origin/claude/build84-cmdcon36` Chernarus mission tree
+ `Tools/` directory. Emitter counts from workflow `wf_a00082ab-7ef` census.

All RPT telemetry is emitted via raw `diag_log` string concatenations on the **server** or
**Headless Client**, not through `WFBE_CO_FNC_LogContent` (which is compiled off on live
servers). Families below are grouped by ownership and V2 cutover fate.

---

## Verdict key

| Verdict | Meaning |
|---|---|
| **PORT** | Commander-owned; content must map to the unified V2 grammar before the old emitters retire |
| **KEEP** | Not commander-owned; format survives cutover unchanged |
| **RELOCATE** | KEEP, but the emitting file (`AI_Commander.sqf`) is shelved at step 4 — emission moves to a different host file, line format stays byte-identical |
| **ADMIN-ONLY** | Kept as-is; not exposed on any public surface |
| **RETIRE** | V1-only share of a PORT family; removed at step 4 of the cutover sequence after consumers port |

See [AICOM V2 Cutover Status](AICOM-V2-Cutover-Status) for the step sequence.

---

## PORT — commander-owned, must survive under the unified grammar

| Family | Emitters | Files | V2 fate | Tool consumers |
|---|---:|---|---|---|
| `AICOMSTAT` | **168** in 35 files | `Server/AI/Commander/AI_Commander*.sqf` (primary), `Common/Functions/Common_RunCommanderTeam.sqf`, others | Retire the V1-only share at step 4 after content maps to unified grammar. The `v2 EVENT` sub-family (74 emitters, 59 distinct event types) ports to `AICOM2|v1|` grammar. See [AICOMSTAT V2 Event Census](AICOMSTAT-V2-Event-Vocabulary-Census). | `Tools/Soak/analyze_soak.py` (3 KPI branches + generic collect); `Tools/PrTestHarness/Aicom/Score-AicomRounds.ps1` (not yet created — cutover gate); `Get-WaspRptMarkerSweep.ps1`; box-side `Update-PublicStats.ps1` |
| `AICOM2` | 39 in 5 files | `Server/AI/Commander/AICOM2_Snapshot.sqf`, `AICOM2_Allocate.sqf`, `AI_Commander.sqf` M5 | **Becomes the unified V2 base.** Grows WHY rows, INTEL families, harness-parseable enums per cutover brief. ⚠️ **Zero tool consumers today** — `analyze_soak.py` does not parse `AICOM2|`. Consumer wiring is a parity-soak prerequisite. | None yet |
| `STUCKSTAT`, `CAPDBG`, `AICOMCOMP`, `AICOMDBG`, `AICOMGATE`, `AICOMHB`, `AICOMPLACE` | ~13 total | Various `AI_Commander_*.sqf` | Content must re-emit from V2 equivalents: stuck detection, composition decisions, placement audits, version heartbeat. Drop or fold into `AICOM2|` unified grammar. | `analyze_soak.py` generic watchlist (partial) |
| `CMDRSTAT` | 3 | `AI_Commander.sqf` | PORT content; home moves to V2 supervisor loop | `analyze_soak.py` |
| `ROUNDSTAT` | 2 | `AI_Commander.sqf` | Superseded by planned `MATCH|v1|END` family | None currently |
| `AICOMSTAT FINAL` | (part of AICOMSTAT) | `AI_Commander.sqf:455` | Superseded by `MATCH|v1|END` | `analyze_soak.py` |

---

## KEEP — not commander-owned, survives cutover unchanged

### Match record bus (wire-stable — do not modify)

| Family | Emitters | Files | Consumers |
|---|---:|---|---|
| `WASPSTAT` | 5 | `Server/FSM/server_playerstat_loop.sqf` + kill pipeline | MatchReport pipeline; post-match soak scorecard. **Wire-stable — do not modify format.** See [Server Broadcast And Telemetry Loop Reference](Server-Broadcast-And-Telemetry-Loop-Reference). |
| `WASPSCALE` | 1 | `Server/AI/Commander/AI_Commander.sqf:893-988` | Soak KPI backbone incl. v2-EXT fields. Wire-stable. See [WASPSCALE V2 Telemetry Reference](WASPSCALE-V2-Telemetry-Reference). |

### groupsGC and town system diagnostics

| Family | Notes |
|---|---|
| `DELEGSTAT` | HC delegation ratio per side. Read by sweep tools. Survives unchanged. |
| `TOWNSTAT` | Town ownership snapshot per tick. Survives unchanged. |
| `EMPTYGRP` | Empty-group audit. ⚠️ Known consumer mismatch: mission emits `EMPTYGRP|v1|` but `Update-PublicStats.ps1` parses `GRPEMPTY|v1|` — dashboard gauge is silently dead. Fix the consumer on the box. |
| `GCSTAT` | Group GC audit. Survives unchanged. |
| `ORBATSTAT` | Order-of-battle snapshot. Survives unchanged. |
| `SCORE` | Per-player score events. Feeds kill/score pipeline. |
| `GUERCAP` | GUER capture events. |
| `CONTESTED` | Town contested state. |
| `BASEGC` | Base/HQ group audit. |

### Standalone system families

| Family | Emitters | System |
|---|---:|---|
| `ICBMTEL` | 19 | ICBM / nuke launch and detonation pipeline |
| `OILFIELD` | 10 | Takistan oilfields objective |
| `GUERAIRDEF` | 12 | GUER air-defense loop (Ka-137 / Mi-24 intercepts) |
| `GUERSTIPEND` | — | GUER economy stipend events |
| `GUERVBIED` | — | GUER VBIED detonation events |
| `AMBSKIRMISH` | — | GUER ambush/skirmish summary |

### HC layer

| Family | Notes |
|---|---|
| `HCSTAT` | HC self-reported fps, units, groups, time. Emitted by `Server/PVFunctions/HCStat.sqf`. |
| `HCSIDE` | HC side-assignment events. Survives unchanged. |
| `HCDELEG` | HC delegation ratio emitted by `AI_Commander.sqf`. ⚠️ **RELOCATE** — moves host when AI_Commander is shelved, line format stays byte-identical. |

### Client diagnostics

| Family | Notes |
|---|---|
| `CLIENTTEAMS` | Client team roster snapshot |
| `CLIENTROSTER` | Client player roster at JIP |
| `BUYTRACE`, `BUYFAIL` | Gear buy-menu trace and failure events |
| `CLIENTUPGRADE` | Client-side upgrade queue events |
| `FUNDS_RESTORE` | Funds restore on JIP |
| `MAPPERF` | Map-marker render performance |
| `FPSREPORT` | Client FPS self-report |
| `MODHOOKS` | Optional-mod hook registration events |
| `[WFBE][BNN]` | Bracket-tag forensic events (free-text, not pipe-delimited) |

### Boot identity

| Family | Notes |
|---|---|
| `WASPRELEASE` | Mission version and build tag at MISSINIT |
| `SELFTEST` | Server self-test results at boot |
| `TEAMREG` | Side team registration at init |
| `DAYLIGHT` | Day/night cycle state at mission start |

---

## RELOCATE — keep format, move host file

| Family | Current host | Target host | Reason |
|---|---|---|---|
| `GRPBUDGET` | `AI_Commander.sqf` (3 emitters) | `Server/FSM/server_groupsGC.sqf` | `AI_Commander.sqf` is shelved at cutover step 4. Cadence: per-side every 300 s + WARN/RECOVER edge triggers. |
| `SRVPERF` | `AI_Commander.sqf` (1 emitter) | `server_groupsGC.sqf` or standalone perf loop | Same reason. Cadence: 300 s. |
| `HCDELEG` | `AI_Commander.sqf` (part of WASPSCALE block) | Same target | Same reason. |

The transition window may carry both old and new hosts behind flag `WFBE_C_TELEM_HOST_V2` (default 0).
Brief double-emission is acceptable; any V1-only emitter still in the tree after step 4 is a review FAIL.

---

## ADMIN-ONLY

| Family | Notes |
|---|---|
| `TOWNPOS` | Coordinate dump; off-by-default extraction tool. Not exposed on any public surface. |

---

## Planned new family (Stats V2)

| Family | Status | Notes |
|---|---|---|
| `MATCH` | **Planned** — not yet emitted | Working name `MATCH|v1|`. Three record kinds: `START`, `END`, `MILESTONE`. Superset of today's `AICOMSTAT FINAL` + `ROUNDSTAT`. Volume budget: ≤ ~50 lines per match. Feeds the after-match report builder and the `/stats` Command Center. Owner confirmation required before emission. |

---

## Known defects in the current pipeline

1. **`EMPTYGRP` vs `GRPEMPTY` consumer mismatch.** Mission emits `EMPTYGRP|v1|`; `Update-PublicStats.ps1` parses `GRPEMPTY|v1|`. Dashboard gauge is silently dead. Fix: update the consumer on the box. The mission-side prefix is correct.
2. **`AICOM2|` has zero tool consumers.** `analyze_soak.py`, the marker sweep, and MatchReport all ignore `AICOM2|` lines. First consumer work item: extend `analyze_soak.py` to parse the unified grammar. This is a parity-soak prerequisite — step 3 of the cutover sequence cannot gate anything until it exists.
3. **`Score-AicomRounds.ps1` and `aicom-watch.ps1` do not exist.** The cutover brief names them as parity-soak gates. They must be created in `Tools/PrTestHarness/` and wired to the unified grammar before cutover step 3 can close.

---

## Related pages

- [AI Commander Logging And AICOMSTAT Telemetry](AI-Commander-Logging-And-AICOMSTAT-Telemetry)
- [AICOMSTAT V2 Event Vocabulary Census](AICOMSTAT-V2-Event-Vocabulary-Census)
- [WASPSCALE V2 Telemetry Reference](WASPSCALE-V2-Telemetry-Reference)
- [WASPSCALE V2-ext Coverage Gap Audit](WASPSCALE-V2-Ext-Coverage-Gap-Audit)
- [AICOM V2 Cutover Status](AICOM-V2-Cutover-Status)
- [RPT Telemetry Consumer Port Map](RPT-Telemetry-Consumer-Port-Map)
- [Server Broadcast And Telemetry Loop Reference](Server-Broadcast-And-Telemetry-Loop-Reference)
- [GLOBALGAMESTATS Extension Reference](GLOBALGAMESTATS-Extension-Reference)
```

---

## Page 2 — AICOM V2 Cutover Status

### Rationale

The cutover brief (`docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md`) is a binding program
directive living in the mission repo, not the wiki. Agents and the owner need a single wiki page
that shows: which of the five steps is current, what the verified blockers are, what the two V2
lines are and which won the reconciliation ruling, and where the migration map artifacts live. The
existing wiki has pages for individual V2 features (B69 roadmap, stuck-recovery v2, AICOMSTAT census)
but no page that tracks the cutover as a sequenced program.

### _Sidebar.md hook

Under **AI / HC**, after:
```
  - [**AI commander B69 improvement roadmap**](AI-Commander-B69-Improvement-Roadmap)
  - [AI commander B69 implementation sketches](AI-Commander-B69-Implementation-Sketches)
```
Insert:
```
  - [**AICOM V2 cutover status**](AICOM-V2-Cutover-Status)
```

### Full markdown body

```markdown
# AICOM V2 Cutover Status

<!-- GUIDE-REV: GR-2026-07-03a -->

> Tracks the five-step one-shot cutover from the V1 commander to the unified V2 implementation.
> Owner ruling: Ray, 2026-07-05. Binding source: `docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md`
> on branch `claude/fable-completion-push`.

---

## The ruling (summary)

AICOM V2 deploys **in full, at once** — not as a permanent parallel system. After cutover the old V1
commander implementation and its telemetry are **mapped, then shelved, then removed**. A single
mission-global flag (`WFBE_C_AICOM_V2_ENABLE`) governs the transition window only; it retires at
step 5. For the authoritative text see the cutover brief cited above.

---

## Five-step sequence

| Step | Name | Gate condition | Current state |
|---|---|---|---|
| **1** | Map | `AICOM-V2-MIGRATION-MAP.md` accounts for every V1 worker, constant, and telemetry emitter | **In progress** — telemetry census complete (this session); record/function mapping table outstanding |
| **2** | Cut over | One-shot build ships; V2 is the only running logic; V1 inert behind flag | Not started |
| **3** | Parity soak | N clean T3 nights; capture-rate ≥ baseline; FPS parity; zero filtered RPT errors; telemetry grammar conformance | Not started — soak-gate tools not yet created (see blockers) |
| **4** | Shelve | V1 commander files + V1-only AICOMSTAT emitters removed onto tagged branch; `Shelved-AICOM-V1` wiki record created | Not started |
| **5** | Remove | Rollback flag retires; docs re-anchor to V2-only; V1-citing wiki pages marked historical | Not started |

**Current milestone: Step 1 — Mapping.**

---

## The fork — resolved by owner ruling

Two V2 implementation lines existed before 2026-07-05:

| | Spec line (Codex pack, PRs #700–705) | Live line (PR #713, branch `fable/aicom-v2-l1`) |
|---|---|---|
| Records | `AICOMV2_*` (PullWorldState, THIRD_VIEW, …) | `AICOM2_Snapshot` / `AICOM2_Allocate` (`wfbe_aicom2_snap`, `WFBE_SNAP_*`) |
| Telemetry | `AICOMSTAT|v3` grammar (PLAN/WHY/INTEL families) | `AICOM2|v1|` family (e.g. `AICOM2|v1|DECAP`) |
| Method | Clean-room, harness-first, lanes 415–426 | Incremental milestones M0–M5 on live code |
| Validation | Acceptance harness + fixtures | Shadow-mode + live soak evidence |

**Resolution (owner, 2026-07-05):** The **live `AICOM2` machinery is the base**. It is shadow-validated
against live soak data (M0 snapshot, M1 allocator, M5 latch) and already coexists with the mission's
locality and HC constraints. The spec-pack behaviours, doctrine rules, schema discipline, WHY-row
explainability, volume protection, and acceptance harness all still bind — ported onto `AICOM2` vocabulary.

**One telemetry grammar ships.** The `AICOM2|v1|` family grows the V3 features (WHY correlation, INTEL
families, harness-parseable enums) rather than a parallel `AICOMSTAT|v3` stream.

---

## RPT evidence confirming V2 live readiness (2026-07-05)

From the 07-05 live Chernarus session (live server + HC RPT, direct reads):

- `AICOM2` telemetry is **flowing correctly**: SNAP/FISTPOOL/ALLOC/ORDER lines healthy from round
  start (46 neutral towns) through tick 820+. ASSAULT_DISPATCH active on both sides.
- `AICOMSTAT|v2` EVENT stream healthy: ECONOMY/COMBATSTAT/CAPTURE_TRACE families present.
- Server perf healthy: FPS 25–48 under 339–403 AI. `antistack_main` is the highest-cost op
  (500–600 ms/call) — known design cost, not a regression.
- GRPBUDGET well under cap (peak: west 67/144, east 47/144, GUER 44/144).
- HC delegation degraded in this session: `remotePct` fell to 21% (vs 92–95% in 07-04 sessions) with
  partial recovery to 37%. Hypothesis: GUER + server-local groups crowding the AI budget at low
  TOWNS_ACTIVE=4 / AI=403. Research packet open — no HC architecture changes without owner approval.

---

## Pre-soak blockers (must close before step 3)

| Blocker | Required action | Owns |
|---|---|---|
| `AICOM2|` has zero tool consumers | Extend `Tools/Soak/analyze_soak.py` to parse the unified grammar | Agent B / Codex |
| `Score-AicomRounds.ps1` does not exist | Create in `Tools/PrTestHarness/Aicom/`; wire to unified grammar | Agent B / Codex |
| `aicom-watch.ps1` does not exist | Create in `Tools/PrTestHarness/Ops/`; wire to unified grammar | Agent B / Codex |
| `GRPBUDGET` / `SRVPERF` emitters live in `AI_Commander.sqf` | Relocate to `server_groupsGC.sqf` (byte-identical format) before shelve — TP-4 is an approved ungated packet | Agent B |
| `AICOM-V2-MIGRATION-MAP.md` record/function table incomplete | Finish mapping every V1 worker to V2 home or deliberate drop | Cutover build lead |

---

## What happens at step 4 (shelve)

- V1 commander files move to a tagged branch (`shelved/aicom-v1-<date>`).
- V1-only AICOMSTAT emitters (those whose content was not ported to the unified grammar) are removed
  from the mission tree. Any V1-only emitter still in the tree after step 4 is a review FAIL.
- A `Shelved-AICOM-V1` wiki record is created in the established `Shelved-*` pattern (what /
  where / how-to-revive).
- GRPBUDGET, DELEGSTAT, TOWNSTAT, and the groupsGC audit families are **not** removed — they are
  not commander-owned and survive unchanged (GRPBUDGET emission moves host but keeps its format).

---

## What is sequenced after cutover

- **GUER Director (PR #715)** — approved including relief waves; sequenced after cutover stabilises
  unless the owner pulls it earlier.
- **`MATCH|v1|` match-facts family** — new telemetry planned for Stats V2; emission begins after
  the unified grammar is confirmed and the ingest pipeline is wired.
- V1-citing wiki pages marked historical at step 5; pages affected include
  [AI Commander Logging And AICOMSTAT Telemetry](AI-Commander-Logging-And-AICOMSTAT-Telemetry)
  and [AICOMSTAT V2 Event Vocabulary Census](AICOMSTAT-V2-Event-Vocabulary-Census).

---

## Related pages

- [AI Commander B69 Improvement Roadmap](AI-Commander-B69-Improvement-Roadmap)
- [AI Commander B69 Implementation Sketches](AI-Commander-B69-Implementation-Sketches)
- [AICOMSTAT V2 Event Vocabulary Census](AICOMSTAT-V2-Event-Vocabulary-Census)
- [AI Commander Execution Loop Reference](AI-Commander-Execution-Loop-Reference)
- [Headless Delegation And Failover Playbook](Headless-Delegation-And-Failover-Playbook)
- [Telemetry Families Reference](Telemetry-Families-Reference)
- [RPT Telemetry Consumer Port Map](RPT-Telemetry-Consumer-Port-Map)
- [Shelved AICOM Concepts](Shelved-AICOM-Concepts)
```

---

## Page 3 — RPT Telemetry Consumer Port Map

### Rationale

The cutover brief explicitly lists every off-engine consumer that must port to the unified grammar
**before** V1 emitters can be retired at step 4. That list lives inside a mission-repo design doc
that most agents and future contributors will not read first. The wiki has no page that names these
consumers, their current parse targets, what they must change, and the gating order. This page is a
direct dependency tracker for cutover step 3 — without it, the parity-soak gate has no written
contract agents can reference.

### _Sidebar.md hook

Under **Tooling / release / integrations**, after:
```
  - [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow)
  - [Current RPT release gate](Testing-Debugging-And-Release-Workflow#2026-07-01-pr126-release-readiness-rpt-gate)
```
Insert:
```
  - [RPT telemetry consumer port map](RPT-Telemetry-Consumer-Port-Map)
```

### Full markdown body

```markdown
# RPT Telemetry Consumer Port Map

<!-- GUIDE-REV: GR-2026-07-03a -->

> Every off-engine consumer of AICOM telemetry that must port to the unified V2 grammar before
> V1 emitters can be retired at cutover step 4. Grounded in the cutover brief
> (`docs/design/v2/AICOM-V2-CUTOVER-AND-RECONCILIATION.md`) and the 2026-07-05 tooling audit.

A consumer that is not ported **blocks step 3** (parity soak). A consumer that is not ported
or deliberately retired **blocks step 4** (shelve). Record each decision — port or retire — in
`AICOM-V2-MIGRATION-MAP.md` as work completes.

---

## Port status table

| Consumer | Location | Current parse target | Port to | Blocks | Status |
|---|---|---|---|---|---|
| `analyze_soak.py` | `Tools/Soak/analyze_soak.py` | `AICOMSTAT|v1|` + `AICOMSTAT|v2|EVENT` (3 KPI branches + generic collect). Regex `RE_V2_EVENT` at line 229–231 requires uppercase side token — misses numeric side IDs. Watchlist at lines 91–103 has 6 stale names. | Extend to parse `AICOM2|v1|` unified grammar; update side-token regex; retire stale watchlist names. | Step 3 (soak-gate scorer) | **Not started** |
| `Score-AicomRounds.ps1` | `Tools/PrTestHarness/Aicom/` | **Does not exist.** Named in cutover brief as the parity-soak round scorer. | Create; parse unified `AICOM2|v1|` grammar; output round-level KPIs comparable to V1 baseline. | Step 3 | **Not started — must be created** |
| `aicom-watch.ps1` | `Tools/PrTestHarness/Ops/` | **Does not exist.** Named in cutover brief as the live AICOM line watcher. | Create; tail RPT and display unified grammar lines in real time. | Step 3 | **Not started — must be created** |
| RPT analyzer suite | `Tools/PrTestHarness/Rpt/*.ps1` + `KnownNoise.txt` + `MissionIssuePatterns.txt` | Various V1 AICOMSTAT patterns | Review each file; add `AICOM2|v1|` patterns; update known-noise list to account for brief double-emission during transition window. | Step 4 | **Audit required** |
| `rpt-grpaudit.ps1` (box-side) | `C:\WASP\rpt-grpaudit.ps1` on livehost | Reads `DELEGSTAT|`, `GRPBUDGET|` etc. (groupsGC families) | These families survive unchanged — **no port needed** for groupsGC lines. Review for any incidental AICOMSTAT parsing. | — | **Likely no action; verify** |
| `Update-PublicStats.ps1` (box-side) | `C:\WASP\Update-PublicStats.ps1` on livehost (the :8080 stats dashboard's RPT parsing) | Reads `AICOMSTAT` for dashboard gauges. ⚠️ **Known bug:** parses `GRPEMPTY|v1|` but mission emits `EMPTYGRP|v1|` — that gauge is silently dead. | Port AICOMSTAT parsing to unified grammar; fix `EMPTYGRP` prefix at the same time. | Step 4 | **Not started** |
| WASPSCALE v2/v2-EXT analyzers | `Tools/Soak/analyze_soak.py` WASPSCALE branches; coverage doc `WASPSCALE-V2-Ext-Coverage-Gap-Audit` | `WASPSCALE|v2|` | **No port needed.** `WASPSCALE` is wire-stable and is not a commander-owned family. Coverage gaps in the existing doc are a separate improvement item. | — | **No action** |
| Wiki reference pages | `AI-Commander-Logging-And-AICOMSTAT-Telemetry`, `AICOMSTAT-V2-Event-Vocabulary-Census`, `WASPSCALE-V2-Telemetry-Reference` + any page citing V1 worker behaviour | Describe V1 grammar as current | At step 5: mark V1-specific content historical; update grammar descriptions to point at unified `AICOM2|v1|` contract. | Step 5 | **Deferred to step 5** |

---

## Gating order

The following order is required by the cutover brief:

1. **`Score-AicomRounds.ps1` created and wired to unified grammar** — gates step 3 (parity soak).
   Nothing else in the soak-gate can close without a scorer.
2. **`analyze_soak.py` extended** — also gates step 3. The scorer depends on the same grammar parse.
3. **`aicom-watch.ps1` created** — gates real-time monitoring during the transition window (steps 2–3).
4. **`Update-PublicStats.ps1` ported** — gates step 4. V1-only emitters cannot retire until the
   dashboard stops reading them.
5. **RPT analyzer suite reviewed** — gates step 4 (must not fire false errors on brief double-emission).
6. **Wiki pages marked historical** — step 5.

---

## `EMPTYGRP` prefix defect (fix at consumer, not mission)

The mission correctly emits `EMPTYGRP|v1|` (server_groupsGC.sqf). The consumer `Update-PublicStats.ps1`
incorrectly parses `GRPEMPTY|v1|`. Fix: update the parse pattern in `Update-PublicStats.ps1` on the
livehost. Do not change the mission-side prefix — it is correct and changing it would invalidate
any historical RPT analysis that used the correct prefix.

---

## Related pages

- [AICOM V2 Cutover Status](AICOM-V2-Cutover-Status)
- [Telemetry Families Reference](Telemetry-Families-Reference)
- [AI Commander Logging And AICOMSTAT Telemetry](AI-Commander-Logging-And-AICOMSTAT-Telemetry)
- [AICOMSTAT V2 Event Vocabulary Census](AICOMSTAT-V2-Event-Vocabulary-Census)
- [WASPSCALE V2 Telemetry Reference](WASPSCALE-V2-Telemetry-Reference)
- [Testing Debugging And Release Workflow](Testing-Debugging-And-Release-Workflow)
- [Tools And Build Workflow](Tools-And-Build-Workflow)
```

---

## Gap found: `EMPTYGRP` / `GRPEMPTY` silent dashboard defect

This defect is documented in the consumer port map above and in `TELEMETRY-AND-STATS-V2-PLAN.md §2`.
It does not require a new wiki page; it is already tracked as a known defect in the Telemetry
Families Reference (page 1 above) and the Consumer Port Map (page 3).

---

## What this proposal does NOT do

- Does not touch any `.sqf` file.
- Does not publish to the live wiki — all three pages are draft content only.
- Does not expose live tactical intel (current enemy positions, AI targets, active capture routes).
- Does not conflict with any existing wiki page (confirmed: none of the three titles exist in the
  local wiki clone at `C:\Users\Steff\_wasp-wiki-work`).
- Does not include A3 references.

---

## Proposed _Footer.md additions (brief)

Each new page needs a footer entry. Suggested addition to the shared footer link bar — append
in the telemetry/tools cluster:

```
[Telemetry families](Telemetry-Families-Reference) ·
[AICOM V2 cutover](AICOM-V2-Cutover-Status) ·
[Consumer port map](RPT-Telemetry-Consumer-Port-Map)
```

---

## Proposed Home.md additions (brief)

Under the **AI / Commander** route table row, add references to the two new AI/telemetry pages.
Under the **Tooling** row, add the consumer port map.

---

## Proposed Page-Index.md additions (brief)

Three one-line entries in the **Reference** and **Tooling** sections:

```
| [Telemetry Families Reference](Telemetry-Families-Reference) | All ~40 RPT prefix families, cutover verdicts, and tool consumers |
| [AICOM V2 Cutover Status](AICOM-V2-Cutover-Status) | Five-step one-shot cutover tracker with blockers and live evidence |
| [RPT Telemetry Consumer Port Map](RPT-Telemetry-Consumer-Port-Map) | Off-engine consumers that must port before V1 emitters retire |
```
