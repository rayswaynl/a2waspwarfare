# Artillery Reference Per Faction (pieces, ranges, ammo, upgrade gates)

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Each faction's artillery configuration is loaded by its Root file at mission start. The firing stats, projectile lists, and upgrade gates are all set via `missionNamespace setVariable` keyed on the side string (`WEST`, `EAST`, `GUER`). The function `Common/Functions/Common_GetArtilleryAmmoOptions.sqf` reads these variables at fire-mission time and filters available ammo against the current upgrade level `WFBE_UP_ARTYAMMO` (index 17 in the upgrades array, `Common/Init/Init_CommonConstants.sqf:54`).

---

## Config File Selection by Faction and Game Mode

Each Root file branches on `WF_A2_CombinedOps` to select the appropriate artillery config. US, US Camo, CDF and INS load unconditionally (no CO branch for artillery).

| Faction | Root file | Config |
|---|---|---|
| US | Root_US.sqf | Artillery_CO_US.sqf (unconditional — no CombinedOps branch) |
| US Camo | Root_US_Camo.sqf | Artillery_CO_US.sqf (unconditional — no CombinedOps branch) |
| USMC | Root_USMC.sqf | Artillery_CO_US.sqf (CombinedOps = true) / Artillery_USMC.sqf (CombinedOps = false) |
| RU | Root_RU.sqf | Artillery_CO_RU.sqf (CombinedOps = true) / Artillery_RU.sqf (CombinedOps = false) |
| TKA | Root_TKA.sqf | Artillery_CO_RU.sqf (CombinedOps = true) / Artillery_OA_TKA.sqf (CombinedOps = false) |
| GUE | Root_GUE.sqf | Artillery_CO_GUE.sqf (CombinedOps = true) / Artillery_GUE.sqf (CombinedOps = false) |
| TK GUE | Root_TKGUE.sqf | Artillery_CO_GUE.sqf (CombinedOps = true) / Artillery_OA_TKGUE.sqf (CombinedOps = false) |
| PMC | Root_PMC.sqf | Artillery_CO_GUE.sqf (CombinedOps = true) / Artillery_OA_TKGUE.sqf (CombinedOps = false) |
| CDF | Root_CDF.sqf | Artillery_CDF.sqf (unconditional) |
| INS | Root_INS.sqf | Artillery_INS.sqf (unconditional) |

Sources: `Common/Config/Core_Root/Root_*.sqf` (artillery exec lines in each file). US unconditional: `Root_US.sqf:131`; US Camo unconditional: `Root_US_Camo.sqf:124`.

---

## WEST Factions

### US / US Camo / USMC (CombinedOps) — Artillery_CO_US.sqf

`Common/Config/Core_Artillery/Artillery_CO_US.sqf:4-48`

| # | Display Name | Weapon Class | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|---|
| 0 | M119 | M119 | M119_US_EP1, M119 | 1000 | 7000 | 7 | 10 | 250 | 50 |
| 1 | M252 | M252 | M252_US_EP1, M252 | 50 | 5500 | 4 | 4 | 235 | 60 |
| 2 | MLRS | MLRS | MLRS, MLRS_DES_EP1 | 1200 | 9000 | 2 | 12 | 275 | 40 |
| 3 | Stryker MC | M120 | M1129_MC_EP1 | 550 | 8000 | 4 | 8 | 235 | 55 |

**Ammo sets** (`WFBE_WEST_ARTILLERY_AMMOS`, lines 18–23):

| Piece | Standard (always available) | Special (WFBE_UP_ARTYAMMO level 1 required) |
|---|---|---|
| M119 | Sh_105_HE | Sh_105_WP, Sh_105_SADARM, Sh_105_LASER, Sh_105_SMOKE, Sh_105_ILLUM |
| M252 | Sh_81_HE | Sh_81_WP, Sh_81_ILLUM |
| MLRS | R_MLRS | — (no special rounds) |
| Stryker MC | 120mmHE_M120 | — (no special rounds) |

**Extended magazines** (loaded into vehicle, gated at WFBE_UP_ARTYAMMO = 1, lines 26–40):
- M119: 30Rnd_105mmWP_M119, 30Rnd_105mmSADARM_M119, 30Rnd_105mmLASER_M119, 30Rnd_105mmSMOKE_M119, 30Rnd_105mmILLUM_M119
- M252: 8Rnd_81mmWP_M252, 8Rnd_81mmILLUM_M252

**Smoke-deploying projectiles**: Sh_105_WP, Sh_105_SMOKE, Sh_81_WP (`line 15`)
**Laser-guided round**: Sh_105_LASER (`line 12`)
**SADARM round**: Sh_105_SADARM (`line 13`)
**ILLUM rounds**: Sh_105_ILLUM, Sh_81_ILLUM (`line 14`)

---

### USMC (Arma 2 vanilla, no CombinedOps) — Artillery_USMC.sqf

`Common/Config/Core_Artillery/Artillery_USMC.sqf:4-44`

| # | Display Name | Weapon Class | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|---|
| 0 | M119 | M119 | M119 | 1000 | 8000 | 7 | 8 | 500 | 50 |
| 1 | M252 | M252 | M252 | 50 | 7500 | 4 | 4 | 475 | 60 |
| 2 | MLRS | MLRS | MLRS | 1200 | 9000 | 2 | 6 | 550 | 40 |

**Ammo sets** (lines 18–22):

| Piece | Standard | Special (WFBE_UP_ARTYAMMO 1) |
|---|---|---|
| M119 | ARTY_Sh_105_HE, Sh_105_HE | ARTY_Sh_105_WP, ARTY_Sh_105_SADARM, ARTY_Sh_105_LASER, ARTY_Sh_105_SMOKE, ARTY_Sh_105_ILLUM |
| M252 | ARTY_Sh_81_HE, Sh_81_HE | ARTY_Sh_81_WP, ARTY_Sh_81_ILLUM |
| MLRS | ARTY_R_227mm_HE_Rocket, R_MLRS | — |

**Extended magazines** (loaded into vehicle, gated at WFBE_UP_ARTYAMMO = 1, `Artillery_USMC.sqf:25-28`):
- M119: ARTY_30Rnd_105mmWP_M119, ARTY_30Rnd_105mmSADARM_M119, ARTY_30Rnd_105mmLASER_M119, ARTY_30Rnd_105mmSMOKE_M119, ARTY_30Rnd_105mmILLUM_M119
- M252: ARTY_8Rnd_81mmWP_M252, ARTY_8Rnd_81mmILLUM_M252
- MLRS: [] (no extended mags)

**Classnames** (`Artillery_USMC.sqf:40-44`): `['M119']`, `['M252']`, `['MLRS']` — vanilla A2 base-game classnames, no EP1 variants.

Note: vanilla mode uses `ARTY_`-prefixed classnames from the ACE/BAF compatibility layer alongside base game classnames.

---

## EAST Factions

### RU (CombinedOps) — Artillery_CO_RU.sqf

`Common/Config/Core_Artillery/Artillery_CO_RU.sqf:4-44`

| # | Display Name | Weapon Class | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|---|
| 0 | D30 | D30 | D30_TK_EP1, D30_RU | 1000 | 7000 | 7 | 10 | 250 | 50 |
| 1 | 2B14 | 2B14 | 2b14_82mm_TK_EP1, 2b14_82mm | 50 | 5500 | 4 | 4 | 235 | 60 |
| 2 | GRAD | GRAD | GRAD_RU, GRAD_TK_EP1 | 800 | 9000 | 2 | 10 | 275 | 40 |

**Ammo sets** (lines 18–22):

| Piece | Standard | Special (WFBE_UP_ARTYAMMO 1) |
|---|---|---|
| D30 | Sh_122_HE | Sh_122_WP, Sh_122_SADARM, Sh_122_LASER, Sh_122_SMOKE, Sh_122_ILLUM |
| 2B14 | Sh_82_HE | Sh_82_WP, Sh_82_ILLUM |
| GRAD | R_GRAD | — (no special rounds) |

**Extended magazines** (lines 25–37):
- D30: 30Rnd_122mmWP_D30, 30Rnd_122mmSADARM_D30, 30Rnd_122mmLASER_D30, 30Rnd_122mmSMOKE_D30, 30Rnd_122mmILLUM_D30
- 2B14: 8Rnd_82mmWP_2B14, 8Rnd_82mmILLUM_2B14

---

### RU (Arma 2 vanilla) — Artillery_RU.sqf

`Common/Config/Core_Artillery/Artillery_RU.sqf:4-44`

| # | Display Name | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|
| 0 | D30 | D30_CDF | 1000 | 7000 | 7 | 8 | 500 | 50 |
| 1 | 2B14 | 2b14_82mm_CDF | 50 | 5500 | 4 | 4 | 475 | 60 |
| 2 | GRAD | GRAD_CDF | 800 | 9000 | 2 | 8 | 550 | 40 |

Ammo sets use `ARTY_Sh_122_*` / `ARTY_Sh_82_*` / `ARTY_R_227mm_HE_Rocket` prefixed classnames, alongside base `Sh_122_HE`, `Sh_82_HE`, `R_GRAD`. Same upgrade gate (WFBE_UP_ARTYAMMO = 1) applies to special rounds.

Note: the vanilla RU config uses CDF vehicle classnames (D30_CDF etc.), which is the only D30/2B14/GRAD variant available without Combined Operations DLC.

---

### TKA (Arrowhead only, no CombinedOps) — Artillery_OA_TKA.sqf

`Common/Config/Core_Artillery/Artillery_OA_TKA.sqf:4-44`

| # | Display Name | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|
| 0 | D30 | D30_TK_EP1 | 1000 | 8000 | 7 | 8 | 500 | 50 |
| 1 | 2B14 | 2b14_82mm_TK_EP1 | 50 | 7500 | 4 | 4 | 475 | 60 |
| 2 | GRAD | GRAD_TK_EP1 | 800 | 9000 | 2 | 8 | 550 | 40 |

Ammo sets use base `Sh_122_*` / `Sh_82_*` / `R_GRAD` classnames. Extended magazines use standard `30Rnd_122mm*` / `8Rnd_82mm*` names, same gate (WFBE_UP_ARTYAMMO = 1).

Note: ILLUM_AMMOS list entry for 2B14 is `['Sh_122_ILLUM','Sh_122_ILLUM']` (line 14) — a duplicate entry; functionally only one ILLUM type is in the 2B14 ammo set.

When TKA plays with CombinedOps enabled, it loads Artillery_CO_RU.sqf instead (see Root_TKA.sqf:125).

---

### INS — Artillery_INS.sqf

`Common/Config/Core_Artillery/Artillery_INS.sqf:4-44` (loaded unconditionally regardless of game mode)

| # | Display Name | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|
| 0 | D30 | D30_CDF | 1000 | 8000 | 7 | 8 | 500 | 50 |
| 1 | 2B14 | 2b14_82mm_CDF | 50 | 7500 | 4 | 4 | 475 | 60 |
| 2 | GRAD | GRAD_CDF | 800 | 9000 | 2 | 8 | 550 | 40 |

**Ammo sets** (lines 18–22): Uses `ARTY_Sh_122_*` / `ARTY_Sh_82_*` / `ARTY_R_227mm_HE_Rocket` + base game fallbacks (`Sh_122_HE`, `Sh_82_HE`, `R_GRAD`).

Extended magazines use `ARTY_`-prefixed names, all gated at WFBE_UP_ARTYAMMO = 1.

---

### CDF — Artillery_CDF.sqf

`Common/Config/Core_Artillery/Artillery_CDF.sqf:4-44` (loaded unconditionally)

| # | Display Name | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|
| 0 | D30 | D30_CDF | 1000 | 7000 | 7 | 8 | 500 | 50 |
| 1 | 2B14 | 2b14_82mm_CDF | 50 | 5500 | 4 | 4 | 475 | 60 |
| 2 | GRAD | GRAD_CDF | 800 | 9000 | 2 | 8 | 550 | 40 |

Ammo sets and extended magazines identical in structure to Artillery_INS.sqf (ARTY_ prefixed). Same WFBE_UP_ARTYAMMO = 1 gate applies.

CDF plays as WEST side (`Root_CDF.sqf:3`).

---

## GUER Factions

### GUE / TK GUE / PMC (CombinedOps) — Artillery_CO_GUE.sqf

`Common/Config/Core_Artillery/Artillery_CO_GUE.sqf:4-40`

| # | Display Name | Weapon Class | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|---|
| 0 | D30 | D30 | D30_TK_GUE_EP1 | 1000 | 7000 | 7 | 8 | 500 | 50 |
| 1 | 2B14 | 2B14 | 2b14_82mm_TK_GUE_EP1, 2b14_82mm_GUE | 50 | 5500 | 4 | 4 | 475 | 60 |

**Ammo sets** (lines 18–21):

| Piece | Standard | Special (WFBE_UP_ARTYAMMO 1) |
|---|---|---|
| D30 | Sh_122_HE | Sh_122_WP, Sh_122_SADARM, Sh_122_LASER, Sh_122_SMOKE, Sh_122_ILLUM |
| 2B14 | Sh_82_HE | Sh_82_WP, Sh_82_ILLUM |

No GRAD in this config. GUE CO has no rocket artillery.

---

### GUE (Arma 2 vanilla) — Artillery_GUE.sqf

`Common/Config/Core_Artillery/Artillery_GUE.sqf:4-36`

| # | Display Name | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|
| 0 | 2B14 | 2b14_82mm_GUE | 50 | 5500 | 4 | 4 | 475 | 60 |

Only the mortar. No D30, no GRAD in vanilla GUE.

Ammo set: ARTY_Sh_82_HE, Sh_82_HE, ARTY_Sh_82_WP, ARTY_Sh_82_ILLUM.
Extended magazines (WFBE_UP_ARTYAMMO = 1): ARTY_8Rnd_82mmWP_2B14, ARTY_8Rnd_82mmILLUM_2B14.
No LASER or SADARM available to vanilla GUE.

---

### TK GUE / PMC (Arrowhead only) — Artillery_OA_TKGUE.sqf

`Common/Config/Core_Artillery/Artillery_OA_TKGUE.sqf:4-40`

| # | Display Name | Vehicle Classnames | Range Min (m) | Range Max (m) | Reload (s) | Burst | Velocity | Dispersion (m) |
|---|---|---|---|---|---|---|---|---|
| 0 | D30 | D30_TK_GUE_EP1 | 1000 | 8000 | 7 | 8 | 500 | 50 |
| 1 | 2B14 | 2b14_82mm_TK_GUE_EP1 | 50 | 7500 | 4 | 4 | 475 | 60 |

Ammo sets and extended mags mirror Artillery_CO_GUE.sqf (base `Sh_122_*` / `Sh_82_*` classnames), same WFBE_UP_ARTYAMMO = 1 gate.

---

## Cross-Faction Stats Comparison

### WEST pieces

| Piece | Min (m) | Max (m) | Burst | Reload (s) | Dispersion (m) | CO only? |
|---|---|---|---|---|---|---|
| M119 (CO_US) | 1000 | 7000 | 10 | 7 | 50 | Yes |
| M119 (USMC vanilla) | 1000 | 8000 | 8 | 7 | 50 | No |
| M252 (CO_US) | 50 | 5500 | 4 | 4 | 60 | Yes |
| M252 (USMC vanilla) | 50 | 7500 | 4 | 4 | 60 | No |
| MLRS (CO_US) | 1200 | 9000 | 12 | 2 | 40 | Yes |
| MLRS (USMC vanilla) | 1200 | 9000 | 6 | 2 | 40 | No |
| Stryker MC (CO_US) | 550 | 8000 | 8 | 4 | 55 | Yes |

### EAST/GUER pieces

| Piece | Min (m) | Max (m) | Burst | Reload (s) | Dispersion (m) | Config |
|---|---|---|---|---|---|---|
| D30 (CO_RU) | 1000 | 7000 | 10 | 7 | 50 | Artillery_CO_RU.sqf |
| D30 (OA_TKA) | 1000 | 8000 | 8 | 7 | 50 | Artillery_OA_TKA.sqf |
| D30 (CO_GUE) | 1000 | 7000 | 8 | 7 | 50 | Artillery_CO_GUE.sqf |
| D30 (OA_TKGUE) | 1000 | 8000 | 8 | 7 | 50 | Artillery_OA_TKGUE.sqf |
| D30 (INS/CDF) | 1000 | 7000–8000 | 8 | 7 | 50 | Artillery_INS/CDF.sqf |
| 2B14 (CO_RU) | 50 | 5500 | 4 | 4 | 60 | Artillery_CO_RU.sqf |
| 2B14 (OA_TKA) | 50 | 7500 | 4 | 4 | 60 | Artillery_OA_TKA.sqf |
| 2B14 (CO_GUE) | 50 | 5500 | 4 | 4 | 60 | Artillery_CO_GUE.sqf |
| 2B14 (OA_TKGUE) | 50 | 7500 | 4 | 4 | 60 | Artillery_OA_TKGUE.sqf |
| 2B14 (GUE vanilla) | 50 | 5500 | 4 | 4 | 60 | Artillery_GUE.sqf |
| GRAD (CO_RU) | 800 | 9000 | 10 | 2 | 40 | Artillery_CO_RU.sqf |
| GRAD (OA_TKA) | 800 | 9000 | 8 | 2 | 40 | Artillery_OA_TKA.sqf |
| GRAD (INS/CDF/RU vanilla) | 800 | 9000 | 8 | 2 | 40 | Artillery_INS/CDF/RU.sqf |

---

## Upgrade Gate: Artillery Ammunition (WFBE_UP_ARTYAMMO)

All special artillery rounds (WP, SADARM, LASER, SMOKE, ILLUM) are gated behind a single upgrade level.

| Constant | Index | Max levels | Cost (credits) | Research time (s) | Dependencies |
|---|---|---|---|---|---|
| WFBE_UP_ARTYAMMO | 17 | 1 | 2500 | 60 | WFBE_UP_GEAR 1, WFBE_UP_HEAVY 1 |

Sources: `Common/Init/Init_CommonConstants.sqf:54`, `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:50,76-77,111-112,138-139`.

The upgrade is only shown when `WFBE_C_ARTILLERY > 0` (artillery module is enabled, `Upgrades_CO_US.sqf:23`).

The runtime check in `Common/Functions/Common_GetArtilleryAmmoOptions.sqf:50` reads:
```
_currentUpgrade = (_sideValue Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_ARTYAMMO;
```
Any ammo whose `EXTENDED_MAGS_UPGRADE` level exceeds `_currentUpgrade` is filtered out of the fire mission menu. Standard HE (always index 0 in each ammo set) has no extended-mag entry and is always available.

The AI commander upgrade order (`Upgrades_CO_US.sqf:148-185`) does not include `WFBE_UP_ARTYAMMO` in its ordered list — the AI will not research artillery ammunition automatically.

---

## Ammo Type Quick Reference

| Type | WEST classname | EAST/GUER classname | Effect |
|---|---|---|---|
| HE | Sh_105_HE / 120mmHE_M120 / R_MLRS | Sh_122_HE / Sh_82_HE / R_GRAD | High explosive, baseline |
| WP | Sh_105_WP / Sh_81_WP | Sh_122_WP / Sh_82_WP | White phosphorus, deploys smoke on impact |
| SMOKE | Sh_105_SMOKE | Sh_122_SMOKE | Smoke only (no incendiary) |
| SADARM | Sh_105_SADARM | Sh_122_SADARM | Sensor-fuzed anti-armor submunition |
| LASER | Sh_105_LASER | Sh_122_LASER | Laser-guided precision round |
| ILLUM | Sh_105_ILLUM / Sh_81_ILLUM | Sh_122_ILLUM / Sh_82_ILLUM | Illumination flare round |

Smoke-deploying projectile lists (used internally to spawn smoke effects) are defined per faction in `WFBE_%1_ARTILLERY_DEPLOY_SMOKE`. For WEST CO: `['Sh_105_WP','Sh_105_SMOKE','Sh_81_WP']` (`Artillery_CO_US.sqf:15`). For EAST CO: `['Sh_122_WP','Sh_122_SMOKE','Sh_82_WP']` (`Artillery_CO_RU.sqf:15`).

In ARTY-module configs (CDF, INS, vanilla RU, USMC, GUE), the classnames use the `ARTY_` prefix for their extended/special rounds. The base HE round always has both the `ARTY_`-prefixed and non-prefixed variant listed in `ARTILLERY_AMMOS`.

---

## Developer Notes

- **Adding a new artillery piece**: add its vehicle classname to the appropriate `WFBE_%1_ARTILLERY_CLASSNAMES` sub-array, its ammo classnames to the matching `WFBE_%1_ARTILLERY_AMMOS` sub-array, and its special mags to `WFBE_%1_ARTILLERY_EXTENDED_MAGS`. The indices must stay aligned across all seven parallel arrays. (`Common_GetArtilleryAmmoOptions.sqf:27-28` relies on positional index.)
- **GRAD and MLRS never get special rounds**: their `EXTENDED_MAGS` entry is always `[]`. SADARM and LASER are only available on towed/wheeled howitzers (M119/D30) and the mortar only gets WP and ILLUM.
- **Velocity and dispersion differ between CO and vanilla configs**: CO_US uses velocity 250–275 and vanilla USMC uses 500–550. This affects how the AI calculates firing solutions. Do not mix configs between game modes.
- **GUE vanilla has no D30**: only the 2B14 mortar. If a GUE commander needs long-range indirect fire, the faction must be running CombinedOps.
- **The duplicate ILLUM entry** (`Artillery_OA_TKA.sqf:14`, `Artillery_CO_GUE.sqf:14`, `Artillery_OA_TKGUE.sqf:14`): `ARTILLERY_AMMO_ILLUMN` lists the same class twice (`['Sh_122_ILLUM','Sh_122_ILLUM']` in OA_TKA and OA_TKGUE; a similar pattern in CO_GUE). This does not cause a runtime error but the second entry is redundant.
- **Artillery_OA_US.sqf exists in Core_Artillery/ but is not loaded by any Root file** — `Root_US.sqf` and `Root_US_Camo.sqf` always call `Artillery_CO_US.sqf` unconditionally (`Root_US.sqf:131`, `Root_US_Camo.sqf:124`). The file is dead/unreferenced code on disk and should not be treated as an active faction configuration.
- **WEST-side factions (US, US Camo, USMC, CDF) all write to the `WFBE_WEST_*` artillery namespace.** Only one Root file runs per match, so there is no overwrite conflict in practice. If two WEST factions were ever active simultaneously they would clobber each other.

---

## Continue Reading

- [Support-Specials-And-Tactical-Modules-Atlas](Support-Specials-And-Tactical-Modules-Atlas) — how artillery fire missions are requested and processed mechanically
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — full upgrade tree including WFBE_UP_ARTYAMMO dependencies and costs
- [Arty-Module-Special-Munitions](Arty-Module-Special-Munitions) — deeper dive into SADARM, LASER, and ILLUM round behavior
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — vehicle classnames for all factions including artillery vehicles
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — WFBE_C_* / WFBE_UP_* constant naming conventions used throughout
