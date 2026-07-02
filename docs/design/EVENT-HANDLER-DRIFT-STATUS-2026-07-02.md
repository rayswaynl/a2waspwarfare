# Event Handler Drift Status - 2026-07-02

Lane: 130, NJ7 event-handler drift.

## Result

Current target already carries both parts of the lane 130 fix. No mission source change is needed.

The live base for this audit is `origin/claude/build84-cmdcon36@ca278c4bc`. The duplicate `HandleAT` `Fired` event handler was removed by commit `1ad62bf4a`, and the respawn-time rocket tracer handler was restored by merged PR #213:

- PR #213: `[codex] Restore rocket tracer Fired EH on respawn`
- Branch: `codex/lane130-rocket-tracer-respawn-eh`
- Merge commit: `ed5de51af130c8261b50a7e16c4ac40689c4bf36`
- Fix commit: `3e3c4448f8`

Both `1ad62bf4a` and `3e3c4448f8` are ancestors of the current lane base.

## Current Source Evidence

`Init_Client.sqf` attaches the initial player `Fired` handlers once near startup:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf:71`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Init/Init_Client.sqf:71`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Init/Init_Client.sqf:71`

Each maintained root also carries the duplicate-handler removal note where the second legacy `HandleAT` attach used to live:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf:495`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Init/Init_Client.sqf:495`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Init/Init_Client.sqf:495`

`Client_PreRespawnHandler.sqf` now reattaches both fired handlers after respawn:

- `:13` reattaches `HandleAT`.
- `:14` reattaches `HandleRocketTraccer`.

The three maintained copies hash-match for each audited file:

- `Init_Client.sqf`: `28EFC31FED3E0BE51709CDF91A9AD47369C0931003EFD0598F08C670A2C09315`
- `Client_PreRespawnHandler.sqf`: `DE9813B12341D4F230382A44375D43B39669F577EA840A47D076630132996933`

## Wiki And Prompt Drift

The lane 130 prompt row still describes `Init_Client.sqf` duplicate `HandleAT` attachment and missing `HandleRocketTracer` respawn restoration as if they are current defects.

Current source shows the duplicate `HandleAT` attach has already been removed, and the respawn handler now restores the intentionally misspelled mission function `HandleRocketTraccer` in Chernarus, Takistan and Zargabad.

## Runtime Smoke To Keep

When a client runtime packet is available, confirm:

- Firing an AT weapon after initial join invokes a single `HandleAT` path, not two.
- After player respawn, AT handling still works.
- After player respawn, rocket tracer handling still works.
- No new client RPT errors appear around `HandleAT`, `HandleRocketTraccer`, `Client_PreRespawnHandler.sqf`, or `Init_Client.sqf`.

## Out Of Scope

This report does not change death flow, respawn flow, SkinSelector, death-camera behavior, fired-handler implementation, live runtime settings or package artifacts.
