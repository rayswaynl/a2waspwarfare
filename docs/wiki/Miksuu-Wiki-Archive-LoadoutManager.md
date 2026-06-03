# Miksuu Wiki Archive: LoadoutManager

> Imported from [`Miksuu/a2waspwarfare.wiki`](https://github.com/Miksuu/a2waspwarfare/wiki) at commit `45ef3da` (`45ef3da367d65e6487de488bbe3b16a8a8b21ba3`) on `2026-06-03`. Original file: `LoadoutManager.md`.
> This page preserves upstream community/developer documentation as historical provenance. It is not the current canonical source of truth for implementation details.

Current routing: [Community & Dev](Community-And-Dev) | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import)

Archive category: `tool-history`

---

## Archive Navigation

Previous: [Miksuu Wiki Archive: Development Process](Miksuu-Wiki-Archive-Development-Process) | Next: [Miksuu Wiki Archive: Chernarus Mission Script Architecture](Miksuu-Wiki-Archive-Project-Script-Architecture-Of-Chernarus-Mission)

Related: [Community & Dev](Community-And-Dev) | [Tools and build workflow](Tools-And-Build-Workflow) | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) | [Source fix propagation queue](Source-Fix-Propagation-Queue)

Author: Miksuu

# Introduction
[LoadoutManager](https://github.com/Miksuu/a2waspwarfare/tree/master/Tools/LoadoutManager) is a C# program (created by Miksuu) designed for managing various vehicle loadouts. It manages generating code for Arma 2’s SQF language for the essential files:
[Common_BalanceInit.sqf](https://github.com/Miksuu/a2waspwarfare/blob/master/Missions/%5B55-2hc%5Dwarfarev2_073v48co.chernarus/Common/Functions/Common_BalanceInit.sqf) & [EASA_Init.sqf](https://github.com/Miksuu/a2waspwarfare/blob/master/Missions/%5B55-2hc%5Dwarfarev2_073v48co.chernarus/Client/Module/EASA/EASA_Init.sqf)

Additionally the program brings these changes (and any other code change excluding [mission.sqm](https://github.com/Miksuu/a2waspwarfare/blob/master/Missions/%5B55-2hc%5Dwarfarev2_073v48co.chernarus/mission.sqm), and [version.sqf](https://github.com/Miksuu/a2waspwarfare/blob/master/Missions/%5B55-2hc%5Dwarfarev2_073v48co.chernarus/version.sqf) files) to our modded terrains which we currently run during biweekly events that are held on weekends.

# Why we created this tool
Before we started working on the [The Air Balance Patch](https://github.com/Miksuu/a2waspwarfare/wiki/Changelog#v12082023-miksuu-jupiter-cleinstein-dmr), we noticed that editing the aircraft loadouts manually to the SQF code could have become a bit tedious. To alleviate this, we developed the LoadoutManager tool. Now, providing that the weapon/ammunition type/vehicle is defined into the program, editing the loadouts became multiple times faster. Later on, I made change to the program that it automatically takes data from Chernarus and Takistan and updates every terrain that is defined in the code as its own class. This way, every time the program is run, those terrains are kept up to date too. This lightens the developer's workload, as only the Forest and Desert terrains need to be edited. Later, I will create functionality to reduce that to one terrain as we could refactor the mission structure a bit.

# SqfFileGenerator.cs
[SqfFileGenerator.cs](https://github.com/Miksuu/a2waspwarfare/blob/master/Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs) is a C# utility class central to the [LoadoutManager](https://github.com/Miksuu/a2waspwarfare/tree/master/Tools/LoadoutManager) program. It specializes in generating SQF (Status Quo Script) files that are tailored to specific loadout configurations. The class serves as a vital link between the program's data models and the SQF files used in the game.
One of the key methods inside the class is GenerateAircraftSpecificLoadouts(), that invokes a method: GenerateLoadoutsForTheAircraft() from the [BaseAircraft.cs](https://github.com/Miksuu/a2waspwarfare/blob/master/Tools/LoadoutManager/Data/Vehicles/Aircrafts/BaseAircraft.cs) class. This method plays a significant role in generating aircraft-specific loadouts and leans heavily on other classes like [BaseWeapon.cs](https://github.com/Miksuu/a2waspwarfare/blob/master/Tools/LoadoutManager/Data/Weapons/BaseWeapon.cs) and [BaseAmmunition.cs](https://github.com/Miksuu/a2waspwarfare/blob/master/Tools/LoadoutManager/Data/Ammunition/BaseAmmunition.cs) to manage various types of ammunition.
The class processes this data to generate the SQF files' content, providing a seamless transition from the program's internal logic to the external SQF files. By doing so, the class ensures that the generated files are compliant with the specific loadout requirements that are setup properly to create a balanced game environment.
Beyond generating content, [SqfFileGenerator.cs](https://github.com/Miksuu/a2waspwarfare/blob/master/Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs) has methods for writing these configurations to files. This makes it easier to integrate them into different modded terrains. The class contains properties that store the text content for these SQF files, which can then be written to disk.

## File Generation Process
1. Data Retrieval: The class first collects all the necessary data, such as vehicle attributes and weapon configurations, from its internal data structures.
2. Data Processing: It then processes this data to determine the valid loadouts and other game mechanics, taking into account the factory levels and other conditions.
3. SQF Content Creation: The processed data is then used to generate the content for Common_BalanceInit.sqf and EASA_Init.sqf
4. File Writing: Finally, the generated SQF content is written to disk, updating the files with the new configurations.

# BaseVehicle.cs
The BaseVehicle.cs class is an abstract base class that encapsulates core functionalities and attributes applicable to all vehicle types in the game. It standardizes common properties like vehicle type, in-game display name, factory level, and production factory type through the implementation of the InterfaceVehicle interface. In addition, this class manages various weapon configurations and loadouts, including conditional weapon removal based on factory level.
The BaseVehicle.cs class plays a vital role in generating the Common_BalanceInit.sqf file. It holds data structures that represent the various types of vehicles and their attributes. These data structures are then processed to create the content for the SQF file, which influences the balance of the game and overall mechanics.
The class includes data structures for managing various attributes and functionalities of vehicles, such as:
- Weapon Configurations: It holds information on the various weapon types that can be equipped on each vehicle.
- Loadouts: Manages the specific combinations of weapons and equipment that can be assigned to vehicles.
- Factory Conditions: Includes logic for conditional weapon removal based on factory levels, affecting what can be produced in the game.
## Example of a class that derives from BaseVehicle.cs (PANDUR.cs)
The PANDUR.cs class is a concrete implementation that extends from the BaseGroundVehicle class. It specializes in defining the attributes and configurations specific to the Pandur vehicle in the game.
```cs
public class PANDUR : BaseGroundVehicle
{
    public PANDUR()
    {
        VehicleType = VehicleType.PANDUR;
        inGameDisplayName = "Pandur";
        base.vanillaGameDefaultLoadoutOnTurret.AmmunitionTypesWithCount = new Dictionary<AmmunitionType, int>
            {
                { AmmunitionType.ATK44HE, 2},
                { AmmunitionType.ATK44AP, 2},
            };
        base.defaultLoadoutOnTurret.AmmunitionTypesWithCount = new Dictionary<AmmunitionType, int>
            {
                { AmmunitionType.TWOHUNDREDTENROUND25MMM242APDS, 2},
                { AmmunitionType.TWOHUNDREDTENROUND25MMM242HEI, 2},
            };
        turretPos = 0;
        inGameFactoryLevel = 3;
        producedFromFactoryType = FactoryType.LIGHTFACTORY;
        weaponsOnTheTurretToRemoveUntilFactoryLevelOnAVehicle = new Dictionary<WeaponType, int>
        {
            {WeaponType.SPIKELAUNCHER, 4},
        };
    }
}
```
Here are some of the key properties set within the PANDUR.cs class:

`VehicleType`: This is set to `VehicleType.PANDUR`, specifying the type of the vehicle.
inGameDisplayName: The in-game display name for this vehicle is set to "Pandur". Right now, this is only used for displaying the comment that is generated for the SQF code.

vanillaGameDefaultLoadoutOnTurret.AmmunitionTypesWithCount: This Dictionary defines the default loadout that the game uses. Weapons that are not modified, can be left empty, since this will only affect the Common_BalanceInit.sqf (what weapons the vehicle will have on the start). The weapons to define here should be verified using the game files.

defaultLoadoutOnTurret.AmmunitionTypesWithCount: Through an algorithm, this will be compared to the vanillaGameDefaultLoadoutOnTurret to decide the final weapon loadout for the vehicle upon its spawn. In this case, we replaced the ATK44 cannon with the M242 cannon. This change was made to improve the vehicle's fire rate and increase its ammunition, thus making it more viable.

turretPos: Can be checked from the game files. Is not needed when defining ammunition to not be on the turret itself.

inGameFactoryLevel: Currently only have function for commenting purposes, in the future we might add automatic unit generation for SQF code and sorting them according to their price and factory level more properly.

weaponsOnTheTurretToRemoveUntilFactoryLevelOnAVehicle: Will be used for Common_BalanceInit.sqf to remove certain weapons on the vehicle. Define weapon name and it's level for it to be available here for the Dictionary. Multiple weapons are not supported at the moment (and probably not needed at least yet), functionality for this may be added later.

Here's an example output of that variable config:
```sqf
// Pandur [LF3]
case "Pandur2_ACR": {
    _this removeMagazineTurret ["140Rnd_30mm_ATKMK44_HE_ACR", [0]];
    _this removeMagazineTurret ["60Rnd_30mm_ATKMK44_AP_ACR", [0]];
    _this removeWeaponTurret ["ATKMK44_ACR", [0]];
    _this addMagazineTurret ["210Rnd_25mm_M242_APDS", [0]];
    _this addMagazineTurret ["210Rnd_25mm_M242_HEI", [0]];
    _this addWeaponTurret ["M242", [0]];
    _currentFactoryLevel = ((side group player) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_LIGHT;
    if (_currentFactoryLevel < 4) then {
        _this removeWeaponTurret ["SpikeLauncher_ACR", [0]];
    };
};
```

producedFromFactoryType: If you are using the weaponsOnTheTurretToRemoveUntilFactoryLevelOnAVehicle Dictionary which is documented above, this is important, asides from the usage in the comments that are generated. It defines in what factory the vehicle is produced, so the in the code, for example WFBE_UP_LIGHT or WFBE_UP_HEAVY can be defined to restrict certain weapons under a specific factory updgrade level. In the future we might add code generation features to make this unit a certain level, and add variables like pricing too (right now hardcoded in to SQF codebase configs).

# BaseAircraft.cs
In the LoadoutManager program, loadouts for aircraft are primarily generated using the BaseAircraft.cs class. This class is an abstract foundation for all types of aircraft and is derived from the BaseVehicle.cs class. It also implements the InterfaceAircraft, encapsulating common behaviors, properties, and methods that are shared across different types of aircraft.
The class also contains functionalities for calculating weapon counts and managing ammunition types among other features. It accepts various parameters, such as the type of aircraft and ammunition, to generate tailored loadouts. The method processes these inputs to produce a loadout that can then be written into an SQF file by the SqfFileGenerator.cs class.

## Example of a class that derives from BaseAircraft.cs (SU39.cs)
```cs
public class SU39 : BaseAircraft
{
    public SU39()
    {
        pylonAmount = 10;
        allowedAmmunitionTypesWithTheirLimitationAmount = new Dictionary<AmmunitionType, int>
        {
            { AmmunitionType.SIXROUNDFAB250, 0 },
            { AmmunitionType.FOURTYROUNDS8, 0 },
            { AmmunitionType.TWELVEROUNDSVIKHR, 4 }, // Vikhrs and Hellfires are automatically multiplied by two
            { AmmunitionType.BASECH29, 0 },
            { AmmunitionType.TWOROUNDGBU12, 8 },
            { AmmunitionType.TWOROUNDR73, 4 },
        };
    }
}
```
*(Note: BaseVehicle components have been omitted for brevity as they have already been provided in the chapter above)*

For EASA loadouts configuration, data in the allowedAmmunitionTypesWithTheirLimitationAmount Dictionary.
The program automatically calculates all possible loadout combinations for a given aircraft based on this data. Note that 12 Vikhrs and 8 Hellfires will always take four pylons. Additionally, some weapons can fit multiple units into a single pylon. For example, one pylon can hold 3 FAB250/MK82 bombs or 20 S8 rockets. The price of each loadout is calculated on a cost-per-pylon basis, and each magazine type has its own price. Each new weapon currently adds +1000$ to the cost (this may be changed later per weapon). List of these costs can be found at the [Implementations folder of the Data of the Ammunition folder structure](https://github.com/Miksuu/a2waspwarfare/blob/master/Tools/LoadoutManager/Data/Ammunition/Implementations/).

Here's an example how one of the loadouts,
``[14400,'FAB-250 (6) | S-8 (40) | Kh-29 (4) | R-73 (2)',[['AirBombLauncher','S8Launcher','Ch29Launcher_Su34','R73Launcher_2'],['4Rnd_FAB_250','2Rnd_FAB_250','40Rnd_S8T','4Rnd_Ch29','2Rnd_R73']]],``
is calculated:
6 FAB250s, 40 S8s, 2 R73's take two pylons each, and four Kh-29's take one each per missile. The per-pylon costs are [300, 3000, 600, 700], resulting in a total cost of 10 400. However, as mentioned before each of the new weapon types, such as AirBombLauncher for the FAB250s, adds 1000$ to the price, thus with four weapon types giving us the final price of 14400$.

Helicopters (BaseHelicopter.cs, AH1Z.cs) have modifiers of prices for missiles like the AIM-9/R-73, which makes them more expensive for that type of aircraft. If the need arises to make such missiles less accessible on helicopters, this modifier could be increased.

The complete list of all the loadouts can be found [here](https://github.com/Miksuu/a2waspwarfare/blob/master/Missions/%5B55-2hc%5Dwarfarev2_073v48co.chernarus/Client/Module/EASA/EASA_Init.sqf) (updated always when a new version of the mission is deployed to the server).

This system allows for easy modification of these values in the program to generate new loadouts. With this system, editing these values and exporting them to the game is very easy.
