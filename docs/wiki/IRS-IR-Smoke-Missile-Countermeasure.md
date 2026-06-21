# IRS — IR-Smoke Missile Countermeasure System (per-vehicle table, upgrade-level behavior)

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The IRS (IR Smoke) module is WASP's ground-vehicle missile countermeasure system. When an IR-guided missile is fired at a qualifying vehicle, the system deploys smoke grenades and attempts to deflect the missile's trajectory. It is entirely distinct from the vanilla CM (`WFBE_C_MODULE_WFBE_FLARES`) flare path used by air vehicles.

---

## Module Gate

IRS is guarded by a single flag:

| Constant | Default | Where set |
|---|---|---|
| `WFBE_C_MODULE_WFBE_IRSMOKE` | `1` (enabled) | `Common/Init/Init_CommonConstants.sqf:255` |

`IRS_Init.sqf` is compiled only when this flag is `> 0`:

```sqf
if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_IRSMOKE") > 0) then {
    Call Compile preprocessFileLineNumbers "Common\Module\IRS\IRS_Init.sqf"
};
```
`Common/Init/Init_Common.sqf:321`

Both `Client_BuildUnit.sqf` and `Server_BuyUnit.sqf` check this same constant before attaching the `incomingMissile` event handler or setting `wfbe_irs_flares` on a vehicle. `Client_BuildUnit.sqf:353`, `Server_BuyUnit.sqf:117`.

---

## Global Constants (IRS_Init.sqf)

| Constant | Value | Meaning |
|---|---|---|
| `WFBE_IRS_AREA_OPERATING` | `35` m | Smoke grenade must land within this radius of the vehicle for the deflection attempt to trigger |
| `WFBE_IRS_AUTO_DETECT_RANGE` | `200` m | Missile is tracked once it enters this range of the vehicle |
| `WFBE_IRS_FLARE_DELAY` | `60` s | Cooldown between consecutive IRS deployments on a single vehicle |
| `WFBE_IRS_MISSILE_CHECK_RANGE` | `200` m | IRS actions are checked when the missile enters this range |

All four defined at `Common/Module/IRS/IRS_Init.sqf:11-14`.

---

## Per-Vehicle Table

Each entry registers a vehicle type as `<type>_IRS = [dodgeChance%, smokeCount]` in `missionNamespace`. An entry is only registered if (a) the vehicle type is already defined in the mission's core variable space, and (b) `configFile >> "CfgVehicles" >> type >> "smokeLauncherGrenadeCount"` resolves to a number — i.e., the vehicle has smoke launchers in its A2 config. `Common/Module/IRS/IRS_Init.sqf:49-56`.

| Class name | Dodge chance (%) | Base smoke count | Notes |
|---|---|---|---|
| `AAV` | 50 | 2 | `IRS_Init.sqf:18` |
| `BAF_FV510_W` | 70 | 3 | `IRS_Init.sqf:19` |
| `BAF_FV510_D` | 70 | 3 | `IRS_Init.sqf:20` |
| `BMP2_CDF` | 50 | 2 | `IRS_Init.sqf:21` |
| `BMP2_Gue` | 50 | 2 | `IRS_Init.sqf:22` |
| `BMP2_INS` | 50 | 2 | `IRS_Init.sqf:23` |
| `BMP2_TK_EP1` | 50 | 2 | `IRS_Init.sqf:24` |
| `BMP3` | 65 | 3 | `IRS_Init.sqf:25` |
| `BTR90` | 65 | 2 | `IRS_Init.sqf:26` |
| `LAV25` | 65 | 2 | `IRS_Init.sqf:27` |
| `M1126_ICV_M2_EP1` | 60 | 1 | Stryker ICV; `IRS_Init.sqf:28` |
| `M1126_ICV_mk19_EP1` | 55 | 1 | Stryker ICV MK19; `IRS_Init.sqf:29` |
| `M1129_MC_EP1` | 60 | 1 | Stryker MC; `IRS_Init.sqf:30` |
| `M1135_ATGMV_EP1` | 60 | 1 | Stryker ATGM; `IRS_Init.sqf:31` |
| `M1128_MGS_EP1` | 60 | 1 | Stryker MGS; `IRS_Init.sqf:32` |
| `M1133_MEV_EP1` | 60 | 1 | Stryker MEV; `IRS_Init.sqf:33` |
| `M1A1` | 70 | 4 | `IRS_Init.sqf:34` |
| `M1A1_US_DES_EP1` | 70 | 4 | Desert M1A1; `IRS_Init.sqf:35` |
| `M1A2_TUSK_MG` | 75 | 4 | `IRS_Init.sqf:36` |
| `M1A2_US_TUSK_MG_EP1` | 75 | 4 | `IRS_Init.sqf:37` |
| `M2A2_EP1` | 65 | 3 | Bradley A2; `IRS_Init.sqf:38` |
| `M2A3_EP1` | 65 | 3 | Bradley A3; `IRS_Init.sqf:39` |
| `M6_EP1` | 60 | 3 | Linebacker; `IRS_Init.sqf:40` |
| `T72_CDF` | 65 | 4 | `IRS_Init.sqf:41` |
| `T72_INS` | 65 | 4 | `IRS_Init.sqf:42` |
| `T72_Gue` | 65 | 4 | `IRS_Init.sqf:43` |
| `T72_RU` | 65 | 4 | `IRS_Init.sqf:44` |
| `T72_TK_EP1` | 65 | 4 | `IRS_Init.sqf:45` |
| `T90` | 80 | 4 | Highest dodge chance in the table; `IRS_Init.sqf:46` |

**Total: 29 entries.**

The "Base smoke count" column is the value stored at index 1 of the `<type>_IRS` array. This is the count assigned to `wfbe_irs_flares` at spawn for a side with upgrade level 1. At upgrade level 2 it is doubled (see Upgrade Levels below).

**Silent exclusion rule:** A vehicle type not present in this table — or whose class is undefined in the mission's variable namespace, or which lacks `smokeLauncherGrenadeCount` in `CfgVehicles` — receives no IRS registration and no `wfbe_irs_flares` variable. A vehicle type not in this table receives no `wfbe_irs_flares` variable and no `incomingMissile` IRS event handler — the exclusion happens at spawn/build time in `Client_BuildUnit`/`Server_BuyUnit`, not at event-fire time. `IRS_Init.sqf:49-56`.

---

## WFBE_UP_IRSMOKE Upgrade

| Constant | Index | File |
|---|---|---|
| `WFBE_UP_IRSMOKE` | `18` | `Common/Init/Init_CommonConstants.sqf:55` |

The upgrade has **2 levels** across all factions. `Upgrades_USMC.sqf:78` (line 78: `2, //--- IR Smoke`; all other faction upgrade files confirm the same max-level value).

### Costs and research times (all factions, identical)

| Level | Cost (money, supply) | Research time (s) | Prerequisite |
|---|---|---|---|
| 1 | `[3000, 0]` | 120 | `WFBE_UP_HEAVY` level 3 |
| 2 | `[9000, 0]` | 180 | None (no link) |

Sources: `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:51,78,113,140` (costs, levels, links, times). The RU faction upgrade file confirms identical values at the same line offsets: `Common/Config/Core_Upgrades/Upgrades_RU.sqf:51`.

The `WFBE_C_UPGRADES_<side>_ENABLED` flag for IR Smoke at index 18 is gated on `WFBE_C_MODULE_WFBE_IRSMOKE > 0` — if the module is disabled the upgrade entry is `false` and the research node does not appear in the buy menu. `Upgrades_USMC.sqf:24`.

---

## Upgrade-Level Behavior

### Level 1 — basic IRS

When a player-purchased or player-built vehicle is built (`Client_BuildUnit.sqf:354-367` or `Server_BuyUnit.sqf:118-124`):

1. The side upgrade level is checked: `((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_IRSMOKE > 0`.
2. The vehicle's `<type>_IRS` entry is retrieved from `missionNamespace`.
3. `wfbe_irs_flares` is set to `_get select 1` (the base smoke count from the table above). `Client_BuildUnit.sqf:363`.
4. An `incomingMissile` EH for `WFBE_CO_MOD_IRS_OnIncomingMissile` is attached. `Client_BuildUnit.sqf:364`.

On each trigger the vehicle announces via `vehicleChat` (localized string `STR_WF_CHAT_IRS_Deployed`): "Deploying IR Smoke! %1 ammunitions remaining." `IRS_OnIncomingMissile.sqf:33`, `stringtable.xml:317`.

At upgrade level < 2, the player crew hears a single one-shot sound: `playSound ["inboundMissileGround", true]`. `IRS_OnIncomingMissile.sqf:37`.

### Level 2 — doubled smoke + continuous warning

At upgrade level 2, the base smoke count from the table is **doubled** before being stored in `wfbe_irs_flares`:

```sqf
if (((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_IRSMOKE > 1) then {
    _getSelectOne = _getSelectOne * 2;
};
_vehicle setVariable ["wfbe_irs_flares", _getSelectOne, true];
```
`Client_BuildUnit.sqf:361-363`

Note: the doubling is applied only in `Client_BuildUnit` (player-spawned vehicles). `Server_BuyUnit` (AI-purchased vehicles) does not apply the level-2 doubling; it always uses `_get select 1` unmodified. `Server_BuyUnit.sqf:121`.

The warning sound at upgrade level 2 changes from a single shot to a looping tone that plays for as long as the inbound missile is alive:

```sqf
[_projectile] spawn {
    _projectile = _this select 0;
    while {!(isNull _projectile)} do {
        playSound["inboundMissileGround_cont",true];
        sleep 0.2;
    };
};
```
`IRS_OnIncomingMissile.sqf:41-48`

This continuous loop runs on the local player's machine only (the outer `if ((local player) && (player in crew _vehicle))` guard applies to both branches). `IRS_OnIncomingMissile.sqf:28`.

---

## incomingMissile Event Flow

Both `Client_BuildUnit` and `Server_BuyUnit` attach a **second** `incomingMissile` handler — the vanilla-tracking `HandleATMissiles` function — unconditionally for all `Tank` or `Car` class vehicles, regardless of IRS module state. `HandleATMissiles` is compiled at `Common/Init/Init_Common.sqf:11`; the EH attachment is at `Client_BuildUnit.sqf:350`. The IRS-specific handler (`WFBE_CO_MOD_IRS_OnIncomingMissile`) is then added on top if IRS conditions are met.

When an incoming missile fires, `IRS_OnIncomingMissile` executes this sequence:

| Step | Code path | Gate condition |
|---|---|---|
| 1. Ammo gate | `IRS_OnIncomingMissile.sqf:18` | Only IR-lock ammo (`CfgAmmo >> irLock == 1`) triggers IRS |
| 2. Locality gate | `IRS_OnIncomingMissile.sqf:20` | Vehicle must be local to this machine |
| 3. Crew alive check | `IRS_OnIncomingMissile.sqf:21` | At least one of driver / gunner / commander must be alive |
| 4. Flare counter check | `IRS_OnIncomingMissile.sqf:24` | `wfbe_irs_flares > 0` |
| 5. Cooldown check | `IRS_OnIncomingMissile.sqf:24` | `time - wfbe_irs_lastfired > WFBE_IRS_FLARE_DELAY` (60 s) |
| 6. Deploy smoke | `IRS_OnIncomingMissile.sqf:25` | Spawns `IRS_DeploySmoke` on the vehicle |
| 7. Update lastfired | `IRS_OnIncomingMissile.sqf:26` | Sets `wfbe_irs_lastfired = time` |
| 8. Decrement counter | `IRS_OnIncomingMissile.sqf:27` | Sets `wfbe_irs_flares -= 1`, broadcast global (`true`) |
| 9. Player HUD | `IRS_OnIncomingMissile.sqf:28-50` | Chat + sound, only if local player is in the vehicle |
| 10. Missile handler | `IRS_OnIncomingMissile.sqf:56` | If missile is local: spawns `IRS_HandleMissile` |

---

## Smoke Deployment (IRS_DeploySmoke.sqf)

`IRS_DeploySmoke` reads `smokeLauncherGrenadeCount`, `smokeLauncherVelocity`, `smokeLauncherOnTurret`, and `smokeLauncherAngle` directly from `CfgVehicles` for the vehicle type to calculate launch arcs. It creates `SmokeShellVehicle` objects and broadcasts them to clients via `WFBE_CO_FNC_SendToClients` for particle FX. The shells persist for 55 seconds before deletion. `Common/Module/IRS/IRS_DeploySmoke.sqf:11-54`.

`IRS_CreateSmoke` attaches custom particle emitters to each shell for the local visual effect (trail + white phosphorus cloud). `Common/Module/IRS/IRS_CreateSmoke.sqf:1-30`.

---

## Missile Deflection (IRS_HandleMissile.sqf)

The deflection handler runs on the machine that is **local to the missile** (not the vehicle). It:

1. Waits until the missile enters `WFBE_IRS_AUTO_DETECT_RANGE` (200 m) of the vehicle. `IRS_HandleMissile.sqf:21`.
2. Checks that at least one `SmokeShellVehicle` exists within `WFBE_IRS_AREA_OPERATING` (35 m) of the vehicle. If none, exits without deflection. `IRS_HandleMissile.sqf:26-27`.
3. Rolls `random 100` against the vehicle's dodge chance (`_get select 0`). `IRS_HandleMissile.sqf:29`.
4. On a successful roll, applies iterative deflection via `setVectorDirAndUp` on the missile over 10 ticks (0.01 s each), scaled by the ammo's `maneuvrability` config value over 10 ticks (0.01 s each), scaled by the ammo's `maneuvrability` config value (defaults to `20` if not set). `IRS_HandleMissile.sqf:31-67`.

The dodge check is probabilistic — the table value is a **percentage chance per missile event**, not a guarantee.

---

## Rearming Resets Flare Count

`Common_RearmVehicle.sqf` and `Common_RearmVehicleOA.sqf` both reset `wfbe_irs_flares` to the base table value (`_get select 1`) whenever the vehicle rearmed — provided the current count differs from the table default. This means rearming at a supply truck always restores base flares; it does not re-apply the level-2 doubling. `Common/Functions/Common_RearmVehicle.sqf:33-39`, `Common/Functions/Common_RearmVehicleOA.sqf:23-30`.

---

## Distinction from the Vanilla CM Module

| Feature | IRS (`WFBE_C_MODULE_WFBE_IRSMOKE`) | Vanilla CM (`WFBE_C_MODULE_WFBE_FLARES`) |
|---|---|---|
| Applies to | Ground vehicles: `Tank`, `Car` class | Air vehicles |
| Trigger | `irLock == 1` ammo, `incomingMissile` EH | `incomingMissile` EH (CM countermeasures) |
| Mechanic | Smoke + probabilistic trajectory deflect | Flare countermeasures (vanilla A2 CM) |
| Upgrade index | `WFBE_UP_IRSMOKE` = 18 | `WFBE_UP_FLARESCM` = 9 |
| Max levels | 2 | 1 |

---

## Continue Reading

- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — full upgrade index, cost tables, and research prerequisite chains for all factions
- [Modules-Atlas](Modules-Atlas) — master list of all `WFBE_C_MODULE_*` flags, their defaults, and what they gate
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — how `Server_BuyUnit` and `Client_BuildUnit` spawn vehicles and attach module event handlers
- [Gear-Loadout-And-EASA-Atlas](Gear-Loadout-And-EASA-Atlas) — the parallel EASA module for aircraft weapon customization (analogous optional-module pattern)
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*`, `WFBE_UP_*`, and per-vehicle dynamic variable naming conventions
