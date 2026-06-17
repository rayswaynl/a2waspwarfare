// The BaseTerrain class serves as the foundation for managing different types of terrains in the game.
// It implements the InterfaceTerrain to ensure certain properties and methods are present in derived classes.
// The class provides functionality for:
// - Determining mission paths and types based on whether the terrain is modded or not.
// - Writing specific content to terrain files.
// - Updating existing files, particularly for modded terrains.
// - Handling the source and destination directories for file operations.
// It utilizes helper methods for these operations, making it a comprehensive solution for terrain management.

public abstract class BaseTerrain : InterfaceTerrain
{
    // Properties that specifies the name/type of the terrain.
    public TerrainName TerrainName { get => terrainName; set => terrainName = value; }
    public TerrainType TerrainType { get => terrainType; set => terrainType = value; }
    private TerrainName terrainName { get; set; }
    private TerrainType terrainType { get; set; }

    public int startingDistanceInMeters { get; set; }

    // Boolean flag to check if the terrain is modded. Replaced with TerrainModStatus
    //public bool isModdedTerrain { get; set; }
    public TerrainModStatus terrainModStatus { get; set; }

    public bool isNavalTerrain { get; set; }

    // The directory the game sees, added here after refactoring the EnumMember for The Discord bot usage
    public string inGameMapName { get; set; }

    // Method that writes and updates the terrain files.
    public void WriteAndUpdateTerrainFiles(
        string _easaFileString, string _commonBalanceFileString, string _aircraftDisplayNameStrings, string _addedAircraftDamageModelChanges, string _coreModFile = "")
    {
        string destinationDirectory = DetermineDestinationDirectory();

        if (terrainName == TerrainName.CHERNARUS)
        {
            string soundDirectory = destinationDirectory + "/Sounds/";
            var soundFiles = Directory.GetFiles(soundDirectory, "*.ogg");
            List<string> soundClasses = new List<string>();

            foreach (var file in soundFiles)
            {
                var fileName = Path.GetFileNameWithoutExtension(file);
                var splitName = fileName.Split('-');
                var className = splitName[0];
                var volume = splitName[1];

                string soundClass = $@"
    class {className} {{
        name = ""{className}"";
        sound[] = {{""\Sounds\{fileName}.ogg"", {volume}, 1}};
        titles[] = {{}};
    }};";

                soundClasses.Add(soundClass);
            }

            string cfgSounds = $@"
class CfgSounds
{{
    sounds[] = {{}};
    {string.Join(Environment.NewLine, soundClasses)}
}};";

            File.WriteAllText(soundDirectory + "description.ext", cfgSounds);
        }

        // Handle writing to the vanilla maps (Utes, Zargabad) more properly here later
        if (terrainModStatus == TerrainModStatus.VANILLA)
        {
            UpdateFilesForTakistan();
            EnsureTakistanInitServerUsesCorrectMapId(destinationDirectory);
        }

        // Perhaps do a inherited class from this to reduce spaghetti
        if (terrainModStatus == TerrainModStatus.MODDED)
        {
            UpdateFilesForModdedTerrains();

            WriteFilesToTheModdedTerrains(destinationDirectory, _coreModFile);
            ReplaceInitCommmonSqfForCoreModInit(destinationDirectory);
        }

        FileManager.InsertGeneratedCodeInToAFile(
            _addedAircraftDamageModelChanges, destinationDirectory + @"\Common\Functions\Common_ModifyAirVehicle.sqf",
            "//LoadoutManagerInsertChanges", "//LoadoutManagerInsertChanges_END");

        WriteSpecificFilesToTheTerrains(destinationDirectory, _easaFileString, _commonBalanceFileString, _aircraftDisplayNameStrings, _addedAircraftDamageModelChanges);

        Console.WriteLine("-------" + terrainName + " DONE! ---------");
    }

    // Method to write specific content to terrain files based on conditions
    private void WriteSpecificFilesToTheTerrains(
        string _destinationDirection, string _easaFileString, string _commonBalanceFileString, string _aircraftDisplayNameStrings, string _addedAircraftDamageModelChanges)
    {
        // Write the content to the specified files
        // Maybe could use a bit more better data structure, maybe if needed, use the new replace content method instead of writing the whole file
        WriteToFile(_destinationDirection, _easaFileString, @"\Client\Module\EASA\EASA_Init.sqf");

        // Inject Ka-137 GUER EASA block into the marker slot left by GenerateEndOfTheEasaFile().
        // This is post-write so it survives regen: markers are regenerated, then this re-fills them.
        // Only inject for vanilla (non-modded) terrains; modded maps don't carry GUER playerside.
        if (terrainModStatus == TerrainModStatus.VANILLA || terrainModStatus == TerrainModStatus.MAIN)
        {
            FileManager.InsertGeneratedCodeInToAFile(
                FileManager.GenerateGuerEasaKa137Block(),
                _destinationDirection + @"\Client\Module\EASA\EASA_Init.sqf",
                "//LoadoutManagerGuerEasaInsert",
                "//LoadoutManagerGuerEasaInsert_END");
        }

        WriteToFile(_destinationDirection, _commonBalanceFileString, @"\Common\Functions\Common_BalanceInit.sqf");
        WriteToFile(_destinationDirection, _aircraftDisplayNameStrings, @"\Common\Common_ReturnAircraftNameFromItsType.sqf");
        WriteToFile(_destinationDirection, GenerateAndWriteVersionSqf(), @"\version.sqf");

        ReplaceGUIMenuHelp(_destinationDirection);
    }

    private void WriteFilesToTheModdedTerrains(string _destinationDirection, string _coreModFile)
    {
        if (_coreModFile == "")
        {
            Console.WriteLine("_coreModFile was empty!!!");
            return;
        }

        WriteToFile(_destinationDirection, _coreModFile, @"\Common\Config\Core\Core_MOD.sqf");
    }

    // Method to write content to a file at a specific path
    private void WriteToFile(string _destinationDirection, string _content, string _targetScriptPath)
    {
        // Concatenate the directory and file path
        string targetFile = _destinationDirection + _targetScriptPath;

        // Make sure the directory exists
        string directoryName = Path.GetDirectoryName(targetFile);
        if (!Directory.Exists(directoryName))
        {
            // Create the directory if it doesn't exist
            Directory.CreateDirectory(directoryName);
        }

        // Write the content to the target file
        File.WriteAllText(targetFile, _content);
    }

    // Method to determine the mission path based on whether the terrain is modded or not
    private string DetermineMissionPathBasedOnModStatus()
    {
        // Return "Modded_Missions" if the terrain is modded, "Missions" if it's vanilla, and "Main_Missions" if it's main
        switch (terrainModStatus)
        {
            case TerrainModStatus.MODDED:
                return "Modded_Missions";
            case TerrainModStatus.VANILLA:
                return "Missions_Vanilla";
            case TerrainModStatus.MAIN:
                return "Missions";
            default:
                throw new Exception("Invalid terrain mod status");
        }
    }

    // Method to determine where to get the source files from
    private string DetermineMissionSourcePathForModdedTerrains()
    {
        return TerrainType == TerrainType.FOREST ? "chernarus" : "takistan";
    }

    // Method to determine the mission type based on the terrain type (Forest or Desert)
    private string DetermineMissionTypeIfItsForestOrDesert()
    {
        // Return "55" if the terrain type is FOREST, otherwise return "61"
        return TerrainType == TerrainType.FOREST ? "55" : "61";
    }

    // Method to determine the mission camo based on the terrain type (Forest or Desert)
    // Return string for commenting the camo/map definition variable for Desert maps
    // Used for generation of the version.sqf file
    private string DetermineIfTheMissionIsTakistanTypeAndReturnCommentStringIfThatIsTheCase()
    {
        return TerrainType == TerrainType.DESERT ? "//" : "";
    }

    // Method to determine if the terrain is modded
    // Returns true if the terrain is modded, false otherwise
    public bool IsTerrainModded()
    {
        return terrainModStatus == TerrainModStatus.MODDED;
    }

    // Method for determine if the terrain is not modded and return a comment string if that is not the case
    // Used for generation of the version.sqf file
    private string DetermineIfTheTerrainIsNotModdedAndReturnCommentStringIfThatIsTheCase()
    {
        return terrainModStatus != TerrainModStatus.MODDED ? "//" : "";
    }

    private string DetermineIfTheTerrainIsNavalReturnCommentStringIfThatIsTheCase()
    {
        return isNavalTerrain == false ? "//" : "";
    }

    // Method to update all the files for Takistan, and the modded maps
    private void UpdateFilesForTakistan()
    {
        // Determine the source and destination directories for file operations
        string sourceDirectory = DetermineChernarusDirectory();
        string destinationDirectory = DetermineDestinationDirectory();

        // Copy files from the source to the destination directory
        FileManager.CopyFilesFromSourceToDestination(sourceDirectory, destinationDirectory, terrainModStatus);
    }

    // Method to update all the files for the modded terrains
    private void UpdateFilesForModdedTerrains()
    {
        // Determine the source and destination directories for file operations
        string sourceDirectory = DetermineSourceDirectoryForModdedTerrains();
        string destinationDirectory = DetermineDestinationDirectory();

        // Copy files from the source to the destination directory
        FileManager.CopyFilesFromSourceToDestination(sourceDirectory, destinationDirectory, terrainModStatus);
    }

    // Replaces the gui menu help mission name according to the current Terrain name
    private void ReplaceGUIMenuHelp(string _destinationDirectory)
    {
        ReplaceContentOnASpecificFile(_destinationDirectory, @"\Client\GUI\GUI_Menu_Help.sqf",
            "<t size='1.2' color='#2394ef' align='center'>Warfare WASP-AWESOME EDITION | v48 | - CO - Mission</t><br />",
            $"<t size='1.2' color='#2394ef' align='center'>Warfare WASP-AWESOME EDITION | v48 | - CO -" +
            $" {EnumExtensions.GetEnumMemberAttrValue(terrainName)}</t><br />");
    }

    // Replaces the core /* Class Core */ Call compile for the mod maps
    private void ReplaceInitCommmonSqfForCoreModInit(string _destinationDirectory)
    {
        ReplaceContentOnASpecificFile(_destinationDirectory, @"\Common\Init\Init_Common.sqf",
            "/* Class Core */",
            $"/* Class Core */\n Call Compile preprocessFileLineNumbers 'Common\\Config\\Core\\Core_MOD.sqf';");
    }

    // Method to determine the Chernarus directory, for Takistan
    private string DetermineChernarusDirectory()
    {
        // Determine the name of the source terrain based on the terrain type
        string sourceTerrainName = "chernarus";

        // Determine the player count for the mission based on the terrain type
        string sourceTerrainPlayerCount = "55";

        // Construct and return the full source directory path
        return Path.Combine(FileManager.FindA2WaspWarfareDirectory().FullName, @"Missions\[" + sourceTerrainPlayerCount + "-2hc]warfarev2_073v48co." + sourceTerrainName);
    }

    // Method to determine the source directory path based on terrain type and mission type
    private string DetermineSourceDirectoryForModdedTerrains()
    {
        // Determine the player count for the mission based on the terrain type
        string sourceTerrainPlayerCount = DetermineMissionTypeIfItsForestOrDesert();

        string sourceDirectory = DetermineMissionSourcePathForModdedTerrains();

        string pathToTakeMissionFrom = TerrainType == TerrainType.FOREST ? "Missions" : "Missions_Vanilla";

        // Construct and return the full source directory path
        return Path.Combine(FileManager.FindA2WaspWarfareDirectory().FullName, pathToTakeMissionFrom + @"\[" + sourceTerrainPlayerCount + "-2hc]warfarev2_073v48co." + sourceDirectory);
    }

    // Method to determine the destination directory based on mission type and terrain name
    private string DetermineDestinationDirectory()
    {
        DirectoryInfo projectDirectory = FileManager.FindA2WaspWarfareDirectory();

        // Determine the player count for the mission based on the terrain type
        string sourceTerrainPlayerCount = DetermineMissionTypeIfItsForestOrDesert();

        string directoryOfMissions = DetermineMissionPathBasedOnModStatus();

        // Construct and return the full destination directory path
        return Path.Combine(projectDirectory.FullName, directoryOfMissions + @"\[" + sourceTerrainPlayerCount +
            "-2hc]warfarev2_073v48co." + inGameMapName);
    }

    // Method to update a specific file's content (such as init_server on modded maps for disabling guerilla barracks)
    private static void ReplaceContentOnASpecificFile(string _destinationDirectory, string _missionFileToEdit,
        string _contentToSearchFor, string _contentToReplaceWith)
    {
        // Construct the full path of the file that needs to be updated
        string finalPathToEdit = _destinationDirectory + _missionFileToEdit;

        // Check if the file exists
        if (!File.Exists(finalPathToEdit))
        {
            // Log a message if the file was not found
            Console.WriteLine("File not found!");
        }

        // Read the content of the file
        string content = File.ReadAllText(finalPathToEdit);

        // Check if the file contains the specific string to be replaced
        if (!content.Contains(_contentToSearchFor))
        {
            // Log a message if the specific content was not found
            Console.WriteLine("The specified content was not found in the file.");
            return;
        }

        // Replace the string and update the file
        content = content.Replace(_contentToSearchFor, _contentToReplaceWith);
        File.WriteAllText(finalPathToEdit, content);
    }

    // Ensures the Takistan init_server uses the correct map id after copying from Chernarus
    private void EnsureTakistanInitServerUsesCorrectMapId(string _destinationDirectory)
    {
        if (terrainName != TerrainName.TAKISTAN)
        {
            return;
        }

        string initServerPath = Path.Combine(_destinationDirectory, @"Server\Init\Init_Server.sqf");

        if (!File.Exists(initServerPath))
        {
            Console.WriteLine($"Init_Server.sqf not found at {initServerPath}");
            return;
        }

        const string chernarusMapLine = "[\"SET_MAP\", 1] call WFBE_SE_FNC_CallDatabaseSetMap;";
        const string takistanMapLine = "[\"SET_MAP\", 2] call WFBE_SE_FNC_CallDatabaseSetMap;";

        string fileContent = File.ReadAllText(initServerPath);

        if (fileContent.Contains(takistanMapLine))
        {
            return;
        }

        if (fileContent.Contains(chernarusMapLine))
        {
            File.WriteAllText(initServerPath, fileContent.Replace(chernarusMapLine, takistanMapLine));
            return;
        }

        Console.WriteLine($"SET_MAP definition not updated for Takistan in {initServerPath}.");
    }

    // Generates and returns the SQF code for a specific terrain. This method is built upon 
    // the base functionalities defined in BaseTerrain.cs.
    // Generate the mission name by combining various parameters including the terrain name
    // Determine if the mission has camo enabled based on base terrain configurations
    // Marty - IMPORTANT : COMMENT the WF_LOG_CONTENT line if you DONT want to activate logs in rpt file. Changing only its value wont have any effect.
    // Marty - IS_CHERNARUS_MAP_DEPENDENT MUST NOT BE COMMENTED IF the map depend on chernarus content. MUST BE COMMENT IF the map depend on takistan content. 
    // Generate the version-specific SQF code using string interpolation
    public string GenerateAndWriteVersionSqf()
    {
        string wfDebug = GenerateWFDebug();
        string wfLogContent = GenerateWFLogContent();
        string terrainTypeCommentPrefix = DetermineIfTheMissionIsTakistanTypeAndReturnCommentStringIfThatIsTheCase();
        string isModMapDependant = DetermineIfTheTerrainIsNotModdedAndReturnCommentStringIfThatIsTheCase();
        string isNavalTerrain = DetermineIfTheTerrainIsNavalReturnCommentStringIfThatIsTheCase();
        string maxPlayers = DetermineMissionTypeIfItsForestOrDesert();
        string missionName = $@"[{maxPlayers}] Warfare V48 {EnumExtensions.GetEnumMemberAttrValue(terrainName)}";
        string isAirWarEvent = GenerateIsAirWarEvent();
        
        return $@"{wfDebug}
{wfLogContent}
{terrainTypeCommentPrefix}#define IS_CHERNARUS_MAP_DEPENDENT
{isModMapDependant}#define IS_MOD_MAP_DEPENDENT
{isNavalTerrain}#define IS_NAVAL_MAP
{isAirWarEvent}
#define WF_MAXPLAYERS {maxPlayers}
#define WF_MISSIONNAME ""{missionName}""
#define STARTING_DISTANCE {startingDistanceInMeters}
#define COMBINEDOPS 1
#define WF_RESPAWNDELAY 2";
    }

    private string GenerateWFDebug()
    {
#if DEBUG || AIRWAR_DEBUG
        return "#define WF_DEBUG 1";
#elif SERVER_DEBUG || AIRWAR_SERVER_DEBUG
        return "// #define WF_DEBUG 1";
#else
        return "// #define WF_DEBUG 1";
#endif
    }

    private string GenerateWFLogContent()
    {
#if DEBUG || AIRWAR_DEBUG
        return "#define WF_LOG_CONTENT";
#elif SERVER_DEBUG || AIRWAR_SERVER_DEBUG
        return "#define WF_LOG_CONTENT";
#else
        return "// #define WF_LOG_CONTENT";
#endif
    }

    private string GenerateIsAirWarEvent()
    {
#if AIRWAR_DEBUG || AIRWAR_SERVER_DEBUG || AIRWAR_RELEASE
        return "#define IS_AIR_WAR_EVENT";
#else
        return "//#define IS_AIR_WAR_EVENT";
#endif
    }
}
