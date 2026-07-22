# Restart-safety harness (HP-01 core-loop supervisor)

Repo-testable evidence harness for owner picklist item 3:

> prove watchdog-triggered restarts are state-safe (no double-charging, no town-state
> corruption, no upgrade re-grant), then arm money/towns/upgrades loop-by-loop.

## What it covers

| Loop id   | Mission file                         | Default mode (HP-01) |
|-----------|--------------------------------------|----------------------|
| `town`    | `Server/FSM/server_town.sqf`         | observe (1)          |
| `economy` | `Server/FSM/updateresources.sqf`     | observe (1)          |
| `upgrade` | `Server/FSM/upgradeQueue.sqf`        | observe (1)          |
| `groupsgc`| `Server/FSM/server_groupsGC.sqf`     | **restart (2)**      |

Supervisor: `Server/FSM/server_coreloop_supervisor.sqf`.

## Run

```powershell
# from repo root
python Tools/RestartSafety/restart_safety_harness.py
python -m pytest Tools/RestartSafety/test_restart_safety_harness.py -q
# or:
python Tools/RestartSafety/test_restart_safety_harness.py
```

Writes:

- `docs/Proposals/wasp-restart-safety-harness-20260722/EVIDENCE.md`
- `docs/Proposals/wasp-restart-safety-harness-20260722/EVIDENCE.json`

## Verdicts

- **GREEN** — model + static checks show restart is state-safe → may arm `WFBE_C_CORELOOP_RESTART_<ID> = 2`
- **AMBER** — no double-credit found, but stuck/incomplete intermediate paths remain → stay observe
- **RED** — double-charge / corruption / re-grant demonstrated → stay observe until fixed

## Scope notes

- No live Arma server required.
- Models intentional simplifications of SQF transaction order; EVIDENCE lists what was **not** verified.
- Arming SQF flips are **owner/deploy GO** decisions; this harness only produces the per-loop table.
