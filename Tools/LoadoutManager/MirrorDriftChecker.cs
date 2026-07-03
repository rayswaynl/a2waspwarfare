public static class MirrorDriftChecker
{
    private const string TakistanMissionRelativePath = @"Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan";
    private const string TakistanMissionDirectoryName = "[61-2hc]warfarev2_073v48co.takistan";
    private const int MaxReportedDifferences = 200;

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
            List<string> guardFailures = CheckTakistanGeneratedTemplateDefines(expectedTakistanPath);
            if (differences.Count == 0 && guardFailures.Count == 0)
            {
                Console.WriteLine("Takistan mirror check passed: no generated drift detected.");
                return 0;
            }

            Console.Error.WriteLine($"Takistan mirror check failed: {differences.Count} difference(s), {guardFailures.Count} guard failure(s) detected.");
            foreach (string guardFailure in guardFailures)
            {
                Console.Error.WriteLine(guardFailure);
            }

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

    private static List<string> CheckTakistanGeneratedTemplateDefines(string _expectedTakistanPath)
    {
        string templatePath = Path.Combine(_expectedTakistanPath, "version.sqf.template");
        List<string> failures = new List<string>();

        if (!File.Exists(templatePath))
        {
            failures.Add("GUARD   version.sqf.template missing from generated Takistan output.");
            return failures;
        }

        string[] lines = File.ReadAllLines(templatePath);
        AddFailureForUncommentedDefine(lines, "IS_CHERNARUS_MAP_DEPENDENT", failures);
        AddFailureForUncommentedDefine(lines, "IS_NAVAL_MAP", failures);

        return failures;
    }

    private static void AddFailureForUncommentedDefine(string[] _lines, string _defineName, List<string> _failures)
    {
        for (int index = 0; index < _lines.Length; index++)
        {
            string line = _lines[index].TrimStart();
            string definePrefix = "#define " + _defineName;
            if (line.Equals(definePrefix, StringComparison.Ordinal) ||
                line.StartsWith(definePrefix + " ", StringComparison.Ordinal) ||
                line.StartsWith(definePrefix + "\t", StringComparison.Ordinal))
            {
                _failures.Add($"GUARD   version.sqf.template:{index + 1} generated Takistan output must not uncomment {_defineName}.");
            }
        }
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
