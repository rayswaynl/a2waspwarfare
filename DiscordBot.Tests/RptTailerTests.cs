using System;
using System.IO;
using Xunit;

public class RptTailerTests
{
    private static string TempFile() => Path.Combine(Path.GetTempPath(), "rpt_" + Guid.NewGuid().ToString("N") + ".log");

    [Fact]
    public void Reads_only_new_lines_across_calls()
    {
        var f = TempFile(); var state = f + ".state";
        File.WriteAllText(f, "line1\nline2\n");
        var t = new RptTailer(f, state);
        Assert.Equal(new[] { "line1", "line2" }, t.ReadNewLines());
        Assert.Empty(t.ReadNewLines());                       // nothing new
        File.AppendAllText(f, "line3\n");
        Assert.Equal(new[] { "line3" }, t.ReadNewLines());    // only the new one
        File.Delete(f); File.Delete(state);
    }

    [Fact]
    public void Resets_to_zero_when_file_shrinks_rotation()
    {
        var f = TempFile(); var state = f + ".state";
        File.WriteAllText(f, "a\nb\nc\n");
        var t = new RptTailer(f, state);
        t.ReadNewLines();
        File.WriteAllText(f, "fresh\n");                      // new session: file shorter
        Assert.Equal(new[] { "fresh" }, t.ReadNewLines());
        File.Delete(f); File.Delete(state);
    }

    [Fact]
    public void Missing_file_returns_empty()
        => Assert.Empty(new RptTailer(TempFile(), TempFile() + ".state").ReadNewLines());
}
