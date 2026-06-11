# mission-switcher.ps1 — Hetzner box time-share between the experital mission and the
# AI-commander mission (Steff, 2026-06-11).
#   03:00 task: -Target Aicom      (AI-vs-AI eval window 03:00-15:00)
#   15:00 task: -Target Experital  (human play window 15:00-03:00)
#
# Rules (owner): switch ONLY when no humans are online — never abrupt mid-match.
# Humans = A2S player count MINUS running headless-client processes.
# Mechanism: the engine auto-starts the ALPHABETICALLY-FIRST mission in MPMissions
# ("WASP_Experital_TEST..." sorts before "[55-2hc]..."), so presence/absence of the
# experital folder decides the boot mission. The inactive folder is PARKED (moved to
# C:\WASP\mission-park), never deleted. On any error: restore state, log, exit —
# worst case is "no switch", never "no server".
param(
    [Parameter(Mandatory = $true)][ValidateSet("Aicom", "Experital")][string]$Target,
    [int]$MaxWaitHours = 10,
    [int]$PollSeconds = 120
)

$ErrorActionPreference = "Stop"
$log = "C:\WASP\switcher.log"
$mp  = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions"
$park = "C:\WASP\mission-park"
$expName = "WASP_Experital_TEST.Chernarus"

function Log([string]$m) { Add-Content -LiteralPath $log -Value ("[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Target, $m) }

function Get-A2SPlayerCount {
    # Minimal A2S_INFO query against the local query port (2303). Returns -1 on failure.
    try {
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Client.ReceiveTimeout = 4000
        $udp.Connect("127.0.0.1", 2303)
        [byte[]]$req = @(0xFF,0xFF,0xFF,0xFF,0x54) + [System.Text.Encoding]::ASCII.GetBytes("Source Engine Query") + @(0x00)
        $null = $udp.Send($req, $req.Length)
        $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $resp = $udp.Receive([ref]$ep)
        $udp.Close()
        if ($resp.Length -lt 6) { return -1 }
        # A2S_INFO (header 0x49): skip 4xFF + type, then protocol byte, then 4 null-terminated
        # strings (name, map, folder, game), then 2 bytes appid, then player count byte.
        $i = 5
        if ($resp[4] -eq 0x41) { return -2 }  # challenge response - legacy servers don't do this
        $i = 6  # past header + protocol
        for ($s = 0; $s -lt 4; $s++) { while ($i -lt $resp.Length -and $resp[$i] -ne 0) { $i++ }; $i++ }
        $i += 2  # appid
        if ($i -ge $resp.Length) { return -1 }
        return [int]$resp[$i]
    } catch { return -1 }
}

function Get-HcCount { @(Get-Process ArmA2OA -ErrorAction SilentlyContinue).Count }

function Run-Task([string]$name) { schtasks /Run /TN $name | Out-Null }
function End-Task([string]$name) { schtasks /End /TN $name 2>$null | Out-Null }

Log "window boundary reached - target [$Target], waiting for empty server (max $MaxWaitHours h)"
New-Item -ItemType Directory -Force -Path $park | Out-Null
New-Item -ItemType Directory -Force -Path "C:\WASP\aicom-eval" | Out-Null

# --- 1. Check whether a switch is even needed -------------------------------------
$expPresent = Test-Path -LiteralPath (Join-Path $mp $expName)
if (($Target -eq "Experital" -and $expPresent) -or ($Target -eq "Aicom" -and -not $expPresent)) {
    Log "already in target state (experital present: $expPresent) - nothing to do"
    exit 0
}

# --- 2. Wait until no humans are online -------------------------------------------
$deadline = (Get-Date).AddHours($MaxWaitHours)
while ($true) {
    $players = Get-A2SPlayerCount
    $hcs = Get-HcCount
    $humans = if ($players -ge 0) { [math]::Max(0, $players - $hcs) } else { -1 }
    if ($humans -eq 0) { Log "server empty of humans (a2s=$players, hc=$hcs) - proceeding"; break }
    if ($humans -lt 0) { Log "a2s query failed ($players) - assuming server down, proceeding"; break }
    if ((Get-Date) -gt $deadline) { Log "WAIT EXPIRED with $humans humans online - aborting switch (no abrupt cut)"; exit 1 }
    Log "waiting: $humans human(s) online (a2s=$players, hc=$hcs)"
    Start-Sleep -Seconds $PollSeconds
}

# --- 3. Stop the chain -------------------------------------------------------------
try {
    Log "stopping chain"
    End-Task "MiksuuPR8"; End-Task "MiksuuHC"; End-Task "MiksuuHC2"
    Stop-Process -Name arma2oaserver, ArmA2OA -Force -ErrorAction SilentlyContinue
    Start-Sleep 5

    # --- 4. Park/restore the experital folder --------------------------------------
    if ($Target -eq "Aicom") {
        # preserve the AI-window RPT baseline marker for the morning digest
        $rpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT"
        if (Test-Path -LiteralPath $rpt) { (Get-Item -LiteralPath $rpt).Length | Set-Content "C:\WASP\aicom-eval\window-start-offset.txt" }
        Move-Item -LiteralPath (Join-Path $mp $expName) -Destination (Join-Path $park $expName)
        Log "experital parked - [55-2hc] aicom mission now boots"
    } else {
        # end of AI window: snapshot the RPT for the digest BEFORE restarting
        $rpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT"
        New-Item -ItemType Directory -Force -Path "C:\WASP\aicom-eval" | Out-Null
        if (Test-Path -LiteralPath $rpt) { Copy-Item -LiteralPath $rpt -Destination ("C:\WASP\aicom-eval\rpt-" + (Get-Date -Format "yyyyMMdd-HHmm") + ".RPT") -Force }
        Move-Item -LiteralPath (Join-Path $park $expName) -Destination (Join-Path $mp $expName)
        Log "experital restored - it wins the alphabetical auto-start"
    }

    # --- 5. Relaunch the chain (proven sequence incl. HC1 reslot bounce) -----------
    Run-Task "MiksuuPR8";  Start-Sleep 40
    Run-Task "MiksuuHC";   Start-Sleep 55
    Run-Task "DismissACR"
    Run-Task "MiksuuHC2";  Start-Sleep 50
    Run-Task "DismissACR"
    $hc1 = Get-Process ArmA2OA -ErrorAction SilentlyContinue | Sort-Object StartTime | Select-Object -First 1
    if ($hc1) { Stop-Process -Id $hc1.Id -Force }
    End-Task "MiksuuHC"; Run-Task "MiksuuHC"; Start-Sleep 55
    Run-Task "DismissACR"
    Start-Sleep 10
    $procs = @(Get-Process arma2oaserver, ArmA2OA -ErrorAction SilentlyContinue).Count
    Log "switch complete - $procs/3 processes up"
    if ($procs -lt 2) { Log "WARNING: fewer than server+1HC running - manual check advised" }
} catch {
    Log ("ERROR during switch: " + $_.Exception.Message + " - attempting state restore")
    # never leave MPMissions without a mission: if experital is in neither place, restore from park
    if (-not (Test-Path -LiteralPath (Join-Path $mp $expName)) -and (Test-Path -LiteralPath (Join-Path $park $expName)) -and $Target -eq "Experital") {
        Move-Item -LiteralPath (Join-Path $park $expName) -Destination (Join-Path $mp $expName) -ErrorAction SilentlyContinue
    }
    Run-Task "MiksuuPR8"
    exit 1
}
