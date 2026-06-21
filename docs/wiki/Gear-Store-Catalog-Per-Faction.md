# Gear Store Catalog Per Faction

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The infantry **Buy Gear** menu (`WFBE_BuyGearMenu`) sells weapons, magazines, and backpacks whose purchase price and unlock level are defined per faction in `Common/Config/Gear/Gear_<TAG>.sqf`. The system that consumes these files is mapped in [Gear, Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas); this page catalogs the actual **content** — every item each faction's gear file defines, with its price and the minimum gear-upgrade level required before it can be bought.

This is the **complete** per-faction enumeration of all seven gear files. For a curated quick-reference of only the high-impact rows (price `>= 300` or gear level `>= 4`), see [Gear Store Price And Upgrade Catalog](Gear-Store-Price-And-Upgrade-Catalog).

## How the gear files work

All seven gear files are compiled **client-side** at mission init (`Init_Common.sqf:236-242`, inside `if (local player)` at `:235`, under the Combined Operations case). Each file builds parallel arrays and hands them to a processor (`Gear_US.sqf:348-353` shows the full set; the magazine and backpack blocks omit `_m`):

| Array | Meaning |
| --- | --- |
| `_u` | classname |
| `_p` | picture override (`''` = use the config `picture`) |
| `_n` | label override (`''` = use the config `displayName`) |
| `_o` | **price**, in game funds |
| `_z` | **minimum gear-upgrade level** |
| `_m` | (weapons only) forced magazines; `-1` = auto-pick from the weapon config |

Three processors each store one metadata array per item into `missionNamespace`, keyed by classname:

| Block | Processor | Namespace key | Evidence |
| --- | --- | --- | --- |
| Magazines | `Config_Magazines.sqf` | `Mag_<class>` | `Config_Magazines.sqf:32` |
| Weapons / items | `Config_Weapons.sqf` | `<class>` | `Config_Weapons.sqf:42` |
| Backpacks | `Config_Backpack.sqf` | `<class>` | `Config_Backpack.sqf:64`, `:81` |

In every stored array, index `[2]` is the price and index `[3]` is the upgrade level (`Config_Magazines.sqf:26-27`, `Config_Weapons.sqf:36-37`, `Config_Backpack.sqf:27-28`). Most weapon entries use `_m = -1` (auto), letting `Config_Weapons.sqf` derive magazines from the config. Three entries use forced arrays: `VSS_vintorez` (RU) forces `["20Rnd_9x39_SP5_VSS"]`, `UZI_EP1` (TKA) forces `["30Rnd_9x19_UZI","30Rnd_9x19_UZI_SD"]`, and `UZI_SD_EP1` (TKA) forces `["30Rnd_9x19_UZI_SD"]`.

### The "Min level" gate

`_z` is the minimum **`WFBE_UP_GEAR`** research level (`WFBE_UP_GEAR = 13`, `Init_CommonConstants.sqf:50`) the player's side must have reached before the item is listed. `Client_UI_Gear_FillList.sqf:12` reads the joined side's current gear-upgrade level, and `:21` adds an item to the menu only when `(_get select 3) <= _upgrade_level`. An item with **Min level 5** is therefore invisible and unbuyable through this menu until the side researches gear level 5; **Min level 0** items are always available. Upgrade levels per faction are cataloged in [Upgrade Research Reference](Upgrade-Research-Cross-Faction-Reference).

### Categories and pools

Each item carries a category code at array index `[4]` that decides which menu tab it lands in:

- **Weapons** are categorized by their CfgWeapons `type`, which maps to a category code: Primary (`0`), Pistol (`1`), Launcher (`2`), Equipment (`4`), Item (`5`) — `Config_Weapons.sqf:20-28`.
- **Magazines** fall into the Main pool (`100`, type 16–255) or Secondary pool (`101`, type 256–4095) — `Config_Magazines.sqf:18-21`.
- **Backpacks** are either a carryable backpack (`200`) or an assemble-able static-weapon bag (`201`, i.e. its config defines an `assembleInfo` class) — `Config_Backpack.sqf:14`, `:29`, `:70`, `:79`. Launchers, backpacks, and bags all sort under the **Secondary** tab (`Config_SortWeapons.sqf:26-27`).

Assemble-able bags (`201`) are the deployable static weapons — tripod-mounted MGs, GMGs, AT launchers, and mortars that a player carries as a backpack and then builds in the field (e.g. the US `M252_US_Bag_EP1` mortar and `TOW_TriPod_US_Bag_EP1`).

### Duplicates and conditional availability

- **Duplicate classnames are deduplicated; the first definition wins.** A class already present in `missionNamespace` is skipped (`Config_Magazines.sqf:13`, `:38-41`). For example TKA lists `100Rnd_762x54_PK` twice (`Gear_TKA.sqf:118` at $30, `:124` at $25); the first ($30) is kept and the second is ignored. The duplicate prices in the tables below are reproduced as written in source — only the first occurrence of a repeated classname is live.
- **Thermal-scope primaries are config-gated.** A primary weapon whose `visionMode` includes `"Ti"` is withheld from purchase unless the `WFBE_C_GAMEPLAY_THERMAL_IMAGING` parameter is `1` or `3` (`Config_SortWeapons.sqf:21-37`). This hides the TWS variants (e.g. `M249_TWS_EP1`, `m107_TWS_EP1`) when thermal imaging is disabled.
- **Purchases and the funds debit are client-side**: the loadout is applied locally via `WFBE_CO_FNC_EquipUnit` / `WFBE_CO_FNC_EquipVehicle` and the price is subtracted with `WFBE_CL_FNC_ChangeClientFunds` (`GUI_BuyGearMenu.sqf:439-451`); see the authority caveat in [Gear, Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas).

### Scope

This page catalogs what each `Gear_<TAG>.sqf` **defines**. Which of these items actually appear in a given **side's** menu also depends on that side's `Loadout_<side>.sqf` selection and the side sort pools (`Config_SortWeapons.sqf`, `Config_SortMagazines.sqf`) — that layer is summarized in [Gear store loadout route catalog](Gear-Store-Loadout-Route-Catalog) and mapped systemically by the [Gear, Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas). Prices are in the in-game funds economy ([Economy, Towns And Supply](Economy-Towns-And-Supply)).

## Faction coverage

| Faction tag | Gear file | Magazines | Weapons / items | Backpacks |
| --- | --- | --- | --- | --- |
| US | `Gear_US.sqf` | 56 | 55 | 18 |
| USMC | `Gear_USMC.sqf` | 42 | 50 | — (no block) |
| RU | `Gear_RU.sqf` | 45 | 34 | dynamic, ≤6 |
| TKA | `Gear_TKA.sqf` | 58 | 44 | 23 |
| BAF | `Gear_BAF.sqf` | 10 | 15 | 14 |
| GUE | `Gear_GUE.sqf` | 18 | 21 | — (no block) |
| PMC | `Gear_PMC.sqf` | 8 | 16 | — (no block) |

All seven files load on every client (`Init_Common.sqf:236-242`); GUE, PMC, and USMC define no backpack block, and RU builds its backpacks dynamically (below).

## US (`Gear_US.sqf`)

### Weapons and items — `Gear_US.sqf:356-741`

| Classname | Price | Min level |
| --- | --- | --- |
| `G36A_camo` | $275 | 1 |
| `G36C_camo` | $250 | 1 |
| `G36_C_SD_camo` | $300 | 3 |
| `G36K_camo` | $260 | 2 |
| `M16A2` | $75 | 1 |
| `M16A2GL` | $90 | 2 |
| `M24_des_EP1` | $200 | 2 |
| `M60A4_EP1` | $175 | 2 |
| `m240_scoped_EP1` | $215 | 2 |
| `M249_EP1` | $250 | 2 |
| `M249_m145_EP1` | $265 | 3 |
| `M249_TWS_EP1` | $365 | 5 |
| `M4A1` | $90 | 1 |
| `M4A3_CCO_EP1` | $115 | 2 |
| `M4A3_RCO_GL_EP1` | $130 | 2 |
| `m107` | $400 | 4 |
| `m107_TWS_EP1` | $600 | 5 |
| `Mk_48_DES_EP1` | $250 | 2 |
| `MG36_camo` | $240 | 3 |
| `M32_EP1` | $200 | 2 |
| `M79_EP1` | $75 | 1 |
| `Mk13_EP1` | $125 | 2 |
| `M14_EP1` | $250 | 2 |
| `M110_NVG_EP1` | $350 | 4 |
| `M110_TWS_EP1` | $450 | 5 |
| `SCAR_L_CQC` | $200 | 1 |
| `SCAR_L_CQC_Holo` | $210 | 2 |
| `SCAR_L_STD_Mk4CQT` | $240 | 2 |
| `SCAR_L_STD_EGLM_RCO` | $250 | 3 |
| `SCAR_L_CQC_EGLM_Holo` | $235 | 2 |
| `SCAR_L_STD_EGLM_TWS` | $330 | 5 |
| `SCAR_L_STD_HOLO` | $200 | 2 |
| `SCAR_H_CQC_CCO` | $250 | 2 |
| `SCAR_H_CQC_CCO_SD` | $270 | 3 |
| `SCAR_H_STD_EGLM_Spect` | $285 | 4 |
| `SCAR_H_LNG_Sniper` | $320 | 4 |
| `SCAR_H_LNG_Sniper_SD` | $340 | 4 |
| `SCAR_H_STD_TWS_SD` | $350 | 4 |
| `Stinger` | $350 | 3 |
| `Javelin` | $500 | 5 |
| `Laserdesignator` | $250 | 4 |
| `M136` | $125 | 0 |
| `MAAWS` | $500 | 3 |
| `Colt1911` | $15 | 0 |
| `M9` | $20 | 0 |
| `M9SD` | $25 | 0 |
| `glock17_EP1` | $30 | 0 |
| `Binocular` | $10 | 0 |
| `Binocular_Vector` | $35 | 2 |
| `NVGoggles` | $25 | 0 |
| `ItemCompass` | $5 | 0 |
| `ItemGPS` | $25 | 1 |
| `ItemMap` | $5 | 0 |
| `ItemRadio` | $10 | 0 |
| `ItemWatch` | $5 | 0 |

### Magazines — `Gear_US.sqf:10-346`

| Classname | Price | Min level |
| --- | --- | --- |
| `5Rnd_762x51_M24` | $10 | 0 |
| `6Rnd_HE_M203` | $60 | 0 |
| `6Rnd_FlareWhite_M203` | $30 | 0 |
| `6Rnd_FlareGreen_M203` | $30 | 0 |
| `6Rnd_FlareRed_M203` | $30 | 0 |
| `6Rnd_FlareYellow_M203` | $30 | 0 |
| `6Rnd_Smoke_M203` | $40 | 0 |
| `6Rnd_SmokeRed_M203` | $40 | 0 |
| `6Rnd_SmokeGreen_M203` | $40 | 0 |
| `6Rnd_SmokeYellow_M203` | $40 | 0 |
| `7Rnd_45ACP_1911` | $5 | 0 |
| `8Rnd_B_Beneli_Pellets` | $5 | 0 |
| `10Rnd_127x99_m107` | $25 | 0 |
| `15Rnd_9x19_M9` | $5 | 0 |
| `15Rnd_9x19_M9SD` | $5 | 0 |
| `17Rnd_9x19_glock17` | $5 | 0 |
| `20Rnd_762x51_B_SCAR` | $20 | 0 |
| `20rnd_762x51_SB_SCAR` | $30 | 0 |
| `20Rnd_762x51_DMR` | $15 | 0 |
| `20Rnd_556x45_Stanag` | $10 | 0 |
| `30Rnd_9x19_UZI` | $5 | 0 |
| `30Rnd_9x19_UZI_SD` | $10 | 0 |
| `30Rnd_556x45_G36` | $15 | 0 |
| `30Rnd_556x45_G36SD` | $20 | 0 |
| `30Rnd_556x45_Stanag` | $15 | 0 |
| `30Rnd_556x45_StanagSD` | $20 | 0 |
| `100Rnd_556x45_BetaCMag` | $30 | 2 |
| `100Rnd_762x51_M240` | $35 | 0 |
| `100Rnd_556x45_M249` | $30 | 0 |
| `200Rnd_556x45_M249` | $60 | 0 |
| `Laserbatteries` | $30 | 4 |
| `MAAWS_HEAT` | $350 | 3 |
| `MAAWS_HEDP` | $400 | 4 |
| `Stinger` | $150 | 3 |
| `Javelin` | $900 | 5 |
| `HandGrenade_West` | $10 | 0 |
| `HandGrenade_Stone` | $1 | 0 |
| `SmokeShell` | $5 | 0 |
| `SmokeShellRed` | $5 | 0 |
| `SmokeShellGreen` | $5 | 0 |
| `SmokeShellBlue` | $5 | 0 |
| `SmokeShellYellow` | $5 | 0 |
| `SmokeShellOrange` | $5 | 0 |
| `SmokeShellPurple` | $5 | 0 |
| `FlareWhite_M203` | $5 | 0 |
| `FlareYellow_M203` | $5 | 0 |
| `FlareGreen_M203` | $5 | 0 |
| `FlareRed_M203` | $5 | 0 |
| `1Rnd_HE_M203` | $20 | 0 |
| `1Rnd_Smoke_M203` | $10 | 0 |
| `1Rnd_SmokeRed_M203` | $10 | 0 |
| `1Rnd_SmokeGreen_M203` | $10 | 0 |
| `1Rnd_SmokeYellow_M203` | $10 | 0 |
| `Mine` | $40 | 1 |
| `PipeBomb` | $50 | 1 |
| `IR_Strobe_Target` | $25 | 1 |

### Backpacks and deployable bags — `Gear_US.sqf:750-858`

| Classname | Price | Min level |
| --- | --- | --- |
| `US_Assault_Pack_EP1` | $50 | 0 |
| `US_Assault_Pack_Ammo_EP1` | $50 | 0 |
| `US_Assault_Pack_AmmoSAW_EP1` | $50 | 0 |
| `US_Assault_Pack_AT_EP1` | $50 | 0 |
| `US_Assault_Pack_Explosives_EP1` | $50 | 0 |
| `US_Patrol_Pack_EP1` | $60 | 0 |
| `US_Patrol_Pack_Ammo_EP1` | $60 | 0 |
| `US_Patrol_Pack_Specops_EP1` | $60 | 2 |
| `US_Backpack_EP1` | $70 | 1 |
| `US_Backpack_AmmoMG_EP1` | $70 | 1 |
| `US_Backpack_AT_EP1` | $70 | 2 |
| `US_Backpack_Specops_EP1` | $70 | 2 |
| `Tripod_Bag` | $15 | 1 |
| `M2HD_mini_TriPod_US_Bag_EP1` | $250 | 2 |
| `M2StaticMG_US_Bag_EP1` | $325 | 2 |
| `MK19_TriPod_US_Bag_EP1` | $600 | 3 |
| `TOW_TriPod_US_Bag_EP1` | $750 | 4 |
| `M252_US_Bag_EP1` | $800 | 1 |

## USMC (`Gear_USMC.sqf`)

### Weapons and items — `Gear_USMC.sqf:272-622`

| Classname | Price | Min level |
| --- | --- | --- |
| `DMR` | $300 | 3 |
| `G36a` | $275 | 1 |
| `G36C` | $250 | 1 |
| `G36_C_SD_eotech` | $300 | 3 |
| `G36K` | $260 | 2 |
| `M16A2` | $75 | 1 |
| `M16A2GL` | $90 | 2 |
| `m16a4` | $100 | 1 |
| `m16a4_acg` | $115 | 2 |
| `M16A4_ACG_GL` | $130 | 2 |
| `M16A4_GL` | $115 | 2 |
| `M24` | $200 | 2 |
| `M40A3` | $250 | 2 |
| `M240` | $200 | 2 |
| `M249` | $250 | 2 |
| `M4A1` | $90 | 1 |
| `M4A1_Aim` | $100 | 2 |
| `M4A1_Aim_camo` | $120 | 2 |
| `M4SPR` | $180 | 2 |
| `M4A1_RCO_GL` | $115 | 2 |
| `M4A1_AIM_SD_camo` | $160 | 3 |
| `M4A1_HWS_GL_SD_Camo` | $200 | 3 |
| `M4A1_HWS_GL` | $180 | 3 |
| `M4A1_HWS_GL_camo` | $195 | 3 |
| `m8_carbine` | $220 | 2 |
| `m8_carbineGL` | $235 | 3 |
| `m8_compact` | $225 | 2 |
| `m8_SAW` | $250 | 2 |
| `m8_sharpshooter` | $270 | 3 |
| `m107` | $400 | 5 |
| `M1014` | $60 | 0 |
| `Mk_48` | $250 | 3 |
| `MP5A5` | $50 | 0 |
| `MP5SD` | $60 | 1 |
| `MG36` | $240 | 3 |
| `Stinger` | $350 | 3 |
| `Javelin` | $500 | 5 |
| `Laserdesignator` | $250 | 4 |
| `M136` | $125 | 0 |
| `SMAW` | $400 | 4 |
| `Colt1911` | $15 | 0 |
| `M9` | $20 | 0 |
| `M9SD` | $25 | 0 |
| `Binocular` | $10 | 0 |
| `NVGoggles` | $25 | 0 |
| `ItemCompass` | $5 | 0 |
| `ItemGPS` | $25 | 1 |
| `ItemMap` | $5 | 0 |
| `ItemRadio` | $10 | 0 |
| `ItemWatch` | $5 | 0 |

### Magazines — `Gear_USMC.sqf:10-262`

| Classname | Price | Min level |
| --- | --- | --- |
| `5Rnd_762x51_M24` | $10 | 0 |
| `7Rnd_45ACP_1911` | $5 | 0 |
| `8Rnd_B_Beneli_74Slug` | $5 | 0 |
| `10Rnd_127x99_m107` | $25 | 0 |
| `15Rnd_9x19_M9` | $5 | 0 |
| `15Rnd_9x19_M9SD` | $5 | 0 |
| `20Rnd_762x51_DMR` | $15 | 0 |
| `20Rnd_556x45_Stanag` | $10 | 0 |
| `30Rnd_9x19_MP5` | $10 | 0 |
| `30Rnd_9x19_MP5SD` | $10 | 0 |
| `30Rnd_556x45_G36` | $15 | 0 |
| `30Rnd_556x45_G36SD` | $20 | 0 |
| `30Rnd_556x45_Stanag` | $15 | 0 |
| `30Rnd_556x45_StanagSD` | $20 | 0 |
| `100Rnd_556x45_BetaCMag` | $30 | 2 |
| `100Rnd_762x51_M240` | $35 | 0 |
| `200Rnd_556x45_M249` | $50 | 0 |
| `Laserbatteries` | $30 | 4 |
| `SMAW_HEAA` | $300 | 4 |
| `SMAW_HEDP` | $350 | 5 |
| `Stinger` | $150 | 3 |
| `Javelin` | $900 | 5 |
| `HandGrenade_West` | $10 | 0 |
| `HandGrenade_Stone` | $1 | 0 |
| `SmokeShell` | $5 | 0 |
| `SmokeShellRed` | $5 | 0 |
| `SmokeShellGreen` | $5 | 0 |
| `SmokeShellBlue` | $5 | 0 |
| `SmokeShellYellow` | $5 | 0 |
| `SmokeShellOrange` | $5 | 0 |
| `SmokeShellPurple` | $5 | 0 |
| `FlareWhite_M203` | $5 | 0 |
| `FlareYellow_M203` | $5 | 0 |
| `FlareGreen_M203` | $5 | 0 |
| `FlareRed_M203` | $5 | 0 |
| `1Rnd_HE_M203` | $20 | 0 |
| `1Rnd_Smoke_M203` | $10 | 0 |
| `1Rnd_SmokeRed_M203` | $10 | 0 |
| `1Rnd_SmokeGreen_M203` | $10 | 0 |
| `1Rnd_SmokeYellow_M203` | $10 | 0 |
| `Mine` | $40 | 1 |
| `PipeBomb` | $50 | 1 |

### Backpacks

This faction's gear file defines no backpack block.

## RU (`Gear_RU.sqf`)

### Weapons and items — `Gear_RU.sqf:290-528`

| Classname | Price | Min level |
| --- | --- | --- |
| `AK_47_M` | $40 | 1 |
| `AK_47_S` | $50 | 1 |
| `AK_74` | $75 | 1 |
| `AK_74_GL` | $85 | 2 |
| `AK_107_kobra` | $110 | 2 |
| `AK_107_GL_kobra` | $125 | 2 |
| `AK_107_pso` | $120 | 2 |
| `AK_107_GL_pso` | $135 | 3 |
| `AKS_74_kobra` | $80 | 0 |
| `AKS_74_pso` | $95 | 2 |
| `AKS_74_U` | $80 | 1 |
| `AKS_74_UN_kobra` | $110 | 2 |
| `bizon` | $90 | 0 |
| `bizon_silenced` | $120 | 2 |
| `PK` | $150 | 2 |
| `ksvk` | $250 | 4 |
| `Pecheneg` | $200 | 3 |
| `RPK_74` | $125 | 2 |
| `Saiga12K` | $80 | 0 |
| `SVD` | $150 | 3 |
| `SVD_CAMO` | $170 | 3 |
| `VSS_vintorez` | $175 | 5 |
| `Igla` | $250 | 3 |
| `MetisLauncher` | $500 | 5 |
| `RPG7V` | $90 | 1 |
| `RPG18` | $50 | 0 |
| `Strela` | $225 | 3 |
| `Makarov` | $15 | 0 |
| `MakarovSD` | $20 | 1 |
| `ItemCompass` | $5 | 0 |
| `ItemGPS` | $25 | 1 |
| `ItemMap` | $5 | 0 |
| `ItemRadio` | $10 | 0 |
| `ItemWatch` | $5 | 0 |

### Magazines — `Gear_RU.sqf:10-280`

| Classname | Price | Min level |
| --- | --- | --- |
| `5Rnd_127x108_KSVK` | $12 | 0 |
| `8Rnd_9x18_Makarov` | $2 | 0 |
| `8Rnd_9x18_MakarovSD` | $3 | 1 |
| `8Rnd_B_Saiga12_74Slug` | $5 | 0 |
| `10Rnd_762x54_SVD` | $5 | 0 |
| `10Rnd_9x39_SP5_VSS` | $8 | 2 |
| `20Rnd_9x39_SP5_VSS` | $16 | 3 |
| `30Rnd_545x39_AK` | $10 | 0 |
| `30Rnd_545x39_AKSD` | $15 | 2 |
| `30Rnd_762x39_AK47` | $5 | 0 |
| `64Rnd_9x19_Bizon` | $6 | 0 |
| `64Rnd_9x19_SD_Bizon` | $8 | 1 |
| `75Rnd_545x39_RPK` | $10 | 0 |
| `100Rnd_762x54_PK` | $15 | 0 |
| `AT13` | $600 | 3 |
| `Igla` | $150 | 3 |
| `OG7` | $100 | 3 |
| `PG7V` | $50 | 1 |
| `PG7VR` | $125 | 3 |
| `PG7VL` | $75 | 2 |
| `Strela` | $100 | 3 |
| `HandGrenade_East` | $10 | 0 |
| `HandGrenade_Stone` | $1 | 0 |
| `SmokeShell` | $5 | 0 |
| `SmokeShellRed` | $5 | 0 |
| `SmokeShellGreen` | $5 | 0 |
| `SmokeShellBlue` | $5 | 0 |
| `SmokeShellYellow` | $5 | 0 |
| `SmokeShellOrange` | $5 | 0 |
| `SmokeShellPurple` | $5 | 0 |
| `FlareWhite_GP25` | $5 | 0 |
| `FlareYellow_GP25` | $5 | 0 |
| `FlareGreen_GP25` | $5 | 0 |
| `FlareRed_GP25` | $5 | 0 |
| `1Rnd_HE_M203` | $20 | 0 |
| `1Rnd_HE_GP25` | $15 | 0 |
| `1Rnd_SMOKE_GP25` | $5 | 0 |
| `1Rnd_SMOKERED_GP25` | $5 | 0 |
| `1Rnd_SMOKEGREEN_GP25` | $5 | 0 |
| `1Rnd_SMOKEYELLOW_GP25` | $5 | 0 |
| `MineE` | $40 | 1 |
| `PipeBomb` | $50 | 1 |
| `20Rnd_B_AA12_Pellets` | $10 | 2 |
| `20Rnd_B_AA12_74Slug` | $10 | 2 |
| `20Rnd_B_AA12_HE` | $40 | 4 |

### Backpacks (built at runtime)

RU has no static backpack list. Instead it checks eight candidate classes with `isClass` and offers the **first six that exist on the server**, all at gear level 0 (`Gear_RU.sqf:538-581`). Prices mirror the US-side equivalents (`_bp_prices`, `Gear_RU.sqf:552`). The candidates, in priority order (`Gear_RU.sqf:540-548`):

| Candidate (priority order) | Price |
| --- | --- |
| `TK_Assault_Pack_EP1` | $50 |
| `TK_RPG_Backpack_EP1` | $70 |
| `TK_ALICE_Pack_EP1` | $60 |
| `CZ_Backpack_EP1` | $70 |
| `CZ_VestPouch_EP1` | $50 |
| `TK_AmmoBox_Backpack_EP1` | $70 |
| `US_Backpack_EP1` (fallback) | $70 |
| `US_Assault_Pack_EP1` (fallback) | $50 |

At most six of these are offered; the `isClass` filter and six-entry cap are at `Gear_RU.sqf:561-567`.

## TKA (`Gear_TKA.sqf`)

### Weapons and items — `Gear_TKA.sqf:368-676`

| Classname | Price | Min level |
| --- | --- | --- |
| `AK_47_M` | $40 | 1 |
| `AK_47_S` | $50 | 1 |
| `AK_74` | $75 | 1 |
| `AK_74_GL` | $85 | 2 |
| `AK_74_GL_kobra` | $100 | 2 |
| `AKS_74` | $70 | 1 |
| `AKS_74_GOSHAWK` | $180 | 5 |
| `AKS_74_kobra` | $80 | 1 |
| `AKS_74_NSPU` | $110 | 3 |
| `AKS_74_pso` | $95 | 2 |
| `AKS_74_U` | $80 | 1 |
| `FN_FAL` | $110 | 2 |
| `FN_FAL_ANPVS4` | $140 | 5 |
| `ksvk` | $250 | 4 |
| `LeeEnfield` | $25 | 1 |
| `PK` | $150 | 2 |
| `RPK_74` | $125 | 2 |
| `Sa58P_EP1` | $100 | 1 |
| `Sa58V_EP1` | $110 | 1 |
| `Sa58V_RCO_EP1` | $135 | 2 |
| `Sa58V_CCO_EP1` | $145 | 2 |
| `SVD` | $150 | 3 |
| `SVD_des_EP1` | $170 | 3 |
| `SVD_NSPU_EP1` | $200 | 5 |
| `Igla` | $250 | 3 |
| `MetisLauncher` | $500 | 5 |
| `M47Launcher_EP1` | $250 | 3 |
| `RPG7V` | $90 | 1 |
| `RPG18` | $50 | 0 |
| `Strela` | $225 | 3 |
| `Makarov` | $15 | 0 |
| `MakarovSD` | $25 | 1 |
| `revolver_EP1` | $20 | 0 |
| `revolver_gold_EP1` | $50 | 1 |
| `Sa61_EP1` | $30 | 0 |
| `UZI_EP1` | $35 | 1 |
| `UZI_SD_EP1` | $50 | 2 |
| `Binocular` | $10 | 0 |
| `NVGoggles` | $25 | 0 |
| `ItemCompass` | $5 | 0 |
| `ItemGPS` | $25 | 1 |
| `ItemMap` | $5 | 0 |
| `ItemRadio` | $10 | 0 |
| `ItemWatch` | $5 | 0 |

### Magazines — `Gear_TKA.sqf:10-358`

| Classname | Price | Min level |
| --- | --- | --- |
| `5Rnd_127x108_KSVK` | $12 | 0 |
| `6Rnd_45ACP` | $4 | 0 |
| `8Rnd_9x18_Makarov` | $2 | 0 |
| `8Rnd_9x18_MakarovSD` | $3 | 1 |
| `8Rnd_B_Saiga12_Pellets` | $5 | 0 |
| `10Rnd_762x54_SVD` | $10 | 1 |
| `10Rnd_B_765x17_Ball` | $4 | 0 |
| `10x_303` | $3 | 0 |
| `20Rnd_762x51_FNFAL` | $10 | 0 |
| `20Rnd_B_765x17_Ball` | $6 | 1 |
| `20Rnd_9x39_SP5_VSS` | $15 | 2 |
| `30Rnd_545x39_AK` | $10 | 0 |
| `30Rnd_545x39_AKSD` | $15 | 2 |
| `30Rnd_762x39_AK47` | $7 | 0 |
| `30Rnd_762x39_SA58` | $15 | 0 |
| `30Rnd_9x19_UZI` | $5 | 1 |
| `30Rnd_9x19_UZI_SD` | $10 | 2 |
| `75Rnd_545x39_RPK` | $15 | 0 |
| `100Rnd_762x54_PK` | $30 | 0 |
| `100Rnd_762x54_PK` | $25 | 0 |
| `AT13` | $600 | 3 |
| `Dragon_EP1` | $325 | 1 |
| `Igla` | $150 | 3 |
| `OG7` | $100 | 3 |
| `PG7V` | $50 | 1 |
| `PG7VR` | $125 | 3 |
| `PG7VL` | $75 | 2 |
| `Strela` | $100 | 3 |
| `HandGrenade_East` | $10 | 0 |
| `HandGrenade_Stone` | $1 | 0 |
| `SmokeShell` | $5 | 0 |
| `SmokeShellRed` | $5 | 0 |
| `SmokeShellGreen` | $5 | 0 |
| `SmokeShellBlue` | $5 | 0 |
| `SmokeShellYellow` | $5 | 0 |
| `SmokeShellOrange` | $5 | 0 |
| `SmokeShellPurple` | $5 | 0 |
| `FlareWhite_M203` | $5 | 0 |
| `FlareYellow_M203` | $5 | 0 |
| `FlareGreen_M203` | $5 | 0 |
| `FlareRed_M203` | $5 | 0 |
| `1Rnd_HE_M203` | $20 | 0 |
| `1Rnd_Smoke_M203` | $10 | 0 |
| `1Rnd_SmokeRed_M203` | $10 | 0 |
| `1Rnd_SmokeGreen_M203` | $10 | 0 |
| `1Rnd_SmokeYellow_M203` | $10 | 0 |
| `FlareWhite_GP25` | $5 | 0 |
| `FlareYellow_GP25` | $5 | 0 |
| `FlareGreen_GP25` | $5 | 0 |
| `FlareRed_GP25` | $5 | 0 |
| `1Rnd_HE_M203` | $20 | 0 |
| `1Rnd_HE_GP25` | $15 | 0 |
| `1Rnd_SMOKE_GP25` | $5 | 0 |
| `1Rnd_SMOKERED_GP25` | $5 | 0 |
| `1Rnd_SMOKEGREEN_GP25` | $5 | 0 |
| `1Rnd_SMOKEYELLOW_GP25` | $5 | 0 |
| `MineE` | $40 | 1 |
| `PipeBomb` | $50 | 1 |

### Backpacks and deployable bags — `Gear_TKA.sqf:685-823`

| Classname | Price | Min level |
| --- | --- | --- |
| `TK_Assault_Pack_EP1` | $40 | 0 |
| `TK_RPG_Backpack_EP1` | $30 | 0 |
| `TK_ALICE_Pack_EP1` | $50 | 0 |
| `TK_ALICE_Pack_AmmoMG_EP1` | $50 | 0 |
| `TK_ALICE_Pack_Explosives_EP1` | $50 | 1 |
| `TKA_ALICE_Pack_Ammo_EP1` | $50 | 0 |
| `TKG_ALICE_Pack_AmmoAK47_EP1` | $50 | 0 |
| `TKG_ALICE_Pack_AmmoAK74_EP1` | $50 | 0 |
| `TK_Assault_Pack_EP1` | $60 | 0 |
| `TK_Assault_Pack_RPK_EP1` | $60 | 0 |
| `TKA_Assault_Pack_Ammo_EP1` | $60 | 0 |
| `Tripod_Bag` | $15 | 1 |
| `KORD_TK_Bag_EP1` | $250 | 2 |
| `DSHkM_Mini_TriPod_TK_GUE_Bag_EP1` | $250 | 1 |
| `KORD_high_TK_Bag_EP1` | $325 | 2 |
| `DSHKM_TK_GUE_Bag_EP1` | $325 | 1 |
| `AGS_TK_Bag_EP1` | $600 | 2 |
| `AGS_TK_GUE_Bag_EP1` | $600 | 2 |
| `SPG9_TK_INS_Bag_EP1` | $450 | 3 |
| `SPG9_TK_GUE_Bag_EP1` | $450 | 3 |
| `Metis_TK_Bag_EP1` | $650 | 4 |
| `2b14_82mm_TK_Bag_EP1` | $800 | 2 |
| `2b14_82mm_TK_GUE_Bag_EP1` | $800 | 2 |

## BAF (`Gear_BAF.sqf`)

### Weapons and items — `Gear_BAF.sqf:80-185`

| Classname | Price | Min level |
| --- | --- | --- |
| `BAF_AS50_scoped` | $380 | 5 |
| `BAF_AS50_TWS` | $580 | 5 |
| `BAF_LRR_scoped` | $290 | 4 |
| `BAF_LRR_scoped_W` | $270 | 4 |
| `BAF_L85A2_RIS_Holo` | $200 | 2 |
| `BAF_L85A2_UGL_Holo` | $215 | 2 |
| `BAF_L85A2_RIS_SUSAT` | $230 | 3 |
| `BAF_L85A2_UGL_SUSAT` | $245 | 3 |
| `BAF_L85A2_RIS_ACOG` | $250 | 2 |
| `BAF_L85A2_UGL_ACOG` | $260 | 3 |
| `BAF_L85A2_RIS_CWS` | $385 | 5 |
| `BAF_L86A2_ACOG` | $270 | 2 |
| `BAF_L110A1_Aim` | $270 | 3 |
| `BAF_L7A2_GPMG` | $240 | 2 |
| `BAF_NLAW_Launcher` | $350 | 2 |

### Magazines — `Gear_BAF.sqf:10-70`

| Classname | Price | Min level |
| --- | --- | --- |
| `5Rnd_127x99_AS50` | $20 | 3 |
| `5Rnd_86x70_L115A1` | $15 | 2 |
| `30Rnd_556x45_Stanag` | $15 | 0 |
| `30Rnd_556x45_StanagSD` | $20 | 0 |
| `200Rnd_556x45_L110A1` | $50 | 1 |
| `BAF_L109A1_HE` | $10 | 0 |
| `BAF_ied_v1` | $10 | 0 |
| `BAF_ied_v2` | $25 | 1 |
| `BAF_ied_v3` | $40 | 2 |
| `BAF_ied_v4` | $50 | 2 |

### Backpacks and deployable bags — `Gear_BAF.sqf:194-278`

| Classname | Price | Min level |
| --- | --- | --- |
| `BAF_AssaultPack_ARAmmo` | $70 | 0 |
| `BAF_AssaultPack_ATAmmo` | $70 | 0 |
| `BAF_AssaultPack_FAC` | $70 | 0 |
| `BAF_AssaultPack_HAAAmmo` | $70 | 0 |
| `BAF_AssaultPack_HATAmmo` | $70 | 0 |
| `BAF_AssaultPack_LRRAmmo` | $70 | 0 |
| `BAF_AssaultPack_MGAmmo` | $70 | 0 |
| `BAF_AssaultPack_RifleAmmo` | $70 | 0 |
| `BAF_AssaultPack_special` | $70 | 0 |
| `Tripod_Bag` | $15 | 0 |
| `BAF_L2A1_ACOG_minitripod_bag` | $270 | 1 |
| `BAF_L2A1_ACOG_tripod_bag` | $350 | 0 |
| `BAF_GPMG_Minitripod_D_bag` | $300 | 1 |
| `BAF_GMG_ACOG_minitripod_bag` | $300 | 1 |

## GUE (`Gear_GUE.sqf`)

### Weapons and items — `Gear_GUE.sqf:128-275`

| Classname | Price | Min level |
| --- | --- | --- |
| `AK_47_M` | $40 | 1 |
| `AK_47_S` | $50 | 1 |
| `AK_74` | $75 | 1 |
| `AK_74_GL` | $85 | 2 |
| `AKS_74_kobra` | $80 | 2 |
| `AKS_74_pso` | $95 | 2 |
| `AKS_74_U` | $80 | 1 |
| `AKS_74_UN_kobra` | $110 | 2 |
| `AKS_GOLD` | $350 | 2 |
| `huntingrifle` | $100 | 1 |
| `PK` | $150 | 2 |
| `RPK_74` | $125 | 2 |
| `SVD` | $150 | 3 |
| `RPG7V` | $90 | 1 |
| `Strela` | $225 | 3 |
| `Makarov` | $15 | 0 |
| `ItemCompass` | $5 | 0 |
| `ItemGPS` | $25 | 0 |
| `ItemMap` | $5 | 0 |
| `ItemRadio` | $10 | 0 |
| `ItemWatch` | $5 | 0 |

### Magazines — `Gear_GUE.sqf:10-118`

| Classname | Price | Min level |
| --- | --- | --- |
| `5x_22_LR_17_HMR` | $2 | 0 |
| `8Rnd_9x18_Makarov` | $2 | 0 |
| `8Rnd_9x18_MakarovSD` | $3 | 1 |
| `10Rnd_762x54_SVD` | $5 | 0 |
| `30Rnd_545x39_AK` | $10 | 0 |
| `30Rnd_545x39_AKSD` | $15 | 2 |
| `30Rnd_762x39_AK47` | $5 | 0 |
| `75Rnd_545x39_RPK` | $10 | 0 |
| `100Rnd_762x54_PK` | $15 | 0 |
| `OG7` | $100 | 3 |
| `PG7V` | $50 | 1 |
| `PG7VR` | $125 | 3 |
| `PG7VL` | $75 | 2 |
| `Strela` | $100 | 3 |
| `1Rnd_SMOKE_GP25` | $5 | 0 |
| `1Rnd_SMOKERED_GP25` | $5 | 0 |
| `1Rnd_SMOKEGREEN_GP25` | $5 | 0 |
| `1Rnd_SMOKEYELLOW_GP25` | $5 | 0 |

### Backpacks

This faction's gear file defines no backpack block.

## PMC (`Gear_PMC.sqf`)

### Weapons and items — `Gear_PMC.sqf:68-180`

| Classname | Price | Min level |
| --- | --- | --- |
| `AA12_PMC` | $225 | 2 |
| `m8_carbine` | $220 | 2 |
| `m8_carbineGL` | $235 | 3 |
| `m8_compact` | $225 | 2 |
| `m8_SAW` | $250 | 2 |
| `m8_sharpshooter` | $270 | 3 |
| `m8_carbine_pmc` | $230 | 2 |
| `m8_compact_pmc` | $235 | 2 |
| `m8_holo_sd` | $250 | 3 |
| `m8_tws` | $380 | 5 |
| `m8_tws_sd` | $350 | 5 |
| `ItemCompass` | $5 | 0 |
| `ItemGPS` | $25 | 1 |
| `ItemMap` | $5 | 0 |
| `ItemRadio` | $10 | 0 |
| `ItemWatch` | $5 | 0 |

### Magazines — `Gear_PMC.sqf:10-58`

| Classname | Price | Min level |
| --- | --- | --- |
| `20Rnd_B_AA12_Pellets` | $10 | 2 |
| `20Rnd_B_AA12_74Slug` | $10 | 2 |
| `20Rnd_B_AA12_HE` | $40 | 4 |
| `30Rnd_556x45_G36` | $15 | 0 |
| `30Rnd_556x45_G36SD` | $20 | 0 |
| `30Rnd_556x45_Stanag` | $15 | 0 |
| `30Rnd_556x45_StanagSD` | $20 | 0 |
| `100Rnd_556x45_BetaCMag` | $30 | 0 |

### Backpacks

This faction's gear file defines no backpack block.

## Continue Reading

- [Gear, Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas) — the buy-gear/EASA system that reads these files
- [Gear Store Price And Upgrade Catalog](Gear-Store-Price-And-Upgrade-Catalog) — curated high-impact subset (price `>= 300` or gear level `>= 4`)
- [Default Gear Template Content Catalog](Default-Gear-Template-Content-Catalog) — the Template-tab seed content (the buy-gear menu's other half)
- [Upgrade Research Reference](Upgrade-Research-Cross-Faction-Reference) — the `WFBE_UP_GEAR` levels the "Min level" column gates against
- [Faction Unit and Vehicle Roster Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — the units and vehicles this gear equips
- [Defense Structures Catalog](Defense-Structures-Catalog) — sibling per-faction content catalog
- [Economy, Towns And Supply](Economy-Towns-And-Supply) — the funds economy these prices draw on
