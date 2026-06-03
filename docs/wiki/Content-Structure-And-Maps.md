# Content Structure And Maps

## Mission Folders

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`: authoritative Chernarus source mission.
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`: vanilla Takistan generated/copy target.
- `Modded_Missions/*`: modded terrain variants.

## Mission Ownership Tiers

| Tier | What it means | Edit rule |
| --- | --- | --- |
| Source | Chernarus is the gameplay source of truth. | Edit here first for shared mission logic. |
| Generated vanilla | Takistan is maintained by LoadoutManager plus terrain-specific skips/patches. | Run LoadoutManager after source edits, then hand-check skip-listed files. |
| Divergent modded forks | Napf, Eden and Lingor have substantial hand drift from source. | Do not assume source fixes land here; each fork needs review or a regeneration policy. |
| Abandoned modded stubs | Sahrani, Dingor, Tavi and Isla Duala are incomplete/stub trees. | Do not treat as deployable until the owner revives or retires them. |

Use [Tools and build workflow](Tools-And-Build-Workflow) for the operational skip-list and [Deep-review findings](Deep-Review-Findings) DR-4/DR-32 for the full drift evidence.

## Terrain Support In LoadoutManager

Terrain classes include Chernarus, Takistan and modded maps such as Dingor, Eden, Lingor, SMD Sahrani, Tavi, Isla Duala and Napf. Some generator code still has a TODO to add modded maps back in one workflow path, so verify generated modded terrain output before treating it as automatic.

## Assets

Mission assets include:

- `.paa` UI/building/support icons and textures;
- `.ogg` music, warning and notification sounds;
- `.ogv` intro video;
- `loadScreen.jpg`;
- `stringtable.xml`;
- `mission.sqm`;
- `Rsc` dialog/resource headers.

## Config Layout

`Common/Config` contains the faction, core, defense, gear, group and root configuration loaded during common init. This is the primary data surface for unit availability, faction selection and side-specific content.

## Chernarus/Takistan Faction Switch

`Init_CommonConstants.sqf` sets faction defaults based on `IS_chernarus_map_dependent`: Chernarus uses USMC/RU/GUE style defaults, while Takistan uses US/TKA/TKGUE style defaults. The west side remains American on both map families.

## Generated Folder Warning

Do not treat differences in generated mission folders as independent source truth until LoadoutManager has been checked. Most shared logic changes should be made once in Chernarus and propagated, but skip-listed files are intentionally terrain-owned and modded forks/stubs are not currently maintained by the normal generation path.


## Representative Source Anchors

| Folder / tool claim | Source anchors |
| --- | --- |
| Current maintained mission roots | Filesystem check: `Missions/[55-2hc]warfarev2_073v48co.chernarus`, `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`, and seven `Modded_Missions/*` folders are present in the current worktree. |
| Takistan is generated from Chernarus | `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:68-72` updates Vanilla terrain files; `:193-202` copies Chernarus source to the Takistan destination. |
| Destination folder tiering | `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:139-148` maps modded, vanilla and main terrain states to `Modded_Missions`, `Missions_Vanilla` and `Missions`. |
| Terrain-owned skip list | `Tools/LoadoutManager/FileManagement/FileManager.cs:20-39` skips selected directories for Takistan; `:87-100` skips terrain-owned files such as `mission.sqm`, `version.sqf`, help, texture headers and load screen. |
| Modded generation is currently not automatic | `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs:127-133` writes Chernarus/Takistan and leaves modded terrain writes commented with a TODO. |
| Terrain enum includes inactive/modded names | `Tools/LoadoutManager/Data/Terrains/TerrainName.cs:3-30` lists Chernarus, Takistan, Dingor, Eden, Lingor, Sahrani, Taviana, Isla Duala and Napf. |

## Continue Reading

Previous: [Source inventory](Source-Inventory) | Next: [WASP overlay](WASP-Overlay)

Main map: [Home](Home) | Build workflow: [Tools and build workflow](Tools-And-Build-Workflow) | Drift evidence: [Deep-review findings](Deep-Review-Findings)
