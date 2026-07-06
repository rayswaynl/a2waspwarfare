# Build-Queue Progress Feedback Status - 2026-07-03

Scope: fleet lane 147, source audit only. The prompt asks for visible queue
progress while `Client_BuildUnit.sqf` waits for a queued factory purchase to
reach the front of the queue.

## Verdict

Lane 147 is already implemented on `origin/claude/build84-cmdcon36`
(`b1608b096eb4a02d7c213d794e22b8bc59df8df0`). No additional
`Client_BuildUnit.sqf` source change is needed for the prompt as written.

The current code shows the buyer a recurring plain title message while their
purchase is still behind another queue token. The message includes:

- the unit label;
- the buyer's current queue position;
- total queue length;
- an approximate ETA in seconds.

## Source Evidence

- `Client/Functions/Client_BuildUnit.sqf:1` declares `_nextQueueHint`,
  `_queuePos`, and `_queueEta`.
- `Client/Functions/Client_BuildUnit.sqf:213` initializes `_nextQueueHint` to
  `time` before the queue wait loop.
- `Client/Functions/Client_BuildUnit.sqf:214-227` runs during the multi-slot
  wait and refreshes the hint every 12 seconds when the queue is non-empty.
- `Client/Functions/Client_BuildUnit.sqf:221-225` computes the token's queue
  position, estimates ETA as `(_queuePos * _longest) + _waitTime`, and emits:
  `Build queue: %1 position %2/%3, ETA about %4s.`
- Git history contains `f721ae5ac Merge PR #223: show factory queue
  position/ETA progress`, with the implementation commit `a0df4e5f6 Show
  factory queue progress` already in the target lineage.

## Boundaries

This status note does not change queue-token, refund, factory-death, cancel, or
spawn behavior. Those are separate economy/factory lanes. It also does not
change the final post-wait `STR_WF_INFO_BuyEffective` hint; the lane-147 prompt
was specifically about feedback during the invisible queue wait.

## Verification

- Brain and GitHub were checked for active/open lane-147 work before this pass.
- Source anchors and git history above were read from
  `origin/claude/build84-cmdcon36`.
- No mission source, generated mirror, package artifact, live server, or
  LoadoutManager output is changed by this audit.
