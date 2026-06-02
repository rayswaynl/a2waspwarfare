using System;
using System.IO;
using System.Linq;
using Xunit;

// End-to-end test of the producer half WITHOUT a game/Discord/network: build the exact RPT line
// that Server/Stats/StatsFlush.sqf emits, run it through the real RptTailer -> StatsBatchParser ->
// StatsAccumulator -> StatsDocument, and assert the resulting stats.json matches the contract the
// website/bot consume. This is the cross-language guard for the WFBE_STAT_* <-> PlayerStat index map.
public class StatsPipelineIntegrationTests
{
    // Index order MUST match WFBE_STAT_* (SQF) and PlayerStat.AddDelta (C#):
    // 0 inf,1 veh,2 air,3 static,4 factory,5 hq,6 deaths,7 pvp,8 supplyRuns,9 supplyValue,
    // 10 capTown,11 capCamp,12 structures,13 defenses,14 playtime
    private static string WaspLine(int seq, string uid, int[] d, int side)
    {
        // Mirrors StatsFlush.sqf: "WASPSTAT|v1|<seq>|<uid>:<d0>,..,<d14>,<side>", as diag_log writes it
        // into the RPT (timestamp prefix + surrounding quotes).
        var csv = string.Join(",", d) + "," + side;
        return $"23:59:59 \"WASPSTAT|v1|{seq}|{uid}:{csv}\"";
    }

    // Replicates the receiver-side weights (web/src/app/api/stats/route.ts + bot/cogs/stats_reader.py).
    private static int Composite(PlayerStat p) =>
        p.KillsInfantry * 10 + p.KillsVehicle * 30 + p.KillsAir * 60 + p.KillsStatic * 15 +
        p.KillsFactory * 100 + p.KillsHq * 500 + p.PvpKills * 20 + p.SupplyRuns * 15 +
        p.CapturesTown * 50 + p.CapturesCamp * 25 + p.StructuresBuilt * 20 + p.DefensesBuilt * 15;

    [Fact]
    public void Two_flushes_accumulate_into_a_contract_correct_stats_json()
    {
        var dir = Path.Combine(Path.GetTempPath(), "wasp_e2e_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        var rpt = Path.Combine(dir, "ArmA2OA.RPT");
        var state = Path.Combine(dir, "stats.json.tail.state");
        var statsJson = Path.Combine(dir, "stats.json");
        const string uid = "76561198000000000";
        var d = new[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 60 };

        // Simulate a fresh session header line + the bot's accumulator seeded from any existing stats.json.
        File.WriteAllText(rpt, "Arma 2 OA dedicated server session start\n");
        var acc = new StatsAccumulator(StatsDocument.Load(statsJson));
        var tailer = new RptTailer(rpt, state);

        void Tick()
        {
            foreach (var line in tailer.ReadNewLines())
                if (StatsBatchParser.TryParseLine(line, out var batch)) acc.ApplyBatch(batch);
            if (acc.Dirty) acc.Save(statsJson);
        }

        Tick();                                                       // consumes the header, no stats yet
        File.AppendAllText(rpt, WaspLine(1, uid, d, 1) + "\n"); Tick();
        File.AppendAllText(rpt, WaspLine(2, uid, d, 2) + "\n"); Tick();

        // Reload from disk like the Python reader does, and verify the index->field mapping doubled.
        var doc = StatsDocument.Load(statsJson);
        var p = doc.Players[uid];
        Assert.Equal(2, p.KillsInfantry);
        Assert.Equal(4, p.KillsVehicle);
        Assert.Equal(6, p.KillsAir);
        Assert.Equal(8, p.KillsStatic);
        Assert.Equal(10, p.KillsFactory);
        Assert.Equal(12, p.KillsHq);
        Assert.Equal(14, p.Deaths);
        Assert.Equal(16, p.PvpKills);
        Assert.Equal(18, p.SupplyRuns);
        Assert.Equal(20, p.SupplyValue);
        Assert.Equal(22, p.CapturesTown);
        Assert.Equal(24, p.CapturesCamp);
        Assert.Equal(26, p.StructuresBuilt);
        Assert.Equal(28, p.DefensesBuilt);
        Assert.Equal(120, p.PlaytimeSeconds);
        Assert.Equal(2, p.Side);                                       // latest flush wins
        Assert.Equal(10850, Composite(p));                             // receiver would store this in total_score

        // Contract guard: stats.json carries every column the receiver expects, by name.
        var json = File.ReadAllText(statsJson);
        foreach (var key in new[] {
            "kills_infantry","kills_vehicle","kills_air","kills_static","kills_factory","kills_hq",
            "deaths","pvp_kills","supply_runs","supply_value","captures_town","captures_camp",
            "structures_built","defenses_built","playtime_seconds","side" })
            Assert.Contains($"\"{key}\"", json);

        Directory.Delete(dir, true);
    }

    [Fact]
    public void Server_restart_resets_offset_without_double_counting()
    {
        var dir = Path.Combine(Path.GetTempPath(), "wasp_e2e_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        var rpt = Path.Combine(dir, "ArmA2OA.RPT");
        var statsJson = Path.Combine(dir, "stats.json");
        var state = Path.Combine(dir, "stats.json.tail.state");
        const string uid = "76561198000000000";
        var one = new int[15]; one[0] = 1;   // 1 infantry kill per line

        File.WriteAllText(rpt, "session A header\n" + WaspLine(1, uid, one, 1) + "\n");
        var acc = new StatsAccumulator(StatsDocument.Load(statsJson));
        var tailer = new RptTailer(rpt, state);
        foreach (var l in tailer.ReadNewLines()) if (StatsBatchParser.TryParseLine(l, out var b)) acc.ApplyBatch(b);
        acc.Save(statsJson);
        Assert.Equal(1, StatsDocument.Load(statsJson).Players[uid].KillsInfantry);

        // New session: RPT replaced (different first line). The single kill in session B must add once.
        File.WriteAllText(rpt, "session B header\n" + WaspLine(1, uid, one, 1) + "\n");
        foreach (var l in tailer.ReadNewLines()) if (StatsBatchParser.TryParseLine(l, out var b)) acc.ApplyBatch(b);
        acc.Save(statsJson);
        Assert.Equal(2, StatsDocument.Load(statsJson).Players[uid].KillsInfantry);   // 1 + 1, not 1 + replay

        Directory.Delete(dir, true);
    }
}
