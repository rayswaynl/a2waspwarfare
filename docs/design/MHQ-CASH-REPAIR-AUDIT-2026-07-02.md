# MHQ Cash Repair Audit

Date: 2026-07-02
Lane: 121 - MHQ cash-repair one-shot
Branch: `codex/lane121-mhq-cashrepair-audit`
Base: `claude/build84-cmdcon36`

## Verdict

Lane 121 is already fixed on the current target. No source change is needed.

The prompt row described `Action_RepairMHQDepot.sqf` as setting `cashrepaired` permanently, which
would make cash HQ recovery work only once per side. Current source still sets `cashrepaired` during
the client-side cash recovery request, but both maintained roots clear the flag again after
`Server_MHQRepair.sqf` finishes registering the rebuilt HQ.

## Evidence

- Chernarus `WASP/actions/Action_RepairMHQDepot.sqf:6` reads `cashrepaired` with default `false`, avoiding nil errors before the first repair.
- Takistan `WASP/actions/Action_RepairMHQDepot.sqf:6` has the same defaulted read.
- Chernarus/Takistan `WASP/actions/Action_RepairMHQDepot.sqf:21-24` sends `RequestMHQRepair`, marks the side repair flag, and sets `cashrepaired` to `true` as a duplicate-use guard while the repair is in flight.
- Chernarus/Takistan `Server/Functions/Server_MHQRepair.sqf:23` sets `wfbe_hq_repairing` to `true` at the start of the server repair path.
- Chernarus/Takistan `Server/Functions/Server_MHQRepair.sqf:47-48` clears both `wfbe_hq_repairing` and `cashrepaired` after the rebuilt HQ is registered, so a later destroyed HQ can be cash-repaired again.
- `git diff --no-index` shows the Chernarus and Takistan copies of `Action_RepairMHQDepot.sqf` and `Server_MHQRepair.sqf` match for this lane's relevant files.

## Scope Notes

- No mission source was changed.
- This does not reopen the Mission Audit 60 repaired-HQ killed-event-handler bug; `docs/design/MISSION-AUDIT-60.md` already records that separate `_mhq` to `_MHQ` fix.
- This does not touch DR-6 `RequestMHQRepair` authority validation, which is covered by the separate open PVF hardening PR.
- No LoadoutManager run was needed because this is docs-only.

## Suggested Smoke

Owner/operator smoke in a disposable match:

- Destroy a side's HQ and recover it with the depot cash action.
- Confirm the first request blocks duplicate clicks while the repair is in flight.
- Destroy the rebuilt HQ and confirm the depot cash action is available again after `Server_MHQRepair.sqf` has completed.
