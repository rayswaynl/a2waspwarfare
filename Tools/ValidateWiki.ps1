param(
    [string]$WikiPath = "docs/wiki",
    [switch]$SkipGitDiffCheck
)

$ErrorActionPreference = "Stop"

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message"
}

function Fail {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

function Add-MachineExactReferenceProblems {
    param(
        [object]$Value,
        [string]$Path,
        [System.Collections.Generic.List[string]]$Problems
    )

    if ($null -eq $Value) { return }

    if ($Value -is [string]) {
        $ref = [string]$Value
        if ($ref -match '^[A-Za-z0-9_.\-/\\]+\.md$') {
            $pageName = [IO.Path]::GetFileNameWithoutExtension($ref)
            if (-not $pages.ContainsKey($pageName)) {
                $Problems.Add("$Path -> $ref")
            }
        } elseif ($ref -match '^agent-[A-Za-z0-9_.-]+\.jsonl?$') {
            if (-not (Test-Path -LiteralPath (Join-Path $wikiRoot $ref))) {
                $Problems.Add("$Path -> $ref")
            }
        } elseif ($ref -match '^[A-Za-z0-9_.\-/\\]+\.ps1$') {
            if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $ref))) {
                $Problems.Add("$Path -> $ref")
            }
        }
        return
    }

    if ($Value -is [System.ValueType]) {
        return
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $index = 0
        foreach ($item in $Value) {
            Add-MachineExactReferenceProblems -Value $item -Path "$Path[$index]" -Problems $Problems
            $index++
        }
        return
    }

    if ($Value.PSObject -and $Value.PSObject.Properties) {
        foreach ($property in $Value.PSObject.Properties) {
            Add-MachineExactReferenceProblems -Value $property.Value -Path "$Path.$($property.Name)" -Problems $Problems
        }
    }
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$wikiRoot = if ([IO.Path]::IsPathRooted($WikiPath)) {
    (Resolve-Path -LiteralPath $WikiPath).Path
} else {
    (Resolve-Path -LiteralPath (Join-Path $repoRoot $WikiPath)).Path
}

$mdFiles = @(Get-ChildItem -LiteralPath $wikiRoot -Filter "*.md")
if ($mdFiles.Count -eq 0) {
    Fail "No markdown files found under $wikiRoot"
}

$pages = @{}
foreach ($file in $mdFiles) {
    $pages[[IO.Path]::GetFileNameWithoutExtension($file.Name)] = $true
}

$agentContextPath = Join-Path $wikiRoot "agent-context.json"
$agentStatusPath = Join-Path $wikiRoot "agent-status.json"
$backlogPath = Join-Path $wikiRoot "agent-hardening-backlog.jsonl"

try {
    $agentContext = Get-Content -LiteralPath $agentContextPath -Raw | ConvertFrom-Json
    Write-Ok "agent-context.json parses"
} catch {
    Fail "agent-context.json does not parse: $($_.Exception.Message)"
}

try {
    $agentStatus = Get-Content -LiteralPath $agentStatusPath -Raw | ConvertFrom-Json
    Write-Ok "agent-status.json parses"
} catch {
    Fail "agent-status.json does not parse: $($_.Exception.Message)"
}

$backlogItems = @()
$lineNo = 0
foreach ($line in Get-Content -LiteralPath $backlogPath) {
    $lineNo++
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $backlogItems += ($line | ConvertFrom-Json)
    } catch {
        Fail "agent-hardening-backlog.jsonl line $lineNo does not parse: $($_.Exception.Message)"
    }
}
Write-Ok "agent-hardening-backlog.jsonl parses ($($backlogItems.Count) entries)"

$featureStatusPath = Join-Path $wikiRoot "agent-feature-status.jsonl"
if (Test-Path -LiteralPath $featureStatusPath) {
    $featureStatusCount = 0
    $lineNo = 0
    foreach ($line in Get-Content -LiteralPath $featureStatusPath) {
        $lineNo++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $null = ($line | ConvertFrom-Json)
            $featureStatusCount++
        } catch {
            Fail "agent-feature-status.jsonl line $lineNo does not parse: $($_.Exception.Message)"
        }
    }
    Write-Ok "agent-feature-status.jsonl parses ($featureStatusCount entries)"
}

$jsonFileCount = 0
foreach ($jsonFile in @(Get-ChildItem -LiteralPath $wikiRoot -Filter "*.json")) {
    try {
        $null = Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json
        $jsonFileCount++
    } catch {
        Fail "$($jsonFile.Name) does not parse: $($_.Exception.Message)"
    }
}

$jsonlFileCount = 0
$jsonlEntryCount = 0
foreach ($jsonlFile in @(Get-ChildItem -LiteralPath $wikiRoot -Filter "*.jsonl")) {
    $lineNo = 0
    foreach ($line in Get-Content -LiteralPath $jsonlFile.FullName) {
        $lineNo++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $null = $line | ConvertFrom-Json
            $jsonlEntryCount++
        } catch {
            Fail "$($jsonlFile.Name) line $lineNo does not parse: $($_.Exception.Message)"
        }
    }
    $jsonlFileCount++
}
Write-Ok "all wiki JSON/JSONL files parse ($jsonFileCount JSON files, $jsonlFileCount JSONL files, $jsonlEntryCount JSONL entries)"

$controlCharacterProblems = New-Object System.Collections.Generic.List[string]
$controlCharacterPattern = '[\x00-\x08\x0B\x0C\x0E-\x1F]'
foreach ($contentFile in @(Get-ChildItem -LiteralPath $wikiRoot -File)) {
    $lineNo = 0
    foreach ($line in Get-Content -LiteralPath $contentFile.FullName) {
        $lineNo++
        if ($line -match $controlCharacterPattern) {
            $controlCharacterProblems.Add("$($contentFile.Name):$lineNo")
        }
    }
}

if ($controlCharacterProblems.Count -gt 0) {
    $controlCharacterProblems | Sort-Object | ForEach-Object { Write-Host $_ }
    Fail "Control-character scan failed"
}
Write-Ok "control-character scan clean"

$pageListProblems = New-Object System.Collections.Generic.List[string]
$documentedPages = @($agentContext.documentation.pages | ForEach-Object { [string]$_ })
$documentedPageSet = @{}
foreach ($page in $documentedPages) {
    $documentedPageSet[$page] = $true
}

$duplicatePages = @($documentedPages | Group-Object | Where-Object { $_.Count -gt 1 })
foreach ($duplicate in $duplicatePages) {
    $pageListProblems.Add("agent-context documentation.pages duplicate -> $($duplicate.Name)")
}

foreach ($pageName in ($pages.Keys | Sort-Object)) {
    if (-not $documentedPageSet.ContainsKey($pageName)) {
        $pageListProblems.Add("agent-context documentation.pages missing -> $pageName")
    }
}

foreach ($pageName in $documentedPages) {
    if (-not $pages.ContainsKey($pageName)) {
        $pageListProblems.Add("agent-context documentation.pages stale -> $pageName")
    }
}

$primaryTour = @($agentContext.documentation.navigation.primaryTour | ForEach-Object { [string]$_ })
foreach ($duplicate in @($primaryTour | Group-Object | Where-Object { $_.Count -gt 1 })) {
    $pageListProblems.Add("agent-context navigation.primaryTour duplicate -> $($duplicate.Name)")
}

foreach ($pageName in $primaryTour) {
    if (-not $pages.ContainsKey($pageName)) {
        $pageListProblems.Add("agent-context navigation.primaryTour stale -> $pageName")
    }
}

if ($pageListProblems.Count -gt 0) {
    $pageListProblems | Sort-Object | ForEach-Object { Write-Host $_ }
    Fail "Agent-context page-list validation failed"
}
Write-Ok "agent-context page lists match wiki mirror"

$missing = New-Object System.Collections.Generic.List[string]
$markdownLinkPattern = '\[[^\]]+\]\(([^)]+)\)'
foreach ($file in $mdFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in [regex]::Matches($text, $markdownLinkPattern)) {
        $target = $match.Groups[1].Value.Trim()
        if ($target -match '^(https?:|mailto:|#)' -or $target -match '^`') { continue }
        $clean = ($target -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }

        if ($clean -match '\.jsonl?$|\.schema\.json$|\.txt$') {
            if (-not (Test-Path -LiteralPath (Join-Path $wikiRoot $clean))) {
                $missing.Add("$($file.Name) -> $target")
            }
            continue
        }

        $pageName = [IO.Path]::GetFileNameWithoutExtension($clean)
        if (-not $pages.ContainsKey($pageName)) {
            $missing.Add("$($file.Name) -> $target")
        }
    }
}

if ($missing.Count -gt 0) {
    $missing | Sort-Object | ForEach-Object { Write-Host $_ }
    Fail "Markdown link validation failed"
}
Write-Ok "markdown links resolve"

$machineMissing = New-Object System.Collections.Generic.List[string]
foreach ($machineFile in @($agentContext.documentation.machineFiles)) {
    if (-not (Test-Path -LiteralPath (Join-Path $wikiRoot ([string]$machineFile)))) {
        $machineMissing.Add("agent-context machineFiles -> $machineFile")
    }
}

foreach ($item in $backlogItems) {
    foreach ($ref in @($item.wikiRefs)) {
        $pageName = [IO.Path]::GetFileNameWithoutExtension([string]$ref)
        if (-not $pages.ContainsKey($pageName)) {
            $machineMissing.Add("$($item.id) wikiRefs -> $ref")
        }
    }
}

foreach ($property in $agentStatus.sourceOfTruth.PSObject.Properties) {
    $ref = [string]$property.Value
    if ($ref -match '\.md$') {
        $pageName = [IO.Path]::GetFileNameWithoutExtension($ref)
        if (-not $pages.ContainsKey($pageName)) {
            $machineMissing.Add("agent-status sourceOfTruth.$($property.Name) -> $ref")
        }
    } elseif ($ref -match '\.jsonl?$') {
        if (-not (Test-Path -LiteralPath (Join-Path $wikiRoot $ref))) {
            $machineMissing.Add("agent-status sourceOfTruth.$($property.Name) -> $ref")
        }
    } elseif ($ref -match '\.ps1$') {
        if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $ref))) {
            $machineMissing.Add("agent-status sourceOfTruth.$($property.Name) -> $ref")
        }
    }
}

if ($machineMissing.Count -gt 0) {
    $machineMissing | Sort-Object | ForEach-Object { Write-Host $_ }
    Fail "Machine-reference validation failed"
}
Write-Ok "machine references resolve"

$exactMachineReferenceProblems = New-Object System.Collections.Generic.List[string]
Add-MachineExactReferenceProblems -Value $agentContext -Path "agent-context.json" -Problems $exactMachineReferenceProblems
Add-MachineExactReferenceProblems -Value $agentStatus -Path "agent-status.json" -Problems $exactMachineReferenceProblems
$backlogIndex = 0
foreach ($item in $backlogItems) {
    Add-MachineExactReferenceProblems -Value $item -Path "agent-hardening-backlog.jsonl[$backlogIndex]" -Problems $exactMachineReferenceProblems
    $backlogIndex++
}

if ($exactMachineReferenceProblems.Count -gt 0) {
    $exactMachineReferenceProblems | Sort-Object | ForEach-Object { Write-Host $_ }
    Fail "Exact machine-reference validation failed"
}
Write-Ok "exact machine references resolve"

$retiredRouteNames = @(
    "Claude-Long-Term-Goal",
    "Client-UI-Systems-Atlas",
    "Construction-And-CoIn-Systems-Atlas",
    "Factory-And-Purchase-Systems-Atlas",
    "Gear-Loadout-And-EASA-Atlas",
    "Server-Gameplay-Runtime-Atlas",
    "Hardening-Implementation-Roadmap",
    "Server-Authority-Migration-Map",
    "Attack-Wave-Authority-Playbook",
    "Testing-Debugging-And-Release-Workflow",
    "Headless-Delegation-And-Failover-Playbook",
    "Agent-Collaboration-Protocol",
    "External-Research-Reports",
    "Subagent-Discovery-Swarm"
)
$retiredPattern = ($retiredRouteNames | Where-Object { -not $pages.ContainsKey($_) } | ForEach-Object { [regex]::Escape($_) }) -join "|"
$staleHits = @()
if (-not [string]::IsNullOrWhiteSpace($retiredPattern)) {
    foreach ($path in @($agentContextPath, $agentStatusPath, $backlogPath)) {
        $hits = @(Select-String -LiteralPath $path -Pattern $retiredPattern)
        foreach ($hit in $hits) {
            $staleHits += "$([IO.Path]::GetFileName($path)):$($hit.LineNumber): $($hit.Line.Trim())"
        }
    }
}

if ($staleHits.Count -gt 0) {
    $staleHits | ForEach-Object { Write-Host $_ }
    Fail "Retired machine-route scan failed"
}
Write-Ok "retired machine-route scan clean"

$currentStateFiles = @(
    "Current-Source-Status-Snapshot.md",
    "Progress-Dashboard.md",
    "Feature-Status-Register.md",
    "Agent-Context.md",
    "Coordination-Board.md",
    "agent-context.json",
    "agent-status.json",
    "agent-collaboration.json",
    "agent-hardening-backlog.jsonl",
    "agent-feature-status.jsonl"
)

$staleCurrentTerms = @(
    "source-vanilla-patched-smoke-pending",
    "partial-scan-source-vanilla-patched-smoke-pending",
    "partial-paratrooper-source-vanilla-patched-smoke-pending",
    "published-source-vanilla-patched-smoke-pending",
    "Source+Vanilla patched",
    "source/Vanilla patched, smoke pending",
    "source/Vanilla patched in maintained targets",
    "source/Vanilla patched; broader",
    "source/Vanilla patched: current source",
    "source/Vanilla patched with Arma smoke pending"
)

$currentStateStaleHits = New-Object System.Collections.Generic.List[string]
foreach ($fileName in $currentStateFiles) {
    $path = Join-Path $wikiRoot $fileName
    if (-not (Test-Path -LiteralPath $path)) {
        continue
    }

    foreach ($term in $staleCurrentTerms) {
        $hits = @(Select-String -LiteralPath $path -SimpleMatch -Pattern $term)
        foreach ($hit in $hits) {
            if ($hit.Line -match "false|superseded|historical|older worklog/event/knowledge|Do not mark") {
                continue
            }
            $currentStateStaleHits.Add("$($fileName):$($hit.LineNumber): $($hit.Line.Trim())")
        }
    }
}

if ($currentStateStaleHits.Count -gt 0) {
    $currentStateStaleHits | Sort-Object | ForEach-Object { Write-Host $_ }
    Fail "Current-state stale patched wording scan failed"
}
Write-Ok "current-state stale patched wording scan clean"

$compatibilityGuardFiles = @(
    "Current-Source-Status-Snapshot.md",
    "Progress-Dashboard.md",
    "Feature-Status-Register.md",
    "Agent-Context.md",
    "Coordination-Board.md",
    "agent-context.json",
    "agent-status.json",
    "agent-collaboration.json",
    "agent-hardening-backlog.jsonl",
    "agent-feature-status.jsonl",
    "LLM-Agent-Entry-Pack.md",
    "AI-Assistant-Guide.md",
    "AI-Assistant-Developer-Guide.md",
    "Quickstart-For-Humans-And-Agents.md",
    "Arma-2-OA-Compatibility-Audit.md",
    "Arma-2-OA-Command-Version-Reference.md",
    "Arma-2-OA-External-Reference-Guide.md",
    "External-Arma-2-OA-Reference-Index.md",
    "Networking-And-Public-Variables.md",
    "Public-Variable-Channel-Index.md",
    "Testing-Debugging-And-Release-Workflow.md",
    "Tools-And-Build-Workflow.md",
    "llms.txt"
)

$modernAssumptionTerms = @(
    "remoteExec",
    "remoteExecCall",
    "BIS_fnc_MP",
    "addMissionEventHandler",
    "isRemoteExecuted",
    "remoteExecutedOwner",
    "parseSimpleArray",
    "isEqualTo",
    "isEqualType",
    "setGroupOwner",
    "groupOwner",
    "private _var = value",
    "private _var",
    "private _x = value",
    "CfgRemoteExec"
)

$compatibilityWarningPattern = "avoid|do not|no |not |not-|without OA|unless OA|Arma 3|A3 |outside the OA|has no|guardrail|caveat|warning|instead|rather than|not listed|must not|should not|superseded|historical|checkedTerms|unsafeWithoutOaProof|externalReferences|remainingUncertain|sourceRefs|validation|no hidden|no trusted|not rely|not import|not replace|not use|OA has no|mission already uses|own PVF|class Params|paramsArray|A3-only|contrast|unsafe|Source Basis|Corrections Made|No Doc Change Needed|Modern remote-execution terms|Corrected|remove"
$modernAssumptionHits = New-Object System.Collections.Generic.List[string]
foreach ($fileName in $compatibilityGuardFiles) {
    $path = Join-Path $wikiRoot $fileName
    if (-not (Test-Path -LiteralPath $path)) {
        continue
    }

    $lineNo = 0
    foreach ($line in Get-Content -LiteralPath $path) {
        $lineNo++
        foreach ($term in $modernAssumptionTerms) {
            if ($line -like "*$term*" -and $line -notmatch $compatibilityWarningPattern) {
                $modernAssumptionHits.Add(("{0}:{1}: {2} -> {3}" -f $fileName, $lineNo, $term, $line.Trim()))
            }
        }
    }
}

if ($modernAssumptionHits.Count -gt 0) {
    $modernAssumptionHits | Sort-Object | ForEach-Object { Write-Host $_ }
    Fail "Arma 2 OA compatibility guardrail scan failed"
}
Write-Ok "Arma 2 OA compatibility guardrail scan clean"



if (-not $SkipGitDiffCheck) {
    Push-Location $repoRoot
    try {
        & git diff --check
        if ($LASTEXITCODE -ne 0) {
            Fail "git diff --check failed"
        }
        Write-Ok "git diff --check"
    } finally {
        Pop-Location
    }
}

Write-Host "Wiki validation complete."
