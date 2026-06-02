# Content Structure And Maps

## Mission Folders

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`: authoritative Chernarus source mission.
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`: vanilla Takistan generated/copy target.
- `Modded_Missions/*`: modded terrain variants.

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

Do not treat differences in generated mission folders as independent source truth until LoadoutManager has been checked. Many changes should be made once in Chernarus and propagated.

`Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` is copied from Chernarus, then `SET_MAP` is patched from `1` to `2`. The generator intentionally skips map-specific or binary/terrain files such as `mission.sqm`, `version.sqf`, `GUI_Menu_Help.sqf`, `texHeaders.bin`, `StartVeh.sqf`, non-modded `loadScreen.jpg`, `Textures`, `Server/Config` and Takistan `Core_Artillery`.

`Modded_Missions/*` should be treated as stale/non-authoritative right now. Terrain classes exist, but the modded-terrain generation call is commented in `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs`. Packaging also zips only `Missions` and `Missions_Vanilla`, not `Modded_Missions`.

`version.sqf` is generated/expected, not source-owned. It is absent from a fresh checkout and is included by both `description.ext` and `initJIPCompatible.sqf`, so a mission pack/test run needs LoadoutManager output or a terrain-specific generated copy first. Also note the local Codex checkout path hazard: `Tools/LoadoutManager` currently searches for an ancestor folder literally named `a2waspwarfare`, while this workspace lives under `work\a`; see [Tools and build workflow](Tools-And-Build-Workflow).

Claude DR-32 sharpened this into three tiers:

| Folder | Tier | Meaning |
| --- | --- | --- |
| Chernarus source mission | Authoritative source | Gameplay edits belong here first. |
| Vanilla Takistan | Faithful generated target | Logic drift is characterized and currently limited to documented map-config/skip-list differences. |
| Napf, Eden, Lingor | Divergent forks | They need their own maintenance/audit decision before source hardening can be considered shipped there. |
| Sahrani, Dingor, Tavi, Isla Duala | Abandoned stubs | They should not be treated as playable/supportable until completed or retired. |

## Continue Reading

Previous: [Source inventory](Source-Inventory) | Next: [WASP overlay](WASP-Overlay)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
