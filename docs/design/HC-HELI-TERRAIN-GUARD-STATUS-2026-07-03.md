# HC Heli Terrain Guard Status - 2026-07-03

Lane: 94, Port heli terrain-guard to HC

Base checked: `origin/claude/build84-cmdcon36@b1608b096`.

Scope: docs-only status. No aircraft source, AICOM source, `AI-MODS-AND-PATHFINDING.md`, generated mirror, package artifact, or live server was changed.

## Verdict

The HC terrain-guard port is source-present on the current live lane.

The prompt asks for `Headless/headless_heli_terrain_guard.sqf`, but the current implementation uses a shared helper instead: `Common/Functions/Common_AICOM_HeliTerrainGuard.sqf`. That helper is spawned from both server init and HC init, so it covers AICOM helicopter teams wherever the hulls are local while preserving the original server-local world scan for non-team air.

## Current Source Path

| Surface | Current evidence | Status |
| --- | --- | --- |
| HC launch | `Headless/Init/Init_HC.sqf:245-251` explicitly documents the old server-only gap and spawns `Common\Functions\Common_AICOM_HeliTerrainGuard.sqf`. | Source-present in Chernarus and Takistan. |
| Server launch | `Server/Init/Init_Server.sqf:1049-1055` still runs `Server\server_heli_terrain_guard.sqf` for server-local air and also spawns the shared AICOM team helper for server-local team air. | Source-present in Chernarus and Takistan. |
| Shared helper | `Common/Functions/Common_AICOM_HeliTerrainGuard.sqf:18-25` walks side-logic `wfbe_teams` and acts only on local `Helicopter` hulls. `:27-33` says the look-ahead climb is reused from the server guard. `:73-87` performs the local heli check and raises `flyInHeight` only when terrain ahead violates clearance. | Source-present. |
| Server-only legacy guard | `Server/server_heli_terrain_guard.sqf:11-16` remains server-gated and flag-gated; it still scans `vehicles` for server-local AI helis. | Preserved for non-team/server-local air. |
| Shared flag and tunables | `Common/Init/Init_CommonConstants.sqf:1475-1477` defines `WFBE_C_AIHELI_TERRAIN_GUARD = 1`, look-ahead `250`, and clearance `60`. | One flag toggles both server and common helper paths. |

## Routing

No source PR is needed for lane 94 unless runtime RPT evidence proves the helper does not start on an HC.

Use these proof tokens for a live smoke:

- `Common_AICOM_HeliTerrainGuard.sqf: AICOM-heli terrain guard started (HC, look-ahead ...`
- `Common_AICOM_HeliTerrainGuard.sqf: AICOM-heli terrain guard started (SERVER, look-ahead ...`
- `server_heli_terrain_guard.sqf: AI-heli terrain guard ON ...`

Leave `docs/design/AI-MODS-AND-PATHFINDING.md` drift to the active lane-68 design-doc owner. This note only records the current lane-94 source state and avoids touching aircraft or AICOM behavior.

No LoadoutManager run is needed for this status note.
