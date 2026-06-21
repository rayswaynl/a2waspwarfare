# Gear Store Loadout Route Catalog

> Provenance: 2026-06-21; source `master@0139a346`; Chernarus mission; Arma 2 OA 1.64.

This page catalogs the current Chernarus gear-store route and loadout-list coverage: side roots, visible `Loadout_*.sqf` imports, row counts, metadata extrema, and gated or dynamic content. It complements [Gear store catalog per faction](Gear-Store-Catalog-Per-Faction) for complete item rows and [Gear store price and upgrade catalog](Gear-Store-Price-And-Upgrade-Catalog) for high-impact price/gate rows; runtime defects and authority risks stay on [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas).

## Source Model

| Layer | Current Chernarus rule | Source |
| --- | --- | --- |
| Gear metadata roots | Combined Ops clients compile `Gear_US`, `Gear_TKA`, `Gear_BAF`, `Gear_GUE`, `Gear_PMC`, `Gear_RU` and `Gear_USMC`; those files define magazine, weapon and backpack price / upgrade metadata. | `Common/Init/Init_Common.sqf:234-243`; `Common/Config/readme.txt:11-26` |
| Side-visible gear pools | Loadout files provide class lists for the gear menu; magazine lists call `Config_SortMagazines`, weapon/backpack/item lists call `Config_SortWeapons`, and template lists call `Config_SetTemplates`. | `Common/Config/readme.txt:34-42` |
| Weapon buckets | `Config_SortWeapons` appends visible class names into `WFBE_%SIDE_Primary`, `WFBE_%SIDE_Pistols`, `WFBE_%SIDE_Secondary`, `WFBE_%SIDE_Equipment` and `WFBE_%SIDE_All`. | `Common/Config/Config_SortWeapons.sqf:50-57` |
| Magazine buckets | `Config_SortMagazines` appends visible magazine classes into `WFBE_%SIDE_Magazines` and returns newly added magazine classes for `WFBE_%SIDE_All`. | `Common/Config/Config_SortMagazines.sqf:24-31` |
| Price and upgrade fields | Weapon metadata stores price at index `2`, upgrade level at index `3`, bucket at index `4`, cargo size at index `5` and magazine compatibility at index `6`; magazine metadata stores price at index `2`, upgrade level at index `3`, bucket at index `4`, slot size at index `5` and class name at index `6`. | `Common/Config/Config_Weapons.sqf:34-42`; `Common/Config/Config_Magazines.sqf:23-32` |
| Template price and gate | Templates compute total price from registered weapons, magazines and backpack content, track the highest item upgrade, then store `WFBE_%SIDE_Template`. | `Common/Config/Config_SetTemplates.sqf:33-123`; `Common/Config/Config_SetTemplates.sqf:128-132` |
| Runtime filtering caveat | The counts below are source-list counts before engine class validation and thermal-imaging filtering; primary weapons with `Ti` vision mode are withheld when `WFBE_C_GAMEPLAY_THERMAL_IMAGING` is not `1` or `3`. | `Common/Config/Config_Weapons.sqf:12-14`; `Common/Config/Config_Backpack.sqf:11-29`; `Common/Config/Config_SortWeapons.sqf:19-35` |

## Chernarus Side Roots

| Side root | Default buy-menu faction | Visible loadout files | Default primary / sidearm | AI loadout tiers |
| --- | --- | --- | --- | --- |
| `Root_US_Camo.sqf` for WEST on Chernarus | `US` | `Loadout_US`, `Loadout_USMC`, `Loadout_BAF` | `SCAR_L_CQC` / `M9` | Tier variant counts are `2 / 3 / 2 / 2` for levels `0 / 1 / 2 / 3`. |
| Source | `Common/Config/Core_Root/Root_US_Camo.sqf:129-137` | `Common/Config/Core_Root/Root_US_Camo.sqf:134-137` | `Common/Config/Core_Root/Root_US_Camo.sqf:140-144` | `Common/Config/Core_Root/Root_US_Camo.sqf:91-126` |
| `Root_RU.sqf` for EAST on Chernarus | `Russians` | `Loadout_RU`; `Loadout_TKA` when `WF_A2_CombinedOps` is true | `AK_107_kobra` / `Makarov` | Tier variant counts are `2 / 3 / 2 / 2` for levels `0 / 1 / 2 / 3`. |
| Source | `Common/Config/Core_Root/Root_RU.sqf:126-135` | `Common/Config/Core_Root/Root_RU.sqf:131-135` | `Common/Config/Core_Root/Root_RU.sqf:138-143` | `Common/Config/Core_Root/Root_RU.sqf:89-123` |
| `Root_GUE.sqf` for Resistance on Chernarus | `Guerilla` | `Loadout_GUE`; `Loadout_TKGUE` when `WF_A2_CombinedOps` is true | `AKS_74_kobra` / `Makarov` | Tier variant counts are `2 / 3 / 2 / 2` for levels `0 / 1 / 2 / 3`. |
| Source | `Common/Config/Core_Root/Root_GUE.sqf:116-126` | `Common/Config/Core_Root/Root_GUE.sqf:121-126` | `Common/Config/Core_Root/Root_GUE.sqf:134-139` | `Common/Config/Core_Root/Root_GUE.sqf:79-113` |

The mission still defines selectable faction arrays for all three sides: EAST `INS/RU/TKA`, GUER `GUE/PMC/TKGUE`, and WEST `CDF/US/USMC`; Chernarus defaults those indexes to WEST `USMC`, EAST `RU`, GUER `GUE`, while the side root files above own the player gear-menu loadout imports. Source: `Common/Init/Init_CommonConstants.sqf:610-626`; `Common/Init/Init_Common.sqf:265-302`.

## Loadout File Coverage

| Loadout file | Literal magazine rows | Literal weapon / backpack / item rows | Current route |
| --- | ---: | ---: | --- |
| `Loadout_US.sqf` | `53` rows | `73` rows | WEST Chernarus imports it through `Root_US_Camo.sqf`; the tail of the visible class list includes US tripod/static bags. |
| Source | `Common/Config/Loadout/Loadout_US.sqf:6-58` | `Common/Config/Loadout/Loadout_US.sqf:63-135` | `Common/Config/Core_Root/Root_US_Camo.sqf:134-137`; `Common/Config/Loadout/Loadout_US.sqf:130-135` |
| `Loadout_USMC.sqf` | `43` rows | `50` rows | WEST Chernarus imports it through `Root_US_Camo.sqf`. |
| Source | `Common/Config/Loadout/Loadout_USMC.sqf:6-48` | `Common/Config/Loadout/Loadout_USMC.sqf:53-102` | `Common/Config/Core_Root/Root_US_Camo.sqf:134-137` |
| `Loadout_BAF.sqf` | `33` rows | `37` rows | WEST Chernarus imports it through `Root_US_Camo.sqf`; the tail includes `BAF_L2A1` and `BAF_GMG` tripod bags. |
| Source | `Common/Config/Loadout/Loadout_BAF.sqf:6-38` | `Common/Config/Loadout/Loadout_BAF.sqf:43-79` | `Common/Config/Core_Root/Root_US_Camo.sqf:134-137`; `Common/Config/Loadout/Loadout_BAF.sqf:75-79` |
| `Loadout_RU.sqf` | `49` rows | `51` rows | EAST Chernarus imports it through `Root_RU.sqf`. |
| Source | `Common/Config/Loadout/Loadout_RU.sqf:6-54` | `Common/Config/Loadout/Loadout_RU.sqf:59-109` | `Common/Config/Core_Root/Root_RU.sqf:131-135` |
| `Loadout_TKA.sqf` | `57` rows | `65` rows | EAST Chernarus imports it through `Root_RU.sqf` under the `WF_A2_CombinedOps` branch. |
| Source | `Common/Config/Loadout/Loadout_TKA.sqf:6-62` | `Common/Config/Loadout/Loadout_TKA.sqf:67-131` | `Common/Config/Core_Root/Root_RU.sqf:131-135` |
| `Loadout_GUE.sqf` | `38` rows | `29` rows | Resistance Chernarus imports it through `Root_GUE.sqf`. |
| Source | `Common/Config/Loadout/Loadout_GUE.sqf:6-43` | `Common/Config/Loadout/Loadout_GUE.sqf:48-76` | `Common/Config/Core_Root/Root_GUE.sqf:121-126` |
| `Loadout_TKGUE.sqf` | `51` rows | `54` rows | Resistance Chernarus imports it through `Root_GUE.sqf` under the `WF_A2_CombinedOps` branch; `Root_TKGUE.sqf` also imports it for Takistani Guerilla roots. |
| Source | `Common/Config/Loadout/Loadout_TKGUE.sqf:6-56` | `Common/Config/Loadout/Loadout_TKGUE.sqf:61-114` | `Common/Config/Core_Root/Root_GUE.sqf:121-126`; `Common/Config/Core_Root/Root_TKGUE.sqf:95-99` |
| `Loadout_PMC.sqf` | `63` rows | `75` rows | `Gear_PMC.sqf` metadata is compiled in Combined Ops, but `Loadout_PMC` is visible only when a PMC-capable root imports it; `Root_TKGUE.sqf` gates the extra PMC import on `WFBE_C_MODULE_BIS_PMC > 0`, and `Root_PMC.sqf` imports `Loadout_PMC` plus `Loadout_TKGUE`. |
| Source | `Common/Config/Loadout/Loadout_PMC.sqf:6-68` | `Common/Config/Loadout/Loadout_PMC.sqf:74-148` | `Common/Init/Init_Common.sqf:234-243`; `Common/Config/Core_Root/Root_TKGUE.sqf:95-99`; `Common/Config/Core_Root/Root_PMC.sqf:88-94` |
| `Loadout_CDF.sqf` | `38` rows | `29` rows | `Root_CDF.sqf` imports it when a CDF root is selected. |
| Source | `Common/Config/Loadout/Loadout_CDF.sqf:6-43` | `Common/Config/Loadout/Loadout_CDF.sqf:48-76` | `Common/Config/Core_Root/Root_CDF.sqf:98-105` |
| `Loadout_INS.sqf` | `38` rows | `29` rows | `Root_INS.sqf` imports it when an Insurgents root is selected. |
| Source | `Common/Config/Loadout/Loadout_INS.sqf:6-43` | `Common/Config/Loadout/Loadout_INS.sqf:48-76` | `Common/Config/Core_Root/Root_INS.sqf:97-104` |

## Metadata Price And Gate Extremes

| Gear metadata file | Magazines | Weapons | Backpacks / tripod bags |
| --- | --- | --- | --- |
| `Gear_US.sqf` | `56` literal rows; `Javelin` magazine is the max price and max gate at `$900`, upgrade `5`. | `55` literal rows; `m107_TWS_EP1` is the max price and max gate at `$600`, upgrade `5`. | `18` literal rows; `M252_US_Bag_EP1` is max price at `$800`, and `TOW_TriPod_US_Bag_EP1` is the highest gate at upgrade `4`. |
| Source | `Common/Config/Gear/Gear_US.sqf:10-344`; `Common/Config/Gear/Gear_US.sqf:214-218` | `Common/Config/Gear/Gear_US.sqf:356-738`; `Common/Config/Gear/Gear_US.sqf:468-472` | `Common/Config/Gear/Gear_US.sqf:750-856`; `Common/Config/Gear/Gear_US.sqf:852-856`; `Common/Config/Gear/Gear_US.sqf:846-850` |
| `Gear_USMC.sqf` | `42` literal rows; `Javelin` magazine is max price at `$900`, upgrade `5`. | `50` literal rows; `Javelin` weapon is max price at `$500`, upgrade `5`. | No literal backpack section in this file. |
| Source | `Common/Config/Gear/Gear_USMC.sqf:10-260`; `Common/Config/Gear/Gear_USMC.sqf:136-140` | `Common/Config/Gear/Gear_USMC.sqf:272-619`; `Common/Config/Gear/Gear_USMC.sqf:524-528` | `Common/Config/Gear/Gear_USMC.sqf:622` |
| `Gear_BAF.sqf` | `10` literal rows; `200Rnd_556x45_L110A1` and `BAF_ied_v4` share max price at `$50`; `5Rnd_127x99_AS50` has the highest magazine gate at upgrade `3`. | `15` literal rows; `BAF_AS50_TWS` is max price at `$580`, upgrade `5`; `BAF_L85A2_RIS_CWS` is also gate `5`. | `14` literal rows; `BAF_L2A1_ACOG_tripod_bag` is max price at `$350`; `BAF_L2A1_ACOG_minitripod_bag`, `BAF_GPMG_Minitripod_D_bag` and `BAF_GMG_ACOG_minitripod_bag` share the highest backpack gate at upgrade `1`. |
| Source | `Common/Config/Gear/Gear_BAF.sqf:10-68`; `Common/Config/Gear/Gear_BAF.sqf:34-38`; `Common/Config/Gear/Gear_BAF.sqf:64-68`; `Common/Config/Gear/Gear_BAF.sqf:10-14` | `Common/Config/Gear/Gear_BAF.sqf:80-182`; `Common/Config/Gear/Gear_BAF.sqf:87-91`; `Common/Config/Gear/Gear_BAF.sqf:150-154` | `Common/Config/Gear/Gear_BAF.sqf:194-276`; `Common/Config/Gear/Gear_BAF.sqf:260-264`; `Common/Config/Gear/Gear_BAF.sqf:254-258`; `Common/Config/Gear/Gear_BAF.sqf:266-276` |
| `Gear_RU.sqf` | `45` literal rows; `AT13` is max price at `$600`, upgrade `3`; `20Rnd_B_AA12_HE` is highest gate at upgrade `4`. | `34` literal rows; `MetisLauncher` is max price at `$500`, upgrade `5`; `VSS_vintorez` is also gate `5`. | Runtime-filtered backpack candidates: `8` candidate classes, price list `[50, 70, 60, 70, 50, 70, 70, 50]`, valid class cap `6`, all emitted with upgrade `0`. |
| Source | `Common/Config/Gear/Gear_RU.sqf:10-278`; `Common/Config/Gear/Gear_RU.sqf:94-98`; `Common/Config/Gear/Gear_RU.sqf:274-278` | `Common/Config/Gear/Gear_RU.sqf:290-525`; `Common/Config/Gear/Gear_RU.sqf:451-455`; `Common/Config/Gear/Gear_RU.sqf:437-441` | `Common/Config/Gear/Gear_RU.sqf:536-581` |
| `Gear_TKA.sqf` | `58` literal rows; `AT13` is max price at `$600`, upgrade `3`; `Strela` is also gate `3`. | `44` literal rows; `MetisLauncher` is max price at `$500`, upgrade `5`; `SVD_NSPU_EP1` is also gate `5`. | `23` literal rows; `2b14_82mm_TK_Bag_EP1` and `2b14_82mm_TK_GUE_Bag_EP1` share max price at `$800`, upgrade `2`; `Metis_TK_Bag_EP1` is highest gate at upgrade `4`. |
| Source | `Common/Config/Gear/Gear_TKA.sqf:10-356`; `Common/Config/Gear/Gear_TKA.sqf:130-134`; `Common/Config/Gear/Gear_TKA.sqf:172-176` | `Common/Config/Gear/Gear_TKA.sqf:368-673`; `Common/Config/Gear/Gear_TKA.sqf:543-547`; `Common/Config/Gear/Gear_TKA.sqf:529-533` | `Common/Config/Gear/Gear_TKA.sqf:685-821`; `Common/Config/Gear/Gear_TKA.sqf:811-821`; `Common/Config/Gear/Gear_TKA.sqf:805-809` |
| `Gear_GUE.sqf` | `18` literal rows; `PG7VR` is max price at `$125`, upgrade `3`; `Strela` is also gate `3`. | `21` literal rows; `AKS_GOLD` is max price at `$350`, upgrade `2`; `Strela` is highest gate at upgrade `3`. | No literal backpack section in this file. |
| Source | `Common/Config/Gear/Gear_GUE.sqf:10-116`; `Common/Config/Gear/Gear_GUE.sqf:76-80`; `Common/Config/Gear/Gear_GUE.sqf:88-92` | `Common/Config/Gear/Gear_GUE.sqf:128-272`; `Common/Config/Gear/Gear_GUE.sqf:184-188`; `Common/Config/Gear/Gear_GUE.sqf:226-230` | `Common/Config/Gear/Gear_GUE.sqf:275` |
| `Gear_PMC.sqf` | `8` literal rows; `20Rnd_B_AA12_HE` is max price and max gate at `$40`, upgrade `4`. | `16` literal rows; `m8_tws` is max price at `$380`, upgrade `5`; `m8_tws_sd` is also gate `5`. | No literal backpack section in this file. |
| Source | `Common/Config/Gear/Gear_PMC.sqf:10-56`; `Common/Config/Gear/Gear_PMC.sqf:22-26` | `Common/Config/Gear/Gear_PMC.sqf:68-177`; `Common/Config/Gear/Gear_PMC.sqf:131-135`; `Common/Config/Gear/Gear_PMC.sqf:138-142` | `Common/Config/Gear/Gear_PMC.sqf:180` |

## Gated And Dynamic Content

| Content | Status | Source |
| --- | --- | --- |
| Thermal-imaging weapons in visible primary pools | Config-gated: primary weapons with `Ti` in `visionMode` are omitted unless `WFBE_C_GAMEPLAY_THERMAL_IMAGING` is `1` or `3`. | `Common/Config/Config_SortWeapons.sqf:19-35` |
| RU backpacks | Dynamic/runtime-valid: `Gear_RU.sqf` has `8` candidates, keeps at most `6` valid `CfgVehicles` classes, and sends the resulting list to `Config_Backpack`. | `Common/Config/Gear/Gear_RU.sqf:536-581`; `Common/Config/Config_Backpack.sqf:11-29` |
| PMC loadout in TKGUE root | Config-gated: `Root_TKGUE.sqf` imports `Loadout_PMC.sqf` only when `WFBE_C_MODULE_BIS_PMC > 0`. | `Common/Config/Core_Root/Root_TKGUE.sqf:95-99` |
| GUER player overlay | Config-gated: `Root_GUE.sqf` and `Root_TKGUE.sqf` call `Root_GUE_PlayerOverlay.sqf` only when `WFBE_C_GUER_PLAYERSIDE > 0`; the overlay exits unless the local player is resistance, then defines role default gear and a tiered GUER depot pool. | `Common/Config/Core_Root/Root_GUE.sqf:128-130`; `Common/Config/Core_Root/Root_TKGUE.sqf:101-105`; `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:22-47`; `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:56-66` |

## Continue Reading

Previous: [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas) | Next: [Gear store catalog per faction](Gear-Store-Catalog-Per-Faction)

Main map: [Home](Home) | Price/gate rows: [Gear store price and upgrade catalog](Gear-Store-Price-And-Upgrade-Catalog) | Default templates: [Default gear template content catalog](Default-Gear-Template-Content-Catalog)
