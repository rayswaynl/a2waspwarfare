<#
  Dependency-free assertion tests for Get-FlagRecommendation.ps1. Exit 0 pass / 1 fail.
  Confirms the recommender surfaces evidence-based recommendations (incl. GUER-affecting, per the
  owner ruling that everything may be surfaced) while staying strictly surface-only.
#>
$ErrorActionPreference = 'Stop'
$here   = $PSScriptRoot
$script = Join-Path $here 'Get-FlagRecommendation.ps1'
$exps   = Join-Path $here 'topExperiments.json'

$fail = 0
function Assert([bool]$c, [string]$m) { if ($c) { Write-Host "  ok   $m" } else { Write-Host "  FAIL $m" -ForegroundColor Red; $script:fail++ } }

$work = Join-Path ([IO.Path]::GetTempPath()) ("wasp-rec-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
    # a decisive finding on a flag experiment (guer-director-aliveness -> WFBE_C_GUER_DIRECTOR)
    $findings = Join-Path $work 'findings.jsonl'
    @'
# header
{"schema":"a2wasp-finding-v1","findingId":"20260707-0001","experiment":"guer-director-aliveness","metric":"captures","verdict":"BETTER","evidence":{"pctDelta":40.0,"direction":"better","armA":{"rowIds":["r1"]},"armB":{"rowIds":["r2"]}}}
{"schema":"a2wasp-finding-v1","findingId":"20260707-0002","experiment":"fps-knee-hc-sensitivity","metric":"serverFpsMedian","verdict":"WORSE","evidence":{"pctDelta":-30.0,"direction":"worse","armA":{"rowIds":["r3"]},"armB":{"rowIds":["r4"]}}}
{"schema":"a2wasp-finding-v1","findingId":"20260707-0003","experiment":"guer-director-aliveness","metric":"captures","verdict":"INCONCLUSIVE","evidence":{"pctDelta":null,"direction":"flat"}}
'@ | Set-Content -LiteralPath $findings -Encoding utf8

    # tiny constants file providing the live default
    $consts = Join-Path $work 'Init_CommonConstants.sqf'
    'WFBE_C_GUER_DIRECTOR = missionNamespace getVariable ["WFBE_C_GUER_DIRECTOR", 0];' | Set-Content -LiteralPath $consts -Encoding utf8

    $out = Join-Path $work 'recommendations.jsonl'
    $recs = & $script -FindingsPath $findings -ExperimentsPath $exps -ConstantsPath $consts -OutPath $out -Json

    Assert (@($recs).Count -eq 1) "one recommendation from one decisive flag finding (count=$(@($recs).Count))"
    $r = @($recs)[0]
    Assert ($r.flag -eq 'WFBE_C_GUER_DIRECTOR')          "recommends the mapped flag"
    Assert ($r.currentDefault -eq '0')                    "reads live default (0) from constants"
    Assert ($r.contextLabels -contains 'guer-affecting')  "labels GUER-affecting (surfaced, not blocked)"
    Assert ($r.disposition -eq 'SURFACE')                 "disposition SURFACE-only"
    Assert ($r.ownerActionRequired -eq $true)             "owner action required"
    Assert ($r.autoApplied -eq $false)                    "never auto-applied"
    Assert ($r.verdict -eq 'BETTER')                      "carries the finding verdict"

    Assert (Test-Path $out)                               "recommendations.jsonl written"
    $line0 = ([IO.File]::ReadAllLines($out))[0]
    Assert ($line0.StartsWith('#'))                       "header comment present"

    # the WORSE finding maps to a no-flag experiment (fps-knee) -> no recommendation; INCONCLUSIVE skipped
    Assert (@($recs | Where-Object { $_.findingId -eq '20260707-0002' }).Count -eq 0) "no-flag experiment yields no rec"
    Assert (@($recs | Where-Object { $_.findingId -eq '20260707-0003' }).Count -eq 0) "INCONCLUSIVE yields no rec"

    # idempotent: re-run does not duplicate (findingId dedup)
    & $script -FindingsPath $findings -ExperimentsPath $exps -ConstantsPath $consts -OutPath $out *> $null
    $total = @([IO.File]::ReadAllLines($out) | Where-Object { $_.Trim() -and -not $_.StartsWith('#') })
    Assert ($total.Count -eq 1) "re-run is idempotent (no duplicate rec)"

    # HARD safety: the script never invokes a deploy/PR/network COMMAND (prose mentioning "deploy" is fine)
    $src = Get-Content -Raw $script
    Assert (-not ($src -match 'gh pr create|git push|Invoke-RestMethod|Invoke-WebRequest|Start-Process')) "no deploy/PR/network command in the recommender"
}
finally { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ""
if ($fail -gt 0) { Write-Host "FAILED ($fail)" -ForegroundColor Red; exit 1 }
Write-Host "PASSED" -ForegroundColor Green; exit 0
