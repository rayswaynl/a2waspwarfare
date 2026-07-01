using System;
using System.IO;
using System.Diagnostics;

public class ZipManager
{
    public static void DoZipOperations()
    {
        if (ShouldSkipZipOperations())
        {
            Console.WriteLine("Skipping mission packaging because A2WASP_SKIP_ZIP is set.");
            return;
        }

        string a2waspDirectory = FileManager.FindA2WaspWarfareDirectory().FullName;
        string[] missionDirectories = { "Missions", "Missions_Vanilla" }; //, "Modded_Missions"
        string tempDirectory = Path.Combine(a2waspDirectory, "TempZippingDirectory");
        string destinationFile = Path.Combine(a2waspDirectory, "_MISSIONS.7z");
        string tempDestinationFile = destinationFile + ".tmp";

        string? sevenZipPath = ResolveSevenZip();
        if (sevenZipPath == null)
        {
            Console.WriteLine("[ZipManager] 7-Zip not found (checked the 7za env var, the standard "
                + "C:\\Program Files\\7-Zip install location, and PATH). Skipping the _MISSIONS.7z packing step. "
                + "Install 7-Zip, or set the 7za environment variable to a 7z/7za executable, to enable "
                + "easy-deploy packing. The mission mirror itself completed normally.");
            return;
        }
        Console.WriteLine($"[ZipManager] Using 7-Zip at: {sevenZipPath}");

        try
        {
            if (File.Exists(tempDestinationFile))
            {
                File.Delete(tempDestinationFile);
                Console.WriteLine($"Deleted existing temp file: {tempDestinationFile}");
            }

            CreateDirectory(tempDirectory);

            foreach (var missionDirectory in missionDirectories)
            {
                string sourceDirectory = Path.Combine(a2waspDirectory, missionDirectory);
                CopyFilesFromSourceToDestinationWithoutModdedTerrainsParam(sourceDirectory, tempDirectory);
            }

            Create7zFromDirectory(sevenZipPath, tempDirectory, tempDestinationFile);

            if (File.Exists(destinationFile))
            {
                File.Delete(destinationFile);
                Console.WriteLine($"Deleted existing file: {destinationFile}");
            }

            File.Move(tempDestinationFile, destinationFile);
            Console.WriteLine($"Created 7z file: {destinationFile}");
        }
        finally
        {
            if (Directory.Exists(tempDirectory))
            {
                DeleteDirectory(tempDirectory);
            }

            if (File.Exists(tempDestinationFile))
            {
                File.Delete(tempDestinationFile);
                Console.WriteLine($"Deleted temp file: {tempDestinationFile}");
            }
        }
    }

    private static bool ShouldSkipZipOperations()
    {
        string skipZip = Environment.GetEnvironmentVariable("A2WASP_SKIP_ZIP");
        if (string.IsNullOrWhiteSpace(skipZip))
        {
            return false;
        }

        return skipZip == "1" ||
               skipZip.Equals("true", StringComparison.OrdinalIgnoreCase) ||
               skipZip.Equals("yes", StringComparison.OrdinalIgnoreCase);
    }

    // Locate a 7-Zip executable, in priority order:
    //   1) the explicit 7za environment variable (back-compat with the documented mechanism),
    //   2) the standard Windows install locations (7z.exe handles "a -t7z" identically to standalone 7za.exe),
    //   3) any 7z/7za on PATH.
    // Returns null when none is found; the caller then skips packing rather than treating it as fatal.
    private static string? ResolveSevenZip()
    {
        // 1) Explicit override.
        string? env = Environment.GetEnvironmentVariable("7za");
        if (!string.IsNullOrWhiteSpace(env))
        {
            if (File.Exists(env))
            {
                return env;
            }

            throw new FileNotFoundException("7za environment variable points to a missing executable.", env);
        }

        // 2) Standard 7-Zip install locations.
        string[] candidates =
        {
            @"C:\Program Files\7-Zip\7z.exe",
            @"C:\Program Files\7-Zip\7za.exe",
            @"C:\Program Files (x86)\7-Zip\7z.exe",
            @"C:\Program Files (x86)\7-Zip\7za.exe",
        };
        foreach (var candidate in candidates)
        {
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        // 3) Anything named 7z/7za on PATH.
        string pathVar = Environment.GetEnvironmentVariable("PATH") ?? "";
        foreach (var dir in pathVar.Split(Path.PathSeparator))
        {
            if (string.IsNullOrWhiteSpace(dir))
            {
                continue;
            }
            foreach (var exe in new[] { "7z.exe", "7za.exe" })
            {
                try
                {
                    string full = Path.Combine(dir.Trim(), exe);
                    if (File.Exists(full))
                    {
                        return full;
                    }
                }
                catch
                {
                    // Ignore malformed PATH entries.
                }
            }
        }

        return null;
    }

    // This method creates a new directory if it doesn't exist
    private static void CreateDirectory(string _directoryPath)
    {
        try
        {
            if (!Directory.Exists(_directoryPath))
            {
                Directory.CreateDirectory(_directoryPath);
                Console.WriteLine($"Created directory: {_directoryPath}");
            }
        }
        catch (IOException)
        {
            if (!Directory.Exists(_directoryPath))
            {
                return;
            }
        }
    }

    // This method deletes a directory
    private static void DeleteDirectory(string _directoryPath)
    {
        Directory.Delete(_directoryPath, true);
        Console.WriteLine($"Deleted directory: {_directoryPath}");
    }

    // This method creates a 7z file from a directory using the resolved 7-Zip executable.
    private static void Create7zFromDirectory(string _sevenZipPath, string _sourceDirectory, string _destinationFile)
    {
        ProcessStartInfo p = new ProcessStartInfo();
        p.FileName = _sevenZipPath;
        p.Arguments = $"a -t7z \"{_destinationFile}\" \"{_sourceDirectory}\\*\" -mx=9";
        p.WindowStyle = ProcessWindowStyle.Hidden;
        p.UseShellExecute = false;
        p.CreateNoWindow = true;
        Process? x = Process.Start(p);
        if (x == null)
        {
            throw new Exception($"Could not start 7-Zip process ({_sevenZipPath}).");
        }
        x.WaitForExit();
        if (x.ExitCode != 0)
        {
            throw new Exception($"7-Zip failed with exit code {x.ExitCode} while creating {_destinationFile}.");
        }
        else
        {
            Console.WriteLine($"Created 7z file: {_destinationFile}");
        }
    }

    // This method copies directories from one location to another, ignoring symlinks
    private static void CopyDirectories(string _sourceDirectory, string _destinationDirectory)
    {
        foreach (var directory in Directory.GetDirectories(_sourceDirectory))
        {
            var pathName = Path.GetFileName(directory);

            if (pathName.Contains("PromptLibrary"))
            {
                continue;
            }

            string destinationDirectory = Path.Combine(_destinationDirectory, pathName);

            // Create the directory if it doesn't exist
            if (!Directory.Exists(destinationDirectory))
            {
                Directory.CreateDirectory(destinationDirectory);
            }
            Console.WriteLine($"Copied directory: {directory} to {_destinationDirectory}");
        }
    }

    public static void CopyFilesFromSourceToDestinationWithoutModdedTerrainsParam(string _source, string _destination)
    {
        FileManager.EnsureDirectoryExists(_destination);
        CopyFilesWithoutModdedTerrainsParam(_source, _destination);
        RecursivelyCopySubdirectoriesWithoutModdedTerrainsParam(_source, _destination);
    }

    private static void RecursivelyCopySubdirectoriesWithoutModdedTerrainsParam(string _source, string _destination)
    {
        List<string> blacklistedDirectories = new List<string>
        {
            "PromptLibrary"
        };

        foreach (var directory in Directory.GetDirectories(_source))
        {
            string directoryName = Path.GetFileName(directory);
            bool shouldSkipDirectory = blacklistedDirectories.Any(blacklist => directory.EndsWith(blacklist));

            // Check if directoryName ends with any string in blacklistedDirectories
            if (shouldSkipDirectory)
            {
                continue; // Exit the method if the directory is blacklisted
            }

            if (directoryName == null) continue;

            string destinationDirectory = Path.Combine(_destination, directoryName);
            CopyFilesFromSourceToDestinationWithoutModdedTerrainsParam(directory, destinationDirectory);
        }
    }

    private static void CopyFilesWithoutModdedTerrainsParam(string _source, string _destination)
    {
        foreach (var file in Directory.GetFiles(_source))
        {
            string fileName = Path.GetFileName(file);
            string destFile = Path.Combine(_destination, fileName);
            try
            {
                using (FileStream sourceStream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read))
                using (FileStream destStream = new FileStream(destFile, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    sourceStream.CopyTo(destStream);
                }
            }
            catch (IOException ex)
            {
                Console.WriteLine($"Error copying file: {ex.Message}");
            }
        }
    }
}
