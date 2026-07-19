#requires -Version 5.1
<#!
.SYNOPSIS
    Guards the GUER wildcard checkpoint against publishing a broken event.

.DESCRIPTION
    The default-on v2 checkpoint may create a hull, statics, and crews before
    it publishes the marker and starts the tax/toll watcher.  Every required
    driver/gunner must actually occupy its intended seat before that publish
    point.  A failed fresh attempt must roll back without awarding a token or
    charging the occupier.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
$script:Failures = 0

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
}

function Read-RequiredText {
    param([Parameter(Mandatory)] [string]$RelativePath)

    $path = Join-Path $RepoRoot $RelativePath
    if (!(Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Match {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Text -match $Pattern) {
        Write-Host ("  PASS  {0}" -f $Label)
    } else {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
    }
}

function Assert-EqualText {
    param(
        [Parameter(Mandatory)] [string]$Left,
        [Parameter(Mandatory)] [string]$Right,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($Left -ceq $Right) {
        Write-Host ("  PASS  {0}" -f $Label)
    } else {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
    }
}

function Remove-SqfLineComments {
    param([Parameter(Mandatory)] [string]$Text)

    return (($Text -split "\r?\n" | ForEach-Object { $_ -replace '//.*$', '' }) -join "`n")
}

function Get-SqfBlockFromOpenBrace {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [int]$OpenBraceIndex,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($OpenBraceIndex -lt 0 -or $OpenBraceIndex -ge $Text.Length -or $Text[$OpenBraceIndex] -ne '{') {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
        return $null
    }

    $depth = 0
    for ($index = $OpenBraceIndex; $index -lt $Text.Length; $index++) {
        if ($Text[$index] -eq '{') { $depth++ }
        if ($Text[$index] -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return [pscustomobject]@{
                    Start = $OpenBraceIndex
                    End = $index
                    Text = $Text.Substring($OpenBraceIndex, $index - $OpenBraceIndex + 1)
                }
            }
        }
    }

    Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
    $script:Failures++
    return $null
}

function Get-SqfBranchBlock {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (!$match.Success -or !$match.Groups['open'].Success) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
        return $null
    }

    return Get-SqfBlockFromOpenBrace -Text $Text -OpenBraceIndex $match.Groups['open'].Index -Label $Label
}

function Get-SqfElseBlock {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [AllowNull()] $IfBlock,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -eq $IfBlock) { return $null }
    $suffixStart = $IfBlock.End + 1
    $suffix = $Text.Substring($suffixStart)
    $match = [regex]::Match($suffix, '^\s*else\s*(?<open>\{)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (!$match.Success) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
        return $null
    }

    return Get-SqfBlockFromOpenBrace -Text $Text -OpenBraceIndex ($suffixStart + $match.Groups['open'].Index) -Label $Label
}

function Assert-BlockMatch {
    param(
        $Block,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -ne $Block) { Assert-Match -Text $Block.Text -Pattern $Pattern -Label $Label }
}

function Assert-BlockNotMatch {
    param(
        $Block,
        [Parameter(Mandatory)] [string]$Pattern,
        [Parameter(Mandatory)] [string]$Label
    )

    if ($null -eq $Block) { return }
    if ($Block.Text -match $Pattern) {
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
        $script:Failures++
    } else {
        Write-Host ("  PASS  {0}" -f $Label)
    }
}

$chernarus = 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Functions\AI_Commander_Wildcard_GUER.sqf'
$takistan = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan\Server\Functions\AI_Commander_Wildcard_GUER.sqf'
$zargabad = 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Server\Functions\AI_Commander_Wildcard_GUER.sqf'

$source = Read-RequiredText $chernarus
$code = Remove-SqfLineComments $source

Write-Host 'Checking wildcard checkpoint crew admission'
Assert-Match $source '(?s)_cpVehicleSeats\s*=\s*\[\].*?_cpStaticSeats\s*=\s*\[\]' 'Checkpoint records fresh vehicle and static seat receipts'
Assert-Match $source '(?s)_d1\s*=\s*objNull.*?_d2\s*=\s*objNull.*?_cpVehicleSeats\s+set' 'Checkpoint records the main hull seat receipt even on creation failure'
Assert-Match $source '(?s)_sGunner\s*=\s*objNull.*?_cpStaticSeats\s+set' 'Checkpoint records each static gunner receipt even on creation failure'
Assert-Match $source '(?s)_ad1\s*=\s*objNull.*?_ad2\s*=\s*objNull.*?_cpVehicleSeats\s+set' 'Checkpoint records each configured armor-hull seat receipt'
Assert-Match $source '(?s)sleep 1;\s*_cpCrewReady\s*=\s*true' 'Checkpoint waits for seat resolution before admission'
Assert-Match $source '(?s)\(driver _seatVeh\)\s*==\s*_seatDriver.*?\(gunner _seatVeh\)\s*==\s*_seatGunner' 'Checkpoint verifies driver and gunner occupancy for every hull'
Assert-Match $source '(?s)\(gunner _seatStatic\)\s*==\s*_seatStaticGunner' 'Checkpoint verifies gunner occupancy for every static'

$admission = Get-SqfBranchBlock -Text $code -Pattern 'if\s*\(\s*_cpCrewReady\s*\)\s*then\s*(?<open>\{)' -Label 'Checkpoint admission branch exists'
$rollback = Get-SqfElseBlock -Text $code -IfBlock $admission -Label 'Checkpoint rollback branch exists'
Assert-BlockMatch $admission 'createMarker\s*\[' 'Checkpoint creates its map marker only after all core seats are valid'
Assert-BlockMatch $admission 'ChangeSideSupply' 'Checkpoint tax/toll worker is reachable only after admission'
Assert-BlockMatch $admission '\[_grp, _veh, _target, _occSide' 'Checkpoint watcher starts only after admission'
Assert-BlockMatch $rollback 'GUERCP\|v2\|spawnfail\|' 'Checkpoint reports a failed seat receipt'
Assert-BlockMatch $rollback '(?s)forEach _cpObjs.*?forEach _statics.*?deleteVehicle _veh.*?deleteGroup _grp' 'Checkpoint rollback cleans props, fresh combat assets, and group'
Assert-BlockNotMatch $rollback 'createMarker\s*\[' 'Checkpoint rollback cannot publish a map marker'
Assert-BlockNotMatch $rollback 'ChangeSideSupply' 'Checkpoint rollback cannot tax or toll either side'
Assert-BlockNotMatch $rollback 'WFBE_GUER_FOB_AVAIL' 'Checkpoint rollback cannot award a FOB token'

Write-Host 'Checking wildcard announcement admission'
$announcement = Get-SqfBranchBlock -Text $code -Pattern 'if\s*\(\s*_result\s*==\s*"applied"\s*\)\s*then\s*(?<open>\{)' -Label 'Wildcard success-announcement branch exists'
Assert-BlockMatch $announcement '\[nil,\s*"LocalizeMessage",\s*\["Wildcard",\s*_locMsg\]\]' 'Only a successful wildcard draw broadcasts its strike announcement'

Write-Host 'Checking maintained-mirror parity'
Assert-EqualText $source (Read-RequiredText $takistan) 'Takistan wildcard mirror matches Chernarus'
Assert-EqualText $source (Read-RequiredText $zargabad) 'Zargabad wildcard mirror matches Chernarus'

Write-Host ''
if ($script:Failures -eq 0) {
    Write-Host 'Test-GuerWildcardCheckpointAtomic: PASS' -ForegroundColor Green
    exit 0
}

Write-Host ("Test-GuerWildcardCheckpointAtomic: {0} failure(s)" -f $script:Failures) -ForegroundColor Red
exit 1
