# Lane 123 Town Patrol SV60 Audit

Date: 2026-07-02
Target: `origin/claude/build84-cmdcon36`
Lane: 123 - AI6 patrol switch fall-through

## Verdict

Lane 123 is already fixed on the current live lane. The prompt row says `Server_GetTownPatrol.sqf` falls through at exactly `supplyValue == 60`, but both maintained roots now include the equality case in the HEAVY patrol branch.

No source patch is needed for this lane.

## Evidence

The maintained Chernarus source reads the town `supplyValue`, maps it into `LIGHT`, `MEDIUM`, or `HEAVY`, then looks up `WFBE_<side>_PATROL_<type>`:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownPatrol.sqf:14` reads `_sv = _town getVariable "supplyValue";`.
- `.../Server_GetTownPatrol.sqf:18` handles the medium interval with `_sv > 30 && _sv < 60`.
- `.../Server_GetTownPatrol.sqf:19` handles `_sv >= 60`, with an inline note that this includes `SV==60`.
- `.../Server_GetTownPatrol.sqf:22` uses the resolved `_type` in the patrol-array lookup.

The maintained Takistan mirror has the same threshold and lookup anchors:

- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_GetTownPatrol.sqf:18` handles `_sv > 30 && _sv < 60`.
- `.../Server_GetTownPatrol.sqf:19` handles `_sv >= 60`, again noting that the equality case closes the old nil switch gap.
- `.../Server_GetTownPatrol.sqf:22` uses the resolved `_type` in the same `WFBE_<side>_PATROL_<type>` lookup.

The current ranges are therefore contiguous:

- `0..30`: `LIGHT`
- `31..59`: `MEDIUM`
- `60+`: `HEAVY`

An exact 60-SV town cannot leave `_type` nil in the current target.

## Scope

This audit is documentation-only. It does not change mission source, generated mirror output, runtime defaults, package artifacts, or live server state.

`Tools/LoadoutManager` was not run because no maintained Chernarus mission source changed.

## Recommended Disposition

Treat lane 123 as stale/resolved for `origin/claude/build84-cmdcon36`. If this row resurfaces, the regression check is simply:

```powershell
rg -n "_sv > 30 && _sv < 60|_sv >= 60|WFBE_.*PATROL_" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownPatrol.sqf" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_GetTownPatrol.sqf"
```
