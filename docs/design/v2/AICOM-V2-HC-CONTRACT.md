# AICOM V2 HC and Locality Contract

Source status: based on `AGENTS.md`, loaded journal evidence, and roster lane 405. Direct reads of `Server_HandleSpecial.sqf`, `Client/PVFunctions/HandleSpecial.sqf`, `Headless/Init/Init_HC.sqf`, and `Common_CreateGroup.sqf` were blocked by Windows sandbox error 206. Every invariant below is written as a builder contract; orchestrator must add exact file:line citations before publish if grading requires them.

## Core Rule

All AICOM V2 decision state lives in one server-side namespace. HC workers are executors. They may own groups locally and report execution facts, but they do not choose strategy, targets, posture, economy, or research.

## Identity and Registration

| Invariant | Required behavior | Source/evidence status |
|---|---|---|
| HC identity key | Server registry keys HCs by owner ID/generation, not UID alone. | B57/PR #118 journal: UID may be empty/colliding; owner-keyed registration used. |
| Idempotent connect | Repeated `connected-hc` messages update same owner record and increment no duplicate active slot. | VERIFY file lines. |
| Reconnect generation | Every HC-owned order carries owner generation. Stale gen reports are logged and ignored. | New V2 requirement. |
| Disconnect cleanup | Disconnect prunes registry by owner before human path if UID empty. | Journal PR #118. |
| CIV side requirement | HC registry should require server-observed CIV for HC slots. | Journal PR #118 and #119. |
| Cold-start retry | HC reannounces after startup and server waits long enough for owner resolution. | B57 adopted HC cold-start retry. |

## Delegation Invariants

| Work type | Server owns | HC owns | Allowed reports | Forbidden |
|---|---|---|---|---|
| `aicom-team` | Team founding intent, template, target, order seq, retirement/merge decision. | Group creation/execution if delegated, movement, local arrival checks. | founded, arrived, depleted, stuck, damage/death, owner gen. | Target choice, posture change, research/build choices. |
| `sidepatrol` | Patrol spawn budget, town/route, TTL. | Patrol movement and cleanup. | spawned, arrived, expired, dead. | Town priority changes. |
| `static-defense` | Defense request, position, class, budget. | Placement/crew execution if locality requires. | placed, failed, crew dead. | Fire-and-forget without ack. |
| `wildcard execution` | Event legality, target, cost, visible-event cadence. | Concrete movement/fire task. | started, completed, failed. | Inventing new wildcard target. |

## HC PVF Allow-List Required Entries

The final source audit must enumerate exact action names. Minimum V2 allow-list:

| Action | Direction | Payload fields | Required ack |
|---|---|---|---|
| `delegate-aicom-team` | server -> HC | side, teamId, ownerGen, template, spawnPos, teamType, padStamp, orderSeq | `HC_TEAM_FOUNDED` or `HC_TEAM_FOUND_FAILED` |
| `aicom-order-move` | server -> HC | teamId, ownerGen, orderSeq, targetPos, radius, mode | `ASSAULT_DISPATCH` and later arrival/stuck |
| `aicom-order-retire` | server -> HC | teamId, ownerGen, reason, cleanupMode | `TEAM_RETIRE` |
| `aicom-order-merge` | server -> HC | fromTeam, toTeam, ownerGen, reason | `TEAM_MERGE` |
| `hc-heartbeat` | HC -> server | ownerId, ownerGen, fps, groupCount, activeAicomTeams | server updates registry |
| `hc-drop-audit` | server/internal | ownerId, ownerGen, lostTeams, reassignedTeams | log only |

## Group Budget Contract

| Limit | Rule |
|---|---|
| Engine side cap | Treat 144 groups/side as hard danger line. |
| Warning line | Emit `GRPBUDGET|WARN|side|count|max|pct|context|ownerGen`. |
| Emergency GC | Server may trigger cleanup for empty/stale groups but must not delete live player groups or GUER volume for convenience. |
| GUER soft cap | Preserve `WFBE_C_GUER_GROUPS_MAX` behavior; no V2 commander design may cap/nerf GUER output to hide budget pressure. |
| Untagged groups | Non-empty untagged group after warmup is leak evidence; include sample tags. |

## JIP Catch-Up Contract

| State | Targeted rebroadcast | Broad rebroadcast | Open risk |
|---|---|---|---|
| Commander posture and intent | Send to joining player/spectator after client side stabilizes. | Periodic `AICOMHB|v3` in RPT, optional public variable if existing UI needs it. | Partial JIP gap exists today. |
| Team markers/headings | Client marker loops should recover from public state. | Existing marker update loops. | HC drop can break heading continuity. |
| AICOM RHUD | Stable client side id fallback for spectator/dead clients. | Lane 248 already added a flag. | Verify V2 side normalization. |

## HC Drop/Reconnect Audit Tokens

| Event | Fields |
|---|---|
| `AICOMSTAT|v3|HC_DROP` | t, side, ownerId, ownerGen, activeTeams, aicomTeams, sidepatrols, staticDefense, markerContinuityState |
| `AICOMSTAT|v3|HC_RECONNECT` | t, ownerId, oldGen, newGen, recoveredTeams, orphanedTeams |
| `AICOMSTAT|v3|HC_STALE_REPORT` | t, ownerId, reportGen, currentGen, teamId, orderSeq, droppedReason |
| `AICOMSTAT|v3|HC_NO_FAILBACK` | t, side, ownerId, teamCount, reason |

## Explicit Known Gaps

| Gap | Risk | V2 handling |
|---|---|---|
| No complete failback on HC disconnect | HC-local teams may stop executing until cleaned or reassigned. | Log loudly; owner-generation watchdog fences stale reports; builder may add failback only behind V2 flag. |
| Partial JIP catch-up | Late viewers may not see intent/markers. | RHUD fallback plus heartbeat; do not block gameplay on UI state. |
| Fire-and-forget static defense | Lost PVF/action can silently fail. | Every delegated work item needs ack/fail token. |
| Owner resolution timing | Cold starts can race slot seating. | Use retry and longer owner wait from PR #118/B57 pattern. |

## Builder Acceptance

1. Every HC action has a symmetric ack or fail token.
2. Every report includes owner generation.
3. Server ignores stale generation reports.
4. No planning decision runs on HC.
5. Soak analyzer reports HC drop/reconnect counts even when zero.
