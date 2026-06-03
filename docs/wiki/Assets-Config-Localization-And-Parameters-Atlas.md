# Assets, Config, Localization And Parameters Atlas

This page maps the mission-facing configuration and media layer: `description.ext`, `Rsc/*.hpp`, mission parameters, stringtable localization, sounds, music, textures and UI images. Check it before adding a mission parameter, sound, title resource, dialog image or localized string.

## Entry Graph

| Layer | Source | Runtime role |
| --- | --- | --- |
| Mission root config | `Missions/[55-2hc]warfarev2_073v48co.chernarus/description.ext:39-67` | Includes `version.sqf`, sound/music configs and all `Rsc` UI/resource config files. |
| Loading screen | `description.ext:64`, `Rsc/Titles.hpp:36` | Uses `loadScreen.jpg`; the file exists in the source mission. |
| Disabled legacy include | `description.ext:37` | `scripts\unitCaching\description.ext` is commented and the `scripts/unitCaching` folder is absent. |
| Mission parameters | `Rsc/Parameters.hpp:3`, `Common/Init/Init_Parameters.sqf:5-9` | `class Params` entries are read in order and exported into `missionNamespace` under the class name. Multiplayer uses `paramsArray`; SP uses each class `default`. |
| Common constants fallback | `Common/Init/Init_CommonConstants.sqf:93-100`, `:212-234`, `:290` | Provides fallback values if a parameter/global is missing. |
| Stringtable | `stringtable.xml` | Real `STR_WF_*` localization package used by parameters, dialogs and messages. |
| Sound registry | `Sounds/description.ext:2-159` | Defines 26 `CfgSounds` classes and 26 tracked `.ogg` files in `Sounds/`. |
| Music registry | `Music/description.ext:1-19` | Defines `wf_outro` and `cherna_intro`, backed by two tracked `.ogg` files. |
| UI resources | `Rsc/Ressources.hpp`, `Rsc/Dialogs.hpp`, `Rsc/Titles.hpp` | Shared controls, dialog classes and title resources. Current source has 18 top-level dialog classes and 99 title classes. |
| Local media folders | `Textures/`, `Client/Images/`, `Sounds/`, `Music/` | Current source has 20 local texture `.paa`, 45 client image `.paa`, 26 sound `.ogg` and 2 music `.ogg` files. |

## Parameter Contract

`Init_Parameters.sqf` is intentionally generic: it iterates `missionConfigFile >> "Params"` and sets each config class name as a mission variable. The parameter class name is the public API. Renaming a class is a gameplay compatibility change, not just UI cleanup.

| Parameter | Source | Current shape | Notes |
| --- | --- | --- | --- |
| `WFBE_C_AI_DELEGATION` | `Rsc/Parameters.hpp:50-54` | `0/1/2`, default `2` | Hosted server path can force HC mode off in `initJIPCompatible.sqf:168-169`. Runtime consumers include client FPS delegation, town AI, static defense and disconnect cleanup. |
| `WFBE_C_AI_TEAMS_ENABLED` | `Rsc/Parameters.hpp:74-78` | `0/1`, default `0` | AI teams are disabled by default in current mission parameters even though constants fallback defaults to enabled in `Init_CommonConstants.sqf:94`. |
| `WFBE_C_STRUCTURES_CONSTRUCTION_MODE` | `Rsc/Parameters.hpp:122-126` | only value `0` | UI still has sold/instant affordances for mode `1` in `GUI_Menu_Economy.sqf:149`, but the parameter only exposes timed construction. |
| `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC` | `Rsc/Parameters.hpp:210-214`, `Client/Init/Init_Client.sqf:218` | only value `0` | Comment says clouds are globally disabled for FPS/stutter; client init also forces the variable to `0`. |
| `WFBE_C_MODULE_BIS_PMC` | `Rsc/Parameters.hpp:222-227` | hidden behind `#ifndef VANILLA` | Loadout/unit roots use it for PMC content gates, for example `Common/Config/Core_Root/Root_TKGUE.sqf:99`. |
| `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` | `Rsc/Parameters.hpp:290-294` | distance list | Its `title` is the same string as bomb altitude (`$STR_WF_PARAMETER_BombAltitude`), but it drives distance restriction in `Common/Functions/Common_HandleShootBombs.sqf:21`. |

## Config Data-Model Checklist

`Common/Config/readme.txt:7-65` is still the best map of the intended data model: gear files register weapons, magazines and backpacks; group files feed town groups; loadout files build gear-menu templates; model/root files select side assets, support vehicles, AI loadouts and faction defaults. Runtime init then chooses faction roots from mission parameters and imports root, defense and group files (`Common/Init/Init_Common.sqf:263-308`).

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
| Missing local vehicle textures | `Common/Functions/Common_AddVehicleTexture.sqf:19-72`, `:215-217`; `Server/Init/Init_Server.sqf:323-325`. | Several relative `Textures/*.paa` overlays are absent, including AAV/LAV/BMP3/BTR/Tunguska/T-90 desert paths. Engine-absolute `\ca\...` paths are not flagged. |
| `loadScreen.jpg` is live and present | `description.ext:64`, `Rsc/Titles.hpp:36`; `loadScreen.jpg` exists. | Do not remove the file as "unused"; it is used by both config and title resources. |
| Commented unit caching include is stale | `description.ext:37`; no `scripts/unitCaching` folder. | Treat as abandoned scaffold, not an available optimization switch. |

## Safe Edit Rules

- Add new server/admin-facing settings as `class Params` entries only after choosing a stable `WFBE_*` variable name. `Init_Parameters.sqf:5-9` exports class names directly.
- Keep `values[]`, `texts[]` and `default` aligned. A single-value parameter is a deliberate locked switch and should be documented when left that way.
- When adding sounds, update both the `.ogg` file and `Sounds/description.ext`, then grep for `playSound`/`say` to verify the class name matches exactly.
- When adding UI images, verify every relative path exists in the source mission before propagation.
- Do not convert engine-absolute paths such as `\ca\ui\data\...` into local files unless there is a clear portability reason.
- Source mission edits must start in `Missions/[55-2hc]warfarev2_073v48co.chernarus`; generated Vanilla/Takistan changes come through LoadoutManager.
- For content/config edits, use the data-model checklist above before marking work complete. A class added in one file may still be absent from derived factory, gear-template, side-root, AI-loadout or generated-mission consumers.

## Backlog Seeds

1. Add or replace the missing `airRaid` CfgSounds class used by `NukeIncoming.sqf`, or retire the stale PVF path if support/nuke owners confirm it is dead.
2. Decide whether missing `Client\Images\wf_*.paa` tactical icons are intended absent art, stale dialog references or files lost during repo history.
3. Audit missing local vehicle texture references before changing texture behavior; many entries may be old livery leftovers.
4. Rename or retitle `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` UI text so it does not present as bomb altitude.
5. Either remove the commented unit-caching include from docs/mental model or restore the folder as a real optimization feature.

## Continue Reading

Previous: [Mission parameters, localization and generated build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) | Next: [Client UI systems atlas](Client-UI-Systems-Atlas)

Main map: [Home](Home) | Related: [Tools/build workflow](Tools-And-Build-Workflow), [Tooling release-readiness audit](Tooling-Release-Readiness-Audit), [Feature status register](Feature-Status-Register)
