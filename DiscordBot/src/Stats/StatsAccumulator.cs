public class StatsAccumulator
{
    private readonly object _lock = new();
    public StatsDocument Document { get; }
    public bool Dirty { get; private set; }

    public StatsAccumulator(StatsDocument seed) { Document = seed ?? new StatsDocument(); }

    public void ApplyBatch(ParsedBatch batch)
    {
        lock (_lock)
        {
            if (batch.Segments == null) return;
            foreach (var seg in batch.Segments)
            {
                if (!Document.Players.TryGetValue(seg.Uid, out var p))
                {
                    p = new PlayerStat();
                    Document.Players[seg.Uid] = p;
                }
                for (int i = 0; i < PlayerStat.FieldCount; i++) p.AddDelta(i, seg.Deltas[i]);
                if (seg.Side >= 0) p.Side = seg.Side;
                Dirty = true;
            }
        }
    }

    public void Save(string path)
    {
        lock (_lock) { Document.SaveAtomic(path); Dirty = false; }
    }
}
