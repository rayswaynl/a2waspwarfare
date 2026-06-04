# External Research Reports

This page is the intake index for Steff-provided external deep-research reports: three PDFs from 2026-06-01 and nine Markdown reports from 2026-06-02.

Treat every report claim as a lead until it is checked against repository source or an already verified DR finding. The current verdict is that the reports are useful corroboration and planning material, but not stronger authority than the source-backed wiki.

Exact local paths, byte counts, hashes, page counts and timestamps live in [`external-research-report-manifest.json`](external-research-report-manifest.json). Raw PDF extraction cache remains local at `work/research-intake/pdf-reports`; raw report bodies are not mirrored into the wiki.

## Current Use

| Use | Route |
| --- | --- |
| Need exact report metadata | [`external-research-report-manifest.json`](external-research-report-manifest.json) |
| Need source-backed bug evidence | [Deep-review findings](Deep-Review-Findings), [Feature status](Feature-Status-Register), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) |
| Need architecture/lifecycle truth | [Architecture overview](Architecture-Overview), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Need network/authority truth | [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Server authority map](Server-Authority-Migration-Map) |
| Need release/test gates | [Testing workflow](Testing-Debugging-And-Release-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Tooling release readiness audit](Tooling-Release-Readiness-Audit) |

## Report Inventory

| Batch | Reports | Status |
| --- | --- | --- |
| PDFs, 2026-06-01 | `Analytisch rapport over rayswaynl/a2waspwarfare`, `Analyse van rayswaynl/a2waspwarfare`, `Diepgaande analyse van rayswaynl/a2waspwarfare` | Extracted and reconciled. Most useful claims overlap source-backed DRs and subsystem pages. Keep as provenance, not source truth. |
| Markdown reports, 2026-06-02 | Server authority refactor, AI onboarding/refactor playbook, runtime architecture, trust-boundary audit, feature archaeology, modernization strategy, locality/JIP architecture, testing/release workflow and gameplay/state-ownership atlas | Intake complete. Use as planning and checklist material only after repo verification. |

## Absorption Matrix

| Input | Unique value after source check | Canonical destination | Missing destination | Decision |
| --- | --- | --- | --- | --- |
| Three PDF reports | Corroborate existing findings around PVF/direct-PV risk, client-authoritative economy/construction, generated mission drift, AntiStack/Discord/Extension trust and PR #1 supply-heli hazards. Claude found the citations are mostly downstream of this wiki or upstream proxy material. | [Deep-review findings](Deep-Review-Findings), [Networking/PV](Networking-And-Public-Variables), [Construction/CoIn](Construction-And-CoIn-Systems-Atlas), [Factory/purchase](Factory-And-Purchase-Systems-Atlas), [External integrations](External-Integrations), [Current supply heli PR](Current-Work-Supply-Helicopters-PR1) | None for current behavior. Re-open only for a specific source-check target. | Keep compact metadata here; archive report prose outside the wiki. |
| Server authority refactor design | Useful staged-hardening vocabulary: server-side re-derivation, request validation, idempotency and staged migration. | [Server authority map](Server-Authority-Migration-Map), [Hardening roadmap](Hardening-Implementation-Roadmap), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) | Patch-specific design notes belong on owner playbooks only when a code lane starts. | Absorbed as roadmap input. |
| AI onboarding / safe refactor playbook | Reinforces repo-native agent entrypoints, source-first claims and validation discipline. | [Instructions for Codex](Instructions-For-Codex), [AI assistant developer guide](AI-Assistant-Developer-Guide), [Agent collaboration protocol](Agent-Collaboration-Protocol), [`agent-entrypoint.json`](agent-entrypoint.json) | No new root guide needed unless future agents find a gap not covered by `AGENTS.md`, `CLAUDE.md` and the machine files. | Absorbed; do not copy generated guide prose. |
| Runtime architecture, locality and JIP reports | Mostly match current boot/runtime/wait-chain docs. Useful as a checklist for future JIP timeout and hosted/headless reviews. | [Architecture overview](Architecture-Overview), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [AI/headless/performance](AI-Headless-And-Performance) | Specific wait-timeout or hosted/headless bugs need source-file evidence before promotion. | Absorbed; keep as checklist lead. |
| Trust-boundary hardening audit | Repeats and organizes the same major authority classes: PVF compile, SEND_MESSAGE compile, construction, purchase, ICBM, attack-wave and side-supply direct PVs. | [Deep-review findings](Deep-Review-Findings), [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Server authority map](Server-Authority-Migration-Map) | Implementation remains code-owner work; no extra research page needed. | Absorbed into canonical DR/authority pages. |
| Broken/partial feature archaeology | Useful lead list, especially for MASH/paratrooper markers, old task hooks, modded stubs and missing/disabled systems. | [Feature status](Feature-Status-Register), [Abandoned feature revival](Abandoned-Feature-Revival-Review), [Source inventory](Source-Inventory), [Wiki source consistency](Wiki-Source-Consistency-Findings) | Relaunch only for a named feature family with source refs. | Absorbed; broad archaeology prose is duplicate. |
| Testing/release workflow report | Confirms the need for explicit validation tiers, Arma smoke packs and generated-file gates. | [Testing workflow](Testing-Debugging-And-Release-Workflow), [Tooling release readiness audit](Tooling-Release-Readiness-Audit), [`agent-test-plan.schema.json`](agent-test-plan.schema.json) | New smoke packs belong on the testing page or owner playbook. | Absorbed as test-plan input. |
| Gameplay/state-ownership atlas report | Overlaps owner pages for towns, economy, commander, construction, factories and support systems. | [Gameplay systems atlas](Gameplay-Systems-Atlas), [Economy/towns/supply](Economy-Towns-And-Supply), [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Construction/CoIn](Construction-And-CoIn-Systems-Atlas), [Factory/purchase](Factory-And-Purchase-Systems-Atlas) | None unless a future pass names an unowned subsystem. | Absorbed into subsystem atlases. |
| Claude Round 34 report intake | Source-confirmed two low-level leads: generated `version.sqf` completeness and duplicate bind cleanup. Later Codex rechecked duplicate bind counts and routed the correction. | [Deep-review findings](Deep-Review-Findings#round-34--2026-06-02-claude--external-deep-research-intake-2-9-reports--dr-43-2-new-source-confirmed-leads), [Mission config/version include graph](Mission-Config-Version-Include-Graph), [Source inventory](Source-Inventory), [SQF atlas](SQF-Code-Atlas) | None currently. | Keep DR-43 as evidence; do not expand this intake page. |

## Claims To Re-Verify Before Promotion

These remain useful only as targeted source-check prompts:

| Lead | Verification target |
| --- | --- |
| `!isServer` / `!isDedicated` may be too broad for headless or hosted behavior. | Init files, long loops and UI-only actions; split real bugs from harmless locality shortcuts. |
| `waitUntil` chains without timeout can hang startup or JIP. | [Lifecycle wait-chain](Lifecycle-Wait-Chain) plus exact producer/consumer variables. |
| Town AI despawn may delete a vehicle with a player passenger. | `Server/FSM/server_town_ai.sqf` and [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety). |
| Broadcast-heavy PV delivery may be overused where targeted delivery would be cheaper or safer. | [Networking/PV](Networking-And-Public-Variables) and [Public variable channel index](Public-Variable-Channel-Index). |
| `spawn` dispatch may create ordering uncertainty for mutating flows. | Only promote after finding a concrete economy, commander, construction or supply ordering bug. |

## Agent Index Facts

```json
{
  "page": "External-Research-Reports",
  "sourceType": "external_report_intake",
  "status": "absorbed_as_leads_not_source_truth",
  "pdfReports": 3,
  "markdownReports": 9,
  "promotionRule": "Only promote claims to subsystem pages after source-file verification or a verified DR record."
}
```

## Continue Reading

Previous: [Deep-review findings](Deep-Review-Findings) | Next: [Codebase coverage ledger](Codebase-Coverage-Ledger)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
