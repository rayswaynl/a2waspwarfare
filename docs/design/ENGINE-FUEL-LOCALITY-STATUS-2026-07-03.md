# Engine Fuel Locality Status

Fleet lane 124 / V4 flags stealth-engine fuel being saved as local-only state, so a locality transfer could lose the original fuel value before `Startengine.sqf` restores it.

Status: already represented in the current `claude/build84-cmdcon36` target source. This note is docs-only; it does not change mission source, mirrors, package output, or live runtime state.

## Current Source Anchors

The maintained mission copies save the fuel value with a public vehicle variable:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Engines/Engine.sqf:8`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Module/Engines/Engine.sqf:8`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Module/Engines/Engine.sqf:8`

```sqf
_vehicle setVariable ["Fuel",fuel _vehicle,true];
```

The third argument is `true`, so the saved `Fuel` variable is broadcast rather than client-local.

The matching restore path is also present in all three copies:

- `Client/Module/Engines/Startengine.sqf:4` reads `_fuel = _vehicle getVariable 'Fuel';`
- `Client/Module/Engines/Startengine.sqf:5` restores `_vehicle setFuel _fuel;`

`Startengine.sqf:7-10` still treats the separate `"stopped"` state as flag-controlled:

```sqf
if ((missionNamespace getVariable ["WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC", 0]) > 0) then {
	_vehicle setVariable ["stopped",false,true];
} else {
	_vehicle setVariable ["stopped",false];
};
```

`Common/Init/Init_CommonConstants.sqf:1335` defaults `WFBE_C_FIX_ENGINE_STEALTH_STATE_PUBLIC = 0`, so stopped-state publicization remains an explicit opt-in. That is separate from lane 124's saved fuel value, which is already public.

## Status Call

No source patch is recommended for lane 124 from this branch. The current source has the required public saved-fuel write and restore path across Chernarus, Takistan, and Zargabad.

## Follow-Up

The remaining useful proof is a runtime locality smoke: stop an eligible vehicle's engine, force or observe a locality transfer, use the stealth-off action, and confirm the vehicle restores the pre-stop fuel level rather than losing it.
