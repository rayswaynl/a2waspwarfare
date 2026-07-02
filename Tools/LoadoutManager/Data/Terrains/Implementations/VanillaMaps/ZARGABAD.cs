public class ZARGABAD : BaseTerrain
{
    public ZARGABAD()
    {
        TerrainName = TerrainName.ZARGABAD;
        TerrainType = TerrainType.DESERT;
        // 8192 m world — Takistan's 7500 m starting distance barely fits the
        // map diagonal, so base placement uses a smaller minimum here.
        startingDistanceInMeters = 5000;
        terrainModStatus = TerrainModStatus.VANILLA;
        inGameMapName = "zargabad";
        isNavalTerrain = false;
    }
}