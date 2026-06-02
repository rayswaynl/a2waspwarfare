using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
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
        protected override IList<JsonProperty> CreateProperties(Type type, MemberSerialization ms)
            => base.CreateProperties(type, ms)
                   .Where(p => p.AttributeProvider!.GetAttributes(typeof(DataMemberAttribute), true).Any())
                   .ToList();
    }
}
