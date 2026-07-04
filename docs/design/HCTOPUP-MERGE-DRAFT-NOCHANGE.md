# HCTopUp MERGE draft no-change audit

Lane 372 asked whether the HC MERGE path bypasses the four-unit per-tick top-up cap by joining a
donor group into a keeper group in one pass. On current Build84, no mission source change is
warranted.

## Verdict

The lane mixes two different mechanisms:

- The live `wfbe_aicom_topup_req` path creates replacement units. `AI_Commander_Produce.sqf` stamps
  the request on the team, and `Common_RunCommanderTeam.sqf` consumes it locally with a hard
  four-unit creation cap per tick.
- The old `AI_Commander_HCTopUp.DRAFT.sqf` MERGE picker would move existing donor survivors with
  `joinSilent`, not create new units. It is not compiled into `WFBE_SE_FNC_AI_Com_HCTopUp`, so the
  supervisor nil-guard makes the picker a no-op on current Build84.

Because the implicated MERGE picker is draft/uncompiled, and because the live top-up request
consumer already carries the per-tick creation cap, this lane ships as documentation-only
verification. No SQF, constants, mirrors, package output, deploy, or runtime state changed.

## Source evidence

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:64-83` compiles the
current AICOM worker list. It registers AssignTypes, AssignTowns, Produce, DisbandLowTier, Execute,
Base, Beacon, Teams, Strategy, Snapshot, Allocate, MHQReloc, PlayerArty, and Paratroops. It does not
compile `AI_Commander_HCTopUp.DRAFT.sqf` or define `WFBE_SE_FNC_AI_Com_HCTopUp`.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:449-454`
reads `WFBE_C_AICOM_HC_MERGE_ENABLE` and `WFBE_C_AICOM_HC_TOPUP_ENABLE`, then calls the worker only
inside `if (!isNil "WFBE_SE_FNC_AI_Com_HCTopUp")`. With no compile registration, the symbol remains
nil and the call is skipped.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_HCTopUp.DRAFT.sqf:1-7`
still identifies itself as `DRAFT / NOT WIRED`. Its MERGE section at `:69-168` is a server-side
picker/dispatcher. It sends `aicom-team-merge` to live HCs and has a server-local fallback, but that
code cannot run until the draft file is compiled.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/HandleSpecial.sqf:52-68` already
contains the HC-side `aicom-team-merge` consumer. It is default-off through
`WFBE_C_AICOM_HC_MERGE_ENABLE`, self-gates on both leaders being local, and runs
`(units _grpB) joinSilent _grpA`. This is a survivor-transfer merge, not a createUnit top-up
consumer.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2312-2352`
is the live top-up request consumer. It reads `wfbe_aicom_topup_req`, respects request TTL/proximity
defer, and creates at most four replacement units in the current tick with
`while {_topMade < _topN && {_topMade < 4}}`.

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1144-1152`
keeps HC MERGE default-off (`WFBE_C_AICOM_HC_MERGE_ENABLE = 0`) while the live HC top-up request path
is default-on (`WFBE_C_AICOM_HC_TOPUP_ENABLE = 1`). The top-up default belongs to the
Produce-to-RunCommanderTeam request path; it does not make the draft HCTopUp picker live.

The maintained Takistan and Zargabad roots match the same compile/no-compile shape for
`WFBE_SE_FNC_AI_Com_HCTopUp`.

## No-change rationale

There is no current runtime bug to patch in the MERGE picker because the picker is unreachable. The
four-unit cap is already present where live unit creation happens. Reusing that cap for `joinSilent`
survivor transfer would be a new merge-throttling design decision, not a fix to the live top-up
consumer.

If a future lane intentionally wires `AI_Commander_HCTopUp.DRAFT.sqf`, it should validate the MERGE
contract as a separate feature:

- keep `WFBE_C_AICOM_HC_MERGE_ENABLE` default-off until live HC soak proves the picker;
- decide whether existing-unit merge should be all-at-once or batched under a dedicated MERGE knob;
- if batching is added, delay donor bookkeeping (`aicom-team-ended`) until the final batch, so a
  partially moved donor group cannot be deregistered early;
- keep the live `wfbe_aicom_topup_req` creation cap separate from survivor-transfer policy.

## Verification

- Refreshed the Game PC prompt/brain, wiki coordination state, open PR board, and remote branch list
  before claiming lane 372.
- Exact duplicate scan found no lane372 / HC MERGE consumer / topup cap ignored owner; PR #372 is
  unrelated lane121.
- `git grep` over maintained roots found `WFBE_SE_FNC_AI_Com_HCTopUp` only in the supervisor
  nil-guard and draft-file diagnostics, not in a compile registration.
- Source anchors above were read from `claude/build84-cmdcon36@873c7f7af25070bbf690d27cc4c006d45a00155f`.
- Docs-only validation: no SQF edited, no LoadoutManager run, no package artifact, no deploy, and no
  live runtime action.
