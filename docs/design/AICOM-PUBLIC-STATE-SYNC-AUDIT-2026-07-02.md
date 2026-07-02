# AICOM Public State Sync Audit - 2026-07-02

Lane: 98, NJ9 HC reads nil AICOM funds/running
Base checked: `origin/claude/build84-cmdcon36@04b1ecf913`
Scope: docs/source audit only. No mission source, parameters, HC topology, public-variable defaults, or generated Takistan files are changed here.

## Summary

The prompt row is stale on the current live target. Both maintained mission roots already have a default-off sync path for the two side-logic variables called out by NJ9:

- `wfbe_aicom_funds`
- `wfbe_aicom_running`

The implementation is intentionally conservative. `WFBE_C_AICOM_PUBLIC_STATE_SYNC` defaults to `0`, so the live default keeps those side-logic writes server-local. When the owner enables the flag, the same writes pass `true` as the `setVariable` public argument, which broadcasts the values through the existing side logic instead of adding separate unconditional `publicVariable` calls.

## Verdict

No source patch is recommended in this lane. The live target already provides the intended default-preserving mechanism, mirrored in Chernarus and Takistan.

The remaining decision is operational, not mechanical: if HC-side readers need these values in a live test, enable `WFBE_C_AICOM_PUBLIC_STATE_SYNC` or add a default-0 parameter row in a dedicated parameter lane. This audit does not flip the default.

## Evidence Table

| Path | Evidence | Result |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:252` | Defines `WFBE_C_AICOM_PUBLIC_STATE_SYNC = 0` when unset. | Default preserves server-local behavior. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf:252` | Same default-0 flag. | Mirror present. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:707-711` | Computes `_syncAicomState` from the flag, then seeds `wfbe_aicom_running` and `wfbe_aicom_funds` with that public argument. | Initial state can be broadcast when enabled. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Init/Init_Server.sqf:707-711` | Same init path. | Mirror present. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_ChangeAICommanderFunds.sqf:1-6` | Adds `_syncAicomState` and applies it to `wfbe_aicom_funds` updates. | Runtime funds changes can be broadcast when enabled. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_ChangeAICommanderFunds.sqf:1-6` | Same funds update path. | Mirror present. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:21,247,700` | Computes `_syncAicomState` and applies it to full/assist/stopped `wfbe_aicom_running` transitions. | Runtime running-state transitions can be broadcast when enabled. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander.sqf:21,247,700` | Same commander state path. | Mirror present. |
| `Server_AssignNewCommander.sqf:7,15`, `Server_VoteForCommander.sqf:12,62`, `RequestClaimCommander.sqf:18,43` in both maintained roots | Human commander assignment, vote, and claim paths clear `wfbe_aicom_running` through the same `_syncAicomState` flag. | Human takeover paths are covered. |

## Non-Findings

- The target does not need an unconditional `publicVariable` call for this row. The current side-logic `setVariable` path is narrower and remains default-off.
- The flag has no visible parameter row in this audit. That is acceptable while Ray keeps the owner decision in source/constants, and should be handled separately if this becomes an operator-facing toggle.
- No Chernarus-to-Takistan drift was found in the checked AICOM state-sync paths.

## Verification

- `rg` confirmed `WFBE_C_AICOM_PUBLIC_STATE_SYNC` exists in both maintained roots.
- `rg` confirmed `_syncAicomState` is used for `wfbe_aicom_funds` and `wfbe_aicom_running` writes in both maintained roots.
- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only audit.
