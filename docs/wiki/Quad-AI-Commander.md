# Quad AI Commander Concept

This page indexes `origin/codex/quad-ai-commander` head `3179be6d`. It is a **future design sketch**, not current stable mission behavior.

Use [AI commander autonomy audit](AI-Commander-Autonomy-Audit) for source-backed status. Stable `origin/master` still has partial AI commander state and workers, but no proven full autonomous commander loop. `origin/feat/ai-commander` is the current branch-level revival attempt. Quad AI Commander is a separate idea for an intelligence/log-driven command layer.

## Concept

Quad AI Commander proposes a readable AI battle-staff layer for Wasp Warfare:

1. Units, commanders and intel scripts write operational log lines.
2. A parser extracts contacts, locations, counts, timestamps and sources.
3. A context store merges reports into contact beliefs.
4. Confidence decays over time as sightings go stale.
5. The commander chooses scout, defend, attack, retreat or support-fire orders from those beliefs.
6. Orders and results are written back into the same log stream for debugging and tuning.

## Why It Is Interesting

The key design value is uncertainty. Instead of giving AI perfect map knowledge, the system could act from partial reports, fuzzy scripted intel and stale sightings. That makes decisions easier for humans and future agents to inspect: the log explains what the commander believed and why it issued an order.

## Minimal First Version

A safe first version would be advisory/debug-visible only:

- field sighting logs from known events;
- fuzzy scripted intel logs;
- contact merging by nearby location and type;
- confidence decay for stale reports;
- basic suggested orders, not automatic forced execution;
- debug output that shows source, confidence and selected recommendation.

## Current Implementation Status

| Piece | Status |
| --- | --- |
| Stable master support | Not implemented as this concept. |
| `feat/ai-commander` relation | Adjacent but separate: that branch adds a supervisor/workers/order executor, not this log/intel context store. |
| Branch source | `origin/codex/quad-ai-commander:wiki/Quad-AI-Commander.md` at `3179be6d`. |
| Recommended use | Treat as product/design input for a future AI commander research branch. |

## Risks Before Implementation

- Do not feed logs directly into server authority effects without validating requester, side, team and target state.
- Keep Arma 2 OA SQF constraints in mind; avoid importing Arma 3-style event systems or scheduler assumptions.
- Start as observer/advisor output so bad belief merging cannot move player teams or spend resources.
- Make JIP behavior explicit: late joiners need enough replicated state to understand current AI orders if the feature becomes visible to players.

## Continue Reading

Previous: [AI commander autonomy audit](AI-Commander-Autonomy-Audit) | Next: [AI runtime / HC loop map](AI-Runtime-HC-Loop-Map)

Related: [Feature status](Feature-Status-Register) | [Server authority map](Server-Authority-Migration-Map) | [Current source status](Current-Source-Status-Snapshot)
