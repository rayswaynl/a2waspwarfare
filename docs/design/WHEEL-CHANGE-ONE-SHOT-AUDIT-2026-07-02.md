# Lane 122 Wheel Change One-Shot Audit - 2026-07-02

## Verdict

Lane 122 is stale against the current Build 88 base. No source change is needed.

The prompt item names `WASP/actions/car_wheel_new.sqf:28` and the `wheel_change` sentinel. Neither the script nor the sentinel exists in the maintained Chernarus or Takistan roots. The old script was removed from Chernarus by commit `71f8bfcb5` as an orphaned asset referenced only from commented-out addAction lines, and the current maintained roots have no active wheel-change action path to reset.

## Current evidence

- `rg "car_wheel_new|wheel_change" Missions/[55-2hc]... Missions_Vanilla/[61-2hc]...` returns no current-source hits.
- Recursive `*wheel*.sqf` searches under both maintained mission roots return no wheel-change scripts.
- `Client/Functions/Client_SupportRepair.sqf:78-86` now performs full repair by clearing global damage and iterating every configured vehicle hitpoint with `setHit`, which covers wheels and engine without relying on the removed wheel-change action.
- Both `mission.sqm` briefing descriptions advertise "repaired wheels and engines", matching the current support-repair path.

## Scope decision

This PR does not re-add `car_wheel_new.sqf`. The named one-shot bug belongs to a removed orphan action, and reintroducing it would be behavioral churn. The maintained repair path is the support repair script, which already handles wheel and engine hitpoints in both roots.

## Verification

- Checked active brain claims plus remote branch/open PR searches for lane 122 and `car_wheel_new`/`wheel_change`; no owner or open PR was found.
- Grepped maintained Chernarus and Takistan roots for `car_wheel_new`, `wheel_change`, and wheel-named SQF files.
- Checked `git log --all --name-only -- "*car_wheel_new.sqf"` to confirm the maintained Chernarus copy was removed as orphaned by commit `71f8bfcb5`.
- Compared the Chernarus and Takistan `Client_SupportRepair.sqf` repair blocks.
- No LoadoutManager mirror was run because the diff is docs-only.
