# AICOM V2 B69 Consolidated Brief

Source status: B69 wiki pages and `git diff master origin/claude/b69` were not reachable in this sandbox after error 206. This brief consolidates the 15 required recommendation slots into a V2-ready classification table using loaded journal/roster evidence. Rows marked VERIFY must be source-confirmed before implementation.

## Classification Legend

| Class | Meaning |
|---|---|
| A | Already in master; do not re-propose except as V2 port. |
| B | Branch-only; blocked or unsafe until fixed. |
| C | Open V2 candidate; precise final-form change needed. |
| D | Rejected; do not rebuild. |

## Fifteen-Item Matrix

| # | Recommendation | Class | Evidence/status | V2 final form |
|---:|---|---|---|---|
| 1 | Infantry founding pad | A | B57 deployed and runtime-confirmed padding to floor. | Port as `TeamPad(snapshot, template) -> paddedTemplate`; log `TEAM_FOUNDED|v3` with pad stamp. |
| 2 | Retreat and reform depleted teams | A | B57 adopted from `feat/aicom-fleet-improvements`. | Retain. Add depleted-team merge event and no top-up for disbanding teams. |
| 3 | Last-stand mode | A | B57 adopted and persisted `wfbe_aicom_strat_mode`. | Retain as posture state with map-profile gates. |
| 4 | HQ-strike order | C | B57 adopted partial package; roster requires collapsing duplicates. | Implement only as atomic order/gate/picker package. No standalone HQ order. |
| 5 | HQ-strike gate | C | B57 used 8-town gate; exact constant name VERIFY. | Gate fields: enemyTownCount, ownTownCount, HQKnown, routeReachable, cooldown. |
| 6 | HQ-strike picker | C | Three reasons for dead HQ-strike remain in failure catalog. | Picker chooses eligible assault-capable teams with superiority and reachable route. |
| 7 | HC merge/failback | C | Roster asks for HC merge path and gaps. | Server owns merge decision; HC only reports depletion/arrival. No automatic failback without owner-generation fencing. |
| 8 | West infantry fallback | C | Required new v3 event. | If WEST cannot found intended team for N ticks but has funds and group headroom, found fallback infantry and log trigger. |
| 9 | Reactive CBR/base defense | VERIFY | Mentioned in migration lane, source pending. | Port only if it is not fire-and-forget static-defense. |
| 10 | Bootstrap stipend | A | Lane 356 aligned sentinel and windfall telemetry. | Keep; add hoard+lose watchdog. |
| 11 | Adaptive spend | C | Doctrine says money is pressure; hoards are bugs. | Spend-rate floor keyed to posture; alarm if funds grow while losing ground. |
| 12 | Capture-phase interrupt | C | Required in migration map; failure catalog names capture while-loop. | Add bounded interrupt with order sequence check; no unbounded `while` or `waitUntil`. |
| 13 | MHQ relocation ladder | C | 43/43 aborts traced to 600m ring-clear in roster. | Replace pure ring-clear with utility score, escort, and abort TTL. |
| 14 | Wildcard pulse | C | Doctrine "no dead air"; wildcard deck exists. | Escalation director emits visible events within max gap, with intel-honest WHY. |
| 15 | Branch bootstrap/init copies | D | B57 explicitly skipped stale `initJIPCompatible` and `Init_Towns` due sleep trap. | Never copy. Port only isolated A2-safe functions after symbol and wait audit. |

## Atomic HQ-Strike Package

The HQ-strike feature is one unit with three required parts:

| Part | Required behavior |
|---|---|
| Gate | Side can consider HQ strike only when enemy has enough towns, own posture is not emergency collapse, HQ target is known by legal intel, route is reachable, and cooldown expired. |
| Picker | Choose assault-capable team bundle with local superiority and enough fuel/reach. Do not send one depleted team. |
| Order | Emit a distinct objective record `{type:"HQ_STRIKE", targetSide, targetPos, teamIds, seq, reason}`; HC gets only move/attack execution payload. |

Dead HQ-strike causes to prevent:

| Cause | Prevention |
|---|---|
| Gate opens but no picker finds teams | Emit `HQ_STRIKE_ABORT|no_eligible_force` and stay in pressure posture. |
| Picker chooses teams without route/reach | Planner must precompute reachability from map profile. |
| Order is not visible to execution loop | Order record has sequence, target, and explicit team list; analyzer expects dispatch token. |

## B74.x / Cmdcon Delta Guard

Before adding any B69 item:

1. Diff `master..origin/claude/b69`.
2. Diff B74.1/B74.2/cmdcon branches against current master for the same files.
3. If the idea already exists under another name, classify A and write only the V2 port mapping.
4. If the idea was reverted, classify B or D and copy the revert reason.

## Open V2 Candidates

| Candidate | File/home layer | Gate | A2 safety argument |
|---|---|---|---|
| HQ-strike atomic package | Planning + execution adapter | V2 master flag, HQ gate constant default profile | Arrays/strings/numbers only; no A3 commands. |
| Spend-rate floor | Assessment/build planner | V2 master flag | Pure arithmetic over funds/supply; no group locality. |
| MHQ relocation utility | Planning + execution adapter | V2 master flag and relocation cooldown | Bounded loops only; no `sleep`-based bootstrap waits. |
| Capture-phase interrupt | Execution adapter | Sequence mismatch or enemy flip | Uses order sequence guard to avoid stale HC action. |
| Wildcard pulse director | Planning/escalation | Visible-event gap and legal intel event | No psychic decisions; WHY log cites observable. |
