<#
.SYNOPSIS
  Resolve a named test scenario from scenarios.json into a concrete, ready-to-run spec.

.DESCRIPTION
  Merges the catalog defaults, resolves the map template, expands a sweep scenario into one
  concrete run per swept value, and applies any caller overrides. Pure and deterministic
  (no Arma, no I/O beyond reading the catalog) so it is fully unit-testable offline.

.OUTPUTS
  With -List: the scenario names + descriptions (text).
  With -Name: the resolved spec object, or its JSON with -Json.

  Resolved spec shape:
    { name, description, requires[], asserts[], base{...}, runs[ {runLabel, map, template,
      hcCount, popPin, durationMin, flags{}} ] }

.NOTES
  A2-OA-1.64 project tooling; no mission code touched. Guide rev GR-2026-07-03a.
#>
[CmdletBinding()]
param(
    [string] $Name,
    [switch] $List,
    [string] $ScenariosPath,
    [string] $Map,
    [int]    $HcCount = -999,
    [int]    $PopPin  = -999,
    [int]    $DurationMin = -999,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ScenariosPath)) { $ScenariosPath = Join-Path $PSScriptRoot 'scenarios.json' }
if (-not (Test-Path -LiteralPath $ScenariosPath)) { throw "scenarios.json not found: $ScenariosPath" }
$cat = [System.IO.File]::ReadAllText($ScenariosPath) | ConvertFrom-Json

function Props($obj) { if ($null -eq $obj) { return @() } return $obj.PSObject.Properties.Name }

if ($List) {
    Write-Output "Scenarios in $ScenariosPath :"
    foreach ($n in (Props $cat.scenarios)) {
        $s = $cat.scenarios.$n
        $sweep = if ($s.PSObject.Properties['sweep']) { "  [sweep: $($s.sweep.dimension) x$($s.sweep.values.Count)]" } else { '' }
        Write-Output ("  {0,-14} {1}{2}" -f $n, $s.description, $sweep)
    }
    return
}
if ([string]::IsNullOrWhiteSpace($Name)) { throw "Specify -Name <scenario> or -List." }
if (-not ($cat.scenarios.PSObject.Properties[$Name])) {
    throw "Unknown scenario '$Name'. Known: $((Props $cat.scenarios) -join ', ')"
}
$s   = $cat.scenarios.$Name
$def = $cat.defaults

# --- merge defaults, then per-scenario, then overrides -----------------------
function Pick($scenObj, $key, $fallback) {
    if ($scenObj.PSObject.Properties[$key] -and $null -ne $scenObj.$key) { return $scenObj.$key }
    return $fallback
}
# NOTE: PowerShell variable names are case-insensitive, so the working locals MUST NOT reuse
# the parameter names ($Map/$HcCount/$PopPin) or the merge would clobber the caller's override.
$rMap = Pick $s 'map'         $def.map
$rHc  = [int](Pick $s 'hcCount'     $def.hcCount)
$rPin = [int](Pick $s 'popPin'      $def.popPin)
$rDur = [int](Pick $s 'durationMin' $def.durationMin)
if (-not [string]::IsNullOrWhiteSpace($Map)) { $rMap = $Map }
if ($HcCount -ne -999)     { $rHc = $HcCount }
if ($PopPin -ne -999)      { $rPin = $PopPin }
if ($DurationMin -ne -999) { $rDur = $DurationMin }

if (-not ($cat.templates.PSObject.Properties[$rMap])) {
    throw "No template for map '$rMap'. Known: $((Props $cat.templates) -join ', ')"
}
$template = $cat.templates.$rMap

# flags: scenario flags (defaults are empty)
$flags = [ordered]@{}
if ($s.PSObject.Properties['flags']) {
    foreach ($fp in $s.flags.PSObject.Properties) { $flags[$fp.Name] = $fp.Value }
}

$requires = @()
if ($s.PSObject.Properties['requires']) { $requires = @($s.requires) }
$asserts = @()
if ($s.PSObject.Properties['asserts']) { $asserts = @($s.asserts) }

# --- build the run list (expand sweep) --------------------------------------
function New-Run([string]$label, [string]$rmap, [string]$rtpl, [int]$hc, [int]$pin, [int]$dur, $fl) {
    return [ordered]@{
        runLabel = $label; map = $rmap; template = $rtpl
        hcCount = $hc; popPin = $pin; durationMin = $dur; flags = $fl
    }
}
$runs = @()
if ($s.PSObject.Properties['sweep']) {
    $dim = $s.sweep.dimension
    foreach ($v in $s.sweep.values) {
        switch ($dim) {
            'popPin'  { $runs += (New-Run ("pin$v") $rMap $template $rHc ([int]$v) $rDur $flags) }
            'hcCount' { $runs += (New-Run ("hc$v")  $rMap $template ([int]$v) $rPin $rDur $flags) }
            default   { throw "Unsupported sweep dimension '$dim' in scenario '$Name'." }
        }
    }
} else {
    $runs += (New-Run 'single' $rMap $template $rHc $rPin $rDur $flags)
}

$spec = [ordered]@{
    name        = $Name
    description = $s.description
    requires    = $requires
    asserts     = $asserts
    base        = [ordered]@{
        map = $rMap; template = $template; hcCount = $rHc
        popPin = $rPin; durationMin = $rDur; flags = $flags
    }
    runs        = $runs
}

if ($Json) {
    if ($PSVersionTable.PSVersion.Major -ge 6) { return ($spec | ConvertTo-Json -Depth 20) }
    Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.MaxJsonLength = [int]::MaxValue
    return $ser.Serialize($spec)
}
return $spec
