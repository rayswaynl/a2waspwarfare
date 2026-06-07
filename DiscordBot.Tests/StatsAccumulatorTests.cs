using System.Collections.Generic;
using Xunit;

public class StatsAccumulatorTests
{
    private static ParsedBatch Batch(int seq, string uid, int[] deltas, int side)
        => new ParsedBatch { Seq = seq, Segments = new() { new StatSegment { Uid = uid, Deltas = deltas, Side = side } } };

    [Fact]
    public void ApplyBatch_accumulates_deltas_into_lifetime_totals()
    {
        var acc = new StatsAccumulator(new StatsDocument());
        var d = new int[15]; d[0] = 2; d[7] = 1;            // 2 infantry kills, 1 pvp
        acc.ApplyBatch(Batch(1, "76561198000000000", d, 1));
        acc.ApplyBatch(Batch(2, "76561198000000000", d, 2)); // again -> totals double, side updates
        var p = acc.Document.Players["76561198000000000"];
        Assert.Equal(4, p.KillsInfantry);
        Assert.Equal(2, p.PvpKills);
        Assert.Equal(2, p.Side);
        Assert.True(acc.Dirty);
    }

    [Fact]
    public void Seeds_from_existing_document()
    {
        var seed = new StatsDocument();
        seed.Players["76561198000000000"] = new PlayerStat { KillsInfantry = 10 };
        var acc = new StatsAccumulator(seed);
        var d = new int[15]; d[0] = 1;
        acc.ApplyBatch(Batch(1, "76561198000000000", d, 1));
        Assert.Equal(11, acc.Document.Players["76561198000000000"].KillsInfantry);
    }
}
