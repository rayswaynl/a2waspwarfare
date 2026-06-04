# Miksuu Wiki Archive: Chernarus Mission Script Architecture

> Imported from [`Miksuu/a2waspwarfare.wiki`](https://github.com/Miksuu/a2waspwarfare/wiki) at commit `45ef3da` (`45ef3da367d65e6487de488bbe3b16a8a8b21ba3`) on `2026-06-03`. Original file: `Project-Script-Architecture-of-Chernarus-mission.md`.
> This page preserves upstream community/developer documentation as historical provenance. It is not the current canonical source of truth for implementation details.

Current routing: [Community & Dev](Community-And-Dev) | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import)

Archive category: `architecture-history`

---

## Archive Navigation

Previous: [Miksuu Wiki Archive: LoadoutManager](Miksuu-Wiki-Archive-LoadoutManager) | Next: [Miksuu Wiki Archive: Wiki Home Stub](Miksuu-Wiki-Archive-Home)

Related: [Community & Dev](Community-And-Dev) | [Architecture overview](Architecture-Overview) | [SQF code atlas](SQF-Code-Atlas) | [Source inventory](Source-Inventory)

Welcome to the documentation page dedicated to the architecture of the script project of the Chernarus mission. This page aims to present the hierarchical structure of folders and files that make up the project. The project architecture has been designed to organize and facilitate the management of over 500 SQF files.

# Hierarchical Diagram

The hierarchical diagram below illustrates the organization of folders and files in the project.

![](https://cdn.discordapp.com/attachments/1117093090642100295/1117483001538945095/chernarus_map_files_project.png)

The PDF document provided at the link below can be useful to navigate into the diagram :

[Chernarus mission project architecture](https://cdn.discordapp.com/attachments/1117093090642100295/1117435014376849418/55warfarev2_073v48cw.chernarus_-_map_files.pdf)

# Folder Structure

Here is a brief description of the main folders in the project:

## Client
The "Client" folder contains various subfolders and files that are essential for the functioning of the client in the game that are supposed to be run by the computer of the player. Overall, the "Client" folder organizes the necessary components for the client's functionality, ranging from actions and user interface management to initialization and specialized modules. Here is an explanation of each subfolder and the associated files:

The main folder is called "Client." Inside this folder, we find several subfolders and files. Here is an explanation of each subfolder and the associated files:

1. Subfolder "**Action**":
   This subfolder contains several files with the extension ".sqf" that are used to manage various actions in the game. For example, "Action_Build.sqf" is used to construct structures, "Action_EjectCargo.sqf" is used to eject vehicle cargo, and so on.

2. Subfolder "**FSM**":
   This subfolder contains files with the extensions ".sqf" and ".fsm" that are used to update and manage the client's states in the game. For instance, "updateclient.sqf" is responsible for updating client information, while "updateactions.fsm" is used to update available actions.

3. Subfolder "**Functions**":
   This subfolder contains multiple files with the extension ".sqf" that contain specific functions utilized by the client in the game. For instance, "Client_GetPlayerFunds.sqf" retrieves player funds, and "Client_SupportRepair.sqf" provides support repairs.

4. Subfolder "**GUI**":
   This subfolder contains files with the extension ".sqf" that handle the client's user interface. For example, "GUI_Menu_BuyUnits.sqf" displays the unit purchase menu, and "GUI_RespawnMenu.sqf" shows the respawn menu.

5. Subfolder "**Images**":
   This subfolder contains files with the extension ".paa" that consist of images used in the client's user interface or other graphical elements.

6. Subfolder "**Init**":
   This subfolder contains files with the extension ".sqf" responsible for client initialization. For example, "Init_Client.sqf" handles general client initialization, and "Init_ProfileGear.sqf" initializes equipment profiles.

7. Subfolder "**Module**":
   This subfolder contains various subfolders and files defining different modules used by the client in the game. For instance, the "CM" subfolder contains files related to countermeasures, and the "EASA" subfolder contains files related to EASA equipment.

8. Subfolder "**PVFunctions**":
   This subfolder contains files with the extension ".sqf" that include specific functions used by the client for specific gameplay features. For example, "Func_Client_LowGear.sqf" manages low gear shifting.

9. Subfolder "**Sounds**":
        This subfolder contains audio files used by the client. These files can include sound effects, ambient sounds, music, and other audio assets that enhance the immersive experience of the mod.

10. Subfolder "**UI**":
        This subfolder contains files related to user interface (UI) customization and configuration. These files define the layout, behavior, and appearance of the mod's UI elements, allowing players to customize their interface preferences.

11. Subfolder "**Modules**":
        This subfolder contains files that define specific gameplay modules or features offered by the mod. These modules can include additional game mechanics, missions, or other enhancements that players can utilize in their gameplay.

12. Subfolder "**PVFunctions**":
        This subfolder contains files with the ".sqf" extension that contain specific functions used by the client for particular gameplay features. For example, "Func_Client_LowGear.sqf" is used to handle low gear shifting, "Func_Client_Radio.sqf" is used for radio functionality, etc.

13. Subfolder "**Sound**":
        This subfolder contains files with the ".ogg" extension, which are audio files used by the client in the game. For example, "Explosion1.ogg" is used for explosion sound, "RadioStatic.ogg" is used for radio static noise, etc.

14. File "**Client_Dialog.hpp**":
        This file is a definition file for the client's dialogues used in the game. It contains information about the layout, style, and content of dialogue boxes.

15. File "**Client.hpp**":
        This is a main file that defines constants, variables, and main functions used by the client in the game.

16. File "**Client_Init.sqf**":
        This file is executed during the initialization of the client in the game. It can contain instructions to load different files, initialize variables, etc.

Overall, the "Client" folder organizes the necessary components for the client's functionality, ranging from actions and user interface management to initialization and specialized modules.
## Common
Overall, the "common" folder organizes configuration files and functions related to different aspects of the system. The subfolders categorize the configuration files based on their purpose, such as core settings, artillery, models, units, upgrades, defenses, gear, groups, and loadouts. This organization allows for easy access and management of specific configuration settings for different factions and components within the system.

1. Folder: "**Config**"
        This folder contains configuration files related to various aspects of the system. It includes subfolders for different configurations.
   * Subfolder: "**Core**"
            This subfolder contains core configuration files for different factions (e.g., CDF, GUE, INS, RU, USMC, etc.). Each faction has its own configuration file.
   * Subfolder: "**Core_Artillery**"
            This subfolder contains artillery configuration files for different factions, specifying their artillery capabilities.
   * Subfolder: "**Core_Models**"
            This subfolder contains model configuration files for different game models, such as "Arrowhead," "CombinedOps," etc.
   * Subfolder: "**Core_Root**"
            This subfolder contains root configuration files for different factions, defining their root settings.
   * Subfolder: "**Core_Squads**"
            This subfolder contains squad configuration files for different factions, defining their squad settings.
   * Subfolder: "**Core_Structures**"
            This subfolder contains structure configuration files for different factions, specifying their structure settings.
   * Subfolder: "**Core_Units**"
            This subfolder contains unit configuration files for different factions, defining their unit settings.
   * Subfolder: "**Core_Upgrades**"
            This subfolder contains upgrade configuration files for different factions, specifying their upgrade options.
   * Subfolder: "**Defenses**"
            This subfolder contains defense configuration files for different factions, defining their defense settings.
   * Subfolder: "**Gear**"
            This subfolder contains gear configuration files for different factions, specifying their gear options.
   * Subfolder: "**Groups**"
            This subfolder contains group configuration files for different factions, defining their group settings.
   * Subfolder: "**Loadout**"
            This subfolder contains loadout configuration files for different factions, specifying their loadout options.
   * Other configuration files: "Config_Backpack.sqf," "Config_Defenses_Towns.sqf," "Config_Groups.sqf," "Config_Magazines.sqf," "Config_SetTemplates.sqf," "Config_SortMagazines.sqf," "Config_SortWeapons.sqf," and "Config_Weapons.sqf."
        Additionally, there is a "readme.txt" file providing information or instructions related to the configuration files.

2. Folder: "**Functions**"

   This folder contains various functions that can be used by the system. Each function is defined in a separate file. The SQF files included in the "functions" folder are organized to group together different reusable functions that are common to the mission. These functions may cover various aspects such as vehicle manipulation, unit creation and placement, objective management, client-server communication, event handling, and more.
By using these function files, mission creators can save time and effort by reusing predefined functionalities instead of having to recreate them from scratch. This enhances the efficiency of mission development and ensures consistency in the implementation of different functionalities.
In summary, the "functions" folder in the context of an ArmA 2: Operation Arrowhead mission creation project contains SQF files that group reusable functions, aiming to facilitate mission development and provide common and practical features for an enhanced gameplay experience.

3. Folder: "**Init**"

   The "Init" folder contains SQF files that handle the initialization and configuration of various aspects of the mission. These files may include initializing airports, defining boundaries for the game area, common configuration, defining constant variables, and more. Generally, the "Init" folder is used to prepare and set up the foundational elements of the mission before its execution.

4. Folder: "**Module**"

   The "Module" folder contains several sub-folders and files that serve specific purposes in the mission:

    * The "**Arty**" sub-folder appears to be dedicated to artillery functionalities, with files such as "ARTY_HandleILLUM.sqf" and "ARTY_HandleSADARM.sqf" handling illuminations and SADARM projectiles, respectively. The files "ARTY_mobileMissionFinish.sqf" and "ARTY_mobileMissionPrep.sqf" seem to be related to mobile artillery missions.

    * The "**CIPHER**" sub-folder includes files like "CIPHER_Init.sqf" and "CIPHER_Sort.sqf" that handle encryption initialization and sorting.

    * The "**IRS**" sub-folder contains files like "IRS_CreateSmoke.sqf" and "IRS_DeploySmoke.sqf" for smoke creation and deployment. The files "IRS_HandleMissile.sqf," "IRS_Init.sqf," and "IRS_OnIncomingMissile.sqf" are involved in managing incoming missiles and initializing the IRS system.

    * The "**Reaktiv**" sub-folder consists of files "Reaktiv_Init.sqf" and "Reaktiv_OnHandleDamage.sqf" for initializing and managing reactions to damage.

## Headless
The "Headless" folder consists of two sub-folders:

1. "**Functions**" sub-folder:
   - "HC_IsHeadlessClient.sqf" file: This file contains functions or logic related to determining whether a client is a headless client. It likely provides functionality specific to headless client operations.

2. "**Init**" sub-folder:
   - "Init_HC.sqf" file: This file is responsible for the initialization of the headless client. It likely contains code or configurations required to set up the headless client.

In summary, the "Headless" folder plays an important role in managing the headless client functionality. It includes the necessary functions in the "Functions" sub-folder, such as "HC_IsHeadlessClient.sqf," and the initialization process in the "Init" sub-folder, specifically the "Init_HC.sqf" file.
## Rsc
The "Rsc" folder is crucial for handling the user interface and resources in the project. It contains files that define dialogs, project headers, character identities, parameters, external resources, styles, and titles, contributing to the overall functionality and visual presentation of the project.

## Server
The "Server" folder plays a critical role in managing server-related functionalities in the project. It includes sub-folders and files responsible for handling AI behavior, configurations, construction, cleanup, functions, initialization, modules, player-voted functions, and support operations.
It consists of several sub-folders and files that contribute to the overall server operations. Here's an overview of each sub-folder and its purpose:

1. "**AI**" sub-folder:
        It contains files related to AI behavior and orders. For example, "AI_MoveTo.sqf," "AI_Patrol.sqf," "AI_TownPatrol.sqf," "AI_WPAdd.sqf," and "AI_WPRemove.sqf" handle AI movement, patrols, and waypoint manipulation.

2. "**Config**" sub-folder:
        The "Config_GUE.sqf" file likely includes specific configurations for the GUE (Guerrilla) side in the project. It may contain settings or variables relevant to the GUE faction.

3. "**Construction**" sub-folder:
        This sub-folder manages construction-related operations. Files like "Construction_HQSite.sqf," "Construction_MediumSite.sqf," "Construction_SmallSite.sqf," and "Construction_StationaryDefense.sqf" handle the creation of different types of construction sites and stationary defenses.

4. "**FSM**" sub-folder:
        The "FSM" sub-folder includes files that handle various server cleanup and restoration tasks. For example, "crater_cleaner.sqf," "droppeditems_cleaner.sqf," "mines_cleaner.sqf," and "ruins_cleaner.sqf" manage the cleanup of specific elements from the game world.

5. "**Functions**" sub-folder:
        This sub-folder contains numerous functions used by the server. Files like "Server_AI_Com_Upgrade.sqf," "Server_AssignNewCommander.sqf," "Server_HandleBuildingDamage.sqf," "Server_HandleEmptyVehicle.sqf," and many others handle different aspects of server logic and operations.

6. "**Init**" sub-folder:
        The "Init" sub-folder includes initialization files for various server components. "Init_Defenses.sqf," "Init_Server.sqf," and "Init_Towns.sqf" likely handle the initialization of defenses, server settings, and town-related functionalities, respectively.

7. "**Module**" sub-folder:
        This sub-folder likely contains additional modules or plugins for server functionality. For example, the "NEURO" sub-folder may contain a specific module called "NEURO.sqf" for advanced server features.

8. "**PVFunctions**" sub-folder:
        The "PVFunctions" sub-folder includes files responsible for handling various player-voted functions. These files, such as "RequestAutoWallConstructinChange.sqf," "RequestCommanderVote.sqf," "RequestDefense.sqf," "RequestJoin.sqf," and others, handle different player-requested actions and functionalities.

9. "**Support**" sub-folder:
        This sub-folder manages support-related operations. Files like "Support_ParaAmmo.sqf," "Support_Paratroopers.sqf," "Support_ParaVehicles.sqf," and "Support_UAV.sqf" handle support actions such as supplying ammunition, deploying paratroopers, and controlling UAVs.

## Sounds
The "Sounds" folder contains audio files that contribute to the immersive experience of the game. These files include a sound effect for bipod activation, a configuration file for sound-related settings, and an audio cue indicating an incoming threat.

## Textures
The "Textures" folder in the project contains various texture files used for visual elements in the game. These files include camouflage patterns, base textures for objects or terrain, solid colors, vehicle components, logos, and more. They are essential for enhancing the visual appeal and realism of the game by providing detailed textures for different in-game assets. The textures contribute to the overall immersive experience and help create a visually engaging environment for players.

## Wasp
The "WASP" folder in the project contains several files and subfolders that serve different purposes.

1. In the "**actions**" subfolder, there are scripts such as "Action_RepairMHQDepot.sqf," "AddActions.sqf," "car_wheel_new.sqf," "GearYouUnit.sqf," and "OnKilled.sqf." These scripts are responsible for implementing various actions within the game, including repairing the MHQ Depot, adding actions to objects, handling car wheel functionality, managing gear for the player's unit, and handling events when an entity is killed.

2. The "**baserep**" subfolder contains files like "data.sqf," "init.sqf," "repair.sqf," and "viem.sqf." These scripts are related to base repair functionality and deal with initializing data, initiating repairs, and viewing repair progress.

3. The "**common**" subfolder consists of the "procInitComm.sqf" script, which is likely responsible for initializing common procedures or functions used throughout the game.

The "**rpg_dropping**" subfolder includes the "DropRPG.sqf" script, which likely handles the dropping of rocket-propelled grenades (RPGs) in the game.

The "**unsort**" subfolder contains the "StartVeh.sqf" script, which may be responsible for starting or initializing vehicles in the game.

Overall, the "WASP" folder contains a collection of scripts and subfolders that contribute to various aspects of gameplay, including actions, repairs, common procedures, RPG dropping, vehicle initialization, and client initialization.
