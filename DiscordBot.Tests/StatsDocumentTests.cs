using System;
using System.IO;
using Xunit;

public class StatsDocumentTests
{
    [Fact]
    public void SaveAtomic_then_Load_roundtrips_values_and_keys()
    {
        var path = Path.Combine(Path.GetTempPath(), "stats_rt_" + Guid.NewGuid().ToString("N") + ".json");
        var doc = new StatsDocument();
        doc.Players["76561198000000000"] = new PlayerStat { KillsInfantry = 3, PvpKills = 1, PlaytimeSeconds = 120, Side = 1 };
        doc.SaveAtomic(path);

        var json = File.ReadAllText(path);
        Assert.Contains("\"kills_infantry\"", json);   // contract key name, not C# name
        Assert.Contains("\"pvp_kills\"", json);

        var loaded = StatsDocument.Load(path);
        Assert.Equal(3, loaded.Players["76561198000000000"].KillsInfantry);
        Assert.Equal(1, loaded.Players["76561198000000000"].PvpKills);
        File.Delete(path);
    }

    [Fact]
    public void Load_missing_file_returns_empty_doc()
    {
        var loaded = StatsDocument.Load(Path.Combine(Path.GetTempPath(), "nope_" + Guid.NewGuid().ToString("N") + ".json"));
        Assert.NotNull(loaded);
        Assert.Empty(loaded.Players);
    }
}
