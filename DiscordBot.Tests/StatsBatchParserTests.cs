using Xunit;

public class StatsBatchParserTests
{
    // a 16-int segment: 15 deltas (kills_infantry=2, pvp_kills=1, playtime=60) + side=1
    private const string Seg = "76561198000000000:2,0,0,0,0,0,0,1,0,0,0,0,0,0,60,1";

    [Fact]
    public void Parses_a_real_rpt_line_with_timestamp_and_quotes()
    {
        var line = $" 1:23:45 \"WASPSTAT|v1|7|{Seg}\"";
        Assert.True(StatsBatchParser.TryParseLine(line, out var batch));
        Assert.Equal(7, batch.Seq);
        var seg = Assert.Single(batch.Segments);
        Assert.Equal("76561198000000000", seg.Uid);
        Assert.Equal(2, seg.Deltas[0]);
        Assert.Equal(1, seg.Deltas[7]);
        Assert.Equal(60, seg.Deltas[14]);
        Assert.Equal(1, seg.Side);
    }

    [Fact]
    public void Returns_false_for_non_stats_line()
        => Assert.False(StatsBatchParser.TryParseLine("some unrelated RPT noise", out _));

    [Fact]
    public void Skips_malformed_segments_but_keeps_good_ones()
    {
        var line = $"WASPSTAT|v1|3|bad:1,2,3|{Seg}|99999:notnumbers";
        Assert.True(StatsBatchParser.TryParseLine(line, out var batch));
        var seg = Assert.Single(batch.Segments);   // only the well-formed one survives
        Assert.Equal("76561198000000000", seg.Uid);
    }

    [Fact]
    public void Rejects_non_numeric_uid_keys()
    {
        var line = "WASPSTAT|v1|1|abc:1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1";
        Assert.True(StatsBatchParser.TryParseLine(line, out var batch));
        Assert.Empty(batch.Segments);
    }
}
