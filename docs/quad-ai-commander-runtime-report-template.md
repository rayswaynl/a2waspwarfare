# Quad AI Commander Runtime Report Template

Paste this template into the relevant PR conversation after an in-engine test pass. Keep exact RPT excerpts short but concrete. Mark unknowns as `UNCERTAIN`; do not infer a pass from missing errors alone.

Use with:

- `docs/quad-ai-commander-evidence-audit-matrix.md`
- `docs/quad-ai-commander-runtime-validation.md`
- `docs/quad-ai-commander-phase0-evidence-checklist.md`
- `docs/quad-ai-commander-phase2-smoke-update.md`

## Report Header

```text
Branch:
Commit:
PR:
Mission/map:
Side(s): WEST / EAST / both
Mode(s): full-auto / hybrid-assist / handoff / stopped
Runtime duration:
Server/player setup:
RPT path or artifact:
Tester:
Date:
Decision: PASS / FAIL / UNCERTAIN
Next PR allowed to proceed: YES / NO
```

## Phase 0 Execution Substrate

Target owner: PR #14 / `feat/ai-commander`.

```text
Full-auto lifecycle: PASS / FAIL / UNCERTAIN
Type assignment: PASS / FAIL / UNCERTAIN
Town assignment and movement: PASS / FAIL / UNCERTAIN
Production queue/release: PASS / FAIL / UNCERTAIN
Upgrade start/debit: PASS / FAIL / UNCERTAIN
Hybrid assist state: PASS / FAIL / UNCERTAIN
Human Move waypoint execution: PASS / FAIL / UNCERTAIN
Human Patrol waypoint execution: PASS / FAIL / UNCERTAIN
Human Defense waypoint execution: PASS / FAIL / UNCERTAIN
Delegated team auto-driving: PASS / FAIL / UNCERTAIN
Non-delegated team preserved: PASS / FAIL / UNCERTAIN
Human economy freeze: PASS / FAIL / UNCERTAIN
Human-leaves handoff: PASS / FAIL / UNCERTAIN
Stopped/HQ-down/disabled state: PASS / FAIL / UNCERTAIN
Watchlist/error sweep: PASS / FAIL / UNCERTAIN
```

Required RPT excerpts:

```text
AI_Commander.sqf: [WEST] AI commander ACTIVE (full command).
AI_Commander_AssignTypes.sqf: [WEST] ...
AI_Commander_AssignTowns.sqf: [WEST] team ... heading to attack town ...
AI_Commander_Produce.sqf: [WEST] team ... ordering ...
Server_AI_Com_Upgrade...
AI_Commander.sqf: [WEST] AI commander ASSIST (hybrid - human commander, executor only).
AI_Commander_Execute.sqf: [WEST] team ... executing move order ...
AI_Commander_Execute.sqf: [WEST] team ... executing patrol order ...
AI_Commander_Execute.sqf: [WEST] team ... executing defense order ...
AI_Commander.sqf: [WEST] AI commander STOPPED (disabled / HQ down).
```

Manual observations:

```text
Move waypoint visible/movement observed:
Patrol waypoint visible/movement observed:
Defense waypoint visible/movement observed:
Delegated team auto-driven:
Non-delegated team overwritten:
Explicit human order preserved:
AI production/upgrade seen while human commander owned economy:
Full-auto resumed after human left:
Worker actions continued after stopped:
```

Error/watchlist search results:

```text
AI_Commander errors:
AI_Commander_Execute errors:
AI_Commander_AssignTowns retarget/reset loop:
wfbe_exec_sig stale-order issue:
wfbe_queue stuck issue:
Undefined variable / nil-code hits:
```

## Phase 1 Structured Logs

Target owner: PR #18 / `codex/ai-commander-logs`.

Preconditions:

```text
#14 Phase 0 runtime proof complete: YES / NO
#18 graph-refreshed onto accepted #14 head: YES / NO
Visible diff still instrumentation-only plus inherited Phase 0 hardening: YES / NO
```

Gate results:

```text
STATE full log: PASS / FAIL / UNCERTAIN
STATE assist log: PASS / FAIL / UNCERTAIN
STATE stopped log: PASS / FAIL / UNCERTAIN
ORDER log for human Move/Patrol/Defense: PASS / FAIL / UNCERTAIN
TOWN_ASSIGN log: PASS / FAIL / UNCERTAIN
PRODUCTION log in full-auto only: PASS / FAIL / UNCERTAIN
UPGRADE log in full-auto only: PASS / FAIL / UNCERTAIN
No production/upgrade log under human economy ownership: PASS / FAIL / UNCERTAIN
Per-side sequence monotonic: PASS / FAIL / UNCERTAIN
Log buffer bounded: PASS / FAIL / UNCERTAIN
Behavior-neutral relative to Phase 0: PASS / FAIL / UNCERTAIN
```

Required RPT excerpts:

```text
AI_Commander_Log: [WEST] #... STATE ...
AI_Commander_Log: [WEST] #... ORDER ...
AI_Commander_Log: [WEST] #... TOWN_ASSIGN ...
AI_Commander_Log: [WEST] #... PRODUCTION ...
AI_Commander_Log: [WEST] #... UPGRADE ...
```

Bounds evidence:

```text
First observed sequence:
Last observed sequence:
Max side-log count observed:
Run duration for cap check:
```

## Phase 2 Context/Beliefs

Target owner: PR #19 / `codex/ai-commander-context`.

Preconditions:

```text
#18 Phase 1 runtime proof complete: YES / NO
#19 graph-refreshed onto accepted #18 head: YES / NO
Visible diff limited to context hook/helpers plus inherited stack: YES / NO
```

Manual smoke command:

```sqf
west Call WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke;
```

Use `east` for the other side.

Gate results:

```text
Manual helper only, never automatic: PASS / FAIL / UNCERTAIN
CONTACT log appended: PASS / FAIL / UNCERTAIN
INTEL log appended: PASS / FAIL / UNCERTAIN
LOSS log appended: PASS / FAIL / UNCERTAIN
CONTACT creates belief: PASS / FAIL / UNCERTAIN
Nearby contact merges and raises confidence: PASS / FAIL / UNCERTAIN
Confidence cap respected: PASS / FAIL / UNCERTAIN
INTEL remains low-confidence rumor/tracked context: PASS / FAIL / UNCERTAIN
LOSS reinforces moderate threat: PASS / FAIL / UNCERTAIN
Nearest-town attachment appears: PASS / FAIL / UNCERTAIN
Confidence decays: PASS / FAIL / UNCERTAIN
Stale belief expires/stops appearing: PASS / FAIL / UNCERTAIN
No worker reads wfbe_aicom_context: PASS / FAIL / UNCERTAIN
No behavior change from context existence: PASS / FAIL / UNCERTAIN
```

Required RPT excerpts:

```text
AI_Commander_ContextSyntheticSmoke: [WEST] appended CONTACT/INTEL/LOSS synthetic records
AI_Commander_Log: [WEST] #... CONTACT ...
AI_Commander_Log: [WEST] #... INTEL ...
AI_Commander_Log: [WEST] #... LOSS ...
AI_Commander_Context: [WEST] ... tracked beliefs, top=...
```

Belief observations:

```text
Belief id / top summary:
Initial confidence:
Merged confidence:
Decay confidence:
Expiry observation:
Nearest town:
Any worker behavior changed because context existed:
```

## Phase 3 Advisory Planner

Target owner: future `codex/ai-commander-planner`.

Preconditions:

```text
#19 Phase 2 evidence complete: YES / NO
Planner defaults advisory-on: YES / NO
Workers do not read priorities yet: YES / NO
```

Gate results:

```text
DEFEND_TOWN priority: PASS / FAIL / UNCERTAIN
SCOUT_CONTACT or scout/attack priority: PASS / FAIL / UNCERTAIN
CONTAIN_ARMOR priority: PASS / FAIL / UNCERTAIN
WATCH_AIR priority: PASS / FAIL / UNCERTAIN
IGNORE_STALE or stale suppression: PASS / FAIL / UNCERTAIN
Priority count bounded: PASS / FAIL / UNCERTAIN
No behavior change in advisory mode: PASS / FAIL / UNCERTAIN
```

Required RPT excerpts:

```text
AI_Commander_Plan: [WEST] top DEFEND_TOWN ... score=... reason=... belief=...
AI_Commander_Plan: [WEST] selected ... priorities ...
```

## Phase 4 Worker Biasing

Target owner: future `codex/ai-commander-worker-biasing`.

Preconditions:

```text
Phase 3 advisory evidence complete: YES / NO
Worker bias defaults off: YES / NO
Explicit activation required: YES / NO
```

Advisory-on results:

```text
Priorities exist: PASS / FAIL / UNCERTAIN
Workers fall back to current behavior: PASS / FAIL / UNCERTAIN
No priority-driven assignment occurs: PASS / FAIL / UNCERTAIN
```

Advisory-off results:

```text
DEFEND_TOWN assigns bounded eligible/delegated team: PASS / FAIL / UNCERTAIN
SCOUT_CONTACT assigns bounded eligible/delegated team: PASS / FAIL / UNCERTAIN
ATTACK_CONTACT biases without dogpiling: PASS / FAIL / UNCERTAIN
Human explicit orders preserved: PASS / FAIL / UNCERTAIN
Non-delegated hybrid teams untouched: PASS / FAIL / UNCERTAIN
Human economy freeze preserved: PASS / FAIL / UNCERTAIN
Expired/malformed priorities fall back: PASS / FAIL / UNCERTAIN
Production/funds/factory/cap checks intact: PASS / FAIL / UNCERTAIN
```

Required RPT excerpts:

```text
AI_Commander_AssignTowns: [WEST] team ... defending ... from priority DEFEND_TOWN score=... reason=...
AI_Commander_AssignTypes: [WEST] team ... picked template ... from CONTAIN_ARMOR priority belief=...
```

## Final Decision

```text
Rows marked FAIL:
Rows marked UNCERTAIN:
Accepted uncertainties, if any:
Fix required before downstream work:
Downstream branch may proceed: YES / NO
PR should remain draft: YES / NO
Follow-up comment/issue created:
```
