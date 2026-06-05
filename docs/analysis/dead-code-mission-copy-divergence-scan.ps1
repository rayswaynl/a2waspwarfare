$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$outputPath = Join-Path $repoRoot "docs\analysis\dead-code-mission-copy-divergence-scan.json"
$rootFolders = @("Missions", "Missions_Vanilla", "Modded_Missions")
$textExtensions = @(".sqf", ".fsm", ".hpp", ".ext", ".cpp", ".h", ".xml", ".sqm", ".rvmat", ".bisurf")

function Get-RelativePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($repoRoot, $Path)
}

function Get-MissionRoots {
    $roots = New-Object System.Collections.Generic.List[object]
    foreach ($folder in $rootFolders) {
        $full = Join-Path $repoRoot $folder
        if (-not (Test-Path -LiteralPath $full)) { continue }
        Get-ChildItem -LiteralPath $full -Directory | ForEach-Object {
            $roots.Add([pscustomobject]@{
                folder = $folder
                name = $_.Name
                label = "$folder/$($_.Name)"
                path = $_.FullName
            }) | Out-Null
        }
    }
    return $roots
}

function Get-MissionRelativePath {
    param(
        [string]$MissionRootPath,
        [string]$FilePath
    )
    return [System.IO.Path]::GetRelativePath($MissionRootPath, $FilePath)
}

function Get-ConflictMarkerCount {
    param([string]$Path)
    $count = 0
    Get-Content -LiteralPath $Path -ErrorAction Stop | ForEach-Object {
        if ($_ -match '^\s*(<{7,}|={7,}|>{7,})') { $count++ }
    }
    return $count
}

function Get-PathFamily {
    param([string]$RelativePath)

    if ($RelativePath -match '^[^\\/]+$') { return "mission-root-file" }
    if ($RelativePath -match '^[Rr]sc[\\/]') { return "ui-rsc" }
    if ($RelativePath -match '^[Cc]lient[\\/]') { return "client-runtime" }
    if ($RelativePath -match '^[Ss]erver[\\/]') { return "server-runtime" }
    if ($RelativePath -match '^[Cc]ommon[\\/]Config[\\/]') { return "common-config" }
    if ($RelativePath -match '^[Cc]ommon[\\/]Init[\\/]') { return "common-init" }
    if ($RelativePath -match '^[Cc]ommon[\\/]Module[\\/]') { return "common-module" }
    if ($RelativePath -match '^[Cc]ommon[\\/]Functions[\\/]') { return "common-functions" }
    if ($RelativePath -match '^[Cc]ommon[\\/]') { return "common-other" }
    if ($RelativePath -match '^[Ww][Aa][Ss][Pp][\\/]') { return "wasp" }
    if ($RelativePath -match '^[Aa]rty_and_[Ll]og[\\/]') { return "arty-and-log" }
    return "other"
}

$missionRoots = @(Get-MissionRoots)
$files = New-Object System.Collections.Generic.List[object]

foreach ($root in $missionRoots) {
    Get-ChildItem -LiteralPath $root.path -Recurse -File | Where-Object {
        $textExtensions -contains $_.Extension
    } | ForEach-Object {
        $missionRelative = Get-MissionRelativePath -MissionRootPath $root.path -FilePath $_.FullName
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName
        $lineCount = (Get-Content -LiteralPath $_.FullName -ErrorAction Stop | Measure-Object -Line).Lines
        $conflictCount = Get-ConflictMarkerCount -Path $_.FullName

        $files.Add([pscustomobject]@{
            rootFolder = $root.folder
            missionRoot = $root.label
            missionName = $root.name
            path = Get-RelativePath -Path $_.FullName
            missionRelative = $missionRelative
            extension = $_.Extension.ToLowerInvariant()
            family = Get-PathFamily -RelativePath $missionRelative
            hash = $hash.Hash
            length = $_.Length
            lineCount = $lineCount
            conflictMarkerCount = $conflictCount
        }) | Out-Null
    }
}

$allRootLabels = @($missionRoots | ForEach-Object { $_.label })
$groups = $files | Group-Object -Property missionRelative

$pathGroups = foreach ($group in $groups) {
    $entries = @($group.Group)
    $hashes = @($entries | Select-Object -ExpandProperty hash -Unique)
    $rootsPresent = @($entries | Select-Object -ExpandProperty missionRoot -Unique)
    $rootFoldersPresent = @($entries | Select-Object -ExpandProperty rootFolder -Unique)
    $missingRoots = @($allRootLabels | Where-Object { $_ -notin $rootsPresent })
    $conflictCount = ($entries | Measure-Object -Property conflictMarkerCount -Sum).Sum

    [pscustomobject]@{
        missionRelative = $group.Name
        family = Get-PathFamily -RelativePath $group.Name
        rootCount = $rootsPresent.Count
        rootFolders = $rootFoldersPresent
        hashCount = $hashes.Count
        status = if ($hashes.Count -gt 1) { "diverged" } elseif ($rootsPresent.Count -gt 1) { "identical-copy" } else { "single-root-only" }
        conflictMarkerCount = [int]$conflictCount
        rootsPresent = $rootsPresent
        missingRootCount = $missingRoots.Count
        missingRoots = $missingRoots
        variants = @(
            $entries | Sort-Object missionRoot | ForEach-Object {
                [pscustomobject]@{
                    missionRoot = $_.missionRoot
                    rootFolder = $_.rootFolder
                    path = $_.path
                    hash = $_.hash
                    lineCount = $_.lineCount
                    length = $_.length
                    conflictMarkerCount = $_.conflictMarkerCount
                }
            }
        )
    }
}

$sourceLabel = "Missions/[55-2hc]warfarev2_073v48co.chernarus"
$vanillaLabel = "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"

$sourceVanillaPairs = foreach ($group in $pathGroups) {
    $sourceVariant = @($group.variants | Where-Object { $_.missionRoot -eq $sourceLabel }) | Select-Object -First 1
    $vanillaVariant = @($group.variants | Where-Object { $_.missionRoot -eq $vanillaLabel }) | Select-Object -First 1
    if ($sourceVariant -and $vanillaVariant) {
        [pscustomobject]@{
            missionRelative = $group.missionRelative
            family = $group.family
            status = if ($sourceVariant.hash -eq $vanillaVariant.hash) { "identical" } else { "diverged" }
            sourcePath = $sourceVariant.path
            vanillaPath = $vanillaVariant.path
            sourceLines = $sourceVariant.lineCount
            vanillaLines = $vanillaVariant.lineCount
            sourceHash = $sourceVariant.hash
            vanillaHash = $vanillaVariant.hash
            conflictMarkerCount = $sourceVariant.conflictMarkerCount + $vanillaVariant.conflictMarkerCount
        }
    }
}

$summaryByFamily = $pathGroups | Group-Object -Property family | ForEach-Object {
    [pscustomobject]@{
        family = $_.Name
        pathCount = $_.Count
        diverged = @($_.Group | Where-Object { $_.status -eq "diverged" }).Count
        identicalCopy = @($_.Group | Where-Object { $_.status -eq "identical-copy" }).Count
        singleRootOnly = @($_.Group | Where-Object { $_.status -eq "single-root-only" }).Count
        conflictMarkerGroups = @($_.Group | Where-Object { $_.conflictMarkerCount -gt 0 }).Count
    }
} | Sort-Object family

$result = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("o")
    rootFolders = $rootFolders
    missionRootCount = $missionRoots.Count
    missionRoots = $missionRoots | Select-Object folder, name, label
    scannedTextFiles = $files.Count
    uniqueMissionRelativePaths = @($pathGroups).Count
    divergedPathCount = @($pathGroups | Where-Object { $_.status -eq "diverged" }).Count
    identicalCopyPathCount = @($pathGroups | Where-Object { $_.status -eq "identical-copy" }).Count
    singleRootOnlyPathCount = @($pathGroups | Where-Object { $_.status -eq "single-root-only" }).Count
    conflictMarkerFileCount = @($files | Where-Object { $_.conflictMarkerCount -gt 0 }).Count
    conflictMarkerPathCount = @($pathGroups | Where-Object { $_.conflictMarkerCount -gt 0 }).Count
    sourceVanillaComparedPathCount = @($sourceVanillaPairs).Count
    sourceVanillaDivergedPathCount = @($sourceVanillaPairs | Where-Object { $_.status -eq "diverged" }).Count
    sourceVanillaIdenticalPathCount = @($sourceVanillaPairs | Where-Object { $_.status -eq "identical" }).Count
    summaryByFamily = $summaryByFamily
    sourceVanillaDivergences = @($sourceVanillaPairs | Where-Object { $_.status -eq "diverged" } | Sort-Object family, missionRelative)
    conflictMarkerFiles = @($files | Where-Object { $_.conflictMarkerCount -gt 0 } | Sort-Object missionRoot, missionRelative)
    highFanoutDivergences = @($pathGroups | Where-Object { $_.status -eq "diverged" -and $_.rootCount -ge 4 } | Sort-Object family, missionRelative)
    pathGroups = @($pathGroups | Sort-Object family, missionRelative)
}

$outDir = Split-Path -Parent $outputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputPath -Encoding UTF8
$result
