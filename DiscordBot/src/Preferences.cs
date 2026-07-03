using Newtonsoft.Json;

public sealed class Preferences
{
    private const string PreferencesFileName = "preferences.json";

    // Singleton stuff
    private static Preferences? instance;
    private static readonly object padlock = new object();

    public ulong GuildID;
    public ulong[] AuthorizedUserIDs { get; set; } = new ulong[0];
    public ulong? GameStatusChannelID { get; set; }
    public ulong? GameStatusMessageID { get; set; }
    public string? DataSourcePath { get; set; }
    public bool a3Mode { get; set; } = false;

    public static Preferences Instance
    {
        get
        {
            if (!TryLoad(out string errorMessage))
            {
                throw new InvalidOperationException(errorMessage);
            }

            return instance ?? throw new InvalidOperationException("Preferences were not loaded.");
        }
        set
        {
            lock (padlock)
            {
                instance = value;
            }
        }
    }

    public static bool TryLoad(out string errorMessage)
    {
        lock (padlock)
        {
            if (instance != null)
            {
                errorMessage = string.Empty;
                return true;
            }

            if (!File.Exists(PreferencesFileName))
            {
                errorMessage = $"Preferences file '{PreferencesFileName}' not found in the application directory. Please create it before starting the Discord bot.";
                return false;
            }

            string json;
            try
            {
                json = File.ReadAllText(PreferencesFileName);
            }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException)
            {
                errorMessage = $"Could not read preferences file '{PreferencesFileName}': {ex.Message}";
                return false;
            }

            if (string.IsNullOrWhiteSpace(json))
            {
                errorMessage = $"Preferences file '{PreferencesFileName}' is empty. Please add a valid JSON preferences object.";
                return false;
            }

            try
            {
                Preferences? loadedPreferences = JsonConvert.DeserializeObject<Preferences>(json);

                if (loadedPreferences == null)
                {
                    errorMessage = $"Preferences file '{PreferencesFileName}' contains JSON null. Please replace it with a valid preferences object.";
                    return false;
                }

                loadedPreferences.AuthorizedUserIDs ??= Array.Empty<ulong>();
                instance = loadedPreferences;
                errorMessage = string.Empty;
                return true;
            }
            catch (JsonException ex)
            {
                errorMessage = $"Could not parse preferences file '{PreferencesFileName}': {ex.Message}";
                return false;
            }
        }
    }

    public static void SaveToFile()
    {
        lock (padlock)
        {
            string json = JsonConvert.SerializeObject(Instance, Formatting.Indented);
            File.WriteAllText(PreferencesFileName, json);
        }
    }

    public bool IsUserAuthorized(ulong userId)
    {
        return AuthorizedUserIDs.Contains(userId);
    }
}
