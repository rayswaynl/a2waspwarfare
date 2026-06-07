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

    public const int FieldCount = 15;

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
}
