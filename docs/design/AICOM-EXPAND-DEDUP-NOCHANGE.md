# AICOM Expansion Dedup No-Change Audit

Lane: 330 - Expansion lane: deduplicate neutral-town picks across expand-quota teams
Guide: GR-2026-07-03a
Base: `claude/build84-cmdcon36` at `4910fc3f5fb5657feee6b554d700155f3a827092`
Verdict: no mission source change is needed on the current Build84 lane.

## Finding

The lane request is already implemented in the maintained mission sources. Build84 keeps
a per-allocation-tick `_expandClaimed` list, gates it with
`WFBE_C_AICOM_EXPAND_DEDUP`, excludes already claimed neutral towns during each
expand-team nearest search, and records each selected expansion target before the next
team is evaluated.

The prompt text says the bug-fix flag should be default 1, but the current binding
AGENTS rule says new behavior must be flag-gated and default off. Build84 follows that
binding rule: `Init_CommonConstants.sqf` registers `WFBE_C_AICOM_EXPAND_DEDUP = 0`
with comments explaining that owners can flip it to 1 when ready.

## Evidence

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:306`
  declares `_expandClaimed` and `_dedupOn` in the local allocator scope.
- `AI_Commander_Allocate.sqf:309` initializes `_expandClaimed = []` for the current
  allocation tick.
- `AI_Commander_Allocate.sqf:317` reads
  `missionNamespace getVariable ["WFBE_C_AICOM_EXPAND_DEDUP", 0]`, so legacy behavior
  is retained unless the flag is enabled.
- `AI_Commander_Allocate.sqf:351-360` skips `_neutTowns` already present in
  `_expandClaimed` and appends the selected `_eTgt` after assignment.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:698`
  registers `WFBE_C_AICOM_EXPAND_DEDUP = 0` with a comment documenting the legacy and
  dedup modes.

The same anchors are present in the Takistan and Zargabad maintained mirrors. SHA256
parity also matches across all three maps:

- `AI_Commander_Allocate.sqf`: `51130643BE883C64835E8FDF4BC546551C3ECF7A9A567BBF360D00E7BC45B2E5`
- `Init_CommonConstants.sqf`: `2BEB0448A1C03CC11D8238ECCA9C2AA7C84D752EE0ACD2C6492DCFFA544DCB04`

## Scope

This is a docs-only no-change audit. It deliberately avoids touching
`AI_Commander_Allocate.sqf` because that allocator file is already hot under open
Build84 PRs #599, #597, and #579. No SQF was edited, no LoadoutManager mirror run is
needed, no package artifact was produced, and no deploy or live runtime action was
taken.
