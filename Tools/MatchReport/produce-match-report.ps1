<#
  produce-match-report.ps1 — production runner for the WASP post-match report.

  Pulls the live server RPT, finds the latest COMPLETED match (newest ROUNDEND),
  slices that match's WASPSTAT block, renders the report video, and drops the MP4
  in the output folder. De-dupes on the ROUNDEND sequence so it only renders each
  match once. Designed to run as a box-side Scheduled Task every ~10 min (per the
  "automation on the box, never Claude crons" rule).

  Data path: WASPSTAT lines live in the Hetzner server RPT (the same source the
  leaderboard/soak reporters read via SSH).

  Usage:
    # production (SSH-pull the live RPT):
    pwsh -File produce-match-report.ps1 -Notify
    # test against a local log file (no SSH):
    pwsh -File produce-match-report.ps1 -RptFile sample.waspstat
#>
[CmdletBinding()]
param(
  [string]$RptFile,                                   # local RPT/log; if omitted, SSH-pull from Hetzner
  [string]$OutDir   = 'C:\Users\Game\wasp-match-reports',
  [string]$NamesTsv,                                  # optional uid<TAB>name map (else Op-XXXX)
  [switch]$Notify                                     # Peach DM Ray with the result
)
$ErrorActionPreference = 'Stop'
$ToolDir   = 'C:\Users\Game\a2waspwarfare-report\Tools\MatchReport'
$Py        = Join-Path $ToolDir '.venv\Scripts\python.exe'
$Hetzner   = 'Administrator@78.46.107.142'
$RemoteRpt = 'C:/Users/Administrator/AppData/Local/ArmA 2 OA/arma2oaserver.RPT'
$StateFile = Join-Path $OutDir '.last-rendered-seq.txt'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-RptText {
  if ($RptFile) { return Get-Content -LiteralPath $RptFile -Raw }
  # SSH pull. `type` on the remote Windows box streams the whole RPT; cheap enough at ~10-min cadence.
  return (ssh $Hetzner "type `"$RemoteRpt`"")
}
function Get-Seq([string]$line) { if ($line -match 'WASPSTAT\|v1\|(\d+)\|') { [int]$Matches[1] } else { -1 } }

# 1. collect WASPSTAT lines + ROUNDEND markers
$lines = (Get-RptText) -split "`r?`n" | Where-Object { $_ -match 'WASPSTAT\|v1\|' }
$roundEnds = @($lines | Where-Object { $_ -match 'WASPSTAT\|v1\|\d+\|ROUNDEND\|' })
if ($roundEnds.Count -eq 0) { Write-Host 'No completed match (no ROUNDEND yet).'; return }

# 2. latest match + de-dupe on its ROUNDEND seq
$lastSeq = Get-Seq $roundEnds[-1]
$done = if (Test-Path $StateFile) { (Get-Content $StateFile -Raw).Trim() } else { '' }
if ($done -eq "$lastSeq") { Write-Host "Already rendered match (ROUNDEND seq $lastSeq)."; return }
$prevSeq = if ($roundEnds.Count -ge 2) { Get-Seq $roundEnds[-2] } else { 0 }

# 3. slice this match's events: prevSeq < seq <= lastSeq
$matchLines = $lines | Where-Object { $s = Get-Seq $_; $s -gt $prevSeq -and $s -le $lastSeq }
if (-not $matchLines) { Write-Host 'Empty match slice; skipping.'; return }

# parse the ROUNDEND for a nice filename: ...|ROUNDEND|<winner>|<dur>|<map>
$winner = 'WEST'; $map = 'chernarus'
if ($roundEnds[-1] -match 'ROUNDEND\|([^|]+)\|\d+\|([^|]+)') { $winner = $Matches[1]; $map = $Matches[2] }

# 4. render
$logFile = Join-Path $OutDir "match-$lastSeq.waspstat"
($matchLines -join "`n") | Set-Content -LiteralPath $logFile -Encoding UTF8
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out   = Join-Path $OutDir ("wasp-report-{0}-{1}-{2}.mp4" -f $stamp, $map.ToLower(), $winner.ToLower())
$args  = @((Join-Path $ToolDir 'render_report.py'), '--waspstat', $logFile, '-o', $out)
if ($NamesTsv) { $args += @('--names', $NamesTsv) }
Write-Host "Rendering match ROUNDEND seq $lastSeq ($winner / $map) -> $out"
& $Py @args
if ($LASTEXITCODE -ne 0) { throw "render_report.py failed (exit $LASTEXITCODE)" }

# 5. record state so we never re-render this match
Set-Content -LiteralPath $StateFile -Value "$lastSeq"
$sizeMB = [math]::Round((Get-Item $out).Length/1MB, 1)
Write-Host "DONE: $out ($sizeMB MB)"

# 6. optional Peach DM to Ray with the path (so it pings your phone)
if ($Notify) {
  try {
    $keyLine = Get-Content 'C:\Users\Game\Complete-discord-bot\.env' | Where-Object { $_ -match '^\s*PEACH_OPS_API_KEY\s*=' } | Select-Object -First 1
    $key = ($keyLine -split '=',2)[1].Trim()
    $msg = "**WASP Match Report** ready: $winner victory on $map. File: $out ($sizeMB MB). Post to TikTok when you like."
    Invoke-WebRequest -Uri 'http://127.0.0.1:5001/api/peach/admin/dm' -Method POST `
      -Headers @{ 'Content-Type'='application/json'; 'X-Ops-Key'=$key } `
      -Body (@{ content=$msg } | ConvertTo-Json -Compress) -TimeoutSec 15 -UseBasicParsing | Out-Null
  } catch { Write-Warning "Peach notify failed: $($_.Exception.Message)" }
}
