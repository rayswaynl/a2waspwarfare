$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$missionRoots = @(
    "Missions",
    "Missions_Vanilla",
    "Modded_Missions"
)
$textExtensions = @(".sqf", ".fsm", ".hpp", ".ext", ".cpp", ".h", ".xml", ".sqm")

function Get-RelativePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($repoRoot, $Path)
}

function Normalize-PathText {
    param([string]$Path)
    return ($Path -replace '/', '\').TrimStart('\')
}

function Get-MissionRootLabel {
    param([string]$RelativePath)
    $parts = $RelativePath -split '[\\/]'
    if ($parts.Length -ge 2 -and $parts[0] -in @("Missions", "Missions_Vanilla", "Modded_Missions")) {
        return "$($parts[0])/$($parts[1])"
    }
    return $parts[0]
}

function Add-Record {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Kind,
        [string]$Name,
        [System.IO.FileInfo]$File,
        [int]$LineNumber,
        [string]$Line,
        [bool]$CommentOnly = $false,
        [hashtable]$Extra = @{}
    )

    $relative = Get-RelativePath -Path $File.FullName
    $record = [ordered]@{
        kind = $Kind
        name = $Name
        source = $relative
        missionRoot = Get-MissionRootLabel -RelativePath $relative
        line = $LineNumber
        commentOnly = $CommentOnly
        text = $Line.Trim()
    }

    foreach ($key in $Extra.Keys) {
        $record[$key] = $Extra[$key]
    }

    $List.Add([pscustomobject]$record) | Out-Null
}

function Get-CommentState {
    param(
        [string]$Line,
        [bool]$InBlockComment
    )

    $trimmed = $Line.TrimStart()
    $commentOnly = $InBlockComment -or $trimmed.StartsWith("//") -or $trimmed.StartsWith("*")
    $nextInBlock = $InBlockComment

    if ($Line -match '/\*') {
        $beforeBlock = $Line.Substring(0, $Line.IndexOf("/*"))
        if ($beforeBlock.Trim().Length -eq 0) {
            $commentOnly = $true
        }
        $nextInBlock = $true
    }
    if ($Line -match '\*/') {
        $nextInBlock = $false
    }

    return [pscustomobject]@{
        CommentOnly = $commentOnly
        NextInBlock = $nextInBlock
    }
}

function Get-SqfFileRole {
    param([string]$Path)

    if ($Path -match '[\\/]Rsc[\\/]') { return "resource-script-or-data" }
    if ($Path -match '[\\/]Common[\\/]Config[\\/]') { return "config-data" }
    if ($Path -match '[\\/]Tools?[\\/]') { return "tooling" }
    if ($Path -match '[\\/]Functions?[\\/]|[\\/]PVFunctions[\\/]|[\\/]PVFunctions?[\\/]') { return "function-library" }
    if ($Path -match '[\\/]FSM[\\/]') { return "fsm-adjacent-script" }
    if ($Path -match '[\\/]Module[\\/]') { return "module-script" }
    if ($Path -match '[\\/]Init[\\/]') { return "init-script" }
    if ($Path -match '[\\/]Server[\\/]') { return "server-script" }
    if ($Path -match '[\\/]Client[\\/]') { return "client-script" }
    if ($Path -match '[\\/]Common[\\/]') { return "common-script" }
    return "mission-script"
}

$files = foreach ($root in $missionRoots) {
    $fullRoot = Join-Path $repoRoot $root
    if (Test-Path $fullRoot) {
        Get-ChildItem -LiteralPath $fullRoot -Recurse -File |
            Where-Object { $textExtensions -contains $_.Extension.ToLowerInvariant() }
    }
}

$sqfFiles = @(
    $files |
        Where-Object { $_.Extension.ToLowerInvariant() -eq ".sqf" } |
        Sort-Object FullName
)

$sqfByMissionRelative = @{}
foreach ($file in $sqfFiles) {
    $relative = Get-RelativePath -Path $file.FullName
    $parts = $relative -split '[\\/]'
    if ($parts.Length -lt 3) { continue }
    $missionRoot = "$($parts[0])/$($parts[1])"
    $missionRelative = Normalize-PathText -Path (($parts[2..($parts.Length - 1)] -join '\'))
    $key = "$missionRoot|$missionRelative".ToLowerInvariant()
    $sqfByMissionRelative[$key] = [pscustomobject]@{
        fullPath = $relative
        missionRoot = $missionRoot
        missionRelative = $missionRelative
        fileName = [System.IO.Path]::GetFileName($missionRelative)
        stem = [System.IO.Path]::GetFileNameWithoutExtension($missionRelative)
        role = Get-SqfFileRole -Path $relative
    }
}

$records = [System.Collections.Generic.List[object]]::new()
$quotedSqfRegex = '["'']([^"'']+?\.sqf)["'']'
$preprocessRegex = '\b(preprocessFile|preprocessFileLineNumbers|execVM|spawn|exec|loadFile)\b'

foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file.FullName)
    $relative = Get-RelativePath -Path $file.FullName
    $parts = $relative -split '[\\/]'
    $missionRoot = if ($parts.Length -ge 2 -and $parts[0] -in @("Missions", "Missions_Vanilla", "Modded_Missions")) { "$($parts[0])/$($parts[1])" } else { $parts[0] }
    $sourceFolderInMission = if ($parts.Length -ge 4) { $parts[2..($parts.Length - 2)] -join '\' } else { "" }
    $inBlockComment = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNumber = $i + 1
        $commentState = Get-CommentState -Line $line -InBlockComment $inBlockComment

        foreach ($match in [regex]::Matches($line, $quotedSqfRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $rawRef = $match.Groups[1].Value
            $normalizedRef = Normalize-PathText -Path $rawRef
            $candidateKeys = [System.Collections.Generic.List[string]]::new()
            $candidateKeys.Add("$missionRoot|$normalizedRef".ToLowerInvariant()) | Out-Null
            if ($sourceFolderInMission.Length -gt 0 -and $normalizedRef -notmatch '^[A-Za-z]+\\') {
                $candidateKeys.Add("$missionRoot|$(Normalize-PathText -Path (Join-Path $sourceFolderInMission $normalizedRef))".ToLowerInvariant()) | Out-Null
            }

            $target = $null
            foreach ($key in $candidateKeys) {
                if ($sqfByMissionRelative.ContainsKey($key)) {
                    $target = $sqfByMissionRelative[$key]
                    break
                }
            }

            $callHint = if ($line -match $preprocessRegex) { $Matches[1] } else { "quoted-sqf" }
            Add-Record -List $records -Kind "sqf-path-reference" -Name $normalizedRef -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentState.CommentOnly -Extra @{
                callHint = $callHint
                resolved = [bool]$target
                target = if ($target) { $target.fullPath } else { $null }
            }
        }

        $inBlockComment = $commentState.NextInBlock
    }
}

$activeRecords = $records | Where-Object { -not $_.commentOnly }
$commentOnlyRecords = $records | Where-Object { $_.commentOnly }
$activeRefsByTarget = $activeRecords | Where-Object { $_.kind -eq "sqf-path-reference" -and $_.resolved } | Group-Object target -AsHashTable -AsString
$commentRefsByTarget = $commentOnlyRecords | Where-Object { $_.kind -eq "sqf-path-reference" -and $_.resolved } | Group-Object target -AsHashTable -AsString

$unreferenced = foreach ($entry in $sqfByMissionRelative.Values | Sort-Object fullPath) {
    $activeCount = if ($activeRefsByTarget.ContainsKey($entry.fullPath)) { @($activeRefsByTarget[$entry.fullPath]).Count } else { 0 }
    $commentCount = if ($commentRefsByTarget.ContainsKey($entry.fullPath)) { @($commentRefsByTarget[$entry.fullPath]).Count } else { 0 }
    if ($activeCount -eq 0) {
        [pscustomobject]@{
            path = $entry.fullPath
            missionRoot = $entry.missionRoot
            missionRelative = $entry.missionRelative
            role = $entry.role
            commentOnlyReferenceCount = $commentCount
            commentOnlyReferences = if ($commentCount -gt 0) { @($commentRefsByTarget[$entry.fullPath]) } else { @() }
        }
    }
}

$byRole = $unreferenced | Group-Object role | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
        role = $_.Name
        count = $_.Count
    }
}

$output = [ordered]@{
    generatedAt = (Get-Date).ToString("o")
    roots = $missionRoots
    scannedTextFiles = @($files).Count
    sqfFileCount = @($sqfFiles).Count
    sqfPathReferenceCount = @($records).Count
    activeSqfPathReferenceCount = @($activeRecords).Count
    commentOnlySqfPathReferenceCount = @($commentOnlyRecords).Count
    resolvedActiveReferenceCount = @($activeRecords | Where-Object { $_.resolved }).Count
    unreferencedSqfCount = @($unreferenced).Count
    unreferencedByRole = @($byRole)
    unreferencedSqfFiles = @($unreferenced)
    records = @($records)
}

$outPath = Join-Path $PSScriptRoot "dead-code-sqf-reachability-scan.json"
$output | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outPath -Encoding UTF8

[pscustomobject]$output
