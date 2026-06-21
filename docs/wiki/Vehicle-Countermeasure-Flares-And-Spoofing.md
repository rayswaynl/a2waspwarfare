# Vehicle Countermeasure Module (Flares and Missile Spoofing)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The CM module (`Client/Module/CM/`, by Maddmatt) is the **vanilla-Arma-2** vehicle countermeasure system: when an air vehicle is locked by a guided missile it ejects flares from its model's `flare_launcher` selections and probabilistically spoofs the incoming round by jittering the missile's heading. It is a client-local, vanilla-only system gated by `WFBE_C_MODULE_WFBE_FLARES`. It is **distinct** from the IRS IR-smoke module (`Common/Module/IRS/`, ground vehicles, `irLock` ammo) which has its own page and explicitly disclaims the CM module (`IRS-IR-Smoke-Missile-Countermeasure.md`).

## Module gate and the two code paths

The CM module only compiles and wires up under the **vanilla** branch. On Operation Arrowhead the module is never compiled; instead built aircraft have their native OA countermeasure magazines stripped when the gate is off.

| Path | Condition | Effect | Citation |
|---|---|---|---|
| Compile CM functions | `WFBE_C_MODULE_WFBE_FLARES > 0 && WF_A2_Vanilla` | Calls `CM_Init.sqf` (compiles `CM_Countermeasures`, `CM_Flares`, `CM_Spoofing`) | `Client/Init/Init_Client.sqf:664`; `Client/Module/CM/CM_Init.sqf:1-3` |
| Module constant default | `WFBE_C_MODULE_WFBE_FLARES = 1` | `0`: disabled, `1`: enabled-with-upgrade, `2`: always enabled | `Common/Init/Init_CommonConstants.sqf:406` |
| OA removal | `!WF_A2_Vanilla`, module `0` or side lacks upgrade | `WFBE_CO_FNC_RemoveCountermeasures` strips native CM magazines | `Client/Functions/Client_BuildUnit.sqf:351-360` |

The OA removal helper inspects the built aircraft's config and removes any `60/120/240Rnd_CMFlare[_Chaff]_Magazine` turret magazines when `CMFlareLauncher` is among its weapons (`Common/Functions/Common_RemoveCountermeasures.sqf:11-17`). On vanilla, `WFBE_CO_FNC_RemoveCountermeasures` is bound to an empty closure (`Common/Init/Init_Common.sqf:156`), so the script CM system below is the only countermeasure on vanilla.

## Wiring: how a vehicle gets the system

Each unit's init applies the CM event handler in the vanilla branch, switching on the module mode:

| Mode | Behavior | Citation |
|---|---|---|
| `1` (enabled-with-upgrades) | Only if the side owns `WFBE_UP_FLARESCM`: ExecVM `CM_Set.sqf`, add `incomingMissile` EH `{_this Spawn CM_Countermeasures}` | `Common/Init/Init_Unit.sqf:102-107` |
| `2` (enabled) | Always: ExecVM `CM_Set.sqf`, add the same `incomingMissile` EH | `Common/Init/Init_Unit.sqf:108-111` |

The vanilla branch is itself gated on `WFBE_C_MODULE_WFBE_FLARES > 0 && WF_A2_Vanilla` (`Common/Init/Init_Unit.sqf:100`). The OA build path adds an unrelated `IncomingMissile` EH to `HandleAlarm` only when the aircraft's `incommingmissliedetectionsystem` config value `> 8` (`Client/Functions/Client_BuildUnit.sqf:350`) — that is a separate alarm system, not the CM flare pump.

## Per-vehicle state: FlareCount and FlareActive

`CM_Set.sqf` seeds two object variables on the vehicle after `commonInitComplete` plus a 2s settle delay:

| Variable | Initial value | Meaning | Citation |
|---|---|---|---|
| `FlareCount` | `WFBE_C_UNITS_COUNTERMEASURE_PLANES` if `isKindOf "Plane"`, else `..._CHOPPERS` | Remaining flares this vehicle can dispense | `Client/Module/CM/CM_Set.sqf:7-8` |
| `FlareActive` | `false` | Re-entrancy lock so a single incoming missile triggers only one volley | `Client/Module/CM/CM_Set.sqf:9` |

If the vehicle is `isNull` the script exits without seeding (`Client/Module/CM/CM_Set.sqf:4`).

### Default capacities

| Constant | Default | Applies to | Citation |
|---|---|---|---|
| `WFBE_C_UNITS_COUNTERMEASURE_PLANES` | `64` | Fixed-wing (`isKindOf "Plane"`) | `Common/Init/Init_CommonConstants.sqf:531` |
| `WFBE_C_UNITS_COUNTERMEASURE_CHOPPERS` | `32` | Helicopters / other `Air` | `Common/Init/Init_CommonConstants.sqf:532` |

### Rearm reset

`Common_RearmVehicle.sqf` (the vanilla rearm path; on OA `RearmVehicle` binds to `Common_RearmVehicleOA.sqf` instead — `Common/Init/Init_Common.sqf:76`) re-seeds `FlareCount` whenever an `Air` vehicle is rearmed, switching on the same module mode and re-applying the plane/chopper default:

| Mode | Rearm reset | Citation |
|---|---|---|
| `1` | Re-seed only if side owns `WFBE_UP_FLARESCM` | `Common/Functions/Common_RearmVehicle.sqf:19-24` |
| `2` | Always re-seed to plane/chopper default | `Common/Functions/Common_RearmVehicle.sqf:25-28` |

## Incoming-missile detection (CM_Countermeasures)

The `incomingMissile` event handler spawns `CM_Countermeasures` with `[_vehicle, _missile]`. The handler gates and fires the flare volley:

| Step | Condition / action | Citation |
|---|---|---|
| Altitude gate | `alive _vehicle` and `(getPos _vehicle) select 2 > 5` (above 5 m AGL) | `Client/Module/CM/CM_Countermeasures.sqf:5` |
| AirLock detection | Reads `CfgAmmo >> _missile >> AirLock`; proceeds only if `== 1` (an air-locking, i.e. radar/IR-guided, round) | `Client/Module/CM/CM_Countermeasures.sqf:7-8` |
| Re-entrancy | Proceeds only if `FlareActive` is false; immediately sets it `true` | `Client/Module/CM/CM_Countermeasures.sqf:6,8,10` |
| Driver warning | If `driver _vehicle == player`, `vehicleChat "WARNING: incomming missile!"` | `Client/Module/CM/CM_Countermeasures.sqf:11` |
| Flares available? | Only if `FlareCount > 0` does it dispense | `Client/Module/CM/CM_Countermeasures.sqf:12-13` |
| Spoofing | `_this Spawn CM_Spoofing` (with `[_vehicle, _ammo, _enemy]`) | `Client/Module/CM/CM_Countermeasures.sqf:14` |
| Flare volley | Loop `_i = 0` while `_i < 8`: `[_vehicle] Call CM_Flares; sleep 0.3` (8 bursts at 0.3 s) | `Client/Module/CM/CM_Countermeasures.sqf:15-18` |
| Release lock | `FlareActive` set back to `false` after the volley | `Client/Module/CM/CM_Countermeasures.sqf:20` |

Note the EH passes the whole `_this` array to `CM_Spoofing` (`[_vehicle, _ammo, _enemy]`), but only `[_vehicle]` to each `CM_Flares` call.

## Flare deployment (CM_Flares)

Each `CM_Flares` call dispenses one flare per `flare_launcher` selection found on the vehicle model and spawns the visual emitters:

| Element | Value / behavior | Citation |
|---|---|---|
| Muzzle velocity | `25` m/s baseline; `150` if `isKindOf "Plane"` | `Client/Module/CM/CM_Flares.sqf:6-7` |
| Launcher discovery | Counts `flare_launcher%1` selections (starting at 1) until `selectionPosition` returns `[0,0,0]` | `Client/Module/CM/CM_Flares.sqf:8-9` |
| Per-launcher decrement | `FlareCount = FlareCount - 1` each launcher iteration | `Client/Module/CM/CM_Flares.sqf:12-13` |
| Flare object | `"FlareCountermeasure" createVehicleLocal` at the launcher world position; velocity = launch direction (`flare_launcher%1_dir`) × muzzle velocity + vehicle velocity | `Client/Module/CM/CM_Flares.sqf:14-22` |
| Smoke emitter | `#particlesource` billboard (Universal particle set) at the flare, `setDropInterval 0.02` | `Client/Module/CM/CM_Flares.sqf:25-28` |
| Spark emitter | second `#particlesource`, `setDropInterval 0.001` | `Client/Module/CM/CM_Flares.sqf:30-33` |
| Light point | `#lightpoint` attached to the flare, amber color `[1, 0.5, 0.2]`, brightness `0.1` | `Client/Module/CM/CM_Flares.sqf:35-39` |
| Auto-cleanup | All emitters + flares `spawn { sleep 4.5 + random 1; deleteVehicle each }` | `Client/Module/CM/CM_Flares.sqf:43-45` |

Because `CM_Countermeasures` calls `CM_Flares` 8 times and `CM_Flares` decrements `FlareCount` once per `flare_launcher` selection, a single incoming-missile event spends `8 ×` (number of launcher selections) flares from the pool. All objects are `createVehicleLocal` / local emitters, so the effect is purely client-side and not network-replicated.

## Missile spoofing (CM_Spoofing)

Run in parallel with the flare volley, `CM_Spoofing` attempts to defeat the tracking missile by perturbing its heading:

| Step | Condition / action | Citation |
|---|---|---|
| Engine gate | Only if `alive _vehicle && isEngineOn _vehicle` | `Client/Module/CM/CM_Spoofing.sqf:7` |
| Acquire missile | `_missile = nearestObject [_enemy, _ammo]` | `Client/Module/CM/CM_Spoofing.sqf:8` |
| Arming trigger | `waitUntil { (_missile distance _vehicle) < (speed _vehicle) * 1.5 }` (waits until the round closes to within ~1.5 s of the vehicle's own speed) | `Client/Module/CM/CM_Spoofing.sqf:9` |
| Defeat probability | `_prob = 25 + random 75` vs `_chance = random 100`; spoof only if `_prob > _chance` | `Client/Module/CM/CM_Spoofing.sqf:10-12` |
| Jitter loop | While `alive _missile`: `_missile setDir ((getDir _missile) + (random 20 - 10)); sleep 0.1` (±10° random heading wobble every 0.1 s) | `Client/Module/CM/CM_Spoofing.sqf:13-16` |

The probability band is **25–100%** (`25 + random 75`), so the spoof succeeds on average ~62.5% of the time and is never below a 25% floor. When it succeeds, the missile's heading is continuously nudged within ±10° until it detonates or despawns, which tends to throw it off the lock.

## Upgrade gate: WFBE_UP_FLARESCM

The CM system in mode `1` is gated by the per-side upgrade `WFBE_UP_FLARESCM`, which is upgrade index **9**.

| Fact | Value | Citation |
|---|---|---|
| Index constant | `WFBE_UP_FLARESCM = 9` | `Common/Init/Init_CommonConstants.sqf:46` |
| Upgrade label | "Custom Flares" (enabled when module `== 1`) | `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:15` |
| Research cost | single level, `[[4500,0]]` (4500 funds / 0 supply) | `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:42` |
| Prerequisite | `[[WFBE_UP_AIR,2]]` (Air upgrade level 2) | `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:102` |
| Research time | `[100]` | `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:134` |

The same module gate `WFBE_C_MODULE_WFBE_FLARES == 1` also unlocks a sibling upgrade, **Aircraft AA Missiles** (label at `Upgrades_CO_US.sqf:25`, cost `[[7500,0]]` at `:53`, prereq `[[WFBE_UP_AIR,3]]` at `:117`, time `[120]` at `:145`) — both flare countermeasures and aircraft AA missiles are tied to the same `WFBE_C_MODULE_WFBE_FLARES` parameter being `1`. East-side and other-faction upgrade files carry the parallel `[WFBE_UP_FLARESCM,1]` research-order entry (e.g. `Common/Config/Core_Upgrades/Upgrades_CO_RU.sqf:176`).

## Notes and edge cases

- **Vanilla-only.** The script CM system never runs on OA; OA aircraft instead rely on (or have stripped) their native engine countermeasure magazines via `WFBE_CO_FNC_RemoveCountermeasures` (`Client/Functions/Client_BuildUnit.sqf:351-360`).
- **5 m AGL floor.** A missile fired at a landed or near-ground aircraft will not trigger flares (`CM_Countermeasures.sqf:5`).
- **AirLock filter.** Only rounds whose `CfgAmmo` `AirLock == 1` trigger the system; non-air-locking ordnance is ignored (`CM_Countermeasures.sqf:7-8`).
- **Spoofing needs the engine on.** `CM_Spoofing` exits silently if the engine is off, even though flares may still deploy (`CM_Spoofing.sqf:7`).

## Continue Reading

- [IRS IR-Smoke Missile Countermeasure](IRS-IR-Smoke-Missile-Countermeasure) — the ground-vehicle smoke counterpart that explicitly distinguishes itself from this CM module
- [Modules Atlas](Modules-Atlas) — the one-paragraph CM gate pointer and the surrounding client gameplay-module index
- [Upgrades And Research Atlas](Upgrades-And-Research-Atlas) — how `WFBE_UP_*` upgrade indices, costs, prerequisites and research times are structured
- [Faction Root Variables Reference](Faction-Root-Variables-Reference) — per-faction `WFBE_%1*` variable catalog that the module gates read against
- [Support Specials And Tactical Modules Atlas](Support-Specials-And-Tactical-Modules-Atlas) — broader index of the client-side tactical/support modules
