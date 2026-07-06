# SG11 Malicious Supply Warning Status

Fleet lane 131 flags `Server_BuildingKilled.sqf` passing an empty reason string into `ChangeSideSupply`, causing normal guerrilla-barracks supply awards to log the generic "malicious supply update" warning.

Status: already represented in the current `claude/build84-cmdcon36` target source. This note is docs-only; it does not change mission source, mirrors, package output, or live runtime state.

## Current Source Anchors

The maintained mission copies now pass named reasons from the building-kill reward paths:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_BuildingKilled.sqf:74`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_BuildingKilled.sqf:74`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_BuildingKilled.sqf:74`

```sqf
[_side_killer, 500, "GUER FOB barracks cleared", false] Call ChangeSideSupply
```

- `Server/Functions/Server_BuildingKilled.sqf:87` in all three copies:

```sqf
[_side_killer, _supplies, "GUER barracks bounty", false] Call ChangeSideSupply;
```

The same files also use a named reason for the bank side-supply award at line 137:

```sqf
[(side group _killer), 10000, "Bank destruction", false] Call ChangeSideSupply;
```

`Server/Functions/Server_ChangeSideSupply.sqf:33-34` still converts non-string reasons and substitutes the generic warning text when a caller actually passes an empty string. That fallback remains useful for malformed or suspicious callers; lane 131 is specifically about the normal `Server_BuildingKilled.sqf` reward paths no longer triggering it.

## Status Call

No source patch is recommended for lane 131 from this branch. The current source has the required caller-side named reasons across Chernarus, Takistan, and Zargabad.

## Follow-Up

The remaining useful proof is runtime/RPT smoke: destroy a resistance barracks or clear a GUER FOB factory, confirm the side supply award logs `GUER barracks bounty` or `GUER FOB barracks cleared`, and confirm the generic malicious-supply warning does not appear for that normal reward path.
