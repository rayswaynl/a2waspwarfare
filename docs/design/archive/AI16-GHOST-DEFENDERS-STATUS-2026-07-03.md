# AI16 Ghost Defenders Status

Fleet lane 118 flags `Server_HandleDefense.sqf` re-manning statics after an area changes hands, leaving defenders permanently occupying enemy-owned territory.

Status: already represented in the current `claude/build84-cmdcon36` target source. This note is docs-only; it does not change mission source, mirrors, package output, or live runtime state.

## Current Source Anchors

The maintained mission copies carry the same AI16 guard chain:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Construction/Construction_StationaryDefense.sqf:121-123`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Construction/Construction_StationaryDefense.sqf:121-123`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Construction/Construction_StationaryDefense.sqf:121-123`

When a manned base static is placed, the constructor stamps the base-area logic on the defense:

```sqf
_defense setVariable ["WFBE_DefenseBaseArea", _area];
```

`Server_HandleDefense.sqf` then uses that stamp before creating another gunner:

- `Server/Functions/Server_HandleDefense.sqf:17-20` adds `_sideStillValid` and keeps the manning loop conditional on it.
- `Server/Functions/Server_HandleDefense.sqf:25-37` reads `WFBE_DefenseBaseArea`, fetches the area's `DefenseTeam`, and sets `_sideStillValid = false` when `side _areaTeam != _side`.
- The loop exits before creating a replacement gunner once the stamped area belongs to another side.

Those anchors exist in Chernarus, Takistan, and Zargabad at the same line ranges.

There is also capture-side cleanup in `Server/FSM/server_town.sqf:352-360` across the same three mission copies: the old side's `WFBE_%1_DefenseTeam` units are deleted and town defenses are removed during the capture transition.

## Status Call

No source patch is recommended for lane 118 from this branch. The current source already has the two pieces the lane needs:

- A placement-time owner/area stamp on manned base static defenses.
- A re-manning loop exit when the stamped area's `DefenseTeam` no longer belongs to the original side.

## Follow-Up

The remaining useful proof is runtime soak, not another source edit: place or observe manned statics for a side, flip the associated area/town to another side, kill the old gunner, and confirm `Server_HandleDefense.sqf` logs the changed-hands stop message instead of spawning a fresh defender for the old owner.
