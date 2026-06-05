param(
    [string[]]$Roots = @("Missions", "Missions_Vanilla", "Modded_Missions"),
    [string]$OutputPath = "docs/analysis/dead-code-ui-rsc-scan.json"
)

$ErrorActionPreference = "Stop"

function Get-RelativeLiteralPath {
    param([string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $base = (Get-Location).Path
    if ($resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        return $resolved.Substring($base.Length + 1)
    }

    return $resolved
}

function Get-MissionRootLabel {
    param([string]$RelativePath)

    $parts = $RelativePath -split '[\\/]'
    for ($i = 0; $i -lt $parts.Length; $i++) {
        if ($parts[$i] -in @("Missions", "Missions_Vanilla", "Modded_Missions")) {
            if ($i + 1 -lt $parts.Length) {
                return "$($parts[$i])/$($parts[$i + 1])"
            }
        }
    }

    return "unknown"
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

    $relative = Get-RelativeLiteralPath -Path $File.FullName
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

    $List.Add([PSCustomObject]$record)
}

$sourceExtensions = @(".sqf", ".fsm", ".hpp", ".ext", ".cpp")
$uiExtensions = @(".hpp", ".ext", ".cpp")

$files = foreach ($root in $Roots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Recurse -File | Where-Object { $sourceExtensions -contains $_.Extension.ToLowerInvariant() }
    }
}

$records = [System.Collections.Generic.List[object]]::new()

$classRegex = '^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)\b'
$dialogCallRegex = '\b(createDialog|createDialogLocal)\s+["'']([^"'']+)["'']'
$ctrlIdCommandRegex = '\b(ctrlSetText|ctrlEnable|ctrlShow|ctrlSetTooltip|ctrlSetStructuredText|ctrlSetTextColor|ctrlSetBackgroundColor|ctrlSetEventHandler|buttonSetAction|lbClear|lbAdd|lbSetData|lbSetValue|lbSetCurSel|lbSetColor|lbSetPicture|sliderSetRange|sliderSetPosition|ctrlCommit|ctrlSetPosition)\s*\[?\s*([0-9]{3,6})\b'
$displayCtrlRegex = '\bdisplayCtrl\s+([0-9]{3,6})\b'
$controlGetRegex = '\b(controlNull|ctrlText|lbCurSel|lbText|lbData|lbValue|ctrlShown|ctrlEnabled|sliderPosition)\s+([0-9]{3,6})\b'
$idcRegex = '\bidc\s*=\s*([0-9]{3,6})\s*;'
$iddRegex = '\bidd\s*=\s*([0-9]{3,6})\s*;'
$handlerScriptRegex = '\b(onLoad|onUnload)\b.*?(Client\\GUI\\[A-Za-z0-9_\\.-]+?\.sqf)'

foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file.FullName)
    $isUiFile = $uiExtensions -contains $file.Extension.ToLowerInvariant()
    $inBlockComment = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNumber = $i + 1
        $trimmed = $line.TrimStart()
        $commentOnly = $inBlockComment -or $trimmed.StartsWith("//") -or $trimmed.StartsWith("*")

        if ($isUiFile -and $line -match $classRegex) {
            Add-Record -List $records -Kind "class" -Name $Matches[1] -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentOnly
        }

        if ($line -match $dialogCallRegex) {
            Add-Record -List $records -Kind "dialog-call" -Name $Matches[2] -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentOnly -Extra @{ function = $Matches[1] }
        }

        if ($isUiFile -and $line -match $idcRegex) {
            Add-Record -List $records -Kind "idc-declaration" -Name $Matches[1] -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentOnly
        }

        if ($isUiFile -and $line -match $iddRegex) {
            Add-Record -List $records -Kind "idd-declaration" -Name $Matches[1] -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentOnly
        }

        if ($line -match $handlerScriptRegex) {
            Add-Record -List $records -Kind "handler-script-reference" -Name $Matches[2] -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentOnly -Extra @{ handler = $Matches[1] }
        }

        foreach ($match in [regex]::Matches($line, $ctrlIdCommandRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            Add-Record -List $records -Kind "idc-use" -Name $match.Groups[2].Value -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentOnly -Extra @{ function = $match.Groups[1].Value }
        }

        foreach ($match in [regex]::Matches($line, $displayCtrlRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            Add-Record -List $records -Kind "idc-use" -Name $match.Groups[1].Value -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentOnly -Extra @{ function = "displayCtrl" }
        }

        foreach ($match in [regex]::Matches($line, $controlGetRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            Add-Record -List $records -Kind "idc-use" -Name $match.Groups[2].Value -File $file -LineNumber $lineNumber -Line $line -CommentOnly $commentOnly -Extra @{ function = $match.Groups[1].Value }
        }

        if ($trimmed -match '/\*' -and $trimmed -notmatch '\*/') {
            $inBlockComment = $true
        }
        if ($inBlockComment -and $trimmed -match '\*/') {
            $inBlockComment = $false
        }
    }
}

$activeRecords = $records | Where-Object { -not $_.commentOnly }
$commentOnlyRecords = $records | Where-Object { $_.commentOnly }

$dialogClasses = $activeRecords | Where-Object { $_.kind -eq "class" -and $_.name -like "RscMenu_*" } | Group-Object name | Sort-Object Name
$dialogCalls = $activeRecords | Where-Object { $_.kind -eq "dialog-call" } | Group-Object name | Sort-Object Name
$handlerRefs = $activeRecords | Where-Object { $_.kind -eq "handler-script-reference" } | Group-Object name | Sort-Object Name
$idcDeclarations = $activeRecords | Where-Object { $_.kind -eq "idc-declaration" } | Group-Object name | Sort-Object Name
$idcUses = $activeRecords | Where-Object { $_.kind -eq "idc-use" } | Group-Object name | Sort-Object Name
$iddDeclarations = $activeRecords | Where-Object { $_.kind -eq "idd-declaration" } | Group-Object name | Sort-Object Name

$calledDialogNames = @{}
foreach ($group in $dialogCalls) { $calledDialogNames[$group.Name] = $true }

$declaredIdcs = @{}
foreach ($group in $idcDeclarations) { $declaredIdcs[$group.Name] = $true }

$usedIdcs = @{}
foreach ($group in $idcUses) { $usedIdcs[$group.Name] = $true }

$handlerMissing = foreach ($group in $handlerRefs) {
    $first = $group.Group | Select-Object -First 1
    $root = $first.missionRoot
    $candidate = Join-Path $root ($group.Name -replace '\\', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $candidate)) {
        [PSCustomObject]@{
            script = $group.Name
            references = $group.Group
        }
    }
}

$unusedDialogs = foreach ($group in $dialogClasses) {
    if (-not $calledDialogNames.ContainsKey($group.Name)) {
        [PSCustomObject]@{
            class = $group.Name
            declarations = $group.Group
        }
    }
}

$usedUndeclaredIdcs = foreach ($group in $idcUses) {
    if (-not $declaredIdcs.ContainsKey($group.Name)) {
        [PSCustomObject]@{
            idc = $group.Name
            uses = $group.Group
        }
    }
}

$declaredUnusedIdcs = foreach ($group in $idcDeclarations) {
    if (-not $usedIdcs.ContainsKey($group.Name)) {
        [PSCustomObject]@{
            idc = $group.Name
            declarations = $group.Group
        }
    }
}

$duplicateIdds = foreach ($group in $iddDeclarations) {
    $classSources = $group.Group | ForEach-Object {
        $lines = @(Get-Content -LiteralPath $_.source)
        $className = $null
        for ($i = [Math]::Max(0, $_.line - 30); $i -lt $_.line; $i++) {
            if ($lines[$i] -match $classRegex) { $className = $Matches[1] }
        }
        [PSCustomObject]@{
            idd = $group.Name
            class = $className
            source = $_.source
            line = $_.line
        }
    }

    $uniqueClasses = @($classSources | Select-Object -ExpandProperty class -Unique)
    if ($uniqueClasses.Count -gt 1) {
        [PSCustomObject]@{
            idd = $group.Name
            classes = $classSources
        }
    }
}

$result = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString("o")
    roots = $Roots
    scannedFiles = @($files).Count
    totalRecords = $records.Count
    activeRecords = @($activeRecords).Count
    commentOnlyRecords = @($commentOnlyRecords).Count
    dialogClassCount = @($dialogClasses).Count
    dialogCallCount = @($dialogCalls).Count
    handlerScriptReferenceCount = @($handlerRefs).Count
    iddDeclarationCount = @($iddDeclarations).Count
    idcDeclarationCount = @($idcDeclarations).Count
    idcUseCount = @($idcUses).Count
    missingHandlerScripts = @($handlerMissing)
    declaredDialogClassesWithoutLiteralCalls = @($unusedDialogs)
    usedIdcsWithoutDeclarations = @($usedUndeclaredIdcs)
    declaredIdcsWithoutDetectedUses = @($declaredUnusedIdcs)
    duplicateIdds = @($duplicateIdds)
    records = @($records)
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$result
