$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$missionRoots = @(
    "Missions",
    "Missions_Vanilla",
    "Modded_Missions"
)
$textExtensions = @(".sqf", ".fsm", ".hpp", ".ext", ".cpp", ".h", ".xml")

function Get-RelativePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($repoRoot, $Path)
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

$files = foreach ($root in $missionRoots) {
    $fullRoot = Join-Path $repoRoot $root
    if (Test-Path $fullRoot) {
        Get-ChildItem -LiteralPath $fullRoot -Recurse -File |
            Where-Object { $textExtensions -contains $_.Extension.ToLowerInvariant() }
    }
}

$records = [System.Collections.Generic.List[object]]::new()
$paramClassRegex = '^\s*class\s+(WFBE_[A-Za-z0-9_]+)\b'
$wfbeTokenRegex = '\b(WFBE_[A-Za-z0-9_]+)\b'

foreach ($file in $files) {
    $relative = Get-RelativePath -Path $file.FullName
    if ($relative -notmatch '[\\/]Rsc[\\/]Parameters\.hpp$') {
        continue
    }

    $lines = @(Get-Content -LiteralPath $file.FullName)
    $inBlockComment = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $commentState = Get-CommentState -Line $line -InBlockComment $inBlockComment
        $lineNumber = $i + 1

        if ($line -match $paramClassRegex) {
            Add-Record -List $records -Kind "parameter-class" -Name $Matches[1] -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentState.CommentOnly
        }

        $inBlockComment = $commentState.NextInBlock
    }
}

$activeParameterNames = @(
    $records |
        Where-Object { $_.kind -eq "parameter-class" -and -not $_.commentOnly } |
        Select-Object -ExpandProperty name -Unique |
        Sort-Object
)
$parameterSet = @{}
foreach ($name in $activeParameterNames) {
    $parameterSet[$name] = $true
}

foreach ($file in $files) {
    $relative = Get-RelativePath -Path $file.FullName
    $isParameterFile = $relative -match '[\\/]Rsc[\\/]Parameters\.hpp$'
    $lines = @(Get-Content -LiteralPath $file.FullName)
    $inBlockComment = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $commentState = Get-CommentState -Line $line -InBlockComment $inBlockComment
        $lineNumber = $i + 1

        foreach ($match in [regex]::Matches($line, $wfbeTokenRegex)) {
            $name = $match.Groups[1].Value
            if (-not $parameterSet.ContainsKey($name)) {
                continue
            }

            $context = "token-reference"
            if ($isParameterFile) {
                $context = "parameter-file"
            } elseif ($line -match "missionNamespace\s+getVariable\s+(\[\s*)?[""']$([regex]::Escape($name))[""']") {
                $context = "namespace-read"
            } elseif ($line -match "missionNamespace\s+setVariable\s+\[\s*[""']$([regex]::Escape($name))[""']") {
                $context = "namespace-set"
            } elseif ($line -match "isNil\s+[""']$([regex]::Escape($name))[""']") {
                $context = "nil-default"
            } elseif ($line -match "\b$([regex]::Escape($name))\b\s*=") {
                $context = "direct-assignment"
            }

            Add-Record -List $records -Kind "parameter-reference" -Name $name -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentState.CommentOnly -Extra @{
                context = $context
            }
        }

        $inBlockComment = $commentState.NextInBlock
    }
}

$activeRecords = $records | Where-Object { -not $_.commentOnly }
$activeReferences = $activeRecords | Where-Object { $_.kind -eq "parameter-reference" }
$runtimeReferences = $activeReferences | Where-Object {
    $_.context -notin @("parameter-file", "nil-default") -and
    $_.source -notmatch '[\\/]Common[\\/]Init[\\/]Init_Parameters\.sqf$' -and
    $_.source -notmatch '[\\/]Client[\\/]GUI[\\/]GUI_Display_Parameters\.sqf$'
}

$parameters = foreach ($name in $activeParameterNames) {
    $declarations = @($activeRecords | Where-Object { $_.kind -eq "parameter-class" -and $_.name -eq $name })
    $refs = @($activeReferences | Where-Object { $_.name -eq $name })
    $runtime = @($runtimeReferences | Where-Object { $_.name -eq $name })
    $sets = @($runtime | Where-Object { $_.context -in @("namespace-set", "direct-assignment") })
    $reads = @($runtime | Where-Object { $_.context -eq "namespace-read" -or ($_.context -eq "token-reference" -and $_.source -notmatch '[\\/]Rsc[\\/]Parameters\.hpp$') })

    [pscustomobject]@{
        name = $name
        declarations = $declarations
        totalReferenceCount = $refs.Count
        runtimeReferenceCount = $runtime.Count
        runtimeReadLikeCount = $reads.Count
        runtimeSetLikeCount = $sets.Count
        runtimeReferences = $runtime
    }
}

$noRuntimeReference = @($parameters | Where-Object { $_.runtimeReferenceCount -eq 0 })
$noRuntimeReadLike = @($parameters | Where-Object { $_.runtimeReadLikeCount -eq 0 })
$forcedOverrides = @($parameters | Where-Object { $_.runtimeSetLikeCount -gt 0 })

$output = [ordered]@{
    generatedAt = (Get-Date).ToString("o")
    scannedFiles = @($files).Count
    roots = $missionRoots
    activeParameterClassCount = $activeParameterNames.Count
    totalRecords = $records.Count
    activeRecords = @($activeRecords).Count
    commentOnlyRecords = @($records | Where-Object { $_.commentOnly }).Count
    parametersWithoutRuntimeReferences = @($noRuntimeReference)
    parametersWithoutRuntimeReadLikeReferences = @($noRuntimeReadLike)
    parametersWithRuntimeSetLikeOverrides = @($forcedOverrides)
    parameters = @($parameters)
    records = @($records)
}

$outPath = Join-Path $PSScriptRoot "dead-code-parameter-scan.json"
$output | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outPath -Encoding UTF8

[pscustomobject]$output
