# AICOM V2 Failure-Mode Catalog

Source status: built from loaded `JOURNAL.md`, `FLEET-ROSTER.md`, and `AGENTS.md`. Wiki/source-line mining was blocked by Windows sandbox error 206. Rows include one required RPT/token family where known; exact line citations must be filled by orchestrator.

Severity scale: S0 round-breaking, S1 major behavior stall, S2 degraded behavior, S3 telemetry/diagnostic gap.

| Severity | Failure | Symptom | Trigger | Earliest confirmed build | Fix status | Evidence token |
|---|---|---|---|---|---|---|
| S0 | Supervisor silent death | Commander stops making visible decisions without hard error. | Unbounded wait, nil cascade, or loop exception. | VERIFY | Open V2 watchdog requirement | `AICOMHB` absence |
| S0 | Duplicate supervisor loop | Double buys/orders, target churn, budget spikes. | Re-init without generation fencing. | VERIFY | Open | `AICOMHB|gen` duplicate |
| S1 | Human-blip starvation | AI waits or defers because player proximity/visibility blips persist. | Deferred top-up or attack gate never clears. | Lane 376 | Fixed master for top-up TTL; broader open | `wfbe_aicom_topup_req`, TTL expiry |
| S0 | HC units bleed | Teams shrink permanently and never regain strength. | HC-founded teams skipped Produce refill floor. | B57 | Fixed master by founding pad | `B57 padded infantry team to floor` |
| S0 | WEST 0-team founding | WEST has no founded teams for a window. | Cmdcon30 conditions pending raw RPT. | cmdcon30 | Open evidence gap | `SNAP`, `GRPBUDGET`, missing `TEAM_FOUNDED` |
| S1 | Pending-slot starvation | Commander wants teams but group/HC slot budget blocks indefinitely. | 144/side pressure or HC owner unresolved. | VERIFY | Open | `GRPBUDGET|WARN` |
| S1 | Empty trucks | Transport hulls exist without useful infantry delivery. | Transport production/execution split loses cargo. | B66 suspected | Open/VERIFY | transport dispatch token pending |
| S1 | Stranded survivors | Team remnants survive but cannot rejoin, retire, or merge. | Vehicle death, stuck waypoint, or HC locality drop. | VERIFY | Open V2 merge event | `TEAM_RETIRE`, proposed `TEAM_MERGE|v3` |
| S1 | HQ-strike dead | HQ finisher never fires or fires without effect. | Missing order, too-strict gate, or picker no eligible teams. | B69/B57 | Partly branch/live; open atomic package | `HQ_STRIKE_ABORT`, `ASSAULT_DISPATCH` absence |
| S1 | Capture-phase while-loop | Execution loop wedges during capture phase. | Unbounded `while`/stale capture condition. | VERIFY | Open | `ASSAULT_ARRIVED` without next order |
| S2 | Wedged defense | Static/base defense request fires once and never recovers. | Fire-and-forget PVF/static defense path. | VERIFY | Open | `STATIC_DEFENSE`/PVF drop |
| S2 | Stall-advance false-fire | Stall recovery triggers when side is actually consolidating. | Poor KPI window or map-specific low tempo. | ZG soaks | Open | `STALL`, `POSTURE` |
| S1 | Bootstrap starvation | AI cannot start production due initial economy gap. | Funds/supply sentinel mismatch or missed first grant. | Pre lane 356 | Fixed/telemetry added | `BOOTSTRAP_STIPEND_WINDFALL` |
| S2 | Lockstep scheduling | WEST/EAST act on same phase, causing artificial symmetry or spikes. | Identical tick offsets. | VERIFY | Open acceptance scorer | proposed phase jitter scorer |
| S1 | Upgrade worker stuck | Research path never reaches needed tech such as air/SCUD. | Static upgrade array, disabled upgrade, air min-town gate. | VERIFY | Open V2 build planner | upgrade tick token |
| S0 | PVF guard drops HC action | Server sends payload but allow-list/guard discards it. | Missing action in `HandleSpecial` allow-list or CODE guard. | VERIFY | Open contract | `PVF_DROP`, `delegate-aicom-team` |
| S0 | HC disconnect no failback | Existing teams remain assigned to dead owner. | HC drop/reconnect. | Known gap in lane 405 | Open explicit risk | proposed `HC_DROP|v3` |
| S1 | Partial JIP catch-up | Late clients/spectators miss commander state/intent. | Targeted vs broad rebroadcast gap. | Lane 248 spectator RHUD related | Partly fixed client display; open contract | RHUD row / `AICOMHB` |
| S0 | JIP bootstrap hang | Client never reaches init/fade clear. | Unbounded wait on side team data. | B56 | Fixed master, never regress | client RPT wait timeout logs |
| S2 | ZG nil cascade | Compact map missing assumptions trip commander reads. | Town/map vars assumed present. | ZG branch audits | Open defensive read requirement | nil variable RPT |
| S2 | ORBITER_STUCK on compact map | Teams orbit/stuck instead of entering town. | Lane offset too large for ZG. | ZG soak, 127 events cited | Open map-profile offset | `ORBITER_STUCK` |
| S2 | Funds hoard while losing | AI accumulates large bank instead of applying pressure. | Spend logic lacks posture floor. | Doctrine cites 1.5M hoard | Open | `AICOMSTAT|TICK` funds trajectory |

## Ranked Open Items

| Rank | Open failure | Required V2 prevention |
|---:|---|---|
| 1 | Supervisor silent death / duplicate loop | `AICOMHB|v3` with generation, watchdog restart, single server namespace. |
| 2 | WEST 0-team founding | No-team watchdog, founding fallback, group-budget context in alarm. |
| 3 | HC disconnect/failback | Owner-generation fencing, HC drop/reconnect audit, explicit no-failback risk until implemented. |
| 4 | HQ-strike dead | Atomic package with gate/picker/order and analyzer events. |
| 5 | Capture-phase wedge | Bounded execution loop with order seq and timeout. |
| 6 | Money hoard | Spend-rate floor and hoard+lose warning. |
| 7 | ZG map assumptions | Defensive map-profile reads and compact-map lane offset. |

## Do-Not-Reintroduce List

| Trap | Reason |
|---|---|
| Unbounded `waitUntil` in bootstrap or execution | B56 proved it can permanent-black clients. |
| `sleep` as rescue timer on loading clients | Paused while loading; use `uiSleep` where client bootstrap is involved. |
| Whole-file branch imports from old AICOM branches | B57 skipped stale branch files for good reasons. |
| Server `publicVariableServer` callbacks | AGENTS hard-stop: call server callback directly on server. |
| Group `getVariable [name, default]` | A2 group receiver trap; use local helper/plain read. |
| GUER volume nerfs | Owner constraint: GUER volume is the point. |
