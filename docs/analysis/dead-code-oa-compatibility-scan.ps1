$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$outputPath = Join-Path $repoRoot "docs\analysis\dead-code-oa-compatibility-scan.json"
$roots = @(
    "Missions",
    "Missions_Vanilla",
    "Modded_Missions",
    "Tools",
    "DiscordBot",
    "Extension",
    "BattlEyeFilter",
    "docs\wiki"
)
$textExtensions = @(".sqf", ".fsm", ".hpp", ".ext", ".cpp", ".h", ".sqm", ".xml", ".json", ".jsonl", ".md", ".txt", ".cs", ".ps1", ".csproj", ".config")

$patterns = @(
    @{ name = "remoteExec"; regex = "\bremoteExec(Call)?\b"; expected = "a3-networking-api" },
    @{ name = "BIS_fnc_MP"; regex = "\bBIS_fnc_MP\b"; expected = "modern-mp-helper" },
    @{ name = "addMissionEventHandler"; regex = "\baddMissionEventHandler\b"; expected = "a3-event-api" },
    @{ name = "isRemoteExecuted"; regex = "\bisRemoteExecuted\b"; expected = "a3-remoteexec-state" },
    @{ name = "remoteExecutedOwner"; regex = "\bremoteExecutedOwner\b"; expected = "a3-remoteexec-state" },
    @{ name = "parseSimpleArray"; regex = "\bparseSimpleArray\b"; expected = "a3-parser-helper" },
    @{ name = "RVExtensionArgs"; regex = "\bRVExtensionArgs\b"; expected = "a3-extension-abi" },
    @{ name = "CfgFunctions"; regex = "\bCfgFunctions\b"; expected = "modern-function-lifecycle" },
    @{ name = "CBA"; regex = "(?-i:\bCBA\b|CBA_fnc)"; expected = "external-dependency" },
    @{ name = "ACE"; regex = "(?-i:\bACE\b|ACE_[A-Za-z0-9_]*|\bace_[A-Za-z0-9_]*\b)"; expected = "external-dependency" },
    @{ name = "Eden Editor"; regex = "\bEden Editor\b"; expected = "a3-editor-workflow" },
    @{ name = "isEqualTo"; regex = "\bisEqualTo\b"; expected = "newer-sqf-syntax" },
    @{ name = "params-command"; regex = "^\s*params\s*\["; expected = "newer-sqf-syntax" },
    @{ name = "apply-command"; regex = "\bapply\s*\{"; expected = "newer-sqf-syntax" },
    @{ name = "pushBack"; regex = "\bpushBack\b"; expected = "newer-sqf-syntax" },
    @{ name = "allPlayers"; regex = "\ballPlayers\b"; expected = "a3-command" },
    @{ name = "getUnitLoadout"; regex = "\bgetUnitLoadout\b|\bsetUnitLoadout\b"; expected = "a3-loadout-command" },
    @{ name = "createSimpleObject"; regex = "\bcreateSimpleObject\b"; expected = "a3-object-command" },
    @{ name = "setGroupOwner"; regex = "\bsetGroupOwner\b|\bgroupOwner\b"; expected = "a3-hc-locality-command" },
    @{ name = "diag_tickTime"; regex = "\bdiag_tickTime\b"; expected = "oa-safe-inverse-trap" },
    @{ name = "uiSleep"; regex = "\buiSleep\b"; expected = "oa-safe-inverse-trap" },
    @{ name = "setVehicleInit"; regex = "\bsetVehicleInit\b|\bprocessInitCommands\b"; expected = "oa-safe-inverse-trap" }
)

function Get-RelativePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($repoRoot, $Path)
}

function Get-Area {
    param([string]$RelativePath)
    $first = ($RelativePath -split '[\\/]')[0]
    if ($first -eq "docs") { return "docs-wiki" }
    return $first
}

function Get-CommentState {
    param(
        [string]$Line,
        [bool]$InBlockComment
    )

    $trimmed = $Line.TrimStart()
    $commentOnly = $InBlockComment -or $trimmed.StartsWith("//") -or $trimmed.StartsWith("*") -or $trimmed.StartsWith("#")
    $nextInBlock = $InBlockComment

    if ($Line -match '/\*') {
        $before = $Line.Substring(0, $Line.IndexOf("/*"))
        if ($before.Trim().Length -eq 0) { $commentOnly = $true }
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

function Classify-Hit {
    param(
        [string]$Area,
        [string]$RelativePath,
        [string]$PatternName,
        [string]$Line,
        [bool]$CommentOnly
    )

    if ($Area -eq "docs-wiki") {
        return "docs-reference-review"
    }

    if ($PatternName -in @("diag_tickTime", "uiSleep", "setVehicleInit")) {
        return "oa-safe-inverse-trap-review"
    }

    if ($CommentOnly) {
        return "comment-only-review"
    }

    if ($PatternName -eq "params-command" -and $Line -match "paramsArray|class Params|Param") {
        return "false-positive-params-system"
    }

    if ($PatternName -in @("remoteExec", "BIS_fnc_MP", "addMissionEventHandler", "isRemoteExecuted", "remoteExecutedOwner", "parseSimpleArray", "RVExtensionArgs", "CfgFunctions", "isEqualTo", "params-command", "apply-command", "pushBack", "allPlayers", "getUnitLoadout", "createSimpleObject", "setGroupOwner")) {
        return "code-risk-review"
    }

    return "review"
}

$files = foreach ($root in $roots) {
    $full = Join-Path $repoRoot $root
    if (Test-Path -LiteralPath $full) {
        Get-ChildItem -LiteralPath $full -Recurse -File | Where-Object {
            $textExtensions -contains $_.Extension.ToLowerInvariant()
        }
    }
}

$hits = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $relative = Get-RelativePath -Path $file.FullName
    $area = Get-Area -RelativePath $relative
    $lines = Get-Content -LiteralPath $file.FullName -ErrorAction Stop
    $inBlock = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $comment = Get-CommentState -Line $line -InBlockComment $inBlock
        $inBlock = $comment.NextInBlock

        foreach ($pattern in $patterns) {
            if ($line -match $pattern.regex) {
                $classification = Classify-Hit -Area $area -RelativePath $relative -PatternName $pattern.name -Line $line -CommentOnly $comment.CommentOnly
                $hits.Add([pscustomobject]@{
                    pattern = $pattern.name
                    expected = $pattern.expected
                    classification = $classification
                    area = $area
                    source = $relative
                    line = $i + 1
                    commentOnly = $comment.CommentOnly
                    text = $line.Trim()
                }) | Out-Null
            }
        }
    }
}

$summaryByPattern = $hits | Group-Object -Property pattern | ForEach-Object {
    [pscustomobject]@{
        pattern = $_.Name
        count = $_.Count
        codeRiskReview = @($_.Group | Where-Object { $_.classification -eq "code-risk-review" }).Count
        docsReferenceReview = @($_.Group | Where-Object { $_.classification -eq "docs-reference-review" }).Count
        commentOnlyReview = @($_.Group | Where-Object { $_.classification -eq "comment-only-review" }).Count
        oaSafeInverseTrapReview = @($_.Group | Where-Object { $_.classification -eq "oa-safe-inverse-trap-review" }).Count
        otherReview = @($_.Group | Where-Object { $_.classification -eq "review" }).Count
    }
} | Sort-Object pattern

$summaryByArea = $hits | Group-Object -Property area | ForEach-Object {
    [pscustomobject]@{
        area = $_.Name
        count = $_.Count
        codeRiskReview = @($_.Group | Where-Object { $_.classification -eq "code-risk-review" }).Count
        docsReferenceReview = @($_.Group | Where-Object { $_.classification -eq "docs-reference-review" }).Count
        commentOnlyReview = @($_.Group | Where-Object { $_.classification -eq "comment-only-review" }).Count
        oaSafeInverseTrapReview = @($_.Group | Where-Object { $_.classification -eq "oa-safe-inverse-trap-review" }).Count
        otherReview = @($_.Group | Where-Object { $_.classification -eq "review" }).Count
    }
} | Sort-Object area

$result = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("o")
    roots = $roots
    scannedTextFiles = @($files).Count
    patternCount = $patterns.Count
    hitCount = $hits.Count
    codeRiskHitCount = @($hits | Where-Object { $_.classification -eq "code-risk-review" }).Count
    docsReferenceHitCount = @($hits | Where-Object { $_.classification -eq "docs-reference-review" }).Count
    commentOnlyHitCount = @($hits | Where-Object { $_.classification -eq "comment-only-review" }).Count
    oaSafeInverseTrapHitCount = @($hits | Where-Object { $_.classification -eq "oa-safe-inverse-trap-review" }).Count
    summaryByPattern = $summaryByPattern
    summaryByArea = $summaryByArea
    codeRiskHits = @($hits | Where-Object { $_.classification -eq "code-risk-review" } | Sort-Object area, source, line)
    commentOnlyHits = @($hits | Where-Object { $_.classification -eq "comment-only-review" } | Sort-Object area, source, line)
    oaSafeInverseTrapHits = @($hits | Where-Object { $_.classification -eq "oa-safe-inverse-trap-review" } | Sort-Object area, source, line)
    docsReferenceHits = @($hits | Where-Object { $_.classification -eq "docs-reference-review" } | Sort-Object source, line)
    hits = @($hits | Sort-Object area, source, line, pattern)
}

$outDir = Split-Path -Parent $outputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputPath -Encoding UTF8
$result
