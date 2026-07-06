using System;
using System.Collections.Generic;

class Program
{
    static int Main(string[] args)
    {
        if (args.Any(arg =>
            arg.Equals("--check", StringComparison.OrdinalIgnoreCase) ||
            arg.Equals("--dry-run", StringComparison.OrdinalIgnoreCase) ||
            arg.Equals("--check-takistan-mirror", StringComparison.OrdinalIgnoreCase)))
        {
            int tkResult = MirrorDriftChecker.CheckTakistanMirror();
            int zgResult = MirrorDriftChecker.CheckZargabadMirror();
            return tkResult != 0 ? tkResult : zgResult;
        }

        SqfFileGenerator.GenerateCommonBalanceInitAndTheEasaFileForEachTerrain();
        return 0;
    }
}
