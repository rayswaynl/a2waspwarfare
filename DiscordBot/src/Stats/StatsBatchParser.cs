using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

public struct StatSegment { public string Uid; public int[] Deltas; public int Side; }
public struct ParsedBatch { public int Seq; public List<StatSegment> Segments; }

public static class StatsBatchParser
{
    private const string Marker = "WASPSTAT|v1|";
    private static readonly Regex UidRe = new(@"^\d{5,20}$", RegexOptions.Compiled);

    public static bool TryParseLine(string rptLine, out ParsedBatch batch)
    {
        batch = default;
        if (rptLine == null) return false;
        int i = rptLine.IndexOf(Marker, StringComparison.Ordinal);
        if (i < 0) return false;

        var payload = rptLine.Substring(i).TrimEnd('"', ' ', '\t', '\r', '\n');
        var parts = payload.Split('|');                 // WASPSTAT, v1, <seq>, seg, seg...
        if (parts.Length < 3 || !int.TryParse(parts[2], out var seq)) return false;

        var segments = new List<StatSegment>();
        for (int p = 3; p < parts.Length; p++)
        {
            var colon = parts[p].IndexOf(':');
            if (colon <= 0) continue;
            var uid = parts[p].Substring(0, colon);
            if (!UidRe.IsMatch(uid)) continue;
            var nums = parts[p].Substring(colon + 1).Split(',');
            if (nums.Length != PlayerStat.FieldCount + 1) continue;   // 15 deltas + side
            var deltas = new int[PlayerStat.FieldCount];
            bool ok = true;
            for (int k = 0; k < PlayerStat.FieldCount; k++)
                if (!int.TryParse(nums[k], out deltas[k])) { ok = false; break; }
            if (!ok || !int.TryParse(nums[PlayerStat.FieldCount], out var side)) continue;
            segments.Add(new StatSegment { Uid = uid, Deltas = deltas, Side = side });
        }
        batch = new ParsedBatch { Seq = seq, Segments = segments };
        return true;
    }
}
