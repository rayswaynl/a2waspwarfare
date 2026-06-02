using System;
using System.Threading;
using System.Timers;

// Mirrors GameStatusUpdater: a System.Timers.Timer guarded by a SemaphoreSlim.
// Each tick: tail the server RPT, parse WASPSTAT lines, accumulate lifetime totals, write stats.json.
public class StatsService
{
    private System.Timers.Timer? _timer;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private StatsAccumulator? _acc;
    private RptTailer? _tailer;
    private string _statsJsonPath = "";

    public void Start()
    {
        var p = Preferences.Instance;
        if (!p.StatsEnabled) { Log.WriteLine("Stats disabled, not starting StatsService", LogLevel.DEBUG); return; }
        if (string.IsNullOrWhiteSpace(p.ServerRptPath)) { Log.WriteLine("ServerRptPath not set, StatsService idle", LogLevel.WARNING); return; }

        _statsJsonPath = p.StatsJsonPath;
        _acc = new StatsAccumulator(StatsDocument.Load(_statsJsonPath));
        _tailer = new RptTailer(p.ServerRptPath!, _statsJsonPath + ".tail.state");

        _timer = new System.Timers.Timer(Math.Max(10, p.StatsPollSeconds) * 1000) { AutoReset = true, Enabled = true };
        _timer.Elapsed += OnTick;
        Log.WriteLine($"StatsService started (rpt={p.ServerRptPath}, out={_statsJsonPath})", LogLevel.DEBUG);
    }

    private async void OnTick(object? sender, ElapsedEventArgs e)
    {
        if (!await _gate.WaitAsync(100)) return;
        try
        {
            bool applied = false;
            foreach (var line in _tailer!.ReadNewLines())
                if (StatsBatchParser.TryParseLine(line, out var batch)) { _acc!.ApplyBatch(batch); applied = true; }
            if (applied && _acc!.Dirty) _acc.Save(_statsJsonPath);
        }
        catch (Exception ex) { Log.WriteLine($"StatsService tick error: {ex.Message}", LogLevel.ERROR); }
        finally { _gate.Release(); }
    }
}
