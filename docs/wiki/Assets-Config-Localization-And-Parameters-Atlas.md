# Assets, Config, Localization And Parameters Atlas

This page maps the mission-facing configuration and media layer: `description.ext`, `Rsc/*.hpp`, mission parameters, stringtable localization, sounds, music, textures and UI images. Check it before adding a mission parameter, sound, title resource, dialog image or localized string.

## How To Use This Page

| Need | Start here | Then read |
| --- | --- | --- |
| Add or rename a lobby parameter | [Parameter contract](#parameter-contract) | [Mission start parameters index](Mission-Start-Parameters-Index) for the full source-order table, then [Mission parameters/localization/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) for runtime caveats. |
| Verify generated `version.sqf` or map flags | [Entry graph](#entry-graph) | [Mission config/version include graph](Mission-Config-Version-Include-Graph) and [Tools/build workflow](Tools-And-Build-Workflow). |
| Add config/content rows | [Config data-model checklist](#config-data-model-checklist) | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas), [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas) or [Upgrades and research](Upgrades-And-Research-Atlas), depending on the content family. |
| Add or prune media | [Asset and media findings](#asset-and-media-findings) | [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and [UI resource parity cleanup](UI-Resource-Parity-Cleanup) before deleting files or references. |

## Current Branch Scope

Source anchors below were rechecked on docs checkout `85679dba` on 2026-06-14 in the source Chernarus mission unless another root/ref is named. Maintained Vanilla Takistan `Rsc/Parameters.hpp` has the same SHA-256 hash as source Chernarus in this checkout; both roots expose 89 active lobby-visible parameters plus one commented upgrade-clearance class.

| Scope | Recheck result |
| --- | --- |
| Generated `version.sqf` | Current working tree has no present or tracked Chernarus/Vanilla `version.sqf`; `.gitignore:1,23` still ignores those generated paths. `HEAD` `85679dba`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f` and release `a96fdda2` also do not track those generated files. |
| Parameter branch debts | Docs `85679dba`, stable `cf2a6d6a`, Miksuu `b8389e74`, perf `0076040f` and release `a96fdda2` all keep the `WFBE_C_MODULE_WFBE_IRS` lobby name versus `WFBE_C_MODULE_WFBE_IRSMOKE` runtime consumers, and all keep the bomb-distance live path beside the commented bomb-altitude enforcement block. |
| Asset counts | Source Chernarus currently has 20 local texture `.paa`, 45 client image `.paa`, 26 sound `.ogg` and 2 music `.ogg` files. `Sounds/description.ext` defines 26 non-wrapper `CfgSounds` classes; `Rsc/Dialogs.hpp` has 18 top-level dialog classes and `Rsc/Titles.hpp` has 99 title class rows. |

## Entry Graph

| Layer | Source | Runtime role |
| --- | --- | --- |
| Mission root config | `Missions/[55-2hc]warfarev2_073v48co.chernarus/description.ext:39-67` | Includes generated `version.sqf`, sound/music configs and all `Rsc` UI/resource config files. `version.sqf` is required at pack/run time but absent from the clean tracked checkout. |
| Loading screen | `description.ext:64`, `Rsc/Titles.hpp:36` | Uses `loadScreen.jpg`; the file exists in the source mission. |
| Disabled legacy include | `description.ext:37` | `scripts\unitCaching\description.ext` is commented and the `scripts/unitCaching` folder is absent. |
| Mission parameters | `Rsc/Parameters.hpp:3`, `Common/Init/Init_Parameters.sqf:5-9` | `class Params` entries are read in order and exported into `missionNamespace` under the class name. Multiplayer uses `paramsArray`; SP uses each class `default`. |
| Common constants fallback | `Common/Init/Init_CommonConstants.sqf:93-100`, `:212-234`, `:290` | Provides fallback values if a parameter/global is missing. |
| Stringtable | `stringtable.xml` | Real `STR_WF_*` localization package used by parameters, dialogs and messages. |
| Sound registry | `Sounds/description.ext:2-159` | Defines 26 `CfgSounds` classes and 26 tracked `.ogg` files in `Sounds/`. |
| Music registry | `Music/description.ext:1-19` | Defines `wf_outro` and `cherna_intro`, backed by two tracked `.ogg` files. |
| UI resources | `Rsc/Ressources.hpp`, `Rsc/Dialogs.hpp`, `Rsc/Titles.hpp` | Shared controls, dialog classes and title resources. Docs checkout source has 18 top-level dialog classes and 99 title classes. |
| Local media folders | `Textures/`, `Client/Images/`, `Sounds/`, `Music/` | Docs checkout source has 20 local texture `.paa`, 45 client image `.paa`, 26 sound `.ogg` and 2 music `.ogg` files. |
| Asset/reference scanner | `docs/analysis/dead-code-asset-reference-scan.ps1` | Repeatable scanner for mission path references, missing bootstrap files, local assets, include targets and OA addon paths. Latest scan: 5860 path records across 9 mission roots, 21 missing bootstrap files all under `Modded_Missions`. |

## Parameter Contract

`Init_Parameters.sqf` is intentionally generic: it iterates `missionConfigFile >> "Params"` and sets each config class name as a mission variable. The parameter class name is the public API. Renaming a class is a gameplay compatibility change, not just UI cleanup.

This page keeps only the cross-layer contract. The full source-order index and per-parameter debt are canonical on [Mission start parameters index](Mission-Start-Parameters-Index) and [Mission parameters/localization/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs).

| Surface | Current source anchor | Owner / rule |
| --- | --- | --- |
| Generic import | `Common/Init/Init_Parameters.sqf:5-9` | `class Params` names become `missionNamespace` variables directly. Do not rename or reorder parameters without auditing `paramsArray` order and every runtime reader. |
| Full visible list | `Rsc/Parameters.hpp:5-555` | Use [Mission start parameters index](Mission-Start-Parameters-Index) for the 89 active lobby-visible rows and the one commented `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE` row. |
| Locked or forced switches | `Rsc/Parameters.hpp:210-214`, `Init_CommonConstants.sqf:212`, `Client/Init/Init_Client.sqf:218`; `Rsc/Parameters.hpp:351-356`, `Init_CommonConstants.sqf:225`, `initJIPCompatible.sqf:148,152` | Volumetric weather and upgrade-clearance are not ordinary host-selectable behavior. Keep detailed wording on the parameter-flow page. |
| Name drift | `Rsc/Parameters.hpp:393-397`, `Init_CommonConstants.sqf:238`, `Init_Common.sqf:320`, `Upgrades_CO_US.sqf:24-25` | Lobby `WFBE_C_MODULE_WFBE_IRS` and runtime `WFBE_C_MODULE_WFBE_IRSMOKE` remain split in every checked ref named above. Patch or document the alias deliberately; do not assume the generic importer normalizes names. |
| Ordnance caveat | `Rsc/Parameters.hpp:284-294`, `Common/Functions/Common_HandleShootBombs.sqf:21,32-44` | Distance restriction is live; altitude enforcement is commented. Keep UI/title and behavior decisions on [Mission parameters/localization/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs). |

## Config Data-Model Checklist

`Common/Config/readme.txt:7-65` is still the best map of the intended data model: gear files register weapons, magazines and backpacks; group files feed town groups; loadout files build gear-menu templates; model/root files select side assets, support vehicles, AI loadouts and faction defaults. Runtime init then chooses faction roots from mission parameters and imports root, defense and group files (`Common/Init/Init_Common.sqf:263-308`).

The config layer is mostly positional data. Many families are not keyed objects; they are parallel arrays that must stay aligned with shared index constants or sibling arrays. The high-risk families are:

| Family | Why it is brittle |
| --- | --- |
| `class Params` / `paramsArray` | Lobby parameter order is the runtime API; `Init_Parameters.sqf:5-9` exports by class name after reading `paramsArray` in config order. |
| `WFBE_C_UPGRADES_<side>_*` | Enabled, cost, max-level, link, time and AI-order arrays must stay aligned to the `WFBE_UP_*` constants from `Init_CommonConstants.sqf`. |
| `WFBE_%SIDE%_ARTILLERY_*` | Artillery UI, ammunition choices and behavior index across the same per-artillery slots. |
| `WFBE_%SIDE%STRUCTURES*` | Structure names, classnames, descriptions, costs, times, distances, directions and scripts are positional siblings. `WFBE_C_STRUCTURES_ANTIAIRRADAR` also conditionally adds radar entries in `Common/Config/Core_Structures/Structures_*.sqf:86`. |
| `WFBE_%SIDE%LIGHTUNITS` / `HEAVYUNITS` / `AIRCRAFTUNITS` / `AIRPORTUNITS` / `DEPOTUNITS` | Buy UI, factory queues and build-time/price derivations consume these lists directly. `WFBE_C_UNITS_TOWN_PURCHASE` and map/faction gates can change what is visible. |
| `WFBE_%SIDE%AITEAM*` | Squad templates, requirements, type labels, upgrade requirements and AI-team roles must remain in lockstep. |

There is also a post-load mutation layer. `Init_Common.sqf:325-367` derives longest build times, doubles selected unit prices under `WFBE_C_UNITS_PRICING`, multiplies structure costs when `WFBE_C_ECONOMY_CURRENCY_SYSTEM == 1`, and builds aggregate repair-truck lists. `Config_SetTemplates.sqf:33-123` is a schema builder, not just a helper: it consumes nested weapon/magazine/backpack rows and outputs `[picture, label, price, upgrade, weapons, magazines, backpack]`.

Load-order landmarks for config work:

- `initJIPCompatible.sqf:121-123` loads mission parameters and common constants, then `:214-215` starts common config and town initialization.
- `Common/Init/Init_Common.sqf:217-253` loads model/class core records such as `Core_US.sqf`, while `:222-230` loads gear registries.
- `Init_Common.sqf:290-300` loads faction root and defense files; `Server/Init/Init_Server.sqf:142` loads `Server/Init/Init_Defenses.sqf` for server-side defense templates.
- LoadoutManager-generated files are a separate layer: `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs:116-129` and `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:99-102` write EASA, balance, aircraft-name and `version.sqf` outputs.

Use this checklist before claiming a content/config edit is complete:

| Change type | Source anchors | What to verify |
| --- | --- | --- |
| New buyable unit or vehicle | Unit config records are loaded from `Common/Config/Core/Core_*.sqf` into mission variables; representative US records are stored at `Core_US.sqf:302`. `Init_Common.sqf:325-348` later scans `WFBE_%SIDE%STRUCTUREUNITS`, records `WFBE_LONGEST%STRUCTURE%BUILDTIME` and may double light/heavy/air prices under `WFBE_C_UNITS_PRICING`. | Confirm the class exists in the engine config, appears in the right factory list, has price/time/upgrade/faction fields, survives the post-load price mutation, and still appears in buy UI/factory smoke. |
| New gear, magazine or backpack | Gear helpers validate engine classes and publish missionNamespace records: weapons at `Config_Weapons.sqf:12-44`, magazines at `Config_Magazines.sqf:11-34`, backpacks at `Config_Backpack.sqf:11-65,70-82`. | Confirm `CfgWeapons`, `CfgMagazines` or `CfgVehicles` class validity, side gear visibility, price/upgrade values, backpack cargo references and RPT errors from the helper logs. |
| New gear template | Loadout files sort magazines/weapons then call templates (`Loadout_US.sqf:60,137,142`). Templates derive display picture, label, total price and required upgrade from already registered gear (`Config_SetTemplates.sqf:33-123`) and append to `WFBE_%SIDE_Template` (`:128-133`). | Do not edit a template in isolation: verify every referenced item is registered first, then smoke the gear menu price/upgrade gate and save/load behavior if profile templates are touched. |
| Side root or support asset change | Root files own ambulances, repair/supply trucks, patrols, AI loadouts, default faction and follow-on loadout/squad/artillery/unit/structure/upgrade imports; representative US anchors are `Root_US.sqf:13-17,69-117,128-137`. `Init_Common.sqf:359-366` also aggregates `WFBE_REPAIRTRUCKS` across present sides. | Smoke the live consumer, not only boot: mobile respawn for ambulances, service/repair for repair trucks, supply missions for supply trucks, AI respawn for `WFBE_%SIDE_AI_Loadout_%level`, and buy-menu default faction filtering. |
| Structure or command-center change | Structure files publish construction/HQ/factory arrays and scripts; representative CO US anchors are `Structures_CO_US.sqf:10,20,103-113`. Money-only economy multiplies structure costs in `Init_Common.sqf:350-357`. | Verify structure arrays stay index-aligned, command-center class changes still match supply delivery scans, construction-site/HQ names are valid, and money-only cost mutation is expected. Smoke build, deploy and supply-return behavior. |
| Generated mission propagation | Source edits start in Chernarus, but maintained Vanilla Takistan is copied/generated by LoadoutManager. `Tools-And-Build-Workflow` owns the skip-list and command. | Run `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj` with `A2WASP_SKIP_ZIP=1` for propagation-only checks, then inspect Takistan diffs. Hand-mirror only files in the documented skip-list. |

Minimum smoke scenario for content changes: boot hosted or dedicated with the edited faction selected, open the affected buy/gear/build UI, buy or equip one changed item, trigger one runtime consumer (AI respawn, supply, service, construction or factory queue), then run LoadoutManager propagation or record why it is not required.

## Asset And Media Findings

| Finding | Evidence | Impact |
| --- | --- | --- |
| Missing `airRaid` sound class | `Client/PVFunctions/NukeIncoming.sqf:7` plays `airRaid`, but `Sounds/description.ext` has no `class airRaid`. | Nuke incoming may fail to play its intended warning sound even though ICBM/radiation sounds are registered. Banach also found this PVF path is likely stale, so fix should follow the support/nuke owner decision. |
| Unused registered message sounds | `Sounds/description.ext:24-39`, `:96-105`; no source play/use found for `ARTY_message_to_friendly_*` or `ICBM_message_to_*`. | Likely abandoned voice/message audio or unused support/ICBM notification variants. Keep files until support-agent findings confirm removal is safe. |
| Missing local tactical menu icons | `Rsc/Dialogs.hpp:2634-2821` references `Client\Images\wf_*.paa`; none of those local files exist. | Tactical/support menu buttons may show blank/missing icons unless these paths were intended to be generated/restored. |
| Map-conditional vehicle texture leads | `Common/Functions/Common_AddVehicleTexture.sqf:8-223` contains both `IS_chernarus_map_dependent` and `!IS_chernarus_map_dependent` branches. `initJIPCompatible.sqf:111-113` turns generated `IS_CHERNARUS_MAP_DEPENDENT` into the runtime boolean; `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:346-367` writes the generated `version.sqf` macro set. | Do not treat every static missing `Textures/*.paa` hit as broken. Many are opposite-terrain branches. Verify the target terrain profile and generated `version.sqf` first, then smoke the guarded branch before adding, deleting or copying texture files. |
| `loadScreen.jpg` is live and present | `description.ext:64`, `Rsc/Titles.hpp:36`; `loadScreen.jpg` exists. | Do not remove the file as "unused"; it is used by both config and title resources. |
| Commented unit caching include is stale | `description.ext:37`; no `scripts/unitCaching` folder. | Treat as abandoned scaffold, not an available optimization switch. |

## Safe Edit Rules

- Add new server/admin-facing settings as `class Params` entries only after choosing a stable `WFBE_*` variable name. `Init_Parameters.sqf:5-9` exports class names directly.
- Keep `values[]`, `texts[]` and `default` aligned. A single-value parameter is a deliberate locked switch and should be documented when left that way.
- Verify the runtime variable name matches the `class Params` name. `Init_Parameters.sqf` exports the class name directly; a near-miss such as `WFBE_C_MODULE_WFBE_IRS` versus `WFBE_C_MODULE_WFBE_IRSMOKE` is not automatically aliased.
- Before trusting a lobby switch, grep for forced assignments after constants load. Volumetric weather is exposed in `Parameters.hpp` but forced off in both common constants and client init.
- When adding sounds, update both the `.ogg` file and `Sounds/description.ext`, then grep for `playSound`/`say` to verify the class name matches exactly.
- When adding UI images, verify every relative path exists in the source mission before propagation.
- Do not convert engine-absolute paths such as `\ca\ui\data\...` into local files unless there is a clear portability reason.
- Source mission edits must start in `Missions/[55-2hc]warfarev2_073v48co.chernarus`; generated Vanilla/Takistan changes come through LoadoutManager.
- For content/config edits, use the data-model checklist above before marking work complete. A class added in one file may still be absent from derived factory, gear-template, side-root, AI-loadout or generated-mission consumers.

## Backlog Seeds

1. Add or replace the missing `airRaid` CfgSounds class used by `NukeIncoming.sqf`, or retire the stale PVF path if support/nuke owners confirm it is dead.
2. Decide whether missing `Client\Images\wf_*.paa` tactical icons are intended absent art, stale dialog references or files lost during repo history.
3. Audit map-conditional vehicle texture references before changing texture behavior; many static missing hits are opposite-terrain branches, while real livery leftovers still need Arma smoke.
4. Rename or retitle `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` UI text so it does not present as bomb altitude.
5. Decide whether `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE` should be revived, hidden or marked historical in the host parameter UX.
6. Decide whether IR smoke should use the lobby-facing `WFBE_C_MODULE_WFBE_IRS` name, the runtime `WFBE_C_MODULE_WFBE_IRSMOKE` name, or an explicit alias during parameter import.
7. Either remove `WFBE_C_MODULE_BIS_HC` from the visible parameter set or wire/document a live consumer separate from headless-client `WFBE_C_AI_DELEGATION`.
8. Either remove the commented unit-caching include from docs/mental model or restore the folder as a real optimization feature.

## Continue Reading

Previous: [Mission parameters, localization and generated build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) | Next: [Client UI systems atlas](Client-UI-Systems-Atlas)

Main map: [Home](Home) | Related: [Mission config/version include graph](Mission-Config-Version-Include-Graph), [Tools/build workflow](Tools-And-Build-Workflow), [Tooling release-readiness audit](Tooling-Release-Readiness-Audit), [Feature status register](Feature-Status-Register)
