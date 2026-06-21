# CIPHER Sort Utilities Reference

> Source-verified 2026-06-21 against master 0139a346. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64.

This page owns the small CIPHER utility surface: shared sort helpers plus the boot-time upgrade-label sort that feeds the Upgrade menu.

## Runtime Path

| Step | Source-backed behavior |
| --- | --- |
| Common init loads CIPHER | ICBM and IRS are parameter-gated in the same block, while CIPHER is compiled unconditionally through `CIPHER_Init.sqf`: `Common/Init/Init_Common.sqf:329-333`. |
| Upgrade labels start unsorted | `Labels_Upgrades.sqf` writes `WFBE_C_UPGRADES_LABELS` as the upgrade-label array: `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:53-79`. |
| Descriptions and images stay aligned by original upgrade id | The same file writes `WFBE_C_UPGRADES_DESCRIPTIONS` and `WFBE_C_UPGRADES_IMAGES` in the same source order as the labels: `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:81-106`; `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:108-132`. |
| The sort script is started after label/image setup | `Labels_Upgrades.sqf` executes `Common\Module\CIPHER\CIPHER_Sort.sqf` after closing the image array: `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:133`. |
| CIPHER writes a sorted index list | `CIPHER_Sort.sqf` reads a copy of `WFBE_C_UPGRADES_LABELS`, calls `CIPHER_SortArrayIndex`, then stores `_content select 1` as `WFBE_C_UPGRADES_SORTED`: `Common/Module/CIPHER/CIPHER_Sort.sqf:37-39`; `Common/Module/CIPHER/CIPHER_Init.sqf:121`. |
| The Upgrade menu uses sorted indices, not sorted labels | `GUI_UpgradeMenu.sqf` reads `WFBE_C_UPGRADES_SORTED`, iterates those ids, adds one row per enabled id, and stores the original upgrade id in the list value: `Client/GUI/GUI_UpgradeMenu.sqf:16`; `Client/GUI/GUI_UpgradeMenu.sqf:23-29`. |

## Helper Contracts

| Helper | Contract | Evidence |
| --- | --- | --- |
| `CIPHER_CompareString` | Converts both inputs with `toArray`, walks the first string, exits when one side differs or string B ends, and returns whether string A is greater. | `Common/Module/CIPHER/CIPHER_Init.sqf:8-23` |
| `CIPHER_ArraySwap` | Reads two array positions, swaps them in-place with `set`, and returns the mutated array. | `Common/Module/CIPHER/CIPHER_Init.sqf:26-39` |
| `CIPER_ArrayReverse` | Reverses an array into a new `_reversed` array; the global helper assignment in this file is spelled `CIPER_ArrayReverse`, not `CIPHER_ArrayReverse`. | `Common/Module/CIPHER/CIPHER_Init.sqf:42-55` |
| `CIPHER_SortArray` | Selection-sorts `_this select 0`, requires a reverse flag at `_this select 1`, optionally keeps a third auxiliary array aligned, and returns `[sortedList, sortedAux]`. | `Common/Module/CIPHER/CIPHER_Init.sqf:57-90` |
| `CIPHER_SortArrayIndex` | Builds an auxiliary index array, selection-sorts the copied labels, swaps the index array in parallel, and returns `[sortedList, sortedIndices]`. | `Common/Module/CIPHER/CIPHER_Init.sqf:93-121` |
| `_preformat` in `CIPHER_Sort.sqf` | Local closure that maps unit classnames through missionNamespace config records and reads `QUERYUNITLABEL` when the record exists. | `Common/Module/CIPHER/CIPHER_Sort.sqf:3-18` |
| `_preformat_gear` in `CIPHER_Sort.sqf` | Local closure that maps gear classnames through optional prefixed missionNamespace records and reads metadata index `1` when the record exists. | `Common/Module/CIPHER/CIPHER_Sort.sqf:20-35` |

## Upgrade Menu Effect

| Surface | What CIPHER changes | Evidence |
| --- | --- | --- |
| Upgrade-menu row order | The menu walks `_upgrade_sorted` instead of raw array order, so label sort order controls display order. | `Client/GUI/GUI_UpgradeMenu.sqf:16`; `Client/GUI/GUI_UpgradeMenu.sqf:23-29` |
| Upgrade id preservation | Each row stores `_x` with `lnbSetValue`, so downstream row actions still operate on the original upgrade id. | `Client/GUI/GUI_UpgradeMenu.sqf:24-26`; `Client/GUI/GUI_UpgradeMenu.sqf:183-188` |
| Label source set | The current label source contains factory, tactical, support, gear, ammo, EASA, IRS, Air AA, Anti-Air Radar, Unit Cost, CBRadar and Patrols labels. | `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:54-79` |
| Description/image lookup | The menu reads labels, descriptions and images separately, then uses the stored upgrade id for image and description lookup after selection. | `Client/GUI/GUI_UpgradeMenu.sqf:11-13`; `Client/GUI/GUI_UpgradeMenu.sqf:183-188` |

## Review Notes

| Note | Evidence |
| --- | --- |
| `CIPHER_Sort.sqf` is a boot-time data-prep script, not a compiled public function. | It is started with `ExecVM` from `Labels_Upgrades.sqf`: `Common/Config/Core_Upgrades/Labels_Upgrades.sqf:133`; its top-level active work is the upgrade sort and missionNamespace write: `Common/Module/CIPHER/CIPHER_Sort.sqf:37-39`. |
| The reverse helper's misspelled public name is internally consistent for `CIPHER_SortArray`. | The helper is declared as `CIPER_ArrayReverse`: `Common/Module/CIPHER/CIPHER_Init.sqf:43`; `CIPHER_SortArray` calls that same spelling in the reverse branch: `Common/Module/CIPHER/CIPHER_Init.sqf:85-87`. |
| Current upgrade sorting uses `CIPHER_SortArrayIndex`, not `CIPHER_SortArray`, so the reverse branch is not part of the current upgrade-menu path. | The upgrade sort call is `CIPHER_SortArrayIndex`: `Common/Module/CIPHER/CIPHER_Sort.sqf:38`; `CIPHER_SortArrayIndex` returns without a reverse branch: `Common/Module/CIPHER/CIPHER_Init.sqf:93-121`. |

## Continue Reading

Previous: [Modules atlas](Modules-Atlas) | Next: [Function and module index](Function-And-Module-Index)

Related: [Upgrades and research](Upgrades-And-Research-Atlas) | [Upgrade research reference](Upgrade-Research-Cross-Faction-Reference) | [Client UI systems atlas](Client-UI-Systems-Atlas)
