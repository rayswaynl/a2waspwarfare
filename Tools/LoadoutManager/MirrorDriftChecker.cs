public static class MirrorDriftChecker
{
    private const string TakistanMissionRelativePath = @"Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan";
    private const string TakistanMissionDirectoryName = "[61-2hc]warfarev2_073v48co.takistan";
    private const string ZargabadMissionRelativePath = @"Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad";
    private const string ZargabadMissionDirectoryName = "[61-2hc]warfarev2_073v48co.zargabad";
    private const int MaxReportedDifferences = 200;
    private static readonly string[] TakistanVersionGuardRelativePaths =
    {
        "version.sqf.template",
        "version.sqf"
    };

    private static readonly string[] TakistanForbiddenUncommentedDefines =
    {
        "IS_CHERNARUS_MAP_DEPENDENT",
        "IS_NAVAL_MAP"
    };

    public static int CheckTakistanMirror()
    {
        string repoRoot = FileManager.FindA2WaspWarfareDirectory().FullName;
        string actualTakistanPath = Path.Combine(repoRoot, TakistanMissionRelativePath);

        if (!Directory.Exists(actualTakistanPath))
        {
            Console.Error.WriteLine($"Takistan mission directory not found: {actualTakistanPath}");
            return 2;
        }

        string tempRoot = Path.Combine(Path.GetTempPath(), "a2wasp-loadoutmanager-check-" + Guid.NewGuid().ToString("N"));
        string expectedTakistanPath = Path.Combine(tempRoot, TakistanMissionDirectoryName);

        try
        {
            CopyDirectoryExact(actualTakistanPath, expectedTakistanPath);

            GeneratedLoadoutFiles generatedFiles = SqfFileGenerator.BuildGeneratedFileStrings();
            var takistan = new TAKISTAN();
            takistan.WriteAndUpdateTerrainFiles(
                generatedFiles.Easa.vanilla,
                generatedFiles.CommonBalance.vanilla,
                generatedFiles.AircraftDisplayNames.vanilla,
                generatedFiles.AircraftDamageModelChanges.vanilla,
                destinationDirectoryOverride: expectedTakistanPath);

            List<string> differences = CompareDirectories(expectedTakistanPath, actualTakistanPath);
            List<string> versionGuardFindings = FindTakistanVersionGuardFindings(expectedTakistanPath);
            if (differences.Count == 0 && versionGuardFindings.Count == 0)
            {
                Console.WriteLine("Takistan drift: none (mirror check passed).");
                return 0;
            }

            if (differences.Count > 0)
            {
                Console.Error.WriteLine($"Takistan mirror check failed: {differences.Count} difference(s) detected.");
                foreach (string difference in differences.Take(MaxReportedDifferences))
                {
                    Console.Error.WriteLine(difference);
                }

                if (differences.Count > MaxReportedDifferences)
                {
                    Console.Error.WriteLine($"... {differences.Count - MaxReportedDifferences} more difference(s) not shown.");
                }
            }

            if (versionGuardFindings.Count > 0)
            {
                Console.Error.WriteLine($"Takistan version guard failed: {versionGuardFindings.Count} finding(s).");
                foreach (string finding in versionGuardFindings)
                {
                    Console.Error.WriteLine(finding);
                }
            }

            return 1;
        }
        finally
        {
            TryDeleteDirectory(tempRoot);
        }
    }

    public static int CheckZargabadMirror()
    {
        string repoRoot = FileManager.FindA2WaspWarfareDirectory().FullName;
        string actualZargabadPath = Path.Combine(repoRoot, ZargabadMissionRelativePath);

        if (!Directory.Exists(actualZargabadPath))
        {
            Console.Error.WriteLine($"Zargabad mission directory not found: {actualZargabadPath}");
            return 2;
        }

        string tempRoot = Path.Combine(Path.GetTempPath(), "a2wasp-loadoutmanager-check-" + Guid.NewGuid().ToString("N"));
        string expectedZargabadPath = Path.Combine(tempRoot, ZargabadMissionDirectoryName);

        try
        {
            CopyDirectoryExact(actualZargabadPath, expectedZargabadPath);

            GeneratedLoadoutFiles generatedFiles = SqfFileGenerator.BuildGeneratedFileStrings();
            var zargabad = new ZARGABAD();
            zargabad.WriteAndUpdateTerrainFiles(
                generatedFiles.Easa.vanilla,
                generatedFiles.CommonBalance.vanilla,
                generatedFiles.AircraftDisplayNames.vanilla,
                generatedFiles.AircraftDamageModelChanges.vanilla,
                destinationDirectoryOverride: expectedZargabadPath);

            List<string> differences = CompareDirectories(expectedZargabadPath, actualZargabadPath);
            if (differences.Count == 0)
            {
                Console.WriteLine("Zargabad drift: none (mirror check passed).");
                return 0;
            }

            Console.Error.WriteLine($"Zargabad drift: {differences.Count} difference(s) detected.");
            foreach (string difference in differences.Take(MaxReportedDifferences))
            {
                Console.Error.WriteLine(difference);
            }

            if (differences.Count > MaxReportedDifferences)
            {
                Console.Error.WriteLine($"... {differences.Count - MaxReportedDifferences} more difference(s) not shown.");
            }

            return 1;
        }
        finally
        {
            TryDeleteDirectory(tempRoot);
        }
    }

    private static void CopyDirectoryExact(string _sourceDirectory, string _destinationDirectory)
    {
        Directory.CreateDirectory(_destinationDirectory);

        foreach (string directory in Directory.EnumerateDirectories(_sourceDirectory, "*", SearchOption.AllDirectories))
        {
            string relativeDirectory = Path.GetRelativePath(_sourceDirectory, directory);
            Directory.CreateDirectory(Path.Combine(_destinationDirectory, relativeDirectory));
        }

        foreach (string file in Directory.EnumerateFiles(_sourceDirectory, "*", SearchOption.AllDirectories))
        {
            string relativeFile = Path.GetRelativePath(_sourceDirectory, file);
            string destinationFile = Path.Combine(_destinationDirectory, relativeFile);
            string? destinationParent = Path.GetDirectoryName(destinationFile);
            if (destinationParent != null)
            {
                Directory.CreateDirectory(destinationParent);
            }

            File.Copy(file, destinationFile, overwrite: true);
        }
    }

    private static List<string> CompareDirectories(string _expectedDirectory, string _actualDirectory)
    {
        Dictionary<string, string> expectedFiles = EnumerateComparableFiles(_expectedDirectory);
        Dictionary<string, string> actualFiles = EnumerateComparableFiles(_actualDirectory);
        List<string> differences = new List<string>();

        foreach (string relativePath in expectedFiles.Keys.Union(actualFiles.Keys).OrderBy(_path => _path, StringComparer.OrdinalIgnoreCase))
        {
            bool expectedExists = expectedFiles.TryGetValue(relativePath, out string? expectedFile);
            bool actualExists = actualFiles.TryGetValue(relativePath, out string? actualFile);

            if (!expectedExists)
            {
                differences.Add($"EXTRA   {relativePath}");
                continue;
            }

            if (!actualExists)
            {
                differences.Add($"MISSING {relativePath}");
                continue;
            }

            if (!File.ReadAllBytes(expectedFile!).SequenceEqual(File.ReadAllBytes(actualFile!)))
            {
                differences.Add($"DIFF    {relativePath}");
            }
        }

        return differences;
    }

    private static Dictionary<string, string> EnumerateComparableFiles(string _directory)
    {
        Dictionary<string, string> files = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (string file in Directory.EnumerateFiles(_directory, "*", SearchOption.AllDirectories))
        {
            string relativePath = Path.GetRelativePath(_directory, file).Replace('\\', '/');
            if (ShouldIgnoreRelativePath(relativePath))
            {
                continue;
            }

            files[relativePath] = file;
        }

        return files;
    }

    private static bool ShouldIgnoreRelativePath(string _relativePath)
    {
        return _relativePath.Equals("version.sqf", StringComparison.OrdinalIgnoreCase);
    }

    private static List<string> FindTakistanVersionGuardFindings(string _expectedTakistanPath)
    {
        List<string> findings = new List<string>();

        foreach (string relativePath in TakistanVersionGuardRelativePaths)
        {
            string versionPath = Path.Combine(_expectedTakistanPath, relativePath);
            if (!File.Exists(versionPath))
            {
                findings.Add($"MISSING {relativePath}");
                continue;
            }

            int lineNumber = 0;
            foreach (string line in File.ReadLines(versionPath))
            {
                lineNumber++;
                string? defineName = ReadUncommentedDefineName(line);
                if (defineName == null)
                {
                    continue;
                }

                if (TakistanForbiddenUncommentedDefines.Contains(defineName, StringComparer.Ordinal))
                {
                    findings.Add($"{relativePath}:{lineNumber} active {defineName}");
                }
            }
        }

        return findings;
    }

    private static string? ReadUncommentedDefineName(string _line)
    {
        const string defineKeyword = "#define";
        string trimmedLine = _line.TrimStart();

        if (!trimmedLine.StartsWith(defineKeyword, StringComparison.Ordinal))
        {
            return null;
        }

        string rest = trimmedLine.Substring(defineKeyword.Length);
        if (rest.Length == 0 || !char.IsWhiteSpace(rest[0]))
        {
            return null;
        }

        string[] defineParts = rest.TrimStart().Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
        return defineParts.Length == 0 ? null : defineParts[0];
    }

    private static void TryDeleteDirectory(string _directory)
    {
        try
        {
            if (Directory.Exists(_directory))
            {
                Directory.Delete(_directory, recursive: true);
            }
        }
        catch
        {
            Console.Error.WriteLine($"Warning: could not delete temporary mirror check directory: {_directory}");
        }
    }
}
