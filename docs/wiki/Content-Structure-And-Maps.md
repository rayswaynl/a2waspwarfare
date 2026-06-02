# Content Structure And Maps

## Mission Folders

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`: authoritative Chernarus source mission.
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`: vanilla Takistan generated/copy target.
- `Modded_Missions/*`: modded terrain variants.

## Terrain Support In LoadoutManager

Terrain classes include Chernarus, Takistan and modded maps such as Dingor, Eden, Lingor, SMD Sahrani, Tavi, Isla Duala and Napf. The operational generation rules, skip-list and modded-mission status table live in [Tools and build workflow](Tools-And-Build-Workflow); this page only orients the folder layout.

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

Do not treat generated mission folders as independent source truth until [Tools and build workflow](Tools-And-Build-Workflow) has been checked. [Deep-review findings](Deep-Review-Findings) DR-4 owns the Chernarus -> vanilla Takistan skip-list evidence, and DR-32 owns the full generated/modded drift analysis.

Generated-mission maintenance tiers:

| Folder | Tier | Meaning |
| --- | --- | --- |
| Chernarus source mission | Authoritative source | Gameplay edits belong here first. |
| Vanilla Takistan | Faithful generated target | Logic drift is characterized and currently limited to documented map-config/skip-list differences. |
| Napf, Eden, Lingor | Divergent forks | They need their own maintenance/audit decision before source hardening can be considered shipped there. |
| Sahrani, Dingor, Tavi, Isla Duala | Abandoned stubs | They should not be treated as playable/supportable until completed or retired. |

`version.sqf` is generated/expected, not source-owned. A fresh checkout needs LoadoutManager output or a terrain-specific generated copy before direct mission pack/test work; see [Tools and build workflow](Tools-And-Build-Workflow) and DR-43a.

## Continue Reading

Previous: [Source inventory](Source-Inventory) | Next: [WASP overlay](WASP-Overlay)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
