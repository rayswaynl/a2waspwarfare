# LoadoutManager

A tool for managing loadouts and packing missions for the A2WaspWarfare project.

## Prerequisites

- .NET 8.0 SDK
- 7-Zip Command Line version (7za.exe), only when building `_MISSIONS.7z`

## Environment Setup

Before running the tool, set the `7za` environment variable to point to the 7-Zip executable (7za.exe) when you want to pack missions. Without it, LoadoutManager still regenerates and copies mission files, then skips `_MISSIONS.7z`.

### Windows

1. Download 7-Zip Command Line version from [7-Zip website](https://www.7-zip.org/download.html)
2. Extract it to a location of your choice
3. Set the environment variable using PowerShell:

```powershell
$env:7za = "C:\path\to\7za.exe"
```

For permanent setup, you can set it in your system environment variables:
1. Open System Properties (Win+X → System)
2. Click on "Advanced system settings"
3. Click "Environment Variables"
4. Under "User variables", click "New"
5. Variable name: 7za
6. Variable value: Full path to 7za.exe (e.g., C:\Program Files\7-Zip\7za.exe)

## Usage

Run the tool using the dotnet CLI:

```
dotnet run -c <Configuration>
```

Where `<Configuration>` is one of the available build configurations.

## Build Configurations

- **DEBUG**: Developer mode. Not intended for deployment on live servers.
- **SERVER_DEBUG**: Deployable on the server with logging enabled. Use this when monitoring issues on a live server.
- **RELEASE**: Production mode with logging disabled, optimized for runtime performance.
- **AIRWAR_DEBUG**: Debug configuration specific to the Air War module.
- **AIRWAR_SERVER_DEBUG**: Server debug configuration for the Air War module.
- **AIRWAR_RELEASE**: Release configuration for the Air War module.

## Example

```powershell
# Set the 7za environment variable (if not already set)
$env:7za = "C:\Program Files\7-Zip\7za.exe"

# Run with server debug configuration
dotnet run -c SERVER_DEBUG
```

To generate/copy mission files without packing `_MISSIONS.7z`, set:

```powershell
$env:A2WASP_SKIP_ZIP = "1"
dotnet run -c RELEASE
```

To check whether the committed Takistan mirror matches what LoadoutManager would generate,
run:

```powershell
dotnet run -c RELEASE -- --check
```

The check builds the expected Takistan mission in a temporary directory, compares it to
`Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`, ignores the gitignored
`version.sqf`, and exits `1` when drift is detected. Aliases: `--dry-run` and
`--check-takistan-mirror`.

To verify a release archive after packaging, run:

```powershell
powershell -ExecutionPolicy Bypass -File ..\PrTestHarness\Package\Test-WaspReleasePackage.ps1 `
  -ArchivePath ..\..\_MISSIONS.7z `
  -ExpectedCandidate build89-cmdcon44-20260703 `
  -ExpectedGit (git -C ..\.. rev-parse --short=10 HEAD)
```

## Notes

- Setting the 7za environment variable is only necessary if you're packing missions. It's not required if you're only copying files to other missions from Chernarus or when `A2WASP_SKIP_ZIP=1`.
- If `7za` is set but the executable is missing or exits non-zero, packaging fails instead of replacing a known-good archive.
- Make sure to use the appropriate configuration based on your deployment target.
