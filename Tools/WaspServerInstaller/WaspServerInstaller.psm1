#requires -Version 5.1
<#
.SYNOPSIS
  Config-driven WASP main-server installer (render + validate + dry-run + apply).

.DESCRIPTION
  Owner-facing easy installer layer. Reconciles with:
    - Tools/HetznerInstaller (PR #1102) — transactional fenced install of PBO/configs
    - Tools/Ops/Deploy-Wasp.ps1 — mission pack/deploy/verify/rollback (separate)
    - server-config/* + PR #1081 snapshots — proven basic.cfg / server.cfg baseline
    - Tools/Ops/Set-WaspCpuAffinity.ps1 — affinity mask application pattern

  Does NOT touch live main server slots. Safe default is dry-run.
  Secrets (password / passwordAdmin) are never written into example configs.

.NOTES
  GUIDE-REV awareness: tooling-only; no SQF mission edits.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ModuleRoot = $PSScriptRoot
$script:SchemaVersion = 1
$script:ImmutableDifficulty = 'Veteran'

function Get-WsiModuleRoot { return $script:ModuleRoot }

function Read-WsiJsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "JSON not found: $Path" }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return $raw | ConvertFrom-Json
}

function ConvertTo-WsiOrderedHashtable {
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $h = [ordered]@{}
        foreach ($k in $InputObject.Keys) { $h[$k] = ConvertTo-WsiOrderedHashtable $InputObject[$k] }
        return $h
    }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-WsiOrderedHashtable $p.Value }
        return $h
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $list = @()
        foreach ($i in $InputObject) { $list += ,(ConvertTo-WsiOrderedHashtable $i) }
        return $list
    }
    return $InputObject
}

function Get-WsiFlagCatalog {
    param([string]$CatalogPath = (Join-Path $script:ModuleRoot 'flag-catalog.json'))
    return Read-WsiJsonFile -Path $CatalogPath
}

function Get-WsiExampleConfig {
    param([string]$Path = (Join-Path $script:ModuleRoot 'wasp-server.example.json'))
    return Read-WsiJsonFile -Path $Path
}

function New-WsiDefaultConfig {
    <#
    .SYNOPSIS
      Clone the example config into a writeable object (secrets empty).
    #>
    $cfg = Get-WsiExampleConfig
    $cfg.server.password = ''
    $cfg.server.passwordAdmin = ''
    $cfg.server.difficulty = $script:ImmutableDifficulty
    return $cfg
}

function Save-WsiConfig {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Path
    )
    # Never persist secrets into a path under the repo Tools tree if mis-pointed.
    $clone = $Config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    if ($clone.server) {
        $clone.server.password = ''
        $clone.server.passwordAdmin = ''
        $clone.server.difficulty = $script:ImmutableDifficulty
    }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    ($clone | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $Path -Encoding UTF8
    return $Path
}

function Test-WsiConfig {
    <#
    .SYNOPSIS
      Validate config shape and invariants. Returns PSCustomObject with Ok + Errors[].
    #>
    param(
        [Parameter(Mandatory)]$Config,
        [switch]$RequireInstallRoot
    )
    $errors = New-Object System.Collections.Generic.List[string]

    if ($null -eq $Config) { $errors.Add('Config is null'); return [pscustomobject]@{ Ok = $false; Errors = $errors.ToArray() } }

    $sv = 0
    try { $sv = [int]$Config.schemaVersion } catch { $errors.Add('schemaVersion missing or not int') }
    if ($sv -ne $script:SchemaVersion) { $errors.Add("schemaVersion $sv != supported $($script:SchemaVersion)") }

    if (-not $Config.server) { $errors.Add('server section required') }
    else {
        if ([string]::IsNullOrWhiteSpace([string]$Config.server.hostname)) { $errors.Add('server.hostname required') }
        $port = 0
        try { $port = [int]$Config.server.port } catch { $errors.Add('server.port invalid') }
        if ($port -lt 1 -or $port -gt 65535) { $errors.Add('server.port out of range') }
        $diff = [string]$Config.server.difficulty
        if ($diff -and $diff -ne $script:ImmutableDifficulty) {
            $errors.Add("server.difficulty must be '$($script:ImmutableDifficulty)' (owner lock); got '$diff'")
        }
        $be = $Config.server.battlEye
        if ($null -ne $be -and [int]$be -notin 0,1) { $errors.Add('server.battlEye must be 0 or 1') }
    }

    if (-not $Config.mission -or [string]::IsNullOrWhiteSpace([string]$Config.mission.template)) {
        $errors.Add('mission.template required')
    }

    $hcCount = -1
    try { $hcCount = [int]$Config.headlessClients.count } catch { $errors.Add('headlessClients.count invalid') }
    if ($hcCount -lt 0 -or $hcCount -gt 8) { $errors.Add('headlessClients.count must be 0..8') }

    $mode = [string]$Config.telemetry.mode
    if ($mode -notin @('on','off','stats-only')) { $errors.Add("telemetry.mode must be on|off|stats-only (got '$mode')") }

    if ($RequireInstallRoot) {
        $ir = [string]$Config.paths.installRoot
        if ([string]::IsNullOrWhiteSpace($ir)) { $errors.Add('paths.installRoot required for Apply/DryRun') }
    }

    # Refuse live-shaped roots without explicit override env (belt + suspenders).
    $irCheck = [string]$Config.paths.installRoot
    if ($irCheck -and ($irCheck -match '(?i)^[cC]:\\WASP(\\|$)' -or $irCheck -match '(?i)157\.180\.54\.113')) {
        $errors.Add("paths.installRoot looks like live WASP layout ('$irCheck'). Use a scratch fence or set WASP_INSTALLER_ALLOW_LIVE_SHAPED=1 with owner authority.")
        if ($env:WASP_INSTALLER_ALLOW_LIVE_SHAPED -eq '1') {
            # demote to warning by removing error if env set
            $errors.RemoveAt($errors.Count - 1)
        }
    }

    return [pscustomobject]@{
        Ok = ($errors.Count -eq 0)
        Errors = $errors.ToArray()
        DifficultyLocked = $script:ImmutableDifficulty
    }
}

function Get-WsiLogicalProcessorCount {
    try {
        return [int]$env:NUMBER_OF_PROCESSORS
    } catch {
        return 8
    }
}

function Get-WsiAffinityPlan {
    <#
    .SYNOPSIS
      Compute disjoint affinity masks: OS reserved, server cores, then each HC.
      Hyperthread-sibling aware when possible: prefers even logical IDs first (common HT pairing 0-1,2-3,...).
    #>
    param(
        [Parameter(Mandatory)]$Config,
        [int]$LogicalCount = 0
    )
    if ($LogicalCount -le 0) { $LogicalCount = Get-WsiLogicalProcessorCount }
    $aff = $Config.perf.affinity
    $reserve = 2
    $serverCores = 4
    $perHc = 2
    if ($aff) {
        try { $reserve = [int]$aff.reserveOsLogicalCores } catch {}
        try { $serverCores = [int]$aff.serverLogicalCores } catch {}
        try { $perHc = [int]$aff.coresPerHc } catch {}
    }
    $hcCount = [int]$Config.headlessClients.count
    $need = $reserve + $serverCores + ($hcCount * $perHc)
    $warnings = New-Object System.Collections.Generic.List[string]
    if ($need -gt $LogicalCount) {
        $warnings.Add("Requested $need logical cores but host reports $LogicalCount — shrinking allocation.")
        # shrink: keep 1 OS, min 2 server, min 1 per HC if possible
        $reserve = [Math]::Min($reserve, 1)
        $serverCores = [Math]::Max(2, [Math]::Min($serverCores, [Math]::Max(2, $LogicalCount - $reserve - $hcCount)))
        $remain = $LogicalCount - $reserve - $serverCores
        if ($hcCount -gt 0) { $perHc = [Math]::Max(1, [int][Math]::Floor($remain / $hcCount)) }
    }

    # Prefer even logical IDs first (HT sibling-aware heuristic), then odds.
    $pool = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $LogicalCount; $i += 2) { [void]$pool.Add($i) }
    for ($i = 1; $i -lt $LogicalCount; $i += 2) { [void]$pool.Add($i) }

    $cursor = 0
    $osCores = @()
    for ($k = 0; $k -lt $reserve -and $cursor -lt $pool.Count; $k++) { $osCores += $pool[$cursor]; $cursor++ }
    $srvCores = @()
    for ($k = 0; $k -lt $serverCores -and $cursor -lt $pool.Count; $k++) { $srvCores += $pool[$cursor]; $cursor++ }
    $hcCoreSets = @()
    for ($h = 0; $h -lt $hcCount; $h++) {
        $set = @()
        for ($k = 0; $k -lt $perHc -and $cursor -lt $pool.Count; $k++) { $set += $pool[$cursor]; $cursor++ }
        $hcCoreSets += ,$set
    }

    $serverMask = [int64]0
    foreach ($c in $srvCores) {
        if ($c -ge 0 -and $c -lt 63) { $serverMask = $serverMask -bor ([int64]1 -shl $c) }
    }
    $hcMasks = @()
    foreach ($set in $hcCoreSets) {
        $m = [int64]0
        foreach ($c in $set) {
            if ($c -ge 0 -and $c -lt 63) { $m = $m -bor ([int64]1 -shl $c) }
        }
        $hcMasks += $m
    }

    return [pscustomobject]@{
        LogicalCount = $LogicalCount
        OsReservedCores = $osCores
        ServerCores = $srvCores
        HcCoreSets = $hcCoreSets
        ServerMask = $serverMask
        ServerMaskHex = ('0x{0:X}' -f $serverMask)
        HcMasks = $hcMasks
        HcMaskHex = @($hcMasks | ForEach-Object { '0x{0:X}' -f $_ })
        Warnings = $warnings.ToArray()
        MathComment = @"
Affinity math (logical processors, bit0=CPU0):
  hostLogical=$LogicalCount reserve=$reserve serverCores=$serverCores perHc=$perHc hcCount=$hcCount
  OS reserved cores: $($osCores -join ',')
  Server cores: $($srvCores -join ',') mask=$('0x{0:X}' -f $serverMask)
  HC masks: $((@($hcMasks | ForEach-Object { '0x{0:X}' -f $_ })) -join ', ')
  Policy: server and HCs never share cores; even IDs preferred first (HT-sibling heuristic).
  Apply via Start-Process affinity or post-boot Set-WaspCpuAffinity.ps1.
"@
    }
}

function Get-WsiTelemetryFlagPlan {
    param(
        [Parameter(Mandatory)]$Config,
        $Catalog = $null
    )
    if ($null -eq $Catalog) { $Catalog = Get-WsiFlagCatalog }
    $mode = [string]$Config.telemetry.mode
    $plan = [ordered]@{}
    foreach ($f in $Catalog.flags) {
        $hasTm = $null -ne ($f.PSObject.Properties['telemetryModes'])
        if (-not $hasTm) { continue }
        $tm = $f.telemetryModes
        if ($null -eq $tm) { continue }
        $val = $null
        switch ($mode) {
            'on' { $val = $tm.on }
            'off' { $val = $tm.off }
            'stats-only' { $val = $tm.'stats-only' }
        }
        $plan[$f.id] = [pscustomobject]@{
            value = $val
            layer = $f.layer
            title = $f.title
            description = $f.description
            source = $f.source
            fromTelemetryMode = $mode
        }
    }
    # Merge explicit featureFlags (explicit wins)
    if ($Config.featureFlags) {
        foreach ($p in $Config.featureFlags.PSObject.Properties) {
            $meta = @($Catalog.flags | Where-Object { $_.id -eq $p.Name } | Select-Object -First 1)
            $meta0 = if ($meta.Count -gt 0) { $meta[0] } else { $null }
            $layer = if ($meta0) { $meta0.layer } else { 'unknown-verify-before-apply' }
            $plan[$p.Name] = [pscustomobject]@{
                value = $p.Value
                layer = $layer
                title = if ($meta0) { $meta0.title } else { $p.Name }
                description = if ($meta0) { $meta0.description } else { 'User-specified; not in curated catalog' }
                source = if ($meta0) { $meta0.source } else { 'config.featureFlags' }
                fromTelemetryMode = $null
            }
        }
    }
    return $plan
}

function ConvertTo-WsiCfgStringList {
    param([string[]]$Lines)
    if (-not $Lines -or $Lines.Count -eq 0) { return '{""}' }
    $escaped = @()
    foreach ($l in $Lines) {
        $e = ($l -replace '\\', '\\\\') -replace '"', '\"'
        $escaped += ('"{0}"' -f $e)
    }
    return '{' + ($escaped -join ', ') + '}'
}

function New-WsiServerCfgContent {
    param(
        [Parameter(Mandatory)]$Config,
        [string]$Password = '',
        [string]$PasswordAdmin = ''
    )
    $s = $Config.server
    $hc = $Config.headlessClients
    $m = $Config.mission
    $diff = $script:ImmutableDifficulty
    $be = 0
    try { $be = [int]$s.battlEye } catch {}
    $pw = if ($Password) { $Password } else { [string]$s.password }
    $pwa = if ($PasswordAdmin) { $PasswordAdmin } else { [string]$s.passwordAdmin }
    if ([string]::IsNullOrWhiteSpace($pwa)) { $pwa = '__SET_AT_APPLY_TIME__' }

    $addrs = @('127.0.0.1')
    if ($hc.bindAddresses) { $addrs = @($hc.bindAddresses) }
    $addrList = ($addrs | ForEach-Object { '"{0}"' -f $_ }) -join ', '

    $motd = @()
    if ($s.motd) { $motd = @($s.motd) }
    $rules = @()
    if ($s.rules) { $rules = @($s.rules) }
    $motdAll = @($motd + $rules)
    $motdBlock = ConvertTo-WsiCfgStringList -Lines $motdAll
    $motdInterval = 30
    try { $motdInterval = [int]$s.motdInterval } catch {}

    $className = if ($m.className) { [string]$m.className } else { 'WASP_Mission' }
    $template = [string]$m.template

    $hcCount = [int]$hc.count
    $hcComment = if ($hcCount -gt 0) {
        "headlessClients[] = {$addrList};`r`nlocalClient[] = {$addrList};"
    } else {
        "// headlessClients disabled (count=0)"
    }

    $verify = 2
    try { $verify = [int]$s.verifySignatures } catch {}
    $kick = 1
    try { $kick = [int]$s.kickDuplicate } catch {}
    $persist = 1
    try { $persist = [int]$s.persistent } catch {}
    $maxP = 56
    try { $maxP = [int]$s.maxPlayers } catch {}

    return @"
// Generated by Tools/WaspServerInstaller — do not hand-edit without re-apply
// difficulty is IMMUTABLE: Veteran (owner directive 2026-07-17)
// passwordAdmin: set only on box; never commit real values
hostname = "$([string]$s.hostname)";
password = "$pw";
passwordAdmin = "$pwa";
maxPlayers = $maxP;
persistent = $persist;
BattlEye = $be;
kickDuplicate = $kick;
verifySignatures = $verify;
motd[] = $motdBlock;
motdInterval = $motdInterval;
$hcComment

class Missions
{
    class $className
    {
        template = "$template";
        difficulty = "$diff";
    };
};
"@
}

function New-WsiBasicCfgContent {
    param([Parameter(Mandatory)]$Config)
    $b = $Config.perf.basicCfg
    $get = {
        param($name, $default)
        if ($null -ne $b -and $null -ne $b.$name) { return $b.$name }
        return $default
    }
    $minBw = & $get 'MinBandwidth' 131072
    $maxBw = & $get 'MaxBandwidth' 104857600
    $maxMsg = & $get 'MaxMsgSend' 512
    $maxG = & $get 'MaxSizeGuaranteed' 512
    $maxN = & $get 'MaxSizeNonguaranteed' 512
    $minErr = & $get 'MinErrorToSend' 0.005
    $minNear = & $get 'MinErrorToSendNear' 0.03
    $maxCustom = & $get 'MaxCustomFileSize' 0

    # Optional mild slot scaling — only MaxBandwidth bump if enabled and maxPlayers high; never touch MaxSizeGuaranteed.
    $maxPlayers = 56
    try { $maxPlayers = [int]$Config.server.maxPlayers } catch {}
    if ($b.slotScaling -and [bool]$b.slotScaling.enabled) {
        $base = 56
        try { $base = [int]$b.slotScaling.baseMaxPlayers } catch {}
        if ($maxPlayers -gt $base) {
            # Keep MaxMsgSend at proven 512 unless operator sets MaxMsgSendPerExtra8Slots > 0 with evidence
            $extra = 0
            try { $extra = [int]$b.slotScaling.MaxMsgSendPerExtra8Slots } catch {}
            if ($extra -gt 0) {
                $steps = [int][Math]::Floor(($maxPlayers - $base) / 8)
                $maxMsg = [int]$maxMsg + ($steps * $extra)
            }
        }
    }

    return @"
// Generated by Tools/WaspServerInstaller — VERSIONED artifact: basic.cfg.v1
// WHY: live JIP fix MaxSizeGuaranteed=512 (server-config/README.md; PR #1081 snapshot family)
// Do NOT raise MaxSizeGuaranteed to 1024 — causes permanent black "Receiving mission".
language="English";
adapter=-1;
3D_Performance=1;
Resolution_Bpp=32;
MinBandwidth=$minBw;
MaxBandwidth=$maxBw;
MaxMsgSend=$maxMsg;
MaxSizeGuaranteed=$maxG;
MaxSizeNonguaranteed=$maxN;
MinErrorToSend=$minErr;
MinErrorToSendNear=$minNear;
MaxCustomFileSize=$maxCustom;
Windowed=0;
"@
}

function New-WsiServerLaunchCmd {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)]$AffinityPlan,
        [string]$ProfilesDir
    )
    $port = [int]$Config.server.port
    $malloc = [string]$Config.perf.serverMalloc
    if ([string]::IsNullOrWhiteSpace($malloc)) { $malloc = 'mimalloc' }
    $cpu = 2
    try { $cpu = [int]$Config.perf.serverCpuCount } catch {}
    $ex = 3
    try { $ex = [int]$Config.perf.serverExThreads } catch {}
    $maxMem = 2047
    try { $maxMem = [int]$Config.perf.maxMem } catch {}
    $root = [string]$Config.paths.arma2oaRoot
    $maskHex = $AffinityPlan.ServerMaskHex
    $prio = [string]$Config.perf.serverPriority
    if ([string]::IsNullOrWhiteSpace($prio)) { $prio = 'High' }

    return @"
@echo off
REM Generated by Tools/WaspServerInstaller
REM $($AffinityPlan.MathComment -replace "`r`n","`r`nREM ")
REM Priority: $prio (apply via `start /HIGH` or post-boot wmic/SetPriority)
set SteamAppId=33930
cd /d "$root"
REM Affinity mask $maskHex — start /affinity expects hex without 0x on some hosts; using PowerShell pin recommended.
REM start "WASP-Server" /HIGH /AFFINITY $($AffinityPlan.ServerMask.ToString('X')) arma2oaserver.exe ...
arma2oaserver.exe -port=$port "-config=$ProfilesDir\server.cfg" "-cfg=$ProfilesDir\basic.cfg" "-profiles=$ProfilesDir" -malloc=$malloc -cpuCount=$cpu -exThreads=$ex -maxMem=$maxMem -nosplash -noPause -world=empty
"@
}

function New-WsiHcLaunchCmd {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)]$AffinityPlan,
        [Parameter(Mandatory)][int]$Index,
        [string]$HcVideoCfg = ''
    )
    $port = [int]$Config.server.port
    $root = [string]$Config.paths.arma2oaRoot
    $a2 = [string]$Config.paths.arma2Root
    $modCore = [string]$Config.headlessClients.modLine
    if ([string]::IsNullOrWhiteSpace($modCore)) { $modCore = '@CBA_CO;@adwasp;@admkswf' }
    $mod = $modCore
    if ($Config.headlessClients.includeArma2RootInMod -ne $false) {
        $mod = "$a2;expansion;$modCore"
    }
    $namePrefix = [string]$Config.headlessClients.namePrefix
    if ([string]::IsNullOrWhiteSpace($namePrefix)) { $namePrefix = 'HC-AI-Control' }
    $name = "{0}-{1}" -f $namePrefix, $Index
    $alloc = [string]$Config.headlessClients.hcAllocator
    if ([string]::IsNullOrWhiteSpace($alloc)) { $alloc = 'tbb4malloc_bi' }
    $cpu = 2
    try { $cpu = [int]$Config.headlessClients.hcCpuCount } catch {}
    $ex = 3
    try { $ex = [int]$Config.headlessClients.hcExThreads } catch {}
    $maxMem = 2047
    try { $maxMem = [int]$Config.headlessClients.hcMaxMem } catch {}
    $mask = 0
    if ($AffinityPlan.HcMasks -and $AffinityPlan.HcMasks.Count -ge $Index) {
        $mask = [int64]$AffinityPlan.HcMasks[$Index - 1]
    }
    $maskHex = '0x{0:X}' -f $mask
    if ([string]::IsNullOrWhiteSpace($HcVideoCfg)) {
        $HcVideoCfg = 'hc-profile\hc-video.cfg'
    }
    $prio = [string]$Config.perf.hcPriority
    if ([string]::IsNullOrWhiteSpace($prio)) { $prio = 'AboveNormal' }

    $useSb = $false
    if ($Index -ge 2 -and $Config.headlessClients.useSandboxieForHc2Plus) { $useSb = $true }
    $box = [string]$Config.headlessClients.sandboxieBoxName
    if ([string]::IsNullOrWhiteSpace($box)) { $box = 'HC2' }

    if ($useSb) {
        return @"
@echo off
REM Generated by Tools/WaspServerInstaller — HC$Index (Sandboxie-isolated Steam session)
REM Affinity mask $maskHex  Priority $prio
REM $($AffinityPlan.MathComment -replace "`r`n","`r`nREM ")
set SteamAppId=33930
set SBIE=C:\Program Files\Sandboxie-Plus\Start.exe
"%SBIE%" /box:$box "C:\Program Files (x86)\Steam\steam.exe" -silent
timeout /t 30 /nobreak >nul
cd /d "$root"
"%SBIE%" /box:$box "$root\ArmA2OA.exe" -client -connect=127.0.0.1 -port=$port -window -cfg="$HcVideoCfg" "-mod=$mod" -name="$name" -exThreads=$ex -cpuCount=$cpu -malloc=$alloc -maxMem=$maxMem -world=empty -nosplash -noPause -noSound
"@
    }

    return @"
@echo off
REM Generated by Tools/WaspServerInstaller — HC$Index
REM Affinity mask $maskHex  Priority $prio
REM $($AffinityPlan.MathComment -replace "`r`n","`r`nREM ")
set SteamAppId=33930
cd /d "$root"
ArmA2OA.exe -client -connect=127.0.0.1 -port=$port -window -cfg="$HcVideoCfg" "-mod=$mod" -name="$name" -exThreads=$ex -cpuCount=$cpu -malloc=$alloc -maxMem=$maxMem -world=empty -nosplash -noPause -noSound
"@
}

function New-WsiAsrUserconfig {
    param([Parameter(Mandatory)]$Config)
    $k = $null
    if ($Config.perf.asrAi -and $Config.perf.asrAi.knobs) { $k = $Config.perf.asrAi.knobs }
    $enabled = 1; $debug = 0; $gun = 1; $jip = 1
    if ($k) {
        try { $enabled = [int]$k.enabled } catch {}
        try { $debug = [int]$k.debug } catch {}
        try { $gun = [int]$k.gunshotHearing } catch {}
        try { $jip = [int]$k.joinInProgress } catch {}
    }
    return @"
// Generated skeleton by Tools/WaspServerInstaller
// WHY: ASR AI (@adwasp) is the primary modpack AI/FPS lever on HC locality (server-config/README.md).
// Merge with your live userconfig/asr_ai/asr_ai_settings.hpp — knob names vary by ASR build.
// Source: server-config README HC mod line @CBA_CO;@adwasp;@admkswf
class asr_ai_settings {
    enabled = $enabled;
    debug = $debug;
    // Placeholder semantic knobs (owner should reconcile with installed ASR version):
    gunshotHearing = $gun;
    joinInProgress = $jip;
};
"@
}

function New-WsiFirewallScript {
    param([Parameter(Mandatory)]$Config)
    $port = [int]$Config.server.port
    $name = [string]$Config.paths.firewallRuleName
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'WASP-Arma2OA' }
    return @"
#requires -Version 5.1
# Generated by Tools/WaspServerInstaller — run elevated on the box only
# Opens UDP game port + Steam query-adjacent (port, port+1) for Arma 2 OA dedicated.
`$ErrorActionPreference = 'Stop'
`$ports = @($port, $($port+1))
foreach (`$p in `$ports) {
    `$n = '$name-UDP-' + `$p
    if (-not (Get-NetFirewallRule -DisplayName `$n -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName `$n -Direction Inbound -Protocol UDP -LocalPort `$p -Action Allow | Out-Null
        Write-Host "Created `$n"
    } else { Write-Host "Exists `$n" }
}
"@
}

function New-WsiRenderBundle {
    <#
    .SYNOPSIS
      Build in-memory render of all installer outputs from config.
    #>
    param(
        [Parameter(Mandatory)]$Config,
        [string]$Password = '',
        [string]$PasswordAdmin = '',
        [int]$LogicalCount = 0
    )
    $v = Test-WsiConfig -Config $Config
    if (-not $v.Ok) { throw "Config invalid: $($v.Errors -join '; ')" }

    # Force difficulty lock in rendered output even if omitted
    if ($Config.server) { $Config.server.difficulty = $script:ImmutableDifficulty }

    $aff = Get-WsiAffinityPlan -Config $Config -LogicalCount $LogicalCount
    $catalog = Get-WsiFlagCatalog
    $flagPlan = Get-WsiTelemetryFlagPlan -Config $Config -Catalog $catalog
    $profilesName = 'profiles-main'
    if ($Config.paths.profilesDirName) { $profilesName = [string]$Config.paths.profilesDirName }
    $profilesRel = $profilesName

    $files = [ordered]@{}
    $files["$profilesRel/server.cfg"] = New-WsiServerCfgContent -Config $Config -Password $Password -PasswordAdmin $PasswordAdmin
    $files["$profilesRel/basic.cfg"] = New-WsiBasicCfgContent -Config $Config
    $files["$profilesRel/basic.cfg.v1"] = $files["$profilesRel/basic.cfg"]
    $files['server_launch.cmd'] = New-WsiServerLaunchCmd -Config $Config -AffinityPlan $aff -ProfilesDir $profilesRel

    $hcCount = [int]$Config.headlessClients.count
    for ($i = 1; $i -le $hcCount; $i++) {
        $leaf = if ($i -eq 1) { 'hc_launch.cmd' } elseif ($i -eq 2) { 'hc2_launch.cmd' } else { "hc${i}_launch.cmd" }
        $files[$leaf] = New-WsiHcLaunchCmd -Config $Config -AffinityPlan $aff -Index $i
    }

    if ($Config.perf.asrAi -and $Config.perf.asrAi.enabled) {
        $rel = 'userconfig/asr_ai/asr_ai_settings.hpp'
        if ($Config.perf.asrAi.userconfigRelative) { $rel = [string]$Config.perf.asrAi.userconfigRelative }
        $files[$rel] = New-WsiAsrUserconfig -Config $Config
    }

    $files['firewall-open-ports.ps1'] = New-WsiFirewallScript -Config $Config

    $flagPlanObj = [ordered]@{
        schemaVersion = 1
        difficultyLocked = $script:ImmutableDifficulty
        telemetryMode = [string]$Config.telemetry.mode
        layerNote = $catalog.layerNote
        parametersTrap = 'Lobby Parameters.hpp default= WINS over Init_CommonConstants.sqf. This plan does NOT rewrite mission SQF. Lobby-layer entries require Deploy-Wasp repack or lobby UI. Script-layer entries require mission rebuild or a future pre-init overlay.'
        flags = $flagPlan
        rptTailProducer = [bool]$Config.telemetry.rptTailProducer
    }
    $files['flag-plan/flag-plan.json'] = ($flagPlanObj | ConvertTo-Json -Depth 10)
    $files['flag-plan/README.md'] = @"
# Flag plan (installer output)

## Parameters.hpp trap
Mission lobby parameters registered in ``Rsc/Parameters.hpp`` use ``default=`` values that **override** ``Init_CommonConstants.sqf`` ``isNil`` fallbacks when the mission starts from the multiplayer lobby.

## What this installer writes
- **server.cfg / basic.cfg / launch scripts**: applied under the install root (this tool).
- **flag-plan.json**: desired feature/telemetry values + layer metadata. It does **not** silently patch mission SQF.

## How to realize lobby flags
1. Review ``flag-plan.json`` entries with ``layer=lobby``.
2. Pack a mission build whose Parameters.hpp defaults match (via your normal Deploy-Wasp flow), **or** set them in the MP lobby before start.
3. Script-layer flags (telemetry etc.) also need a mission build that honors them, unless you maintain a private overlay (out of scope here).

## Telemetry modes
- **on** — gameplay/WASPSCALE-family + stats pipeline
- **off** — all mapped telemetry flags off
- **stats-only** — player stats / PLAYERSTAT on; broader RPT gameplay telemetry off
"@

    $files['AFFINITY.txt'] = $aff.MathComment
    $files['INSTALL-RECEIPT.json'] = (@{
        tool = 'Tools/WaspServerInstaller'
        schemaVersion = $script:SchemaVersion
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        hostname = [string]$Config.server.hostname
        port = [int]$Config.server.port
        hcCount = $hcCount
        telemetryMode = [string]$Config.telemetry.mode
        difficulty = $script:ImmutableDifficulty
        serverMask = $aff.ServerMaskHex
        hcMasks = $aff.HcMaskHex
        malloc = [string]$Config.perf.serverMalloc
        basedOn = @(
            'PR #1102 HetznerInstaller',
            'Deploy-Wasp.ps1',
            'server-config + PR #1081',
            'Set-WaspCpuAffinity.ps1'
        )
    } | ConvertTo-Json -Depth 6)

    $files['README-GENERATED.md'] = @"
# Generated WASP server install tree

Produced by ``Tools/WaspServerInstaller``.

| Next step | Tool |
| --- | --- |
| Mission PBO pack/deploy/verify | ``Tools/Ops/Deploy-Wasp.ps1`` (owner; never agents on live) |
| Fenced transactional host tree | ``Tools/HetznerInstaller`` (PR #1102; MIKSUUS-TEST gate) |
| Post-boot affinity | ``Tools/Ops/Set-WaspCpuAffinity.ps1`` or masks in launch comments |

Difficulty is locked to **Veteran**. BattlEye default off per BE-master-down finding (override in config).
"@

    return [pscustomobject]@{
        Files = $files
        Affinity = $aff
        FlagPlan = $flagPlanObj
        Validation = $v
    }
}

function Get-WsiFileHashSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Compare-WsiRenderToDisk {
    param(
        [Parameter(Mandatory)]$Bundle,
        [Parameter(Mandatory)][string]$InstallRoot
    )
    $diffs = New-Object System.Collections.Generic.List[object]
    foreach ($rel in $Bundle.Files.Keys) {
        $dest = Join-Path $InstallRoot ($rel -replace '/', '\')
        $desired = [string]$Bundle.Files[$rel]
        if (-not (Test-Path -LiteralPath $dest)) {
            $diffs.Add([pscustomobject]@{ Path = $rel; Status = 'MISSING'; Detail = 'would create' })
            continue
        }
        $existing = Get-Content -LiteralPath $dest -Raw -Encoding UTF8
        # Normalize newlines for compare (CRLF / CR / LF -> LF)
        $a = (($existing -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd()
        $b = (($desired -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd()
        if ($a -ne $b) {
            $diffs.Add([pscustomobject]@{ Path = $rel; Status = 'DIFFER'; Detail = ("disk={0}B desired={1}B" -f $existing.Length, $desired.Length) })
        } else {
            $diffs.Add([pscustomobject]@{ Path = $rel; Status = 'SAME'; Detail = '' })
        }
    }
    return $diffs.ToArray()
}

function Install-WsiRenderBundle {
    param(
        [Parameter(Mandatory)]$Bundle,
        [Parameter(Mandatory)][string]$InstallRoot,
        [switch]$Apply
    )
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) { throw 'InstallRoot required' }
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($rel in $Bundle.Files.Keys) {
        $dest = Join-Path $InstallRoot ($rel -replace '/', '\')
        $desired = [string]$Bundle.Files[$rel]
        if (-not $Apply) {
            $results.Add([pscustomobject]@{ Path = $rel; Action = 'DRYRUN-WRITE'; Dest = $dest })
            continue
        }
        $dir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $tmp = $dest + '.wsi-tmp'
        # UTF8 no BOM preferred for cfg; .NET API
        # Normalize any existing CRLF to LF first so we never emit CR CR LF.
        $normalized = ($desired -replace "`r`n", "`n" -replace "`r", "`n") -replace "`n", "`r`n"
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tmp, $normalized, $utf8)
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
        Move-Item -LiteralPath $tmp -Destination $dest -Force
        $hash = Get-WsiFileHashSha256 -Path $dest
        $results.Add([pscustomobject]@{ Path = $rel; Action = 'WROTE'; Dest = $dest; Sha256 = $hash })
    }
    return $results.ToArray()
}

function Invoke-WsiInteractiveNewConfig {
    <#
    .SYNOPSIS
      Minimal interactive prompts; writes config JSON (no secrets stored).
    #>
    param([Parameter(Mandatory)][string]$OutPath)
    $cfg = New-WsiDefaultConfig
    Write-Host "WASP Server Installer — interactive config (empty = keep default)"
    $h = Read-Host "Hostname [$($cfg.server.hostname)]"
    if ($h) { $cfg.server.hostname = $h }
    $p = Read-Host "Port [$($cfg.server.port)]"
    if ($p) { $cfg.server.port = [int]$p }
    $hc = Read-Host "HC count 0-8 [$($cfg.headlessClients.count)]"
    if ($hc -ne '') { $cfg.headlessClients.count = [int]$hc }
    $tm = Read-Host "Telemetry mode on|off|stats-only [$($cfg.telemetry.mode)]"
    if ($tm) { $cfg.telemetry.mode = $tm }
    $be = Read-Host "BattlEye 0|1 [$($cfg.server.battlEye)]"
    if ($be -ne '') { $cfg.server.battlEye = [int]$be }
    $mp = Read-Host "Mission template [$($cfg.mission.template)]"
    if ($mp) { $cfg.mission.template = $mp }
    $ir = Read-Host "Install root (scratch path for Apply)"
    if ($ir) { $cfg.paths.installRoot = $ir }
    $cfg.server.difficulty = $script:ImmutableDifficulty
    Save-WsiConfig -Config $cfg -Path $OutPath | Out-Null
    Write-Host "Wrote $OutPath (secrets not stored; pass -PasswordAdmin at Apply)"
    return $OutPath
}

Export-ModuleMember -Function @(
    'Get-WsiModuleRoot',
    'Read-WsiJsonFile',
    'Get-WsiFlagCatalog',
    'Get-WsiExampleConfig',
    'New-WsiDefaultConfig',
    'Save-WsiConfig',
    'Test-WsiConfig',
    'Get-WsiLogicalProcessorCount',
    'Get-WsiAffinityPlan',
    'Get-WsiTelemetryFlagPlan',
    'New-WsiRenderBundle',
    'Compare-WsiRenderToDisk',
    'Install-WsiRenderBundle',
    'Invoke-WsiInteractiveNewConfig',
    'New-WsiServerCfgContent',
    'New-WsiBasicCfgContent'
)
