# Proposed arm: town loop observe → auto-restart

**Status:** harness-prepared only. Not applied in this PR (builder lane / owner deploy GO).

**Evidence:** `EVIDENCE.md` — town = **GREEN**, confidence medium.

## Current default

`Server/FSM/server_coreloop_supervisor.sqf` descriptor table:

```sqf
["town",     "Server\FSM\server_town.sqf",      5, 1],  // mode 1 = observe
```

Per-loop override (if registered later):

```sqf
WFBE_C_CORELOOP_RESTART_TOWN  // default falls back to descriptor 1
```

## Exact flip (follow-up SQF PR)

Option A — descriptor default (matches groupsgc style):

```sqf
["town",     "Server\FSM\server_town.sqf",      5, 2],  // mode 2 = restart
```

Option B — explicit constant (preferred for lobby/ops visibility), append-only in
`Common/Init/Init_CommonConstants.sqf`:

```sqf
if (isNil "WFBE_C_CORELOOP_RESTART_TOWN") then {WFBE_C_CORELOOP_RESTART_TOWN = 2};
// leave ECONOMY and UPGRADE at 1 (observe) until their harness verdicts are GREEN
if (isNil "WFBE_C_CORELOOP_RESTART_ECONOMY") then {WFBE_C_CORELOOP_RESTART_ECONOMY = 1};
if (isNil "WFBE_C_CORELOOP_RESTART_UPGRADE") then {WFBE_C_CORELOOP_RESTART_UPGRADE = 1};
// groupsgc already defaults to 2 in the supervisor descriptor
```

Mirror via LoadoutManager after CH edit. Do **not** touch JIP paths.

## Must stay watch-only (this harness run)

| Loop | Verdict | Why |
|------|---------|-----|
| economy | RED | Mid-tick restart re-pays sides already charged; no last-tick idempotency key |
| upgrade | AMBER | Kill after `wfbe_upgrading=true` / deduct but before `ProcessUpgrade` spawn can stick the gate |

## Deploy patchnotes line (when town arm ships)

```
CORELOOP arming this deploy: groupsgc=restart (existing), town=restart (NEW, harness GREEN),
economy=observe (RED — double-charge risk), upgrade=observe (AMBER — stuck-start paths).
```
