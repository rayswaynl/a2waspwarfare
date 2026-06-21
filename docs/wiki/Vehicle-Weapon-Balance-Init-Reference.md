# Vehicle Weapon Balance Init (Common_BalanceInit per-class armament rebalance)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`BalanceInit` is the client-side function that normalizes each vehicle's engine-default armament to a mission-tuned loadout the moment it spawns or rearms. It is a single `typeOf`-dispatched `switch` over roughly 35 vehicle classes: each case strips the stock magazines/weapons and adds the rebalanced set, so a Su-34 carries split R-73 packs, an A-10A trades cluster ordnance for FFAR + Mk82, and a few top-tier ground vehicles only keep their best weapon when the side's factory upgrade is high enough. This page documents the dispatch, the per-class strip/reload tables, the `isServer` skip gate, the upgrade-gated ground cases, and every call site. It is distinct from [Vehicle-Equip-And-Rearm-Function-Reference](Vehicle-Equip-And-Rearm-Function-Reference), which only names `BalanceInit` as one step in the rearm flow and never documents what it changes.

## Function summary

| Aspect | Value | Source |
| --- | --- | --- |
| Global name | `BalanceInit` | `Common/Init/Init_Common.sqf:17` |
| Defined as | `BalanceInit = Compile preprocessFileLineNumbers "Common\Functions\Common_BalanceInit.sqf";` | `Common/Init/Init_Common.sqf:17` |
| Argument (`_this`) | the vehicle object to rebalance | `Common/Functions/Common_BalanceInit.sqf:6` |
| Return | none (side-effects only: add/remove magazine/weapon) | `Common/Functions/Common_BalanceInit.sqf:6-363` |
| Local var | `Private["_currentFactoryLevel"];` (used by upgrade-gated cases) | `Common/Functions/Common_BalanceInit.sqf:1,314,322,344,358` |
| File length | 364 lines | `Common/Functions/Common_BalanceInit.sqf:364` |

## The isServer skip gate

The body's first executable statement bails out on the dedicated server. The comment explains why: adding the Pandur and BTR-90 cases made the script capable of an occasional freeze if run server-side, so it now runs only on clients.

| Line | Statement | Effect | Source |
| --- | --- | --- | --- |
| 3 | `// After adding Pandur and BTR-90 to this script, it's necessary to exit on the server to prevent an occassional freeze` | rationale comment | `Common/Functions/Common_BalanceInit.sqf:3` |
| 4 | `if (isServer) exitWith {};` | function does nothing on a server instance | `Common/Functions/Common_BalanceInit.sqf:4` |

Because of this gate, every call site (including the server-side ones) relies on the function being a no-op on the headless/dedicated server and only doing real work on player clients. The upgrade-gated cases below also depend on a local `player`, so they are inherently client-only.

## Dispatch

A single `switch (typeOf _this) do { ... }` maps the exact vehicle class string to its rebalance case. Unlisted classes fall through silently (there is no `default` case, so they are left untouched).

| Line | Statement | Source |
| --- | --- | --- |
| 6 | `switch (typeOf _this) do` | `Common/Functions/Common_BalanceInit.sqf:6` |

Several cases are present but intentionally empty (no rebalance, but explicitly listed so the engine default is "approved"): `Mi24_D_CZ_ACR` (`:130-131`), `AH64D_EP1` (`:142-143`), `BAF_Apache_AH1_D` (`:146-147`), `Ka52Black` (`:214-215`).

## Fixed-wing jets (AF-tagged)

Each case is commented with the in-mission air tier tag `[AFn]` and a pylon count. The strip/reload swaps the stock launcher+magazine for a rebalanced loadout.

| Class | Tag (comment) | Removed | Added | Source |
| --- | --- | --- | --- | --- |
| `Su34` | `[AF5]` 10 pylons | mag `4Rnd_R73`; wpn `R73Launcher` | mag `2Rnd_R73` x2; wpn `R73Launcher_2` | `Common/Functions/Common_BalanceInit.sqf:9-15` |
| `Su25_Ins` | `[AF3]` 6 pylons | mags `2Rnd_R73`, `80Rnd_S8T`; wpns `R73Launcher_2`, `S8Launcher` | mag `64Rnd_57mm`; wpn `57mmLauncher` | `Common/Functions/Common_BalanceInit.sqf:18-25` |
| `Su25_TK_EP1` | `[AF4]` 8 pylons | mags `4Rnd_FAB_250`, `80Rnd_S8T`; wpns `AirBombLauncher`, `80mmLauncher` | mags `4Rnd_AT9_Mi24P` x2, `40Rnd_S8T`; wpns `AT9Launcher`, `S8Launcher` | `Common/Functions/Common_BalanceInit.sqf:28-38` |
| `Su39` | `[AF5]` 10 pylons | mags `4Rnd_FAB_250`, `80Rnd_S8T`, `4Rnd_Ch29`; wpns `AirBombLauncher`, `80mmLauncher`, `Ch29Launcher` | mags `12Rnd_Vikhr_KA50`, `40Rnd_S8T` x2; wpns `VikhrLauncher`, `S8Launcher` | `Common/Functions/Common_BalanceInit.sqf:41-53` |
| `L39_TK_EP1` | `[AF3]` 4 pylons | (none) | mags `2Rnd_R73`, `60Rnd_CMFlareMagazine`; wpns `R73Launcher_2`, `CMFlareLauncher` | `Common/Functions/Common_BalanceInit.sqf:56-61` |
| `F35B` | `[AF5]` 6 pylons | (none) | mag `2Rnd_Maverick_A10`; wpn `MaverickLauncher` | `Common/Functions/Common_BalanceInit.sqf:64-67` |
| `L159_ACR` | `[AF3]` 6 pylons | mag `4Rnd_Maverick_L159`; wpn `MaverickLauncher_ACR` | mags `2Rnd_Maverick_A10`, `38Rnd_FFAR`; wpns `MaverickLauncher`, `FFARLauncher` | `Common/Functions/Common_BalanceInit.sqf:70-77` |
| `A10` | `[AF3]` 4 pylons | mags `14Rnd_FFAR`, `4Rnd_GBU12`, `2Rnd_Sidewinder_AH1Z`, `2Rnd_Maverick_A10`; wpns `FFARLauncher_14`, `BombLauncherA10`, `SidewinderLaucher_AH1Z`, `MaverickLauncher` | mags `38Rnd_FFAR`, `6Rnd_Mk82`; wpns `FFARLauncher`, `Mk82BombLauncher_6` | `Common/Functions/Common_BalanceInit.sqf:80-93` |
| `A10_US_EP1` | `[AF4]` 8 pylons | mags `14Rnd_FFAR`, `4Rnd_GBU12`; wpns `FFARLauncher_14`, `BombLauncherA10` | mags `38Rnd_FFAR`, `6Rnd_Mk82`; wpns `FFARLauncher`, `Mk82BombLauncher_6` | `Common/Functions/Common_BalanceInit.sqf:96-105` |
| `AV8B` | `[AF4]` 8 pylons | mag `6Rnd_GBU12_AV8B`; wpn `BombLauncher` | mag `2Rnd_GBU12` x3; wpn `BombLauncherF35` | `Common/Functions/Common_BalanceInit.sqf:108-115` |
| `AV8B2` | `[AF5]` 8 pylons | mags `14Rnd_FFAR`, `6Rnd_Mk82`; wpns `FFARLauncher_14`, `Mk82BombLauncher_6` | mag `2Rnd_Maverick_A10` x3; wpn `MaverickLauncher` | `Common/Functions/Common_BalanceInit.sqf:118-127` |
| `An2_TK_EP1` | `[AF1]` 10 pylons | (none) | mags `60Rnd_CMFlareMagazine`, `500Rnd_TwinVickers` x2, `4Rnd_FAB_250`; wpns `CMFlareLauncher`, `TwinVickers`, `AirBombLauncher` | `Common/Functions/Common_BalanceInit.sqf:228-236` |

## Rotary-wing (AF-tagged, turret/pylon path)

Helicopter armament lives on turret paths, so these cases use the `...MagazineTurret`/`...WeaponTurret` commands. Most use the special turret index `[-1]`, which Arma 2 OA resolves to "all turrets" for add/remove operations (see [Turret index notes](#turret-index--1) below). Some helos use plain (hull) `addMagazine`/`addWeapon` for their pylon-mounted ordnance, mirroring the jet pattern, plus a `[-1]` turret swap for the nose/wing gun.

| Class | Tag (comment) | Removed | Added | Source |
| --- | --- | --- | --- | --- |
| `AH64D` | `[AF3]` 4 pylons | mag `8Rnd_Hellfire`; wpn `HellfireLauncher` | mag `6Rnd_TOW2`; wpn `TOWLauncherSingle` | `Common/Functions/Common_BalanceInit.sqf:134-139` |
| `AH1Z` | `[AF5]` 4 pylons | mags `8Rnd_Hellfire`, `2Rnd_Sidewinder_AH1Z`; wpn `SidewinderLaucher_AH1Z` | mag `8Rnd_Hellfire` x2 | `Common/Functions/Common_BalanceInit.sqf:150-156` |
| `AW159_Lynx_BAF` | `[AF3]` 4 pylons | turret `[-1]` mags `12Rnd_CRV7`, `1200Rnd_20mm_M621`; turret wpns `CRV7_PG`, `BAF_M621` | turret `[-1]` mags `200Rnd_40mmHE_FV510`, `200Rnd_40mmSABOT_FV510`, `6Rnd_CRV7_HEPD`, `2Rnd_Spike_ACR` x2; turret wpns `CTWS`, `CRV7_HEPD`, `SpikeLauncher_ACR` | `Common/Functions/Common_BalanceInit.sqf:159-172` |
| `Mi24_V` | `[AF3]` 4 pylons | mag `4Rnd_AT6_Mi24V`; wpn `AT6Launcher` | mag `4Rnd_AT9_Mi24P`; wpn `AT9Launcher` | `Common/Functions/Common_BalanceInit.sqf:175-180` |
| `Mi24_P` | `[AF3]` 4 pylons | hull mag `4Rnd_AT9_Mi24P` x2; turret `[-1]` mags `2Rnd_FAB_250`, `80Rnd_S8T`; turret wpns `HeliBombLauncher`, `80mmLauncher` | hull mag `4Rnd_AT9_Mi24P`; turret `[-1]` mags `750Rnd_30mm_GSh301` x2, `64Rnd_57mm`; turret wpn `57mmLauncher` | `Common/Functions/Common_BalanceInit.sqf:183-195` |
| `Mi24_D_TK_EP1` | `[AF3]` 2 pylons | turret `[-1]` mag `128Rnd_57mm` | turret `[-1]` mag `64Rnd_57mm` | `Common/Functions/Common_BalanceInit.sqf:198-201` |
| `Ka52` | `[AF4]` 8 pylons | mag `12Rnd_Vikhr_KA50`; wpn `VikhrLauncher` | mag `4Rnd_AT9_Mi24P` x3; wpn `AT9Launcher` | `Common/Functions/Common_BalanceInit.sqf:204-211` |
| `UH1Y` | `[AF2]` 0 pylons | turret `[-1]` mag `14Rnd_FFAR` (one) | turret `[-1]` mag `14Rnd_FFAR` x4 | `Common/Functions/Common_BalanceInit.sqf:287-293` |
| `AH6J_EP1` | `[AF2]` 0 pylons | (none) | mag `14Rnd_FFAR` | `Common/Functions/Common_BalanceInit.sqf:308-310` |

## Ground vehicles (HF/LF-tagged, some upgrade-gated)

Ground cases carry a heavy-factory `[HFn]` or light-factory `[LFn]` tag. The upgrade-gated ones read the side's factory level and strip the top-tier weapon if the level is too low (see next section). Plain ground cases simply swap magazines/weapons.

| Class | Tag (comment) | Removed | Added | Gate | Source |
| --- | --- | --- | --- | --- | --- |
| `M6_EP1` | `[HF4]` | mag `4Rnd_Stinger` x3; wpn `StingerLaucher_4x` | mag `8Rnd_9M311`; wpn `9M311Laucher` | none | `Common/Functions/Common_BalanceInit.sqf:218-225` |
| `T34_TK_EP1` | `[HF1]` | (none) | hull mags `60Rnd_762x54_DT` x7, `10Rnd_85mmAP`; turret `[1]` mag `60Rnd_762x54_DT` x5 | none | `Common/Functions/Common_BalanceInit.sqf:239-253` |
| `T34_TK_GUE_EP1` | `[HF1]` | (none) | hull mags `60Rnd_762x54_DT` x7, `10Rnd_85mmAP`; turret `[1]` mag `60Rnd_762x54_DT` x5 | none | `Common/Functions/Common_BalanceInit.sqf:256-270` |
| `M2A2_EP1` | `[HF1]` | mag `2Rnd_TOW2` x5, `210Rnd_25mm_M242_HEI`, `210Rnd_25mm_M242_APDS`; wpns `TOWLauncher`, `M242BC` | wpn `M242` | none | `Common/Functions/Common_BalanceInit.sqf:273-284` |
| `BMP2_INS` | `[HF1]` | (gated) wpn `AT5LauncherSingle` | (none) | `WFBE_UP_HEAVY < 2` strips ATGM | `Common/Functions/Common_BalanceInit.sqf:313-318` |
| `BMP2_TK_EP1` | `[HF1]` | (gated) wpn `AT5LauncherSingle` | (none) | `WFBE_UP_HEAVY < 2` strips ATGM | `Common/Functions/Common_BalanceInit.sqf:321-326` |
| `M1128_MGS_EP1` | `[LF4]` | (none) | turret `[0]` mag `6RND_105mm_APDS` | none | `Common/Functions/Common_BalanceInit.sqf:329-331` |
| `BRDM2_ATGM_INS` | `[LF4]` | turret `[0]` mag `5Rnd_AT5_BRDM2`; turret wpn `AT5Launcher` | turret `[0]` mag `2Rnd_Igla` x2; turret wpn `Igla_twice` | none | `Common/Functions/Common_BalanceInit.sqf:334-340` |
| `BTR90` | `[LF3]` | (gated) wpn `AT5LauncherSingle` | (none) | `WFBE_UP_LIGHT < 4` strips ATGM | `Common/Functions/Common_BalanceInit.sqf:343-348` |
| `Pandur2_ACR` | `[LF3]` | turret `[0]` mags `140Rnd_30mm_ATKMK44_HE_ACR`, `60Rnd_30mm_ATKMK44_AP_ACR`; turret wpn `ATKMK44_ACR`; (gated) turret wpn `SpikeLauncher_ACR` | turret `[0]` mags `210Rnd_25mm_M242_APDS`, `210Rnd_25mm_M242_HEI`; turret wpn `M242` | `WFBE_UP_LIGHT < 4` strips the Spike ATGM | `Common/Functions/Common_BalanceInit.sqf:351-362` |

## Upgrade-gated cases (factory-level dependent)

Four cases read the calling player's side factory upgrade level and conditionally remove the vehicle's best weapon, so the strongest ordnance is locked behind research. They all use the same idiom: query `WFBE_CO_FNC_GetSideUpgrades` for `side group player`, index it by an upgrade constant, and strip the weapon below a threshold.

| Class | Read | Constant value | Threshold / action | Source |
| --- | --- | --- | --- | --- |
| `BMP2_INS` | `((side group player) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_HEAVY` | `WFBE_UP_HEAVY = 2` | `< 2` -> remove `AT5LauncherSingle` | `Common/Functions/Common_BalanceInit.sqf:314-317` |
| `BMP2_TK_EP1` | `... select WFBE_UP_HEAVY` | `WFBE_UP_HEAVY = 2` | `< 2` -> remove `AT5LauncherSingle` | `Common/Functions/Common_BalanceInit.sqf:322-325` |
| `BTR90` | `... select WFBE_UP_LIGHT` | `WFBE_UP_LIGHT = 1` | `< 4` -> remove `AT5LauncherSingle` | `Common/Functions/Common_BalanceInit.sqf:344-347` |
| `Pandur2_ACR` | `... select WFBE_UP_LIGHT` | `WFBE_UP_LIGHT = 1` | `< 4` -> remove turret `[0]` `SpikeLauncher_ACR` | `Common/Functions/Common_BalanceInit.sqf:358-361` |

The upgrade index constants are defined in `Common/Init/Init_CommonConstants.sqf:37-41`: `WFBE_UP_BARRACKS = 0`, `WFBE_UP_LIGHT = 1`, `WFBE_UP_HEAVY = 2`, `WFBE_UP_AIR = 3`, `WFBE_UP_PARATROOPERS = 4` (`Init_CommonConstants.sqf:36-42`). `WFBE_CO_FNC_GetSideUpgrades` is a `switch (_this)` over side that returns the side HQ's `"wfbe_upgrades"` array, with a 30-zero fallback for resistance/GUER (`Common/Functions/Common_GetSideUpgrades.sqf:7-17`; defined at `Common/Init/Init_Common.sqf:143`). The `select WFBE_UP_*` index therefore reads one element of that per-side upgrade array.

### Turret index `[-1]`

The rotary cases and several others pass `[-1]` as the turret path to `addMagazineTurret`/`removeWeaponTurret` etc. In Arma 2 OA this special index targets all of the vehicle's turrets at once for the add/remove operation, which is why a single `[-1]` call rearms the whole turret set without enumerating each path. Ground cases that target a specific turret instead pass a concrete index such as `[0]` (e.g. `Pandur2_ACR` turret swaps, `Common/Functions/Common_BalanceInit.sqf:352-357`) or `[1]` (e.g. `T34_TK_EP1` coax DT mags, `Common/Functions/Common_BalanceInit.sqf:248-252`).

## Call sites

`BalanceInit` is invoked at vehicle creation (build/buy/start) and on rearm. Every call is gated on the mission parameter `WFBE_C_UNITS_BALANCING > 0`; the two rearm paths additionally exclude `M6_EP1` (its Stinger->9M311 swap should not re-run on every rearm). All real work happens client-side because of the `isServer` gate.

| Caller | Line | Guard | Source |
| --- | --- | --- | --- |
| Client build (player-built unit) | `(_vehicle) Call BalanceInit` | `WFBE_C_UNITS_BALANCING > 0` | `Client/Functions/Client_BuildUnit.sqf:346` |
| Server buy (purchased unit) | `(_vehicle) Call BalanceInit` | `WFBE_C_UNITS_BALANCING > 0` | `Server/Functions/Server_BuyUnit.sqf:150` |
| Server init start vehicles (per side) | `(_vehicle) Call BalanceInit` | `WFBE_C_UNITS_BALANCING > 0` | `Server/Init/Init_Server.sqf:518`, `:535` |
| Rearm (base game) | `(_vehicle) Call BalanceInit` | `WFBE_C_UNITS_BALANCING > 0 && typeOf _vehicle != 'M6_EP1'` | `Common/Functions/Common_RearmVehicle.sqf:50` |
| Rearm (OA) | `(_vehicle) Call BalanceInit` | `WFBE_C_UNITS_BALANCING > 0 && typeOf _vehicle != 'M6_EP1'` | `Common/Functions/Common_RearmVehicleOA.sqf:37` |

The `WFBE_C_UNITS_BALANCING` parameter defaults to `1` (enabled) when nil — `if (isNil "WFBE_C_UNITS_BALANCING") then {WFBE_C_UNITS_BALANCING = 1};` (`Common/Init/Init_CommonConstants.sqf:518`) — and is also exposed as a mission parameter (`Rsc/Parameters.hpp:352`).

## Continue Reading

- [Vehicle-Equip-And-Rearm-Function-Reference](Vehicle-Equip-And-Rearm-Function-Reference) — the rearm flow that calls `BalanceInit` as one step
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — which factions field the classes rebalanced here
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — the `wfbe_upgrades` array and `WFBE_UP_*` indices the gated cases read
- [Upgrade-Research-Cross-Faction-Reference](Upgrade-Research-Cross-Faction-Reference) — LIGHT/HEAVY factory levels that gate BTR-90, Pandur, and BMP-2 ordnance
- [Vehicle-Cargo-Equip-Loop-Bounds](Vehicle-Cargo-Equip-Loop-Bounds) — related vehicle cargo/equip handling at spawn
