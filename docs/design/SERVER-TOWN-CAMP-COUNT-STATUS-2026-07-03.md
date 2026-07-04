# Server Town Camp-Count Status

Fleet lane 134 flags `server_town.sqf` dividing by `GetTotalCamps` with no zero guard, which would crash or miscompute capture rate for a town with no camps.

Status: already represented in the current `claude/build84-cmdcon36` target source. This note is docs-only; it does not change mission source, mirrors, package output, or live runtime state.

## Current Source Anchors

The maintained mission copies carry the same guarded camp-ratio block:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town.sqf:212-218`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/server_town.sqf:212-218`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/FSM/server_town.sqf:212-218`

The code first resolves the divisor:

```sqf
_totalCamps = _location Call WFBE_CO_FNC_GetTotalCamps;
```

It then divides only when the divisor is positive:

```sqf
if (_totalCamps > 0) then {
	_rate = _town_capture_rate * (([_location,_newSide] Call WFBE_CO_FNC_GetTotalCampsOnSide) / _totalCamps) * _town_camps_capture_rate;
} else {
	_rate = _town_capture_rate * _town_camps_capture_rate;
};
```

That covers the lane 134 failure mode: zero-camp towns do not use `_totalCamps` as a divisor, and instead receive the unscaled fallback camp capture rate.

## Status Call

No source patch is recommended for lane 134 from this branch. The current source has the required `_totalCamps > 0` guard and zero-camp fallback across Chernarus, Takistan, and Zargabad.

## Follow-Up

The remaining useful proof is a targeted runtime smoke with a zero-camp location: trigger the classic capture path and confirm the town uses the fallback rate without an RPT arithmetic error.
