# Engine Stealth Fuel Toggle Reference

> Source provenance: checked 2026-06-21 against stable `master@0139a346`, Arma 2 OA 1.64, source mission `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

The Engines module is the "STEALTH ON" / "STEALTH OFF" vehicle fuel toggle under `Client/Module/Engines`. The live source path is small but stateful: eligible tanks and wheeled APCs receive an `Engine` event handler and a `STEALTH ON` action, the stop action forces the engine off, the event handler drains fuel to zero after saving the old fuel value, and the start action restores that saved fuel (`Client/Functions/Client_BuildUnit.sqf:417-418`; `Client/Module/Engines/Stopengine.sqf:2-7`; `Client/Module/Engines/Engine.sqf:3-11`; `Client/Module/Engines/Startengine.sqf:2-7`).

## Entry Points

| Source surface | What the current source does | Evidence |
| --- | --- | --- |
| Purchased player vehicles | After player vehicle construction, any vehicle that is `Tank` or `Wheeled_APC` receives an `Engine` event handler executing `Client\Module\Engines\Engine.sqf` and a `STEALTH ON` action executing `Client\Module\Engines\Stopengine.sqf`. The action condition requires the target to be alive and `isEngineOn _target`. | `Client/Functions/Client_BuildUnit.sqf:417-418` |
| WASP extra start vehicles, west side | The west-side WASP extra start vehicle path creates a random `WEST_StartVeh`, then applies the same `Tank` / `Wheeled_APC` engine handler and `STEALTH ON` action block. | `Server/Init/Init_Server.sqf:504-522` |
| WASP extra start vehicles, east side | The east-side WASP extra start vehicle path creates a random `EAST_StartVeh`, then applies the same `Tank` / `Wheeled_APC` engine handler and `STEALTH ON` action block. | `Server/Init/Init_Server.sqf:524-540` |
| Refuel service integration | The refuel helper reads the vehicle's `stopped` variable before doing any refuel timing and exits with the raw hint `Quit the stealth mode !` when the value is true. If it proceeds and a support remains in range, the helper eventually calls `setFuel 1`. | `Client/Functions/Client_SupportRefuel.sqf:8-12`; `Client/Functions/Client_SupportRefuel.sqf:60-79` |

## Toggle Flow

| Step | Source behavior | Evidence |
| --- | --- | --- |
| `STEALTH ON` action | `Stopengine.sqf` resolves the caller's current vehicle, stores the action id in vehicle variable `ID`, calls `EngineOn false`, and sets vehicle variable `stopped` to `true`. | `Client/Module/Engines/Stopengine.sqf:2-7` |
| Engine event follow-up | `Engine.sqf` receives the vehicle and the new engine state. It only proceeds when vehicle variable `ID` exists, and only saves/drains fuel when `_isOn` is false. | `Client/Module/Engines/Engine.sqf:3-7` |
| Fuel save and forced shutdown state | On the engine-off event, `Engine.sqf` stores `fuel _vehicle` in vehicle variable `Fuel`, calls `setFuel 0`, adds a `STEALTH OFF` action pointing at `Startengine.sqf`, then clears vehicle variable `ID`. | `Client/Module/Engines/Engine.sqf:8-11` |
| `STEALTH OFF` action | `Startengine.sqf` resolves the caller's current vehicle, reads vehicle variable `Fuel`, restores it with `setFuel _fuel`, removes the current action id, and sets vehicle variable `stopped` to `false`. | `Client/Module/Engines/Startengine.sqf:2-7` |

## Vehicle State Keys

| Vehicle variable | Writer | Reader | Practical note |
| --- | --- | --- | --- |
| `ID` | `Stopengine.sqf` stores the current action id; `Engine.sqf` clears it after the engine event is handled. | `Engine.sqf` checks whether `ID` exists before saving/draining fuel. | The source shape prevents ordinary engine-off events from running the fuel-save path unless `Stopengine.sqf` first staged an action id. Evidence: `Client/Module/Engines/Stopengine.sqf:4-5`; `Client/Module/Engines/Engine.sqf:5-11`. |
| `Fuel` | `Engine.sqf` stores the current fuel value only inside the `_isOn == false` branch. | `Startengine.sqf` reads `Fuel` and immediately passes it to `setFuel`. | There is no fallback value in `Startengine.sqf` if a future source change lets the start action run without a stored `Fuel` value. Evidence: `Client/Module/Engines/Engine.sqf:7-10`; `Client/Module/Engines/Startengine.sqf:4-5`. |
| `stopped` | `Stopengine.sqf` writes `true`; `Startengine.sqf` writes `false`. | `Client_SupportRefuel.sqf` reads `stopped` before starting the refuel flow. | The current refuel guard is checked at entry, before the refuel timing loop; the loop later refuels only if support remained in range. Evidence: `Client/Module/Engines/Stopengine.sqf:7`; `Client/Module/Engines/Startengine.sqf:7`; `Client/Functions/Client_SupportRefuel.sqf:8-9,60-79`. |

All three module variables above are written with two-argument `setVariable` calls in the current source. Do not treat `Fuel`, `ID`, or `stopped` as intentionally published object state unless a future code change adds an explicit publication path and then smoke-tests owner changes, refuel service behavior, and start/stop actions (`Client/Module/Engines/Stopengine.sqf:5,7`; `Client/Module/Engines/Engine.sqf:8,11`; `Client/Module/Engines/Startengine.sqf:7`). For Arma locality, compare the missing public argument against Bohemia's [`setVariable`](https://community.bistudio.com/wiki/setVariable) reference.

The mission variable name `"stopped"` is separate from the Arma `stopped` command used by AI and travel diagnostics elsewhere. Engine-stealth writers/readers are the `Stopengine.sqf`, `Startengine.sqf` and `Client_SupportRefuel.sqf` variable accesses above; unrelated command/state-string hits include `Client/GUI/GUI_Menu_Tactical.sqf:408`, `Client/Functions/Client_DiagnosePlayerAI.sqf:197-199` and `Server/AI/Commander/AI_Commander.sqf:252-255`.

## Smoke Targets

| Check | Expected source-backed result | Evidence |
| --- | --- | --- |
| Purchased tank or wheeled APC action appears only while alive and engine-on. | The purchased-vehicle attach block gates on `Tank` / `Wheeled_APC` and the action condition requires `alive _target &&(isEngineOn _target)`. | `Client/Functions/Client_BuildUnit.sqf:417-418` |
| `STEALTH ON` stages the engine-off fuel-drain path. | The stop action stores `ID`, calls `EngineOn false` and marks `stopped=true`; the Engine EH then saves `Fuel`, calls `setFuel 0` and adds `STEALTH OFF`. | `Client/Module/Engines/Stopengine.sqf:5-7`; `Client/Module/Engines/Engine.sqf:5-10` |
| `STEALTH OFF` restores fuel and clears the refuel guard. | The start action reads `Fuel`, calls `setFuel _fuel`, removes the current action and marks `stopped=false`; refuel exits only when `stopped` is true. | `Client/Module/Engines/Startengine.sqf:4-7`; `Client/Functions/Client_SupportRefuel.sqf:8-9` |
| WASP extra start vehicles keep the same attach path. | West and East extra start vehicles both run the `Tank` / `Wheeled_APC` Engine EH and `STEALTH ON` action attach during server init. | `Server/Init/Init_Server.sqf:504-522`; `Server/Init/Init_Server.sqf:524-540` |

## Maintenance Notes

| If you touch... | Keep this invariant | Evidence |
| --- | --- | --- |
| Vehicle construction or start vehicles | Preserve both runtime edges: purchased tanks/wheeled APCs and WASP extra start vehicles currently attach the engine handler/action. | `Client/Functions/Client_BuildUnit.sqf:417-418`; `Server/Init/Init_Server.sqf:504-522`; `Server/Init/Init_Server.sqf:524-540` |
| Fuel restore behavior | Keep the saved-fuel and restored-fuel paths paired; `Engine.sqf` writes `Fuel`, and `Startengine.sqf` reads it before restoring the vehicle fuel value. | `Client/Module/Engines/Engine.sqf:8-10`; `Client/Module/Engines/Startengine.sqf:4-5` |
| Refuel service | Keep the stealth/refuel contract explicit. The service path currently blocks when `stopped` is true, then uses its normal support-range loop and final `setFuel 1` behavior. | `Client/Functions/Client_SupportRefuel.sqf:8-12`; `Client/Functions/Client_SupportRefuel.sqf:60-79` |

## Continue Reading

- [Modules atlas](Modules-Atlas)
- [Vehicle equip and rearm reference](Vehicle-Equip-And-Rearm-Function-Reference)
- [Service menu affordability guards](Service-Menu-Affordability-Guards)
- [Vehicle countermeasure flares and spoofing](Vehicle-Countermeasure-Flares-And-Spoofing)
- [Valhalla vehicle climbing assist](Valhalla-Vehicle-Climbing-Assist)
