# Squad Micro Layer (Commander V2) — Owner-Approved Pitch

Status: **APPROVED CONCEPT** (owner pitch, re-confirmed 2026-07-06). Build order locked: **SML-1 camp-split first**, then dismount/pickup as the foundation the air work reuses. Builds post-consolidation on the V2 lane.

## The core technique
AI teams currently move as one blob. A2 OA's engine allows ordering **individual soldiers inside a group** — `doStop` detaches a unit from formation (it STAYS in its group), `doMove` sends it somewhere, `doFollow` snaps it back. Group count and unit count never change — the two things server FPS actually depends on. Orders are one-shot engine calls; logic is event-driven on the HCs (sub-1 fps there, zero on the server).

## THE ONE HARD RULE (non-negotiable)
**Every detached unit carries a TTL watchdog** — completion, timeout, or leader death snaps it back with `doFollow`. A leaked `doStop` is a soldier frozen in a field forever, and frozen AI is the one thing we never ship. Every SML feature PR must demonstrate the watchdog covers all exit paths (including team disband/recycle and HC handoff).

## The five features
| # | Feature | What players see | Perf note |
|---|---------|------------------|-----------|
| SML-1 | **Camp-split captures** | Half the team takes camp A while half takes camp B simultaneously; two units hold center. ~Halves town capture time. **Biggest bang; build FIRST (small, self-contained).** | Net positive — faster captures |
| SML-2 | **Real dismounts** | Infantry exits into cover at a chosen drop point while the vehicle keeps moving; the truck returns for pickup later. Same choreography powers heli landings + para drops that land as a squad, not confetti. | Foundation for air work |
| SML-3 | **Graceful retreats** | Mauled individual soldiers pull back to the transport while healthy ones keep fighting. Teams degrade instead of getting wiped; disband/refit when no longer worth it. | Net positive — fewer standing units |
| SML-4 | **AT overwatch** | The launcher soldier gets positioned on the armor approach BEFORE the assault, instead of walking in formation and dying like a rifleman. | One-shot orders |
| SML-5 | **Surgical unstuck** | One wedged soldier gets nudged; the other 11 keep walking. No more full-team recovery recycles. | Net positive — cheaper recoveries |

## Integration notes (2026-07-06 program state)
- Complements (does not replace) the group-command model: commander orders teams; SML choreographs units within them. The preserved per-unit behaviors (driver-swap, smoke, get-out-&-repair from #731/#737) are siblings of this layer.
- SML-5 (surgical unstuck) should reconcile with the existing UNSTUCK ladder + the #732 press-guard + #731 in-place repair — likely reduces tier-2/3 escalations dramatically.
- SML-2 (dismounts) supersedes/absorbs the parked "dismount-at-distance preference" from the team-menu scope and connects to the micro-layer spec's EXT-4 air-insertion work.
- SML-4 pairs with the approved economy-of-force / fire-discipline extensions (AICOM-V2-UNIT-MICRO-LAYER-SPEC.md).
- All features flag-gated default 0, HC-local logic, per repo policy.

## Build sequencing
Post-consolidation, V2 lane: SML-1 → SML-2 → (SML-3/4/5 in any order, SML-5 coordinated with the unstuck stack).
