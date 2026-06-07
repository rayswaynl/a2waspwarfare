using Newtonsoft.Json;

public sealed class Preferences
{
    // Singleton stuff
    private static Preferences? instance;
    private static readonly object padlock = new object();

    public ulong GuildID;
    public ulong[] AuthorizedUserIDs { get; set; } = new ulong[0];
    public ulong? GameStatusChannelID { get; set; }
    public ulong? GameStatusMessageID { get; set; }
    public string? DataSourcePath { get; set; }
    public bool a3Mode { get; set; } = false;

    // --- Player-stats ingest (RPT tail -> stats.json). No-op unless StatsEnabled. ---
    public bool StatsEnabled { get; set; } = false;
    public string? ServerRptPath { get; set; }                                  // full path to the Arma 2 OA server .rpt
    public string StatsJsonPath { get; set; } = @"C:\a2waspwarfare\Data\stats.json";
    public int StatsPollSeconds { get; set; } = 60;

    public static Preferences Instance
    {
        get
        {
            lock (padlock)
            {
                if (instance == null)
                {
                    string json = File.ReadAllText("preferences.json");
                    instance = JsonConvert.DeserializeObject<Preferences>(json);
                }
            }
#pragma warning disable CS8603 // Possible null reference return.
            return instance;
#pragma warning restore CS8603 // Possible null reference return.
        }
        set
        {
            instance = value;
        }
    }

    public static void SaveToFile()
    {
        lock (padlock)
        {
            string json = JsonConvert.SerializeObject(Instance, Formatting.Indented);
            File.WriteAllText("preferences.json", json);
        }
    }

    public bool IsUserAuthorized(ulong userId)
    {
        return AuthorizedUserIDs.Contains(userId);
    }
}
