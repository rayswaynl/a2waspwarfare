# AI combat and movement behaviour deep dive — 2026-07-26

## Scope and evidence

This is a read-only investigation of the live Zargabad `dbg0726g` match, windowed to its last `MISSINIT` (about minutes 0–105), plus the current `origin/master` source tree. It covers player-visible AI movement, combat and vehicle behaviour; it does not change the commander-team lifecycle lane, deployment, or the separately owned Balota spawn issue.

Live inputs were the server RPT and HC1–HC4 RPTs on the task box. Static references below are to the Chernarus source, whose equivalent paths are generated for the two mirrors. The RPT proves events happened; it does not, on its own, prove a player saw a particular squad at a particular time.

## Executive verdict

AI is not globally idle: the match contains 19 recorded successful assaults, road-biased patrol dispatches, active patrol-unstuck events and a functioning orphan healer. The player-visible problem is **poor movement conversion under pressure**: the server reached `disp=133`, `arrv=17`, 19 `ASSAULT_STRANDED` events and two abandons by the minute-101 scale sample. Several groups repeatedly timed out far from their targets, and patrol recovery repeatedly retriggered for the same groups.

Do not tune ASR skill/accuracy or tighten a recycle threshold from this sample. The RPT has no per-engagement hit, casualty, target, or ASR-setting telemetry to support that causal claim. The first safe change is outcome correlation, followed by a focused movement fix only after its evidence identifies a failing class.

## Ranked findings

### P0 — Assault orders frequently do not convert into arrivals

**Player effect.** Players can watch multiple friendly AI groups head toward the same objective, then remain absent from the fight or recycle rather than reinforce it. This reads as a stalled offensive, not merely slow AI.

**Evidence.** The server's minute-101 `WASPSCALE` reports `disp=133`, `arrv=17`, `aband=2`; the current window contains 19 `ASSAULT_ARRIVED` and 19 `ASSAULT_STRANDED` records. Concrete traces:

- `B 1-3-E` arrived at Hazar Bagh in 241 s (minute 16), later stranded 4,051 m from Shahbaz after 851 s, then arrived at Zargabad AF in 245 s (minute 101).
- `O 1-3-C` stranded three times: Yarum (30 m moved, `stuck=true`), Shur Dam (24 m, `stuck=true`), then Zargabad AF (59 m).
- `B 1-2-I` stranded at minutes 65, 79 and 97; its final record moved only 43 m in 860 s and was classified `stuck=true`.

The timeout path already records destination distance, elapsed time, displacement, and a `stuck` classification in `Server/AI/Commander/AI_Commander_AssignTowns.sqf:162-170`. Successful arrivals are recorded in the same file at `:106-116`.

**Proposed next change.** Add one bounded, machine-parsed terminal record per dispatch ID: `DISPATCH_OPEN`, then exactly one of `ARRIVED`, `STRANDED`, `RECOVERED`, `RECYCLED`, or `ABANDONED`, including vehicle class, mounted state, route type, target town, initial distance, final distance and recovery tier. Keep this telemetry-only and flag-off until a short Zargabad soak identifies whether the dominant failure is foot pathing, mounted convoy pathing, combat interruption, or retry policy.

### P1 — Stuck recovery exists and fires, but its outcome is unobservable and repeat patrol failures remain

**Player effect.** A patrol can look like a unit milling around an area while recovery pulses repeatedly; the current logs cannot tell whether the pulse restored useful movement.

**Evidence.** The current window has 4 server `UNSTUCK_STRIKE` records, 4/4/1 HC `UNSTUCK_FIRED` records, and at least 14 + 30 + 7 `PATROL_UNSTUCK` records on HC1–HC4. Repeated examples include `O 1-3-K` (HC1 at minutes 58 and 60; later recovery tiers 1 and 2) and `B 1-4-B` (HC2 at tiers 1, 2, 3 and 3). `O 1-1-L` repeatedly received retreat-and-reform orders while its distance declined from 5,601 m to 3,566 m, then was culled after 14 issues; it also had an unstuck strike and stranded at Nango.

The branch contains both a 210-second movement watchdog and a one-shot strand-recovery path (`AI_Commander_AssignTowns.sqf:471-476`, `:867-900`). Patrol order construction itself is live and cyclic: `Server/AI/Orders/AI_Patrol.sqf:31-111` creates road-biased ground routes or cycle waypoints.

**Proposed next change.** Extend the P0 terminal correlation with `recoveryIssuedAt`, `recoveryTier`, and the next 60/180-second displacement-to-target delta. Do not increase teleport/recycle aggression until that trace shows the existing recovery cannot work; it would otherwise turn a visible milling problem into player-visible disappearing squads.

### P2 — Empty-group churn is real across all HCs, but the current cleanup telemetry does not identify its producer or prove deletion

**Player effect.** This is mostly an operational quality issue today, but sustained churn competes with the group cap and eventually presents as AI failing to spawn.

**Evidence.** Server `GCSTAT` ran for 104 passes and ended with `reaped=12|emptyFound=18`; HC cleanups repeatedly reported 4–15 reaps while 5–19 local empty groups remained. The same current window shows `prevConfirmedGone=0` on the sampled HC cleanup records, so the logs do not demonstrate that a prior local delete became globally absent. The server source already uses a collect-then-delete pass to avoid mutating `allGroups` in place (`Server/FSM/server_groupsGC.sqf:31-58`), while the client emits cleanup counters at `Client/Functions/Client_GroupsGC.sqf:97-108`.

**Proposed next change.** Before changing deletion behavior, add a stable group provenance tag at creation (commander, town, patrol, vehicle crew, cleanup) and one two-pass result record: candidate ID + origin, `deleteGroup` issued, and next-pass absence/persistence/locality result. This will distinguish legitimate combat-created transient groups from a no-op/locality leak. No code PR is included here because the overlapping RPT-sweep and lifecycle lanes already own nearby cleanup behavior.

### P3 — Vehicle abandonment is observed, but the empty-vehicle collector cannot currently demonstrate its terminal handling

**Player effect.** Abandoned armor/artillery can make the battlefield look wasteful and leave objectives cluttered; it also masks whether crews are sensibly using vehicles or merely discarding them.

**Evidence.** The server records 19 abandonment-related lines, including a BTR90 and GRAD_RU being enrolled by `aicom-vehicle-abandoned`. Yet all 105 sampled `emptyvehiclescollector` performance records report `queued:0;handled:0`, even as vehicle count rises from 28 to 248. The collector only queues vehicles that meet its empty predicate and passes them to `Server_HandleEmptyVehicle` (`Server/FSM/emptyvehiclescollector.sqf:14-34`). Separately, the base GC explicitly acknowledges that crewed idle hulls can keep the empty-vehicle timer reset and therefore must be addressed by a different path (`Server/FSM/server_groupsGC.sqf:59-77`, `:272-275`).

**Proposed next change.** Add a terminal ledger keyed by vehicle net/object identity: `abandoned-enrolled`, `empty-eligible`, `HandleEmptyVehicle-start`, `deleted`, `kept-crew`, `kept-player-near`, or `basegc-deleted`. This resolves the apparent counter mismatch without altering vehicle deletion policy.

### P4 — Same-destination orders are intentional convergence, but need a live proof that route staggering is working

**Player effect.** Multiple teams visibly sharing the same town coordinate can look like a blob. It is not by itself a bug: that coordinate is the assault objective.

**Evidence.** The server logged 53 `executing move order` lines, including several WEST teams aimed at `[2823.53,5022.13,0]`. The source deliberately separates routes with a persistent lane offset (60 m on Zargabad) and enables wave-order staggering by default (`Common/Init/Init_CommonConstants.sqf:85-91`, `:419-423`; `AI_Commander_AssignTowns.sqf:1112-1129`, `:1155-1158`). The current RPT does not expose the calculated delay or lane choice, so it cannot confirm that the anti-blob mechanisms applied to the observed order cluster.

**Proposed next change.** Emit a single `WAVE_ORDER` line only when multiple teams share a target, with target, team, lane offset, delay and route-hop count. This is evidence-only; do not raise stagger delays or offsets until it proves a real same-road convergence.

### P5 — Combat decisiveness and ASR tuning are unproven from this evidence

**Player effect.** Ineffective firefights and retreat loops read as timid or inaccurate AI, but changing skill without a causal signal risks turning AI into unfair aimbots rather than improving movement.

**Evidence.** The server has 239 retreat-related text matches, but much of that is repeated commander-level scheduling rather than an engagement outcome. HC records include actual `SML|v1|RETREAT`, `RETREAT_REJOIN`, and `RETREAT_SKIP` examples, but no kill/exchange ratio or ASR parameter dump. Mission code sets commander-team generic skill only when supplied by the founder (`Common/Functions/Common_RunCommanderTeam.sqf:96-101`); GUER patrols explicitly set high generic/aiming skill (`Common/Functions/Common_RunSidePatrol.sqf:92-102`). The live window confirms the mission-side ASR fired-handler guard installed, but no `asr_ai_settings.sqf` was found in the task box's inspected `C:\WASP`, desktop, or documents roots. Therefore the mod's active behavior tuning was not verified.

**Proposed next change.** Treat ASR as a separately measured lever. Capture its active settings from the launched modpack path and add aggregate, non-player-facing engagement telemetry (team ID, side, start/end strength, combat duration, retreat/rejoin, and target type). Compare two controlled test rounds before changing ASR or mission skill values.

## Watchdog assessment

There is no universal “group has not moved” watchdog. There are three narrower mechanisms:

1. The assignment timeout flags a team as stuck when it has moved less than `WFBE_C_AICOM_STUCK_MOVED` (200 m) and is not in combat (`AI_Commander_AssignTowns.sqf:162-170`).
2. The orphan healer acts only after a stale HC-driver heartbeat; it has a 50 m `ORPHAN_NEVERMOVED` pad-freeze threshold, two stale sweeps, and player/combat safeguards for field retire (`Server/FSM/server_aicom_orphan_heal.sqf:1-207`; constants `Init_CommonConstants.sqf:3066-3070`). It fired in this match: the server logged `HCHEAL|...|recycle|...|reason=never-moved|...|moved=0|t=84`.
3. `STRAND_FASTRECYCLE` would double-count a stranded journey below 50 m, but it has no current-window `STRAND_FASTTRACK` event. This deep dive does not treat it as a verified active remedy.

The 50 m orphan threshold is appropriate for its narrow purpose—detecting an HC-drop team still on its pad—and is not an appropriate general movement threshold. General movement uses 200 m over a journey timeout, which is the threshold that should be evaluated with the P0 correlation data.

## Actions deliberately not taken

- No live-box mutation, restart, deploy, ASR tuning, threshold adjustment, or mission-code change.
- No duplicate Balota spawn fix, RealPlayersNear fix, RPT-sweep fix, or lifecycle work; all are already assigned/open.
- No small “safe” code fix: the evidence supports instrumentation first, and a behavior change now would duplicate or interfere with the active movement/cleanup lanes.

## Acceptance criteria for the next focused PR

1. A single dispatch/vehicle correlation key produces exactly one terminal record.
2. New records are bounded and rate-limited; no per-frame logging.
3. A 60+ minute Zargabad soak can calculate dispatch-to-arrival, dispatch-to-strand, recovery-to-arrival, abandonment-to-delete, and empty-group provenance rates.
4. No ASR or skill change is included unless the active config and a controlled comparison are attached.
5. The change remains draft-only, uses the Chernarus source and verified mirrors, and preserves the A2 OA command constraints.
