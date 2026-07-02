# FundsSink Wiring Audit

Date: 2026-07-02
Lane: 169 - revive FundsSink
Branch: `codex/lane169-fundssink-wiring-audit`
Base: `claude/build84-cmdcon36`

## Verdict

Lane 169 is already fixed on the current target. No source change is needed.

The prompt row described `AI_Commander_FundsSink.sqf` as complete but never fired. Current source keeps
the feature dark by default, but it is compiled and hooked from the income cadence behind the same
`WFBE_C_AICOM_FUNDS_SINK_ENABLE` flag.

## Evidence

- Chernarus `Common/Init/Init_CommonConstants.sqf:623-626` defines `WFBE_C_AICOM_FUNDS_SINK_ENABLE = 0` plus threshold, drain percentage, and drain max constants.
- Takistan `Common/Init/Init_CommonConstants.sqf:623-626` has the same constants.
- Chernarus `Server/Init/Init_Server.sqf:41-42` compiles `WFBE_SE_FNC_AI_Com_FundsSink` from `Server/AI/Commander/AI_Commander_FundsSink.sqf`.
- Takistan `Server/Init/Init_Server.sqf:41-42` has the same compile registration.
- Chernarus/Takistan `Server/FSM/updateresources.sqf:145-150` hook the worker on the income cadence only when `WFBE_C_AICOM_FUNDS_SINK_ENABLE > 0`, AI commander is enabled, and the compiled function exists.
- Chernarus/Takistan `Server/AI/Commander/AI_Commander_FundsSink.sqf:30-31` hard-gate the worker again, early-exiting when the flag is not enabled.
- `git diff --no-index` shows the Chernarus and Takistan `updateresources.sqf`, `AI_Commander_FundsSink.sqf`, and `Init_CommonConstants.sqf` copies match.
- `git diff --no-index` on `Init_Server.sqf` shows only the expected map-id database difference; the FundsSink compile registration matches.

## Scope Notes

- No mission source was changed.
- No default was flipped. `WFBE_C_AICOM_FUNDS_SINK_ENABLE` remains `0`.
- No LoadoutManager run was needed because this is docs-only.

## Suggested Smoke

Owner/operator smoke if the flag is enabled in a test build:

- Let an AI commander exceed `WFBE_C_AICOM_FUNDS_SINK_THRESHOLD`.
- Confirm the RPT emits `FUNDS-SINK fired` and `AICOMSTAT|v1|EVENT|...|FUNDS_SINK`.
- Confirm funds drain is capped by `WFBE_C_AICOM_FUNDS_SINK_DRAIN_MAX`.
