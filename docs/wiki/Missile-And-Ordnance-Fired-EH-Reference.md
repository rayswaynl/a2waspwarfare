# Missile and Ordnance Fired-EH Reference (combat handler family)

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents fourteen compiled functions and one dead-code file (Common_HandleMissiles.sqf) that form the missile, ordnance, and air-combat enforcement layer: every handler in the `HandleAT` / `HandleAAMissiles` / `HandleShootBombs` family, the two utility strippers (`RemoveAAMissiles`, `RemoveCountermeasures`), the jet damage mechanic (`JetAADamage`), and the legacy dead-code file (`HandleMissiles`). All are compiled in `Common/Init/Init_Common.sqf` lines 6–68 and attached to vehicles in `Client/Functions/Client_BuildUnit.sqf` and `Common/Init/Init_Unit.sqf`.

---

## Compile Registry

All handler functions are compiled into bare global variables by `Common/Init/Init_Common.sqf`. The two utility functions use the `WFBE_CO_FNC_` naming convention; the handlers use legacy bare names.

| Global variable | Source file | Init_Common.sqf line |
|---|---|---|
| `HandleAT` | `Common/Functions/Common_HandleAT.sqf` | 16 |
| `HandleATMissiles` | `Common/Functions/Common_HandleATMissiles.sqf` | 11 |
| `HandleAAMissiles` | `Common/Functions/Common_HandleAAMissiles.sqf` | 12 |
| `HandleAlarm` | `Common/Functions/Common_HandleAlarm.sqf` | 14 |
| `HandleRocketTraccer` | `Common/Functions/Common_HandleRocketTracer.sqf` | 6 |
| `HandleReload` | `Common/Functions/Common_HandleReload.sqf` | 8 |
| `HandleCommanderReload` | `Common/Functions/Common_HandleCommanderReload.sqf` | 7 |
| `HandleATReload` | `Common/Functions/Common_HandleATReload.sqf` | 9 |
| `HandleJetAADamage` | `Common/Functions/Common_JetAADamage.sqf` | 13 |
| `HandleIncomingMissile` | `Common/Functions/Common_HandleIncomingMissile.sqf` | 66 |
| `HandleShootBombs` | `Common/Functions/Common_HandleShootBombs.sqf` | 67 |
| `HandleShootMissiles` | `Common/Functions/Common_HandleShootMissiles.sqf` | 68 |
| `WFBE_CO_FNC_RemoveAAMissiles` | `Common/Functions/Common_RemoveAAMissiles.sqf` | 146 |
| `WFBE_CO_FNC_RemoveCountermeasures` | `Common/Functions/Common_RemoveCountermeasures.sqf` | 147 |

`HandleATReloadVehicle` is compiled out: `Common/Init/Init_Common.sqf` line 10 has the compile call commented (`//HandleATReloadVehicle = ...`). `Common_HandleMissiles.sqf` exists on disk but is never compiled or referenced; it is dead code (see Known Bugs section).

---

## Range / Gameplay Constants

Defined in `Common/Init/Init_CommonConstants.sqf` (via `with missionNamespace`) or `Rsc/Parameters.hpp`. All are lobby-configurable parameters.

| Constant | Code fallback (nil-guard) | Lobby default | Parameter values | Purpose |
|---|---|---|---|---|
| `WFBE_C_GAMEPLAY_MISSILES_RANGE` | `0` (`Init_CommonConstants.sqf`:238) | `3000` (`Rsc/Parameters.hpp`:307) | 0–10000 m (step 500) | Max incoming guided-missile range; 0 = disabled. Read by `HandleAlarm` and `HandleIncomingMissile`. The nil-guard fires only when no lobby parameter is set; in a normal hosted game the lobby value (default 3000) overrides it. |
| `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` | `—` (no nil-guard; lobby value always present) | `2000` (`Rsc/Parameters.hpp`:301) | 0–10000 m (step 500) | Player-to-target distance above which a bomb drop is deleted. 0 = disabled. Read by `HandleShootBombs`. |
| `WFBE_C_JET_AA_SURVIVE` | `1` (`Init_CommonConstants.sqf`:340) | lobby parameter absent — nil-guard value is the runtime value | 0 / 1 | Enable the fuel-drain + two-hit mechanic for jets hit by SPAAG. Read by `Client_BuildUnit.sqf`:325 before attaching `HandleJetAADamage`. |
| `WFBE_C_GAMEPLAY_AIR_AA_MISSILES` | `1` (`Init_CommonConstants.sqf`:233) | `2` (`Rsc/Parameters.hpp`:241) | 0 / 1 / 2 | 0 = remove AA missiles on spawn; 1 = require `WFBE_UP_AIRAAM` upgrade; 2 = always allowed. Governs `RemoveAAMissiles` call site. |
| `WFBE_C_MODULE_WFBE_FLARES` | `1` (`Init_CommonConstants.sqf`:253) | `2` (`Rsc/Parameters.hpp`:380) | 0 / 1 / 2 | 0 = remove CM on spawn; 1 = require `WFBE_UP_FLARESCM` upgrade; 2 = always allowed. Governs `RemoveCountermeasures` call site. |

---

## Handler Functions — Detail

### Common_HandleAT.sqf

**EH type:** `Fired` — attached to infantry and all vehicles on the local client at session start.

**Attachment point:** `Init_Client.sqf`:18 (`(vehicle player) addEventHandler ["Fired",{_this Spawn HandleAT}]`), `Init_Client.sqf`:281 (duplicate — see Known Bugs), and `Client_PreRespawnHandler.sqf`:13 (re-attached on respawn).

**`_this` params (Fired EH):** `[unit, weapon, muzzle, mode, ammo, magazine, projectile]`

| Local var | Index | Description |
|---|---|---|
| `_ammo` | `_this select 4` | Ammo class string |
| `_unit` | `_this select 0` | Firing unit |
| `_rocket` | `nearestObject [_unit,_ammo]` | Projectile object |

**Affected ammo classes** (`Common/Functions/Common_HandleAT.sqf`:4):

```
R_MEEWS_HEAT, R_MEEWS_HEDP, R_SMAW_HEDP, R_SMAW_HEAA
```

**Behavior:** Sets the rocket velocity vector to a fixed speed of **480 m/s** while preserving its direction. (`Common/Functions/Common_HandleAT.sqf`:15–20). The normalization uses `velocity _rocket distance [0,0,0]` as the magnitude.

---

### Common_HandleATMissiles.sqf

**EH type:** `IncomingMissile` — attached to `Tank` and `Car` class vehicles.

**Attachment point:** `Client_BuildUnit.sqf`:350 — only attached by `Client_BuildUnit`, not by `Init_Unit`.

**`_this` params (IncomingMissile EH):** `[unit, ammo, source]`

| Local var | Index | Description |
|---|---|---|
| `_u` | `_this select 0` | Vehicle being targeted |
| `_am` | `_this select 1` | Incoming ammo class |

**Affected ammo classes** (`Common/Functions/Common_HandleATMissiles.sqf`:12):

```
M_AT10_AT, M_AT11_AT
```

**Behavior:** Proportional-navigation guidance loop. On each frame iteration, the rocket's direction and speed are updated using exponential speed ramp toward `_sltd`. Exits immediately if no players are in the targeted vehicle's crew (i.e., no human player is riding in the vehicle that is about to be hit) (`{isPlayer _x} count (crew _u) == 0`). (`Common/Functions/Common_HandleATMissiles.sqf`:10)

**Per-missile tuning** (`Common/Functions/Common_HandleATMissiles.sqf`:16–19):

| Ammo | Max speed (`_sltd`, m/s) | Accel coeff (`_acc`) |
|---|---|---|
| `M_AT10_AT` | 860 | 0.6 |
| `M_AT11_AT` | 900 | 0.5 |

Speed formula: `_spd = _sltd - (_sltd - _sspd) * exp(-_acc * _t)` where `_t = _trvldis / _spd`.

---

### Common_HandleAAMissiles.sqf

**EH type:** `Fired` — attached to fixed-wing aircraft and SPAAG vehicles.

**Attachment points:**
- Jets (`F35B`, `AV8B`, `AV8B2`, `A10`, `A10_US_EP1`, `Su25_TK_EP1`, `Su34`, `Su39`, `An2_TK_EP1`, `L159_ACR`, `L39_TK_EP1`, `Su25_Ins`, `ibrPRACS_MiG21mol`): `Client_BuildUnit.sqf`:320
- SPAAG (`2S6M_Tunguska`, `M6_EP1`): `Client_BuildUnit.sqf`:329

**`_this` params (Fired EH):** `[unit, weapon, muzzle, mode, ammo, magazine, projectile]`

| Local var | Index | Description |
|---|---|---|
| `_u` | `_this select 0` | Firing unit |
| `_am` | `_this select 4` | Ammo class |
| `_rkt` | `nearestObject [_u,_am]` | Projectile object |

**Affected ammo classes** (`Common/Functions/Common_HandleAAMissiles.sqf`:14):

```
M_9M311_AA, M_Sidewinder_AA, M_R73_AA, M_Maverick_AT
```

**Behavior:** Full proportional-navigation guidance loop with lead-prediction. Target is `cursorTarget` for players, `assignedTarget _u` for AI. Exits if target is `null`, if `aimedAtTarget` returns 0, or if target is a `Building`. The loop writes `setVelocity` and `setVectorDirAndUp` each frame until `!isNull _rkt`. (`Common/Functions/Common_HandleAAMissiles.sqf`:33–80)

**Per-missile tuning** (`Common/Functions/Common_HandleAAMissiles.sqf`:26–30):

| Ammo | Max speed (`_sltd`, m/s) | Accel (`_acc`) | Angular gain (`_agl`) | Init delay (`_i`, s) | Prediction ratio (`_prd`) |
|---|---|---|---|---|---|
| `M_9M311_AA` | 920 | 1.2 | 0.115 | 0.1 | 0.3 |
| `M_Sidewinder_AA` | 850 | 1.0 | 0.0095 | 0.1 | 0.5 |
| `M_R73_AA` | 865 | 0.9 | 0.0095 | 0.1 | 0.5 |
| `M_Maverick_AT` | 865 | 0.9 | 0.0095 | 0.1 | 0.5 |

---

### Common_HandleShootBombs.sqf

**EH type:** `Fired` — attached to `Plane` class units only.

**Attachment point:** `Common/Init/Init_Unit.sqf`:120 (runs on all clients via `Init_Unit`).

**`_this` params (Fired EH):** `[unit, weapon, muzzle, mode, ammo, magazine, projectile]`

| Local var | Index | Description |
|---|---|---|
| `_unit_who_shot` | `_this select 0` | Firing unit |
| `_ammo` | `_this select 4` | Ammo class |
| `_projectile` | `_this select 6` | Projectile object |

**Affected ammo classes** (`Common/Functions/Common_HandleShootBombs.sqf`:15):

```
Bo_FAB_250, Bo_Mk82
```

**Behavior:** Exits if `name _unit_who_shot` differs from `name player` (local-only name-equality guard — `Common/Functions/Common_HandleShootBombs.sqf`:17–19). Reads `cursorTarget` as the intended target. If `player distance cursorTarget > WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION`, deletes the projectile and shows `hint localize "STR_WF_MESSAGE_BombDistanceRestriction"`. (`Common/Functions/Common_HandleShootBombs.sqf`:25–30)

**Dead code note:** An altitude-based restriction block (`WFBE_C_GAMEPLAY_BOMBS_ALTITUDE`, lines 33–43) is commented out. `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE` remains defined in `Rsc/Parameters.hpp`:291 and is never read at runtime.

---

### Common_HandleShootMissiles.sqf

**EH type:** `Fired` — attached to `Tank`, `Car`, and `Air` class units.

**Attachment point:** `Common/Init/Init_Unit.sqf`:211. A guard variable `WFBE_MissileTerrainMaskingEH_Added` prevents duplicate attachment (`Init_Unit.sqf`:209–212).

**`_this` params (Fired EH):** `[unit, weapon, muzzle, mode, ammo, magazine, projectile]`

**Ammo detection:** No hardcoded list. Reads `CfgAmmo` config for each fired round and checks (`Common/Functions/Common_HandleShootMissiles.sqf`:60–92):
- `simulation` in `["shotMissile","shotRocket"]`
- At least one of `canLock`, `irLock`, `laserLock`, `airLock`, `manualControl` > 0

**Behavior:** Infantry (when `vehicle player == player`) exits immediately. Checks terrain intersection between the vehicle and `cursorTarget` using `terrainIntersectASL` with a `2.5 m` vertical tolerance applied to both ends. If terrain blocks the line of sight, deletes the projectile and shows `hint localize "STR_WF_MESSAGE_MissileTerrainMaskingRestriction"` plus `playSound "MissileLaunchBlocked"`. (`Common/Functions/Common_HandleShootMissiles.sqf`:123–139)

---

### Common_HandleAlarm.sqf

**EH type:** `IncomingMissile` — attached to air vehicles with `incommingmissliedetectionsystem > 8`.

**Attachment point:** `Client_BuildUnit.sqf`:277 — conditional on `getNumber(configFile >> "CfgVehicles" >> typeOf _vehicle >> "incommingmissliedetectionsystem") > 8`.

**`_this` params (IncomingMissile EH):** `[unit, ammo, source]`

| Local var | Index | Description |
|---|---|---|
| `_unit` | `_this select 0` | Vehicle |
| `_ammo` | `_this select 1` | Incoming ammo |
| `_source` | `_this select 2` | Launch source position |

**Behavior:** Reads `WFBE_C_GAMEPLAY_MISSILES_RANGE`. Plays `playSound ["inbound",true]` every 0.55 s in a loop while `_source distance _missile < _limit`. If the source is already beyond the range limit when the handler fires, the loop body never executes and no sound plays. A `busy` vehicle variable prevents concurrent alarm spawns. (`Common/Functions/Common_HandleAlarm.sqf`:5–13)

---

### Common_HandleIncomingMissile.sqf

**EH type:** `IncomingMissile` — attached to all non-infantry vehicles when `WFBE_C_GAMEPLAY_MISSILES_RANGE != 0`.

**Attachment point:** `Common/Init/Init_Unit.sqf`:127 — gated by `(missionNamespace getVariable "WFBE_C_GAMEPLAY_MISSILES_RANGE") != 0`.

**`_this` params (IncomingMissile EH):** `[unit, ammo, source]`

**Behavior:** Checks `getNumber(configFile >> "CfgAmmo" >> _ammo >> "irLock")`. Bombs (`Bo_FAB_250`, `Bo_Mk82`) are treated as `irLock = 1` via a workaround comment ("Dumb bomb workaround (rocket simulation)"). If `irLock == 1` and the shooter-to-source distance exceeds `WFBE_C_GAMEPLAY_MISSILES_RANGE`, waits until `_missile distance _source > _limit` then `deleteVehicle _missile`. (`Common/Functions/Common_HandleIncomingMissile.sqf`:9–21)

**Maverick dead code:** Lines 24–29 of `Common/Functions/Common_HandleIncomingMissile.sqf` read the `indirectHit` config value for `M_Maverick_AT` and assign `_indirectHit = 849` as a local variable. The value is never written back to the projectile or vehicle — there is no `setHit`, `setAmmo`, broadcast, or property mutation. The assignment has no runtime effect and is dead code, analogous to the commented-out `HandleATReloadVehicle` and the uncompiled `Common_HandleMissiles.sqf`.

---

### Common_HandleRocketTracer.sqf

**EH type:** `Fired` — attached to all vehicles, unconditionally.

**Attachment points:** `Init_Client.sqf`:18 (on session start for `vehicle player`), `Client_BuildUnit.sqf`:312 (for every built vehicle).

**Affected ammo classes** (`Common/Functions/Common_HandleRocketTracer.sqf`:4):

```
M_47_AT_EP1, M_AT13_AT, M_AT5_AT, M_AT2_AT, M_AT9_AT,
M_AT6_AT, M_TOW_AT, M_TOW2_AT, M_Vikhr_AT, M_AT10_AT, M_AT11_AT
```

**Behavior:** Creates two `#particlesource` emitters attached to the rocket — a smoke trail and an exhaust-flash effect — then after `sleep 0.7` creates a third trailing smoke puff. All emitters are attached to `_rocket` as the parent. (`Common/Functions/Common_HandleRocketTracer.sqf`:16–32)

---

### Common_HandleReload.sqf

**EH type:** `Fired` — attached to IFV class vehicles.

**Attachment point:** `Client_BuildUnit.sqf`:340 — conditional on vehicle `isKindOf` one of `["LAV25_Base","M2A2_Base","BMP2_Base","BTR90_Base"]`.

**`_this` params (Fired EH):** `[unit, weapon, muzzle, mode, ammo, ...]`

| Local var | Source | Description |
|---|---|---|
| `_unit` | `_this select 0` | Firing unit |
| `_weapon` | `currentMuzzle (gunner (vehicle _unit))` | Current muzzle |

**Affected weapons** (`Common/Functions/Common_HandleReload.sqf`:7):

```
AT5LauncherSingle, M242BC, M242, 2A46MRocket
```

**Reload times set** (`Common/Functions/Common_HandleReload.sqf`:11–16):

| Weapon | `setWeaponReloadingTime` value |
|---|---|
| `AT5LauncherSingle` | 0.3 |
| `M242BC` | 0.3 |
| `M242` | 0.3 |
| `2A46MRocket` | 1 (default, unchanged) |

---

### Common_HandleCommanderReload.sqf

**EH type:** `Fired` — attached to `Pandur2_ACR` only.

**Attachment point:** `Client_BuildUnit.sqf`:337.

**`_this` params (Fired EH):** `[unit, ...]`

| Local var | Source | Description |
|---|---|---|
| `_unit` | `_this select 0` | Firing unit |
| `_weapon` | `currentMuzzle (commander (vehicle _unit))` | Commander muzzle — note: uses `commander`, not `gunner` |

**Affected weapons** (`Common/Functions/Common_HandleCommanderReload.sqf`:6):

```
M242BC, M242
```

**Reload time:** 0.5 for both via `setWeaponReloadingTime [commander (vehicle _unit), _weapon, 0.5]`. (`Common/Functions/Common_HandleCommanderReload.sqf`:10–14)

---

### Common_HandleATReload.sqf

**EH type:** `Fired` — attached to `T90` and `BMP3`.

**Attachment point:** `Client_BuildUnit.sqf`:333.

**`_this` params (Fired EH):** `[unit, weapon, muzzle, mode, ammo, ...]`

**Affected ammo classes** (`Common/Functions/Common_HandleATReload.sqf`:9):

```
M_AT10_AT, M_AT11_AT
```

**Behavior:** Exits if no player is in the crew. Calls `currentMagazine (vehicle _u)`, removes it, waits `sleep 20`, then re-adds it with `addMagazine [_cmag, _ammocount]`. This enforces a 20-second reload cycle for AT missiles on T90/BMP3. (`Common/Functions/Common_HandleATReload.sqf`:12–16)

---

### Common_JetAADamage.sqf

**EH type:** `HandleDamage` — attached to all `Plane` class vehicles.

**Attachment point:** `Client_BuildUnit.sqf`:325 — gated by `_vehicle isKindOf "Plane" && (missionNamespace getVariable ["WFBE_C_JET_AA_SURVIVE", 1]) > 0`.

**`_this` params (HandleDamage EH):** `[unit, selection, damage, source, ammo]` — returns a damage scalar.

**SPAAG detection** (`Common/Functions/Common_JetAADamage.sqf`:28–34):
- Vehicle type of source or `vehicle source` in `["2S6M_Tunguska","M6_EP1"]`
- OR ammo in `["M_9M311_AA","M_Stinger_AA"]`

**Two-hit mechanic** (`Common/Functions/Common_JetAADamage.sqf`:36–57):

| State | Effect |
|---|---|
| First separate engagement | `setFuel 0` (forced dead-stick). Damage capped at `min((getDammage _unit) + 0.25, 0.9)` — never lethal. |
| Second (or later) separate engagement | `_result = 1` — instant destruction. |

Debounce window: `(time - _last) > 1.5` seconds defines a new engagement. The hit counter `wfbe_jet_aa_hits` and last-hit timestamp `wfbe_jet_aa_lasthit` are broadcast globally via `setVariable [..., true]` (`Common/Functions/Common_JetAADamage.sqf`:41,46). `setFuel 0` is applied locally on the unit's machine only — in Arma 2 OA, `setFuel` is a local effect and is not broadcast automatically.

Repair via `Client_SupportRepair.sqf` restores fuel to 100% and resets `wfbe_jet_aa_hits` to 0, re-arming the mechanic.

---

### Common_RemoveAAMissiles.sqf

**Called as:** `(_vehicle) Call WFBE_CO_FNC_RemoveAAMissiles` — not an EH; called once on vehicle spawn.

**Call sites:** `Client_BuildUnit.sqf`:291 (case 0, AA missiles disabled), `Client_BuildUnit.sqf`:294 (case 1, upgrade not yet purchased).

**`_this` param:** The vehicle object.

**Behavior:** Iterates `weapons _unit`. For each weapon, reads `CfgWeapons >> _x >> magazines` and checks each magazine's ammo via `CfgMagazines >> _x >> ammo`. If the ammo has `airLock == 1` AND `inheritsFrom(CfgAmmo >> _ammo)` resolves to `"MissileBase"`, the magazine and weapon are queued for removal. Removes all queued magazines then all queued weapons. (`Common/Functions/Common_RemoveAAMissiles.sqf`:18–33)

---

### Common_RemoveCountermeasures.sqf

**Called as:** `(_vehicle) Call WFBE_CO_FNC_RemoveCountermeasures` — not an EH; called once on vehicle spawn.

**Call sites:** `Client_BuildUnit.sqf`:280 (case 0, flares disabled), `Client_BuildUnit.sqf`:283 (case 1, upgrade not yet purchased).

**`_this` param:** The vehicle object. Returns `true`.

**Behavior:** Checks `CfgVehicles >> typeOf _unit >> weapons` for `"CMFlareLauncher"`. If present, removes all flare magazines in this hardcoded list from turret `[-1]` (`Common/Functions/Common_RemoveCountermeasures.sqf`:14–16):

```
60Rnd_CMFlareMagazine, 120Rnd_CMFlareMagazine, 240Rnd_CMFlareMagazine,
60Rnd_CMFlare_Chaff_Magazine, 120Rnd_CMFlare_Chaff_Magazine, 240Rnd_CMFlare_Chaff_Magazine
```

---

## EH Attachment Map

This table shows which EH type is attached, where, and under what condition for the full handler family.

| Handler | EH type | Attachment file | Condition |
|---|---|---|---|
| `HandleAT` | `Fired` | `Init_Client.sqf`:18 | Always, on `vehicle player` at session start |
| `HandleAT` | `Fired` | `Init_Client.sqf`:281 | Always — **duplicate** (see Known Bugs) |
| `HandleAT` | `Fired` | `Client_PreRespawnHandler.sqf`:13 | Always, re-attached on respawn |
| `HandleRocketTraccer` | `Fired` | `Init_Client.sqf`:18 | Always, on `vehicle player` at session start |
| `HandleRocketTraccer` | `Fired` | `Client_BuildUnit.sqf`:312 | Always, on every built vehicle |
| `HandleAAMissiles` | `Fired` | `Client_BuildUnit.sqf`:320 | `typeOf _vehicle in [jet classnames]` |
| `HandleAAMissiles` | `Fired` | `Client_BuildUnit.sqf`:329 | `typeOf _vehicle in ['2S6M_Tunguska','M6_EP1']` |
| `HandleJetAADamage` | `HandleDamage` | `Client_BuildUnit.sqf`:325 | `_vehicle isKindOf "Plane" && WFBE_C_JET_AA_SURVIVE > 0` |
| `HandleATReload` | `Fired` | `Client_BuildUnit.sqf`:333 | `typeOf _vehicle in ['T90','BMP3']` |
| `HandleCommanderReload` | `Fired` | `Client_BuildUnit.sqf`:337 | `typeOf _vehicle in ['Pandur2_ACR']` |
| `HandleReload` | `Fired` | `Client_BuildUnit.sqf`:340 | `typeOf _vehicle isKindOf` IFV base classes |
| `HandleATMissiles` | `IncomingMissile` | `Client_BuildUnit.sqf`:350 | `typeOf _vehicle isKindOf "Tank" \|\| isKindOf "Car"` |
| `HandleAlarm` | `IncomingMissile` | `Client_BuildUnit.sqf`:277 | `incommingmissliedetectionsystem > 8` |
| `HandleShootBombs` | `Fired` | `Common/Init/Init_Unit.sqf`:120 | `_unit isKindOf "Plane"` |
| `HandleIncomingMissile` | `IncomingMissile` | `Common/Init/Init_Unit.sqf`:127 | `!_isMan && WFBE_C_GAMEPLAY_MISSILES_RANGE != 0` |
| `HandleShootMissiles` | `Fired` | `Common/Init/Init_Unit.sqf`:211 | `Tank \|\| Car \|\| Air`, guard variable prevents duplication |

---

## Known Bugs

### Duplicate HandleAT on player vehicle

`Init_Client.sqf`:18 adds `HandleAT` to `vehicle player` at session start. `Init_Client.sqf`:281 adds it again unconditionally later in the same init chain. On a fresh spawn, the player's current vehicle receives two `HandleAT` Fired EHs, causing every qualifying rocket to have its velocity set twice per shot. The second call is redundant but produces no incorrect outcome because both calls normalize to the same target speed of 480 m/s on the same projectile.

### Common_HandleMissiles.sqf — dead code

`Common/Functions/Common_HandleMissiles.sqf` exists on disk. It contains an older proportional-navigation loop for `M_9M311_AA`, `M_Sidewinder_AA`, and `M_R73_AA` with slightly different angular gain values (`_agl = 0.015` for `M_9M311_AA` versus `0.115` in the live `Common_HandleAAMissiles.sqf`). The file is not compiled in `Init_Common.sqf` and is not attached anywhere. It is superseded by `Common_HandleAAMissiles.sqf`. Do not register this function.

### HandleATReloadVehicle — commented out

`Common/Functions/Common_HandleATReloadVehicle.sqf` exists and handles `M_TOW_AT` reload cycling for `TOW`-equipped vehicles. The compile line at `Init_Common.sqf`:10 is commented out (`//HandleATReloadVehicle = ...`). The file is never called. TOW vehicles receive no reload manipulation.

### WFBE_C_GAMEPLAY_BOMBS_ALTITUDE — parameter with no reader

`Rsc/Parameters.hpp`:291 defines `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE` (default 2000 m). The only code that would read it is inside a commented-out block in `Common_HandleShootBombs.sqf`:33–43. The parameter appears in the lobby but has no runtime effect.

### HandleReload previous duplicate (resolved)

`Client_BuildUnit.sqf`:342 contains a comment: `//--- V2: removed duplicate "fired"->HandleReload event handler (was identical to the IFV line above; double-registering spawned HandleReload twice per shot).` This was fixed in a prior commit; the duplicate is gone from master.

---

## Continue Reading

- [IRS-IR-Smoke-Missile-Countermeasure](IRS-IR-Smoke-Missile-Countermeasure) — the IR Smoke countermeasure module that works alongside `HandleAlarm` and `HandleATMissiles`
- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — EASA aircraft armament system; controls which missiles are available before `RemoveAAMissiles` strips them
- [Artillery-Reference-Per-Faction](Artillery-Reference-Per-Faction) — artillery ammo classes and fire-mission system; some ammo classes interact with `HandleIncomingMissile`
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — naming rules for `WFBE_C_*` constants and `WFBE_CO_FNC_*` function globals referenced throughout this page
- [Function-And-Module-Index](Function-And-Module-Index) — master index of all compiled functions including the handler family
