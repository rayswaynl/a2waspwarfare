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

