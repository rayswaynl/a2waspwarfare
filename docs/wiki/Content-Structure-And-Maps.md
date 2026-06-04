# Content Structure And Maps

## Mission Folders

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`: authoritative Chernarus source mission.
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`: vanilla Takistan generated/copy target.
- Branch-only `origin/feature/zargabad-map`: adds `Missions_Vanilla/[31-2hc]warfarev2_073v48co.zargabad` as a low-pop Vanilla map candidate, but it is not stable-master content.
- `Modded_Missions/*`: modded terrain variants.

Source anchors: LoadoutManager chooses target roots in `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:139-145`, copies Chernarus to Takistan at `:194-201`, copies modded terrain sources at `:205-212`, and computes modded source roots at `:246-256`.

## Terrain Support In LoadoutManager

Terrain classes include Chernarus, Takistan and modded maps such as Dingor, Eden, Lingor, SMD Sahrani, Tavi, Isla Duala and Napf. The operational generation rules, skip-list and modded-mission status table live in [Tools and build workflow](Tools-And-Build-Workflow); this page only orients the folder layout.

Source anchors: terrain implementations live under `Tools/LoadoutManager/Data/Terrains/Implementations/`; generated `version.sqf` is written by `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:102`, with helper comments at `:168-183`.

Branch-only Zargabad note: `origin/feature/zargabad-map` head `1fdcb37a` adds `DiscordBot/src/ExtensionData/GameData/SharedWithLoadoutManager/Terrains/Implementations/VanillaMaps/ZARGABAD.cs`, `Tools/LoadoutManager/Data/Terrains/Implementations/VanillaMaps/ZARGABAD.cs:1-13`, source hooks at `initJIPCompatible.sqf:121-124` and Zargabad-specific runtime setup under `Server/Init/Init_Zargabad.sqf:1-125`. Treat that branch as a full terrain release candidate; use [Zargabad branch audit](Zargabad-Branch-Audit), [Current source status snapshot](Current-Source-Status-Snapshot#2026-06-04-feature-branch-matrix) and the [branch-only feature smoke pack](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) before calling Zargabad playable or maintained.

## Assets

Mission assets include:

- `.paa` UI/building/support icons and textures;
- `.ogg` music, warning and notification sounds;
- `.ogv` intro video;
- `loadScreen.jpg`;
- `stringtable.xml`;
- `mission.sqm`;
- `Rsc` dialog/resource headers.

Source anchors: `description.ext:39-58` includes `version.sqf`, Sounds, Music and Rsc headers; `description.ext:64-67` points at `loadScreen.jpg` and mission-level channel/AI settings.

## Config Layout

`Common/Config` contains the faction, core, defense, gear, group and root configuration loaded during common init. This is the primary data surface for unit availability, faction selection and side-specific content.

Source anchors: `Common/Init/Init_Common.sqf:217-253` loads model/gear/core files, `:290-300` loads root and defense config, `:305-307` loads group config, and `:323` initializes the CIPHER module.

## Chernarus/Takistan Faction Switch

`Init_CommonConstants.sqf` sets faction defaults based on `IS_chernarus_map_dependent`: Chernarus uses USMC/RU/GUE style defaults, while Takistan uses US/TKA/TKGUE style defaults. The west side remains American on both map families.

Source anchors: `initJIPCompatible.sqf:111-113` sets `IS_chernarus_map_dependent`; `Common/Init/Init_CommonConstants.sqf:383-395` lists west/east/guer faction arrays and sets Chernarus versus Takistan defaults.

## Generated Folder Warning

Do not treat generated mission folders as independent source truth until [Tools and build workflow](Tools-And-Build-Workflow) has been checked. [Deep-review findings](Deep-Review-Findings) DR-4 owns the Chernarus -> vanilla Takistan skip-list evidence, and DR-32 owns the full generated/modded drift analysis.

Generated-mission maintenance tiers:

| Folder | Tier | Meaning |
| --- | --- | --- |
| Chernarus source mission | Authoritative source | Gameplay edits belong here first. |
| Vanilla Takistan | Faithful generated target | Logic drift is characterized and currently limited to documented map-config/skip-list differences. |
| Branch-only Zargabad | Candidate Vanilla low-pop target | `origin/feature/zargabad-map` adds terrain/tooling support and a `[31-2hc]` mission folder. Static branch validation passed locally; see [Zargabad branch audit](Zargabad-Branch-Audit). Runtime evidence, class-load checks, screenshot/RPT packet validation and generated whitespace cleanup are still required. |
| Napf, Eden, Lingor | Divergent forks with syntax-integrity hazards | They need their own maintenance/audit decision before source hardening can be considered shipped there. A 2026-06-03 scan found unresolved conflict markers in 18 modded files across Napf, Eden and Lingor, including `Napf/description.ext:43-46`, `Napf/Common/Module/IRS/IRS_OnIncomingMissile.sqf`, `Lingor/Client/Client_UpdateRHUD.sqf`, `Lingor/Common/Config/Core_Root/*` and `Eden/Client/Module/Skill/Skill_Apply.sqf`. |
| Sahrani, Dingor, Tavi, Isla Duala | Abandoned stubs | They should not be treated as playable/supportable until completed or retired. |

`version.sqf` is generated/expected, not source-owned. A fresh checkout needs LoadoutManager output or a terrain-specific generated copy before direct mission pack/test work; see [Tools and build workflow](Tools-And-Build-Workflow) and DR-43a.

### Modded Folder Completeness Snapshot

All tracked modded folders lack tracked `version.sqf`. The current generator can describe modded roots, but `SqfFileGenerator.cs:132-133` leaves modded writes commented and `ZipManager.cs:16` packages only `Missions` plus `Missions_Vanilla`. Treat Napf, Eden and Lingor as boot-incomplete from the current checkout, not merely drifted: their manifest/includes and common-init compile paths reference files that are absent.

| Folder | Missing or blocking evidence from 2026-06-03 scout |
| --- | --- |
| `eden` | Boot-incomplete: `description.ext:39-42` includes generated/sound dependencies, but tracked `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, `Sounds/description.ext` and `Music/description.ext` are absent. Conflict markers also exist in `Client/Action/Action_RepairMHQ.sqf`, skill files and `Structures_CO_RU.sqf`. `Common/Init/Init_Common.sqf:52-53,127-128` compiles `Common_GetTotalCamps.sqf`, but the tracked `Common/Functions/Common_GetTotalCamps.sqf` file is absent. |
| `lingor` | Hard boot blocker: tracked `description.ext` is absent entirely, so there is no manifest include chain. Also missing `mission.sqm`, `initJIPCompatible.sqf`, generated `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, sound/music descriptions and textures; conflict markers exist in RHUD, Nuke, Init_Unit and multiple root/artillery config files. It also compiles missing `Common/Functions/Common_GetTotalCamps.sqf` from `Common/Init/Init_Common.sqf:52-53,127-128`. |
| `Napf` | Boot-incomplete: `description.ext:39-47` includes generated/sound/music dependencies, but tracked `version.sqf`, `stringtable.xml`, `loadScreen.jpg`, `mission.sqm`, `Sounds/description.ext` and `Music/description.ext` are absent. `description.ext` and several SQF/config files contain conflict markers. It also compiles missing `Common/Functions/Common_GetTotalCamps.sqf` from `Common/Init/Init_Common.sqf:52-53,127-128`. |
| `smd_sahrani_a2` | Stub: missing mission/bootstrap/server-init/generated/sound/music/texture essentials. |
| `tavi` | Stub: missing description/bootstrap/server-init/generated/sound/music/texture essentials. |
| `dingor` | Overlay/stub: `description.ext` exists and includes generated/sound files, but `version.sqf`, `mission.sqm`, `initJIPCompatible.sqf`, server init and `Sounds` are missing. |
| `isladuala` | Stub: missing mission/description/bootstrap/server-init/generated/sound/music/texture essentials. |

## Continue Reading

Previous: [Source inventory](Source-Inventory) | Next: [WASP overlay](WASP-Overlay)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
