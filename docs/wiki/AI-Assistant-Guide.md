# AI Assistant Guide

Compact safety gateway for AI assistants working on A2 Wasp Warfare docs, reviews or code. The canonical boot order, load tables and task bundles live in [LLM agent entry pack](LLM-Agent-Entry-Pack) — start there. This page only carries the guardrails that prevent the common bad first moves, so they are not buried in a longer page.

For routing (live lane state, current-source truth, feature/risk triage, SQF ownership, networking, upstream archaeology, OA command safety), use the load tables in [LLM agent entry pack](LLM-Agent-Entry-Pack), [Progress dashboard](Progress-Dashboard) and [`agent-context.json`](agent-context.json). Hands-on edit rules, Arma 2 OA pitfalls and search patterns are in [AI assistant developer guide](AI-Assistant-Developer-Guide).

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

After meaningful docs or machine-file edits, run `powershell -ExecutionPolicy Bypass -File docs\validate-wiki.ps1`, parse touched JSON/JSONL, run `git diff --check`, mirror touched wiki files, inspect final diffs and keep `docs/wiki` in parity with the GitHub wiki checkout.

## Continue Reading

Previous: [Home](Home) | Next: [AI Assistant Developer Guide](AI-Assistant-Developer-Guide)

Main map: [Home](Home) | Agent pack: [LLM agent entry pack](LLM-Agent-Entry-Pack) | Risk triage: [Feature status](Feature-Status-Register)
