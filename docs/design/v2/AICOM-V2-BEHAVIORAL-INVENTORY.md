# AICOM V2 Behavioral Inventory

Source status: prepared by N1 during the 48-hour V2 prep sprint. Binding guide rev: GR-2026-07-03a. Local live mining was partially blocked by Windows sandbox error 206 after `AGENTS.md`, `FLEET-ROSTER.md`, and `JOURNAL.md` loaded. This file therefore separates confirmed project evidence from rows that the orchestrator should re-check against source before build.

## V2 Non-Negotiables Applied

| Commandment | Inventory consequence |
|---|---|
| Locality-first | V2 commander owns all planning state on server; HC receives executable orders only. |
| Pure planning core | Every current side-effecting worker below must be split into perception snapshot, pure decision, and execution adapter. |
| Master-flag fallback | V2 runs beside V1 behind one default-off flag; V1 files remain callable. |
| Perf and KPI self-watchdog | Every retained worker needs budget, heartbeat, and flatline telemetry. |
| Defensive map reads | Every read from town, group, side, HC, and map profile data has nil/default guards. |

## Supervisor Mode Transition Table

| State | Entry trigger | Exit trigger | Current evidence | V2 keep/spec |
|---|---|---|---|---|
| BOOT | Server commander starts for side. | Required side logic, towns, HQ, and funds are readable or timed out. | Journal B57 lists `[AICOM BOOT]` telemetry and bootstrap stipend behavior in `AI_Commander.sqf`. | Keep. Add `AICOMHB|v3|TICK|gen|BOOT|reason|readyMask`. No unbounded waits. |
| NORMAL | Side has HQ, at least one town or start economy, no last-stand gate. | Enemy reaches HQ-strike gate, loss tempo crosses threshold, or watchdog restarts. | B57 persisted `wfbe_aicom_strat_mode`; B69 roadmaps target autonomy. | Keep as default posture family: EXPAND, PRESSURE, CONSOLIDATE. |
| LAST_STAND | Low town count or HQ threatened. | Side regains buffer or HQ strike opens. | B57 adopted Last-Stand and HQ-strike with 8-town gate. | Keep, but make gate data-driven in map profile. |
| HQ_STRIKE | Enemy has enough towns and path to HQ objective is valid. | HQ destroyed, path invalid, force depleted, or cooldown. | B57 notes "HQ-strike -> 8-towns gate + persisted strat_mode". | Keep as atomic package: order, gate, picker. |
| STALLED | Capture/arrival/visible-event KPIs flatline. | Restarted worker generation emits new valid plan. | FLEET commandment 4 and ZG stall-clock lesson. | New V2 state. Watch captures/hour, arrival rate, churn, funds hoard. |
| RECOVERING | Watchdog restarts supervisor or HC reconnect changes execution capacity. | Fresh generation completes one full order cycle. | HC cold-start retry adopted in B57; reconnect gaps remain. | Keep explicit generation fencing. |

## Worker Dispatch Table

| Worker | Cadence/gate | Main outputs | Known V1 path | V2 port action |
|---|---:|---|---|---|
| Strategy | Slow tick, side has readable economy and town state. | `wfbe_aicom_strat_mode`, target priorities, last-stand/HQ-strike posture. | `Server/AI/Commander/AI_Commander_Strategy.sqf`. | Refactor into pure `AssessPosture(snapshot) -> postureRecord`. |
| Teams | Boot and refill ticks, gated by team cap, funds, HC slot availability. | New team records, HC founding payloads, pad/floor stamp. | `AI_Commander_Teams.sqf`; B57 founding pad. | Keep. New founded event must include template source, pad class, HC owner gen. |
| Produce | Refit/top-up tick, gated by existing team deficit and disband flag. | Town-center top-up request, retreat/reform, replacement buys. | `AI_Commander_Produce.sqf`; lanes 338/376 top-up guards. | Keep as execution adapter; V2 planner emits replenish intents. |
| Assign/Target | Supervisor tick, readable town graph and team availability. | Team to objective assignments, abandon/retry stamps. | `AI_Commander_AssignTowns.sqf`. | Refactor. Must add hysteresis cost and pain-memory TTL. |
| Execute | On assignment, arrival poll, stuck poll. | Move/attack/capture orders to groups/HC. | `AI_Commander_Execute.sqf` plus `Common_RunCommanderTeam.sqf`. | Keep adapter only. No strategy decisions inside HC driver. |
| Base/Build | Economy tick, funds/supply, structure availability. | Factory/building orders, base defense replacement. | `AI_Commander_Base.sqf`. | Split into build planner and construction executor. |
| Upgrade/Research | Economy tick, current upgrade array and doctrine inject. | Upgrade order queue, air research branch. | `Server_AI_Com_Upgrade.sqf` and `AI_Commander.sqf` program prepend. | Refactor into goal-driven research. Static arrays remain fallback. |
| MHQReloc | Ring-clear and economy/position gate. | Relocation order, abort/cooldown stamp. | `AI_Commander_MHQReloc.sqf`; 43/43 abort history in roster. | Keep but replace ring-only gate with utility score plus escort. |
| Wildcard | Slow pulse, deck weight, cooldown, player-visible gap. | Artillery, air cav, relief, pressure events. | `AI_Commander_Wildcard.sqf`; wildcard deck reference pending. | Keep concept. V2 escalation director owns "no dead air". |
| Telemetry/watchdog | Every supervisor tick plus state changes. | AICOMSTAT, AICOMHB, restart logs. | `Common_AICommanderLog.sqf`, B57 `[BRIEF]`. | Promote to first-class contract in AICOM V3 telemetry. |

## AICOM Constant Inventory

Rows marked `VERIFY` must be source-confirmed in `Common/Init/Init_CommonConstants.sqf` before build. Rows marked `CONFIRMED` are supported by loaded project journal/roster evidence.

| Constant | Default | Status | Behavioral effect |
|---|---:|---|---|
| `WFBE_C_AICOM_TEAMS_PC_LOW` | 10 | CONFIRMED B57 | Low-pop max HQ teams per side; raised from 5 to support volume. |
| `WFBE_C_AICOM_CONCENTRATION` | 6 | CONFIRMED B57 | Number of teams massed on primary spearhead. |
| `WFBE_C_AICOM_ASSAULT_REACH_FOOT` | 3000 | CONFIRMED B57 | Max foot-team assault reach; avoids long death marches. |
| `WFBE_C_AICOM_TEAM_SIZE_MIN` | 8 | CONFIRMED B57 | Infantry/mixed founding floor; skipped for MBT and attack heli. |
| `WFBE_C_AICOM_TOPUP_REQ_TTL` | 300 | CONFIRMED lane 376 | Clears stale `wfbe_aicom_topup_req`. |
| `WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA` | 2 | CONFIRMED journal 2026-06-15 | Caps extra late-game dynamic AI teams. |
| `WFBE_C_AICOM_AIR_MIN_TOWNS` | 4 | CONFIRMED roster lane 417 | Minimum towns before air research branch. |
| `WFBE_C_AICOM_RESEARCH_AIR` | VERIFY | VERIFY | Enables conditional air research append. |
| `WFBE_C_AICOM_MHQ_RING_CLEAR` | 600 | CONFIRMED roster lane 418 | Clear radius for MHQ relocation attempt; too strict in low-town state. |
| `WFBE_C_AICOM_MHQ_ABORT_COOLDOWN` | VERIFY | CONFIRMED name | Anti-thrash cooldown after relocation abort. |
| `WFBE_C_AICOM_LANE_OFFSET` | 120 CH/ZG current | CONFIRMED roster lane 415 | Lateral offset for approach lanes; too high for ZG. |
| `WFBE_C_AICOM_HQ_STRIKE_MIN_TOWNS` | 8 candidate | CONFIRMED B57 concept | Gate for HQ strike package. Source name must be verified. |
| `WFBE_C_AICOM_INTENT_SPECTATOR` | 1 | CONFIRMED lane 248 | Client RHUD display flag; not a planning constant. |
| `WFBE_C_CLIENT_FPS_REPORT` | 0 | CONFIRMED journal | Client FPS telemetry flag; soak support. |
| `WFBE_C_GUER_GROUPS_MAX` | 80 | CONFIRMED journal | GUER soft group cap; commander must not solve by nerfing GUER volume. |
| `WFBE_C_GROUPAUDIT_EVERY` | VERIFY | CONFIRMED name | Server group audit throttle. |
| `WFBE_C_PERFORMANCE_AUDIT_ENABLED` | VERIFY | CONFIRMED name | Enables local performance audit logs. |

## Wildcard Deck Inventory

The roster requires all 23 slots including forced-zero weights. Source was not readable in this run. The builder must treat this table as the required final shape and fill weights from `AI_Commander_Wildcard.sqf`, not the stale header.

| Slot | Class | Required fields | V2 rule |
|---:|---|---|---|
| 1-23 | Wildcard event | id, weight, forcedZero, postureGate, cooldown, cost, visibleEvent, telemetryToken | Do not execute if it violates intel honesty or local superiority doctrine. Forced-zero slots stay present with weight 0 so analyzer can detect drift. |

V2 wildcard design rules:

| Rule | Required behavior |
|---|---|
| No dead air | If no visible event for the configured pulse window, emit a legal low-cost event or radio intent. |
| Commit, do not churn | Wildcard cannot retarget assault teams unless it pays hysteresis cost. |
| Never psychic | Trigger must cite an observable event id in WHY telemetry. |
| Map profile | Deck may vary by CH/TK/ZG, but all slots remain present. |

## KEEP List for V2

| Behavior | Why keep | Required V2 hardening |
|---|---|---|
| B57 founding pad | Fixes thin-team pathology on HC-founded teams. | Pad stamp in `TEAM_FOUNDED|v3`; never mutate shared template. |
| Retreat and reform | Prevents unit bleed from becoming permanent dead teams. | Merge/deplete telemetry and no top-up for disbanding teams. |
| Last-stand/HQ-strike package | Provides round end pressure. | Atomic package with picker/order/gate; avoid re-proposing partial dead HQ strike. |
| Snappier team loop | Improves arrival responsiveness. | Put timing budget in HC contract; no planning on HC. |
| Stale top-up TTL | Prevents player-proximity deferred requests from wedging. | Keep TTL and add event on expiry. |
| Bootstrap stipend guard | Avoids economy starvation without hidden windfall. | Keep winfall telemetry and spend-rate watchdog. |
| HC cold-start retry | Handles startup timing. | Add owner-generation fencing and reconnect audit. |
| Group cap telemetry | Protects 144/side and GUER soft-cap realities. | Analyzer must compute group pressure per side. |

## Builder Checklist

1. Re-run source inventory against all `Server/AI/Commander/*.sqf`.
2. Fill exact line citations for each worker and constant.
3. Fill wildcard 23-slot table from source weights.
4. Confirm no row requires A3-only syntax or a forbidden `WFBE_C_SIM_GATING` style flag.
