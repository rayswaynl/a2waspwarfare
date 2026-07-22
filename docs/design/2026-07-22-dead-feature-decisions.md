# Dead-feature wiring decisions — 2026-07-22

> Context: WASP Warfare is an Arma 2 OA video-game mission. This is a source-level wiring and maintenance audit of the owner-operated game repository; no live server action is proposed or performed.

## Decision summary

| Item | Decision | Evidence | Follow-up |
| --- | --- | --- | --- |
| Client AI delegation | **Keep; reject the reported unwired premise.** | `Client/FSM/updateavailableactions.fsm` starts with the client and, while `WFBE_C_AI_DELEGATION == 1`, sends `RequestSpecial/update-clientfps`; `Server_HandleSpecial.sqf` stores the FPS in `WFBE_AI_DELEGATION_<uid>` and `Server_FNC_Delegation.sqf` consumes it. | No sender work or retirement. A local/game-server soak may still measure whether this optional legacy mode is desirable, but static wiring is intact. |
| Squad join request | **Retire rather than add a new UI.** | The maintained mission has the server receive/forward route and client accept/deny handlers, but no maintained client `group-query` sender or Groups dialog. The only sender found is in non-maintained modded mission copies. | Remove as a separate, reviewable cleanup after owner veto window; do not import the legacy modded UI into maintained maps. |
| Mechanical orphan batch | **Do not duplicate active cleanup branches.** | Open draft [#1241](https://github.com/rayswaynl/a2waspwarfare/pull/1241) already removes `Common_ArrayRemoveIndex` and `Common_CreateUnitsForResBases` plus their registrations. | Stack any remaining source removals only after #1241’s ownership/base is reconciled; `CreateUnitsForResBases` remains an owner-call item. |

## Verified routing facts

1. `Client/Init/Init_Client.sqf` launches `Client/FSM/updateavailableactions.fsm`.
2. The FSM’s `update-clientfps` send is guarded by the legacy client-delegation mode and its configured report interval; it is not a dead string or an unlaunched FSM.
3. `Server/Functions/Server_HandleSpecial.sqf` has the matching `update-clientfps` receiver and updates the delegator record created on player connect.
4. The maintained group system can receive a `group-query`, forward `group-join-request`, and return accept/deny notifications, but has no maintained discovery or UI entry point that starts the request.

## Cleanup boundary

The following static candidates were rechecked in all three maintained mission roots. Their disposition is intentionally separated from the decisions above so a future deletion PR can remain mechanical and mirror-safe:

- `Radio_Toggle.sqf`, `Core_KSK.sqf`, `Core_Models Arrowhead.sqf`, `Core_Models Vanilla.sqf`, and `Artillery_TKA/TKGUE/US.sqf` have no maintained-root path reference.
- `WFBE_HC_FNC_ParkDeadspawn` appears only as duplicate registrations; the bare `GetTeamMovePos`, `GetTeamType`, and `GetClosestLocationBySide` registrations likewise have no `WFBE_CO_FNC_*` consumers.
- `FPSPicker_Open.sqf` and the `WFBE_FPSPickerMenu`/`WFBE_SettingsMenu` classes need their action/display wiring read together before deletion; their symbol counts alone are not proof of deadness.
- `GetSideUpgrades`, `FireArtillery`, `CountPlayerScores`, and the supply-mission functions have live namespaced implementations. Any deletion must remove only a demonstrated-unused bare alias, never the active `WFBE_*_FNC_*` function.

## Collision record

- #1241 owns the `Common_ArrayRemoveIndex` and `Common_CreateUnitsForResBases` deletion/registration area.
- #1272 touches `Server_HandleSpecial.sqf` and client-FPS telemetry paths; this decision record makes no source change there.
- No maintained source file was changed by this decision PR, so no terrain mirror run is applicable.

## Verification performed

- Fresh worktree from `origin/master` (`391b845a5b2790f23c8a6b1a1000a07dcf2ce760`).
- Whole-maintained-tree reference searches for the two routing paths and cleanup candidates.
- Open-PR collision check against #1241, #1242, #1243, and #1272.
- Independent read-only source audit requested before submission.
