public sealed class GeneratedLoadoutFiles
{
    public GeneratedLoadoutFiles(
        MapFileProperties _easa,
        MapFileProperties _commonBalance,
        MapFileProperties _aircraftDisplayNames,
        MapFileProperties _aircraftDamageModelChanges,
        string _coreMod)
    {
        Easa = _easa;
        CommonBalance = _commonBalance;
        AircraftDisplayNames = _aircraftDisplayNames;
        AircraftDamageModelChanges = _aircraftDamageModelChanges;
        CoreMod = _coreMod;
    }

    public MapFileProperties Easa { get; }
    public MapFileProperties CommonBalance { get; }
    public MapFileProperties AircraftDisplayNames { get; }
    public MapFileProperties AircraftDamageModelChanges { get; }
    public string CoreMod { get; }
}
