using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Newtonsoft.Json;

// Tails an append-only RPT log. Tracks a byte offset so each line is read once, and detects
// rotation/new-session two ways: the file is shorter than our offset (real restart), OR its
// first line changed (content replaced at the same length). Offset + fingerprint are persisted
// so detection survives a bot restart.
public class RptTailer
{
    private readonly string _rptPath;
    private readonly string _statePath;
    private long _offset;
    private string? _head;   // fingerprint = first line of the file

    public RptTailer(string rptPath, string statePath)
    {
        _rptPath = rptPath; _statePath = statePath;
        LoadState();
    }

    public string[] ReadNewLines()
    {
        if (!File.Exists(_rptPath)) return Array.Empty<string>();

        using var fs = new FileStream(_rptPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        var len = fs.Length;

        var head = ReadHead(fs);                                   // first line; stable under append
        if (len < _offset || (_head != null && _head != head)) _offset = 0;   // rotation / new session

        var lines = new List<string>();
        if (len > _offset)
        {
            fs.Seek(_offset, SeekOrigin.Begin);
            using var sr = new StreamReader(fs, Encoding.UTF8, false, 1024, leaveOpen: true);
            string? line;
            while ((line = sr.ReadLine()) != null) lines.Add(line);
            _offset = fs.Position;                                 // consumed to EOF
        }
        _head = head;
        SaveState();
        return lines.ToArray();
    }

    private static string ReadHead(FileStream fs)
    {
        fs.Seek(0, SeekOrigin.Begin);
        var sb = new StringBuilder();
        int cap = 256, b;
        while (cap-- > 0 && (b = fs.ReadByte()) != -1 && b != '\n') sb.Append((char)b);
        return sb.ToString();
    }

    private void LoadState()
    {
        try
        {
            if (!File.Exists(_statePath)) return;
            var s = JsonConvert.DeserializeObject<State>(File.ReadAllText(_statePath));
            if (s != null) { _offset = s.Offset; _head = s.Head; }
        }
        catch { _offset = 0; _head = null; }
    }

    private void SaveState()
    {
        try { File.WriteAllText(_statePath, JsonConvert.SerializeObject(new State { Offset = _offset, Head = _head })); }
        catch { }
    }

    private class State { public long Offset { get; set; } public string? Head { get; set; } }
}
