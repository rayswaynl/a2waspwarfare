<!-- source: Agent-Guide GUIDE-REV GR-2026-07-06a -->
# Agent skills pack

| Skill | One-liner |
|---|---|
| [sqf-edit-guard](sqf-edit-guard/SKILL.md) | Load before touching any `.sqf`/`.fsm`/`.hpp` under `Missions/**` — banned commands, semantics traps, CRLF-safe Python editing, post-edit gates. |
| [mirror-regen](mirror-regen/SKILL.md) | Run after any Chernarus mission edit, before staging — LoadoutManager mirror, template restore, per-map spot-checks. |
| [pr-preflight](pr-preflight/SKILL.md) | Load before `git push` / `gh pr create` — claim checks, shelved registry, flag-policy audit, gates, draft-PR body, evidence wording. |
| [rpt-triage](rpt-triage/SKILL.md) | Load when diagnosing live/soak/boot behavior — log routing (HC vs server vs client), MISSINIT windowing, analyze_soak grading, token vocabulary. |
| [a2oa-verify-command](a2oa-verify-command/SKILL.md) | Load when unsure a command/semantic exists on OA 1.64 — wiki-first verification ladder up to an offline engine probe. |

**Rule:** these skills CONDENSE AND LINK the repo wiki
(`https://github.com/rayswaynl/a2waspwarfare/wiki/<Page>`); they never fork it. The wiki
Agent-Guide is canonical — on any GUIDE-REV bump, re-diff every skill against the guide
and update the `source:` stamp at the top of each file.
