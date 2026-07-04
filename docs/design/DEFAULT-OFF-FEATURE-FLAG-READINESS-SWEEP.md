# Default-Off Feature Flag Readiness Sweep

Date: 2026-07-03
Lane: fleet lane 303, docs-only source PR
Base checked: `origin/claude/build84-cmdcon36@873c7f7af25070bbf690d27cc4c006d45a00155f`

## Scope

This pass audits default-off `WFBE_C_*` feature switches that look tempting to
flip during release prep. It records what is wired, what is inert at default 0,
and what evidence is still required before any flag can safely move to default 1.

No mission source, lobby parameters, generated mirrors, package artifacts, deploy
scripts, or live runtime state are changed here.

## Summary

| Flag | Current state on Build84 | Flip readiness | Recommendation |
| --- | --- | --- | --- |
| `WFBE_C_SMUGGLER_ENABLE` | No live flag registration or reader found on the target base. The AN-2 smuggler concept is documented as adjacent future work in `docs/design/UNUSED-ASSETS.md:35` and `:55`, but this base has no dormant switch to arm. | Not present | Do not add or flip in release prep. Wait for a dedicated smuggler implementation lane and its own default-off gate. |
| `WFBE_C_ENDGAME_FORCE_ENABLE` | Registered default 0 in `Common/Init/Init_CommonConstants.sqf:663`. When enabled, `server_victory_threeway.sqf:22-38` publishes `WFBE_ENDGAME_FORCE_MULT`; `updateresources.sqf:53-54` applies it to AICOM town income. | Wired but needs soak proof | Keep default 0 until a long-round soak confirms the taper resolves stalemates without starving normal comeback play. |
| `WFBE_C_AICOM_FUNDS_SINK_ENABLE` | Registered default 0 in `Init_CommonConstants.sqf:651`. `AI_Commander_FundsSink.sqf:31` early-exits when dark; `updateresources.sqf:147-149` calls it only when the flag is positive and the worker exists. | Wired but needs economy soak | Keep default 0 until soak data shows the drain rate and veteran push do not overcorrect rich-side behavior. |
| `WFBE_C_VEHICLE_MARKINGS` | Registered default 0 in `Init_CommonConstants.sqf:1666`. `Common_AddVehicleMarking.sqf:41` gates local `#lightpoint` markings; `Common_CreateVehicle.sqf:45-55` feeds the shared pending-texture path. | Not ready for default-on | Keep default 0 until in-engine attach/FPS and visual smoke prove the per-vehicle lightpoints and side skins are acceptable at AI-heavy scale. |
| `WFBE_C_VEHICLE_FLAGS` | Registered default 0 in `Init_CommonConstants.sqf:1670`. `Common_AddVehicleFlag.sqf:30` gates per-vehicle `FlagCarrier` attachment; `Common_CreateVehicle.sqf:48-50` wires it into the same JIP-safe pending-texture path. | Not ready for default-on | Keep default 0 until the flag object attachment cost is measured in a heavy-AI session. |
| `WFBE_C_WALLS_V2` | Registered default 0 as a tombstone in `Init_CommonConstants.sqf:1813-1818`. `Init_Defenses.sqf:58-61` says the v2 factory wall ladder arrays are deleted; construction hooks at `Construction_MediumSite.sqf:170` and `Construction_SmallSite.sqf:127` state the old v2 ladder is reverted/dead. | Dead flag | Keep default 0. Future work should remove or continue tombstoning it in a cleanup lane, not flip it. |

## Readiness Gates Before Any Default Flip

### Endgame soft-force

Required proof before enabling:

- A soak that runs past `WFBE_C_ENDGAME_FORCE_TIMER` and records `AICOMSTAT|v1|EVENT|ALL|...|ENDGAME_FORCE`.
- Before/after income and town-control snapshots showing the taper creates commitment pressure instead of a permanent 10 percent grind.
- Confirmation that player paychecks and supply are not unintentionally reduced. The current consumer is the AICOM town-income path in `updateresources.sqf:53-54`.

### AICOM funds sink

Required proof before enabling:

- A soak where one or both commanders cross `WFBE_C_AICOM_FUNDS_SINK_THRESHOLD` and the RPT logs `AI_Commander_FundsSink.sqf: ... FUNDS-SINK fired`.
- Comparison of commander funds, team pressure, and veteran/premium founding frequency before and after the drain.
- A rollback note for `WFBE_C_AICOM_FUNDS_SINK_DRAIN_PCT` and `WFBE_C_AICOM_FUNDS_SINK_DRAIN_MAX` if the push wave becomes too spiky.

### Vehicle markings and vehicle flags

Required proof before enabling either cosmetic:

- In-engine vehicle-spawn smoke with WEST, EAST, and GUER vehicles created through `Common_CreateVehicle.sqf`.
- Client RPT scan for attachment or texture errors during fresh spawns and JIP.
- Server/client FPS comparison at high active vehicle count, because `WFBE_C_VEHICLE_MARKINGS` can attach multiple local lightpoints per vehicle and `WFBE_C_VEHICLE_FLAGS` attaches a flag object per vehicle.
- Visual review that WEST matte-black hulls, side recognition glows, and attached flags are readable without making the battlefield noisy.

### Smuggler

Required proof before enabling:

- A concrete implementation branch that registers `WFBE_C_SMUGGLER_ENABLE` in `Init_CommonConstants.sqf`.
- Server-side spawn, cleanup, reward, and failure handling with no dependency on the old concept-only notes in `UNUSED-ASSETS.md`.
- A default-off smoke showing flag 0 is byte-inert and flag 1 produces the intended encounter.

### Walls v2

No enablement gate is recommended. The current source describes `WFBE_C_WALLS_V2`
as a dead registration kept for stale host-profile safety. A cleanup lane can
decide whether to leave the tombstone or remove the stale references after profile
compatibility is no longer needed.

## Verification

- `rg -n "WFBE_C_SMUGGLER_ENABLE" -S .` returned no matches on this base.
- `rg -n "WFBE_C_(SMUGGLER_ENABLE|ENDGAME_FORCE_ENABLE|AICOM_FUNDS_SINK_ENABLE|VEHICLE_MARKINGS|VEHICLE_FLAGS|WALLS_V2)" -S Missions/[55-2hc]warfarev2_073v48co.chernarus docs` was used for the source inventory.
- The PR is docs-only; no SQF, SQM, HPP, EXT, generated mirror, package, or deploy file changed.
- LoadoutManager was not run because no mission files changed.
