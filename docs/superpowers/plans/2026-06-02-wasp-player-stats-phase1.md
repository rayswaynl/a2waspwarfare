# WASP Player-Stats — Phase 1 (Thin Slice) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the full in-game-stats pipeline end-to-end with a thin slice — record **kills (by target type) + pvp_kills + playtime** server-side on Chernarus, route them via the RPT log to the `net9` DiscordBot, which writes `stats.json`, which the existing Python bot ingests into Postgres so `/leaderboard` and `/stats` show real data.

**Architecture:** SQF server-side hooks buffer per-player integer deltas; a ~60s flush loop `diag_log`s one `WASPSTAT|v1|<seq>|<uid>:<d0..d14>,<side>|…` line to the server RPT. A new `Stats/` module in the DiscordBot tails the RPT (offset-tracked, rotation-safe), accumulates lifetime totals (seeded from `stats.json`), and writes `stats.json` atomically. The existing `bot/cogs/stats_reader.py` (file mode) upserts it. Server-authoritative (no client stat path); off by default.

**Tech Stack:** Arma 2 OA SQF; C# `net9.0` (Discord.Net 3.10, Newtonsoft 13); xUnit; Python discord.py (receiver, already built); Postgres (already built).

**Spec:** `docs/superpowers/specs/2026-06-02-wasp-player-stats-design.md` (rev 3, in this repo).

**Repo / branch:** all SQF + C# work lives in the `rayswaynl/a2waspwarfare` fork on branch `feat/player-stats` (off `origin/master`), shipped as its own PR. To avoid disturbing the `feat/supply-helicopter` WIP in the main checkout, work happens in an **isolated worktree** at `C:\Users\Steff\a2waspwarfare-stats` — the `C:\Users\Steff\a2waspwarfare\…` paths in the tasks below refer to that worktree. **Never touch the website repo (`miksuus-warfare`) in this PR.**

---

## Prerequisites (do first)

- [ ] **P1: Install the .NET 9 SDK** (current is 8.0.421; the bot targets `net9.0`).
  Run: `winget install Microsoft.DotNet.SDK.9` then restart the shell.
  Verify: `dotnet --list-sdks` shows a `9.x` entry.
- [ ] **P2: Confirm the bot builds today (baseline).**
  Run: `dotnet build "C:\Users\Steff\a2waspwarfare\DiscordBot\DiscordBot.csproj"`
  Expected: `Build succeeded`. If it fails, stop and fix the toolchain before continuing.
- [ ] **P3: Branch/worktree (already done).** The isolated worktree exists at `C:\Users\Steff\a2waspwarfare-stats` on `feat/player-stats` (off `origin/master`). Do all work there; do NOT `git switch` the main checkout (it holds `feat/supply-helicopter` WIP).
  Verify: `git -C "C:\Users\Steff\a2waspwarfare-stats" branch --show-current` → `feat/player-stats`.

> **Wire format (locked).** RPT line payload: `WASPSTAT|v1|<seq>|<uid>:<d0>,<d1>,…,<d14>,<side>|<uid2>:…`
> `<seq>` = monotonic int per server session. Each segment = `uid : 16 comma-ints` (15 stat deltas in the §4.4 index order + trailing `side`). `diag_log` wraps the string in quotes and the RPT prepends a timestamp, so readers must locate the `WASPSTAT|` marker inside the line and trim the trailing quote.
> **Index order:** `0 kills_infantry,1 kills_vehicle,2 kills_air,3 kills_static,4 kills_factory,5 kills_hq,6 deaths,7 pvp_kills,8 supply_runs,9 supply_value,10 captures_town,11 captures_camp,12 structures_built,13 defenses_built,14 playtime_seconds`.

---

## File Structure

**DiscordBot (new, `C:\Users\Steff\a2waspwarfare\DiscordBot\src\Stats\`):**
- `PlayerStat.cs` — POCO, `[DataMember]` names match the contract.
- `StatsDocument.cs` — `{ schema, Dictionary<string,PlayerStat> players }` + `Load(path)` + `SaveAtomic(path)`.
- `StatsBatchParser.cs` — pure: `TryParseLine(string rptLine, out ParsedBatch batch)`.
- `StatsAccumulator.cs` — in-memory `StatsDocument`; `ApplyBatch(ParsedBatch)`; dirty flag; thread-safe.
- `RptTailer.cs` — offset-tracked reader over the RPT; rotation-safe; persists offset sidecar.
- `StatsService.cs` — timer (mirrors `GameStatusUpdater`): tail → parse → apply → save.

**DiscordBot (edited):** `src/Preferences.cs` (+fields), `src/ProgramRuntime.cs` (+launch).

**DiscordBot tests (new, `C:\Users\Steff\a2waspwarfare\DiscordBot.Tests\`):** `DiscordBot.Tests.csproj` (net9 + xUnit, ProjectReference to the bot) + `StatsBatchParserTests.cs`, `StatsAccumulatorTests.cs`, `RptTailerTests.cs`.

**SQF (Chernarus, `C:\Users\Steff\a2waspwarfare\Missions\[55-2hc]warfarev2_073v48co.chernarus\`):**
- `Common\Init\Init_CommonConstants.sqf` (edit) — `WFBE_C_STATS_ENABLED` + `WFBE_STAT_*` indices.
- `Server\Stats\RecordStat.sqf` (new) — defines `WFBE_SE_FNC_RecordStat`.
- `Server\Stats\StatsFlush.sqf` (new) — the ~60s flush loop.
- `Server\Init_Server.sqf` (edit) — compile `RecordStat`, launch `StatsFlush`.
- `Server\PVFunctions\RequestOnUnitKilled.sqf` (edit) — record kills + pvp.
- `Server\CallExtensions\GlobalGameStats.sqf` (edit) — adjacent player-count fix.

**Receiver (config only, no code in this PR):** Python bot `.env` `STATS_SOURCE=file`.

---

## Task 1: Scaffold the DiscordBot test project

**Files:**
- Create: `C:\Users\Steff\a2waspwarfare\DiscordBot.Tests\DiscordBot.Tests.csproj`
- Create: `C:\Users\Steff\a2waspwarfare\DiscordBot.Tests\CanaryTests.cs`

- [ ] **Step 1: Create the test project file**

```xml
<!-- DiscordBot.Tests/DiscordBot.Tests.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.11.1" />
    <PackageReference Include="xunit" Version="2.9.2" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\DiscordBot\DiscordBot.csproj" />
  </ItemGroup>
</Project>
```

- [ ] **Step 2: Write a canary test**

```csharp
// DiscordBot.Tests/CanaryTests.cs
public class CanaryTests
{
    [Fact]
    public void Canary() => Assert.True(true);
}
```

- [ ] **Step 3: Run it**

Run: `dotnet test "C:\Users\Steff\a2waspwarfare\DiscordBot.Tests\DiscordBot.Tests.csproj"`
Expected: `Passed!  - Failed: 0, Passed: 1`. (Confirms net9 test harness + project reference resolve.)

- [ ] **Step 4: Commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add DiscordBot.Tests
git -C "C:\Users\Steff\a2waspwarfare" commit -m "test: scaffold DiscordBot.Tests (net9 xunit)"
```

---

## Task 2: PlayerStat + StatsDocument (load / atomic save)

**Files:**
- Create: `DiscordBot\src\Stats\PlayerStat.cs`
- Create: `DiscordBot\src\Stats\StatsDocument.cs`
- Test: `DiscordBot.Tests\StatsAccumulatorTests.cs` (round-trip test added here; accumulator added in Task 4)

- [ ] **Step 1: Write the failing round-trip test**

```csharp
// DiscordBot.Tests/StatsDocumentTests.cs
using System.IO;
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `dotnet test "C:\Users\Steff\a2waspwarfare\DiscordBot.Tests" --filter StatsDocumentTests`
Expected: FAIL — `PlayerStat`/`StatsDocument` do not exist (compile error).

- [ ] **Step 3: Implement `PlayerStat.cs`**

```csharp
// DiscordBot/src/Stats/PlayerStat.cs
using System.Runtime.Serialization;

[DataContract]
public class PlayerStat
{
    [DataMember(Name = "kills_infantry")]   public int KillsInfantry;
    [DataMember(Name = "kills_vehicle")]    public int KillsVehicle;
    [DataMember(Name = "kills_air")]        public int KillsAir;
    [DataMember(Name = "kills_static")]     public int KillsStatic;
    [DataMember(Name = "kills_factory")]    public int KillsFactory;
    [DataMember(Name = "kills_hq")]         public int KillsHq;
    [DataMember(Name = "deaths")]           public int Deaths;
    [DataMember(Name = "pvp_kills")]        public int PvpKills;
    [DataMember(Name = "supply_runs")]      public int SupplyRuns;
    [DataMember(Name = "supply_value")]     public int SupplyValue;
    [DataMember(Name = "captures_town")]    public int CapturesTown;
    [DataMember(Name = "captures_camp")]    public int CapturesCamp;
    [DataMember(Name = "structures_built")] public int StructuresBuilt;
    [DataMember(Name = "defenses_built")]   public int DefensesBuilt;
    [DataMember(Name = "playtime_seconds")] public int PlaytimeSeconds;
    [DataMember(Name = "side")]             public int Side;

    // Index order MUST match the SQF WFBE_STAT_* constants and the wire format.
    public void AddDelta(int index, int amount)
    {
        switch (index)
        {
            case 0:  KillsInfantry   += amount; break;
            case 1:  KillsVehicle    += amount; break;
            case 2:  KillsAir        += amount; break;
            case 3:  KillsStatic     += amount; break;
            case 4:  KillsFactory    += amount; break;
            case 5:  KillsHq         += amount; break;
            case 6:  Deaths          += amount; break;
            case 7:  PvpKills        += amount; break;
            case 8:  SupplyRuns      += amount; break;
            case 9:  SupplyValue     += amount; break;
            case 10: CapturesTown    += amount; break;
            case 11: CapturesCamp    += amount; break;
            case 12: StructuresBuilt += amount; break;
            case 13: DefensesBuilt   += amount; break;
            case 14: PlaytimeSeconds += amount; break;
        }
    }
    public const int FieldCount = 15;
}
```

- [ ] **Step 4: Implement `StatsDocument.cs`**

```csharp
// DiscordBot/src/Stats/StatsDocument.cs
using System.Collections.Generic;
using System.IO;
using System.Runtime.Serialization;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

[DataContract]
public class StatsDocument
{
    [DataMember(Name = "schema")] public int Schema = 1;
    [DataMember(Name = "players")] public Dictionary<string, PlayerStat> Players = new();

    private static JsonSerializerSettings Settings() => new JsonSerializerSettings
    {
        ContractResolver = new DataMemberOnlyResolver(),
        NullValueHandling = NullValueHandling.Include,
        Formatting = Formatting.Indented,
    };

    public static StatsDocument Load(string path)
    {
        try
        {
            if (!File.Exists(path)) return new StatsDocument();
            var json = File.ReadAllText(path);
            return JsonConvert.DeserializeObject<StatsDocument>(json, Settings()) ?? new StatsDocument();
        }
        catch { return new StatsDocument(); }
    }

    public void SaveAtomic(string path)
    {
        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
        var tmp = path + ".tmp";
        File.WriteAllText(tmp, JsonConvert.SerializeObject(this, Settings()));
        if (File.Exists(path)) File.Replace(tmp, path, null);
        else File.Move(tmp, path);
    }

    private class DataMemberOnlyResolver : DefaultContractResolver
    {
        protected override System.Collections.Generic.IList<JsonProperty> CreateProperties(
            System.Type type, MemberSerialization ms)
            => base.CreateProperties(type, ms)
                   .Where(p => p.AttributeProvider!.GetAttributes(typeof(DataMemberAttribute), true).Any())
                   .ToList();
    }
}
```

- [ ] **Step 5: Run the tests**

Run: `dotnet test "C:\Users\Steff\a2waspwarfare\DiscordBot.Tests" --filter StatsDocumentTests`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add DiscordBot/src/Stats DiscordBot.Tests
git -C "C:\Users\Steff\a2waspwarfare" commit -m "feat(stats): PlayerStat + StatsDocument with contract-named JSON"
```

---

## Task 3: StatsBatchParser

**Files:**
- Create: `DiscordBot\src\Stats\StatsBatchParser.cs`
- Test: `DiscordBot.Tests\StatsBatchParserTests.cs`

- [ ] **Step 1: Write the failing tests**

```csharp
// DiscordBot.Tests/StatsBatchParserTests.cs
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `dotnet test "C:\Users\Steff\a2waspwarfare\DiscordBot.Tests" --filter StatsBatchParserTests`
Expected: FAIL — `StatsBatchParser` not defined.

- [ ] **Step 3: Implement `StatsBatchParser.cs`**

```csharp
// DiscordBot/src/Stats/StatsBatchParser.cs
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
        int i = rptLine.IndexOf(Marker, System.StringComparison.Ordinal);
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
```

- [ ] **Step 4: Run the tests** — Run: `dotnet test "C:\Users\Steff\a2waspwarfare\DiscordBot.Tests" --filter StatsBatchParserTests` — Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add DiscordBot/src/Stats/StatsBatchParser.cs DiscordBot.Tests/StatsBatchParserTests.cs
git -C "C:\Users\Steff\a2waspwarfare" commit -m "feat(stats): WASPSTAT line parser with malformed-segment tolerance"
```

---

## Task 4: StatsAccumulator

**Files:**
- Create: `DiscordBot\src\Stats\StatsAccumulator.cs`
- Test: `DiscordBot.Tests\StatsAccumulatorTests.cs`

- [ ] **Step 1: Write the failing tests**

```csharp
// DiscordBot.Tests/StatsAccumulatorTests.cs
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
        acc.ApplyBatch(Batch(2, "76561198000000000", d, 2)); // again → totals double, side updates
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
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL — `StatsAccumulator` not defined.

- [ ] **Step 3: Implement `StatsAccumulator.cs`**

```csharp
// DiscordBot/src/Stats/StatsAccumulator.cs
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
```

- [ ] **Step 4: Run the tests** — Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add DiscordBot/src/Stats/StatsAccumulator.cs DiscordBot.Tests/StatsAccumulatorTests.cs
git -C "C:\Users\Steff\a2waspwarfare" commit -m "feat(stats): lifetime-total accumulator seeded from stats.json"
```

---

## Task 5: RptTailer (offset + rotation safe)

**Files:**
- Create: `DiscordBot\src\Stats\RptTailer.cs`
- Test: `DiscordBot.Tests\RptTailerTests.cs`

- [ ] **Step 1: Write the failing tests**

```csharp
// DiscordBot.Tests/RptTailerTests.cs
using System.IO;
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
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL — `RptTailer` not defined.

- [ ] **Step 3: Implement `RptTailer.cs`**

```csharp
// DiscordBot/src/Stats/RptTailer.cs
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;

public class RptTailer
{
    private readonly string _rptPath;
    private readonly string _statePath;
    private long _offset;

    public RptTailer(string rptPath, string statePath)
    {
        _rptPath = rptPath; _statePath = statePath;
        _offset = LoadOffset();
    }

    public string[] ReadNewLines()
    {
        if (!File.Exists(_rptPath)) return System.Array.Empty<string>();
        var len = new FileInfo(_rptPath).Length;
        if (len < _offset) _offset = 0;                 // rotation / new session
        if (len == _offset) return System.Array.Empty<string>();

        var lines = new List<string>();
        using (var fs = new FileStream(_rptPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            fs.Seek(_offset, SeekOrigin.Begin);
            using var sr = new StreamReader(fs);
            string? line;
            while ((line = sr.ReadLine()) != null) lines.Add(line);
            _offset = fs.Position;
        }
        SaveOffset();
        return lines.ToArray();
    }

    private long LoadOffset()
    {
        try { return File.Exists(_statePath) ? JsonConvert.DeserializeObject<State>(File.ReadAllText(_statePath))!.Offset : 0; }
        catch { return 0; }
    }
    private void SaveOffset()
    {
        try { File.WriteAllText(_statePath, JsonConvert.SerializeObject(new State { Offset = _offset })); } catch { }
    }
    private class State { public long Offset { get; set; } }
}
```

> Note: `ReadNewLines` may return a trailing partial line if a flush is mid-write; the parser ignores non-`WASPSTAT` / malformed lines, and the next tick re-reads from the advanced offset. Acceptable; documented in spec §6.

- [ ] **Step 4: Run the tests** — Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add DiscordBot/src/Stats/RptTailer.cs DiscordBot.Tests/RptTailerTests.cs
git -C "C:\Users\Steff\a2waspwarfare" commit -m "feat(stats): rotation-safe RPT tailer with persisted offset"
```

---

## Task 6: Preferences fields + StatsService + wiring

**Files:**
- Modify: `DiscordBot\src\Preferences.cs`
- Create: `DiscordBot\src\Stats\StatsService.cs`
- Modify: `DiscordBot\src\ProgramRuntime.cs:63-73` (`SetupProgramListenersAndSchedulers`)

- [ ] **Step 1: Add preferences fields**

In `Preferences.cs`, add inside the class (after `a3Mode`):

```csharp
    public bool StatsEnabled { get; set; } = false;
    public string? ServerRptPath { get; set; }      // full path to the Arma 2 OA server .rpt
    public string StatsJsonPath { get; set; } = @"C:\a2waspwarfare\Data\stats.json";
    public int StatsPollSeconds { get; set; } = 60;
```

- [ ] **Step 2: Implement `StatsService.cs`** (mirrors `GameStatusUpdater`'s timer + semaphore)

```csharp
// DiscordBot/src/Stats/StatsService.cs
using System.Timers;

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

    private async void OnTick(object? s, ElapsedEventArgs e)
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
```

- [ ] **Step 3: Launch it from `ProgramRuntime.SetupProgramListenersAndSchedulers`**

In `ProgramRuntime.cs`, after the `gameStatusUpdater.StartGameStatusUpdates(client);` line, add:

```csharp
        // Start in-game player-stats ingest (RPT tail → stats.json). No-op unless Preferences.StatsEnabled.
        new StatsService().Start();
```

- [ ] **Step 4: Build**

Run: `dotnet build "C:\Users\Steff\a2waspwarfare\DiscordBot\DiscordBot.csproj"`
Expected: `Build succeeded`.

- [ ] **Step 5: Run the full test suite** — Run: `dotnet test "C:\Users\Steff\a2waspwarfare\DiscordBot.Tests"` — Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add DiscordBot/src/Preferences.cs DiscordBot/src/Stats/StatsService.cs DiscordBot/src/ProgramRuntime.cs
git -C "C:\Users\Steff\a2waspwarfare" commit -m "feat(stats): StatsService timer wires RPT tail → accumulator → stats.json"
```

---

## Task 7: SQF — constants, RecordStat helper, flush loop

**Files:**
- Modify: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Common\Init\Init_CommonConstants.sqf`
- Create: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Stats\RecordStat.sqf`
- Create: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Stats\StatsFlush.sqf`
- Modify: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Init_Server.sqf` (near the `GlobalGameStats.sqf` exec, ~line 298)

- [ ] **Step 1: Add constants + flag** to the end of `Init_CommonConstants.sqf`:

```sqf
// --- Player stats (feature-flagged; off by default) ---
WFBE_C_STATS_ENABLED = false;        // master switch
WFBE_C_STATS_FLUSH_INTERVAL = 60;    // seconds between RPT flushes
WFBE_STAT_KILLS_INFANTRY   = 0;
WFBE_STAT_KILLS_VEHICLE    = 1;
WFBE_STAT_KILLS_AIR        = 2;
WFBE_STAT_KILLS_STATIC     = 3;
WFBE_STAT_KILLS_FACTORY    = 4;
WFBE_STAT_KILLS_HQ         = 5;
WFBE_STAT_DEATHS           = 6;
WFBE_STAT_PVP_KILLS        = 7;
WFBE_STAT_SUPPLY_RUNS      = 8;
WFBE_STAT_SUPPLY_VALUE     = 9;
WFBE_STAT_CAPTURES_TOWN    = 10;
WFBE_STAT_CAPTURES_CAMP    = 11;
WFBE_STAT_STRUCTURES_BUILT = 12;
WFBE_STAT_DEFENSES_BUILT   = 13;
WFBE_STAT_PLAYTIME         = 14;
WFBE_STAT_FIELD_COUNT      = 15;
WFBE_STATS_DIRTY_UIDS = [];           // server-only working set
```

- [ ] **Step 2: Create `Server\Stats\RecordStat.sqf`** (defines the buffer-increment helper)

```sqf
// Server-only. Buffers a per-player stat delta. O(1), no IPC. No-op when disabled.
WFBE_SE_FNC_RecordStat = {
    params ["_uid", "_statIndex", ["_amount", 1]];
    if (!WFBE_C_STATS_ENABLED) exitWith {};
    if (isNil "_uid" || {_uid isEqualTo ""} || {_amount == 0}) exitWith {};

    private _key = "WFBE_STAT_BUF_" + _uid;
    private _buf = missionNamespace getVariable [_key, []];
    if (count _buf < WFBE_STAT_FIELD_COUNT) then {
        _buf = [];
        for "_i" from 1 to WFBE_STAT_FIELD_COUNT do { _buf pushBack 0; };
    };
    _buf set [_statIndex, (_buf select _statIndex) + _amount];
    missionNamespace setVariable [_key, _buf];
    if !(_uid in WFBE_STATS_DIRTY_UIDS) then { WFBE_STATS_DIRTY_UIDS pushBack _uid; };
};

// Sets the player's current side number (1 west, 2 east, 0 none) for the next flush.
WFBE_SE_FNC_RecordStatSide = {
    params ["_uid", "_side"];
    if (!WFBE_C_STATS_ENABLED) exitWith {};
    missionNamespace setVariable ["WFBE_STAT_SIDE_" + _uid, _side];
    if !(_uid in WFBE_STATS_DIRTY_UIDS) then { WFBE_STATS_DIRTY_UIDS pushBack _uid; };
};
```

- [ ] **Step 3: Create `Server\Stats\StatsFlush.sqf`** (the ~60s loop)

```sqf
// Server-only flush loop: add playtime, emit one WASPSTAT line per interval, zero buffers.
if (!WFBE_C_STATS_ENABLED) exitWith {};

private _seq = 0;
while {true} do {
    sleep WFBE_C_STATS_FLUSH_INTERVAL;

    // 1) Credit playtime to every connected player.
    {
        if (isPlayer _x) then {
            private _uid = getPlayerUID _x;
            if (_uid != "") then {
                [_uid, WFBE_STAT_PLAYTIME, WFBE_C_STATS_FLUSH_INTERVAL] call WFBE_SE_FNC_RecordStat;
                [_uid, (_x call WFBE_CO_FNC_GetSideNumber)] call WFBE_SE_FNC_RecordStatSide;
            };
        };
    } forEach call BIS_fnc_listPlayers;

    // 2) Build one line for all dirty UIDs.
    if (count WFBE_STATS_DIRTY_UIDS > 0) then {
        _seq = _seq + 1;
        private _line = "WASPSTAT|v1|" + str _seq;
        {
            private _uid = _x;
            private _buf = missionNamespace getVariable ["WFBE_STAT_BUF_" + _uid, []];
            if (count _buf >= WFBE_STAT_FIELD_COUNT) then {
                private _side = missionNamespace getVariable ["WFBE_STAT_SIDE_" + _uid, 0];
                private _csv = "";
                { _csv = _csv + (str _x) + ","; } forEach _buf;   // 15 deltas
                _csv = _csv + (str _side);                        // + side
                _line = _line + "|" + _uid + ":" + _csv;
                // zero this player's buffer
                missionNamespace setVariable ["WFBE_STAT_BUF_" + _uid, nil];
            };
        } forEach WFBE_STATS_DIRTY_UIDS;
        WFBE_STATS_DIRTY_UIDS = [];

        diag_log _line;
    };
};
```

> `WFBE_CO_FNC_GetSideNumber`: if the codebase lacks a side→number helper, inline it: `private _sn = switch (side _x) do { case west:{1}; case east:{2}; default {0} };`. Verify the existing helper name during implementation; otherwise inline.

- [ ] **Step 4: Wire into `Init_Server.sqf`** next to the existing `GlobalGameStats.sqf` launch (~line 298):

```sqf
call compile preprocessFileLineNumbers "Server\Stats\RecordStat.sqf";
[] execVM "Server\Stats\StatsFlush.sqf";
```

- [ ] **Step 5: Pack + manual verify** (no SQF unit framework)

```powershell
# Temporarily set WFBE_C_STATS_ENABLED = true in Init_CommonConstants.sqf for testing, then:
python C:\Users\Steff\pack_pbo.py "C:\Users\Steff\a2waspwarfare\Missions\[55-2hc]warfarev2_073v48co.chernarus"
# Launch the local dedicated server with this mission, join, wait ~2 min.
```
Expected: the server `.rpt` contains at least one `WASPSTAT|v1|<n>|<your_uid>:0,0,...,60,1` line (playtime credited even before any kills). If absent: confirm the flag is true, the loop launched (grep RPT for the exec), and `getPlayerUID player` is non-empty.

- [ ] **Step 6: Revert the flag to `false`, commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Stats" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init_Server.sqf"
git -C "C:\Users\Steff\a2waspwarfare" commit -m "feat(stats): SQF buffer helper + 60s RPT flush loop (off by default)"
```

---

## Task 8: SQF — record kills + pvp in RequestOnUnitKilled

**Files:**
- Modify: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\PVFunctions\RequestOnUnitKilled.sqf` (insert after line ~41, where `_killer_uid`, `_killed_isplayer`, `_killer_isplayer`, `_killed_isman`, `_killed_type`, `_killer_vehicle` are all defined — BEFORE the score-gate `if (!isNil '_get' && _killer_iswfteam)` block)

- [ ] **Step 1: Insert the recording block**

```sqf
// --- Player-stats: record every kill (server-authoritative), independent of the score gate. ---
if (WFBE_C_STATS_ENABLED && {_killer_side != _killed_side} && {!isNull _killer}) then {
    private _attrUid = if (_killer_isplayer) then { getPlayerUID _killer } else { getPlayerUID (leader _killer_group) };
    if (_attrUid != "") then {
        private _idx = WFBE_STAT_KILLS_INFANTRY;
        if (!_killed_isman) then {
            switch (true) do {
                case (_killed isKindOf "Air"):          { _idx = WFBE_STAT_KILLS_AIR; };
                case (_killed isKindOf "StaticWeapon"): { _idx = WFBE_STAT_KILLS_STATIC; };
                default                                 { _idx = WFBE_STAT_KILLS_VEHICLE; };   // Car/Tank/etc.
            };
        };
        [_attrUid, _idx, 1] call WFBE_SE_FNC_RecordStat;
        if (_killed_isplayer) then { [_attrUid, WFBE_STAT_PVP_KILLS, 1] call WFBE_SE_FNC_RecordStat; };
    };
};
// --- end player-stats ---
```

- [ ] **Step 2: Pack + manual verify**

```powershell
# flag = true, then:
python C:\Users\Steff\pack_pbo.py "C:\Users\Steff\a2waspwarfare\Missions\[55-2hc]warfarev2_073v48co.chernarus"
# Launch, join, kill a few AI infantry + one vehicle, wait one flush interval.
```
Expected: a `WASPSTAT` line where your UID's segment shows `kills_infantry` (index 0) and/or `kills_vehicle` (index 1) incremented, e.g. `...|<uid>:3,1,0,...`. Kill another *player* (or a second client) → `pvp_kills` (index 7) increments too.

- [ ] **Step 3: Revert the flag, commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestOnUnitKilled.sqf"
git -C "C:\Users\Steff\a2waspwarfare" commit -m "feat(stats): record kills by type + pvp_kills server-side (off by default)"
```

---

## Task 9: Adjacent fix — empty-server player count

**Files:**
- Modify: `Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\CallExtensions\GlobalGameStats.sqf:20`

- [ ] **Step 1: Replace the off-by-one line**

Replace `:20`:
```sqf
    _playerCount = abs(_playerCount - 1); // Exclude headless client
```
with:
```sqf
    // Exclude headless clients by counting them explicitly; clamp so an empty server reports 0.
    private _hc = { isPlayer _x && !(hasInterface) } count (call BIS_fnc_listPlayers);
    _playerCount = (_playerCount - _hc) max 0;
```

> During implementation, verify the HC-detection predicate against this codebase's conventions (some builds tag the HC via a variable). If `hasInterface` isn't reliable server-side for remote HCs, detect via the known HC name/variable instead. The clamp (`max 0`) is the core fix.

- [ ] **Step 2: Pack + verify** an empty server reports `0` (channel name / database.json player count), and a 1-player server reports `1`.

- [ ] **Step 3: Commit**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/CallExtensions/GlobalGameStats.sqf"
git -C "C:\Users\Steff\a2waspwarfare" commit -m "fix(status): empty-server player count off-by-one"
```

---

## Task 10: End-to-end local wiring + verification

**Files:** (config only)
- The Python bot `.env` (`C:\Users\Steff\miksuus-warfare\bot\.env`) — local test stack.
- The DiscordBot `preferences.json` (next to its exe).

- [ ] **Step 1: Point the DiscordBot at the RPT** — in its `preferences.json` set:

```json
{ "StatsEnabled": true, "ServerRptPath": "<full path to the local Arma 2 OA server .rpt>", "StatsJsonPath": "C:\\a2waspwarfare\\Data\\stats.json", "StatsPollSeconds": 60 }
```

- [ ] **Step 2: Enable file-mode ingest on the Python bot** — in `bot/.env`:

```
STATS_SOURCE=file
STATS_JSON=C:\a2waspwarfare\Data\stats.json
STATS_POLL_SECONDS=60
```

- [ ] **Step 3: Set `WFBE_C_STATS_ENABLED = true`, pack, run everything**

Run (each in its own shell): the local Arma dedicated server (Chernarus PBO); the DiscordBot (`dotnet run --project DiscordBot`); the Python bot (`python bot/main.py` or its pm2/runner).

- [ ] **Step 4: Play, then verify each stage**

1. Kill some AI; wait ~60s.
2. `stats.json` exists at `C:\a2waspwarfare\Data\stats.json` with your SteamID and non-zero `kills_*` / `playtime_seconds`.
3. Postgres: `SELECT steam_id64, kills_infantry, pvp_kills, playtime_seconds, total_score FROM ingame_stats;` shows your row.
4. Web `/leaderboard` (after linking your Steam on `/profile`) shows you ranked; Discord `/stats` shows your combat record.

- [ ] **Step 5: Decide the shipping default**

Leave `WFBE_C_STATS_ENABLED = false` committed (ship dark). Document in the PR that enabling is: set the SQF flag true + repack + set `Preferences.StatsEnabled=true` + bot `STATS_SOURCE=file`.

- [ ] **Step 6: Final commit + open PR**

```bash
git -C "C:\Users\Steff\a2waspwarfare" add -A
git -C "C:\Users\Steff\a2waspwarfare" commit -m "docs(stats): Phase 1 enablement notes"
git -C "C:\Users\Steff\a2waspwarfare" push -u origin feat/player-stats
gh pr create --repo rayswaynl/a2waspwarfare --base master --head feat/player-stats \
  --title "Player stats (Phase 1): server-authoritative kills/PvP/playtime → DiscordBot → stats.json" \
  --body "Adds off-by-default in-game stat recording (Chernarus): SQF buffers per-player deltas, a 60s flush logs WASPSTAT lines to the RPT, and the net9 DiscordBot tails the RPT and writes stats.json for the existing site/bot pipeline. Server-authoritative, no client stat path, no changes to the legacy extension. See docs/superpowers/specs/2026-06-02-wasp-player-stats-design.md."
```

> Per the user's standing rule, commit messages carry **no Claude co-author trailer**.

---

## Separate small change (website repo — NOT in this PR)

After Phase 1 produces real data, in `C:\Users\Steff\miksuus-warfare` (its own tiny branch/PR):
- **Playtime display:** switch `/stats` (`bot/insights/`) + the profile page from `ticks/3600` (`ticks_to_hours`, UNCONFIRMED) to the real `playtime_seconds` column.
- **Contract guard test:** assert the DiscordBot `[DataMember]` names == `ingame_stats` columns / `IncomingPlayer` keys so the producer and receiver can't drift.

---

## Self-Review

- **Spec coverage:** Phase 1 scope (kills-by-type, pvp_kills, playtime, Chernarus, server-authoritative, RPT→DiscordBot→stats.json→Python file-mode→Postgres→leaderboard) — Tasks 1–8, 10. Adjacent player-count fix — Task 9. Receiver-side playtime/contract items — flagged as a separate change (spec §12), intentionally out of this PR. Phases 2–4 (more hooks, Takistan, remote POST) are deliberately not in this plan.
- **Placeholders:** none — code is complete for C# tasks; SQF tasks carry full snippets + explicit "verify this helper name / HC predicate during implementation" notes where a codebase-specific name must be confirmed.
- **Type consistency:** `StatsDocument` / `PlayerStat` (`AddDelta`, `FieldCount=15`) / `StatsBatchParser.TryParseLine`→`ParsedBatch{Seq,Segments}` / `StatSegment{Uid,Deltas[15],Side}` / `StatsAccumulator(StatsDocument)`→`ApplyBatch`,`Save`,`Dirty`,`Document` / `RptTailer(rptPath,statePath)`→`ReadNewLines()` / `StatsService.Start()` — names used consistently across Tasks 2–6 and the SQF wire format (15 deltas + side) matches the parser's `FieldCount + 1`.
