# Standing WASP mission-PERFORMANCE reporter. Posts a high-priority brain task every 3h; the brain
# runner's claude (has ssh + Peach+ + dashboard access) gathers live perf and DMs Ray via Peach.
# Modeled on guer-report-trigger.ps1. Driven by scheduled task WaspPerfReport (every 3h, gaming PC).
$ErrorActionPreference='Continue'
$log='C:\Users\Game\claude-bridge\logs\wasp-perf-report-trigger.log'
function L($m){ try{ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }catch{} }
$ams=[System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow,'W. Europe Standard Time')
try {
  $envLine = Get-Content 'C:\Users\Game\claude-bridge\.env' | Where-Object { $_ -match '^\s*BRAIN_TOKEN\s*=' } | Select-Object -First 1
  $token = ($envLine -split '=',2)[1].Trim().Trim('"').Trim("'")
} catch { L ('cannot read brain token: '+$_.Exception.Message); exit 1 }
$id = 'wasp-perf-report-' + $ams.ToString('MMdd-HHmm')
$detail = "[HIGH PRIORITY report task - do this FIRST, then mark brain done. LEGACY a2waspwarfare ONLY, NEVER NEXT.] Send Ray a CONCISE 3-hourly WASP mission-PERFORMANCE report via Peach+ (one tight Discord POST, start with '**WASP Perf (3h)**'). The legacy server runs BOTH maps in rotation (WaspMapRotate): Chernarus = B41c GUER (active 3rd faction), Takistan = GUER once the port lands else B40. STEPS (fully autonomous, no questions): (1) ssh Administrator@78.46.107.142 ; read the live RPT (C:/Users/Administrator/AppData/Local/ArmA 2 OA/arma2oaserver.RPT, tail a few hundred lines) to get: which map+build is live now, procs up (3/3?), server FPS (latest + rough avg over the window), AI/unit count, active towns, notable events (kills, captures, GUER kill-funds, unstuck fires), and any NEW/distinct SQF error classes (each distinct 'Error in expression' class = a bug to flag, with count). Also glance at C:/WASP/guer-soak-findings.md if present for recent per-round perf. (2) Cross-check the stats DASHBOARD (the canonical perf view) so numbers align. (3) Compose a concise perf summary: live map/build | procs | FPS | AI | towns | top events | one-line health verdict (healthy / degraded + why). Flag any error-class bugs distinctly. (4) POST to Peach+ (DMs Ray): read PEACH_OPS_API_KEY from C:/Users/Game/Complete-discord-bot/.env (do NOT print it). Invoke-RestMethod -Uri 'http://127.0.0.1:5001/api/peach/admin/dm' -Method POST -Headers @{ 'X-Ops-Key'=KEY } -ContentType 'application/json' -Body (@{ content=MSG } | ConvertTo-Json -Compress) -TimeoutSec 15. CRITICAL: do NOT set user_id (Peach+ defaults to the correct RAY_USER_ID; 1498945495970615386 is his PARTNER - never use it). If >~1900 chars, split into sequential POSTs. Confirm HTTP 2xx; retry once. Then mark brain done $id."
$body = @{ id=$id; title='WASP: send 3h mission-performance report to Peach+'; kind='chore'; project='a2waspwarfare'; machine='gaming'; owner='claude-gaming'; priority='high'; detail=$detail; agent='claude-gaming'; source='wasp-perf-report-trigger' } | ConvertTo-Json -Depth 4
try {
  $r = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/task' -Method Post -Headers @{Authorization="Bearer $token"} -ContentType 'application/json' -Body $body -TimeoutSec 12
  L ("posted perf report task $id")
  Write-Output ("posted perf report task $id")
} catch { L ("post failed: "+$_.Exception.Message); Write-Output ("post failed: "+$_.Exception.Message); exit 1 }
