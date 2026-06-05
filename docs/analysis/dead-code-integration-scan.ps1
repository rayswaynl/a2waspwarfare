param(
    [string]$OutputPath = "docs/analysis/dead-code-integration-scan.json"
)

$ErrorActionPreference = "Stop"

function Invoke-GitLines {
    param([string[]]$GitArguments)
    $output = & git @GitArguments
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    return @($output)
}

function Select-LineMatches {
    param(
        [string[]]$Paths,
        [string]$Pattern
    )

    $matches = foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) {
            Select-String -Path $path -Pattern $Pattern | ForEach-Object {
                [PSCustomObject]@{
                    path = $_.Path.Substring((Get-Location).Path.Length + 1)
                    line = $_.LineNumber
                    text = $_.Line.Trim()
                }
            }
        }
    }

    @($matches)
}

$trackedIntegrationFiles = Invoke-GitLines -GitArguments @("ls-files", "Tools", "DiscordBot", "Extension", "BattlEyeFilter")
$trackedBuildArtifacts = @($trackedIntegrationFiles | Where-Object {
    $_ -match '(^|/)(bin|obj)/' -or $_ -match '\.(dll|exe|pdb|cache|up2date|props|targets)$'
})

$ignoredBuildDirs = @(
    Get-ChildItem -Path Tools, DiscordBot, Extension -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @("bin", "obj") } |
        ForEach-Object { $_.FullName.Substring((Get-Location).Path.Length + 1) }
)

$battleyeFiles = Invoke-GitLines -GitArguments @("ls-files", "BattlEyeFilter")
$repoServerConfigFiles = Invoke-GitLines -GitArguments @("ls-files") | Where-Object {
    $_ -match '(^|/)(scripts|server|basic|createvehicle|setvariable|setpos|setdamage|deletevehicle|mpeventhandler|publicvariable)\.txt$' -or
    $_ -match '(^|/)(server|basic)\.cfg$'
}

$serializerHits = Select-LineMatches -Paths @(
    "DiscordBot/src/ExtensionData/GameData/GameData.cs",
    "DiscordBot/src/ExtensionData/GameData/GameDataDeSerialization.cs",
    "Extension/src/SerializationManager.cs"
) -Pattern "TypeNameHandling\.(All|Auto|None)"

$discordConfigHits = Select-LineMatches -Paths @(
    "DiscordBot/FileConfiguration.cs",
    "DiscordBot/src/ExtensionData/GameData/GameData.cs",
    "DiscordBot/src/ProgramRuntime.cs",
    "DiscordBot/src/Preferences.cs",
    "DiscordBot/preferences_sample.json"
) -Pattern "DataSourcePath|botconfig\.json|preferences\.json|token\.txt|GuildID|AuthorizedUserIDs"

$toolingHits = Select-LineMatches -Paths @(
    "Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs",
    "Tools/LoadoutManager/ZipManager.cs",
    "Tools/LoadoutManager/Data/Terrains/TerrainName.cs",
    "DiscordBot/src/ExtensionData/GameData/SharedWithLoadoutManager/Terrains/TerrainName.cs",
    "DiscordBot/src/ExtensionData/GameData/SharedWithLoadoutManager/Terrains/BaseTerrain.cs"
) -Pattern "WriteAndUpdateToFilesForModdedTerrains|Modded_Missions|missionDirectories|TASMANIA2010|WriteToFile|TODO: Add the modded maps"

$result = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString("o")
    trackedIntegrationBuildArtifacts = $trackedBuildArtifacts
    ignoredIntegrationBuildDirsPresent = $ignoredBuildDirs
    battleyeFiles = $battleyeFiles
    repoServerConfigOrFilterFiles = @($repoServerConfigFiles)
    serializerHits = $serializerHits
    discordConfigHits = $discordConfigHits
    toolingAndTerrainDriftHits = $toolingHits
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8
$result
