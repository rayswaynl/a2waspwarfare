# AI Commander Team Lifecycle Deep Dive

**Scope:** founding, refill, attrition, retreat-and-reform, and retirement for
WASP Warfare's Arma 2 OA AICOM teams. This is game-mechanic analysis of Steff's
own community mission; no live server state was changed.

**Evidence snapshot:** source is `origin/master` at `bcd35dbb47` (2026-07-26).
The live-box reads below were read-only and windowed to the last `MISSINIT` on
2026-07-26. The incident figures in the task brief are retained as the historical
dbg0726g observation; they are not presented as a measurement of the later live
window.

## Executive finding

The historical 210 retreat-and-reform orders in 20 minutes were **not normal
attrition**. A lone, distant survivor entered a loop where a refill was only
possible at a friendly rally/parked position or after reaching home, while the
survivor could fail to path home. That is a real liveness failure, and it also
made a side-AI cap capable of amplifying the failure: the remnant counted toward
the cap while it could not be refilled in the field.

Current `master` contains targeted lifecycle guards that address that former
loop: bounded retreat reissues, a merge-or-cull terminal action, and a separate
HC-local top-up consumer. The current live window also shows 11 completed
top-ups across the four HC logs and no retreat orders. This is encouraging, but
the deployed build's legacy/v1 top-up telemetry does not expose the original
v2 team-census/retirement fields, so it is not a full regression proof for the
dbg0726g observation.

## Lifecycle model

1. `AI_Commander_Teams.sqf` chooses a template and pads normal infantry/light
   templates to the configured found size before HC dispatch
   (`AI_Commander_Teams.sqf:1151-1180`). The Zargabad source override is now a
   16-team cap and 10-unit min/max (`Init_CommonConstants.sqf:1090-1093`,
   `2224-2252`).
2. HC-founded teams receive `wfbe_teamtype`, allowing later disband selection
   (`AI_Commander_Teams.sqf:1576-1588`), and founding emits `TEAM_FOUNDED`
   (`1602`).
3. A team under six live units may receive an HC-local top-up request only when
   non-combat and rallying/parked near HQ or an own town. The request is capped
   by remaining side-AI headroom (`AI_Commander_Produce.sqf:139-231`, especially
   `145-165`).
4. The owning HC consumes that request, defers only for nearby real players,
   creates at most four units per tick, refunds failures/stale requests, and
   clears the request (`Common_RunCommanderTeam.sqf:2957-3055`).
5. A lone survivor beyond home range is ordered home. If it stops making
   meaningful progress, exceeds an absolute reissue budget, or is already too
   distant after one issue, it is merged into an eligible nearby server-local
   team or culled (`AI_Commander_Produce.sqf:269-405`).
6. Strategic retirement has two independent selectors: PC-scale retirement when
   `founded > target` (`AI_Commander_Teams.sqf:365-388`) and low-tier/weak-team
   retirement after mobile force exists and the foot-team floor allows it
   (`AI_Commander_DisbandLowTier.sqf:16-91`). Both flag the HC-local executor;
   neither is an immediate server-side group deletion.

## Findings, ranked by gameplay impact

### P0 — historical stranded-survivor loop was a real deadlock; current master has a terminal path

**Evidence.** The historical dbg0726g sample reported 210
`retreat-and-reform ordered` events in 20 minutes, including `alive=1`, while
founding was blocked by `FOUND_SKIP reason=side-cap`. The source explains the
mechanism directly: field refills are suppressed until a team is home or near
an owned forward town (`AI_Commander_Produce.sqf:407-423`); the old distant
one-man team therefore could be repeatedly sent home without becoming eligible
to refill. The current guard records both no-progress `tries` and monotonic
`issues` (`269-307`), then merges or culls (`324-367`) rather than issuing an
unbounded order (`371-393`).

**Verdict.** Broken loop historically, not normal combat attrition. `tries`
means consecutive reissues without at least `WFBE_C_AICOM_RETREAT_MIN_CLOSE`
(50m default) progress; `issues` is the absolute reissue counter and does not
reset on progress. The logs already include the group string, so the original
incident can be grouped by that identifier. The current v2 `REFIT_START` event
also names the group (`386-390`).

**Concrete proposal.** Do not add another retirement rule. Soak the existing
guardrails with a per-group lifecycle chain: `REFIT_START` -> `TOPUP_DONE` or
`stranded survivor MERGED`/`retreat-thrash CULLED`. Alert if one group logs more
than eight retreat orders without one terminal event. This is an observability
addition only and needs a separate, narrowly scoped draft PR after a current
build confirms which RPT host receives every event.

### P1 — the side cap can still delay refill, but is no longer an unbounded deadlock in source

**Evidence.** The founding gate counts all living non-player side units and
returns at `sideAI >= tierCap` (`AI_Commander_Teams.sqf:411-435`). The top-up
dispatcher uses `_capRemaining` and will not request more bodies when it is
zero (`AI_Commander_Produce.sqf:164-165`). Thus a one-man team does count against
the same cap that can prevent its refill.

The historical `sideAI 202 >= tierCap 180` was therefore sufficient to block
new teams and top-up capacity. Current Zargabad source explicitly raised the
cap vector to `[180,170,150,120]` and the team cap/PC curve to 16
(`Init_CommonConstants.sqf:2224-2236`). More importantly, P0's cull/merge path
removes a permanently stranded remnant, freeing headroom instead of retaining
it forever.

**Verdict.** This is cap pressure, not a second independent bug. It becomes a
deadlock only when the historical non-terminal retreat loop is present.

**Concrete proposal.** Keep founding and top-up under the same side cap; do not
special-case a refill to breach it. Add a rate-limited `CAP_RECLAIM` diagnostic
when a cap-blocked side contains a one-man refit/retreat candidate, logging its
group, cap, and chosen terminal action. That gives an operator a direct proof
that cap headroom was reclaimed without silently increasing live population.

### P2 — `TEAM_RETIRED=0` is expected for the PC-scale selector, but not sufficient by itself to prove healthy recycling

**Evidence.** PC-scale retirement fires only if `_foundedTeams > _target`
(`AI_Commander_Teams.sqf:371-388`). With the historical target frozen at 16 and
founded teams below 16, zero `TEAM_RETIRED|reason=pc-scale` is correct: that
selector intentionally cannot run. The separate low-tier selector also needs a
mobile force, an eligible HC-owned idle candidate, and foot teams above its
floor (`AI_Commander_DisbandLowTier.sqf:33-80`), so it can legitimately produce
zero retirements in a short combat-heavy sample.

**Verdict.** Zero retirement was expected from PC cleanup in the cited window,
not proof that the selector failed. It did leave the historical loop without a
prompt cleanup route; P0 now supplies that route.

**Concrete proposal.** Preserve the existing policies, but emit one
rate-limited `RETIRE_SKIP` reason when a selector is evaluated but rejects all
candidates. It should distinguish `target-not-exceeded`, `no-mobile-force`,
`foot-floor`, and `no-eligible-hc-team`; this prevents another ambiguous zero.

### P3 — current intended founding size is 10 for normal teams; the older 6.4–9.1 mean was under-strength evidence

**Evidence.** HC teams bypass the server-local Produce refill path, which is
why founding pads normal templates before dispatch (`AI_Commander_Teams.sqf:1151-1180`).
`WFBE_C_AICOM_TEAM_SIZE_MIN` and `MAX` both resolve to 10 for normal teams
(`Init_CommonConstants.sqf:1090-1093`); MBT and attack-heli templates are
explicitly exempt. A later server registration from the current live window
also recorded a newly registered HC team with nine units, which is a live
exception worth tracking rather than treating as proof of the normal template
target.

**Verdict.** The earlier 6.4–9.1 mean was below the intended regular-team size
and supports the original under-strength concern. It is not by itself proof
that every team *founded* under-strength: attrition and exempt vehicle teams
also lower a mean.

**Concrete proposal.** Extend `TEAM_FOUNDED` with `plannedSize` and add an
HC-side `TEAM_REGISTERED` field for actual initial live count. Compute the mean
only per class (infantry/light versus MBT/attack-heli), then compare founded
size, current size, top-up success, and retirement outcome separately.

## Read-only live-window check (2026-07-26)

All four HC RPTs were scoped from their last `MISSINIT` markers. The current
window had no `retreat-and-reform ordered` records and reported completed topups:

| HC log | Window lines | `TOPUP_DONE` | Examples |
| --- | ---: | ---: | --- |
| HC1 | 7,582 | 2 | EAST `O 1-2-K` +2; WEST `B 1-3-D` +4 |
| HC2 | 8,012 | 2 | WEST `B 1-2-H` +4; WEST `B 1-1-I` +4 |
| HC3 | 7,568 | 5 | EAST/WEST requests, including +2, +3 and +4 |
| HC4 | 7,857 | 2 | EAST `O 1-3-E` +1; WEST `B 1-3-L` +2 |

The server tail also showed a new HC commander team registered with nine units
at minute 61, and HC2 reported `units=76|groups=16`. These observations show
the present round has live teams and the HC consumer is executing; they do not
replace an after-deploy run of the original v2 telemetry contract.

## Recommended acceptance run

On the next dbg build, retain only the current lifecycle code and collect the
last-MISSINIT server plus all four HC windows for 30 minutes after AI reaches
the side cap. Accept the lifecycle only if:

- no group has more than eight `retreat-and-reform ordered` events without a
  `TOPUP_DONE`, merge, or cull terminal event;
- every `TOPUP_REQ` has a `TOPUP_DONE`, partial refund, or stale refund inside
  300 seconds;
- a cap-blocked side logs either successful top-up or terminal reclamation for
  any one-man candidate; and
- founding telemetry records planned and actual initial team size by class.

No small safe code fix is shipped with this report because the historical
failure's terminal lifecycle safeguards are already present in `origin/master`.
The next safe change is the proposed diagnostics, after the current deployed
build's RPT routing is verified.
