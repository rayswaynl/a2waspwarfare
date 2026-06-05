# AI Assistant Guide

Compact safety gateway for AI assistants working on A2 Wasp Warfare docs, reviews or code. Use [LLM agent entry pack](LLM-Agent-Entry-Pack) for the canonical boot order; use this page to avoid the common bad first moves.

## What this page is

- A short safety checklist before opening legacy SQF or editing docs.
- A route to current-source truth, networking authority docs, upstream-history caveats and validation rules.
- Not a replacement for reading source files before making implementation claims.

## Start Safely

| Need | Open |
| --- | --- |
| Canonical AI boot order | [LLM agent entry pack](LLM-Agent-Entry-Pack), [`agent-entrypoint.json`](agent-entrypoint.json), [`llms.txt`](llms.txt) |
| Live lane state | [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json), [`agent-events.jsonl`](agent-events.jsonl) |
| Current source truth | [Current source status snapshot](Current-Source-Status-Snapshot), [Source fix propagation queue](Source-Fix-Propagation-Queue), [`agent-release-readiness.json`](agent-release-readiness.json) |
| Feature/risk triage | [Feature status register](Feature-Status-Register), [Dead/stale code register](Dead-Code-And-Stale-Code-Register), [Pending owner decisions](Pending-Owner-Decisions) |
| SQF ownership | [SQF code atlas](SQF-Code-Atlas), [Function and module index](Function-And-Module-Index) |
| Networking/PV changes | [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) |
| Upstream/branch archaeology | [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons), [HC upstream history](HC-Upstream-History-And-Lessons), [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) |
| Arma 2 OA command safety | [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) |

## Guardrails

| Rule | Why |
| --- | --- |
| Do not infer Arma 3 behavior. | This repo targets Arma 2 OA 1.64. |
| Treat publicVariable/PVF handlers as trust boundaries. | Dispatch is transport; handler validation is authority. |
| Treat old branches and upstream archives as leads, not current truth. | Later reverts and generation drift are common. |
| Keep generated mission claims branch-scoped. | Source Chernarus, maintained Vanilla Takistan, release branches and PR branches can differ. |
| Preserve source paths, branch scope and uncertainty. | Future agents need evidence, not confident prose. |
| Do not make gameplay code changes unless Steff explicitly asks or a code-owner lane is claimed. | This docs loop is not a blanket source-patch mandate. |

## Validation

After meaningful docs or machine-file edits:

```powershell
powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1
```

Also parse touched JSON/JSONL files, run `git diff --check`, mirror touched wiki files, inspect final diffs and keep `docs/wiki` in parity with the GitHub wiki checkout.

## What this page does not own

- Networking implementation detail lives in [Networking/PV](Networking-And-Public-Variables) and [Public variable channel index](Public-Variable-Channel-Index).
- Upstream history detail lives in [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons), [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) and [HC upstream history](HC-Upstream-History-And-Lessons).
- Live source-fix status lives in [Current source status snapshot](Current-Source-Status-Snapshot), [Source fix propagation queue](Source-Fix-Propagation-Queue) and [`agent-release-readiness.json`](agent-release-readiness.json).
- Detailed feature evidence lives in [Deep-review findings](Deep-Review-Findings), [Feature status register](Feature-Status-Register) and subsystem owner pages.

## Continue Reading

Previous: [Home](Home) | Next: [AI Assistant Developer Guide](AI-Assistant-Developer-Guide)

Main map: [Home](Home) | Agent pack: [LLM agent entry pack](LLM-Agent-Entry-Pack) | Risk triage: [Feature status](Feature-Status-Register)
