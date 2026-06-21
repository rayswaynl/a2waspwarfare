# Gear Store Price And Upgrade Catalog

> Source-verified 2026-06-21 against master 0139a346. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64.

This is a focused content catalog for high-impact buy-gear rows: entries with price `>= 300` or gear upgrade level `>= 4`. It is not a full dump of every rifle magazine, grenade, flare or low-tier item.

## Runtime Meaning

| Question | Source-backed answer |
| --- | --- |
| What does the price column mean? | Gear loaders read `_o` from each gear file and store it at metadata index `2`: `Common/Config/Config_Weapons.sqf:7`; `Common/Config/Config_Weapons.sqf:36`; `Common/Config/Config_Magazines.sqf:7`; `Common/Config/Config_Magazines.sqf:26`. |
| What does the upgrade column mean? | Gear loaders read `_z` from each gear file and store it at metadata index `3`: `Common/Config/Config_Weapons.sqf:8`; `Common/Config/Config_Weapons.sqf:37`; `Common/Config/Config_Magazines.sqf:8`; `Common/Config/Config_Magazines.sqf:27`. |
| Which research slot gates the list? | The client buy-gear list reads the side upgrade array at `WFBE_UP_GEAR`: `Client/Functions/Client_UI_Gear_FillList.sqf:12`; `WFBE_UP_GEAR = 13` is defined in `Common/Init/Init_CommonConstants.sqf:50`. |
| How is a row hidden or shown? | The buy-gear list only adds a row when the stored gear upgrade value is less than or equal to the current `WFBE_UP_GEAR` level, then displays the stored price: `Client/Functions/Client_UI_Gear_FillList.sqf:21-22`. |
| Can thermal primary weapons still be hidden? | Yes. `Config_SortWeapons.sqf` reads `WFBE_C_GAMEPLAY_THERMAL_IMAGING` and suppresses primary weapons whose `visionMode` includes `Ti` when TI mode is off: `Common/Config/Config_SortWeapons.sqf:17-35`. |

## Gear Files

| Gear family | Source |
| --- | --- |
| US | `Common/Config/Gear/Gear_US.sqf:1` |
| USMC | `Common/Config/Gear/Gear_USMC.sqf:1` |
| PMC | `Common/Config/Gear/Gear_PMC.sqf:1` |
| RU | `Common/Config/Gear/Gear_RU.sqf:1` |
| TKA | `Common/Config/Gear/Gear_TKA.sqf:1` |
| BAF | `Common/Config/Gear/Gear_BAF.sqf:1` |
| GUE | `Common/Config/Gear/Gear_GUE.sqf:1` |

## High-Impact Rows

Evidence order is: source block comment, classname row, price row, upgrade row.

| Gear family | Block | Class | Price | Gear level | Evidence |
| --- | --- | --- | ---: | ---: | --- |
| BAF | Backpacks & Tripods | `BAF_L2A1_ACOG_tripod_bag` | 350 | 0 | `Common/Config/Gear/Gear_BAF.sqf:193`, `Common/Config/Gear/Gear_BAF.sqf:260`, `Common/Config/Gear/Gear_BAF.sqf:263`, `Common/Config/Gear/Gear_BAF.sqf:264` |
| BAF | Backpacks & Tripods | `BAF_GPMG_Minitripod_D_bag` | 300 | 1 | `Common/Config/Gear/Gear_BAF.sqf:193`, `Common/Config/Gear/Gear_BAF.sqf:266`, `Common/Config/Gear/Gear_BAF.sqf:269`, `Common/Config/Gear/Gear_BAF.sqf:270` |
| BAF | Backpacks & Tripods | `BAF_GMG_ACOG_minitripod_bag` | 300 | 1 | `Common/Config/Gear/Gear_BAF.sqf:193`, `Common/Config/Gear/Gear_BAF.sqf:272`, `Common/Config/Gear/Gear_BAF.sqf:275`, `Common/Config/Gear/Gear_BAF.sqf:276` |
| BAF | Weapons | `BAF_LRR_scoped_W` | 270 | 4 | `Common/Config/Gear/Gear_BAF.sqf:79`, `Common/Config/Gear/Gear_BAF.sqf:101`, `Common/Config/Gear/Gear_BAF.sqf:104`, `Common/Config/Gear/Gear_BAF.sqf:105` |
| BAF | Weapons | `BAF_L85A2_RIS_CWS` | 385 | 5 | `Common/Config/Gear/Gear_BAF.sqf:79`, `Common/Config/Gear/Gear_BAF.sqf:150`, `Common/Config/Gear/Gear_BAF.sqf:153`, `Common/Config/Gear/Gear_BAF.sqf:154` |
| BAF | Weapons | `BAF_NLAW_Launcher` | 350 | 2 | `Common/Config/Gear/Gear_BAF.sqf:79`, `Common/Config/Gear/Gear_BAF.sqf:178`, `Common/Config/Gear/Gear_BAF.sqf:181`, `Common/Config/Gear/Gear_BAF.sqf:182` |
| BAF | Weapons | `BAF_AS50_scoped` | 380 | 5 | `Common/Config/Gear/Gear_BAF.sqf:79`, `Common/Config/Gear/Gear_BAF.sqf:80`, `Common/Config/Gear/Gear_BAF.sqf:83`, `Common/Config/Gear/Gear_BAF.sqf:84` |
| BAF | Weapons | `BAF_AS50_TWS` | 580 | 5 | `Common/Config/Gear/Gear_BAF.sqf:79`, `Common/Config/Gear/Gear_BAF.sqf:87`, `Common/Config/Gear/Gear_BAF.sqf:90`, `Common/Config/Gear/Gear_BAF.sqf:91` |
| BAF | Weapons | `BAF_LRR_scoped` | 290 | 4 | `Common/Config/Gear/Gear_BAF.sqf:79`, `Common/Config/Gear/Gear_BAF.sqf:94`, `Common/Config/Gear/Gear_BAF.sqf:97`, `Common/Config/Gear/Gear_BAF.sqf:98` |
| GUE | Weapons | `AKS_GOLD` | 350 | 2 | `Common/Config/Gear/Gear_GUE.sqf:127`, `Common/Config/Gear/Gear_GUE.sqf:184`, `Common/Config/Gear/Gear_GUE.sqf:187`, `Common/Config/Gear/Gear_GUE.sqf:188` |
| PMC | Weapons | `m8_tws` | 380 | 5 | `Common/Config/Gear/Gear_PMC.sqf:67`, `Common/Config/Gear/Gear_PMC.sqf:131`, `Common/Config/Gear/Gear_PMC.sqf:134`, `Common/Config/Gear/Gear_PMC.sqf:135` |
| PMC | Weapons | `m8_tws_sd` | 350 | 5 | `Common/Config/Gear/Gear_PMC.sqf:67`, `Common/Config/Gear/Gear_PMC.sqf:138`, `Common/Config/Gear/Gear_PMC.sqf:141`, `Common/Config/Gear/Gear_PMC.sqf:142` |
| PMC | Magazines | `20Rnd_B_AA12_HE` | 40 | 4 | `Common/Config/Gear/Gear_PMC.sqf:9`, `Common/Config/Gear/Gear_PMC.sqf:22`, `Common/Config/Gear/Gear_PMC.sqf:25`, `Common/Config/Gear/Gear_PMC.sqf:26` |
| RU | Weapons | `ksvk` | 250 | 4 | `Common/Config/Gear/Gear_RU.sqf:289`, `Common/Config/Gear/Gear_RU.sqf:395`, `Common/Config/Gear/Gear_RU.sqf:398`, `Common/Config/Gear/Gear_RU.sqf:399` |
| RU | Weapons | `VSS_vintorez` | 175 | 5 | `Common/Config/Gear/Gear_RU.sqf:289`, `Common/Config/Gear/Gear_RU.sqf:437`, `Common/Config/Gear/Gear_RU.sqf:440`, `Common/Config/Gear/Gear_RU.sqf:441` |
| RU | Weapons | `MetisLauncher` | 500 | 5 | `Common/Config/Gear/Gear_RU.sqf:289`, `Common/Config/Gear/Gear_RU.sqf:451`, `Common/Config/Gear/Gear_RU.sqf:454`, `Common/Config/Gear/Gear_RU.sqf:455` |
| RU | Magazines | `20Rnd_B_AA12_HE` | 40 | 4 | `Common/Config/Gear/Gear_RU.sqf:9`, `Common/Config/Gear/Gear_RU.sqf:274`, `Common/Config/Gear/Gear_RU.sqf:277`, `Common/Config/Gear/Gear_RU.sqf:278` |
| RU | Magazines | `AT13` | 600 | 3 | `Common/Config/Gear/Gear_RU.sqf:9`, `Common/Config/Gear/Gear_RU.sqf:94`, `Common/Config/Gear/Gear_RU.sqf:97`, `Common/Config/Gear/Gear_RU.sqf:98` |
| TKA | Weapons | `AKS_74_GOSHAWK` | 180 | 5 | `Common/Config/Gear/Gear_TKA.sqf:367`, `Common/Config/Gear/Gear_TKA.sqf:410`, `Common/Config/Gear/Gear_TKA.sqf:413`, `Common/Config/Gear/Gear_TKA.sqf:414` |
| TKA | Weapons | `FN_FAL_ANPVS4` | 140 | 5 | `Common/Config/Gear/Gear_TKA.sqf:367`, `Common/Config/Gear/Gear_TKA.sqf:452`, `Common/Config/Gear/Gear_TKA.sqf:455`, `Common/Config/Gear/Gear_TKA.sqf:456` |
| TKA | Weapons | `ksvk` | 250 | 4 | `Common/Config/Gear/Gear_TKA.sqf:367`, `Common/Config/Gear/Gear_TKA.sqf:459`, `Common/Config/Gear/Gear_TKA.sqf:462`, `Common/Config/Gear/Gear_TKA.sqf:463` |
| TKA | Weapons | `SVD_NSPU_EP1` | 200 | 5 | `Common/Config/Gear/Gear_TKA.sqf:367`, `Common/Config/Gear/Gear_TKA.sqf:529`, `Common/Config/Gear/Gear_TKA.sqf:532`, `Common/Config/Gear/Gear_TKA.sqf:533` |
| TKA | Weapons | `MetisLauncher` | 500 | 5 | `Common/Config/Gear/Gear_TKA.sqf:367`, `Common/Config/Gear/Gear_TKA.sqf:543`, `Common/Config/Gear/Gear_TKA.sqf:546`, `Common/Config/Gear/Gear_TKA.sqf:547` |
| TKA | Backpacks & Tripods | `KORD_high_TK_Bag_EP1` | 325 | 2 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:769`, `Common/Config/Gear/Gear_TKA.sqf:772`, `Common/Config/Gear/Gear_TKA.sqf:773` |
| TKA | Backpacks & Tripods | `DSHKM_TK_GUE_Bag_EP1` | 325 | 1 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:775`, `Common/Config/Gear/Gear_TKA.sqf:778`, `Common/Config/Gear/Gear_TKA.sqf:779` |
| TKA | Backpacks & Tripods | `AGS_TK_Bag_EP1` | 600 | 2 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:781`, `Common/Config/Gear/Gear_TKA.sqf:784`, `Common/Config/Gear/Gear_TKA.sqf:785` |
| TKA | Backpacks & Tripods | `AGS_TK_GUE_Bag_EP1` | 600 | 2 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:787`, `Common/Config/Gear/Gear_TKA.sqf:790`, `Common/Config/Gear/Gear_TKA.sqf:791` |
| TKA | Backpacks & Tripods | `SPG9_TK_INS_Bag_EP1` | 450 | 3 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:793`, `Common/Config/Gear/Gear_TKA.sqf:796`, `Common/Config/Gear/Gear_TKA.sqf:797` |
| TKA | Backpacks & Tripods | `SPG9_TK_GUE_Bag_EP1` | 450 | 3 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:799`, `Common/Config/Gear/Gear_TKA.sqf:802`, `Common/Config/Gear/Gear_TKA.sqf:803` |
| TKA | Backpacks & Tripods | `Metis_TK_Bag_EP1` | 650 | 4 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:805`, `Common/Config/Gear/Gear_TKA.sqf:808`, `Common/Config/Gear/Gear_TKA.sqf:809` |
| TKA | Backpacks & Tripods | `2b14_82mm_TK_Bag_EP1` | 800 | 2 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:811`, `Common/Config/Gear/Gear_TKA.sqf:814`, `Common/Config/Gear/Gear_TKA.sqf:815` |
| TKA | Backpacks & Tripods | `2b14_82mm_TK_GUE_Bag_EP1` | 800 | 2 | `Common/Config/Gear/Gear_TKA.sqf:684`, `Common/Config/Gear/Gear_TKA.sqf:817`, `Common/Config/Gear/Gear_TKA.sqf:820`, `Common/Config/Gear/Gear_TKA.sqf:821` |
| TKA | Magazines | `AT13` | 600 | 3 | `Common/Config/Gear/Gear_TKA.sqf:9`, `Common/Config/Gear/Gear_TKA.sqf:130`, `Common/Config/Gear/Gear_TKA.sqf:133`, `Common/Config/Gear/Gear_TKA.sqf:134` |
| TKA | Magazines | `Dragon_EP1` | 325 | 1 | `Common/Config/Gear/Gear_TKA.sqf:9`, `Common/Config/Gear/Gear_TKA.sqf:136`, `Common/Config/Gear/Gear_TKA.sqf:139`, `Common/Config/Gear/Gear_TKA.sqf:140` |
| US | Weapons | `G36_C_SD_camo` | 300 | 3 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:370`, `Common/Config/Gear/Gear_US.sqf:373`, `Common/Config/Gear/Gear_US.sqf:374` |
| US | Weapons | `M249_TWS_EP1` | 365 | 5 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:433`, `Common/Config/Gear/Gear_US.sqf:436`, `Common/Config/Gear/Gear_US.sqf:437` |
| US | Weapons | `m107` | 400 | 4 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:461`, `Common/Config/Gear/Gear_US.sqf:464`, `Common/Config/Gear/Gear_US.sqf:465` |
| US | Weapons | `m107_TWS_EP1` | 600 | 5 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:468`, `Common/Config/Gear/Gear_US.sqf:471`, `Common/Config/Gear/Gear_US.sqf:472` |
| US | Weapons | `M110_NVG_EP1` | 350 | 4 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:517`, `Common/Config/Gear/Gear_US.sqf:520`, `Common/Config/Gear/Gear_US.sqf:521` |
| US | Weapons | `M110_TWS_EP1` | 450 | 5 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:524`, `Common/Config/Gear/Gear_US.sqf:527`, `Common/Config/Gear/Gear_US.sqf:528` |
| US | Weapons | `SCAR_L_STD_EGLM_TWS` | 330 | 5 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:566`, `Common/Config/Gear/Gear_US.sqf:569`, `Common/Config/Gear/Gear_US.sqf:570` |
| US | Weapons | `SCAR_H_STD_EGLM_Spect` | 285 | 4 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:594`, `Common/Config/Gear/Gear_US.sqf:597`, `Common/Config/Gear/Gear_US.sqf:598` |
| US | Weapons | `SCAR_H_LNG_Sniper` | 320 | 4 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:601`, `Common/Config/Gear/Gear_US.sqf:604`, `Common/Config/Gear/Gear_US.sqf:605` |
| US | Weapons | `SCAR_H_LNG_Sniper_SD` | 340 | 4 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:608`, `Common/Config/Gear/Gear_US.sqf:611`, `Common/Config/Gear/Gear_US.sqf:612` |
| US | Weapons | `SCAR_H_STD_TWS_SD` | 350 | 4 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:615`, `Common/Config/Gear/Gear_US.sqf:618`, `Common/Config/Gear/Gear_US.sqf:619` |
| US | Weapons | `Stinger` | 350 | 3 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:622`, `Common/Config/Gear/Gear_US.sqf:625`, `Common/Config/Gear/Gear_US.sqf:626` |
| US | Weapons | `Javelin` | 500 | 5 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:629`, `Common/Config/Gear/Gear_US.sqf:632`, `Common/Config/Gear/Gear_US.sqf:633` |
| US | Weapons | `Laserdesignator` | 250 | 4 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:636`, `Common/Config/Gear/Gear_US.sqf:639`, `Common/Config/Gear/Gear_US.sqf:640` |
| US | Weapons | `MAAWS` | 500 | 3 | `Common/Config/Gear/Gear_US.sqf:355`, `Common/Config/Gear/Gear_US.sqf:650`, `Common/Config/Gear/Gear_US.sqf:653`, `Common/Config/Gear/Gear_US.sqf:654` |
| US | Backpacks & Tripods | `M2StaticMG_US_Bag_EP1` | 325 | 2 | `Common/Config/Gear/Gear_US.sqf:749`, `Common/Config/Gear/Gear_US.sqf:834`, `Common/Config/Gear/Gear_US.sqf:837`, `Common/Config/Gear/Gear_US.sqf:838` |
| US | Backpacks & Tripods | `MK19_TriPod_US_Bag_EP1` | 600 | 3 | `Common/Config/Gear/Gear_US.sqf:749`, `Common/Config/Gear/Gear_US.sqf:840`, `Common/Config/Gear/Gear_US.sqf:843`, `Common/Config/Gear/Gear_US.sqf:844` |
| US | Backpacks & Tripods | `TOW_TriPod_US_Bag_EP1` | 750 | 4 | `Common/Config/Gear/Gear_US.sqf:749`, `Common/Config/Gear/Gear_US.sqf:846`, `Common/Config/Gear/Gear_US.sqf:849`, `Common/Config/Gear/Gear_US.sqf:850` |
| US | Backpacks & Tripods | `M252_US_Bag_EP1` | 800 | 1 | `Common/Config/Gear/Gear_US.sqf:749`, `Common/Config/Gear/Gear_US.sqf:852`, `Common/Config/Gear/Gear_US.sqf:855`, `Common/Config/Gear/Gear_US.sqf:856` |
| US | Magazines | `Laserbatteries` | 30 | 4 | `Common/Config/Gear/Gear_US.sqf:9`, `Common/Config/Gear/Gear_US.sqf:190`, `Common/Config/Gear/Gear_US.sqf:193`, `Common/Config/Gear/Gear_US.sqf:194` |
| US | Magazines | `MAAWS_HEAT` | 350 | 3 | `Common/Config/Gear/Gear_US.sqf:9`, `Common/Config/Gear/Gear_US.sqf:196`, `Common/Config/Gear/Gear_US.sqf:199`, `Common/Config/Gear/Gear_US.sqf:200` |
| US | Magazines | `MAAWS_HEDP` | 400 | 4 | `Common/Config/Gear/Gear_US.sqf:9`, `Common/Config/Gear/Gear_US.sqf:202`, `Common/Config/Gear/Gear_US.sqf:205`, `Common/Config/Gear/Gear_US.sqf:206` |
| US | Magazines | `Javelin` | 900 | 5 | `Common/Config/Gear/Gear_US.sqf:9`, `Common/Config/Gear/Gear_US.sqf:214`, `Common/Config/Gear/Gear_US.sqf:217`, `Common/Config/Gear/Gear_US.sqf:218` |
| USMC | Weapons | `DMR` | 300 | 3 | `Common/Config/Gear/Gear_USMC.sqf:271`, `Common/Config/Gear/Gear_USMC.sqf:272`, `Common/Config/Gear/Gear_USMC.sqf:275`, `Common/Config/Gear/Gear_USMC.sqf:276` |
| USMC | Weapons | `G36_C_SD_eotech` | 300 | 3 | `Common/Config/Gear/Gear_USMC.sqf:271`, `Common/Config/Gear/Gear_USMC.sqf:293`, `Common/Config/Gear/Gear_USMC.sqf:296`, `Common/Config/Gear/Gear_USMC.sqf:297` |
| USMC | Weapons | `m107` | 400 | 5 | `Common/Config/Gear/Gear_USMC.sqf:271`, `Common/Config/Gear/Gear_USMC.sqf:475`, `Common/Config/Gear/Gear_USMC.sqf:478`, `Common/Config/Gear/Gear_USMC.sqf:479` |
| USMC | Weapons | `Stinger` | 350 | 3 | `Common/Config/Gear/Gear_USMC.sqf:271`, `Common/Config/Gear/Gear_USMC.sqf:517`, `Common/Config/Gear/Gear_USMC.sqf:520`, `Common/Config/Gear/Gear_USMC.sqf:521` |
| USMC | Weapons | `Javelin` | 500 | 5 | `Common/Config/Gear/Gear_USMC.sqf:271`, `Common/Config/Gear/Gear_USMC.sqf:524`, `Common/Config/Gear/Gear_USMC.sqf:527`, `Common/Config/Gear/Gear_USMC.sqf:528` |
| USMC | Weapons | `Laserdesignator` | 250 | 4 | `Common/Config/Gear/Gear_USMC.sqf:271`, `Common/Config/Gear/Gear_USMC.sqf:531`, `Common/Config/Gear/Gear_USMC.sqf:534`, `Common/Config/Gear/Gear_USMC.sqf:535` |
| USMC | Weapons | `SMAW` | 400 | 4 | `Common/Config/Gear/Gear_USMC.sqf:271`, `Common/Config/Gear/Gear_USMC.sqf:545`, `Common/Config/Gear/Gear_USMC.sqf:548`, `Common/Config/Gear/Gear_USMC.sqf:549` |
| USMC | Magazines | `Laserbatteries` | 30 | 4 | `Common/Config/Gear/Gear_USMC.sqf:9`, `Common/Config/Gear/Gear_USMC.sqf:112`, `Common/Config/Gear/Gear_USMC.sqf:115`, `Common/Config/Gear/Gear_USMC.sqf:116` |
| USMC | Magazines | `SMAW_HEAA` | 300 | 4 | `Common/Config/Gear/Gear_USMC.sqf:9`, `Common/Config/Gear/Gear_USMC.sqf:118`, `Common/Config/Gear/Gear_USMC.sqf:121`, `Common/Config/Gear/Gear_USMC.sqf:122` |
| USMC | Magazines | `SMAW_HEDP` | 350 | 5 | `Common/Config/Gear/Gear_USMC.sqf:9`, `Common/Config/Gear/Gear_USMC.sqf:124`, `Common/Config/Gear/Gear_USMC.sqf:127`, `Common/Config/Gear/Gear_USMC.sqf:128` |
| USMC | Magazines | `Javelin` | 900 | 5 | `Common/Config/Gear/Gear_USMC.sqf:9`, `Common/Config/Gear/Gear_USMC.sqf:136`, `Common/Config/Gear/Gear_USMC.sqf:139`, `Common/Config/Gear/Gear_USMC.sqf:140` |

## Reading Notes

| Note | Evidence |
| --- | --- |
| Rows with price below `300` appear here only when their gear level is `4` or `5`. The table shows the exact price and gear level on each row. | Examples: `Laserbatteries` in `Common/Config/Gear/Gear_USMC.sqf:112` and `Common/Config/Gear/Gear_USMC.sqf:115-116`; `VSS_vintorez` in `Common/Config/Gear/Gear_RU.sqf:437` and `Common/Config/Gear/Gear_RU.sqf:440-441`; `SVD_NSPU_EP1` in `Common/Config/Gear/Gear_TKA.sqf:529` and `Common/Config/Gear/Gear_TKA.sqf:532-533`. |
| A listed row is source-configured content, not a guarantee that every side root loads that exact gear family. Root files call `Loadout_*.sqf`, and the loadout files sort selected classnames into side pools. | Root examples: `Common/Config/Core_Root/Root_US.sqf:120-125`, `Common/Config/Core_Root/Root_RU.sqf:132-134`; sort calls: `Common/Config/Loadout/Loadout_US.sqf:60`, `Common/Config/Loadout/Loadout_US.sqf:137`, `Common/Config/Loadout/Loadout_RU.sqf:56`, `Common/Config/Loadout/Loadout_RU.sqf:111`. |

## Continue Reading

Previous: [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas) | Next: [Gear store loadout route catalog](Gear-Store-Loadout-Route-Catalog)

Related: [Upgrade research reference](Upgrade-Research-Cross-Faction-Reference) | [Faction unit and vehicle roster catalog](Faction-Unit-And-Vehicle-Roster-Catalog) | [Service menu affordability guards](Service-Menu-Affordability-Guards)
