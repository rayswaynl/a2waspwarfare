# AAV Naval Hook Status - 2026-07-02

Base checked: `origin/claude/build84-cmdcon36@b2dbab5f3`.

Scope: fleet lane 45, "AAV NAVAL HOOK" - verify whether the default-off WEST AAV metadata hook still needs implementation.

## Summary

No source patch is needed for this lane on the current base. The lane 45 source hook is already present from merge commit `c8b99512e` / PR #302:

`WFBE_C_NAVAL_WEST_AAV` defaults to `0` in both maintained mission roots, and `Core_US.sqf` conditionally registers `AAV` as a Core_US heavy-factory metadata row only when that flag is enabled.

The already-shipped hook is intentionally narrow. It gives a future naval-map lane an explicit WEST/US amphibious APC metadata row without changing the default flag state. It does not implement carrier launch, beach-assault spawning, AAV pathing, naval objective rewards, or any mission-parameter/defaults change.

## Evidence

| Check | Result |
| --- | --- |
| Source provenance | `c8b99512e Merge PR #302: default-off WEST AAV naval buy-row metadata hook (WFBE_C_NAVAL_WEST_AAV=0, both maps)`. |
| Default-off flag | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:886` and the Takistan mirror define `WFBE_C_NAVAL_WEST_AAV = 0`. |
| Live WEST metadata hook | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core/Core_US.sqf:183-188` appends `AAV` metadata only when `WFBE_C_NAVAL_WEST_AAV > 0`; Takistan mirrors the same block. |
| USMC baseline metadata | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core/Core_USMC.sqf:127-128` keeps the original USMC `AAV` metadata row. |
| Existing heavy-pool references | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Units/Units_CO_US.sqf:237` and `:249` include `AAV` in the CO WEST heavy pools for Chernarus/Takistan branches. |
| Current design register | `docs/design/UNUSED-ASSETS.md:42` already marks the lane as "**S** hook shipped / **L** full" and says full carrier launch behavior remains future work. |
| Prompt drift | The fleet prompt still offers lane 45 as if the hook needs implementation; the current target already contains it. |

## Conclusion

Lane 45 is stale relative to `origin/claude/build84-cmdcon36`. Treat the default-off AAV metadata hook as already shipped on the current target, and do not open another source PR for the same hook.

Future work should be framed as a new naval gameplay lane, not a lane 45 retry. That future lane would need explicit owner approval for carrier/depot placement, amphibious spawn rules, AAV route/pathing constraints, player-facing availability, and any parameter/default changes.

No mission source, generated mission files, live server/deploy work, package artifacts, `UNUSED-ASSETS.md`, or LoadoutManager output were changed in this PR.
